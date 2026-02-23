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
    return vec3<f32>(v.x, v.y * c - v.z * s, v.y * s + v.z * c);
}

fn rotate_z(v: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to [-1, 1] range with proper aspect ratio correction
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y * 2.0;
    
    // Cube vertices: axis-aligned cube with side=2, centered at origin
    var v0 = vec3<f32>(-1.0, -1.0, -1.0);
    var v1 = vec3<f32>( 1.0, -1.0, -1.0);
    var v2 = vec3<f32>( 1.0,  1.0, -1.0);
    var v3 = vec3<f32>(-1.0,  1.0, -1.0);
    var v4 = vec3<f32>(-1.0, -1.0,  1.0);
    var v5 = vec3<f32>( 1.0, -1.0,  1.0);
    var v6 = vec3<f32>( 1.0,  1.0,  1.0);
    var v7 = vec3<f32>(-1.0,  1.0,  1.0);
    
    // Camera: elevated view from upper-right
    // Elevation ~45°, azimuth ~30°
    let elevation = 0.7854;  // ~45 degrees
    let azimuth = 0.5236;    // ~30 degrees
    
    // Apply rotations: first Z (azimuth), then X (elevation)
    v0 = rotate_z(v0, azimuth);
    v0 = rotate_x(v0, elevation);
    v1 = rotate_z(v1, azimuth);
    v1 = rotate_x(v1, elevation);
    v2 = rotate_z(v2, azimuth);
    v2 = rotate_x(v2, elevation);
    v3 = rotate_z(v3, azimuth);
    v3 = rotate_x(v3, elevation);
    v4 = rotate_z(v4, azimuth);
    v4 = rotate_x(v4, elevation);
    v5 = rotate_z(v5, azimuth);
    v5 = rotate_x(v5, elevation);
    v6 = rotate_z(v6, azimuth);
    v6 = rotate_x(v6, elevation);
    v7 = rotate_z(v7, azimuth);
    v7 = rotate_x(v7, elevation);
    
    // Simple orthographic projection (divide by scale for perspective-like effect)
    let scale = 1.5;
    let p0 = v0.xy / scale;
    let p1 = v1.xy / scale;
    let p2 = v2.xy / scale;
    let p3 = v3.xy / scale;
    let p4 = v4.xy / scale;
    let p5 = v5.xy / scale;
    let p6 = v6.xy / scale;
    let p7 = v7.xy / scale;
    
    // Determine which edges are visible (front-facing)
    // Back face (z < 0): v0,v1,v2,v3
    // Front face (z > 0): v4,v5,v6,v7
    let back_visible = v0.z < 0.0 && v1.z < 0.0 && v2.z < 0.0 && v3.z < 0.0;
    let front_visible = v4.z > 0.0 && v5.z > 0.0 && v6.z > 0.0 && v7.z > 0.0;
    let left_visible = v0.z < 0.0 && v3.z < 0.0 && v4.z > 0.0 && v7.z > 0.0;
    let right_visible = v1.z < 0.0 && v2.z < 0.0 && v5.z > 0.0 && v6.z > 0.0;
    let bottom_visible = v0.z < 0.0 && v1.z < 0.0 && v4.z > 0.0 && v5.z > 0.0;
    let top_visible = v2.z < 0.0 && v3.z < 0.0 && v6.z > 0.0 && v7.z > 0.0;
    
    var min_dist = 1000.0;
    var is_visible = false;
    
    // Back face edges
    if back_visible {
        min_dist = min(min_dist, line_distance(uv, p0, p1));
        min_dist = min(min_dist, line_distance(uv, p1, p2));
        min_dist = min(min_dist, line_distance(uv, p2, p3));
        min_dist = min(min_dist, line_distance(uv, p3, p0));
        is_visible = true;
    }
    
    // Front face edges
    if front_visible {
        min_dist = min(min_dist, line_distance(uv, p4, p5));
        min_dist = min(min_dist, line_distance(uv, p5, p6));
        min_dist = min(min_dist, line_distance(uv, p6, p7));
        min_dist = min(min_dist, line_distance(uv, p7, p4));
        is_visible = true;
    }
    
    // Left face edges
    if left_visible {
        min_dist = min(min_dist, line_distance(uv, p0, p3));
        min_dist = min(min_dist, line_distance(uv, p4, p7));
        is_visible = true;
    }
    
    // Right face edges
    if right_visible {
        min_dist = min(min_dist, line_distance(uv, p1, p2));
        min_dist = min(min_dist, line_distance(uv, p5, p6));
        is_visible = true;
    }
    
    // Bottom face edges
    if bottom_visible {
        min_dist = min(min_dist, line_distance(uv, p0, p1));
        min_dist = min(min_dist, line_distance(uv, p4, p5));
        is_visible = true;
    }
    
    // Top face edges
    if top_visible {
        min_dist = min(min_dist, line_distance(uv, p2, p3));
        min_dist = min(min_dist, line_distance(uv, p6, p7));
        is_visible = true;
    }
    
    // Vertical connecting edges
    min_dist = min(min_dist, line_distance(uv, p0, p4));
    min_dist = min(min_dist, line_distance(uv, p1, p5));
    min_dist = min(min_dist, line_distance(uv, p2, p6));
    min_dist = min(min_dist, line_distance(uv, p3, p7));
    
    // Edge rendering: midnight-blue (#003366) with 3px width
    let edge_color = vec3<f32>(0.0, 0.2, 0.4);  // #003366
    let edge_width = 0.015;
    let edge_alpha = 1.0 - smoothstep(0.0, edge_width, min_dist);
    
    // Face rendering: sky-blue with low alpha
    let face_color = vec3<f32>(0.5, 0.8, 1.0);  // sky-blue
    let face_alpha = 0.1;
    
    // Blend: edges over semi-transparent faces
    var final_color = face_color;
    var final_alpha = face_alpha;
    
    if edge_alpha > 0.0 {
        final_color = mix(face_color, edge_color, edge_alpha);
        final_alpha = max(final_alpha, edge_alpha);
    }
    
    // Background: dark/black
    final_color = mix(vec3<f32>(0.0, 0.0, 0.0), final_color, final_alpha);
    
    return vec4<f32>(final_color, 1.0);
}