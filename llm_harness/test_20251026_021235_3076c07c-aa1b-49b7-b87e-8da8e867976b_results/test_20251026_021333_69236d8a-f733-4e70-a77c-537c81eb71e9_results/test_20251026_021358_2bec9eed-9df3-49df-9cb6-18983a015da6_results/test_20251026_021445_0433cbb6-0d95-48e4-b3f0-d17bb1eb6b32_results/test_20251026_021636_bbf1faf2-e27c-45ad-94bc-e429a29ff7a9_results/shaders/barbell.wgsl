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

fn smin(d1: f32, d2: f32, k: f32) -> f32 {
    let h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
    return mix(d2, d1, h) - k * h * (1.0 - h);
}

fn sdSphere(p: vec3<f32>, r: f32) -> f32 {
    return length(p) - r;
}

fn sdCylinder(p: vec3<f32>, h: f32, r: f32) -> f32 {
    let d = abs(vec2<f32>(length(p.yz), p.x)) - vec2<f32>(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

fn barbell_distance(p: vec3<f32>) -> f32 {
    let left_sphere = sdSphere(p - vec3<f32>(-2.5, 0.0, 0.0), 0.8);
    let right_sphere = sdSphere(p - vec3<f32>(2.5, 0.0, 0.0), 0.8);
    let cylinder = sdCylinder(p, 1.7, 0.3);
    
    let blended = smin(left_sphere, right_sphere, 2.0);
    return smin(blended, cylinder, 2.0);
}

fn calculate_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let dx = barbell_distance(p + vec3<f32>(eps, 0.0, 0.0)) - barbell_distance(p - vec3<f32>(eps, 0.0, 0.0));
    let dy = barbell_distance(p + vec3<f32>(0.0, eps, 0.0)) - barbell_distance(p - vec3<f32>(0.0, eps, 0.0));
    let dz = barbell_distance(p + vec3<f32>(0.0, 0.0, eps)) - barbell_distance(p - vec3<f32>(0.0, 0.0, eps));
    return normalize(vec3<f32>(dx, dy, dz));
}

fn raymarch(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var t = 0.0;
    var hit = false;
    
    for (var i = 0u; i < 128u; i = i + 1u) {
        let p = ro + rd * t;
        let d = barbell_distance(p);
        
        if (d < 0.001) {
            hit = true;
            break;
        }
        
        if (t > 50.0) {
            break;
        }
        
        t = t + d * 0.8;
    }
    
    if (hit) {
        let p = ro + rd * t;
        let nor = calculate_normal(p);
        return vec4<f32>(nor, t);
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, -1.0);
}

fn pbr_lighting(nor: vec3<f32>, view_dir: vec3<f32>, pos: vec3<f32>, metalness: f32, roughness: f32) -> vec3<f32> {
    let light_dir1 = normalize(vec3<f32>(1.0, 2.0, 1.0));
    let light_intensity1 = 0.8;
    
    let light_dir2 = normalize(vec3<f32>(-3.0, 1.0, 2.0) - pos);
    let light_intensity2 = 0.4;
    
    let light_dir3 = normalize(vec3<f32>(-1.0, 0.0, -1.0));
    let light_intensity3 = 0.3;
    
    let base_color = vec3<f32>(0.7, 0.7, 0.8);
    
    var result = vec3<f32>(0.0);
    
    let diffuse1 = max(dot(nor, light_dir1), 0.0) * light_intensity1;
    let specular1 = pow(max(dot(reflect(-light_dir1, nor), view_dir), 0.0), 32.0 * (1.0 - roughness)) * light_intensity1 * metalness;
    result = result + (base_color * diffuse1 + vec3<f32>(1.0) * specular1);
    
    let diffuse2 = max(dot(nor, light_dir2), 0.0) * light_intensity2;
    let specular2 = pow(max(dot(reflect(-light_dir2, nor), view_dir), 0.0), 32.0 * (1.0 - roughness)) * light_intensity2 * metalness;
    result = result + (base_color * diffuse2 + vec3<f32>(1.0) * specular2);
    
    let diffuse3 = max(dot(nor, light_dir3), 0.0) * light_intensity3;
    let specular3 = pow(max(dot(reflect(-light_dir3, nor), view_dir), 0.0), 32.0 * (1.0 - roughness)) * light_intensity3 * metalness;
    result = result + (base_color * diffuse3 + vec3<f32>(1.0) * specular3);
    
    result = result + base_color * 0.1;
    
    return result;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let angle_y = params.time * 6.283185 / 6.0;
    let angle_z = 0.261799;
    
    let cos_y = cos(angle_y);
    let sin_y = sin(angle_y);
    let cos_z = cos(angle_z);
    let sin_z = sin(angle_z);
    
    let rot_y = mat3x3<f32>(
        vec3<f32>(cos_y, 0.0, sin_y),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sin_y, 0.0, cos_y)
    );
    
    let rot_z = mat3x3<f32>(
        vec3<f32>(cos_z, -sin_z, 0.0),
        vec3<f32>(sin_z, cos_z, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
    
    let rotation = rot_y * rot_z;
    
    let ro = vec3<f32>(4.0, 3.0, 5.0);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let forward = normalize(target_var - ro);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let rd = normalize(right * uv.x + up * uv.y + forward);
    
    let result = raymarch(ro, rd);
    
    if (result.w < 0.0) {
        let grad_factor = 0.5 + 0.5 * uv.y;
        let sky_color = mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0, 1.0, 1.0), grad_factor);
        return vec4<f32>(sky_color, 1.0);
    }
    
    let hit_pos = ro + rd * result.w;
    let normal = result.xyz;
    let view_dir = normalize(ro - hit_pos);
    
    let is_sphere = abs(hit_pos.x) > 1.7;
    let metalness = select(0.8, 0.9, is_sphere);
    let roughness = select(0.3, 0.2, is_sphere);
    
    let color = pbr_lighting(normal, view_dir, hit_pos, metalness, roughness);
    
    let bg_dist = length(hit_pos) / 10.0;
    let shadow_factor = 1.0 - smoothstep(0.0, 0.3, bg_dist);
    
    let final_color = color * (0.7 + 0.3 * shadow_factor);
    
    return vec4<f32>(final_color, 1.0);
}