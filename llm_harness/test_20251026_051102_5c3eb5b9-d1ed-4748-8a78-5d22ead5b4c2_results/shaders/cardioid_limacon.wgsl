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
    _padding: f32,
}

@group(0) @binding(0) var<uniform> params: Params;

fn limacon(theta: f32, a: f32, b: f32) -> f32 {
    return a + b * cos(theta);
}

fn polar_to_cartesian(r: f32, theta: f32) -> vec2<f32> {
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

fn get_curve_color(curve_type: i32) -> vec3<f32> {
    if (curve_type == 0i) {
        return vec3<f32>(1.0, 0.2, 0.2);
    } else if (curve_type == 1i) {
        return vec3<f32>(0.2, 1.0, 0.2);
    } else if (curve_type == 2i) {
        return vec3<f32>(0.2, 0.2, 1.0);
    } else {
        return vec3<f32>(1.0, 1.0, 0.2);
    }
}

fn evaluate_limacon_curve(p: vec2<f32>, a: f32, b: f32, scale: f32) -> f32 {
    let theta = atan2(p.y, p.x);
    let r = limacon(theta, a, b);
    let curve_point = polar_to_cartesian(r * scale, theta);
    return length(p - curve_point);
}

fn draw_grid(p: vec2<f32>, grid_size: f32) -> f32 {
    let grid_val = min(abs(p.x % grid_size), abs(p.y % grid_size));
    return min(grid_val, min(abs(p.x % grid_size - grid_size), abs(p.y % grid_size - grid_size)));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    var color = vec3<f32>(0.05, 0.05, 0.08);
    
    let grid_dist = draw_grid(uv, 0.2);
    let grid_line = smoothstep(0.003, 0.001, grid_dist);
    color = mix(color, vec3<f32>(0.15, 0.15, 0.2), grid_line * 0.4);
    
    let t = params.time * 0.5;
    let animation = sin(t) * 0.3 + 0.7;
    
    let scale = 1.5;
    
    let a1 = 0.5 + sin(t * 0.3) * 0.1;
    let b1 = a1;
    let dist1 = evaluate_limacon_curve(uv, a1, b1, scale);
    let cardioid_line = smoothstep(0.008, 0.002, dist1);
    let cardioid_color = get_curve_color(0i);
    color = mix(color, cardioid_color, cardioid_line * 0.9);
    
    let a2 = 0.4;
    let b2 = 0.7;
    let dist2 = evaluate_limacon_curve(uv, a2, b2, scale);
    let loop_line = smoothstep(0.008, 0.002, dist2);
    let loop_color = get_curve_color(1i);
    color = mix(color, loop_color, loop_line * 0.9);
    
    let a3 = 0.65;
    let b3 = 0.8;
    let dist3 = evaluate_limacon_curve(uv, a3, b3, scale);
    let dimple_line = smoothstep(0.008, 0.002, dist3);
    let dimple_color = get_curve_color(2i);
    color = mix(color, dimple_color, dimple_line * 0.9);
    
    let a4 = 1.0;
    let b4 = 0.5;
    let dist4 = evaluate_limacon_curve(uv, a4, b4, scale);
    let convex_line = smoothstep(0.008, 0.002, dist4);
    let convex_color = get_curve_color(3i);
    color = mix(color, convex_color, convex_line * 0.9);
    
    let circle_origin_dist = length(uv);
    let circle_marker = smoothstep(0.05, 0.04, circle_origin_dist);
    color = mix(color, vec3<f32>(0.8, 0.8, 0.8), circle_marker * 0.5);
    
    let radial_lines = abs(sin(atan2(uv.y, uv.x) * 8.0));
    let radial_alpha = smoothstep(0.02, 0.005, radial_lines) * 0.15;
    color = mix(color, vec3<f32>(0.2, 0.2, 0.25), radial_alpha);
    
    let vignette = 1.0 - length(uv) * 0.3;
    color = color * vignette;
    
    return vec4<f32>(color, 1.0);
}