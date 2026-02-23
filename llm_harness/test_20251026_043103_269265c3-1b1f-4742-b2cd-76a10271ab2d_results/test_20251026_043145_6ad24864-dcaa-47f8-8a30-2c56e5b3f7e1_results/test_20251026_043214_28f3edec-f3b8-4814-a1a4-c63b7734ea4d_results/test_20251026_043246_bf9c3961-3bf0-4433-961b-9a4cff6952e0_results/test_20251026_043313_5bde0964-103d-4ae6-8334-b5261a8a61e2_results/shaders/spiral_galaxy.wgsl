// Two-arm Archimedean spiral galaxy renderer
// Specification: a=0.25, θ∈[0,8π], 120k spiral stars + 10k halo stars
// Star colors via black-body radiation, Gaussian sprites with FWHM scaling

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

// Pseudo-random number generator (PCG-like)
fn hash1(seed: u32) -> f32 {
    var x = seed;
    x = ((x >> u32(16)) ^ x) * u32(0x7feb352d);
    x = ((x >> u32(15)) ^ x) * u32(0x846ca68b);
    x = (x >> u32(16)) ^ x;
    return f32(x) / 4294967295.0;
}

fn hash2(seed: u32) -> vec2<f32> {
    return vec2<f32>(hash1(seed), hash1(seed ^ u32(0x12345678)));
}

// Box-Muller transform for Gaussian sampling
fn gaussianPair(seed: u32) -> vec2<f32> {
    let u = hash2(seed);
    let r = sqrt(-2.0 * log(max(u.x, 1e-6)));
    let theta = 6.283185307179586 * u.y;
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

// Single Gaussian sample
fn gaussian(seed: u32, sigma: f32) -> f32 {
    return gaussianPair(seed).x * sigma;
}

// Kelvin to sRGB via black-body approximation
fn kelvintosRGB(kelvin: f32) -> vec3<f32> {
    let k = clamp(kelvin, 1000.0, 15000.0) / 100.0;
    
    var r = 1.0;
    var g = 1.0;
    var b = 1.0;
    
    if (k <= 66.0) {
        r = 1.0;
        g = (99.4743696951 * log(k)) - 161.1195681661;
        g = clamp(g / 255.0, 0.0, 1.0);
        b = select(0.0, (138.5177312231 * log(k - 10.0)) - 305.0447927307, k >= 20.0);
        b = clamp(b / 255.0, 0.0, 1.0);
    } else {
        r = (329.698676031 * pow(k - 60.0, -0.1332047592)) / 255.0;
        r = clamp(r, 0.0, 1.0);
        g = (288.1221695283 * pow(k - 60.0, -0.0755148492)) / 255.0;
        g = clamp(g, 0.0, 1.0);
        b = 1.0;
    }
    
    return vec3<f32>(r, g, b);
}

// 2D Gaussian sprite intensity
fn gaussianSprite(dist: f32, fwhm: f32) -> f32 {
    let sigma = fwhm / 2.354820045;
    let sigma2 = sigma * sigma;
    return exp(-0.5 * dist * dist / sigma2);
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to [-10, 10] square (orthographic view, r ≤ 10)
    let uv = (pos.xy - params.resolution * 0.5) / (params.resolution.y * 0.05);
    let pixelRadius = length(uv);
    
    var color = vec3<f32>(0.0, 0.0, 0.0);
    
    // =========== SPIRAL ARM STARS (120,000 samples) ===========
    let spiralSamples = 120000u;
    let a = 0.25;
    
    for (var i = 0u; i < spiralSamples; i = i + 1u) {
        let thetaNorm = f32(i) / f32(spiralSamples);
        let theta = thetaNorm * 8.0 * 3.141592653589793;
        
        let arm = select(0u, 1u, i % 2u);
        let thetaArm = theta + f32(arm) * 3.141592653589793;
        
        let r_center = a * thetaArm;
        
        if (r_center > 10.0) { continue; }
        
        let delta_theta = gaussian(i * 73u, 0.035);
        
        let sigma_r = 0.025 * (1.0 + 0.5 * thetaArm);
        let delta_r = gaussian(i * 137u, sigma_r);
        
        let r = r_center + delta_r;
        let theta_pert = thetaArm + delta_theta;
        let star_pos = vec2<f32>(r * cos(theta_pert), r * sin(theta_pert));
        
        let weight = exp(-r / 3.0);
        let rand_keep = hash1(i * 251u);
        if (rand_keep > weight) { continue; }
        
        let temp = 7200.0 - 250.0 * r;
        let star_color = kelvintosRGB(temp);
        let brightness = exp(-0.5 * r);
        
        let fwhm = 0.03 + 0.004 * r;
        
        let dist_to_star = length(uv - star_pos);
        let sprite_intensity = gaussianSprite(dist_to_star, fwhm);
        
        color = color + star_color * brightness * sprite_intensity;
    }
    
    // =========== HALO STARS (10,000 samples) ===========
    let haloPsamples = 10000u;
    
    for (var j = 0u; j < haloPsamples; j = j + 1u) {
        let u_r = hash1(j * 313u);
        let u_theta = hash1(j * 401u);
        
        let r_test = u_r * 10.0;
        let p_r = r_test * exp(-r_test / 3.0);
        let accept_prob = p_r / 10.0;
        
        if (hash1(j * 509u) > accept_prob) { continue; }
        
        let halo_theta = u_theta * 6.283185307179586;
        let halo_pos = vec2<f32>(r_test * cos(halo_theta), r_test * sin(halo_theta));
        
        let halo_color = vec3<f32>(1.0, 1.0, 1.0);
        let halo_fwhm = 0.015;
        let dist_to_halo = length(uv - halo_pos);
        let halo_sprite = gaussianSprite(dist_to_halo, halo_fwhm);
        
        color = color + halo_color * halo_sprite * 0.3;
    }
    
    // =========== CORE GLOW BLOOM ===========
    let core_radius = 0.4;
    let dist_to_core = length(uv);
    let core_bloom = smoothstep(core_radius, 0.0, dist_to_core);
    let core_color = vec3<f32>(1.0, 1.0, 0.667);
    
    color = color + core_color * core_bloom * 0.6;
    
    // =========== TONE MAPPING & OUTPUT ===========
    color = color / (color + vec3<f32>(1.0));
    color = pow(color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(color, 1.0);
}