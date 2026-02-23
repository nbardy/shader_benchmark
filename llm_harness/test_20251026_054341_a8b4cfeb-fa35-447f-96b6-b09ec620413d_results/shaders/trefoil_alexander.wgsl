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
    // Canvas setup
    let canvas_size = params.resolution;
    let center = canvas_size * 0.5;
    let max_radius = min(canvas_size.x, canvas_size.y) * 0.45;
    
    // Normalize to polar coordinates centered at image center
    let delta = pos.xy - center;
    let r_pixel = length(delta);
    let theta = atan2(delta.y, delta.x);
    
    // Background: midnight navy #040418
    var final_color = vec3<f32>(0.016, 0.016, 0.094);
    
    // Draw polar grid (behind curve)
    let grid_color = vec3<f32>(0.333, 0.333, 0.333);  // #555555
    var grid_intensity = 0.0;
    
    // Five concentric circles
    let circle_radii = array<f32, 5>(
        max_radius * 0.2,
        max_radius * 0.4,
        max_radius * 0.6,
        max_radius * 0.8,
        max_radius * 1.0
    );
    
    for (var i = 0u; i < 5u; i = i + 1u) {
        let circle_r = circle_radii[i];
        let circle_thickness = 1.2;
        let dist_to_circle = abs(r_pixel - circle_r);
        grid_intensity = max(grid_intensity, 1.0 - smoothstep(0.0, circle_thickness, dist_to_circle));
    }
    
    // 30° spokes (12 total)
    let spoke_step = 3.14159265359 / 6.0;
    let theta_normalized = (theta + 3.14159265359) % (2.0 * 3.14159265359);
    let dist_to_spoke = abs(theta_normalized % spoke_step - spoke_step * 0.5);
    let spoke_visibility = min(dist_to_spoke, 3.14159265359 - dist_to_spoke);
    let spoke_thickness = 0.8;
    grid_intensity = max(grid_intensity, 1.0 - smoothstep(0.0, spoke_thickness, spoke_visibility));
    
    // Blend grid
    final_color = mix(final_color, grid_color, grid_intensity * 0.25);
    
    // Trefoil Alexander polynomial: r(θ) = 2|sin(θ/2)|
    let theta_half = theta * 0.5;
    let r_magnitude = 2.0 * abs(sin(theta_half));
    
    // Normalize to canvas (max r ≈ 2 maps to 90% of max_radius)
    let scale_factor = (max_radius * 0.9) / 2.0;
    let r_scaled = r_magnitude * scale_factor;
    
    // Distance from pixel to curve
    let dist_to_curve = abs(r_pixel - r_scaled);
    
    // Hot-pink stroke: #FF0088
    let stroke_color = vec3<f32>(1.0, 0.0, 0.533);
    let stroke_width = 6.0;
    let stroke_alpha = 1.0 - smoothstep(0.0, stroke_width, dist_to_curve);
    
    // Outer glow (20% opacity)
    let glow_width = stroke_width + 12.0;
    let glow_alpha = (1.0 - smoothstep(stroke_width, glow_width, dist_to_curve)) * 0.2;
    
    // Composite
    let curve_intensity = max(stroke_alpha, glow_alpha);
    final_color = mix(final_color, stroke_color, curve_intensity);
    
    // Neon core highlight
    let core_alpha = 1.0 - smoothstep(0.0, 2.0, dist_to_curve);
    final_color = mix(final_color, vec3<f32>(1.0, 0.8, 1.0), core_alpha * 0.3);
    
    return vec4<f32>(final_color, 1.0);
}