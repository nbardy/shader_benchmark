@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    resolution: vec2<f32>,
};

// Random number generation using hash functions
fn hash(p: vec2<f32>) -> f32 {
    var p3 = fract(vec3<f32>(p.xyx) * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn hash2(p: vec2<f32>) -> vec2<f32> {
    let k = vec2<f32>(0.3183099, 0.3678794);
    var p2 = p;
    p2 = p2 * k + k.yx;
    return -1.0 + 2.0 * fract(16.0 * k * fract(p2.x * p2.y * (p2.x + p2.y)));
}

// Box-Muller transform for Gaussian distribution
fn gaussian_random(seed: vec2<f32>) -> vec2<f32> {
    let u1 = hash(seed);
    let u2 = hash(seed + vec2<f32>(127.1, 311.7));
    let r = sqrt(-2.0 * log(max(0.0001, u1)));
    let theta = 2.0 * 3.14159265359 * u2;
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

// Black-body color approximation
fn blackbody_to_rgb(temperature: f32) -> vec3<f32> {
    let temp = clamp(temperature, 1000.0, 12000.0) / 100.0;
    var r: f32;
    var g: f32;
    var b: f32;
    
    // Red
    if (temp <= 66.0) {
        r = 1.0;
    } else {
        r = 1.292936 * pow(temp - 60.0, -0.1332047592);
    }
    
    // Green
    if (temp <= 66.0) {
        g = 0.39008157 * log(temp) - 0.63184144;
    } else {
        g = 1.292936 * pow(temp - 60.0, -0.0755148492);
    }
    
    // Blue
    if (temp >= 66.0) {
        b = 1.0;
    } else if (temp >= 19.0) {
        b = 0.543206789 * log(temp - 10.0) - 1.19625408;
    } else {
        b = 0.0;
    }
    
    return clamp(vec3<f32>(r, g, b), vec3<f32>(0.0), vec3<f32>(1.0));
}

// Gaussian sprite rendering
fn gaussian_sprite(uv: vec2<f32>, center: vec2<f32>, fwhm: f32) -> f32 {
    let sigma = fwhm / 2.35482;
    let dist_sq = dot(uv - center, uv - center);
    return exp(-dist_sq / (2.0 * sigma * sigma));
}

// Sample a spiral arm star
fn sample_spiral_star(seed: f32, arm_offset: f32) -> vec3<f32> {
    let a = 0.25;
    let max_theta = 8.0 * 3.14159265359;
    
    // Uniform theta sampling
    let theta = hash(vec2<f32>(seed, 0.0)) * max_theta + arm_offset;
    
    // Compute arm center radius
    let r_center = a * theta;
    
    // Add Gaussian offsets
    let gaussian_offset = gaussian_random(vec2<f32>(seed, 1.0));
    let delta_theta = gaussian_offset.x * 0.035;
    let sigma_r = 0.025 * (1.0 + 0.5 * theta);
    let delta_r = gaussian_offset.y * sigma_r;
    
    // Final position
    let final_theta = theta + delta_theta;
    let final_r = max(0.0, r_center + delta_r);
    
    // Radial density fall-off
    let weight = exp(-final_r / 3.0);
    let keep = hash(vec2<f32>(seed, 2.0)) < weight;
    
    let x = final_r * cos(final_theta);
    let y = final_r * sin(final_theta);
    
    return vec3<f32>(x, y, select(0.0, 1.0, keep));
}

// Sample background disc-halo star
fn sample_halo_star(seed: f32) -> vec2<f32> {
    // Sample r from p(r) ∝ r * exp(-r/3)
    // Using rejection sampling
    var r: f32 = 0.0;
    var accepted = false;
    var iter = 0u;
    
    loop {
        if (iter > 10u) { break; }
        let u1 = hash(vec2<f32>(seed, f32(iter) * 10.0));
        let u2 = hash(vec2<f32>(seed, f32(iter) * 10.0 + 1.0));
        
        let r_test = u1 * 10.0;
        let pdf = r_test * exp(-r_test / 3.0);
        let max_pdf = 3.0 * exp(-1.0); // Maximum at r=3
        
        if (u2 * max_pdf < pdf) {
            r = r_test;
            accepted = true;
            break;
        }
        iter = iter + 1u;
    }
    
    if (!accepted) {
        r = 3.0; // Fallback
    }
    
    // Uniform angle
    let angle = hash(vec2<f32>(seed, 20.0)) * 2.0 * 3.14159265359;
    
    return vec2<f32>(r * cos(angle), r * sin(angle));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Convert to galaxy coordinates (range -10 to 10)
    let uv = (pos.xy - params.resolution * 0.5) / (params.resolution.y * 0.5) * 10.0;
    
    var color = vec3<f32>(0.0);
    
    // Render spiral arms
    let num_spiral_stars = 120000u;
    let stars_per_arm = num_spiral_stars / 2u;
    
    for (var i = 0u; i < 300u; i = i + 1u) {
        // Arm 1
        let star1 = sample_spiral_star(f32(i), 0.0);
        if (star1.z > 0.5) {
            let star_pos = star1.xy;
            let r = length(star_pos);
            let temperature = 7200.0 - 250.0 * r;
            let star_color = blackbody_to_rgb(temperature);
            let brightness = exp(-0.5 * r);
            let fwhm = 0.03 + 0.004 * r;
            let intensity = gaussian_sprite(uv, star_pos, fwhm) * brightness;
            color = color + star_color * intensity * 0.4;
        }
        
        // Arm 2 (offset by π)
        let star2 = sample_spiral_star(f32(i) + 60000.0, 3.14159265359);
        if (star2.z > 0.5) {
            let star_pos = star2.xy;
            let r = length(star_pos);
            let temperature = 7200.0 - 250.0 * r;
            let star_color = blackbody_to_rgb(temperature);
            let brightness = exp(-0.5 * r);
            let fwhm = 0.03 + 0.004 * r;
            let intensity = gaussian_sprite(uv, star_pos, fwhm) * brightness;
            color = color + star_color * intensity * 0.4;
        }
    }
    
    // Render background halo stars
    for (var i = 0u; i < 25u; i = i + 1u) {
        let star_pos = sample_halo_star(f32(i) + 120000.0);
        let dist = length(uv - star_pos);
        if (dist < 0.02) {
            let intensity = exp(-dist * dist * 2000.0);
            color = color + vec3<f32>(1.0) * intensity * 0.1;
        }
    }
    
    // Add supernova-like core glow
    let core_dist = length(uv);
    if (core_dist < 0.4) {
        let glow_intensity = exp(-core_dist * core_dist * 15.0) * 0.6;
        let glow_color = vec3<f32>(1.0, 1.0, 0.667); // #ffffaa
        color = color + glow_color * glow_intensity;
    }
    
    // Add overall galaxy glow
    let galaxy_glow = exp(-core_dist * 0.3) * 0.1;
    color = color + vec3<f32>(0.3, 0.3, 0.5) * galaxy_glow;
    
    // Tone mapping and gamma correction
    color = color / (1.0 + color); // Reinhard tone mapping
    color = pow(color, vec3<f32>(1.0 / 2.2)); // Gamma correction
    
    return vec4<f32>(color, 1.0);
}