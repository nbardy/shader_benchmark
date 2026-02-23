// VERTEX SHADER - Full-screen triangle
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// UNIFORMS
struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

// SDF COMPONENTS
fn sd_capsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, r1: f32, r2: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let r = mix(r1, r2, h);
    return length(pa - ba * h) - r;
}

// ROTATION HELPERS
fn rotate_x(p: vec3<f32>, a: f32) -> vec3<f32> {
    let c = cos(a);
    let s = sin(a);
    return vec3<f32>(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

fn rotate_y(p: vec3<f32>, a: f32) -> vec3<f32> {
    let c = cos(a);
    let s = sin(a);
    return vec3<f32>(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

fn rotate_z(p: vec3<f32>, a: f32) -> vec3<f32> {
    let c = cos(a);
    let s = sin(a);
    return vec3<f32>(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

// SCENE SDF
// Depth 7 Tree: 127 segments. For performance in a fragment shader SDF,
// we'll unroll the iterative logic to find the closest segment.
fn map(p: vec3<f32>) -> f32 {
    let trunk_len = 1.0;
    let trunk_rad = 0.08;
    
    var d = 1e10;
    
    // Level 0: Trunk
    d = min(d, sd_capsule(p, vec3<f32>(0.0), vec3<f32>(0.0, trunk_len, 0.0), trunk_rad, trunk_rad * 0.6));
    
    var stack_pos = array<vec3<f32>, 128>();
    var stack_dir = array<vec3<f32>, 128>();
    var stack_len = array<f32>, 128>();
    var stack_rad = array<f32>, 128>();
    
    // Manual DFS/BFS logic is complex in WGSL without pointers. 
    // We approximate the organic structure using a loop-based spatial partitioning or fixed branching.
    
    // Since we need depth 7 (127 branches), we iteratively define child transforms.
    // For brevity and stability, we use a loop over bits to represent the tree structure.
    for (var i: u32 = 1u; i < 127u; i = i + 1u) {
        let parent_idx = (i - 1u) / 2u;
        // Deterministic branching based on index
        var curr_p = vec3<f32>(0.0, trunk_len, 0.0);
        var curr_dir = vec3<f32>(0.0, 1.0, 0.0);
        var curr_l = trunk_len;
        var curr_r = trunk_rad;
        
        let depth = u32(floor(log2(f32(i + 1u))));
        
        for (var j: u32 = 1u; j <= depth; j = j + 1u) {
            let side = (i >> (depth - j)) & 1u;
            let side_f = select(-1.0, 1.0, side == 1u);
            
            curr_l = curr_l * 0.7;
            curr_r = curr_r * 0.6;
            
            // Apply rotations
            let bend = 0.785; // 45 deg
            let twist = 0.61; // 35 deg
            
            // Local transform logic
            let axis = normalize(select(vec3<f32>(1.0, 0.0, 1.0), vec3<f32>(-1.0, 0.0, 1.0), side == 1u));
            // simplified rotation logic for tree structure
            let cos_b = cos(bend);
            let sin_b = sin(bend);
            let new_dir = normalize(curr_dir * cos_b + cross(axis, curr_dir) * sin_b);
            
            let segment_start = curr_p;
            let segment_end = curr_p + new_dir * curr_l;
            
            if (j == depth) {
                d = min(d, sd_capsule(p, segment_start, segment_end, curr_r / 0.6, curr_r));
            }
            
            curr_p = segment_end;
            curr_dir = new_dir;
        }
    }
    
    return d;
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    return normalize(vec3<f32>(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Camera Setup
    let ro = vec3<f32>(3.0, -6.0, 2.5);
    let target = vec3<f32>(0.0, 1.0, 0.0);
    let fwd = normalize(target - ro);
    let right = normalize(cross(fwd, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, fwd);
    let rd = normalize(fwd * 1.5 + uv.x * right + uv.y * up);
    
    // Background Raymarching
    var t = 0.0;
    var hit = false;
    for (var i = 0; i < 80; i = i + 1) {
        let p = ro + rd * t;
        let d = map(p);
        if (d < 0.001) {
            hit = true;
            break;
        }
        t = t + d;
        if (t > 20.0) { break; }
    }
    
    // Colors
    let sky_zenith = vec3<f32>(0.843, 0.925, 1.0); // #d7ecff
    let sky_horizon = vec3<f32>(1.0, 1.0, 1.0);  // #ffffff
    let bark_color = vec3<f32>(0.294, 0.216, 0.149); // #4b3726
    
    let sky = mix(sky_horizon, sky_zenith, clamp(rd.y + 0.5, 0.0, 1.0));
    
    if (!hit) {
        return vec4<f32>(sky, 1.0);
    }
    
    let p = ro + rd * t;
    let n = get_normal(p);
    let view_dir = normalize(ro - p);
    
    // Lighting
    let key_pos = vec3<f32>(3.0, -5.0, 5.0);
    let fill_pos = vec3<f32>(-2.0, -6.0, 4.0);
    let rim_pos = vec3<f32>(0.0, 0.0, 6.0);
    
    let key_dir = normalize(key_pos - p);
    let fill_dir = normalize(fill_pos - p);
    let rim_dir = normalize(rim_pos - p);
    
    let key_diff = max(dot(n, key_dir), 0.0);
    let fill_diff = max(dot(n, fill_dir), 0.0) * 0.4;
    let rim_pow = pow(max(1.0 - dot(n, view_dir), 0.0), 3.0) * max(dot(n, rim_dir), 0.0) * 0.3;
    
    let lighting = key_diff + fill_diff + rim_pow;
    let final_color = bark_color * lighting;
    
    // Fog / depth
    let res = mix(final_color, sky, smoothstep(5.0, 15.0, t));
    
    return vec4<f32>(res, 1.0);
}