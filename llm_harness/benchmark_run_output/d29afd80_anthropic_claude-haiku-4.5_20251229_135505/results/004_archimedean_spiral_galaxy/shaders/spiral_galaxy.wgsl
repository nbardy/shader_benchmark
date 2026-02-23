// ============================================================================
// SPIRAL GALAXY RENDERER - Archimedean Two-Arm Galaxy
// ============================================================================
// Renders a face-on two-arm spiral galaxy with ~120,000 stars.
// Uses procedural noise + seeding to generate consistent star field.
// 
// Spiral: r = a*θ, a=0.25, θ ∈ [0, 8π], two arms offset by π
// Stars: Archimedean spiral arms + Gaussian offsets (tangential & radial)
// Background: 10,000 disc-halo stars with density p(r) ∝ r*exp(-r/3)
// Colors: Black-body temperature T(r) = 7200 - 250*r K → sRGB
// Brightness: exp(-0.5*r), rendered as Gaussian sprites (FWHM = 0.03 + 0.004*r)
// ============================================================================

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

// ============================================================================
// PSEUDORANDOM NUMBER GENERATOR (Xorshift64)
// ============================================================================
fn hash_seed(seed: u32) -> u32 {
    var s = seed;
    s = s ^ (s << 13u);
    s = s ^ (s >> 7u);
    s = s ^ (s << 17u);
    return s;
}

fn xorshift64_step(state: ptr<function, u64>) -> f32 {
    var x = (*state);
    x = x ^ (x << 13u);
    x = x ^ (x >> 7u);
    x = x ^ (x << 17u);
    (*state) = x;
    return f32((x >> 8u) & 0xFFFFFFu) / 16777216.0;
}

// Box-Muller transform: generate two independent Gaussians
fn gaussian_pair(state: ptr<function, u64>) -> vec2<f32> {
    let u1 = xorshift64_step(state);
    let u2 = xorshift64_step(state);
    let r = sqrt(-2.0 * log(u1 + 1e-6));
    let theta = 6.283185307 * u2;
    return r * vec2<f32>(cos(theta), sin(theta));
}

// ============================================================================
// BLACK-BODY TO sRGB CONVERSION
// Planck's law approximation for color temperature T(K) → sRGB
// ============================================================================
fn temperature_to_srgb(temp_K: f32) -> vec3<f32> {
    let T = clamp(temp_K, 1000.0, 12000.0);
    let t = T / 1000.0;
    
    // CIE 1931 chromaticity approximation (simplified)
    var x = 0.0;
    var y = 0.0;
    
    if (t <= 6.6) {
        x = 0.3366 + 0.00476 * t;
        y = 0.1735 + (-0.0699) * t + 0.01464 * t * t;
    } else {
        x = 0.3356 - 0.00195 * (t - 6.6);
        y = 0.1691 + (-0.00287) * (t - 6.6);
    }
    
    let X = x / y;
    let Z = (1.0 - x - y) / y;
    
    // XYZ to RGB (linear)
    let r_lin = clamp(3.2406 * X - 1.5372 - 0.4986 * Z, 0.0, 1.0);
    let g_lin = clamp(-0.9689 * X + 1.8758 + 0.0415 * Z, 0.0, 1.0);
    let b_lin = clamp(0.0557 * X - 0.2040 - 1.0570 * Z, 0.0, 1.0);
    
    // sRGB gamma correction
    let r_srgb = select(12.92 * r_lin, 1.055 * pow(r_lin, 1.0 / 2.4) - 0.055, r_lin > 0.0031308);
    let g_srgb = select(12.92 * g_lin, 1.055 * pow(g_lin, 1.0 / 2.4) - 0.055, g_lin > 0.0031308);
    let b_srgb = select(12.92 * b_lin, 1.055 * pow(b_lin, 1.0 / 2.4) - 0.055, b_lin > 0.0031308);
    
    return clamp(vec3<f32>(r_srgb, g_srgb, b_srgb), 0.0, 1.0);
}

// ============================================================================
// STAR GENERATION & SAMPLING
// ============================================================================

// Archimedean spiral arm position
fn spiral_arm_center(theta: f32) -> vec2<f32> {
    let a = 0.25;
    let r = a * theta;
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

// Generate spiral arm star at index i
fn sample_spiral_star(i: u32) -> vec4<f32> {
    let i_f = f32(i);
    let seed0 = hash_seed(i + 10000u);
    var state = (u64(seed0) << 32u) | u64(hash_seed(seed0));
    
    // Uniform θ sampling: θ ∈ [0, 8π]
    let u_theta = xorshift64_step(&state);
    let theta = 8.0 * 3.141592654 * u_theta;
    
    // Arm center
    let center = spiral_arm_center(theta);
    
    // Tangential Gaussian offset: Δθ ~ N(0, σ_θ²), σ_θ = 0.035
    let sigma_theta = 0.035;
    let gauss_pair1 = gaussian_pair(&state);
    let delta_theta = sigma_theta * gauss_pair1.x;
    
    // Radial Gaussian offset: Δr ~ N(0, σ_r²), σ_r = 0.025*(1 + 0.5*θ)
    let sigma_r = 0.025 * (1.0 + 0.5 * theta / 8.0);
    let delta_r = sigma_r * gauss_pair1.y;
    
    // Perturbed polar coordinates
    let r_pert = length(center) + delta_r;
    let theta_pert = atan2(center.y, center.x) + delta_theta;
    let pos = vec2<f32>(r_pert * cos(theta_pert), r_pert * sin(theta_pert));
    
    // Radial density falloff: keep if u < exp(-r/3)
    let u_weight = xorshift64_step(&state);
    let weight = exp(-r_pert / 3.0);
    let keep = u_weight < weight;
    
    // Return: [x, y, r_pert, valid (as f32)]
    return vec4<f32>(pos.x, pos.y, r_pert, select(0.0, 1.0, keep));
}

// Generate background (disc-halo) star at index i
fn sample_halo_star(i: u32) -> vec4<f32> {
    let seed0 = hash_seed(i + 150000u);
    var state = (u64(seed0) << 32u) | u64(hash_seed(seed0));
    
    // Radial distribution: p(r) ∝ r * exp(-r/3), r_max = 10
    // Use rejection sampling with envelope u ~ U(0, 1), r ~ U(0, 10)
    var r = 0.0;
    var accepted = false;
    
    for (var attempt = 0u; attempt < 10u; attempt = attempt + 1u) {
        let u = xorshift64_step(&state);
        let r_cand = 10.0 * xorshift64_step(&state);
        let p_r = r_cand * exp(-r_cand / 3.0);
        let p_max = 1.5 * exp(-1.5); // approx envelope max
        
        if (u < p_r / p_max) {
            r = r_cand;
            accepted = true;
            break;
        }
    }
    
    // If rejection sampling failed, fallback
    if (!accepted) {
        r = 10.0 * xorshift64_step(&state);
    }
    
    // Angle uniform
    let angle = 6.283185307 * xorshift64_step(&state);
    let pos = vec2<f32>(r * cos(angle), r * sin(angle));
    
    // Return: [x, y, r, 1.0 (always valid)]
    return vec4<f32>(pos.x, pos.y, r, 1.0);
}

// ============================================================================
// STAR RENDERING
// ============================================================================

// Compute star brightness
fn star_brightness(r: f32) -> f32 {
    return exp(-0.5 * r);
}

// Compute star FWHM (Full Width Half Max)
fn star_fwhm(r: f32) -> f32 {
    return 0.03 + 0.004 * r;
}

// Gaussian profile for star sprite
fn gaussian_sprite(dist: f32, fwhm: f32) -> f32 {
    let sigma = fwhm / 2.355; // FWHM to sigma
    return exp(-0.5 * (dist / sigma) * (dist / sigma));
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to [-10, +10] in x & y (orthographic view, r ≤ 10)
    let pixel_uv = pos.xy / params.resolution;
    let uv = (pixel_uv - 0.5) * 2.0; // [-1, 1]
    let aspect = params.resolution.x / params.resolution.y;
    let world_x = uv.x * 10.0 * aspect;
    let world_y = uv.y * 10.0;
    let world_pos = vec2<f32>(world_x, world_y);
    
    var accum_color = vec3<f32>(0.0, 0.0, 0.0);
    
    // ========================================================================
    // SPIRAL ARM STARS (~120,000)
    // ========================================================================
    let num_spiral_stars = 120000u;
    for (var i = 0u; i < num_spiral_stars; i = i + 1u) {
        let star = sample_spiral_star(i);
        if (star.w < 0.5) {
            continue; // rejected by density falloff
        }
        
        let star_pos = star.xy;
        let r = star.z;
        
        // Distance from pixel to star
        let star_dist = distance(world_pos, star_pos);
        
        // Star color via black-body temperature
        let temp_K = 7200.0 - 250.0 * r;
        let star_color = temperature_to_srgb(temp_K);
        
        // Star brightness & sprite
        let brightness = star_brightness(r);
        let fwhm = star_fwhm(r);
        let sprite = gaussian_sprite(star_dist, fwhm);
        
        // Accumulate
        accum_color = accum_color + brightness * star_color * sprite * 0.0001;
    }
    
    // ========================================================================
    // DISC-HALO STARS (~10,000)
    // ========================================================================
    let num_halo_stars = 10000u;
    for (var i = 0u; i < num_halo_stars; i = i + 1u) {
        let star = sample_halo_star(i);
        let star_pos = star.xy;
        let r = star.z;
        
        // Distance from pixel to star
        let star_dist = distance(world_pos, star_pos);
        
        // Halo stars: small white dots
        let star_color = vec3<f32>(1.0, 1.0, 1.0);
        let brightness = 0.3 * exp(-0.5 * r);
        let fwhm = 0.01 + 0.002 * r;
        let sprite = gaussian_sprite(star_dist, fwhm);
        
        // Accumulate
        accum_color = accum_color + brightness * star_color * sprite * 0.00005;
    }
    
    // ========================================================================
    // SUPERNOVA CORE GLOW
    // ========================================================================
    let core_glow_radius = 0.4;
    let core_dist = length(world_pos);
    let core_bloom = exp(-0.5 * (core_dist / core_glow_radius) * (core_dist / core_glow_radius));
    let core_color = vec3<f32>(1.0, 1.0, 0.666); // #ffffaa
    accum_color = accum_color + core_bloom * core_color * 0.6;
    
    // ========================================================================
    // TONE MAPPING & OUTPUT
    // ========================================================================
    let final_color = clamp(accum_color, 0.0, 1.0);
    
    return vec4<f32>(final_color, 1.0);
}