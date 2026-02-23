// Ramanujan Mock-Theta Heat-Disk Shader
// Visualization of f(q) = 1 + Σ(n=1 to 50) q^(n²) / [(1+q)²(1+q²)²...(1+q^n)²]
// on polar grid: q(t,θ) = e^(-t) * e^(iθ), t ∈ [0,2], θ ∈ [0,2π]

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

// Complex number operations
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cadd(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return a + b;
}

fn cabs(a: vec2<f32>) -> f32 {
    return length(a);
}

fn cpow(z: vec2<f32>, n: i32) -> vec2<f32> {
    var result = vec2<f32>(1.0, 0.0);
    var base = z;
    var exp = n;
    
    loop {
        if (exp <= 0) { break; }
        if ((exp & 1) == 1) {
            result = cmul(result, base);
        }
        base = cmul(base, base);
        exp = exp >> 1;
    }
    return result;
}

// Ramanujan mock-theta function approximation
fn ramanujan_mock_theta(q: vec2<f32>) -> vec2<f32> {
    var sum = vec2<f32>(1.0, 0.0);
    var q_power = q;  // q^1
    
    for (var n: i32 = 1; n <= 50; n = n + 1) {
        // Compute q^(n²)
        let n_squared = n * n;
        var q_n_sq = vec2<f32>(1.0, 0.0);
        for (var k: i32 = 0; k < n_squared; k = k + 1) {
            q_n_sq = cmul(q_n_sq, q);
        }
        
        // Compute denominator: (1+q)²(1+q²)²...(1+q^n)²
        var denom = vec2<f32>(1.0, 0.0);
        var q_k_power = q;
        
        for (var k: i32 = 1; k <= n; k = k + 1) {
            let factor = cadd(vec2<f32>(1.0, 0.0), q_k_power);
            denom = cmul(denom, factor);
            denom = cmul(denom, factor);
            q_k_power = cmul(q_k_power, q);
        }
        
        // Avoid division by zero
        let denom_mag = cabs(denom);
        if (denom_mag > 1e-6) {
            let numerator = q_n_sq;
            let inv_denom = vec2<f32>(denom.x / (denom_mag * denom_mag), -denom.y / (denom_mag * denom_mag));
            let term = cmul(numerator, inv_denom);
            sum = cadd(sum, term);
        }
    }
    
    return sum;
}

// Magma colormap (perceptual palette)
fn magma_palette(t: f32) -> vec3<f32> {
    let t_clamped = clamp(t, 0.0, 1.0);
    
    // Magma palette: deep purple → dark red → orange-yellow → white
    // Key points: [0, 0.3, 0.6, 1.0]
    var color = vec3<f32>(0.0);
    
    if (t_clamped < 0.25) {
        // Deep purple to dark red
        let s = t_clamped / 0.25;
        color = mix(vec3<f32>(0.001, 0.0, 0.014), vec3<f32>(0.2, 0.01, 0.14), s);
    } else if (t_clamped < 0.5) {
        // Dark red to brown-red
        let s = (t_clamped - 0.25) / 0.25;
        color = mix(vec3<f32>(0.2, 0.01, 0.14), vec3<f32>(0.4, 0.08, 0.1), s);
    } else if (t_clamped < 0.75) {
        // Brown-red to orange
        let s = (t_clamped - 0.5) / 0.25;
        color = mix(vec3<f32>(0.4, 0.08, 0.1), vec3<f32>(0.8, 0.4, 0.05), s);
    } else {
        // Orange to yellow-white
        let s = (t_clamped - 0.75) / 0.25;
        color = mix(vec3<f32>(0.8, 0.4, 0.05), vec3<f32>(0.99, 0.99, 0.85), s);
    }
    
    return color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let center = resolution * 0.5;
    let pixel = pos.xy - center;
    
    // Convert to polar coordinates
    let radius = length(pixel);
    let angle = atan2(pixel.y, pixel.x);
    
    // Map radius to t ∈ [0, 2]
    // Outer edge (radius = resolution.x/2) corresponds to t = 2
    let max_radius = resolution.x * 0.5;
    let t = clamp((radius / max_radius) * 2.0, 0.0, 2.0);
    
    // q(t, θ) = e^(-t) * e^(iθ)
    let exp_neg_t = exp(-t);
    let q = vec2<f32>(exp_neg_t * cos(angle), exp_neg_t * sin(angle));
    
    // Compute Ramanujan mock-theta function
    let f_q = ramanujan_mock_theta(q);
    let magnitude = cabs(f_q);
    
    // Map magnitude to palette index
    // |f| = 1 → index 0.15, |f| = 2.3 → index 0.85
    let palette_index = mix(0.15, 0.85, clamp((magnitude - 1.0) / 1.3, 0.0, 1.0));
    
    // Get color from magma palette
    var base_color = magma_palette(palette_index);
    
    // Add concentric gold rings at t = 0.5, 1.0, 1.5
    let ring_positions = array<f32, 3>(0.5, 1.0, 1.5);
    var ring_glow = 0.0;
    
    for (var i: u32 = 0u; i < 3u; i = i + 1u) {
        let ring_t = ring_positions[i];
        let ring_radius = (ring_t / 2.0) * max_radius;
        let dist_to_ring = abs(radius - ring_radius);
        let ring_width = 0.02 * max_radius;
        ring_glow = ring_glow + exp(-dist_to_ring * dist_to_ring / (ring_width * ring_width)) * 0.15;
    }
    
    // Add gold ring color
    let gold = vec3<f32>(0.95, 0.85, 0.2);
    base_color = mix(base_color, gold, ring_glow);
    
    // Fade to black outside annulus
    let fade = smoothstep(max_radius + 10.0, max_radius - 5.0, radius);
    let final_color = base_color * fade;
    
    return vec4<f32>(final_color, 1.0);
}