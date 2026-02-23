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
    aspect: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn line_distance(point: vec2<f32>, p0: vec2<f32>, p1: vec2<f32>) -> f32 {
    let pa = point - p0;
    let ba = p1 - p0;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn rotate_x(v: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(
        v.x,
        v.y * c - v.z * s,
        v.y * s + v.z * c
    );
}

fn rotate_z(v: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(
        v.x * c - v.y * s,
        v.x * s + v.y * c,
        v.z
    );
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates to [-1, 1]
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Camera elevation ~45°, azimuth ~30°
    let elevation = 0.785398;  // 45 degrees in radians
    let azimuth = 0.523599;    // 30 degrees in radians
    
    // Cube vertices (side = 2, centered at origin)
    let v0 = vec3<f32>(-1.0, -1.0, -1.0);
    let v1 = vec3<f32>( 1.0, -1.0, -1.0);
    let v2 = vec3<f32>( 1.0,  1.0, -1.0);
    let v3 = vec3<f32>(-1.0,  1.0, -1.0);
    let v4 = vec3<f32>(-1.0, -1.0,  1.0);
    let v5 = vec3<f32>( 1.0, -1.0,  1.0);
    let v6 = vec3<f32>( 1.0,  1.0,  1.0);
    let v7 = vec3<f32>(-1.0,  1.0,  1.0);
    
    // Apply rotation: first azimuth (around Y), then elevation (around X)
    let rot0 = rotate_z(v0, azimuth);
    let rot1 = rotate_z(v1, azimuth);
    let rot2 = rotate_z(v2, azimuth);
    let rot3 = rotate_z(v3, azimuth);
    let rot4 = rotate_z(v4, azimuth);
    let rot5 = rotate_z(v5, azimuth);
    let rot6 = rotate_z(v6, azimuth);
    let rot7 = rotate_z(v7, azimuth);
    
    let p0 = rotate_x(rot0, elevation);
    let p1 = rotate_x(rot1, elevation);
    let p2 = rotate_x(rot2, elevation);
    let p3 = rotate_x(rot3, elevation);
    let p4 = rotate_x(rot4, elevation);
    let p5 = rotate_x(rot5, elevation);
    let p6 = rotate_x(rot6, elevation);
    let p7 = rotate_x(rot7, elevation);
    
    // Project to 2D (orthographic)
    let proj0 = p0.xy;
    let proj1 = p1.xy;
    let proj2 = p2.xy;
    let proj3 = p3.xy;
    let proj4 = p4.xy;
    let proj5 = p5.xy;
    let proj6 = p6.xy;
    let proj7 = p7.xy;
    
    // Define 12 edges of cube
    // Back face (z = -1): v0, v1, v2, v3
    // Front face (z = +1): v4, v5, v6, v7
    // Connections: v0-v4, v1-v5, v2-v6, v3-v7
    
    var min_dist = 1000.0;
    
    // Back face edges
    min_dist = min(min_dist, line_distance(uv, proj0, proj1));
    min_dist = min(min_dist, line_distance(uv, proj1, proj2));
    min_dist = min(min_dist, line_distance(uv, proj2, proj3));
    min_dist = min(min_dist, line_distance(uv, proj3, proj0));
    
    // Front face edges
    min_dist = min(min_dist, line_distance(uv, proj4, proj5));
    min_dist = min(min_dist, line_distance(uv, proj5, proj6));
    min_dist = min(min_dist, line_distance(uv, proj6, proj7));
    min_dist = min(min_dist, line_distance(uv, proj7, proj4));
    
    // Connecting edges
    min_dist = min(min_dist, line_distance(uv, proj0, proj4));
    min_dist = min(min_dist, line_distance(uv, proj1, proj5));
    min_dist = min(min_dist, line_distance(uv, proj2, proj6));
    min_dist = min(min_dist, line_distance(uv, proj3, proj7));
    
    // Determine face occlusion (approximate depth sorting)
    let center = (p0 + p1 + p2 + p3 + p4 + p5 + p6 + p7) * 0.125;
    let face_back_z = (p0.z + p1.z + p2.z + p3.z) * 0.25;
    let face_front_z = (p4.z + p5.z + p6.z + p7.z) * 0.25;
    let face_left_z = (p0.z + p3.z + p7.z + p4.z) * 0.25;
    let face_right_z = (p1.z + p2.z + p6.z + p5.z) * 0.25;
    let face_bottom_z = (p0.z + p1.z + p5.z + p4.z) * 0.25;
    let face_top_z = (p3.z + p2.z + p6.z + p7.z) * 0.25;
    
    // Hidden line detection: if edge connects front and back faces, check visibility
    let is_hidden = select(0.0, 0.5, min_dist < 0.08);
    
    // Edge rendering: 3px midnight blue (#003366)
    let edge_color = vec3<f32>(0.0, 0.2, 0.4);
    let line_width = 0.015;
    let edge_alpha = 1.0 - smoothstep(0.0, line_width, min_dist);
    
    // Face rendering: transparent sky blue (#87CEEB) with alpha 0.1
    let face_color = vec3<f32>(0.529, 0.808, 0.922);
    let face_alpha = 0.1;
    
    // Simple face containment check (point-in-polygon for cube faces)
    var in_face = 0.0;
    
    // Check back face (v0, v1, v2, v3)
    let back_in = select(0.0, 1.0,
        uv.x >= min(min(proj0.x, proj1.x), min(proj2.x, proj3.x)) &&
        uv.x <= max(max(proj0.x, proj1.x), max(proj2.x, proj3.x)) &&
        uv.y >= min(min(proj0.y, proj1.y), min(proj2.y, proj3.y)) &&
        uv.y <= max(max(proj0.y, proj1.y), max(proj2.y, proj3.y))
    );
    in_face = max(in_face, back_in);
    
    // Combine: edges on top, faces underneath
    let final_color = select(
        face_color * face_alpha,
        edge_color,
        edge_alpha > 0.1
    );
    
    return vec4<f32>(final_color, select(face_alpha, edge_alpha, edge_alpha > 0.1));
}