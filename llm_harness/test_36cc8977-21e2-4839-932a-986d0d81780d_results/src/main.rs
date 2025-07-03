use clap::Parser;
use std::{borrow::Cow, fs, path::PathBuf, time::Instant};

/// Render a WGSL shader off-screen, save PNG + timings.
#[derive(Parser)]
struct Opts {
    /// WGSL shader file (expects `@vertex main_vs` & `@fragment main_fs`)
    #[arg(short, long)]
    shader: PathBuf,
    /// PNG file to write
    #[arg(short, long, default_value = "hopf.png")]
    output: PathBuf,
    /// Width & height in pixels
    #[arg(short = 's', long, default_value_t = 1600)]
    size: u32,
}

fn main() {
    // --- parse CLI ---------------------------------------------------------
    let opts = Opts::parse();
    let code = fs::read_to_string(&opts.shader)
        .expect("failed to read WGSL file");

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
        source: wgpu::ShaderSource::Wgsl(Cow::Owned(code)),
    });

    // vertex buffer
    let vertex_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("vertex_buffer"),
        contents: &[],
        usage: wgpu::BufferUsages::VERTEX,
    });

    let pipeline_layout =
        device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            bind_group_layouts: &[],
            push_constant_ranges: &[],
            label: None,
        });

    let render_pipeline =
        device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "main_vs",
                buffers: &[wgpu::VertexBufferLayout {
                    array_stride: std::mem::size_of::<VertexOut>() as wgpu::BufferAddress,
                    step_mode: wgpu::VertexStepMode::Vertex,
                    attributes: &wgpu::vertex_attr_array_vec![0 => Float32x4, 1 => Float32x3],
                }],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "main_fs",
                targets: &[Some(wgpu::ColorTargetState {
                    format: wgpu::TextureFormat::Rgba8UnormSrgb,
                    blend: None,
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState {
                topology: wgpu::PrimitiveTopology::LineList,
                strip_index_format: None,
                front_face: wgpu::FrontFace::Ccw,
                cull_mode: Some(wgpu::Face::Back),
                ..Default::default()
            },
            depth_stencil: None,
            multisample: wgpu::MultisampleState::default(),
            multiview: None,
        });

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
                        load : wgpu::LoadOp::Clear(wgpu::Color::WHITE),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                occlusion_query_set: None,
                timestamp_writes: None,
            });
        pass.set_pipeline(&render_pipeline);
        pass.set_vertex_buffer(0, vertex_buffer.slice(..));
        pass.draw(0..6000, 0..1);
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
        let nanos = (ts[1] - ts[0]) as f64 * period as f64;
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

#[repr(C)]
#[derive(Copy, Clone, Debug, bytemuck::Pod, bytemuck::Zeroable)]
struct VertexOut {
    position: [f32; 4],
    color: [f32; 3],
}

unsafe impl bytemuck::DataAddress for VertexOut {
    fn address() -> u64 {
        std::ptr::addr_of!(position) as _ - std::ptr::addr_of!(self) as _
    }
}