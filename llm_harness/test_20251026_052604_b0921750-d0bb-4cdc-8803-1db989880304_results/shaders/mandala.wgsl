@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

fn distance_to_circle(point: vec2<f32>, center: vec2<f32>, radius: f32) -> f32 {
    return length(point - center) - radius;
}

fn draw_filled_circle(dist: f32) -> f32 {
    return smoothstep(0.002, -0.002, dist);
}

fn draw_stroked_circle(dist: f32, stroke_width: f32) -> f32 {
    let inside_edge = smoothstep(stroke_width + 0.002, stroke_width - 0.002, dist);
    let outside_edge = smoothstep(-0.002, 0.002, dist);
    return inside_edge * outside_edge;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution;
    
    // Constants from geometry
    let R0 = 0.30;
    let csc_pi_12 = 3.46410161513775458705;
    let R1 = R0 / (csc_pi_12 - 1.0);
    let C1 = R0 + R1;
    let R_boundary = 1.0;
    
    // Aspect ratio correction
    let aspect = params.resolution.x / params.resolution.y;
    let uv_corrected = vec2<f32>(uv.x * aspect, uv.y);
    
    var final_color = vec3<f32>(1.0, 1.0, 1.0);
    
    // CENTRAL CIRCLE
    let dist_central = distance_to_circle(uv_corrected, vec2<f32>(0.0, 0.0), R0);
    let fill_central = draw_filled_circle(dist_central);
    let stroke_central = draw_stroked_circle(dist_central, 0.002);
    let central_fill_color = vec3<f32>(1.0, 0.867, 0.333);
    let central_stroke_color = vec3<f32>(0.0, 0.0, 0.0);
    final_color = mix(final_color, central_fill_color, fill_central);
    final_color = mix(final_color, central_stroke_color, stroke_central);
    
    // FIRST RING - 12 circles
    let pi = 3.14159265359;
    let angle_step = pi / 6.0;
    
    for (var i: u32 = 0u; i < 12u; i = i + 1u) {
        let angle = f32(i) * angle_step;
        let circle_center = vec2<f32>(cos(angle), sin(angle)) * C1;
        let dist = distance_to_circle(uv_corrected, circle_center, R1);
        
        let is_odd = i % 2u;
        let color = select(
            vec3<f32>(0.4, 0.8, 0.933),
            vec3<f32>(1.0, 0.467, 0.467),
            is_odd == 1u
        );
        
        let fill = draw_filled_circle(dist);
        let stroke = draw_stroked_circle(dist, 0.002);
        final_color = mix(final_color, color, fill);
        final_color = mix(final_color, vec3<f32>(0.0, 0.0, 0.0), stroke);
    }
    
    // BOUNDING CIRCLE
    let dist_boundary = distance_to_circle(uv_corrected, vec2<f32>(0.0, 0.0), R_boundary);
    let boundary_stroke = draw_stroked_circle(dist_boundary, 0.003);
    let boundary_color = vec3<f32>(1.0, 0.843, 0.0);
    final_color = mix(final_color, boundary_color, boundary_stroke);
    
    return vec4<f32>(final_color, 1.0);
}