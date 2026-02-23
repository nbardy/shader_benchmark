// Stellated Dodecahedron with Twisted Drill Flutes
// Chrome material with ray-marched geometry

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

const PI = 3.14159265359;
const GOLDEN = 1.61803398875;
const MAX_DIST = 1e8;
const EPSILON = 0.001;
const MAX_STEPS = 128u;

fn get_face_normal(face_idx: u32) -> vec3<f32> {
    let idx = face_idx % 12u;
    if (idx == 0u) { return normalize(vec3<f32>(1.0, 1.0, 1.0)); }
    else if (idx == 1u) { return normalize(vec3<f32>(-1.0, 1.0, 1.0)); }
    else if (idx == 2u) { return normalize(vec3<f32>(1.0, -1.0, 1.0)); }
    else if (idx == 3u) { return normalize(vec3<f32>(-1.0, -1.0, 1.0)); }
    else if (idx == 4u) { return normalize(vec3<f32>(1.0, 1.0, -1.0)); }
    else if (idx == 5u) { return normalize(vec3<f32>(-1.0, 1.0, -1.0)); }
    else if (idx == 6u) { return normalize(vec3<f32>(1.0, -1.0, -1.0)); }
    else if (idx == 7u) { return normalize(vec3<f32>(-1.0, -1.0, -1.0)); }
    else if (idx == 8u) { return normalize(vec3<f32>(GOLDEN, 1.0, 0.0)); }
    else if (idx == 9u) { return normalize(vec3<f32>(-GOLDEN, 1.0, 0.0)); }
    else if (idx == 10u) { return normalize(vec3<f32>(1.0, 0.0, GOLDEN)); }
    else { return normalize(vec3<f32>(0.0, GOLDEN, 1.0)); }
}

fn rot_axis(axis: vec3<f32>, angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    let t = 1.0 - c;
    let x = axis.x;
    let y = axis.y;
    let z = axis.z;
    
    return mat3x3<f32>(
        vec3<f32>(t*x*x + c,     t*x*y - z*s, t*x*z + y*s),
        vec3<f32>(t*x*y + z*s,   t*y*y + c,   t*y*z - x*s),
        vec3<f32>(t*x*z - y*s,   t*y*z + x*s, t*z*z + c)
    );
}

fn sdf_dodecahedron(p: vec3<f32>) -> f32 {
    let core_size = 1.0;
    var min_dist = MAX_DIST;
    
    for (var i = 0u; i < 12u; i = i + 1u) {
        let face_normal = get_face_normal(i);
        let face_dist = dot(p, face_normal) - core_size;
        min_dist = min(min_dist, abs(face_dist) - 0.1);
    }
    
    return min_dist;
}

fn distance_to_spike(p: vec3<f32>, face_normal: vec3<f32>, spike_height: f32, twist_angle: f32) -> f32 {
    let rot_twist = rot_axis(face_normal, twist_angle);
    let p_twisted = rot_twist * p;
    
    let base_radius = 0.5;
    let apex = face_normal * spike_height;
    
    let apex_dist = length(p_twisted - apex);
    
    let proj_p = p_twisted - face_normal * dot(p_twisted, face_normal);
    let proj_dist = length(proj_p);
    let height_component = abs(dot(p_twisted, face_normal));
    
    let cone_radius = mix(base_radius, 0.0, height_component / spike_height);
    let cone_dist = abs(proj_dist - cone_radius) - height_component * 0.05;
    
    return min(apex_dist, max(cone_dist, height_component - spike_height));
}

fn sdf_stellated(p: vec3<f32>) -> f32 {
    let spike_height = 0.6;
    let twist_angle = 20.0 * PI / 180.0;
    
    var min_dist = sdf_dodecahedron(p);
    
    for (var i = 0u; i < 12u; i = i + 1u) {
        let face_normal = get_face_normal(i);
        let spike_dist = distance_to_spike(p, face_normal, spike_height, twist_angle);
        min_dist = min(min_dist, spike_dist);
    }
    
    return min_dist;
}

fn chrome_material(normal: vec3<f32>, view_dir: vec3<f32>, light_dir: vec3<f32>) -> vec3<f32> {
    let fresnel = pow(1.0 - abs(dot(view_dir, normal)), 3.0);
    
    let half_dir = normalize(view_dir + light_dir);
    let spec = pow(max(0.0, dot(normal, half_dir)), 64.0);
    
    let reflected = reflect(-view_dir, normal);
    let env_color = vec3<f32>(
        0.5 + 0.5 * reflected.x,
        0.5 + 0.5 * reflected.y,
        0.5 + 0.5 * reflected.z
    );
    
    let chrome_color = mix(
        vec3<f32>(0.8, 0.8, 0.85),
        env_color,
        0.6 + 0.4 * fresnel
    );
    
    return chrome_color + spec * vec3<f32>(1.0, 1.0, 1.0) * 0.8;
}

fn estimate_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = EPSILON;
    let dx = vec3<f32>(eps, 0.0, 0.0);
    let dy = vec3<f32>(0.0, eps, 0.0);
    let dz = vec3<f32>(0.0, 0.0, eps);
    
    let gx = sdf_stellated(p + dx) - sdf_stellated(p - dx);
    let gy = sdf_stellated(p + dy) - sdf_stellated(p - dy);
    let gz = sdf_stellated(p + dz) - sdf_stellated(p - dz);
    
    return normalize(vec3<f32>(gx, gy, gz));
}

fn ray_march(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec4<f32> {
    var dist_traveled = 0.0;
    var step_count = 0u;
    
    loop {
        if (step_count >= MAX_STEPS) { break; }
        
        let current_pos = ray_origin + ray_dir * dist_traveled;
        let sdf_dist = sdf_stellated(current_pos);
        
        if (sdf_dist < EPSILON) {
            let normal = estimate_normal(current_pos);
            let view_dir = normalize(-ray_dir);
            let light_dir = normalize(vec3<f32>(1.0, 1.0, 0.5));
            
            let color = chrome_material(normal, view_dir, light_dir);
            return vec4<f32>(color, 1.0);
        }
        
        dist_traveled = dist_traveled + sdf_dist * 0.8;
        
        if (dist_traveled > 10.0) {
            break;
        }
        
        step_count = step_count + 1u;
    }
    
    return vec4<f32>(0.878, 0.878, 1.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let cam_pos = vec3<f32>(2.5, 2.0, 2.5);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let up_vec = vec3<f32>(0.0, 1.0, 0.0);
    
    let fwd = normalize(target_var - cam_pos);
    let right = normalize(cross(fwd, up_vec));
    let up = cross(right, fwd);
    
    let ray_dir = normalize(fwd + right * uv.x * 0.7 + up * uv.y * 0.7);
    
    return ray_march(cam_pos, ray_dir);
}