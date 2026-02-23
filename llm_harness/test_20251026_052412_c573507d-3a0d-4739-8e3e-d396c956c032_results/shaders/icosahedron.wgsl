// Icosahedron wireframe renderer
// Regular icosahedron with edge length 1
// Perspective camera at (3, 2, 2)
// 1800 × 1500 px canvas, white background
// Blue edges (2px), red vertices

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

const PHI: f32 = 1.618033988749894848204586834365638117720309189303576888376;

fn getIcosahedronVertex(idx: u32) -> vec3<f32> {
    let phi = PHI;
    switch(idx) {
        case 0u: { return vec3<f32>(-1.0,  phi, 0.0); }
        case 1u: { return vec3<f32>( 1.0,  phi, 0.0); }
        case 2u: { return vec3<f32>(-1.0, -phi, 0.0); }
        case 3u: { return vec3<f32>( 1.0, -phi, 0.0); }
        case 4u: { return vec3<f32>(0.0, -1.0,  phi); }
        case 5u: { return vec3<f32>(0.0,  1.0,  phi); }
        case 6u: { return vec3<f32>(0.0, -1.0, -phi); }
        case 7u: { return vec3<f32>(0.0,  1.0, -phi); }
        case 8u: { return vec3<f32>( phi, 0.0, -1.0); }
        case 9u: { return vec3<f32>( phi, 0.0,  1.0); }
        case 10u: { return vec3<f32>(-phi, 0.0, -1.0); }
        case 11u: { return vec3<f32>(-phi, 0.0,  1.0); }
        default: { return vec3<f32>(0.0, 0.0, 0.0); }
    }
}

fn normalizeIcosahedron(v: vec3<f32>) -> vec3<f32> {
    let scale = 1.0 / (2.0 * PHI);
    return v * scale;
}

fn getEdgeEndpoint(edge_idx: u32, is_end: u32) -> u32 {
    let idx = edge_idx * 2u + is_end;
    switch(idx) {
        case 0u: { return 0u; } case 1u: { return 1u; }
        case 2u: { return 0u; } case 3u: { return 5u; }
        case 4u: { return 0u; } case 5u: { return 7u; }
        case 6u: { return 0u; } case 7u: { return 11u; }
        case 8u: { return 2u; } case 9u: { return 3u; }
        case 10u: { return 2u; } case 11u: { return 4u; }
        case 12u: { return 2u; } case 13u: { return 6u; }
        case 14u: { return 2u; } case 15u: { return 10u; }
        case 16u: { return 1u; } case 17u: { return 5u; }
        case 18u: { return 1u; } case 19u: { return 9u; }
        case 20u: { return 1u; } case 21u: { return 8u; }
        case 22u: { return 1u; } case 23u: { return 7u; }
        case 24u: { return 3u; } case 25u: { return 4u; }
        case 26u: { return 3u; } case 27u: { return 9u; }
        case 28u: { return 3u; } case 29u: { return 8u; }
        case 30u: { return 3u; } case 31u: { return 6u; }
        case 32u: { return 5u; } case 33u: { return 11u; }
        case 34u: { return 4u; } case 35u: { return 11u; }
        case 36u: { return 9u; } case 37u: { return 5u; }
        case 38u: { return 9u; } case 39u: { return 4u; }
        case 40u: { return 7u; } case 41u: { return 10u; }
        case 42u: { return 6u; } case 43u: { return 10u; }
        case 44u: { return 8u; } case 45u: { return 6u; }
        case 46u: { return 8u; } case 47u: { return 7u; }
        case 48u: { return 11u; } case 49u: { return 10u; }
        case 50u: { return 10u; } case 51u: { return 6u; }
        case 52u: { return 6u; } case 53u: { return 8u; }
        case 54u: { return 8u; } case 55u: { return 9u; }
        case 56u: { return 9u; } case 57u: { return 3u; }
        case 58u: { return 4u; } case 59u: { return 5u; }
        default: { return 0u; }
    }
}

fn projectPoint(p: vec3<f32>) -> vec2<f32> {
    let camera_pos = vec3<f32>(3.0, 2.0, 2.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let up = vec3<f32>(0.0, 1.0, 0.0);
    
    let focal_length = 2.5;
    let view_dir = normalize(camera_target - camera_pos);
    let right = normalize(cross(view_dir, up));
    let actual_up = cross(right, view_dir);
    
    let to_point = p - camera_pos;
    let depth = dot(to_point, view_dir);
    
    let projected_x = dot(to_point, right) * focal_length / depth;
    let projected_y = dot(to_point, actual_up) * focal_length / depth;
    
    return vec2<f32>(projected_x, projected_y);
}

fn distanceToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let len_sq = dot(ba, ba);
    let h = clamp(dot(pa, ba) / len_sq, 0.0, 1.0);
    return length(pa - ba * h);
}

fn distanceToVertex(p: vec2<f32>, v: vec2<f32>) -> f32 {
    return length(p - v);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let viewport_aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy - params.resolution * 0.5) / (params.resolution.y * 0.5);
    let screen_pos = vec2<f32>(uv.x * viewport_aspect, uv.y);
    
    var final_color = vec3<f32>(1.0, 1.0, 1.0);
    
    var vert_proj: array<vec2<f32>, 12>;
    for(var i: u32 = 0u; i < 12u; i = i + 1u) {
        let vert = normalizeIcosahedron(getIcosahedronVertex(i));
        vert_proj[i] = projectPoint(vert);
    }
    
    let edge_color = vec3<f32>(0.0, 0.533, 1.0);
    let edge_width = 0.02;
    var min_edge_dist = 1000.0;
    
    for(var edge: u32 = 0u; edge < 30u; edge = edge + 1u) {
        let v0_idx = getEdgeEndpoint(edge, 0u);
        let v1_idx = getEdgeEndpoint(edge, 1u);
        
        let p0 = vert_proj[v0_idx];
        let p1 = vert_proj[v1_idx];
        
        let dist = distanceToSegment(screen_pos, p0, p1);
        min_edge_dist = min(min_edge_dist, dist);
    }
    
    if (min_edge_dist < edge_width) {
        final_color = edge_color;
    }
    
    let vertex_color = vec3<f32>(1.0, 0.0, 0.0);
    let vertex_radius = 0.015;
    
    for(var vert: u32 = 0u; vert < 12u; vert = vert + 1u) {
        let v_proj = vert_proj[vert];
        let dist_to_vertex = distanceToVertex(screen_pos, v_proj);
        
        if (dist_to_vertex < vertex_radius) {
            final_color = vertex_color;
        }
    }
    
    return vec4<f32>(final_color, 1.0);
}