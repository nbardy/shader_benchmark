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

fn perspective_project(p: vec3<f32>, eye: vec3<f32>, target_var: vec3<f32>, up_world: vec3<f32>, fov: f32, aspect: f32) -> vec2<f32> {
    let forward = normalize(target_var - eye);
    let right = normalize(cross(forward, up_world));
    let up_local = cross(right, forward);
    
    let to_point = p - eye;
    let z_cam = dot(to_point, forward);
    let x_cam = dot(to_point, right);
    let y_cam = dot(to_point, up_local);
    
    if (z_cam <= 0.1) {
        return vec2<f32>(10.0, 10.0);
    }
    
    let h = tan(fov * 0.5) * z_cam;
    let w = h * aspect;
    
    let x_ndc = x_cam / w;
    let y_ndc = y_cam / h;
    
    return vec2<f32>(x_ndc, y_ndc);
}

fn distance_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn signed_distance_to_triangle(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> f32 {
    let ab = b - a;
    let ac = c - a;
    let ap = p - a;
    
    let cross_ab_ac = ab.x * ac.y - ab.y * ac.x;
    let cross_ab_ap = ab.x * ap.y - ab.y * ap.x;
    let cross_ac_ap = ac.x * ap.y - ac.y * ap.x;
    
    if (abs(cross_ab_ac) < 1e-6) {
        return 1000.0;
    }
    
    let s = cross_ab_ap / cross_ab_ac;
    let t = cross_ac_ap / cross_ab_ac;
    
    let d_edge1 = distance_to_segment(p, a, b);
    let d_edge2 = distance_to_segment(p, b, c);
    let d_edge3 = distance_to_segment(p, c, a);
    
    let min_edge = min(d_edge1, min(d_edge2, d_edge3));
    
    let inside = (s >= -0.01) && (t >= -0.01) && ((s + t) <= 1.01);
    return select(min_edge, -min_edge, inside);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let eye = vec3<f32>(4.0, 3.0, 3.0);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let up = vec3<f32>(0.0, 1.0, 0.0);
    let fov = 30.0 * 3.14159265 / 180.0;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Tetrahedron A: (1,1,1), (-1,-1,1), (-1,1,-1), (1,-1,-1)
    let a_v0 = vec3<f32>(1.0, 1.0, 1.0);
    let a_v1 = vec3<f32>(-1.0, -1.0, 1.0);
    let a_v2 = vec3<f32>(-1.0, 1.0, -1.0);
    let a_v3 = vec3<f32>(1.0, -1.0, -1.0);
    
    // Tetrahedron B: (1,1,-1), (-1,-1,-1), (-1,1,1), (1,-1,1)
    let b_v0 = vec3<f32>(1.0, 1.0, -1.0);
    let b_v1 = vec3<f32>(-1.0, -1.0, -1.0);
    let b_v2 = vec3<f32>(-1.0, 1.0, 1.0);
    let b_v3 = vec3<f32>(1.0, -1.0, 1.0);
    
    // Project
    let a_p0 = perspective_project(a_v0, eye, target_var, up, fov, aspect);
    let a_p1 = perspective_project(a_v1, eye, target_var, up, fov, aspect);
    let a_p2 = perspective_project(a_v2, eye, target_var, up, fov, aspect);
    let a_p3 = perspective_project(a_v3, eye, target_var, up, fov, aspect);
    
    let b_p0 = perspective_project(b_v0, eye, target_var, up, fov, aspect);
    let b_p1 = perspective_project(b_v1, eye, target_var, up, fov, aspect);
    let b_p2 = perspective_project(b_v2, eye, target_var, up, fov, aspect);
    let b_p3 = perspective_project(b_v3, eye, target_var, up, fov, aspect);
    
    // Compute distances
    let dist_a0 = signed_distance_to_triangle(uv, a_p0, a_p1, a_p2);
    let dist_a1 = signed_distance_to_triangle(uv, a_p0, a_p1, a_p3);
    let dist_a2 = signed_distance_to_triangle(uv, a_p0, a_p2, a_p3);
    let dist_a3 = signed_distance_to_triangle(uv, a_p1, a_p2, a_p3);
    
    let dist_b0 = signed_distance_to_triangle(uv, b_p0, b_p1, b_p2);
    let dist_b1 = signed_distance_to_triangle(uv, b_p0, b_p1, b_p3);
    let dist_b2 = signed_distance_to_triangle(uv, b_p0, b_p2, b_p3);
    let dist_b3 = signed_distance_to_triangle(uv, b_p1, b_p2, b_p3);
    
    let dist_a_min = min(dist_a0, min(dist_a1, min(dist_a2, dist_a3)));
    let dist_b_min = min(dist_b0, min(dist_b1, min(dist_b2, dist_b3)));
    
    var final_color = vec3<f32>(1.0, 1.0, 1.0);
    var final_alpha = 0.0;
    
    let edge_threshold = 0.008;
    let face_threshold = 0.08;
    
    // Check which geometry is closest
    let a_is_closer = (dist_a_min < dist_b_min) && (dist_a_min < face_threshold);
    let b_is_visible = (dist_b_min < face_threshold);
    
    if (a_is_closer) {
        let edge_blend = 1.0 - smoothstep(0.0, edge_threshold, abs(dist_a_min));
        final_color = vec3<f32>(0.0, 0.8, 0.93);
        final_alpha = mix(0.6, 1.0, edge_blend);
    } else if (b_is_visible) {
        let edge_blend = 1.0 - smoothstep(0.0, edge_threshold, abs(dist_b_min));
        final_color = vec3<f32>(0.8, 0.0, 0.93);
        final_alpha = mix(0.6, 1.0, edge_blend);
    }
    
    return vec4<f32>(final_color, final_alpha);
}