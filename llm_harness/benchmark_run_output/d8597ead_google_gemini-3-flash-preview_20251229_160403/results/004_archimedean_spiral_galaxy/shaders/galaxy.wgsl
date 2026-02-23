struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// Pseudo-random generator (PCG-like)
fn hash(p_in: u32) -> u32 {
    var p = p_in;
    p = p ^ (p >> 16u);
    p = p * 0x45d9f3bu;
    p = p ^ (p >> 16u);
    p = p * 0x45d9f3bu;
    p = p ^ (p >> 16u);
    return p;
}

fn float_hash(p: u32) -> f32 {
    return f32(hash(p)) / 4294967295.0;
}

// Simple blackbody approximation for color temperature
fn temperature_to_rgb(temp: f32) -> vec3<f32> {
    let t = temp / 100.0;
    var r: f32;
    var g: f32;
    var b: f32;

    if (t <= 66.0) {
        r = 1.0;
        g = clamp(-155.25485562709179 + 3.115908094672322 * t + 0.44596950469579133 * log(t), 0.0, 1.0);
        if (t <= 19.0) {
            b = 0.0;
        } else {
            b = clamp(-254.76935184120902 + 0.8274096064007395 * t + 0.11595058307405 * log(t - 10.0), 0.0, 1.0);
        }
    } else {
        r = clamp(351.97690566805693 + 0.11420645049733 * (t - 60.0) - 40.25366309332127 * log(t - 60.0), 0.0, 1.0);
        g = clamp(325.4494125711974 + 0.079434565366623 * (t - 60.0) - 28.0852963507957 * log(t - 60.0), 0.0, 1.0);
        b = 1.0;
    }
    return vec3<f32>(r, g, b);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Orthographic view: Map screen [0, res] to galaxy space [-10, 10]
    let uv = (pos.xy / params.resolution) * 20.0 - vec2<f32>(10.0);
    let r_pixel = length(uv);
    
    var color = vec3<f32>(0.0, 0.0, 0.0);

    // 1. Core bloom (Supernova-like)
    let core_radius = 0.4;
    let core_dist = r_pixel / core_radius;
    let bloom = exp(-core_dist * core_dist * 4.0) * 0.6;
    color = color + vec3<f32>(1.0, 1.0, 0.66) * bloom;

    // 2. Galaxy arms and stars
    // Note: To render stars efficiently in a fragment shader without a vertex buffer,
    // we use a technique of dividing space into a grid to check nearby sampled stars.
    // However, for this contract, we'll model the continuous distribution density.
    
    let a = 0.25;
    let angle_pixel = atan2(uv.y, uv.x);
    
    // Check multiple turns for spiral intersection
    for (var turn = 0.0; turn < 4.0; turn = turn + 1.0) {
        // Arm 1
        let theta1 = (angle_pixel < 0.0) ? (angle_pixel + 6.28318 * (turn + 1.0)) : (angle_pixel + 6.28318 * turn);
        let r_arm1 = a * theta1;
        
        // Arm 2 (offset by PI)
        let theta2 = theta1 + 3.14159;
        let r_arm2 = a * (theta1 + 3.14159);

        let dist1 = abs(r_pixel - r_arm1);
        let dist2 = abs(r_pixel - r_arm2);
        
        // Dynamic sigma based on radius
        let sigma_r = 0.025 * (1.0 + 0.5 * theta1);
        
        // Density calculation
        let weight = exp(-r_pixel / 3.0);
        let lum = exp(-0.5 * r_pixel);
        
        let star_temp = 7200.0 - 250.0 * r_pixel;
        let star_rgb = temperature_to_rgb(star_temp);
        
        let peak1 = exp(-(dist1 * dist1) / (2.0 * sigma_r * sigma_r));
        let peak2 = exp(-(dist2 * dist2) / (2.0 * sigma_r * sigma_r));
        
        color = color + star_rgb * (peak1 + peak2) * weight * lum * 0.15;
    }

    // 3. Disk/Halo background (Statistical approximation of 10,000 dots)
    // We use a high-frequency hash to simulate discrete stars
    let seed = u32(pos.x) + u32(pos.y) * 3000u;
    let h = float_hash(seed);
    let disk_density = (r_pixel * exp(-r_pixel / 3.0)) * 0.05;
    if (h < disk_density && r_pixel < 10.0) {
        color = color + vec3<f32>(0.8, 0.8, 1.0) * 0.4;
    }

    // Tonemapping/clamping
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(color, 1.0);
}