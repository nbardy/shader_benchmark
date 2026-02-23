// Archimedean spiral galaxy renderer
// Two-arm spiral with Archimedean law: r = a*theta
// 120,000 spiral stars + 10,000 disk-halo stars
// Black-body color temperature mapping + Gaussian sprite rendering

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    time: f32,
    _pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Pseudo-random number generator (hash-based)
fn hash1(p: vec2<f32>) -> f32 {
    let q = vec2<f32>(
        dot(p, vec2<f32>(127.1, 311.7)),
        dot(p, vec2<f32>(269.5, 183.3))
    );
    return fract(sin(q) * 43758.5453);
}

fn hash2(p: vec2<f32>) -> vec2<f32> {
    let x = hash1(p);
    let y = hash1(p + vec2<f32>(1.0, 0.0));
    return vec2<f32>(x, y);
}

// Box-Muller transform for Gaussian sampling
fn gaussianRandom(seed: vec2<f32>) -> f32 {
    let u1 = hash1(seed);
    let u2 = hash1(seed + vec2<f32>(0.5, 0.5));
    let r = sqrt(-2.0 * log(max(u1, 1e-6)));
    let theta = 6.28318530718 * u2;
    return r * cos(theta);
}

// Black-body temperature to RGB (simplified Planck approximation)
fn tempToRGB(temp: f32) -> vec3<f32> {
    let t = temp / 1000.0;
    var r = 1.0;
    var g = 1.0;
    var b = 1.0;
    
    // Approximate black-body color curve
    if (t < 6.6) {
        r = 1.0;
        g = clamp(0.39465 * log(t) - 0.6358, 0.0, 1.0);
    } else {
        r = clamp(1.29293 - 0.18365 * log(t), 0.0, 1.0);
        g = clamp(0.90788 * log(t) - 5.861, 0.0, 1.0);
    }
    
    if (t > 6.6) {
        b = 1.0;
    } else {
        b = clamp(0.54320 * log(t) - 1.6456, 0.0, 1.0);
    }
    
    return vec3<f32>(r, g, b);
}

// Render a single Gaussian star sprite
fn starGaussian(
    pixel_pos: vec2<f32>,
    star_pos: vec2<f32>,
    fwhm: f32,
    color: vec3<f32>,
    brightness: f32
) -> vec3<f32> {
    let dx = pixel_pos - star_pos;
    let dist_sq = dot(dx, dx);
    let sigma = fwhm / 2.355;
    let sigma_sq = sigma * sigma;
    
    let gauss = exp(-dist_sq / (2.0 * sigma_sq));
    return color * brightness * gauss;
}

// Generate a spiral star at parameter theta
fn generateSpiralStar(
    theta: f32,
    arm_idx: i32,
    pixel_pos: vec2<f32>
) -> vec3<f32> {
    let a = 0.25;
    let r_center = a * theta;
    
    // Tangential spread (Gaussian)
    let seed_tang = vec2<f32>(theta, f32(arm_idx));
    let delta_theta = gaussianRandom(seed_tang + vec2<f32>(0.1, 0.2)) * 0.035;
    let theta_jittered = theta + delta_theta;
    
    // Radial spread with density scaling
    let seed_rad = vec2<f32>(theta, f32(arm_idx));
    let sigma_r = 0.025 * (1.0 + 0.5 * theta);
    let delta_r = gaussianRandom(seed_rad + vec2<f32>(0.3, 0.4)) * sigma_r;
    let r_actual = r_center + delta_r;
    
    // Radial density falloff acceptance
    let density_weight = exp(-r_actual / 3.0);
    let acceptance = hash1(seed_rad + vec2<f32>(0.7, 0.8));
    if (acceptance > density_weight) {
        return vec3<f32>(0.0);
    }
    
    // Compute star position in Cartesian coords
    let arm_offset = f32(arm_idx) * 3.14159265359;
    let angle = theta_jittered + arm_offset;
    let star_x = r_actual * cos(angle);
    let star_y = r_actual * sin(angle);
    let star_pos = vec2<f32>(star_x, star_y);
    
    // Convert pixel to galaxy coords (assuming 3000x3000 canvas, centered, [-10, 10])
    let scale_px_to_gal = 20.0 / params.resolution.x;
    let gal_pixel = (pixel_pos - params.resolution * 0.5) * scale_px_to_gal;
    
    // Color temperature based on radius
    let temp = 7200.0 - 250.0 * r_actual;
    let color = tempToRGB(clamp(temp, 1000.0, 10000.0));
    
    // Brightness with exponential falloff
    let brightness_base = exp(-0.5 * r_actual);
    let brightness = clamp(brightness_base, 0.0, 1.0);
    
    // Star size (FWHM)
    let fwhm = 0.03 + 0.004 * r_actual;
    
    // Render Gaussian sprite
    return starGaussian(gal_pixel, star_pos, fwhm, color, brightness);
}

// Generate a disk-halo star
fn generateHaloStar(
    idx: u32,
    pixel_pos: vec2<f32>
) -> vec3<f32> {
    let seed = vec2<f32>(f32(idx % 100u), f32(idx / 100u));
    
    // Radius: p(r) ∝ r * exp(-r/3) up to r=10
    // Use inverse transform: sample u ~ U(0,1), compute r
    let u_r = hash1(seed + vec2<f32>(0.1, 0.2));
    // Approximate inverse CDF: r ≈ -3*log(1-u) for this distribution
    let r = -3.0 * log(max(1e-6, 1.0 - u_r)) * 0.999; // scale to avoid r=10 boundary
    
    // Angle: uniform
    let u_angle = hash1(seed + vec2<f32>(0.3, 0.4));
    let angle = 6.28318530718 * u_angle;
    
    let star_x = r * cos(angle);
    let star_y = r * sin(angle);
    let star_pos = vec2<f32>(star_x, star_y);
    
    // Convert pixel to galaxy coords
    let scale_px_to_gal = 20.0 / params.resolution.x;
    let gal_pixel = (pixel_pos - params.resolution * 0.5) * scale_px_to_gal;
    
    // White halo stars
    let color = vec3<f32>(1.0, 1.0, 1.0);
    let brightness = 0.5;
    let fwhm = 0.02;
    
    return starGaussian(gal_pixel, star_pos, fwhm, color, brightness);
}

// Core supernova bloom
fn coreBloom(pixel_pos: vec2<f32>) -> vec3<f32> {
    let scale_px_to_gal = 20.0 / params.resolution.x;
    let gal_pixel = (pixel_pos - params.resolution * 0.5) * scale_px_to_gal;
    let dist_from_center = length(gal_pixel);
    
    let bloom_radius = 0.4;
    let bloom_color = vec3<f32>(1.0, 1.0, 0.667); // #ffffaa
    let bloom_opacity = 0.6;
    
    let bloom = bloom_opacity * exp(-dist_from_center * dist_from_center / (bloom_radius * bloom_radius));
    return bloom_color * bloom;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    var color = vec3<f32>(0.0); // black background
    
    // Sample spiral stars
    let num_theta_samples = 120u;
    let theta_step = 8.0 * 3.14159265359 / f32(num_theta_samples);
    
    var idx = 0u;
    loop {
        if (idx >= num_theta_samples) { break; }
        
        let theta = f32(idx) * theta_step;
        
        // Two arms
        var arm_contrib = vec3<f32>(0.0);
        arm_contrib = arm_contrib + generateSpiralStar(theta, 0, pos.xy);
        arm_contrib = arm_contrib + generateSpiralStar(theta, 1, pos.xy);
        
        color = color + arm_contrib / f32(num_theta_samples);
        idx = idx + 1u;
    }
    
    // Sample halo stars
    let num_halo_stars = 100u;
    var halo_idx = 0u;
    loop {
        if (halo_idx >= num_halo_stars) { break; }
        color = color + generateHaloStar(halo_idx * 100u, pos.xy) / f32(num_halo_stars);
        halo_idx = halo_idx + 1u;
    }
    
    // Add core bloom
    color = color + coreBloom(pos.xy);
    
    // Tone mapping and gamma correction
    let tone_mapped = color / (color + vec3<f32>(1.0));
    let gamma_corrected = pow(tone_mapped, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(gamma_corrected, 1.0);
}