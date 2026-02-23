// Regular octahedron with one vertex at (0,0,√2)
// Edge length = 2
// Rendering: solid slate-gray faces with glossy appearance and edge bevel
// Key light: (5,3,6), white background

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

// Regular octahedron vertices: edge length = 2, top vertex at (0,0,√2)
fn octahedron_vertex(idx: u32) -> vec3<f32> {
    let sqrt2 = 1.414213562373095;
    switch(idx) {
        case 0u: { return vec3<f32>(0.0, 0.0, sqrt2); }
        case 1u: { return vec3<f32>(1.414213562373095, 0.0, 0.0); }
        case 2u: { return vec3<f32>(0.0, 1.414213562373095, 0.0); }
        case 3u: { return vec3<f32>(-1.414213562373095, 0.0, 0.0); }
        case 4u: { return vec3<f32>(0.0, -1.414213562373095, 0.0); }
        default: { return vec3<f32>(0.0, 0.0, -sqrt2); }
    }
}

fn octahedron_face_normal(face_idx: u32) -> vec3<f32> {
    switch(face_idx) {
        case 0u: { return normalize(vec3<f32>(1.0, 1.0, 1.0)); }
        case 1u: { return normalize(vec3<f32>(-1.0, 1.0, 1.0)); }
        case 2u: { return normalize(vec3<f32>(-1.0, -1.0, 1.0)); }
        case 3u: { return normalize(vec3<f32>(1.0, -1.0, 1.0)); }
        case 4u: { return normalize(vec3<f32>(1.0, 1.0, -1.0)); }
        case 5u: { return normalize(vec3<f32>(-1.0, 1.0, -1.0)); }
        case 6u: { return normalize(vec3<f32>(-1.0, -1.0, -1.0)); }
        default: { return normalize(vec3<f32>(1.0, -1.0, -1.0)); }
    }
}

fn octahedron_face_vertices(face_idx: u32) -> array<vec3<f32>, 3> {
    switch(face_idx) {
        case 0u: { return array<vec3<f32>, 3>(octahedron_vertex(0u), octahedron_vertex(1u), octahedron_vertex(2u)); }
        case 1u: { return array<vec3<f32>, 3>(octahedron_vertex(0u), octahedron_vertex(2u), octahedron_vertex(3u)); }
        case 2u: { return array<vec3<f32>, 3>(octahedron_vertex(0u), octahedron_vertex(3u), octahedron_vertex(4u)); }
        case 3u: { return array<vec3<f32>, 3>(octahedron_vertex(0u), octahedron_vertex(4u), octahedron_vertex(1u)); }
        case 4u: { return array<vec3<f32>, 3>(octahedron_vertex(5u), octahedron_vertex(2u), octahedron_vertex(1u)); }
        case 5u: { return array<vec3<f32>, 3>(octahedron_vertex(5u), octahedron_vertex(3u), octahedron_vertex(2u)); }
        case 6u: { return array<vec3<f32>, 3>(octahedron_vertex(5u), octahedron_vertex(4u), octahedron_vertex(3u)); }
        default: { return array<vec3<f32>, 3>(octahedron_vertex(5u), octahedron_vertex(1u), octahedron_vertex(4u)); }
    }
}

fn ray_triangle(ray_o: vec3<f32>, ray_d: vec3<f32>, v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>) -> vec4<f32> {
    let epsilon = 1e-8;
    let e1 = v1 - v0;
    let e2 = v2 - v0;
    let h = cross(ray_d, e2);
    let a = dot(e1, h);
    
    if (abs(a) < epsilon) {
        return vec4<f32>(-1.0, 0.0, 0.0, 0.0);
    }
    
    let f = 1.0 / a;
    let s = ray_o - v0;
    let u = f * dot(s, h);
    
    if (u < 0.0 || u > 1.0) {
        return vec4<f32>(-1.0, 0.0, 0.0, 0.0);
    }
    
    let q = cross(s, e1);
    let v = f * dot(ray_d, q);
    
    if (v < 0.0 || u + v > 1.0) {
        return vec4<f32>(-1.0, 0.0, 0.0, 0.0);
    }
    
    let t = f * dot(e2, q);
    
    if (t > epsilon) {
        let w = 1.0 - u - v;
        return vec4<f32>(t, u, v, w);
    }
    
    return vec4<f32>(-1.0, 0.0, 0.0, 0.0);
}

fn distance_to_edge(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn edge_bevel_factor(face_p: vec3<f32>, v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>) -> f32 {
    let bevel_width = 0.05;
    let d0 = distance_to_edge(face_p, v0, v1);
    let d1 = distance_to_edge(face_p, v1, v2);
    let d2 = distance_to_edge(face_p, v2, v0);
    let min_dist = min(d0, min(d1, d2));
    
    return smoothstep(0.0, bevel_width, min_dist);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy / params.resolution - 0.5) * 2.0;
    let uv_adj = vec2<f32>(uv.x * aspect, uv.y);
    
    let cam_pos = vec3<f32>(3.0, 2.5, 4.0);
    let cam_target = vec3<f32>(0.0, 0.0, 0.5);
    let cam_up = vec3<f32>(0.0, 1.0, 0.0);
    
    let cam_forward = normalize(cam_target - cam_pos);
    let cam_right = normalize(cross(cam_forward, cam_up));
    let cam_up_norm = normalize(cross(cam_right, cam_forward));
    
    let ray_dir = normalize(cam_right * uv_adj.x + cam_up_norm * uv_adj.y + cam_forward);
    let ray_origin = cam_pos;
    
    var closest_t = 1e10;
    var closest_face = 0u;
    var closest_u = 0.0;
    var closest_v = 0.0;
    var closest_w = 0.0;
    
    for (var f = 0u; f < 8u; f = f + 1u) {
        let verts = octahedron_face_vertices(f);
        let result = ray_triangle(ray_origin, ray_dir, verts[0u], verts[1u], verts[2u]);
        
        if (result.x > 0.0 && result.x < closest_t) {
            closest_t = result.x;
            closest_face = f;
            closest_u = result.y;
            closest_v = result.z;
            closest_w = result.w;
        }
    }
    
    if (closest_t >= 1e10) {
        return vec4<f32>(1.0, 1.0, 1.0, 1.0);
    }
    
    let hit_point = ray_origin + ray_dir * closest_t;
    let face_normal = octahedron_face_normal(closest_face);
    
    let verts = octahedron_face_vertices(closest_face);
    let bevel_factor = edge_bevel_factor(hit_point, verts[0u], verts[1u], verts[2u]);
    
    let light_pos = vec3<f32>(5.0, 3.0, 6.0);
    let light_dir = normalize(light_pos - hit_point);
    
    let diff = max(dot(face_normal, light_dir), 0.0);
    
    let view_dir = normalize(cam_pos - hit_point);
    let half_dir = normalize(light_dir + view_dir);
    let spec = pow(max(dot(face_normal, half_dir), 0.0), 32.0);
    
    let base_color = vec3<f32>(0.4039, 0.4275, 0.4706);
    let bevel_highlight = mix(vec3<f32>(0.3, 0.3, 0.3), vec3<f32>(0.7, 0.7, 0.7), bevel_factor);
    let final_color = base_color * (0.3 + 0.7 * diff) + bevel_highlight * 0.2 + vec3<f32>(1.0, 1.0, 1.0) * spec * 0.5;
    
    return vec4<f32>(final_color, 1.0);
}