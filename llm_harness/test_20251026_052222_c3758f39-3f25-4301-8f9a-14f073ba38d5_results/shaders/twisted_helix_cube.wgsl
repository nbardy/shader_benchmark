// Twisted cube with true helical edges
// Orange diffuse (#ffaa33) with black wireframe overlay (1px)
// 90° twist transformation with parametric helical paths

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

// Distance from point to line segment
fn line_distance(point: vec2<f32>, p0: vec2<f32>, p1: vec2<f32>) -> f32 {
    let pa = point - p0;
    let ba = p1 - p0;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Apply twist transformation to a 3D point
// Vertical edges twist by 90° from y=-1 to y=1
fn apply_twist(vertex: vec3<f32>) -> vec3<f32> {
    let y = vertex.y;
    let theta = 1.5707963267948966 * (y + 1.0) * 0.5; // π/2 * (y+1)/2
    
    let cos_t = cos(theta);
    let sin_t = sin(theta);
    
    let x_orig = vertex.x;
    let z_orig = vertex.z;
    
    let x_twisted = x_orig * cos_t - z_orig * sin_t;
    let z_twisted = x_orig * sin_t + z_orig * cos_t;
    
    return vec3<f32>(x_twisted, y, z_twisted);
}

// Sample a helix along a vertical edge
// Original position: fixed x,z; y varies from -1 to 1
fn sample_helix(x_orig: f32, z_orig: f32, y_param: f32) -> vec3<f32> {
    let y = y_param * 2.0 - 1.0; // map [0,1] to [-1,1]
    let theta = 1.5707963267948966 * (y + 1.0) * 0.5;
    
    let cos_t = cos(theta);
    let sin_t = sin(theta);
    
    let x_twisted = x_orig * cos_t - z_orig * sin_t;
    let z_twisted = x_orig * sin_t + z_orig * cos_t;
    
    return vec3<f32>(x_twisted, y, z_twisted);
}

// Compute minimum distance to all 12 cube edges (with twist)
fn cube_edge_distance(uv: vec2<f32>) -> f32 {
    let time = length(uv) * 0.3;
    
    // Rotation matrices for view
    let rotX = time * 0.4;
    let rotY = time * 0.6;
    
    let cosX = cos(rotX);
    let sinX = sin(rotX);
    let cosY = cos(rotY);
    let sinY = sin(rotY);
    
    let rotMatX = mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, cosX, -sinX),
        vec3<f32>(0.0, sinX, cosX)
    );
    
    let rotMatY = mat3x3<f32>(
        vec3<f32>(cosY, 0.0, sinY),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sinY, 0.0, cosY)
    );
    
    let rot = rotMatY * rotMatX;
    
    // Cube vertices (before twist applied during rendering)
    // Bottom face (y=-1): no twist at y=-1
    let v0 = vec3<f32>(-1.0, -1.0, -1.0);
    let v1 = vec3<f32>( 1.0, -1.0, -1.0);
    let v2 = vec3<f32>( 1.0, -1.0,  1.0);
    let v3 = vec3<f32>(-1.0, -1.0,  1.0);
    
    // Top face (y=1): full 90° twist
    let v4 = apply_twist(vec3<f32>(-1.0,  1.0, -1.0));
    let v5 = apply_twist(vec3<f32>( 1.0,  1.0, -1.0));
    let v6 = apply_twist(vec3<f32>( 1.0,  1.0,  1.0));
    let v7 = apply_twist(vec3<f32>(-1.0,  1.0,  1.0));
    
    // Vertical edges sample as helices
    var minDist = 1000.0;
    
    // Sample vertical edges as helices (12 samples per edge for smooth curves)
    // Edge v0-v4
    for (var i = 0u; i < 12u; i = i + 1u) {
        let t0 = f32(i) / 12.0;
        let t1 = f32(i + 1u) / 12.0;
        let p0 = rot * sample_helix(-1.0, -1.0, t0);
        let p1 = rot * sample_helix(-1.0, -1.0, t1);
        minDist = min(minDist, line_distance(uv, p0.xy * 0.5, p1.xy * 0.5));
    }
    
    // Edge v1-v5
    for (var i = 0u; i < 12u; i = i + 1u) {
        let t0 = f32(i) / 12.0;
        let t1 = f32(i + 1u) / 12.0;
        let p0 = rot * sample_helix(1.0, -1.0, t0);
        let p1 = rot * sample_helix(1.0, -1.0, t1);
        minDist = min(minDist, line_distance(uv, p0.xy * 0.5, p1.xy * 0.5));
    }
    
    // Edge v2-v6
    for (var i = 0u; i < 12u; i = i + 1u) {
        let t0 = f32(i) / 12.0;
        let t1 = f32(i + 1u) / 12.0;
        let p0 = rot * sample_helix(1.0, 1.0, t0);
        let p1 = rot * sample_helix(1.0, 1.0, t1);
        minDist = min(minDist, line_distance(uv, p0.xy * 0.5, p1.xy * 0.5));
    }
    
    // Edge v3-v7
    for (var i = 0u; i < 12u; i = i + 1u) {
        let t0 = f32(i) / 12.0;
        let t1 = f32(i + 1u) / 12.0;
        let p0 = rot * sample_helix(-1.0, 1.0, t0);
        let p1 = rot * sample_helix(-1.0, 1.0, t1);
        minDist = min(minDist, line_distance(uv, p0.xy * 0.5, p1.xy * 0.5));
    }
    
    // Bottom face edges (no twist)
    let p0 = rot * v0;
    let p1 = rot * v1;
    let p2 = rot * v2;
    let p3 = rot * v3;
    
    minDist = min(minDist, line_distance(uv, p0.xy * 0.5, p1.xy * 0.5));
    minDist = min(minDist, line_distance(uv, p1.xy * 0.5, p2.xy * 0.5));
    minDist = min(minDist, line_distance(uv, p2.xy * 0.5, p3.xy * 0.5));
    minDist = min(minDist, line_distance(uv, p3.xy * 0.5, p0.xy * 0.5));
    
    // Top face edges (twisted)
    let p4 = rot * v4;
    let p5 = rot * v5;
    let p6 = rot * v6;
    let p7 = rot * v7;
    
    minDist = min(minDist, line_distance(uv, p4.xy * 0.5, p5.xy * 0.5));
    minDist = min(minDist, line_distance(uv, p5.xy * 0.5, p6.xy * 0.5));
    minDist = min(minDist, line_distance(uv, p6.xy * 0.5, p7.xy * 0.5));
    minDist = min(minDist, line_distance(uv, p7.xy * 0.5, p4.xy * 0.5));
    
    return minDist;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let edge_dist = cube_edge_distance(uv);
    
    // Orange diffuse color: #ffaa33
    let orange = vec3<f32>(1.0, 0.667, 0.2);
    let black = vec3<f32>(0.0, 0.0, 0.0);
    let bg = vec3<f32>(0.05, 0.05, 0.05);
    
    // Face fill with soft shading
    let face_alpha = smoothstep(0.5, 0.45, length(uv));
    
    // Black wireframe (1px ≈ 0.003 in normalized coords)
    let wire_width = 0.003;
    let wire_alpha = 1.0 - smoothstep(0.0, wire_width, edge_dist);
    
    // Blend: black wire on orange face, else background
    let face_color = select(bg, orange, face_alpha > 0.1);
    let final_color = mix(face_color, black, wire_alpha);
    
    return vec4<f32>(final_color, 1.0);
}