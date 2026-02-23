// Twin Helical Staircases around Central Column
// Camera: (6, 4, 6), Resolution: 2600×2600

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

const MAX_STEPS: u32 = 256u;
const MAX_DIST: f32 = 100.0;
const EPSILON: f32 = 0.001;

const CAMERA_POS: vec3<f32> = vec3<f32>(6.0, 4.0, 6.0);
const LOOK_AT: vec3<f32> = vec3<f32>(0.0, 4.0, 0.0);

const COLUMN_RADIUS: f32 = 0.4;
const TOWER_HEIGHT: f32 = 8.0;
const STEP_DEPTH: f32 = 0.3;
const STEP_RISE: f32 = 0.2;
const STAIR_WIDTH: f32 = 1.2;
const HELIX_RADIUS: f32 = 1.2;
const PITCH: f32 = 1.6;
const TOTAL_TURNS: f32 = 5.0;
const STEPS_PER_HELIX: f32 = 160.0;

fn normalize_safe(v: vec3<f32>) -> vec3<f32> {
    let len = length(v);
    return select(v, v / len, len > EPSILON);
}

fn get_camera_ray(uv: vec2<f32>) -> vec3<f32> {
    let forward = normalize_safe(LOOK_AT - CAMERA_POS);
    let right = normalize_safe(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = normalize_safe(cross(right, forward));
    
    let fov = tan(0.785398);
    let ray_dir = normalize_safe(
        forward + right * uv.x * fov + up * uv.y * fov
    );
    return ray_dir;
}

fn signed_distance_column(p: vec3<f32>) -> f32 {
    let height_ok = p.y >= 0.0 && p.y <= TOWER_HEIGHT;
    let xz_dist = length(p.xz) - COLUMN_RADIUS;
    let height_clip = select(1e10, 0.0, height_ok);
    return xz_dist + height_clip;
}

fn signed_distance_step(p: vec3<f32>, helix_angle: f32) -> f32 {
    let cos_a = cos(helix_angle);
    let sin_a = sin(helix_angle);
    
    let step_center = vec3<f32>(
        HELIX_RADIUS * cos_a,
        0.0,
        HELIX_RADIUS * sin_a
    );
    
    let local = p - step_center;
    
    let depth_half = STEP_DEPTH * 0.5;
    let width_half = STAIR_WIDTH * 0.5;
    let rise_half = STEP_RISE * 0.5;
    
    let local_radial = local.x * cos_a + local.z * sin_a;
    let local_tangent = -local.x * sin_a + local.z * cos_a;
    
    let dx = abs(local_radial) - depth_half;
    let dy = abs(local.y) - rise_half;
    let dz = abs(local_tangent) - width_half;
    
    let outside = max(max(dx, dy), dz);
    let inside = min(max(max(dx, dy), dz), 0.0);
    
    return outside + inside;
}

fn signed_distance_helix_stairs(p: vec3<f32>, offset_angle: f32) -> f32 {
    let h = clamp(p.y, 0.0, TOWER_HEIGHT);
    let turns = (h / TOWER_HEIGHT) * TOTAL_TURNS;
    let helix_angle = turns * 6.283185307 + offset_angle;
    
    let step_index = (h / TOWER_HEIGHT) * STEPS_PER_HELIX;
    let step_idx_floor = floor(step_index);
    
    let snapped_step = step_idx_floor;
    let snapped_height = (snapped_step / STEPS_PER_HELIX) * TOWER_HEIGHT;
    let snapped_angle = (snapped_step / STEPS_PER_HELIX) * TOTAL_TURNS * 6.283185307 + offset_angle;
    
    let p_aligned = p - vec3<f32>(0.0, h - snapped_height, 0.0);
    
    return signed_distance_step(p_aligned, snapped_angle);
}

fn signed_distance_scene(p: vec3<f32>) -> f32 {
    var dist = signed_distance_column(p);
    
    dist = min(dist, signed_distance_helix_stairs(p, 0.0));
    dist = min(dist, signed_distance_helix_stairs(p, 3.141592654));
    
    let ground_dist = p.y;
    dist = min(dist, ground_dist);
    
    let bound = length(p - LOOK_AT) - 20.0;
    dist = max(dist, -bound);
    
    return dist;
}

fn estimate_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.002;
    let eps_x = vec3<f32>(eps, 0.0, 0.0);
    let eps_y = vec3<f32>(0.0, eps, 0.0);
    let eps_z = vec3<f32>(0.0, 0.0, eps);
    
    let grad = vec3<f32>(
        signed_distance_scene(p + eps_x) - signed_distance_scene(p - eps_x),
        signed_distance_scene(p + eps_y) - signed_distance_scene(p - eps_y),
        signed_distance_scene(p + eps_z) - signed_distance_scene(p - eps_z)
    );
    
    return normalize_safe(grad);
}

fn raycast(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec3<f32> {
    var t: f32 = 0.0;
    var hit_step: u32 = 0u;
    
    loop {
        if hit_step >= MAX_STEPS || t > MAX_DIST {
            break;
        }
        
        let p = ray_origin + ray_dir * t;
        let d = signed_distance_scene(p);
        
        if d < EPSILON {
            let normal = estimate_normal(p);
            let light_dir = normalize_safe(vec3<f32>(2.0, 3.0, 2.0) - p);
            let diffuse = max(0.0, dot(normal, light_dir));
            let ambient = 0.2;
            
            let h_frac = p.y / TOWER_HEIGHT;
            var mat_color = mix(
                vec3<f32>(0.6, 0.5, 0.4),
                vec3<f32>(0.4, 0.6, 0.7),
                h_frac
            );
            
            let in_stairs = length(p.xz) > COLUMN_RADIUS && p.y >= 0.0 && p.y <= TOWER_HEIGHT;
            mat_color = select(mat_color, mix(mat_color, vec3<f32>(0.8, 0.7, 0.6), 0.4), in_stairs);
            
            let color = mat_color * (ambient + diffuse * 0.8);
            return color;
        }
        
        t = t + d * 0.8;
        hit_step = hit_step + 1u;
    }
    
    let sky_up = clamp(ray_dir.y, 0.0, 1.0);
    return mix(vec3<f32>(0.2, 0.2, 0.25), vec3<f32>(0.7, 0.8, 0.9), sky_up);
}

@fragment
fn fs_main(@builtin(position) frag_pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (frag_pos.xy / params.resolution) * 2.0 - 1.0;
    let aspect = params.resolution.x / params.resolution.y;
    
    let ray_dir = get_camera_ray(vec2<f32>(uv.x * aspect, uv.y));
    let color = raycast(CAMERA_POS, ray_dir);
    
    let gamma = vec3<f32>(0.454545);
    let final_color = pow(color, gamma);
    
    return vec4<f32>(final_color, 1.0);
}