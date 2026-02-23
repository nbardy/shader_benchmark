// 4D Hypercube (Tesseract) Visualization
// Rotates in 4D space and projects to 2D via orthographic→perspective camera

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

// Rotate 4D point in xy-plane by angle θ
fn rotate_4d_xy(p: vec4<f32>, theta: f32) -> vec4<f32> {
    let c = cos(theta);
    let s = sin(theta);
    return vec4<f32>(
        c * p.x - s * p.y,
        s * p.x + c * p.y,
        p.z,
        p.w
    );
}

// Rotate 4D point in zw-plane by angle θ
fn rotate_4d_zw(p: vec4<f32>, theta: f32) -> vec4<f32> {
    let c = cos(theta);
    let s = sin(theta);
    return vec4<f32>(
        p.x,
        p.y,
        c * p.z - s * p.w,
        s * p.z + c * p.w
    );
}

// Distance from point to line segment in 2D
fn dist_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Determine if edge is "hidden" (back-facing)
fn is_front_edge(w1: f32, w2: f32) -> bool {
    return (w1 + w2) * 0.5 > 0.0;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates to [-1, 1]
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // 4D rotation angle: 45° = π/4
    let theta = 0.7853981633974483;
    
    // Generate all 16 tesseract vertices: (±1, ±1, ±1, ±1)
    var vertices: array<vec4<f32>, 16>;
    
    vertices[0u] = vec4<f32>(-1.0, -1.0, -1.0, -1.0);
    vertices[1u] = vec4<f32>( 1.0, -1.0, -1.0, -1.0);
    vertices[2u] = vec4<f32>(-1.0,  1.0, -1.0, -1.0);
    vertices[3u] = vec4<f32>( 1.0,  1.0, -1.0, -1.0);
    vertices[4u] = vec4<f32>(-1.0, -1.0,  1.0, -1.0);
    vertices[5u] = vec4<f32>( 1.0, -1.0,  1.0, -1.0);
    vertices[6u] = vec4<f32>(-1.0,  1.0,  1.0, -1.0);
    vertices[7u] = vec4<f32>( 1.0,  1.0,  1.0, -1.0);
    vertices[8u] = vec4<f32>(-1.0, -1.0, -1.0,  1.0);
    vertices[9u] = vec4<f32>( 1.0, -1.0, -1.0,  1.0);
    vertices[10u] = vec4<f32>(-1.0,  1.0, -1.0,  1.0);
    vertices[11u] = vec4<f32>( 1.0,  1.0, -1.0,  1.0);
    vertices[12u] = vec4<f32>(-1.0, -1.0,  1.0,  1.0);
    vertices[13u] = vec4<f32>( 1.0, -1.0,  1.0,  1.0);
    vertices[14u] = vec4<f32>(-1.0,  1.0,  1.0,  1.0);
    vertices[15u] = vec4<f32>( 1.0,  1.0,  1.0,  1.0);
    
    // Apply 4D rotations and perspective projection
    for (var i: u32 = 0u; i < 16u; i = i + 1u) {
        var v = vertices[i];
        v = rotate_4d_xy(v, theta);
        v = rotate_4d_zw(v, theta);
        
        let p3d = v.xyz;
        let cam_pos = vec3<f32>(3.0, 2.0, 2.0);
        let to_cam = cam_pos - p3d;
        let depth = length(to_cam);
        
        let focal = 2.0;
        let scale = focal / max(depth, 0.1);
        
        vertices[i] = vec4<f32>(p3d * scale, depth);
    }
    
    var min_dist_front = 1e10;
    var min_dist_back = 1e10;
    
    // Edge lists for each dimension
    let edge_x: array<vec2<u32>, 8> = array<vec2<u32>, 8>(
        vec2<u32>(0u, 1u), vec2<u32>(2u, 3u), vec2<u32>(4u, 5u), vec2<u32>(6u, 7u),
        vec2<u32>(8u, 9u), vec2<u32>(10u, 11u), vec2<u32>(12u, 13u), vec2<u32>(14u, 15u)
    );
    
    let edge_y: array<vec2<u32>, 8> = array<vec2<u32>, 8>(
        vec2<u32>(0u, 2u), vec2<u32>(1u, 3u), vec2<u32>(4u, 6u), vec2<u32>(5u, 7u),
        vec2<u32>(8u, 10u), vec2<u32>(9u, 11u), vec2<u32>(12u, 14u), vec2<u32>(13u, 15u)
    );
    
    let edge_z: array<vec2<u32>, 8> = array<vec2<u32>, 8>(
        vec2<u32>(0u, 4u), vec2<u32>(1u, 5u), vec2<u32>(2u, 6u), vec2<u32>(3u, 7u),
        vec2<u32>(8u, 12u), vec2<u32>(9u, 13u), vec2<u32>(10u, 14u), vec2<u32>(11u, 15u)
    );
    
    let edge_w: array<vec2<u32>, 8> = array<vec2<u32>, 8>(
        vec2<u32>(0u, 8u), vec2<u32>(1u, 9u), vec2<u32>(2u, 10u), vec2<u32>(3u, 11u),
        vec2<u32>(4u, 12u), vec2<u32>(5u, 13u), vec2<u32>(6u, 14u), vec2<u32>(7u, 15u)
    );
    
    // Process all edges
    for (var i: u32 = 0u; i < 8u; i = i + 1u) {
        let e_x = edge_x[i];
        let p1_x = vertices[e_x.x];
        let p2_x = vertices[e_x.y];
        let d_x = dist_to_segment(uv, p1_x.xy, p2_x.xy);
        if (is_front_edge(p1_x.w, p2_x.w)) {
            min_dist_front = min(min_dist_front, d_x);
        } else {
            min_dist_back = min(min_dist_back, d_x);
        }
        
        let e_y = edge_y[i];
        let p1_y = vertices[e_y.x];
        let p2_y = vertices[e_y.y];
        let d_y = dist_to_segment(uv, p1_y.xy, p2_y.xy);
        if (is_front_edge(p1_y.w, p2_y.w)) {
            min_dist_front = min(min_dist_front, d_y);
        } else {
            min_dist_back = min(min_dist_back, d_y);
        }
        
        let e_z = edge_z[i];
        let p1_z = vertices[e_z.x];
        let p2_z = vertices[e_z.y];
        let d_z = dist_to_segment(uv, p1_z.xy, p2_z.xy);
        if (is_front_edge(p1_z.w, p2_z.w)) {
            min_dist_front = min(min_dist_front, d_z);
        } else {
            min_dist_back = min(min_dist_back, d_z);
        }
        
        let e_w = edge_w[i];
        let p1_w = vertices[e_w.x];
        let p2_w = vertices[e_w.y];
        let d_w = dist_to_segment(uv, p1_w.xy, p2_w.xy);
        if (is_front_edge(p1_w.w, p2_w.w)) {
            min_dist_front = min(min_dist_front, d_w);
        } else {
            min_dist_back = min(min_dist_back, d_w);
        }
    }
    
    // Render
    let line_width_front = 0.012;
    let line_width_back = 0.004;
    
    var color = vec3<f32>(0.15, 0.15, 0.15);
    
    // Hidden edges (dashed)
    let dash = fract(min_dist_back * 20.0);
    if (dash < 0.5 && min_dist_back < line_width_back * 2.0) {
        color = vec3<f32>(0.4, 0.4, 0.4);
    }
    
    // Front edges (solid cyan)
    if (min_dist_front < line_width_front) {
        color = vec3<f32>(0.0, 0.666, 1.0);
    }
    
    return vec4<f32>(color, 1.0);
}