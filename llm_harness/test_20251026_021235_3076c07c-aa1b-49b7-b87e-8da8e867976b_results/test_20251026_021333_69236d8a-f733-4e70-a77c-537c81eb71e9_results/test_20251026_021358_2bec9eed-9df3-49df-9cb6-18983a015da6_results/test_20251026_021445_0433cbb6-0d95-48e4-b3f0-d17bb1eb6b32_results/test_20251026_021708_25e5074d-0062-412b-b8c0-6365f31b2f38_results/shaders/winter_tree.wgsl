// Winter Tree Renderer - Recursive procedural tree with ray marching
// 7 levels of branching, tapered cylinders, three-point lighting

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

fn mat3_rotate_axis(axis: vec3<f32>, angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    let t = 1.0 - c;
    let x = axis.x;
    let y = axis.y;
    let z = axis.z;
    
    return mat3x3<f32>(
        vec3<f32>(t * x * x + c,       t * x * y - z * s,   t * x * z + y * s),
        vec3<f32>(t * x * y + z * s,   t * y * y + c,       t * y * z - x * s),
        vec3<f32>(t * x * z - y * s,   t * y * z + x * s,   t * z * z + c)
    );
}

fn signed_distance_capsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let dist = length(pa - ba * h) - r;
    return dist;
}

fn signed_distance_sphere(p: vec3<f32>, center: vec3<f32>, r: f32) -> f32 {
    return length(p - center) - r;
}

fn branch_direction_and_radius(level: u32, segment_index: u32) -> vec4<f32> {
    let radius_l0 = 0.08;
    let radius_factor = 0.6;
    
    var direction = vec3<f32>(0.0, 0.0, 1.0);
    var radius = radius_l0;
    
    for (var l = 0u; l < level; l = l + 1u) {
        radius = radius * radius_factor;
        let child_side = (segment_index >> l) & 1u;
        
        let branch_angle = 45.0 * 3.14159265359 / 180.0;
        let twist_angle = select(-35.0, 35.0, child_side == 0u) * 3.14159265359 / 180.0;
        
        let rot_twist = mat3_rotate_axis(direction, twist_angle);
        direction = rot_twist * direction;
        
        let perp = normalize(cross(direction, vec3<f32>(0.0, 0.0, 1.0)));
        let rot_branch = mat3_rotate_axis(perp, branch_angle);
        direction = rot_branch * direction;
        direction = normalize(direction);
    }
    
    return vec4<f32>(direction, radius);
}

fn tree_signed_distance(p: vec3<f32>) -> f32 {
    let max_depth = 7u;
    var min_dist = 1e6;
    
    for (var seg = 0u; seg < 128u; seg = seg + 1u) {
        for (var level = 0u; level <= max_depth; level = level + 1u) {
            let branch_info = branch_direction_and_radius(level, seg);
            let dir = branch_info.xyz;
            let radius = branch_info.w;
            
            let segment_length = pow(0.7, f32(level));
            
            var start_pos = vec3<f32>(0.0, 0.0, 0.0);
            for (var l = 0u; l < level; l = l + 1u) {
                start_pos.z = start_pos.z + segment_length;
            }
            
            let end_pos = start_pos + dir * segment_length;
            
            let dist = signed_distance_capsule(p, start_pos, end_pos, radius);
            min_dist = min(min_dist, dist);
            
            let joint_radius = radius * 1.1;
            let joint_dist = signed_distance_sphere(p, end_pos, joint_radius);
            min_dist = min(min_dist, joint_dist);
        }
    }
    
    return min_dist;
}

fn compute_normal(p: vec3<f32>, epsilon: f32) -> vec3<f32> {
    let d = tree_signed_distance(p);
    let dx = tree_signed_distance(p + vec3<f32>(epsilon, 0.0, 0.0)) - d;
    let dy = tree_signed_distance(p + vec3<f32>(0.0, epsilon, 0.0)) - d;
    let dz = tree_signed_distance(p + vec3<f32>(0.0, 0.0, epsilon)) - d;
    return normalize(vec3<f32>(dx, dy, dz));
}

fn phong_lighting(normal: vec3<f32>, view_dir: vec3<f32>, light_dir: vec3<f32>) -> f32 {
    let n_dot_l = max(dot(normal, light_dir), 0.0);
    let reflect_dir = normalize(reflect(-light_dir, normal));
    let spec = pow(max(dot(view_dir, reflect_dir), 0.0), 32.0);
    return n_dot_l + spec * 0.3;
}

fn evaluate_lighting(p: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>) -> vec3<f32> {
    let key_light = normalize(vec3<f32>(3.0, -5.0, 5.0));
    let fill_light = normalize(vec3<f32>(-2.0, -6.0, 4.0));
    let rim_light = normalize(vec3<f32>(0.0, 0.0, 6.0));
    
    let key_intensity = phong_lighting(normal, view_dir, key_light);
    let fill_intensity = phong_lighting(normal, view_dir, fill_light) * 0.4;
    let rim_intensity = phong_lighting(normal, view_dir, rim_light) * 0.3;
    
    let base_color = vec3<f32>(0.294, 0.216, 0.149);
    let intensity = key_intensity + fill_intensity + rim_intensity;
    
    return base_color * intensity;
}

fn sky_gradient(ray_dir: vec3<f32>) -> vec3<f32> {
    let zenith = vec3<f32>(0.843, 0.933, 1.0);
    let horizon = vec3<f32>(1.0, 1.0, 1.0);
    let t = 0.5 + 0.5 * ray_dir.z;
    return mix(horizon, zenith, clamp(t, 0.0, 1.0));
}

fn ray_march(origin: vec3<f32>, direction: vec3<f32>) -> vec4<f32> {
    let max_steps = 128u;
    let max_dist = 20.0;
    let epsilon = 0.001;
    
    var t = 0.0;
    var step_count = 0u;
    
    loop {
        if (step_count >= max_steps || t > max_dist) { break; }
        
        let p = origin + direction * t;
        let d = tree_signed_distance(p);
        
        if (d < epsilon) {
            let normal = compute_normal(p, epsilon * 0.5);
            let view_dir = normalize(-direction);
            let color = evaluate_lighting(p, normal, view_dir);
            return vec4<f32>(color, 1.0);
        }
        
        t = t + d * 0.8;
        step_count = step_count + 1u;
    }
    
    let sky = sky_gradient(direction);
    return vec4<f32>(sky, 0.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let camera_pos = vec3<f32>(3.0, -6.0, 2.5);
    let camera_target = vec3<f32>(0.0, 0.0, 0.5);
    let camera_up = vec3<f32>(0.0, 0.0, 1.0);
    
    let forward = normalize(camera_target - camera_pos);
    let right = normalize(cross(forward, camera_up));
    let up = cross(right, forward);
    
    let fov = 40.0 * 3.14159265359 / 180.0;
    let focal_length = 1.0 / tan(fov * 0.5);
    
    let ray_dir = normalize(
        forward * focal_length + 
        right * uv.x + 
        up * uv.y
    );
    
    let result = ray_march(camera_pos, ray_dir);
    
    return result;
}