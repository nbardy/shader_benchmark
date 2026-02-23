// Complex Analysis Stained Glass Window
// f(z) = (z² - 1)/(z² + 1) with domain coloring as illuminated glass

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
fn complex_mul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn complex_div(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = b.x * b.x + b.y * b.y;
    return vec2<f32>(
        (a.x * b.x + a.y * b.y) / denom,
        (a.y * b.x - a.x * b.y) / denom
    );
}

fn complex_magnitude(z: vec2<f32>) -> f32 {
    return sqrt(z.x * z.x + z.y * z.y);
}

fn complex_arg(z: vec2<f32>) -> f32 {
    return atan2(z.y, z.x);
}

// Main function: f(z) = (z² - 1)/(z² + 1)
fn eval_function(z: vec2<f32>) -> vec2<f32> {
    let z_sq = complex_mul(z, z);
    let numerator = vec2<f32>(z_sq.x - 1.0, z_sq.y);
    let denominator = vec2<f32>(z_sq.x + 1.0, z_sq.y);
    return complex_div(numerator, denominator);
}

// Hue from complex argument (0..2π → 0..1)
fn arg_to_hue(arg: f32) -> f32 {
    return (arg + 3.14159265359) / (2.0 * 3.14159265359);
}

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let h_prime = (h * 6.0) % 6.0;
    let x = c * (1.0 - abs((h_prime % 2.0) - 1.0));
    
    var rgb_base = vec3<f32>(0.0);
    let h_int = u32(h_prime);
    
    if (h_int == 0u) {
        rgb_base = vec3<f32>(c, x, 0.0);
    } else if (h_int == 1u) {
        rgb_base = vec3<f32>(x, c, 0.0);
    } else if (h_int == 2u) {
        rgb_base = vec3<f32>(0.0, c, x);
    } else if (h_int == 3u) {
        rgb_base = vec3<f32>(0.0, x, c);
    } else if (h_int == 4u) {
        rgb_base = vec3<f32>(x, 0.0, c);
    } else {
        rgb_base = vec3<f32>(c, 0.0, x);
    }
    
    let m = v - c;
    return rgb_base + vec3<f32>(m);
}

// Lead came generation at |f(z)| = 2^n contours
fn is_lead_came(mag: f32) -> f32 {
    let log_mag = log2(mag + 0.001);
    let frac = fract(log_mag);
    let distance_to_contour = min(frac, 1.0 - frac);
    return smoothstep(0.08, 0.02, distance_to_contour);
}

// Stained glass opacity based on magnitude (dark = transparent)
fn magnitude_to_opacity(mag: f32) -> f32 {
    let log_mag = log2(mag + 0.1);
    let clamped = clamp(log_mag * 0.3 + 0.5, 0.0, 1.0);
    return clamped;
}

// Add subtle glass imperfections and bubble effects near singularities
fn glass_imperfection(z: vec2<f32>, dist_to_sing: f32) -> f32 {
    let bubble_intensity = exp(-dist_to_sing * dist_to_sing * 2.0);
    let wobble = sin(z.x * 8.0) * cos(z.y * 8.0) * 0.1;
    return wobble * bubble_intensity;
}

// Distance to nearest pole (z = ±i)
fn distance_to_poles(z: vec2<f32>) -> f32 {
    let pole_i = vec2<f32>(0.0, 1.0);
    let pole_neg_i = vec2<f32>(0.0, -1.0);
    let dist_i = distance(z, pole_i);
    let dist_neg_i = distance(z, pole_neg_i);
    return min(dist_i, dist_neg_i);
}

// Rose window pattern for poles (radial symmetry)
fn rose_window(z: vec2<f32>, petals: f32) -> f32 {
    let angle = atan2(z.y, z.x);
    let radius = length(z);
    let petal_pattern = cos(angle * petals) * 0.5 + 0.5;
    let spiral = sin(radius * 10.0 - angle * 2.0);
    return petal_pattern * spiral;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to complex plane: [-2, 2] × [-2, 2]
    let uv = (pos.xy - params.resolution * 0.5) / (params.resolution * 0.25);
    let z = vec2<f32>(uv.x, uv.y);
    
    // Evaluate function
    let f_z = eval_function(z);
    
    // Domain coloring: magnitude and argument
    let mag = complex_magnitude(f_z);
    let arg = complex_arg(f_z);
    
    // Hue from argument
    let hue = arg_to_hue(arg);
    
    // Opacity from magnitude (log scale for stained glass effect)
    let opacity = magnitude_to_opacity(mag);
    
    // Base glass color (HSV with high saturation)
    let glass_color = hsv_to_rgb(hue, 0.85, opacity);
    
    // Lead came contours at powers of 2
    let lead = is_lead_came(mag);
    
    // Glass imperfections near poles
    let dist_poles = distance_to_poles(z);
    let imperfect = glass_imperfection(z, dist_poles);
    
    // Rose window at poles (6 petals)
    let rose = rose_window(z, 6.0);
    let rose_glow = exp(-dist_poles * 3.0) * abs(rose) * 0.3;
    
    // Combine: glass + lead + rose window
    let final_color = mix(
        glass_color,
        vec3<f32>(0.2, 0.15, 0.1),
        lead
    );
    
    // Add rose window glow
    let with_rose = final_color + vec3<f32>(0.3, 0.2, 0.5) * rose_glow;
    
    // Darken edges for cathedral frame effect
    let edge_vignette = length(uv) / 4.0;
    let vignette = 1.0 - smoothstep(0.5, 1.5, edge_vignette);
    
    // Add subtle caustic patterns from light rays
    let caustic = sin(z.x * 5.0 + z.y * 3.0) * cos(z.x * 3.0 - z.y * 5.0) * 0.15;
    
    // Final composition
    let illuminated = with_rose * (0.7 + caustic) * vignette + 0.15;
    
    // Ensure values don't exceed f32 limits
    let clamped = clamp(illuminated, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(clamped, 1.0);
}