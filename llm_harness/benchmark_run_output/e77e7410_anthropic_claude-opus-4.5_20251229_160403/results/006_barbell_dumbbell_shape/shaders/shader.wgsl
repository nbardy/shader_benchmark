// Barbell (dumbbell) visualization with raymarching
// Two spheres connected by a cylindrical shaft with metallic PBR rendering

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

// Constants
const PI: f32 = 3.14159265359;
const SPHERE_RADIUS: f32 = 0.8;
const SPHERE_DISTANCE: f32 = 2.5;
const CYLINDER_RADIUS: f32 = 0.3;
const CYLINDER_HALF_LENGTH: f32 = 1.7;
const BLEND_FACTOR: f32 = 2.0;

// Smooth minimum using exponential
fn smin_exp(d1: f32, d2: f32, k: f32) -> f32 {
    let e1 = exp(-k * d1);
    let e2 = exp(-k * d2);
    return -log(e1 + e2) / k;
}

// SDF for sphere
fn sd_sphere(p: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

// SDF for capped cylinder along X axis
fn sd_cylinder_x(p: vec3<f32>, half_length: f32, radius: f32) -> f32 {
    let d_radial = length(p.yz) - radius;
    let d_caps = abs(p.x) - half_length;
    return min(max(d_radial, d_caps), 0.0) + length(vec2<f32>(max(d_radial, 0.0), max(d_caps, 0.0)));
}

// Combined barbell SDF with smooth blending
fn sd_barbell(p: vec3<f32>) -> f32 {
    let sphere1 = sd_sphere(p, vec3<f32>(-SPHERE_DISTANCE, 0.0, 0.0), SPHERE_RADIUS);
    let sphere2 = sd_sphere(p, vec3<f32>(SPHERE_DISTANCE, 0.0, 0.0), SPHERE_RADIUS);
    let cylinder = sd_cylinder_x(p, CYLINDER_HALF_LENGTH, CYLINDER_RADIUS);
    
    // Blend cylinder with spheres
    let blended_cyl_s1 = smin_exp(cylinder, sphere1, BLEND_FACTOR);
    let blended = smin_exp(blended_cyl_s1, sphere2, BLEND_FACTOR);
    
    return blended;
}

// Get material ID (0 = sphere region, 1 = cylinder region)
fn get_material(p: vec3<f32>) -> f32 {
    let sphere1_dist = sd_sphere(p, vec3<f32>(-SPHERE_DISTANCE, 0.0, 0.0), SPHERE_RADIUS);
    let sphere2_dist = sd_sphere(p, vec3<f32>(SPHERE_DISTANCE, 0.0, 0.0), SPHERE_RADIUS);
    let cylinder_dist = sd_cylinder_x(p, CYLINDER_HALF_LENGTH, CYLINDER_RADIUS);
    
    let min_sphere = min(sphere1_dist, sphere2_dist);
    return select(0.0, 1.0, cylinder_dist < min_sphere);
}

// Calculate normal via gradient
fn calc_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let dx = sd_barbell(p + vec3<f32>(eps, 0.0, 0.0)) - sd_barbell(p - vec3<f32>(eps, 0.0, 0.0));
    let dy = sd_barbell(p + vec3<f32>(0.0, eps, 0.0)) - sd_barbell(p - vec3<f32>(0.0, eps, 0.0));
    let dz = sd_barbell(p + vec3<f32>(0.0, 0.0, eps)) - sd_barbell(p - vec3<f32>(0.0, 0.0, eps));
    return normalize(vec3<f32>(dx, dy, dz));
}

// Rotation matrix around Y axis
fn rotate_y(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

// Rotation matrix around Z axis
fn rotate_z(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

// Fresnel-Schlick approximation
fn fresnel_schlick(cos_theta: f32, f0: vec3<f32>) -> vec3<f32> {
    return f0 + (vec3<f32>(1.0) - f0) * pow(1.0 - cos_theta, 5.0);
}

// GGX normal distribution
fn distribution_ggx(n_dot_h: f32, roughness: f32) -> f32 {
    let a = roughness * roughness;
    let a2 = a * a;
    let n_dot_h2 = n_dot_h * n_dot_h;
    let denom = n_dot_h2 * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

// Geometry function (Smith's method)
fn geometry_smith(n_dot_v: f32, n_dot_l: f32, roughness: f32) -> f32 {
    let r = roughness + 1.0;
    let k = (r * r) / 8.0;
    let ggx_v = n_dot_v / (n_dot_v * (1.0 - k) + k);
    let ggx_l = n_dot_l / (n_dot_l * (1.0 - k) + k);
    return ggx_v * ggx_l;
}

// PBR lighting calculation
fn pbr_lighting(
    normal: vec3<f32>,
    view_dir: vec3<f32>,
    light_dir: vec3<f32>,
    light_color: vec3<f32>,
    albedo: vec3<f32>,
    metalness: f32,
    roughness: f32
) -> vec3<f32> {
    let h = normalize(view_dir + light_dir);
    
    let n_dot_l = max(dot(normal, light_dir), 0.0);
    let n_dot_v = max(dot(normal, view_dir), 0.001);
    let n_dot_h = max(dot(normal, h), 0.0);
    let v_dot_h = max(dot(view_dir, h), 0.0);
    
    let f0 = mix(vec3<f32>(0.04), albedo, metalness);
    
    let d = distribution_ggx(n_dot_h, roughness);
    let g = geometry_smith(n_dot_v, n_dot_l, roughness);
    let f = fresnel_schlick(v_dot_h, f0);
    
    let specular = (d * g * f) / (4.0 * n_dot_v * n_dot_l + 0.001);
    let diffuse = (vec3<f32>(1.0) - f) * (1.0 - metalness) * albedo / PI;
    
    return (diffuse + specular) * light_color * n_dot_l;
}

// Soft shadow calculation
fn calc_soft_shadow(ro: vec3<f32>, rd: vec3<f32>, mint: f32, maxt: f32, k: f32) -> f32 {
    var res: f32 = 1.0;
    var t: f32 = mint;
    
    for (var i: i32 = 0; i < 32; i = i + 1) {
        if (t >= maxt) { break; }
        let h = sd_barbell(ro + rd * t);
        if (h < 0.001) { return 0.0; }
        res = min(res, k * h / t);
        t = t + h;
    }
    
    return clamp(res, 0.0, 1.0);
}

// Ambient occlusion
fn calc_ao(p: vec3<f32>, n: vec3<f32>) -> f32 {
    var occ: f32 = 0.0;
    var sca: f32 = 1.0;
    
    for (var i: i32 = 0; i < 5; i = i + 1) {
        let h = 0.01 + 0.12 * f32(i);
        let d = sd_barbell(p + h * n);
        occ = occ + (h - d) * sca;
        sca = sca * 0.95;
    }
    
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

// Brushed metal texture for cylinder
fn brushed_metal_texture(p: vec3<f32>, n: vec3<f32>) -> f32 {
    let angle = atan2(p.z, p.y);
    let noise = sin(p.x * 50.0) * 0.5 + 0.5;
    let lines = sin(angle * 100.0 + noise * 10.0) * 0.5 + 0.5;
    return mix(0.8, 1.0, lines * 0.3 + 0.7);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let uv = (pos.xy - 0.5 * res) / min(res.x, res.y);
    
    // Time simulation (static for single image)
    let time: f32 = 0.0;
    
    // Camera setup
    let cam_pos = vec3<f32>(4.0, 3.0, 5.0);
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_up = vec3<f32>(0.0, 1.0, 0.0);
    
    let cam_fwd = normalize(cam_target - cam_pos);
    let cam_right = normalize(cross(cam_fwd, cam_up));
    let cam_up_actual = cross(cam_right, cam_fwd);
    
    // Ray direction
    let rd = normalize(cam_fwd * 1.5 + cam_right * uv.x + cam_up_actual * uv.y);
    let ro = cam_pos;
    
    // Object rotation matrices
    let tilt_angle = 15.0 * PI / 180.0;
    let rotation_angle = time * PI / 3.0; // 1 rev per 6 seconds
    let rot_tilt = rotate_z(tilt_angle);
    let rot_y = rotate_y(rotation_angle);
    let total_rot = rot_y * rot_tilt;
    let inv_rot = transpose(total_rot);
    
    // Background gradient
    let bg_center = length(uv);
    let bg_color = mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0, 1.0, 1.0), bg_center * 0.5);
    
    // Raymarching
    var t: f32 = 0.0;
    var hit: bool = false;
    var hit_pos: vec3<f32> = vec3<f32>(0.0);
    
    for (var i: i32 = 0; i < 128; i = i + 1) {
        let p = ro + rd * t;
        let p_local = inv_rot * p;
        let d = sd_barbell(p_local);
        
        if (d < 0.001) {
            hit = true;
            hit_pos = p;
            break;
        }
        
        if (t > 20.0) { break; }
        t = t + d;
    }
    
    var final_color = bg_color;
    
    if (hit) {
        let p_local = inv_rot * hit_pos;
        let n_local = calc_normal(p_local);
        let n = total_rot * n_local;
        let v = normalize(ro - hit_pos);
        
        // Get material
        let mat_id = get_material(p_local);
        
        // Material properties
        var albedo: vec3<f32>;
        var metalness: f32;
        var roughness: f32;
        
        if (mat_id < 0.5) {
            // Sphere: polished chrome
            albedo = vec3<f32>(0.7, 0.7, 0.8);
            metalness = 0.95;
            roughness = 0.15;
        } else {
            // Cylinder: brushed metal
            let brush = brushed_metal_texture(p_local, n_local);
            albedo = vec3<f32>(0.65, 0.65, 0.75) * brush;
            metalness = 0.85;
            roughness = 0.3;
        }
        
        // Lighting
        var color = vec3<f32>(0.0);
        
        // Primary directional light
        let light1_dir = normalize(vec3<f32>(1.0, 2.0, 1.0));
        let light1_color = vec3<f32>(1.0, 0.98, 0.95) * 0.8;
        let shadow1 = calc_soft_shadow(hit_pos + n * 0.01, light1_dir, 0.02, 10.0, 16.0);
        color = color + pbr_lighting(n, v, light1_dir, light1_color * shadow1, albedo, metalness, roughness);
        
        // Fill light (point light approximated as directional)
        let fill_pos = vec3<f32>(-3.0, 1.0, 2.0);
        let light2_dir = normalize(fill_pos - hit_pos);
        let light2_color = vec3<f32>(0.9, 0.95, 1.0) * 0.4;
        let shadow2 = calc_soft_shadow(hit_pos + n * 0.01, light2_dir, 0.02, 10.0, 8.0);
        color = color + pbr_lighting(n, v, light2_dir, light2_color * shadow2, albedo, metalness, roughness);
        
        // Rim light
        let light3_dir = normalize(vec3<f32>(-1.0, 0.0, -1.0));
        let light3_color = vec3<f32>(1.0, 1.0, 1.0) * 0.3;
        color = color + pbr_lighting(n, v, light3_dir, light3_color, albedo, metalness, roughness);
        
        // Ambient / environment reflection
        let ao = calc_ao(p_local, n_local);
        let ambient = vec3<f32>(0.15, 0.15, 0.18) * albedo * ao;
        
        // Environment reflection
        let refl_dir = reflect(-v, n);
        let env_y = refl_dir.y * 0.5 + 0.5;
        let env_color = mix(vec3<f32>(0.8, 0.85, 0.9), vec3<f32>(1.0, 1.0, 1.0), env_y);
        let fresnel = fresnel_schlick(max(dot(n, v), 0.0), mix(vec3<f32>(0.04), albedo, metalness));
        let reflection = env_color * fresnel * (1.0 - roughness) * 0.5;
        
        color = color + ambient + reflection;
        
        // Tone mapping
        color = color / (color + vec3<f32>(1.0));
        color = pow(color, vec3<f32>(1.0 / 2.2));
        
        final_color = color;
    }
    
    return vec4<f32>(final_color, 1.0);
}