// Winter tree fractal - recursive branching geometry with silhouette lighting
// Trunk → 7 levels of bifurcating branches, tapered cylinders with smooth joints
// Camera: (3, -6, 2.5) → origin; FOV 40°
// Lighting: key (3,-5,5), fill (-2,-6,4) 0.4×, rim (0,0,6) 0.3×
// Material: dark bark #4b3726, roughness 0.7

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

// --- Ray marching constants ---
const MAX_STEPS: u32 = 256u;
const MAX_DIST: f32 = 100.0;
const SURF_DIST: f32 = 0.001;

// --- Tree parameters ---
const TREE_DEPTH: u32 = 7u;
const TRUNK_LEN: f32 = 1.0;
const TRUNK_RAD: f32 = 0.08;
const LEN_SCALE: f32 = 0.7;
const RAD_SCALE: f32 = 0.6;
const BRANCH_ANGLE: f32 = 0.785398;
const TWIST_ANGLE: f32 = 0.610865;
const BARK_COLOR: vec3<f32> = vec3<f32>(0.29, 0.21, 0.15);

// --- Camera & lighting ---
const CAM_POS: vec3<f32> = vec3<f32>(3.0, -6.0, 2.5);
const CAM_TARGET: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
const FOV: f32 = 0.6947;

const KEY_LIGHT: vec3<f32> = vec3<f32>(3.0, -5.0, 5.0);
const FILL_LIGHT: vec3<f32> = vec3<f32>(-2.0, -6.0, 4.0);
const RIM_LIGHT: vec3<f32> = vec3<f32>(0.0, 0.0, 6.0);
const FILL_INTENSITY: f32 = 0.4;
const RIM_INTENSITY: f32 = 0.3;

// --- Math helpers ---
fn mat3_rotation_x(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

fn mat3_rotation_y(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

fn mat3_rotation_z(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

fn normalize_safe(v: vec3<f32>) -> vec3<f32> {
    let len = length(v);
    return select(v, normalize(v), len > 0.001);
}

// --- Signed Distance Functions ---

fn sd_tapered_cylinder(p: vec3<f32>, p_end: vec3<f32>, base_rad: f32, tip_rad: f32) -> f32 {
    let axis = normalize_safe(p_end);
    let len = length(p_end);
    let proj = clamp(dot(p, axis), 0.0, len);
    let closest_axis = axis * proj;
    let r_at_t = mix(base_rad, tip_rad, proj / len);
    let dist_to_axis = length(p - closest_axis);
    let lateral = dist_to_axis - r_at_t;
    let end_cap = length(p - p_end) - tip_rad;
    return max(lateral, min(abs(proj - len), end_cap));
}

fn sd_tree_branch(
    p: vec3<f32>,
    pos: vec3<f32>,
    dir: vec3<f32>,
    len: f32,
    base_rad: f32,
    depth: u32
) -> f32 {
    let p_end = pos + dir * len;
    var d = sd_tapered_cylinder(p, p_end, base_rad, base_rad * RAD_SCALE);
    
    if (depth < TREE_DEPTH) {
        let next_len = len * LEN_SCALE;
        let next_rad = base_rad * RAD_SCALE;
        
        let left_twist = mat3_rotation_z(-TWIST_ANGLE);
        let left_rot = mat3_rotation_x(BRANCH_ANGLE);
        let left_dir = normalize_safe(left_rot * (left_twist * dir));
        d = min(d, sd_tree_branch(p, p_end, left_dir, next_len, next_rad, depth + 1u));
        
        let right_twist = mat3_rotation_z(TWIST_ANGLE);
        let right_rot = mat3_rotation_x(BRANCH_ANGLE);
        let right_dir = normalize_safe(right_rot * (right_twist * dir));
        d = min(d, sd_tree_branch(p, p_end, right_dir, next_len, next_rad, depth + 1u));
    }
    
    return d;
}

fn sd_scene(p: vec3<f32>) -> f32 {
    var d = sd_tree_branch(p, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(0.0, 0.0, 1.0), TRUNK_LEN, TRUNK_RAD, 0u);
    d = min(d, p.z + 2.0);
    return d;
}

// --- Ray marching ---
fn raymarch(ro: vec3<f32>, rd: vec3<f32>) -> vec2<f32> {
    var d_total = 0.0;
    var step_count = 0u;
    
    loop {
        if (step_count >= MAX_STEPS || d_total > MAX_DIST) { break; }
        
        let p = ro + rd * d_total;
        let d_scene = sd_scene(p);
        
        if (abs(d_scene) < SURF_DIST) {
            return vec2<f32>(d_total, 1.0);
        }
        
        d_total += d_scene * 0.8;
        step_count += 1u;
    }
    
    return vec2<f32>(d_total, 0.0);
}

// --- Normal estimation ---
fn normal_at(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let nx = sd_scene(p + vec3<f32>(eps, 0.0, 0.0)) - sd_scene(p - vec3<f32>(eps, 0.0, 0.0));
    let ny = sd_scene(p + vec3<f32>(0.0, eps, 0.0)) - sd_scene(p - vec3<f32>(0.0, eps, 0.0));
    let nz = sd_scene(p + vec3<f32>(0.0, 0.0, eps)) - sd_scene(p - vec3<f32>(0.0, 0.0, eps));
    return normalize_safe(vec3<f32>(nx, ny, nz));
}

// --- Lighting ---
fn shade(p: vec3<f32>, n: vec3<f32>, view_dir: vec3<f32>) -> vec3<f32> {
    var color = vec3<f32>(0.0);
    
    let key_dir = normalize_safe(KEY_LIGHT - p);
    let key_diff = max(0.0, dot(n, key_dir));
    let key_spec = pow(max(0.0, dot(normalize_safe(key_dir + view_dir), n)), 8.0);
    color += BARK_COLOR * key_diff + vec3<f32>(0.3) * key_spec;
    
    let fill_dir = normalize_safe(FILL_LIGHT - p);
    let fill_diff = max(0.0, dot(n, fill_dir));
    color += BARK_COLOR * fill_diff * FILL_INTENSITY;
    
    let rim = pow(max(0.0, 1.0 - abs(dot(n, -view_dir))), 2.0);
    color += vec3<f32>(0.6, 0.5, 0.4) * rim * RIM_INTENSITY;
    
    return color;
}

// --- Sky gradient ---
fn sky(rd: vec3<f32>) -> vec3<f32> {
    let zenith = vec3<f32>(0.84, 0.93, 1.0);
    let horizon = vec3<f32>(1.0);
    let t = 0.5 + 0.5 * rd.z;
    return mix(horizon, zenith, smoothstep(0.0, 1.0, t));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let cam_right = normalize_safe(cross(vec3<f32>(0.0, 0.0, 1.0), normalize_safe(CAM_TARGET - CAM_POS)));
    let cam_up = cross(normalize_safe(CAM_TARGET - CAM_POS), cam_right);
    let cam_forward = normalize_safe(CAM_TARGET - CAM_POS);
    
    let rd = normalize_safe(cam_forward + cam_right * uv.x * tan(FOV) + cam_up * uv.y * tan(FOV));
    
    let hit = raymarch(CAM_POS, rd);
    let t = hit.x;
    let is_hit = hit.y > 0.5;
    
    var final_color = sky(rd);
    
    if (is_hit) {
        let p = CAM_POS + rd * t;
        let n = normal_at(p);
        let view_dir = normalize_safe(CAM_POS - p);
        final_color = shade(p, n, view_dir);
    }
    
    return vec4<f32>(final_color, 1.0);
}