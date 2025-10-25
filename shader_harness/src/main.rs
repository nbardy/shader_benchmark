use clap::Parser;
use std::{borrow::Cow, fs, path::PathBuf, time::Instant};

// GPU-aligned struct for uniform buffer
// CRITICAL: Matches WGSL_CONSTRAINT_SPEC.md section 2.3 contract:
//   @group(0) @binding(0) var<uniform> Params: Params;
//   struct Params { resolution: vec2<f32>, ... }
#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
struct Params {
    resolution: [f32; 2],
    _padding: [f32; 2],  // Align to 16 bytes (vec4 alignment requirement)
}

/// Render WGSL shaders off-screen, save PNG + timings.
/// WGSL only: locked format for deterministic LLM generation.
#[derive(Parser)]
struct Opts {
    /// Shader file (.wgsl)
    #[arg(short, long)]
    shader: PathBuf,
    /// PNG file to write
    #[arg(short, long, default_value = "out.png")]
    output: PathBuf,
    /// Width & height in pixels
    #[arg(short = 'z', long, default_value_t = 1024)]
    size: u32,
}

fn main() {
    // --- parse CLI ---------------------------------------------------------
    let opts = Opts::parse();
    let shader_code = fs::read_to_string(&opts.shader)
        .expect("failed to read shader file");

    // --- init GPU ----------------------------------------------------------
    let now = Instant::now();
    let instance = wgpu::Instance::default();
    let adapter  = pollster::block_on(instance.request_adapter(
        &wgpu::RequestAdapterOptions::default(),
    )).expect("No compatible GPU");

    let (device, queue) = pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            required_features: wgpu::Features::TIMESTAMP_QUERY | wgpu::Features::TIMESTAMP_QUERY_INSIDE_ENCODERS,
            required_limits  : wgpu::Limits::default(),
            label   : None,
        },
        None,
    )).expect("Device failed");

    // --- resources ---------------------------------------------------------
    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some("user_shader"),
        source: wgpu::ShaderSource::Wgsl(Cow::Owned(shader_code)),
    });

    // --- uniform buffer setup ----------------------------------------------
    // Create uniform buffer for Params struct (resolution, etc.)
    // WGSL contract: @group(0) @binding(0) var<uniform> Params: Params;
    let params = Params {
        resolution: [opts.size as f32, opts.size as f32],
        _padding: [0.0, 0.0],
    };

    let uniform_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("uniform_buffer"),
        size: std::mem::size_of::<Params>() as u64,
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
        mapped_at_creation: false,
    });

    // Write initial resolution to uniform buffer
    queue.write_buffer(&uniform_buffer, 0, bytemuck::cast_slice(&[params]));

    // Create bind group layout matching shader expectations
    // Matches WGSL: @group(0) @binding(0) var<uniform> Params: Params;
    let bind_group_layout = device.create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
        label: Some("uniform_bind_group_layout"),
        entries: &[
            wgpu::BindGroupLayoutEntry {
                binding: 0,
                visibility: wgpu::ShaderStages::FRAGMENT,
                ty: wgpu::BindingType::Buffer {
                    ty: wgpu::BufferBindingType::Uniform,
                    has_dynamic_offset: false,
                    min_binding_size: None,
                },
                count: None,
            }
        ],
    });

    // Create bind group binding the uniform buffer
    let bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: Some("uniform_bind_group"),
        layout: &bind_group_layout,
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: uniform_buffer.as_entire_binding(),
            }
        ],
    });

    // full-screen triangle – no vertex buffer, single uniform bind group
    let pipeline_layout =
        device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            bind_group_layouts: &[&bind_group_layout],
            push_constant_ranges: &[],
            label: None,
        });

    let render_pipeline =
        device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "vs_main",
                buffers: &[],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "fs_main",
                targets: &[Some(wgpu::ColorTargetState {
                    format: wgpu::TextureFormat::Rgba8UnormSrgb,
                    blend: None,
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
        });

    run_render_pass(&device, &queue, render_pipeline, &bind_group, &opts, now);
}

fn run_render_pass(
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    render_pipeline: wgpu::RenderPipeline,
    bind_group: &wgpu::BindGroup,
    opts: &Opts,
    now: Instant,
) {
    // output texture → buffer
    let extent = wgpu::Extent3d {
        width : opts.size,
        height: opts.size,
        depth_or_array_layers: 1,
    };
    let texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("output"),
        size: extent,
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8UnormSrgb,
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT
             | wgpu::TextureUsages::COPY_SRC,
        view_formats: &[],
    });
    let texture_view = texture.create_view(&Default::default());

    let buffer_size = (4 * opts.size * opts.size) as wgpu::BufferAddress;
    let readback = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("readback"),
        size: buffer_size,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    // GPU timestamp query set
    let queries = device.create_query_set(&wgpu::QuerySetDescriptor {
        ty: wgpu::QueryType::Timestamp,
        count: 2,
        label: Some("timestamps"),
    });

    // --- encode commands ---------------------------------------------------
    let mut encoder = device.create_command_encoder(
        &wgpu::CommandEncoderDescriptor { label: None });

    encoder.write_timestamp(&queries, 0);

    {
        let mut pass =
            encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: None,
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view              : &texture_view,
                    resolve_target    : None,
                    ops: wgpu::Operations {
                        load : wgpu::LoadOp::Clear(wgpu::Color::BLACK),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                occlusion_query_set: None,
                timestamp_writes: None,
            });
        pass.set_pipeline(&render_pipeline);
        // Bind uniform buffer at @group(0) for shader access to resolution
        pass.set_bind_group(0, bind_group, &[]);
        pass.draw(0..3, 0..1); // full-screen triangle
    }

    encoder.write_timestamp(&queries, 1);

    // copy query → resolve buffer
    let query_resolve_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("query_resolve_buffer"),
        size : 16,
        usage: wgpu::BufferUsages::QUERY_RESOLVE | wgpu::BufferUsages::COPY_SRC,
        mapped_at_creation: false,
    });
    let query_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("query_buffer"),
        size : 16,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });
    encoder.resolve_query_set(&queries, 0..2, &query_resolve_buffer, 0);
    encoder.copy_buffer_to_buffer(&query_resolve_buffer, 0, &query_buffer, 0, 16);

    // copy texture → readback buffer
    encoder.copy_texture_to_buffer(
        wgpu::ImageCopyTexture {
            texture: &texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        wgpu::ImageCopyBuffer {
            buffer: &readback,
            layout: wgpu::ImageDataLayout {
                offset           : 0,
                bytes_per_row    : Some(4 * opts.size),
                rows_per_image   : Some(opts.size),
            },
        },
        extent,
    );

    // submit & wait
    queue.submit(Some(encoder.finish()));
    device.poll(wgpu::Maintain::Wait);

    // --- pull results ------------------------------------------------------
    // GPU time
    let timestamps = pollster::block_on(async {
        let buffer_slice = query_buffer.slice(..);
        let (sender, receiver) = futures_intrusive::channel::shared::oneshot_channel();
        buffer_slice.map_async(wgpu::MapMode::Read, move |v| sender.send(v).unwrap());
        device.poll(wgpu::Maintain::wait()).panic_on_timeout();
        receiver.receive().await.unwrap().unwrap();

        let data = buffer_slice.get_mapped_range();
        let ts: &[u64] = bytemuck::cast_slice(&data);
        let period = queue.get_timestamp_period();
        let nanos = if ts.len() >= 2 && ts[1] >= ts[0] {
            (ts[1] - ts[0]) as f64 * period as f64
        } else {
            0.0
        };
        nanos / 1_000_000.0 // ms
    });

    // image
    pollster::block_on(async {
        let buffer_slice = readback.slice(..);
        let (sender, receiver) = futures_intrusive::channel::shared::oneshot_channel();
        buffer_slice.map_async(wgpu::MapMode::Read, move |v| sender.send(v).unwrap());
        device.poll(wgpu::Maintain::wait()).panic_on_timeout();
        receiver.receive().await.unwrap().unwrap();
    });
    let img_data = readback.slice(..).get_mapped_range();
    let png = image::RgbaImage::from_raw(
        opts.size, opts.size, img_data.to_vec()
    ).expect("size mismatch");
    png.save(&opts.output).expect("png save failed");

    let cpu_ms = now.elapsed().as_secs_f64() * 1e3;
    println!("GPU {:.3} ms   | CPU {:.3} ms   | wrote {:?}",
             timestamps, cpu_ms, opts.output);
}
