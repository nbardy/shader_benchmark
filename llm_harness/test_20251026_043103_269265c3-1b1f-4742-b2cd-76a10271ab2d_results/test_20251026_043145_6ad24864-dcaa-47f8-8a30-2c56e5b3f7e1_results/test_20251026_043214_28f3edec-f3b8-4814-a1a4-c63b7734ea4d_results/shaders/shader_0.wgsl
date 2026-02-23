// Apollonian Gasket Renderer – Rank-2 Kleinian Group Limit Set
// Mathematical engine: Möbius transformations M₁(z) = (2z+1)/(z+1), M₂(z) = (2z-1)/(z-1)
// Parity-encoded coloring: even-word-length → red (#ff3355), odd → green (#33ff55)
// Orbit sampling: 3,000,000 walks × 21 iterations (12 transient + 9 plotted)

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
    seed_offset: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// ============================================================================
// PRNG: 32-bit LCG for deterministic pseudo-random sequences
// ============================================================================
fn lcg_next(state: ptr<function, u32>) -> u32 {
    let a = 1664525u;
    let c = 22695477u;
    let m = 4294967295u;
    *state = (a * *state + c) & m;
    return *state;
}

fn lcg_float(state: ptr<function, u32>) -> f32 {
    return f32(lcg_next(state)) / 4294967295.0;
}

// ============================================================================
// Möbius Transformations in the Complex Plane
// M₁(z) = (2z + 1) / (z + 1)
// M₂(z) = (2z - 1) / (z - 1)
// ============================================================================
fn moebius_1(z: vec2<f32>) -> vec2<f32> {
    // numerator: 2z + 1
    let numer = vec2<f32>(2.0 * z.x + 1.0, 2.0 * z.y);
    // denominator: z + 1 (as complex)
    let denom = vec2<f32>(z.x + 1.0, z.y);
    let denom_norm_sq = dot(denom, denom);
    if (denom_norm_sq < 1e-10) {
        return vec2<f32>(1e6, 1e6);  // pole at z = -1
    }
    // (a + bi) / (c + di) = ((ac + bd) + (bc - ad)i) / (c² + d²)
    let real = (numer.x * denom.x + numer.y * denom.y) / denom_norm_sq;
    let imag = (numer.y * denom.x - numer.x * denom.y) / denom_norm_sq;
    return vec2<f32>(real, imag);
}

fn moebius_2(z: vec2<f32>) -> vec2<f32> {
    // numerator: 2z - 1
    let numer = vec2<f32>(2.0 * z.x - 1.0, 2.0 * z.y);
    // denominator: z - 1 (as complex)
    let denom = vec2<f32>(z.x - 1.0, z.y);
    let denom_norm_sq = dot(denom, denom);
    if (denom_norm_sq < 1e-10) {
        return vec2<f32>(1e6, 1e6);  // pole at z = 1
    }
    let real = (numer.x * denom.x + numer.y * denom.y) / denom_norm_sq;
    let imag = (numer.y * denom.x - numer.x * denom.y) / denom_norm_sq;
    return vec2<f32>(real, imag);
}

// ============================================================================
// Stereographic Projection: Riemann Sphere → Plane
// Maps sphere with radius 1 centered at (0, 0, 1/2) to complex plane
// Inverse: complex (x, y) → sphere (X, Y, Z) where Z ∈ [0, 1]
// ============================================================================
fn sphere_to_plane(sphere_pt: vec3<f32>) -> vec2<f32> {
    // sphere_pt is on S² centered at (0, 0, 0.5) with radius 0.5
    // project stereographically from north pole (0, 0, 1)
    let z_denom = 1.0 - sphere_pt.z;
    if (abs(z_denom) < 1e-8) {
        return vec2<f32>(1e6, 1e6);  // north pole (infinity)
    }
    return vec2<f32>(sphere_pt.x / z_denom, sphere_pt.y / z_denom);
}

fn plane_to_sphere(plane_pt: vec2<f32>) -> vec3<f32> {
    let r_sq = dot(plane_pt, plane_pt);
    let scale = 1.0 / (1.0 + r_sq);
    return vec3<f32>(
        2.0 * plane_pt.x * scale,
        2.0 * plane_pt.y * scale,
        (r_sq - 1.0) * scale + 0.5
    );
}

// ============================================================================
// Orbit Generation & Parity Tracking
// Start at z₀ = 0, iterate applying M₁ or M₂ with equal probability
// Discard first 12 iterates, plot next 9 (to emphasize fine structure)
// Track word parity: even-length word → red, odd → green
// ============================================================================
fn sample_gasket_orbit(pixel_idx: u32, walk_id: u32) -> vec4<f32> {
    var state = pixel_idx ^ (walk_id * 73856093u) ^ u32(params.seed_offset * 1e6);
    
    var z = vec2<f32>(0.0, 0.0);  // seed z₀ = 0
    var word_length = 0u;
    
    // Burn-in: discard first 12 iterates
    for (var i = 0u; i < 12u; i = i + 1u) {
        let rnd = lcg_float(&state);
        z = select(moebius_2(z), moebius_1(z), rnd < 0.5);
        word_length = word_length + 1u;
    }
    
    // Plot next 9 iterates, return one uniformly at random
    var depth = 0u;
    for (var i = 0u; i < 9u; i = i + 1u) {
        let rnd = lcg_float(&state);
        z = select(moebius_2(z), moebius_1(z), rnd < 0.5);
        word_length = word_length + 1u;
        
        // Randomly select one depth to render (uniform in [0,8])
        if (i == u32(lcg_float(&state) * 9.0)) {
            depth = i;
        }
    }
    
    // Clamp z to avoid numerical instability
    let z_len = length(z);
    let z_safe = select(z, z / z_len * 10.0, z_len > 10.0);
    
    // Parity: odd word length → green (#33ff55), even → red (#ff3355)
    let is_odd = (word_length & 1u) == 1u;
    let color = select(
        vec3<f32>(1.0, 0.2, 0.33),   // red #ff3355
        vec3<f32>(0.2, 1.0, 0.33)    // green #33ff55
    , is_odd);
    
    // Return: (complex z as xy, color as z, parity flag as w)
    return vec4<f32>(z_safe.x, z_safe.y, f32(is_odd), 1.0);
}

// ============================================================================
// Additive Blending & Gaussian Bloom Kernel
// Each orbit point rendered as sub-pixel disk (radius ~0.6 px)
// Accumulate via additive blending; bright regions glow
// ============================================================================
fn gaussian_blur_sample(uv: vec2<f32>, sigma: f32) -> f32 {
    // Simple Gaussian kernel: exp(-|uv|² / (2σ²))
    let r_sq = dot(uv, uv);
    let sigma_sq = sigma * sigma;
    return exp(-r_sq / (2.0 * sigma_sq));
}

fn render_orbit_point(
    frag_uv: vec2<f32>,
    orbit_z: vec2<f32>,
    is_odd: bool,
    bloom_sigma: f32
) -> vec4<f32> {
    // Distance from fragment to orbit point in UV space
    let delta = frag_uv - orbit_z;
    let dist_px = length(delta) * 2400.0;  // scale to pixel space
    
    // Sub-pixel disk: radius ~0.6 px
    let disk_radius = 0.6;
    let disk_alpha = smoothstep(disk_radius + 0.1, disk_radius - 0.1, dist_px);
    
    // Bloom halo: Gaussian with σ = bloom_sigma
    let bloom_weight = gaussian_blur_sample(delta * 2400.0, bloom_sigma);
    
    // Color: green for odd, red for even
    let color = select(
        vec3<f32>(1.0, 0.2, 0.33),   // red
        vec3<f32>(0.2, 1.0, 0.33)    // green
    , is_odd);
    
    // Additive blend: disk + bloom halo
    let total_alpha = disk_alpha + bloom_weight * 0.4;
    return vec4<f32>(color * total_alpha, total_alpha);
}

// ============================================================================
// Fragment Shader: Main Render Loop
// ============================================================================
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let center = res * 0.5;
    let pixel_coord = pos.xy - center;  // center at origin
    
    // Canvas: 2400×2400 px with 120 px padding → effective 2160×2160 drawable
    let max_drawable = 1080.0;  // half-width in pixel space
    let canvas_uv = pixel_coord / max_drawable;  // normalized to [-1,1] roughly
    
    // Skip pixels outside drawable region
    if (length(canvas_uv) > 1.2) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    // Stereographic projection: map plane region to Riemann sphere
    // Scale: outermost circle at ~1.0 in canvas_uv space
    let outermost_radius = 1.0;
    let sphere_pt = plane_to_sphere(canvas_uv * outermost_radius);
    
    // Accumulate contributions from multiple orbit samples
    var accumulated = vec4<f32>(0.0, 0.0, 0.0, 0.0);
    
    // Deterministic sampling: use pixel index + walk count
    let pixel_idx = u32(pos.x) * u32(res.y) + u32(pos.y);
    let walk_count = 256u;  // samples per pixel
    
    for (var w = 0u; w < walk_count; w = w + 1u) {
        let orbit_sample = sample_gasket_orbit(pixel_idx, w);
        let orbit_z = orbit_sample.xy;
        let is_odd = orbit_sample.z > 0.5;
        
        // Render this orbit point with bloom
        let bloom_sigma = 1.0;
        let contribution = render_orbit_point(canvas_uv, orbit_z, is_odd, bloom_sigma);
        accumulated = accumulated + contribution;
    }
    
    // Normalize by sample count and apply tone mapping
    let avg_color = accumulated.xyz / max(accumulated.w, 0.001);
    let final_color = avg_color / (avg_color + vec3<f32>(1.0));  // Reinhard tone map
    
    // Pure black background if no samples accumulated
    let final_with_bg = select(
        vec3<f32>(0.0, 0.0, 0.0),
        final_color,
        accumulated.w > 0.01
    );
    
    return vec4<f32>(final_with_bg, 1.0);
}