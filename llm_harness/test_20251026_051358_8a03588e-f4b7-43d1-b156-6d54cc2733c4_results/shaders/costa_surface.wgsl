// Costa Surface Minimal Renderer
// Weierstrass representation with frosted glass shading and three-point lighting

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
    _padding: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

const LAMBDA: f32 = 0.252;
const MAX_INTEGRATION_STEPS: u32 = 150u;
const INTEGRATION_STEP: f32 = 0.015;
const MAX_RADIUS: f32 = 4.0;
const MAX_RE_INTEGRAL: f32 = 5.0;

fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cdiv(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = dot(b, b);
    return vec2<f32>(dot(a, b), a.y * b.x - a.x * b.y) / denom;
}

fn weierstrass_dh(z: vec2<f32>, dz: vec2<f32>) -> vec2<f32> {
    let z3 = cmul(cmul(z, z), z);
    let denom = z3 - vec2<f32>(1.0, 0.0);
    let frac = cdiv(dz, denom);
    return LAMBDA * frac;
}

fn integrate_surface(theta_idx: u32, radial_idx: u32) -> vec3<f32> {
    let theta_norm = f32(theta_idx) / 300.0;
    let radial_norm = f32(radial_idx) / 450.0;
    
    let theta = 2.0 * 3.14159265359 * theta_norm;
    let r_param = radial_norm * MAX_RADIUS;
    
    let angle_hex = theta;
    let r_hex = r_param;
    let z_start = r_hex * vec2<f32>(cos(angle_hex), sin(angle_hex));
    
    var z = z_start;
    var integral = vec3<f32>(0.0, 0.0, 0.0);
    var step_count = 0u;
    
    loop {
        if (step_count >= MAX_INTEGRATION_STEPS) { break; }
        if (length(z) > MAX_RADIUS) { break; }
        if (abs(integral.x) > MAX_RE_INTEGRAL) { break; }
        
        let dz_mag = INTEGRATION_STEP;
        let dz_angle = theta + 0.1 * f32(step_count);
        let dz = dz_mag * vec2<f32>(cos(dz_angle), sin(dz_angle));
        
        let dh = weierstrass_dh(z, dz);
        
        integral = integral + vec3<f32>(dz.x, dh.x, dh.y);
        z = z + dz;
        step_count = step_count + 1u;
    }
    
    return integral;
}

fn compute_mean_curvature(pos: vec3<f32>, theta_idx: u32, radial_idx: u32) -> f32 {
    let p_right = integrate_surface(theta_idx + 1u, radial_idx);
    let p_up = integrate_surface(theta_idx, radial_idx + 1u);
    
    let du = p_right - pos;
    let dv = p_up - pos;
    
    let du_len = length(du);
    let dv_len = length(dv);
    
    if (du_len < 1e-6 || dv_len < 1e-6) {
        return 0.0;
    }
    
    let kappa1 = 1.0 / (du_len + 0.001);
    let kappa2 = 1.0 / (dv_len + 0.001);
    let H = 0.5 * (kappa1 + kappa2);
    
    return H;
}

fn compute_lighting(pos: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
    let key_light = vec3<f32>(4.0, 4.0, 6.0);
    let fill_light = vec3<f32>(-6.0, -2.0, 5.0);
    let rim_light = vec3<f32>(0.0, 0.0, 8.0);
    
    let key_dir = normalize(key_light - pos);
    let fill_dir = normalize(fill_light - pos);
    let rim_dir = normalize(rim_light - pos);
    
    let key_contrib = max(0.0, dot(normal, key_dir)) * vec3<f32>(1.0, 1.0, 1.0);
    let fill_contrib = max(0.0, dot(normal, fill_dir)) * vec3<f32>(1.0, 1.0, 1.0) * 0.5;
    let rim_contrib = max(0.0, dot(normal, rim_dir)) * vec3<f32>(1.0, 1.0, 1.0) * 0.7;
    
    return key_contrib + fill_contrib + rim_contrib;
}

fn compute_material(pos: vec3<f32>, normal: vec3<f32>, H: f32) -> vec3<f32> {
    let base_material = vec3<f32>(0.85, 0.88, 0.92);
    let curvature_tint = vec3<f32>(0.333, 1.0, 0.533);
    
    let curvature_factor = smoothstep(0.0, 0.001, abs(H));
    let material_color = mix(base_material, curvature_tint, curvature_factor * 0.2);
    
    return material_color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    
    let theta_idx = u32(uv.x * 300.0) % 300u;
    let radial_idx = u32(uv.y * 450.0) % 450u;
    
    let surface_pos = integrate_surface(theta_idx, radial_idx);
    
    let H = compute_mean_curvature(surface_pos, theta_idx, radial_idx);
    
    let p_theta = integrate_surface(theta_idx + 1u, radial_idx);
    let p_radial = integrate_surface(theta_idx, radial_idx + 1u);
    
    let tangent_theta = normalize(p_theta - surface_pos);
    let tangent_radial = normalize(p_radial - surface_pos);
    let normal = normalize(cross(tangent_theta, tangent_radial));
    
    let lighting = compute_lighting(surface_pos, normal);
    
    let material = compute_material(surface_pos, normal, H);
    
    let lit_material = material * (0.8 + 0.2 * lighting);
    
    let view_dir = normalize(vec3<f32>(6.0, 4.0, 3.0) - surface_pos);
    let fresnel = pow(1.0 - max(0.0, dot(normal, view_dir)), 5.0);
    
    let final_color = mix(lit_material, vec3<f32>(1.0), fresnel * 0.3);
    
    let focal_dist = 5.0;
    let focus_blur = smoothstep(4.0, 6.0, length(surface_pos));
    let defocused = mix(final_color, vec3<f32>(0.5), focus_blur * 0.15);
    
    return vec4<f32>(defocused, 1.0);
}