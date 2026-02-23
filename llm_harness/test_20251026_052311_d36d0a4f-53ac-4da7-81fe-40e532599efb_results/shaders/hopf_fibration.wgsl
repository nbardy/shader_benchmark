// Hopf Fibration Visualization - Three Linked Tori
// Renders pre-images of three latitude circles on S² under the Hopf map
// Base loops: A (60°), B (0°), C (-60°)

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

// Complex number operations
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cconj(z: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(z.x, -z.y);
}

fn cnorm2(z: vec2<f32>) -> f32 {
    return z.x * z.x + z.y * z.y;
}

fn cnorm(z: vec2<f32>) -> f32 {
    return sqrt(cnorm2(z));
}

// Hopf fiber computation
fn hopf_fiber(z: vec2<f32>, x: f32, t: f32) -> vec4<f32> {
    let r0_sq = (1.0 + x) * 0.5;
    let r1_sq = (1.0 - x) * 0.5;
    
    let r0 = sqrt(max(0.0, r0_sq));
    let r1 = sqrt(max(0.0, r1_sq));
    
    let z_half = z * 0.5;
    let z_half_norm = cnorm(z_half);
    
    let angle_z_half = select(0.0, atan2(z_half.y, z_half.x), z_half_norm > 1e-6);
    
    let alpha = angle_z_half + t;
    let beta = t;
    
    let cos_alpha = cos(alpha);
    let sin_alpha = sin(alpha);
    let cos_beta = cos(beta);
    let sin_beta = sin(beta);
    
    let z0 = vec2<f32>(r0 * cos_alpha, r0 * sin_alpha);
    let z1 = vec2<f32>(r1 * cos_beta, r1 * sin_beta);
    
    return vec4<f32>(z0.x, z0.y, z1.x, z1.y);
}

// Stereographic projection
fn stereo_proj(p: vec4<f32>) -> vec3<f32> {
    let denom = 1.0 - p.w;
    return select(vec3<f32>(1e6), p.xyz / denom, abs(denom) > 1e-4);
}

// Sphere point from spherical coords
fn sphere_point(theta: f32, phi: f32) -> vec3<f32> {
    let sin_theta = sin(theta);
    let cos_theta = cos(theta);
    let sin_phi = sin(phi);
    let cos_phi = cos(phi);
    return vec3<f32>(sin_theta * cos_phi, sin_theta * sin_phi, cos_theta);
}

// Distance to torus
fn distance_to_torus(pos_r3: vec3<f32>, theta: f32) -> f32 {
    let num_phi_samples = 64u;
    let num_fiber_samples = 32u;
    let tube_radius = 0.02;
    
    var min_dist = 1e6;
    
    for (var ip = 0u; ip < num_phi_samples; ip = ip + 1u) {
        let phi = 2.0 * 3.14159265359 * f32(ip) / f32(num_phi_samples);
        
        let s2_point = sphere_point(theta, phi);
        let w = vec2<f32>(s2_point.x, s2_point.y);
        let x = s2_point.z;
        
        for (var it = 0u; it < num_fiber_samples; it = it + 1u) {
            let t = 2.0 * 3.14159265359 * f32(it) / f32(num_fiber_samples);
            
            let fiber_point_s3 = hopf_fiber(w, x, t);
            let fiber_point_r3 = stereo_proj(fiber_point_s3);
            
            let d = length(pos_r3 - fiber_point_r3);
            min_dist = min(min_dist, d);
        }
    }
    
    return max(0.0, min_dist - tube_radius);
}

// HSV to RGB
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let hp = h * 6.0;
    let x = c * (1.0 - abs(hp % 2.0 - 1.0));
    let m = v - c;
    
    var rgb_unhue: vec3<f32>;
    if (hp < 1.0) {
        rgb_unhue = vec3<f32>(c, x, 0.0);
    } else if (hp < 2.0) {
        rgb_unhue = vec3<f32>(x, c, 0.0);
    } else if (hp < 3.0) {
        rgb_unhue = vec3<f32>(0.0, c, x);
    } else if (hp < 4.0) {
        rgb_unhue = vec3<f32>(0.0, x, c);
    } else if (hp < 5.0) {
        rgb_unhue = vec3<f32>(x, 0.0, c);
    } else {
        rgb_unhue = vec3<f32>(c, 0.0, x);
    }
    
    return rgb_unhue + vec3<f32>(m);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let theta_a = 3.14159265359 / 3.0;
    let theta_b = 3.14159265359 / 2.0;
    let theta_c = 2.0 * 3.14159265359 / 3.0;
    
    var color = vec3<f32>(1.0);
    
    let main_size = 0.7;
    let main_uv = uv / main_size;
    
    if (length(main_uv) < 2.5) {
        let cam_pos = vec3<f32>(2.0, 1.5, 3.5);
        
        let fwd = normalize(vec3<f32>(0.0) - cam_pos);
        let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), fwd));
        let up = cross(fwd, right);
        
        let ray_dir = normalize(
            fwd +
            main_uv.x * right * 1.5 +
            main_uv.y * up * 1.5
        );
        
        let d_a = distance_to_torus(cam_pos + ray_dir * 0.1, theta_a);
        let d_b = distance_to_torus(cam_pos + ray_dir * 0.1, theta_b);
        let d_c = distance_to_torus(cam_pos + ray_dir * 0.1, theta_c);
        
        let min_distance = min(min(d_a, d_b), d_c);
        
        let phi_estimate = atan2(main_uv.y, main_uv.x);
        let hue = fract(phi_estimate / 6.28318530718 + 0.5);
        
        if (min_distance < 1.0) {
            let brightness = 1.0 - smoothstep(0.0, 0.1, min_distance);
            let torus_color = hsv_to_rgb(hue, 0.7, 0.8);
            color = mix(vec3<f32>(1.0), torus_color * brightness, brightness);
        }
    }
    
    let sphere_center = vec2<f32>(0.6, -0.6);
    let sphere_radius = 0.3;
    let sphere_dist = length(uv - sphere_center);
    
    if (sphere_dist < sphere_radius) {
        let local_uv = (uv - sphere_center) / sphere_radius;
        let d = length(local_uv);
        if (d < 1.0) {
            let phi = atan2(local_uv.y, local_uv.x);
            let hue = fract(phi / 6.28318530718 + 0.5);
            
            let lat_dist_a = abs(local_uv.y - sin(theta_a) * 0.5);
            let circle_a = smoothstep(0.02, 0.01, lat_dist_a);
            
            let lat_dist_b = abs(local_uv.y);
            let circle_b = smoothstep(0.02, 0.01, lat_dist_b);
            
            let lat_dist_c = abs(local_uv.y + sin(theta_c) * 0.5);
            let circle_c = smoothstep(0.02, 0.01, lat_dist_c);
            
            let circle_blend = max(max(circle_a, circle_b), circle_c);
            let base_color = mix(vec3<f32>(0.85), hsv_to_rgb(hue, 0.6, 0.9), circle_blend);
            
            color = mix(color, base_color * 0.7, 0.7);
        }
    }
    
    return vec4<f32>(color, 1.0);
}