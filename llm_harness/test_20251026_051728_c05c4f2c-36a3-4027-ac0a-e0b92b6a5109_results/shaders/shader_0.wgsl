// Regular pentagram inscribed in circle of radius 1
// Vertices at angles: 0°, 72°, 144°, 216°, 288°
// Connect in order: 1→3→5→2→4→1
// Fill: #ffcc33, Stroke: black 3px

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

fn pentagon_vertex(index: u32) -> vec2<f32> {
    let angle = f32(index) * 1.2566370614359172953850573533118 * 2.0;
    return vec2<f32>(cos(angle), sin(angle));
}

fn line_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn point_in_triangle(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> f32 {
    let v0 = c - a;
    let v1 = b - a;
    let v2 = p - a;
    
    let dot00 = dot(v0, v0);
    let dot01 = dot(v0, v1);
    let dot02 = dot(v0, v2);
    let dot11 = dot(v1, v1);
    let dot12 = dot(v1, v2);
    
    let denom = dot00 * dot11 - dot01 * dot01;
    let invDenom = select(0.0, 1.0 / denom, abs(denom) > 1e-6);
    
    let u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    let v = (dot00 * dot12 - dot01 * dot02) * invDenom;
    
    let inside = select(0.0, 1.0, (u >= 0.0) && (v >= 0.0) && (u + v <= 1.0));
    return inside;
}

fn sign(p1: vec2<f32>, p2: vec2<f32>, p3: vec2<f32>) -> f32 {
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

fn point_in_pentagram(p: vec2<f32>) -> f32 {
    let v0 = pentagon_vertex(0u);
    let v1 = pentagon_vertex(1u);
    let v2 = pentagon_vertex(2u);
    let v3 = pentagon_vertex(3u);
    let v4 = pentagon_vertex(4u);
    
    let tri_a = point_in_triangle(p, v0, v2, v4);
    let tri_b = point_in_triangle(p, v0, v1, v3);
    let tri_c = point_in_triangle(p, v1, v2, v4);
    let tri_d = point_in_triangle(p, v2, v3, v0);
    let tri_e = point_in_triangle(p, v3, v4, v1);
    
    let filled = max(max(max(max(tri_a, tri_b), tri_c), tri_d), tri_e);
    return filled;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let v0 = pentagon_vertex(0u);
    let v1 = pentagon_vertex(1u);
    let v2 = pentagon_vertex(2u);
    let v3 = pentagon_vertex(3u);
    let v4 = pentagon_vertex(4u);
    
    let d0 = line_distance(uv, v0, v2);
    let d1 = line_distance(uv, v2, v4);
    let d2 = line_distance(uv, v4, v1);
    let d3 = line_distance(uv, v1, v3);
    let d4 = line_distance(uv, v3, v0);
    
    let min_dist = min(min(min(min(d0, d1), d2), d3), d4);
    
    let fill = point_in_pentagram(uv);
    
    let stroke_width = 0.015;
    let stroke = select(0.0, 1.0, min_dist < stroke_width);
    
    let fill_color = vec3<f32>(1.0, 0.8, 0.2);
    let stroke_color = vec3<f32>(0.0, 0.0, 0.0);
    let bg_color = vec3<f32>(1.0, 1.0, 1.0);
    
    let color = select(
        select(bg_color, fill_color, fill > 0.5),
        stroke_color,
        stroke > 0.5
    );
    
    return vec4<f32>(color, 1.0);
}