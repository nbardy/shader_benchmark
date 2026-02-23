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

fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn csq(z: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y);
}

fn cpow5(z: vec2<f32>) -> vec2<f32> {
    let z2 = csq(z);
    let z4 = csq(z2);
    return cmul(z4, z);
}

fn evaluateCYValue(p: vec3<f32>) -> f32 {
    let psi = 0.4;
    let epsilon = 1e-5;
    let r = length(p);
    let safe_r = select(1.0, r, r > epsilon);
    let p_norm = p / safe_r;
    
    let denom = 1.0 - p_norm.z + epsilon;
    let z0 = vec2<f32>(p_norm.x, p_norm.y) / denom;
    let z1 = vec2<f32>(p_norm.y, -p_norm.x) / denom;
    let z2 = vec2<f32>(p_norm.z, 0.0) / denom;
    
    let z0_5 = cpow5(z0);
    let z1_5 = cpow5(z1);
    let z2_5 = cpow5(z2);
    let sum_5 = z0_5 + z1_5 + z2_5;
    
    let prod = cmul(cmul(z0, z1), z2);
    return sum_5.x - 5.0 * psi * prod.x;
}

fn viridis(t: f32) -> vec3<f32> {
    let tc = clamp(t, 0.0, 1.0);
    let seg = floor(tc * 4.0);
    let local_t = (tc * 4.0) % 1.0;
    
    if (seg < 1.0) {
        return mix(vec3<f32>(0.267, 0.005, 0.329), vec3<f32>(0.283, 0.140, 0.469), local_t);
    } else if (seg < 2.0) {
        return mix(vec3<f32>(0.283, 0.140, 0.469), vec3<f32>(0.254, 0.265, 0.530), local_t);
    } else if (seg < 3.0) {
        return mix(vec3<f32>(0.254, 0.265, 0.530), vec3<f32>(0.207, 0.372, 0.554), local_t);
    } else {
        return mix(vec3<f32>(0.207, 0.372, 0.554), vec3<f32>(0.993, 0.906, 0.144), local_t);
    }
}

fn rayMarch(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec4<f32> {
    var t = 0.1;
    let max_dist = 10.0;
    
    var i = 0i32;
    loop {
        if (i >= 128i32 || t >= max_dist) { break; }
        
        let pos = ray_origin + ray_dir * t;
        let value = evaluateCYValue(pos);
        let dist = abs(value);
        
        if (dist < 0.01) {
            let delta = 1e-4;
            let dx = evaluateCYValue(pos + vec3<f32>(delta, 0.0, 0.0));
            let dy = evaluateCYValue(pos + vec3<f32>(0.0, delta, 0.0));
            let dz = evaluateCYValue(pos + vec3<f32>(0.0, 0.0, delta));
            
            let normal = normalize(vec3<f32>(dx - value, dy - value, dz - value) / delta);
            
            let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
            let view_dir = normalize(-ray_dir);
            let half_dir = normalize(light_dir + view_dir);
            
            let ambient = 0.3;
            let diffuse = 0.5 * max(0.0, dot(normal, light_dir));
            let specular = 0.2 * pow(max(0.0, dot(normal, half_dir)), 128.0);
            
            let intensity = ambient + diffuse + specular;
            let normal_dot = dot(normal, normalize(vec3<f32>(0.3, 0.7, 0.6)));
            let color = viridis((normal_dot + 1.0) * 0.5);
            
            return vec4<f32>(color * intensity, 1.0);
        }
        
        t = t + max(0.01, dist * 0.8);
        i = i + 1i32;
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let cam_pos = vec3<f32>(4.0, 4.0, 4.0);
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_up = vec3<f32>(0.0, 1.0, 0.0);
    
    let cam_z = normalize(cam_pos - cam_target);
    let cam_x = normalize(cross(cam_up, cam_z));
    let cam_y = cross(cam_z, cam_x);
    
    let fov = 35.0 * 3.14159265 / 180.0;
    let focal_length = 1.0 / tan(fov * 0.5);
    
    let ray_dir = normalize(cam_x * uv.x + cam_y * uv.y - cam_z * focal_length);
    
    let result = rayMarch(cam_pos, ray_dir);
    let bg = vec3<f32>(0.0, 0.0625, 0.09375);
    let final_color = select(bg, result.xyz, result.w > 0.5);
    
    return vec4<f32>(final_color, 1.0);
}