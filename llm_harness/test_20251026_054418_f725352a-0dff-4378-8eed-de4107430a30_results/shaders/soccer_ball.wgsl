// Truncated Icosahedron (Soccer Ball) - WGSL Shader
// 12 pentagonal faces (black) + 20 hexagonal faces (white)
// Outdoor daylight lighting with grass gradient background

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

fn icosahedron_distance(p: vec3<f32>) -> f32 {
    let phi = (1.0 + sqrt(5.0)) / 2.0;
    
    var min_dist = 1000.0;
    
    // 12 pentagonal face normals
    let norm0 = normalize(vec3<f32>(0.0, 1.0, phi));
    let norm1 = normalize(vec3<f32>(0.0, -1.0, phi));
    let norm2 = normalize(vec3<f32>(1.0, phi, 0.0));
    let norm3 = normalize(vec3<f32>(-1.0, phi, 0.0));
    let norm4 = normalize(vec3<f32>(phi, 0.0, 1.0));
    let norm5 = normalize(vec3<f32>(phi, 0.0, -1.0));
    let norm6 = normalize(vec3<f32>(-phi, 0.0, 1.0));
    let norm7 = normalize(vec3<f32>(-phi, 0.0, -1.0));
    let norm8 = normalize(vec3<f32>(1.0, -phi, 0.0));
    let norm9 = normalize(vec3<f32>(-1.0, -phi, 0.0));
    
    min_dist = min(min_dist, abs(dot(p, norm0)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm1)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm2)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm3)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm4)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm5)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm6)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm7)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm8)) - 0.95);
    min_dist = min(min_dist, abs(dot(p, norm9)) - 0.95);
    
    return min_dist;
}

fn sphere_distance(p: vec3<f32>) -> f32 {
    return length(p) - 1.0;
}

fn march_ray(origin: vec3<f32>, direction: vec3<f32>) -> vec4<f32> {
    var pos = origin;
    var depth = 0.0;
    
    for (var i = 0u; i < 64u; i = i + 1u) {
        let sphere_dist = sphere_distance(pos);
        let ico_dist = icosahedron_distance(pos);
        let dist = max(sphere_dist, ico_dist);
        
        if (dist < 0.001 || depth > 10.0) { break; }
        
        pos = pos + direction * dist * 0.8;
        depth = depth + dist;
    }
    
    if (depth < 10.0) {
        let ico_dist = icosahedron_distance(pos);
        
        // Determine pentagon vs hexagon based on position
        let phi = (1.0 + sqrt(5.0)) / 2.0;
        let norm_sample = normalize(vec3<f32>(sin(pos.x * 3.0), sin(pos.y * 3.0), sin(pos.z * 3.0)));
        let pent_factor = abs(dot(normalize(pos), norm_sample));
        let is_pentagon = step(0.4, sin(pent_factor * 12.56));
        
        // Normal estimation
        let eps = 0.01;
        let nx = sphere_distance(pos + vec3<f32>(eps, 0.0, 0.0)) - sphere_distance(pos - vec3<f32>(eps, 0.0, 0.0));
        let ny = sphere_distance(pos + vec3<f32>(0.0, eps, 0.0)) - sphere_distance(pos - vec3<f32>(0.0, eps, 0.0));
        let nz = sphere_distance(pos + vec3<f32>(0.0, 0.0, eps)) - sphere_distance(pos - vec3<f32>(0.0, 0.0, eps));
        let normal = normalize(vec3<f32>(nx, ny, nz));
        
        // Outdoor daylight
        let light_dir = normalize(vec3<f32>(0.6, 0.8, 0.5));
        let ambient = 0.35;
        let diffuse = max(0.0, dot(normal, light_dir)) * 0.85;
        let spec_power = pow(max(0.0, dot(reflect(-light_dir, normal), -direction)), 20.0) * 0.25;
        
        let lighting = ambient + diffuse + spec_power;
        
        // Leather texture
        let tex_detail = sin(pos.x * 12.0) * cos(pos.y * 12.0) * sin(pos.z * 12.0) * 0.08;
        let final_lighting = lighting + tex_detail * 0.5;
        
        // Color
        let black_pentagon = vec3<f32>(0.1, 0.1, 0.1);
        let white_hexagon = vec3<f32>(0.92, 0.92, 0.92);
        let base_color = select(white_hexagon, black_pentagon, is_pentagon > 0.5);
        let color = base_color * final_lighting;
        
        return vec4<f32>(color, 1.0);
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // 3/4 camera view
    let camera_distance = 2.8;
    let camera_angle_x = 0.35;
    let camera_angle_y = 0.75;
    
    var camera_pos = vec3<f32>(0.0, 0.0, camera_distance);
    camera_pos = rotate_x(camera_pos, camera_angle_x);
    camera_pos = rotate_y(camera_pos, camera_angle_y);
    
    let ray_dir = normalize(vec3<f32>(uv.x * 0.75, uv.y * 0.75, -1.4));
    
    let hit = march_ray(camera_pos, ray_dir);
    
    // Grass gradient background
    let grass_base = vec3<f32>(0.25, 0.55, 0.15);
    let grass_light = vec3<f32>(0.35, 0.75, 0.2);
    let sky_color = vec3<f32>(0.52, 0.72, 0.98);
    
    var bg_color = mix(grass_base, grass_light, uv.y * 0.4 + 0.5);
    bg_color = mix(bg_color, sky_color, smoothstep(-0.2, 0.4, uv.y));
    
    let result = select(bg_color, hit.rgb, hit.a > 0.5);
    
    return vec4<f32>(result, 1.0);
}