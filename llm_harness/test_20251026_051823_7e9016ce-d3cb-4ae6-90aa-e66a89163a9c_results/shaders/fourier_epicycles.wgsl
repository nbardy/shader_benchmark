// Fourier Epicycles Visualization
// Decomposes paths into rotating circles (epicycles) using Fourier analysis
// Visualizes multiple shapes with interactive frequency component control

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
    num_epicycles: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Complex number operations (represented as vec2<f32> where x=real, y=imag)
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cexp(phase: f32) -> vec2<f32> {
    return vec2<f32>(cos(phase), sin(phase));
}

// Precomputed Fourier coefficients for different shapes
fn get_fourier_coeff(shape: u32, n: i32) -> vec2<f32> {
    let abs_n = abs(n);
    
    // Square wave: alternating 1, 0, 1/3, 0, 1/5, ...
    if (shape == 0u) {
        if (n == 0) {
            return vec2<f32>(0.5, 0.0);
        }
        if (abs_n % 2u == 1u) {
            let coeff = 1.0 / (3.14159 * f32(abs_n));
            return vec2<f32>(coeff, 0.0);
        }
        return vec2<f32>(0.0, 0.0);
    }
    
    // Heart shape (simplified Fourier approximation)
    if (shape == 1u) {
        switch(abs_n) {
            case 1u: { return vec2<f32>(0.45, 0.0); }
            case 2u: { return vec2<f32>(0.15, 0.25); }
            case 3u: { return vec2<f32>(0.1, 0.0); }
            case 4u: { return vec2<f32>(0.08, -0.12); }
            case 5u: { return vec2<f32>(0.06, 0.0); }
            case 6u: { return vec2<f32>(0.05, 0.08); }
            case 7u: { return vec2<f32>(0.04, 0.0); }
            case 8u: { return vec2<f32>(0.03, -0.05); }
            default: { return vec2<f32>(0.0, 0.0); }
        }
    }
    
    // Figure-8 pattern (lemniscate-like)
    if (shape == 2u) {
        switch(abs_n) {
            case 1u: { return vec2<f32>(0.5, 0.0); }
            case 2u: { return vec2<f32>(0.2, 0.3); }
            case 3u: { return vec2<f32>(0.1, 0.0); }
            case 4u: { return vec2<f32>(0.08, -0.15); }
            case 5u: { return vec2<f32>(0.06, 0.0); }
            case 6u: { return vec2<f32>(0.04, 0.1); }
            case 7u: { return vec2<f32>(0.03, 0.0); }
            case 8u: { return vec2<f32>(0.02, -0.06); }
            default: { return vec2<f32>(0.0, 0.0); }
        }
    }
    
    // Circle (single frequency)
    if (shape == 3u) {
        if (abs_n == 1u) {
            return vec2<f32>(0.3, 0.0);
        }
        return vec2<f32>(0.0, 0.0);
    }
    
    return vec2<f32>(0.0, 0.0);
}

// Compute epicycle position for given shape and time
fn compute_epicycle_position(shape: u32, t: f32, max_freq: i32) -> vec2<f32> {
    var pos = vec2<f32>(0.0, 0.0);
    
    // Sum contributions from each frequency component
    for (var n: i32 = 1 - max_freq; n <= max_freq; n = n + 1) {
        let coeff = get_fourier_coeff(shape, n);
        
        // Skip if coefficient is negligible
        if (length(coeff) < 0.001) {
            continue;
        }
        
        let phase = f32(n) * t;
        let rotation = cexp(phase);
        let contribution = cmul(coeff, rotation);
        pos = pos + contribution;
    }
    
    return pos;
}

// Calculate distance from point to line segment
fn line_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Hash function for deterministic colors
fn hash(val: f32) -> vec3<f32> {
    let x = sin(val * 12.9898) * 43758.5453;
    let frac_x = fract(x);
    let y = sin(val * 78.233 + 1.0) * 43758.5453;
    let frac_y = fract(y);
    let z = sin(val * 45.164 + 2.0) * 43758.5453;
    let frac_z = fract(z);
    return vec3<f32>(frac_x, frac_y, frac_z);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Determine which shape to display based on time
    let shape_cycle = f32(u32(params.time * 0.3) % 4u);
    
    // Animation time
    let t = params.time * 0.5;
    
    // Number of epicycles to compute (clamped)
    let num_cycles = i32(clamp(params.num_epicycles, 1.0, 20.0));
    
    // Compute current position on the curve
    let current_pos = compute_epicycle_position(u32(shape_cycle), t, num_cycles);
    
    // Distance to current position (drawn as bright dot)
    let dist_to_current = length(uv - current_pos);
    
    // Trail effect: show previous positions
    var min_trail_dist = 10.0;
    for (var i: i32 = 0; i < 30; i = i + 1) {
        let trail_time = t - f32(i) * 0.05;
        let trail_pos = compute_epicycle_position(u32(shape_cycle), trail_time, num_cycles);
        let trail_dist = line_distance(uv, trail_pos, current_pos);
        min_trail_dist = min(min_trail_dist, trail_dist);
    }
    
    // Draw epicycles (circles connecting to build the curve)
    var min_circle_dist = 10.0;
    var circle_color = vec3<f32>(0.0, 0.0, 0.0);
    
    // Draw each epicycle circle
    for (var n: i32 = 1; n <= num_cycles; n = n + 1) {
        let coeff = get_fourier_coeff(u32(shape_cycle), n);
        
        if (length(coeff) < 0.001) {
            continue;
        }
        
        let phase = f32(n) * t;
        let rotation = cexp(phase);
        let radius_vec = cmul(coeff, rotation);
        let radius = length(coeff);
        let center = compute_epicycle_position(u32(shape_cycle), t, n - 1);
        
        // Distance to circle perimeter
        let dist_to_circle = abs(length(uv - center) - radius);
        
        if (dist_to_circle < min_circle_dist) {
            min_circle_dist = dist_to_circle;
            circle_color = hash(f32(n) * 0.7);
        }
    }
    
    // Color composition
    var color = vec3<f32>(0.05, 0.05, 0.08); // Dark background
    
    // Trail (cyan)
    let trail_width = 0.003;
    if (min_trail_dist < trail_width) {
        color = mix(color, vec3<f32>(0.2, 0.8, 0.9), 1.0 - min_trail_dist / trail_width);
    }
    
    // Epicycle circles (colored by frequency)
    let circle_width = 0.002;
    if (min_circle_dist < circle_width) {
        color = mix(color, circle_color, 0.7);
    }
    
    // Current position (bright white/yellow)
    let current_width = 0.01;
    if (dist_to_current < current_width) {
        color = mix(color, vec3<f32>(1.0, 0.95, 0.3), 1.0 - dist_to_current / current_width);
    }
    
    // Add subtle grid for reference
    let grid_size = 0.1;
    let grid_x = step(0.95, fract(uv.x / grid_size));
    let grid_y = step(0.95, fract(uv.y / grid_size));
    let grid = (grid_x + grid_y) * 0.15;
    color = color + grid * vec3<f32>(0.2, 0.2, 0.25);
    
    return vec4<f32>(color, 1.0);
}