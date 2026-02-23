@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

fn hash11(p: f32) -> f32 {
    let x = fract(p * 0.1031);
    let y = x * (x + 33.33);
    let z = y * (x + x);
    return fract(z);
}

fn hash22(p: vec2<f32>) -> vec2<f32> {
    var p3 = fract(vec3<f32>(p.xyx) * vec3<f32>(0.1031, 0.1030, 0.0973));
    p3 = p3 + dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

fn get_blackbody(temp: f32) -> vec3<f32> {
    let t = temp / 100.0;
    var r: f32;
    var g: f32;
    var b: f32;

    if (t <= 66.0) {
        r = 1.0;
        g = clamp(0.39 * log(t) - 0.16, 0.0, 1.0);
        b = select(0.0, clamp(0.54 * log(t - 10.0) - 0.70, 0.0, 1.0), t > 10.0);
    } else {
        r = clamp(1.29 * pow(t - 60.0, -0.13), 0.0, 1.0);
        g = clamp(1.12 * pow(t - 60.0, -0.075), 0.0, 1.0);
        b = 1.0;
    }
    return vec3<f32>(r, g, b);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / (params.resolution.y / 20.0);
    let r_pixel = length(uv);
    let theta_pixel = atan2(uv.y, uv.x);
    
    var color = vec3<f32>(0.0, 0.0, 0.0);

    // 1. Core Bloom (Supernova-like)
    let core_dist = length(uv);
    let core_glow = 0.6 * exp(-core_dist / 0.15);
    color = color + core_glow * vec3<f32>(1.0, 1.0, 0.66);

    // 2. Spiral Arms (Simulated via coordinate-based density estimation)
    // To represent 120,000 stars in a fragment shader, we use a statistical density field
    let a = 0.25;
    let pi = 3.14159265;
    
    for (var i: i32 = 0; i < 2; i = i + 1) {
        let arm_offset = f32(i) * pi;
        
        // Find the theta along the arm closest to the current radius r = a * theta
        let theta_arm = r_pixel / a;
        
        if (theta_arm <= 8.0 * pi) {
            let arm_angle = (theta_arm + arm_offset) % (2.0 * pi);
            let pixel_angle = (theta_pixel + 2.0 * pi) % (2.0 * pi);
            
            var diff = abs(pixel_angle - arm_angle);
            diff = min(diff, 2.0 * pi - diff);
            
            // Variances from spec
            let sigma_theta = 0.035;
            let sigma_r = 0.025 * (1.0 + 0.5 * theta_arm);
            
            // Convert tangential spread sigma_theta to radial equivalent at r
            let sigma_total = sqrt(pow(sigma_theta * r_pixel, 2.0) + pow(sigma_r, 2.0));
            
            // Normalized radial falloff weight
            let weight = exp(-r_pixel / 3.0);
            
            // Gaussian sprite approximation density
            let fwhm = 0.03 + 0.004 * r_pixel;
            let sigma_star = fwhm / 2.355;
            
            // Calculate star contribution
            let dist_to_arm = diff * r_pixel;
            let density = exp(-0.5 * pow(dist_to_arm / (sigma_total + 0.1), 2.0)) * weight;
            
            // Color temperature T(r) = 7200 - 250r
            let temp = max(1000.0, 7200.0 - 250.0 * r_pixel);
            let star_col = get_blackbody(temp);
            let brightness = exp(-0.5 * r_pixel);
            
            color = color + star_col * density * brightness * 0.4;
        }
    }

    // 3. Background Disc-Halo Stars
    // Using a hash-based jittered grid to simulate 10,000 points
    let grid_size = 64.0;
    let g_uv = uv * grid_size;
    let g_id = floor(g_uv);
    let g_f = fract(g_uv);
    
    let noise = hash22(g_id);
    let r_star = length(g_id / grid_size * 10.0);
    
    // Probability p(r) ~ r * exp(-r/3)
    let prob = (r_star / 3.0) * exp(-r_star / 3.0);
    if (noise.x < prob && r_star < 10.0) {
        let star_pos = noise;
        let dist_to_point = length(g_f - star_pos);
        let star_glow = smoothstep(0.1, 0.0, dist_to_point);
        color = color + vec3<f32>(star_glow * 0.5);
    }

    // Output with subtle tone mapping
    return vec4<f32>(pow(color, vec3<f32>(1.0 / 2.2)), 1.0);
}