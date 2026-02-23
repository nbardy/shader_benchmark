// Winter Tree - Recursive procedural geometry with lighting
// 127 segments (depth 7), tapered cylinders, silhouette-optimized shading

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

// ============ Math utilities ============
fn rot_x(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

fn rot_y(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

fn rot_z(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

// ============ Ray-segment intersection ============
struct Hit {
    t: f32,
    hit: bool,
    normal: vec3<f32>,
    radius: f32,
};

fn ray_tapered_cylinder(
    ro: vec3<f32>,
    rd: vec3<f32>,
    p0: vec3<f32>,
    p1: vec3<f32>,
    r0: f32,
    r1: f32
) -> Hit {
    var result: Hit;
    result.t = 1e10;
    result.hit = false;
    result.normal = vec3<f32>(0.0);
    result.radius = 0.0;

    let pa = p0;
    let ba = p1 - p0;
    let oa = ro - pa;

    let baba = dot(ba, ba);
    let bard = dot(ba, rd);
    let baoa = dot(ba, oa);
    let rdoa = dot(rd, oa);
    let oaoa = dot(oa, oa);

    let a = baba - bard * bard;
    let b = baba * rdoa - baoa * bard;
    let c = baba * oaoa - baoa * baoa;

    let h = b * b - a * c;
    if (h >= 0.0) {
        let t = (-b - sqrt(h)) / a;
        let y = (baoa + t * bard) / baba;
        
        if (t > 0.01 && y >= -0.1 && y <= 1.1) {
            let r_at_y = mix(r0, r1, clamp(y, 0.0, 1.0));
            let hit_pt = ro + rd * t;
            let closest_pt = pa + ba * clamp(y, 0.0, 1.0);
            let dist_to_axis = length(hit_pt - closest_pt);
            
            if (dist_to_axis <= r_at_y * 1.01) {
                result.t = t;
                result.hit = true;
                result.radius = r_at_y;
                let perp = normalize(hit_pt - closest_pt);
                result.normal = perp;
            }
        }
    }
    return result;
}

// ============ Scene tree ============
struct TreeSegment {
    p0: vec3<f32>,
    p1: vec3<f32>,
    r0: f32,
    r1: f32,
};

fn recursive_tree(
    pos: vec3<f32>,
    dir: vec3<f32>,
    len: f32,
    rad: f32,
    depth: i32,
    axis_rot: f32,
    seg_array: ptr<function, array<TreeSegment, 256>>
) -> i32 {
    if (depth < 0 || len < 0.01) {
        return 0;
    }
    
    let p0 = pos;
    let p1 = pos + dir * len;
    let r0 = rad;
    let r1 = rad * 0.6;

    let seg_idx = 127 - (1 << u32(7 - depth));
    if (seg_idx < 256u) {
        (*seg_array)[seg_idx] = TreeSegment(p0, p1, r0, r1);
    }

    if (depth <= 0) {
        return 1;
    }

    var count = 1;

    // Left child: rotate ±35° about parent axis, then 45° from parent
    let left_axis_rot = axis_rot + 35.0 * 3.14159 / 180.0;
    let perp_left = rot_z(left_axis_rot) * normalize(cross(dir, vec3<f32>(0.0, 0.0, 1.0)));
    let left_rot = rot_x(45.0 * 3.14159 / 180.0);
    let left_dir = normalize(left_rot * (dir + perp_left * 0.3));

    // Right child: opposite rotation
    let right_axis_rot = axis_rot - 35.0 * 3.14159 / 180.0;
    let perp_right = rot_z(right_axis_rot) * normalize(cross(dir, vec3<f32>(0.0, 0.0, 1.0)));
    let right_dir = normalize(left_rot * (dir + perp_right * 0.3));

    count += recursive_tree(p1, left_dir, len * 0.7, rad * 0.6, depth - 1, left_axis_rot, seg_array);
    count += recursive_tree(p1, right_dir, len * 0.7, rad * 0.6, depth - 1, right_axis_rot, seg_array);

    return count;
}

// ============ Lighting ============
fn compute_lighting(normal: vec3<f32>, pos: vec3<f32>) -> vec3<f32> {
    let bark_color = vec3<f32>(0.29, 0.22, 0.15);
    
    // Key light
    let key_pos = vec3<f32>(3.0, -5.0, 5.0);
    let key_dir = normalize(key_pos - pos);
    let key_intensity = max(0.0, dot(normal, key_dir)) * 0.9;
    
    // Fill light
    let fill_pos = vec3<f32>(-2.0, -6.0, 4.0);
    let fill_dir = normalize(fill_pos - pos);
    let fill_intensity = max(0.0, dot(normal, fill_dir)) * 0.4;
    
    // Rim light
    let rim_pos = vec3<f32>(0.0, 0.0, 6.0);
    let rim_dir = normalize(rim_pos - pos);
    let rim_intensity = max(0.0, dot(normal, rim_dir)) * 0.3;
    
    let total = key_intensity + fill_intensity + rim_intensity + 0.15;
    return bark_color * total;
}

// ============ Sky gradient ============
fn sky_color(dir: vec3<f32>) -> vec3<f32> {
    let zenith = vec3<f32>(0.84, 0.93, 1.0);
    let horizon = vec3<f32>(1.0, 1.0, 1.0);
    let t = max(0.0, dir.z * 0.5 + 0.5);
    return mix(horizon, zenith, t * t);
}

// ============ Main fragment shader ============
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Camera setup
    let cam_pos = vec3<f32>(3.0, -6.0, 2.5);
    let cam_target = vec3<f32>(0.0, 0.0, 0.5);
    let cam_up = vec3<f32>(0.0, 0.0, 1.0);
    
    let fov = 40.0 * 3.14159 / 180.0;
    let focal = 1.0 / tan(fov * 0.5);
    
    let forward = normalize(cam_target - cam_pos);
    let right = normalize(cross(forward, cam_up));
    let up = cross(right, forward);
    
    let px = (uv.x - 0.5) * aspect * 2.0;
    let py = (uv.y - 0.5) * 2.0;
    
    let rd = normalize(forward * focal + right * px + up * py);
    let ro = cam_pos;
    
    // Generate tree
    var segments: array<TreeSegment, 256>;
    let _ = recursive_tree(vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(0.0, 0.0, 1.0), 1.0, 0.08, 7, 0.0, &segments);
    
    // Ray march through tree
    var min_t = 1e10;
    var best_hit: Hit;
    best_hit.hit = false;
    best_hit.t = 1e10;
    
    // Check first 32 segments (constraint: limited loops)
    var i = 0;
    loop {
        if (i >= 32) { break; }
        
        let seg = segments[i];
        let hit = ray_tapered_cylinder(ro, rd, seg.p0, seg.p1, seg.r0, seg.r1);
        
        if (hit.hit && hit.t < best_hit.t) {
            best_hit = hit;
        }
        
        i = i + 1;
    }
    
    var final_color: vec3<f32>;
    
    if (best_hit.hit) {
        let hit_pos = ro + rd * best_hit.t;
        final_color = compute_lighting(best_hit.normal, hit_pos);
    } else {
        final_color = sky_color(rd);
    }
    
    return vec4<f32>(final_color, 1.0);
}