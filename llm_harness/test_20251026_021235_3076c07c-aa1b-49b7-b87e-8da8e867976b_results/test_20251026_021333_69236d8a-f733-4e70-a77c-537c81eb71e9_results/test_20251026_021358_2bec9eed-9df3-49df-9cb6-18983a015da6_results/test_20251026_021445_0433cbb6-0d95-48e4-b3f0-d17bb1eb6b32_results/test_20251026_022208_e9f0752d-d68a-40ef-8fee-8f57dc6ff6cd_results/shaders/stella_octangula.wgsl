// Stella Octangula - Compound of Two Interpenetrating Tetrahedra
// Crystal material with IOR 1.5, 80% transparency, blue tint
// Dramatic top-down spot lighting on black background

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

fn rotate_x(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(p.x, c * p.y - s * p.z, s * p.y + c * p.z);
}

fn rotate_y(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(c * p.x + s * p.z, p.y, -s * p.x + c * p.z);
}

fn rotate_z(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(c * p.x - s * p.y, s * p.x + c * p.y, p.z);
}

fn plane_distance(p: vec3<f32>, normal: vec3<f32>, d: f32) -> f32 {
    return dot(p, normalize(normal)) - d;
}

fn tetrahedron_distance(p: vec3<f32>) -> f32 {
    let s = 1.1547f32;
    
    let p0 = vec3<f32>( 1.0,  1.0,  1.0) * s;
    let p1 = vec3<f32>( 1.0, -1.0, -1.0) * s;
    let p2 = vec3<f32>(-1.0,  1.0, -1.0) * s;
    let p3 = vec3<f32>(-1.0, -1.0,  1.0) * s;
    
    var d = plane_distance(p, p0, dot(p0, p0) / 3.0);
    d = max(d, plane_distance(p, p1, dot(p1, p1) / 3.0));
    d = max(d, plane_distance(p, p2, dot(p2, p2) / 3.0));
    d = max(d, plane_distance(p, p3, dot(p3, p3) / 3.0));
    
    return d;
}

fn stella_octangula_distance(p: vec3<f32>) -> f32 {
    let tet1 = tetrahedron_distance(p);
    let tet2 = tetrahedron_distance(vec3<f32>(-p.x, -p.y, -p.z));
    
    return min(tet1, tet2);
}

fn normal_estimate(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.0001f32;
    let d = stella_octangula_distance(p);
    
    let dx = stella_octangula_distance(p + vec3<f32>(eps, 0.0, 0.0)) - d;
    let dy = stella_octangula_distance(p + vec3<f32>(0.0, eps, 0.0)) - d;
    let dz = stella_octangula_distance(p + vec3<f32>(0.0, 0.0, eps)) - d;
    
    return normalize(vec3<f32>(dx, dy, dz));
}

fn fresnel(cos_theta: f32, ior: f32) -> f32 {
    let r0 = ((1.0 - ior) / (1.0 + ior)) * ((1.0 - ior) / (1.0 + ior));
    return r0 + (1.0 - r0) * pow(1.0 - cos_theta, 5.0);
}

fn cast_ray(origin: vec3<f32>, dir: vec3<f32>) -> vec3<f32> {
    var pos = origin;
    var accumulated = vec3<f32>(0.0, 0.0, 0.0);
    var transmission = vec3<f32>(1.0, 1.0, 1.0);
    var bounces = 0u;
    
    loop {
        if (bounces >= 3u) { break; }
        
        var t = 0.0f32;
        var step_count = 0u;
        
        loop {
            if (step_count >= 128u) { break; }
            let d = stella_octangula_distance(pos);
            t = t + d;
            pos = origin + dir * t;
            step_count = step_count + 1u;
            
            if (d < 0.0001f32 || t > 50.0f32) { break; }
        }
        
        if (t > 50.0f32) {
            break;
        }
        
        let hit_pos = pos;
        let normal = normal_estimate(hit_pos);
        let view_dir = -dir;
        let cos_theta = max(dot(view_dir, normal), 0.0001f32);
        
        let light_pos = vec3<f32>(0.0, 8.0, 0.0);
        let light_dir = normalize(light_pos - hit_pos);
        let light_dist = length(light_pos - hit_pos);
        let light_intensity = max(0.0f32, dot(normal, light_dir)) / (light_dist * light_dist);
        
        let reflected_dir = reflect(dir, normal);
        let f = fresnel(cos_theta, 1.5f32);
        
        let crystal_color = vec3<f32>(0.3f32, 0.6f32, 1.0f32);
        let specular = vec3<f32>(1.0f32, 1.0f32, 1.0f32) * light_intensity * f;
        
        accumulated = accumulated + transmission * (specular + crystal_color * light_intensity * (1.0 - f) * 0.2f32);
        transmission = transmission * crystal_color * 0.8f32;
        
        pos = hit_pos + normal * 0.01f32;
        dir = reflected_dir;
        bounces = bounces + 1u;
    }
    
    return accumulated;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5f32) / params.resolution.y;
    
    let camera_pos = vec3<f32>(3.0f32, 4.0f32, 3.0f32);
    let look_at = vec3<f32>(0.0f32, 0.0f32, 0.0f32);
    let forward = normalize(look_at - camera_pos);
    let right = normalize(cross(forward, vec3<f32>(0.0f32, 1.0f32, 0.0f32)));
    let up = cross(right, forward);
    
    let ray_dir = normalize(forward + right * uv.x + up * uv.y);
    
    let color = cast_ray(camera_pos, ray_dir);
    
    return vec4<f32>(color, 1.0f32);
}