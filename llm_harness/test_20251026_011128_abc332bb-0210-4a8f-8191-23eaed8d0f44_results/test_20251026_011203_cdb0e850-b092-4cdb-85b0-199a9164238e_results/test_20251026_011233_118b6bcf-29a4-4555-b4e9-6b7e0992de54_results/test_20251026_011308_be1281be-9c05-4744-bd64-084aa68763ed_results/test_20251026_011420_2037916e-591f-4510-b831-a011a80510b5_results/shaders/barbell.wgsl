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
    _pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn smin(d1: f32, d2: f32, k: f32) -> f32 {
    let a = -k * d1;
    let b = -k * d2;
    let maxab = max(a, b);
    return -log(exp(a - maxab) + exp(b - maxab)) / k + maxab / k;
}

fn sphere_dist(p: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

fn cylinder_dist(p: vec3<f32>, axis: vec3<f32>, radius: f32, h_start: f32, h_end: f32) -> f32 {
    let proj = dot(p, axis);
    let h = clamp(proj, h_start, h_end);
    let closest = h * axis;
    let to_axis = p - closest;
    return length(to_axis) - radius;
}

fn barbell_distance(p: vec3<f32>) -> f32 {
    let sphere_radius = 0.8;
    let cylinder_radius = 0.3;
    let blend_k = 2.0;
    
    let left_sphere = sphere_dist(p, vec3<f32>(-2.5, 0.0, 0.0), sphere_radius);
    let right_sphere = sphere_dist(p, vec3<f32>(2.5, 0.0, 0.0), sphere_radius);
    let cylinder = cylinder_dist(p, vec3<f32>(1.0, 0.0, 0.0), cylinder_radius, -1.7, 1.7);
    
    let blend1 = smin(left_sphere, cylinder, blend_k);
    let blend2 = smin(blend1, right_sphere, blend_k);
    
    return blend2;
}

fn normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.0001;
    let dx = barbell_distance(p + vec3<f32>(eps, 0.0, 0.0)) - barbell_distance(p - vec3<f32>(eps, 0.0, 0.0));
    let dy = barbell_distance(p + vec3<f32>(0.0, eps, 0.0)) - barbell_distance(p - vec3<f32>(0.0, eps, 0.0));
    let dz = barbell_distance(p + vec3<f32>(0.0, 0.0, eps)) - barbell_distance(p - vec3<f32>(0.0, 0.0, eps));
    return normalize(vec3<f32>(dx, dy, dz));
}

fn rotate_y(v: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(v.x * c + v.z * s, v.y, -v.x * s + v.z * c);
}

fn rotate_z(v: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(v.x * c - v.y * s, v.x * s + v.y * c, v.z);
}

fn raycast(ro: vec3<f32>, rd: vec3<f32>) -> f32 {
    var t = 0.0;
    var hit = false;
    for (var i = 0u; i < 128u; i = i + 1u) {
        let p = ro + rd * t;
        let d = barbell_distance(p);
        if (d < 0.001 || t > 100.0) {
            hit = true;
            break;
        }
        t = t + d * 0.8;
    }
    if (hit && t < 100.0) {
        return t;
    }
    return -1.0;
}

fn pbr_shade(n: vec3<f32>, v: vec3<f32>, l: vec3<f32>, albedo: vec3<f32>, metalness: f32, roughness: f32) -> vec3<f32> {
    let h = normalize(l + v);
    let nh = max(dot(n, h), 0.0);
    let nl = max(dot(n, l), 0.0);
    
    let spec = pow(nh, 1.0 / (roughness * roughness + 0.001));
    let diffuse = mix(albedo / 3.14159, vec3<f32>(0.0), metalness);
    
    return (diffuse + vec3<f32>(spec) * mix(vec3<f32>(0.04), albedo, metalness)) * nl;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let fov = 1.0;
    let cam_dist = 5.5;
    let cam_angle_y = params.time * 0.261799;
    let cam_angle_z = 0.261799;
    
    var cam_pos = vec3<f32>(0.0, 3.0, cam_dist);
    cam_pos = rotate_y(cam_pos, cam_angle_y);
    cam_pos = rotate_z(cam_pos, cam_angle_z);
    
    let target = rotate_z(rotate_y(vec3<f32>(0.0, 0.0, 0.0), cam_angle_y), cam_angle_z);
    let forward = normalize(target - cam_pos);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let ray_dir = normalize(forward + right * uv.x * fov + up * uv.y * fov);
    
    let t = raycast(cam_pos, ray_dir);
    
    if (t < 0.0) {
        let sky_gradient = mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0, 1.0, 1.0), 0.5 + uv.y * 0.5);
        return vec4<f32>(sky_gradient, 1.0);
    }
    
    let hit_pos = cam_pos + ray_dir * t;
    let n = normal(hit_pos);
    let v = normalize(cam_pos - hit_pos);
    
    let light1_dir = normalize(vec3<f32>(1.0, 2.0, 1.0));
    let light2_dir = normalize(vec3<f32>(-3.0, 1.0, 2.0));
    let light3_dir = normalize(vec3<f32>(-1.0, 0.0, -1.0));
    
    let metalness = 0.9;
    let roughness = 0.2;
    let base_color = vec3<f32>(0.7, 0.7, 0.8);
    
    let color = pbr_shade(n, v, light1_dir, base_color, metalness, roughness) * 0.8 +
                pbr_shade(n, v, light2_dir, base_color, metalness, roughness) * 0.4 +
                pbr_shade(n, v, light3_dir, base_color, metalness, roughness) * 0.3;
    
    let reflection = reflect(ray_dir, n);
    let fresnel = mix(0.04, 1.0, pow(1.0 - dot(v, n), 5.0));
    let final_color = mix(color, vec3<f32>(1.0), fresnel * metalness * 0.3);
    
    return vec4<f32>(final_color, 1.0);
}