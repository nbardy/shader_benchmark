// Chladni Pattern Visualization - WGSL Implementation
// Physics: u(x,y,t) = A * sin(n*π*x/L) * sin(m*π*y/L) * cos(ω*t)
// Mode: (n,m) = (4,3), L = 2.0, evaluated at t=0 (maximum displacement)

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

fn chladni_amplitude(x: f32, y: f32) -> f32 {
    let pi = 3.14159265359;
    let n = 4.0;
    let m = 3.0;
    let L = 2.0;
    
    let term_x = sin(n * pi * x / L);
    let term_y = sin(m * pi * y / L);
    let amplitude = term_x * term_y;
    
    return amplitude;
}

fn get_color(amplitude: f32) -> vec3<f32> {
    let nodal_threshold = 0.01;
    let abs_amp = abs(amplitude);
    
    // Nodal lines - sandy beige
    if abs_amp < nodal_threshold {
        return vec3<f32>(0.831, 0.647, 0.455); // #D4A574
    }
    
    // Positive displacement - blue gradient
    if amplitude > 0.0 {
        let normalized = min(amplitude / 1.0, 1.0);
        let blue_dark = vec3<f32>(0.0, 0.4, 0.8);      // #0066CC
        let blue_light = vec3<f32>(0.0, 0.8, 1.0);     // #00CCFF
        return mix(blue_dark, blue_light, normalized);
    }
    
    // Negative displacement - red gradient
    let normalized = min(abs_amp / 1.0, 1.0);
    let red_dark = vec3<f32>(0.8, 0.0, 0.0);           // #CC0000
    let red_light = vec3<f32>(1.0, 0.4, 0.4);          // #FF6666
    return mix(red_dark, red_light, normalized);
}

fn is_in_plate_border(uv: vec2<f32>, border_width: f32) -> f32 {
    let border = 0.05;
    let edge_x = step(1.0 - border, abs(uv.x));
    let edge_y = step(1.0 - border, abs(uv.y));
    return max(edge_x, edge_y);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to [-1, 1] domain
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    
    // Compute Chladni amplitude at this point
    let amplitude = chladni_amplitude(uv.x, uv.y);
    
    // Get color based on amplitude
    var color = get_color(amplitude);
    
    // Check if in plate boundary region and apply border
    let border_alpha = is_in_plate_border(uv, 0.05);
    color = mix(color, vec3<f32>(0.0, 0.0, 0.0), border_alpha);
    
    // Background outside plate
    let outside_plate = step(1.0, abs(uv.x)) + step(1.0, abs(uv.y));
    let bg_color = vec3<f32>(0.961, 0.961, 0.863); // #F5F5DC beige
    color = mix(color, bg_color, outside_plate);
    
    // Add subtle height-based shading
    let height_shade = 0.9 + 0.1 * amplitude;
    color = color * height_shade;
    
    // Add soft shadow effect based on distance from nodal lines
    let nodal_threshold = 0.01;
    let abs_amp = abs(amplitude);
    let shadow_dist = smoothstep(0.0, 0.15, abs_amp - nodal_threshold);
    color = color * mix(0.85, 1.0, shadow_dist);
    
    return vec4<f32>(color, 1.0);
}