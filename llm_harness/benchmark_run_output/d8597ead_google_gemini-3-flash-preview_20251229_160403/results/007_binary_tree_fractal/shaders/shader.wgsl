struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

fn sd_capsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, r_a: f32, r_b: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let r = mix(r_a, r_b, h);
    return length(pa - ba * h) - r;
}

fn rot_axis(v: vec3<f32>, axis: vec3<f32>, angle: f32) -> vec3<f32> {
    let s = sin(angle);
    let c = cos(angle);
    let oc = 1.0 - c;
    let m = mat3x3<f32>(
        vec3<f32>(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s),
        vec3<f32>(oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s),
        vec3<f32>(oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c)
    );
    return m * v;
}

fn map(p: vec3<f32>) -> f32 {
    var d = 1e10;
    
    // Iterative tree generation via a stack simulation or manual depth expansion
    // To stay performance friendly and avoid recursion (unsupported), we evaluate 
    // the distance to all 127 segments.
    
    var pos_stack: array<vec3<f32>, 127>;
    var dir_stack: array<vec3<f32>, 127>;
    var depth_stack: array<f32>, 127>;
    
    // Root: Level 0
    let root_pos = vec3<f32>(0.0, -1.5, 0.0);
    let root_dir = vec3<f32>(0.0, 1.0, 0.0);
    let root_len = 1.0;
    let root_rad = 0.08;
    
    // Simplified evaluation without dynamic arrays: 
    // We walk a fixed tree structure.
    var current_p = root_pos;
    var current_d = root_dir;
    var len = root_len;
    var rad = root_rad;
    
    // Level 0
    let p0_end = current_p + current_d * len;
    d = min(d, sd_capsule(p, current_p, p0_end, rad, rad * 0.6));
    
    // Level 1..7 (Unrolled logic conceptually)
    // For SDFs, we can use a more compact symetry/domain repetition for fractal trees,
    // but here we strictly follow the 2^n layout.
    
    // Instead of 127 manual lines, we use a loop-based approach for the fractal distance.
    // We transform the point into the local space of each branch recursively.
    var local_p = p - root_pos;
    var dist = 1e10;
    
    // Bounding sphere
    if (length(local_p - vec3<f32>(0.0, 1.5, 0.0)) > 4.0) { return length(local_p - vec3<f32>(0.0, 1.5, 0.0)) - 0.5; }

    // Manual tree distance check (First 4 levels for reliability/performance)
    dist = tree_node(p, root_pos, root_dir, root_len, root_rad, 0u);
    
    return dist;
}

fn tree_node(p: vec3<f32>, start: vec3<f32>, dir: vec3<f32>, len: f32, rad: f32, depth: u32) -> f32 {
    let end = start + dir * len;
    var d = sd_capsule(p, start, end, rad, rad * 0.6);
    
    if (depth < 5u) {
        let child_len = len * 0.7;
        let child_rad = rad * 0.6;
        
        // Compute side vectors for rotation
        var side = normalize(cross(dir, vec3<f32>(1.0, 0.0, 0.1)));
        var up = normalize(cross(side, dir));
        
        // Branch 1: +45 deg tilt, +35 deg twist
        var d1 = rot_axis(dir, side, 0.785); // 45 deg
        d1 = rot_axis(d1, dir, 0.61);      // 35 deg
        d = min(d, tree_node(p, end, d1, child_len, child_rad, depth + 1u));
        
        // Branch 2: -45 deg tilt, -35 deg twist
        var d2 = rot_axis(dir, side, -0.785);
        d2 = rot_axis(d2, dir, -0.61);
        d = min(d, tree_node(p, end, d2, child_len, child_rad, depth + 1u));
    }
    return d;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    let aspect = params.resolution.x / params.resolution.y;
    
    let cam_pos = vec3<f32>(3.0, -1.0, 2.5);
    let look_at = vec3<f32>(0.0, 0.5, 0.0);
    let forward = normalize(look_at - cam_pos);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let fov = 0.7; // 40 degrees roughly
    let rd = normalize(forward + uv.x * right * aspect * fov + uv.y * up * fov);
    
    var t = 0.0;
    var hit = false;
    var p_hit: vec3<f32>;
    
    // Raymarch
    for (var i = 0u; i < 80u; i = i + 1u) {
        p_hit = cam_pos + rd * t;
        let d = tree_node(p_hit, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u);
        if (d < 0.001) {
            hit = true;
            break;
        }
        t = t + d;
        if (t > 20.0) { break; }
    }
    
    // Sky gradient
    let sky_zenith = vec3<f32>(0.843, 0.925, 1.0); // #d7ecff
    let sky_horizon = vec3<f32>(1.0, 1.0, 1.0);  // #ffffff
    var color = mix(sky_horizon, sky_zenith, clamp(rd.y + 0.2, 0.0, 1.0));
    
    if (hit) {
        // Simple normal calc
        let e = vec2<f32>(0.001, 0.0);
        let n = normalize(vec3<f32>(
            tree_node(p_hit + e.xyy, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u) - tree_node(p_hit - e.xyy, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u),
            tree_node(p_hit + e.yxy, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u) - tree_node(p_hit - e.yxy, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u),
            tree_node(p_hit + e.yyx, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u) - tree_node(p_hit - e.yyx, vec3<f32>(0.0, -1.2, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u)
        ));
        
        let bark_color = vec3<f32>(0.294, 0.216, 0.149); // #4b3726
        
        // Lighting
        let l_key = normalize(vec3<f32>(3.0, -5.0, 5.0) - p_hit);
        let l_fill = normalize(vec3<f32>(-2.0, -6.0, 4.0) - p_hit);
        let l_rim = normalize(vec3<f32>(0.0, 0.0, 6.0) - p_hit);
        
        let diff_key = max(dot(n, l_key), 0.0);
        let diff_fill = max(dot(n, l_fill), 0.0) * 0.4;
        let diff_rim = pow(clamp(1.0 + dot(n, rd), 0.0, 1.0), 3.0) * 0.3;
        
        let lighting = diff_key + diff_fill + diff_rim + 0.05;
        color = bark_color * lighting;
    }
    
    // Gamma correction
    color = pow(color, vec3<f32>(0.4545));
    
    return vec4<f32>(color, 1.0);
}