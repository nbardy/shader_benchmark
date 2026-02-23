// Archimedean Two-Arm Spiral Galaxy Renderer
// Specification: 120,000 stars + 10,000 halo stars
// Orthographic view: r ≤ 10, resolution 3000×3000

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

// Pseudo-random generator (LCG)
fn rand_lcg(seed: ptr<function, u32>) -> f32 {
    *seed = (*seed * 1664525u + 1013904223u) & 0x7fffffffu;
    return f32(*seed) / 2147483647.0;
}

// Box-Muller Gaussian generator
fn gaussian(seed: ptr<function, u32>) -> f32 {
    let u1 = rand_lcg(seed);
    let u2 = rand_lcg(seed);
    let r = sqrt(-2.0 * log(max(u1, 0.0001)));
    let theta = 6.28318530718 * u2;
    return r * cos(theta);
}

// Blackbody to sRGB approximation
fn blackbody_srgb(temp_k: f32) -> vec3<f32> {
    let t = temp_k / 1000.0;
    
    var r = 1.0;
    var g = 1.0;
    var b = 1.0;
    
    if (t <= 66.0) {
        r = 1.0;
        g = (99.4743 + 123.68 * (t - 60.0)) / 255.0;
        g = clamp(g, 0.0, 1.0);
        b = if (t < 19.0) { 0.0 } else { (138.51 + 2.04 * (t - 16.4)) / 255.0 };
    } else {
        r = (329.698 - 60.0 * (t - 66.0)) / 255.0;
        r = clamp(r, 0.0, 1.0);
        g = (288.122 - 0.46 * (t - 55.0)) / 255.0;
        g = clamp(g, 0.0, 1.0);
        b = 1.0;
    }
    
    return vec3<f32>(r, g, b);
}

// Gaussian star sprite kernel
fn star_sprite(dist_px: f32, fwhm: f32) -> f32 {
    let sigma = fwhm / 2.355;
    return exp(-0.5 * (dist_px / sigma) * (dist_px / sigma));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let canvas_center = vec2<f32>(0.5, 0.5);
    let pixel_size = 20.0 / params.resolution.x; // r_max = 10, canvas half-width
    
    // Convert pixel coordinates to galaxy space [-10, 10]
    let canvas_coord = (uv - canvas_center) * 20.0;
    let px = canvas_coord.x;
    let py = canvas_coord.y;
    
    var color_acc = vec3<f32>(0.0);
    var seed: u32 = u32(pos.x * 73.856093 + pos.y * 19.34857 + 12.9898) & 0x7fffffffu;
    
    // ============================================================
    // Spiral Arm Stars (120,000)
    // ============================================================
    let spiral_a = 0.25;
    let sigma_theta = 0.035;
    let sigma_r_base = 0.025;
    let arm_decay = 1.0 / 3.0; // exp(-r/3) at r=1
    
    // Sample stars uniformly across theta and arms
    let num_spiral_stars = 120000u;
    var i: u32 = 0u;
    loop {
        if (i >= num_spiral_stars) { break; }
        
        // Deterministic seed per star
        var star_seed = (i * 73856093u) ^ (u32(pos.x) * 19349663u) ^ (u32(pos.y) * 83492791u);
        
        // Uniform theta: [0, 8π] = 4 full rotations
        let theta_frac = f32(i) / f32(num_spiral_stars);
        let theta = theta_frac * 8.0 * 3.14159265359;
        
        // Two arms: offset by π
        let arm_id = (i / (num_spiral_stars / 2u)) & 1u;
        let theta_arm = theta + f32(arm_id) * 3.14159265359;
        
        // Arm center
        let r_center = spiral_a * theta_arm;
        
        // Tangential blur (Gaussian offset in theta)
        let dtheta = gaussian(&star_seed) * sigma_theta;
        let theta_star = theta_arm + dtheta;
        
        // Radial blur (Gaussian, scaled with theta)
        let sigma_r = sigma_r_base * (1.0 + 0.5 * theta_arm);
        let dr = gaussian(&star_seed) * sigma_r;
        let r_star = r_center + dr;
        
        // Radial density fall-off: keep if u < exp(-r/3)
        let weight = exp(-r_star / 3.0);
        let u_accept = rand_lcg(&star_seed);
        
        if (u_accept < weight && r_star >= 0.0 && r_star <= 10.0) {
            // Convert polar to Cartesian
            let x_star = r_star * cos(theta_star);
            let y_star = r_star * sin(theta_star);
            
            // Distance from pixel to star center (in pixels)
            let star_x_px = (x_star - px) / pixel_size;
            let star_y_px = (y_star - py) / pixel_size;
            let dist_to_star = sqrt(star_x_px * star_x_px + star_y_px * star_y_px);
            
            // Star properties
            let temp = 7200.0 - 250.0 * r_star;
            let temp_clamp = clamp(temp, 3000.0, 10000.0);
            let star_color = blackbody_srgb(temp_clamp);
            
            let brightness = exp(-0.5 * r_star);
            let fwhm = 0.03 + 0.004 * r_star;
            let fwhm_px = fwhm / pixel_size;
            
            let sprite = star_sprite(dist_to_star, fwhm_px);
            color_acc = color_acc + star_color * brightness * sprite * 0.8;
        }
        
        i = i + 1u;
    }
    
    // ============================================================
    // Halo Stars (10,000) - background disc
    // ============================================================
    let num_halo_stars = 10000u;
    i = 0u;
    loop {
        if (i >= num_halo_stars) { break; }
        
        var halo_seed = (i * 13099223u) ^ (u32(pos.x) * 37612801u) ^ (u32(pos.y) * 74858541u);
        
        // Radial distribution: p(r) ∝ r*exp(-r/3)
        let u_r1 = rand_lcg(&halo_seed);
        let u_r2 = rand_lcg(&halo_seed);
        let r_halo = -3.0 * log(max(1.0 - u_r1 * 0.95, 0.01)); // invert exponential
        let r_halo_clamp = min(r_halo, 10.0);
        
        // Uniform angle
        let theta_halo = rand_lcg(&halo_seed) * 6.28318530718;
        
        let x_halo = r_halo_clamp * cos(theta_halo);
        let y_halo = r_halo_clamp * sin(theta_halo);
        
        // Distance from pixel
        let halo_x_px = (x_halo - px) / pixel_size;
        let halo_y_px = (y_halo - py) / pixel_size;
        let dist_to_halo = sqrt(halo_x_px * halo_x_px + halo_y_px * halo_y_px);
        
        // Halo stars: white, small, dim
        let halo_brightness = 0.2;
        let halo_fwhm_px = 2.0;
        let sprite_halo = star_sprite(dist_to_halo, halo_fwhm_px);
        
        color_acc = color_acc + vec3<f32>(1.0) * halo_brightness * sprite_halo * 0.3;
        
        i = i + 1u;
    }
    
    // ============================================================
    // Core Glow (Supernova bloom)
    // ============================================================
    let dist_to_core = sqrt((px * px) + (py * py));
    let core_radius = 0.4;
    let core_glow = exp(-dist_to_core / (core_radius * 0.3));
    color_acc = color_acc + vec3<f32>(1.0, 1.0, 0.67) * core_glow * 0.6;
    
    // ============================================================
    // Tone mapping & output
    // ============================================================
    let tone_mapped = color_acc / (1.0 + color_acc);
    let gamma = 1.0 / 2.2;
    let final_color = pow(tone_mapped, vec3<f32>(gamma));
    
    return vec4<f32>(final_color, 1.0);
}