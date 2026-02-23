// Barbell (Dumbbell) Renderer - WGSL
// High-quality metallic barbell with realistic lighting and materials

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

struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
};

struct HitInfo {
    distance: f32,
    position: vec3<f32>,
    normal: vec3<f32>,
    material_id: i32,
};

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k / 6.0;
}

fn sphere_dist(p: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

fn cylinder_dist(p: vec3<f32>, axis: i32, radius: f32) -> f32 {
    var dist_val = 0.0;
    if (axis == 0) {
        dist_val = length(vec2<f32>(p.y, p.z)) - radius;
    } else if (axis == 1) {
        dist_val = length(vec2<f32>(p.x, p.z)) - radius;
    } else {
        dist_val = length(vec2<f32>(p.x, p.y)) - radius;
    }
    return dist_val;
}

fn barbell_dist(p: vec3<f32>) -> f32 {
    let sphere_radius = 0.8;
    let sphere_left_center = vec3<f32>(-2.5, 0.0, 0.0);
    let sphere_right_center = vec3<f32>(2.5, 0.0, 0.0);
    
    let cylinder_radius = 0.3;
    let cylinder_start = -1.7;
    let cylinder_end = 1.7;
    
    let d_left_sphere = sphere_dist(p, sphere_left_center, sphere_radius);
    let d_right_sphere = sphere_dist(p, sphere_right_center, sphere_radius);
    
    var cyl_p = p;
    cyl_p.x = clamp(p.x, cylinder_start, cylinder_end);
    let d_cylinder = cylinder_dist(cyl_p, 0, cylinder_radius);
    
    let k_blend = 2.0;
    var result = smin(d_left_sphere, d_right_sphere, k_blend);
    result = smin(result, d_cylinder, k_blend);
    
    return result;
}

fn get_material_id(p: vec3<f32>) -> i32 {
    let dist_left = length(p - vec3<f32>(-2.5, 0.0, 0.0)) - 0.8;
    let dist_right = length(p - vec3<f32>(2.5, 0.0, 0.0)) - 0.8;
    let dist_cyl = length(vec2<f32>(p.y, p.z)) - 0.3;
    
    if (dist_left < dist_right && dist_left < dist_cyl) {
        return 0;
    } else if (dist_right < dist_cyl) {
        return 1;
    } else {
        return 2;
    }
}

fn estimate_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let n = normalize(vec3<f32>(
        barbell_dist(p + vec3<f32>(eps, 0.0, 0.0)) - barbell_dist(p - vec3<f32>(eps, 0.0, 0.0)),
        barbell_dist(p + vec3<f32>(0.0, eps, 0.0)) - barbell_dist(p - vec3<f32>(0.0, eps, 0.0)),
        barbell_dist(p + vec3<f32>(0.0, 0.0, eps)) - barbell_dist(p - vec3<f32>(0.0, 0.0, eps))
    ));
    return n;
}

fn ray_march(ray: Ray, max_steps: i32, max_distance: f32) -> HitInfo {
    var hit_info = HitInfo(
        max_distance,
        ray.origin,
        vec3<f32>(0.0, 0.0, 1.0),
        -1
    );
    
    var t = 0.0;
    var position = ray.origin;
    
    for (var step = 0; step < max_steps; step = step + 1) {
        position = ray.origin + ray.direction * t;
        let dist = barbell_dist(position);
        
        if (dist < 0.001) {
            hit_info.distance = t;
            hit_info.position = position;
            hit_info.normal = estimate_normal(position);
            hit_info.material_id = get_material_id(position);
            break;
        }
        
        if (t > max_distance) {
            break;
        }
        
        t = t + dist * 0.8;
    }
    
    return hit_info;
}

fn fresnel_schlick(cos_theta: f32, f0: f32) -> f32 {
    return f0 + (1.0 - f0) * pow(max(1.0 - cos_theta, 0.0), 5.0);
}

fn ggx_distribution(n_dot_h: f32, roughness: f32) -> f32 {
    let a = roughness * roughness;
    let a2 = a * a;
    let denom = n_dot_h * n_dot_h * (a2 - 1.0) + 1.0;
    return a2 / (3.14159 * denom * denom);
}

fn schlick_geometry(n_dot_v: f32, roughness: f32) -> f32 {
    let r = (roughness + 1.0) * (roughness + 1.0) / 8.0;
    let denom = n_dot_v * (1.0 - r) + r;
    return n_dot_v / max(denom, 0.001);
}

struct Material {
    base_color: vec3<f32>,
    metalness: f32,
    roughness: f32,
};

fn get_material(material_id: i32) -> Material {
    if (material_id == 0 || material_id == 1) {
        return Material(
            vec3<f32>(0.7, 0.7, 0.8),
            0.9,
            0.15
        );
    } else {
        return Material(
            vec3<f32>(0.65, 0.65, 0.75),
            0.85,
            0.25
        );
    }
}

fn pbr_lighting(
    position: vec3<f32>,
    normal: vec3<f32>,
    view_dir: vec3<f32>,
    material: Material
) -> vec3<f32> {
    var result = vec3<f32>(0.0);
    
    let light1_dir = normalize(vec3<f32>(1.0, 2.0, 1.0));
    let light1_intensity = 0.8;
    let light1_color = vec3<f32>(1.0, 0.98, 0.95);
    
    let light2_pos = vec3<f32>(-3.0, 1.0, 2.0);
    let light2_dir = normalize(light2_pos - position);
    let light2_distance = length(light2_pos - position);
    let light2_intensity = 0.4 / (light2_distance * light2_distance * 0.1 + 1.0);
    let light2_color = vec3<f32>(0.9, 0.95, 1.0);
    
    let light3_dir = normalize(vec3<f32>(-1.0, 0.0, -1.0));
    let light3_intensity = 0.3;
    let light3_color = vec3<f32>(0.95, 0.9, 0.85);
    
    for (var light_idx = 0; light_idx < 3; light_idx = light_idx + 1) {
        var l_dir = light1_dir;
        var l_intensity = light1_intensity;
        var l_color = light1_color;
        
        if (light_idx == 1) {
            l_dir = light2_dir;
            l_intensity = light2_intensity;
            l_color = light2_color;
        } else if (light_idx == 2) {
            l_dir = light3_dir;
            l_intensity = light3_intensity;
            l_color = light3_color;
        }
        
        let h = normalize(view_dir + l_dir);
        let n_dot_l = max(dot(normal, l_dir), 0.0);
        let n_dot_v = max(dot(normal, view_dir), 0.0);
        let n_dot_h = max(dot(normal, h), 0.0);
        
        let d = ggx_distribution(n_dot_h, material.roughness);
        let f = fresnel_schlick(max(dot(h, view_dir), 0.0), 0.04);
        let g = schlick_geometry(n_dot_v, material.roughness);
        
        let spec = (d * f * g) / max(4.0 * n_dot_v * n_dot_l, 0.001);
        let diffuse = (1.0 - f) * material.base_color / 3.14159;
        
        let brdf = select(diffuse, spec + diffuse, material.metalness > 0.5);
        
        result = result + brdf * l_color * l_intensity * n_dot_l;
    }
    
    result = result + material.base_color * 0.1;
    
    return result;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let camera_distance = 7.0;
    let camera_height = 2.5;
    let camera_angle_x = 0.3;
    
    let cos_ax = cos(camera_angle_x);
    let sin_ax = sin(camera_angle_x);
    
    let rotation_angle = params.time / 6.0 * 6.28318;
    let cos_rot = cos(rotation_angle + 0.26179);
    let sin_rot = sin(rotation_angle + 0.26179);
    
    let camera_pos = vec3<f32>(
        camera_distance * cos_rot * cos_ax,
        camera_height,
        camera_distance * sin_rot * cos_ax
    );
    
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let forward = normalize(target_var - camera_pos);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let ray_dir = normalize(forward + right * uv.x * 0.5 + up * uv.y * 0.5);
    let ray = Ray(camera_pos, ray_dir);
    
    let hit = ray_march(ray, 256, 100.0);
    
    var output_color = vec3<f32>(0.0);
    
    if (hit.distance < 99.9) {
        let material = get_material(hit.material_id);
        let view_dir = -ray.direction;
        
        output_color = pbr_lighting(hit.position, hit.normal, view_dir, material);
        
        output_color = output_color / (output_color + vec3<f32>(1.0));
    } else {
        let gradient = 0.9 + 0.1 * ray.direction.y;
        output_color = vec3<f32>(gradient * 0.95, gradient * 0.95, gradient);
    }
    
    output_color = pow(output_color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(output_color, 1.0);
}