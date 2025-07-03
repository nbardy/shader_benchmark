use clap::Parser;
use std::{borrow::Cow, fs, path::PathBuf, time::Instant};

/// Render a WGSL shader off-screen, save PNG + timings.
#[derive(Parser)]
struct Opts {
    /// WGSL shader file (expects `@vertex main_vs` & `@fragment main_fs`)
    #[arg(short, long)]
    shader: PathBuf,
    /// PNG file to write
    #[arg(short, long, default_value = "hyper_menger_sphere.png")]
    output: PathBuf,
    /// Width & height in pixels
    #[arg(short = 'z', long, default_value_t = 1600)]
    size: u32,
}

fn main() {
    // --- parse CLI ---------------------------------------------------------
    let opts = Opts::parse();
    let code = fs::read_to_string(&opts.shader)
        .expect("failed to read WGSL file");

    println!("Rendering 4D Hyper Menger Cube intersection with 3-sphere...");
    println!("Resolution: {}x{}", opts.size, opts.size);

    // --- init GPU ----------------------------------------------------------
    let now = Instant::now();
    let instance = wgpu::Instance::default();
    let adapter  = pollster::block_on(instance.request_adapter(
        &wgpu::RequestAdapterOptions {
            power_preference: wgpu::PowerPreference::HighPerformance,
            ..Default::default()
        },
    )).expect("No compatible GPU found. This visualization requires a modern GPU.");

    let (device, queue) = pollster::block_on(adapter.request_device(
        &wgpu::DeviceDescriptor {
            required_features: wgpu::Features::TIMESTAMP_QUERY | wgpu::Features::TIMESTAMP_QUERY_INSIDE_ENCODERS,
            required_limits  : wgpu::Limits::default(),
            label   : Some("4D Hyper Menger Device"),
        },
        None,
    )).expect("Device creation failed");

    // --- resources ---------------------------------------------------------
    let shader = device.create_shader_module(wgpu::ShaderModuleDescriptor {
        label: Some("hyper_menger_sphere_shader"),
        source: wgpu::ShaderSource::Wgsl(Cow::Owned(code)),
    });

    // full-screen triangle – no vertex buffer needed
    let pipeline_layout =
        device.create_pipeline_layout(&wgpu::PipelineLayoutDescriptor {
            bind_group_layouts: &[],
            push_constant_ranges: &[],
            label: Some("hyper_menger_layout"),
        });

    let render_pipeline =
        device.create_render_pipeline(&wgpu::RenderPipelineDescriptor {
            label: Some("hyper_menger_pipeline"),
            layout: Some(&pipeline_layout),
            vertex: wgpu::VertexState {
                module: &shader,
                entry_point: "main_vs",
                buffers: &[],
                compilation_options: Default::default(),
            },
            fragment: Some(wgpu::FragmentState {
                module: &shader,
                entry_point: "main_fs",
                targets: &[Some(wgpu::ColorTargetState {
                    format: wgpu::TextureFormat::Rgba8UnormSrgb,
                    blend: Some(wgpu::BlendState::ALPHA_BLENDING),
                    write_mask: wgpu::ColorWrites::ALL,
                })],
                compilation_options: Default::default(),
            }),
            primitive: wgpu::PrimitiveState::default(),
            depth_stencil: None,
            multisample: wgpu::MultisampleState {
                count: 4, // 4x MSAA for anti-aliasing
                mask: !0,
                alpha_to_coverage_enabled: false,
            },
            multiview: None,
        });

    // output texture with multisampling → buffer
    let extent = wgpu::Extent3d {
        width : opts.size,
        height: opts.size,
        depth_or_array_layers: 1,
    };
    
    // Multisampled texture for anti-aliasing
    let ms_texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("ms_output"),
        size: extent,
        mip_level_count: 1,
        sample_count: 4,
        dimension: wgpu::TextureDimension::D2,
        format: wgpu::TextureFormat::Rgba8UnormSrgb,
        usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
        view_formats: &[],
    });
    let ms_texture_view = ms_texture.create_view(&Default::default());
    
    // Resolve texture (single sample)
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
        &wgpu::CommandEncoderDescriptor { 
            label: Some("hyper_menger_encoder") 
        });

    encoder.write_timestamp(&queries, 0);

    {
        let mut pass =
            encoder.begin_render_pass(&wgpu::RenderPassDescriptor {
                label: Some("hyper_menger_render_pass"),
                color_attachments: &[Some(wgpu::RenderPassColorAttachment {
                    view              : &ms_texture_view,
                    resolve_target    : Some(&texture_view),
                    ops: wgpu::Operations {
                        load : wgpu::LoadOp::Clear(wgpu::Color {
                            r: 0.05, g: 0.28, b: 0.63, a: 1.0 // Deep space blue
                        }),
                        store: wgpu::StoreOp::Store,
                    },
                })],
                depth_stencil_attachment: None,
                occlusion_query_set: None,
                timestamp_writes: None,
            });
        pass.set_pipeline(&render_pipeline);
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
    println!("Executing GPU computation...");
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
    println!("Reading back image data...");
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
    ).expect("Image size mismatch");
    
    println!("Saving image...");
    png.save(&opts.output).expect("PNG save failed");

    let cpu_ms = now.elapsed().as_secs_f64() * 1e3;
    println!();
    println!("=== 4D Hyper Menger Sphere Intersection Complete ===");
    println!("GPU render time: {:.3} ms", timestamps);
    println!("Total CPU time:  {:.3} ms", cpu_ms);
    println!("Output written to: {:?}", opts.output);
    println!();
    println!("This visualization shows the intersection of:");
    println!("  • 4D Hyper Menger Cube (4 iterations)");
    println!("  • Unit 3-sphere in 4D space");
    println!("  • Stereographically projected to 3D");
    println!();
    println!("Color mapping:");
    println!("  • Purple: w ≈ -1.0 (south pole of 3-sphere)");
    println!("  • Orange: w ≈ 0.0 (equator of 3-sphere)");  
    println!("  • Yellow: w ≈ +1.0 (north pole of 3-sphere)");
}