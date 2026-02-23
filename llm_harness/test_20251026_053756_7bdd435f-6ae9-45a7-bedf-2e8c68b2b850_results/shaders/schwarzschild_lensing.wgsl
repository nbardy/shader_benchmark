// Schwarzschild Black Hole Gravitational Lensing Shader
// Physical ray tracing with starfield distortion
// Resolution: 1920x1080, FOV: 100°, Observer: r=10M, θ=π/2

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    time_frame: f32,
    pad0: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Constants
const PI = 3.14159265359;
const TWO_PI = 6.28318530718;
const M = 1.0;
const R_OBS = 10.0;
const FOV_H = 100.0;
const B_CRIT = 5.19615242271;
const B_CRIT_TOLERANCE = 0.01;
const EVENT_HORIZON = 2.0;
const RAY_MAX_RADIUS = 1000.0;
const RAY_STEP_SIZE = 0.01;
const RAY_MAX_STEPS = 100000u;
const STAR_COUNT = 10000u;
const STAR_SEARCH_ANGLE = 0.2;
const DEEP_NAVY = vec3<f32>(0.0, 0.0, 0.125);
const AMBER_PHOTON = vec3<f32>(1.0, 0.666, 0.2);
const STAR_WHITE = vec3<f32>(1.0, 1.0, 1.0);

fn pcg_hash(seed: u32) -> u32 {
    var x = seed;
    x = ((x >> 16u) ^ x) * 0x7feb352du;
    x = ((x >> 15u) ^ x) * 0x846ca68bu;
    x = (x >> 16u) ^ x;
    return x;
}

fn rand_f32(seed: ptr<function, u32>) -> f32 {
    *seed = pcg_hash(*seed ^ 0x12345678u);
    return f32(*seed) / 4294967296.0;
}

fn rand_sphere(seed: ptr<function, u32>) -> vec3<f32> {
    let u = rand_f32(seed);
    let v = rand_f32(seed);
    let theta = TWO_PI * u;
    let phi = acos(2.0 * v - 1.0);
    let sin_phi = sin(phi);
    return vec3<f32>(
        sin_phi * cos(theta),
        sin_phi * sin(theta),
        cos(phi)
    );
}

fn get_star_position(star_id: u32) -> vec3<f32> {
    var seed = star_id * 73856093u ^ 19349663u;
    return rand_sphere(&seed);
}

fn ray_sphere_intersect(ray_dir: vec3<f32>, star_dir: vec3<f32>, angle_tol: f32) -> bool {
    let cos_angle = dot(ray_dir, star_dir);
    let angle = acos(clamp(cos_angle, -1.0, 1.0));
    return angle < angle_tol;
}

fn schwarzschild_metric_rk4(
    pos: ptr<function, vec3<f32>>,
    vel: ptr<function, vec3<f32>>,
    dt: f32
) {
    let r = length(*pos);
    let r2 = r * r;
    let r3 = r2 * r;
    
    let metric_factor = 1.0 - 2.0 * M / r;
    if metric_factor <= 0.0 {
        return;
    }
    
    let r_hat = normalize(*pos);
    let v_mag2 = dot(*vel, *vel);
    let v_radial = dot(*vel, r_hat);
    let v_tangential_sq = v_mag2 - v_radial * v_radial;
    
    let a_radial = M / r2 - (M / r3) * v_tangential_sq / metric_factor;
    let accel = (a_radial - v_radial * v_radial / r) * r_hat;
    
    let k1v = accel * dt;
    let k1p = *vel * dt;
    
    let pos_k2 = *pos + k1p * 0.5;
    let vel_k2 = *vel + k1v * 0.5;
    let r_k2 = length(pos_k2);
    let r2_k2 = r_k2 * r_k2;
    let r3_k2 = r2_k2 * r_k2;
    let mf_k2 = 1.0 - 2.0 * M / r_k2;
    let r_hat_k2 = normalize(pos_k2);
    let v_mag2_k2 = dot(vel_k2, vel_k2);
    let v_rad_k2 = dot(vel_k2, r_hat_k2);
    let v_tan_sq_k2 = v_mag2_k2 - v_rad_k2 * v_rad_k2;
    let a_rad_k2 = M / r2_k2 - (M / r3_k2) * v_tan_sq_k2 / mf_k2;
    let accel_k2 = (a_rad_k2 - v_rad_k2 * v_rad_k2 / r_k2) * r_hat_k2;
    let k2v = accel_k2 * dt;
    let k2p = vel_k2 * dt;
    
    let pos_k3 = *pos + k2p * 0.5;
    let vel_k3 = *vel + k2v * 0.5;
    let r_k3 = length(pos_k3);
    let r2_k3 = r_k3 * r_k3;
    let r3_k3 = r2_k3 * r_k3;
    let mf_k3 = 1.0 - 2.0 * M / r_k3;
    let r_hat_k3 = normalize(pos_k3);
    let v_mag2_k3 = dot(vel_k3, vel_k3);
    let v_rad_k3 = dot(vel_k3, r_hat_k3);
    let v_tan_sq_k3 = v_mag2_k3 - v_rad_k3 * v_rad_k3;
    let a_rad_k3 = M / r2_k3 - (M / r3_k3) * v_tan_sq_k3 / mf_k3;
    let accel_k3 = (a_rad_k3 - v_rad_k3 * v_rad_k3 / r_k3) * r_hat_k3;
    let k3v = accel_k3 * dt;
    let k3p = vel_k3 * dt;
    
    let pos_k4 = *pos + k3p;
    let vel_k4 = *vel + k3v;
    let r_k4 = length(pos_k4);
    let r2_k4 = r_k4 * r_k4;
    let r3_k4 = r2_k4 * r_k4;
    let mf_k4 = 1.0 - 2.0 * M / r_k4;
    let r_hat_k4 = normalize(pos_k4);
    let v_mag2_k4 = dot(vel_k4, vel_k4);
    let v_rad_k4 = dot(vel_k4, r_hat_k4);
    let v_tan_sq_k4 = v_mag2_k4 - v_rad_k4 * v_rad_k4;
    let a_rad_k4 = M / r2_k4 - (M / r3_k4) * v_tan_sq_k4 / mf_k4;
    let accel_k4 = (a_rad_k4 - v_rad_k4 * v_rad_k4 / r_k4) * r_hat_k4;
    let k4v = accel_k4 * dt;
    let k4p = vel_k4 * dt;
    
    *pos = *pos + (k1p + 2.0 * k2p + 2.0 * k3p + k4p) / 6.0;
    *vel = *vel + (k1v + 2.0 * k2v + 2.0 * k3v + k4v) / 6.0;
}

fn trace_ray(ray_dir: vec3<f32>) -> vec3<f32> {
    var pos = vec3<f32>(R_OBS, 0.0, 0.0);
    var vel = ray_dir;
    
    var step_count = 0u;
    var impact_param = length(cross(pos, vel));
    var is_photon_ring = false;
    var captured = false;
    
    loop {
        if (step_count >= RAY_MAX_STEPS) { break; }
        
        let r = length(pos);
        
        if (r <= EVENT_HORIZON) {
            captured = true;
            break;
        }
        
        if (r >= RAY_MAX_RADIUS) {
            break;
        }
        
        let b_ratio = impact_param / B_CRIT;
        if (b_ratio > 1.0 - B_CRIT_TOLERANCE && b_ratio < 1.0 + B_CRIT_TOLERANCE) {
            is_photon_ring = true;
        }
        
        schwarzschild_metric_rk4(&pos, &vel, RAY_STEP_SIZE);
        step_count = step_count + 1u;
    }
    
    if (captured) {
        return vec3<f32>(0.0, 0.0, 0.0);
    }
    
    if (is_photon_ring) {
        return AMBER_PHOTON;
    }
    
    let angle_tol = STAR_SEARCH_ANGLE * PI / 180.0;
    let norm_vel = normalize(vel);
    
    var found_star = false;
    var star_color = DEEP_NAVY;
    
    for (var i = 0u; i < STAR_COUNT; i = i + 1u) {
        let star_pos = get_star_position(i);
        if (ray_sphere_intersect(norm_vel, star_pos, angle_tol)) {
            found_star = true;
            star_color = STAR_WHITE;
            break;
        }
    }
    
    return select(DEEP_NAVY, STAR_WHITE, found_star);
}

fn get_ray_direction(uv: vec2<f32>) -> vec3<f32> {
    let fov_rad = FOV_H * PI / 180.0;
    let tan_half_fov = tan(fov_rad * 0.5);
    
    let aspect = params.resolution.x / params.resolution.y;
    let cam_right = normalize(vec3<f32>(0.0, 1.0, 0.0));
    let cam_up = normalize(vec3<f32>(0.0, 0.0, 1.0));
    let cam_forward = -normalize(vec3<f32>(1.0, 0.0, 0.0));
    
    let px = (uv.x - 0.5) * 2.0 * aspect * tan_half_fov;
    let py = (0.5 - uv.y) * 2.0 * tan_half_fov;
    
    let ray = cam_forward + cam_right * px + cam_up * py;
    return normalize(ray);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let ray_dir = get_ray_direction(uv);
    let color = trace_ray(ray_dir);
    
    return vec4<f32>(color, 1.0);
}