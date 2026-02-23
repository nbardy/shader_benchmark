// Helical Twist Deformation - Twisted Cube with Advanced Rendering
// Full 3D ray marching with signed distance fields, metallic materials, and multi-light shading

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

// ============================================================================
// CORE MATHEMATICAL PRIMITIVES
// ============================================================================

fn twist_transform(p: vec3<f32>, k: f32) -> vec3<f32> {
    let theta = k * p.z;
    let cos_theta = cos(theta);
    let sin_theta = sin(theta);
    let x_rot = p.x * cos_theta - p.y * sin_theta;
    let y_rot = p.x * sin_theta + p.y * cos_theta;
    return vec3<f32>(x_rot, y_rot, p.z);
}

fn inverse_twist_transform(p: vec3<f32>, k: f32) -> vec3<f32> {
    let theta = k * p.z;
    let cos_theta = cos(theta);
    let sin_theta = sin(theta);
    let x_rot = p.x * cos_theta + p.y * sin_theta;
    let y_rot = -p.x * sin_theta + p.y * cos_theta;
    return vec3<f32>(x_rot, y_rot, p.z);
}

// Signed distance field for unit cube with beveling
fn cube_sdf(p: vec3<f32>, bevel_radius: f32) -> f32 {
    let abs_p = abs(p);
    let q = abs_p - vec3<f32>(1.0, 1.0, 1.0);
    let outer = length(max(q, vec3<f32>(0.0, 0.0, 0.0)));
    let inner = min(max(q.x, max(q.y, q.z)), 0.0);
    return outer + inner - bevel_radius;
}

// SDF for twisted cube via inverse transform
fn twisted_cube_sdf(p: vec3<f32>, k: f32, bevel_radius: f32) -> f32 {
    let p_untwisted = inverse_twist_transform(p, k);
    return cube_sdf(p_untwisted, bevel_radius);
}

// ============================================================================
// RAY MARCHING ENGINE
// ============================================================================

struct RayMarchResult {
    distance: f32,
    steps: u32,
    hit: bool,
};

fn ray_march(ray_origin: vec3<f32>, ray_dir: vec3<f32>, k: f32, max_dist: f32, max_steps: u32) -> RayMarchResult {
    var t = 0.0;
    var steps = 0u;
    let bevel_radius = 0.05;
    let min_step = 0.0001;
    
    loop {
        if (steps >= max_steps || t > max_dist) { break; }
        
        let p = ray_origin + ray_dir * t;
        let d = twisted_cube_sdf(p, k, bevel_radius);
        
        if (d < 0.001) {
            return RayMarchResult(t, steps, true);
        }
        
        t = t + max(d, min_step);
        steps = steps + 1u;
    }
    
    return RayMarchResult(t, steps, false);
}

// ============================================================================
// NORMAL ESTIMATION & LIGHTING
// ============================================================================

fn compute_normal(p: vec3<f32>, k: f32) -> vec3<f32> {
    let eps = 0.001;
    let bevel_radius = 0.05;
    
    let f0 = twisted_cube_sdf(p, k, bevel_radius);
    let fx = twisted_cube_sdf(p + vec3<f32>(eps, 0.0, 0.0), k, bevel_radius);
    let fy = twisted_cube_sdf(p + vec3<f32>(0.0, eps, 0.0), k, bevel_radius);
    let fz = twisted_cube_sdf(p + vec3<f32>(0.0, 0.0, eps), k, bevel_radius);
    
    let grad = vec3<f32>(fx - f0, fy - f0, fz - f0);
    return normalize(grad);
}

fn fresnel_schlick(cos_theta: f32, f0: f32) -> f32 {
    let clipped_cos = clamp(cos_theta, 0.0, 1.0);
    return f0 + (1.0 - f0) * pow(1.0 - clipped_cos, 5.0);
}

fn compute_lighting(p: vec3<f32>, normal: vec3<f32>, viewer: vec3<f32>, k: f32) -> vec3<f32> {
    let view_dir = normalize(viewer - p);
    
    // Three-point lighting setup
    let key_light_pos = vec3<f32>(2.0, 3.0, 1.0);
    let fill_light_pos = vec3<f32>(-1.0, 1.0, 2.0);
    let rim_light_pos = vec3<f32>(0.0, -2.0, -1.0);
    
    let key_light_dir = normalize(key_light_pos - p);
    let fill_light_dir = normalize(fill_light_pos - p);
    let rim_light_dir = normalize(rim_light_pos - p);
    
    // Key light
    let key_diffuse = max(dot(normal, key_light_dir), 0.0);
    let key_specular = pow(max(dot(view_dir, reflect(-key_light_dir, normal)), 0.0), 32.0);
    let key_contrib = vec3<f32>(0.9, 0.85, 0.7) * (key_diffuse * 0.6 + key_specular * 0.4);
    
    // Fill light
    let fill_diffuse = max(dot(normal, fill_light_dir), 0.0);
    let fill_contrib = vec3<f32>(0.4, 0.5, 0.6) * fill_diffuse * 0.4;
    
    // Rim light
    let rim_dot = max(dot(normal, rim_light_dir), 0.0);
    let rim_contrib = vec3<f32>(1.0, 0.9, 0.5) * pow(1.0 - abs(dot(normal, view_dir)), 2.0) * rim_dot * 0.3;
    
    // Height-based color gradient: deep blue to golden yellow
    let height = (p.y + 1.0) / 2.0;
    let base_color = mix(
        vec3<f32>(0.0, 0.1, 0.3),     // Deep blue (bottom)
        vec3<f32>(1.0, 0.85, 0.1),    // Golden yellow (top)
        clamp(height, 0.0, 1.0)
    );
    
    // Fresnel metallic effect
    let fresnel = fresnel_schlick(dot(view_dir, normal), 0.04);
    let metallic_color = mix(base_color, vec3<f32>(1.0, 1.0, 1.0), fresnel * 0.5);
    
    return (key_contrib + fill_contrib + rim_contrib) * metallic_color;
}

fn shadow_test(p: vec3<f32>, light_dir: vec3<f32>, k: f32) -> f32 {
    var shadow = 0.0;
    let bevel_radius = 0.05;
    var t = 0.01;
    let max_t = 10.0;
    
    for (var i = 0u; i < 32u; i = i + 1u) {
        if (t > max_t) { break; }
        let sample_p = p + light_dir * t;
        let d = twisted_cube_sdf(sample_p, k, bevel_radius);
        if (d < 0.01) {
            shadow = shadow + 1.0;
            break;
        }
        t = t + 0.1;
    }
    
    return 1.0 - shadow * 0.3;
}

// ============================================================================
// CAMERA & RAY GENERATION
// ============================================================================

fn generate_ray(uv: vec2<f32>, fov: f32) -> vec3<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let half_fov = fov * 0.5;
    let y = tan(half_fov) * (uv.y - 0.5) * 2.0;
    let x = tan(half_fov) * (uv.x - 0.5) * 2.0 * aspect;
    return normalize(vec3<f32>(x, y, 1.0));
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    
    // Background color
    let bg_color = vec3<f32>(0.1, 0.1, 0.12);
    
    // Camera setup
    let camera_pos = vec3<f32>(3.0, 2.0, 4.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let camera_forward = normalize(camera_target - camera_pos);
    let camera_right = normalize(cross(camera_forward, vec3<f32>(0.0, 1.0, 0.0)));
    let camera_up = cross(camera_right, camera_forward);
    
    // Ray generation (FOV = 35°)
    let fov_rad = 35.0 * 3.14159 / 180.0;
    let local_ray = generate_ray(uv, fov_rad);
    let ray_dir = normalize(
        local_ray.x * camera_right +
        local_ray.y * camera_up +
        local_ray.z * camera_forward
    );
    
    // Twist parameter: 2π for full rotation over height
    let k = 6.28318;
    
    // Ray marching
    let result = ray_march(camera_pos, ray_dir, k, 50.0, 256u);
    
    var final_color = bg_color;
    
    if (result.hit) {
        let hit_point = camera_pos + ray_dir * result.distance;
        let normal = compute_normal(hit_point, k);
        
        // Compute lighting with shadows
        let key_light_pos = vec3<f32>(2.0, 3.0, 1.0);
        let key_light_dir = normalize(key_light_pos - hit_point);
        let shadow_factor = shadow_test(hit_point, key_light_dir, k);
        
        let lit_color = compute_lighting(hit_point, normal, camera_pos, k);
        final_color = lit_color * shadow_factor;
    }
    
    // Gamma correction
    let gamma = 2.2;
    final_color = pow(final_color, vec3<f32>(1.0 / gamma, 1.0 / gamma, 1.0 / gamma));
    
    return vec4<f32>(final_color, 1.0);
}