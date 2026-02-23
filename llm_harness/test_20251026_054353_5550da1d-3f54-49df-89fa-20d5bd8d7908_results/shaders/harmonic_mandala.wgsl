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

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let center = resolution * 0.5;
    let coord = pos.xy - center;
    let aspect = resolution.x / resolution.y;
    
    // Normalize to [-1, 1] range
    let uv = coord / (resolution.y * 0.5);
    let uv_corrected = vec2<f32>(uv.x * aspect, uv.y);
    
    // Convert to polar coordinates
    let r_dist = length(uv_corrected);
    let theta = atan2(uv_corrected.y, uv_corrected.x);
    
    // Compute harmonic mandala radius function:
    // r(θ) = 1 + 0.15*sin(6θ) + 0.10*sin(12θ) + 0.06*sin(18θ)
    let r_mandala = 1.0 + 0.15 * sin(6.0 * theta) + 0.10 * sin(12.0 * theta) + 0.06 * sin(18.0 * theta);
    
    // Distance to curve (for outline)
    let curve_distance = abs(r_dist - r_mandala);
    
    // Fill interior with radial gradient (gamma 2.2)
    // Centre #001133 → edge #55ffee
    let fill_factor = clamp(r_dist / r_mandala, 0.0, 1.0);
    let fill_factor_gamma = pow(fill_factor, 1.0 / 2.2);
    
    let center_color = vec3<f32>(0.0, 0.067, 0.2);      // #001133
    let edge_color = vec3<f32>(0.333, 1.0, 0.933);      // #55ffee
    let interior = mix(center_color, edge_color, fill_factor_gamma);
    
    // Outline: white 3px (relative to canvas)
    let outline_width = 3.0 / resolution.y;
    let outline_alpha = 1.0 - smoothstep(0.0, outline_width, curve_distance);
    let outline_color = vec3<f32>(1.0, 1.0, 1.0);
    
    // Semi-transparent scaled duplicate (0.7x, #ff66cc, α=0.3)
    let r_inner = r_mandala * 0.7;
    let inner_distance = abs(r_dist - r_inner);
    let inner_alpha = (1.0 - smoothstep(0.0, outline_width, inner_distance)) * 0.3;
    let inner_color = vec3<f32>(1.0, 0.4, 0.8);          // #ff66cc
    
    // Determine if we're inside the main mandala
    let is_inside = r_dist < r_mandala;
    let is_inside_inner = r_dist < r_inner;
    
    // Composite: background (black) → interior → outline → inner semi-transparent
    var final_color = vec3<f32>(0.0, 0.0, 0.0);
    
    if (is_inside) {
        final_color = interior;
    }
    
    // Overlay outline
    if (outline_alpha > 0.0) {
        final_color = mix(final_color, outline_color, outline_alpha);
    }
    
    // Overlay inner semi-transparent
    if (is_inside_inner && inner_alpha > 0.0) {
        final_color = mix(final_color, inner_color, inner_alpha);
    }
    
    return vec4<f32>(final_color, 1.0);
}