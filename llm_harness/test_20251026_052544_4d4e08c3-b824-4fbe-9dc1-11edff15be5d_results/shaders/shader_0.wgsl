// Loxodromic Spirals on Sphere - WGSL Renderer
// Renders 12 loxodromic curves with constant angle to meridians

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

// Constants for loxodrome rendering
const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;
const ALPHA: f32 = 0.610865238;  // 35 degrees in radians
const COT_ALPHA: f32 = 1.42815;   // cot(35°)
const NUM_SPIRALS: u32 = 12u;
const TUBE_RADIUS: f32 = 0.02;
const SPHERE_RADIUS: f32 = 0.98;
const T_MIN: f32 = -8.0;
const T_MAX: f32 = 8.0;
const T_SAMPLES: u32 = 256u;

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let h_norm = h % 1.0;
    let i = u32(h_norm * 6.0);
    let f = h_norm * 6.0 - f32(i);
    let p = v * (1.0 - s);
    let q = v * (1.0 - f * s);
    let t = v * (1.0 - (1.0 - f) * s);
    
    let i_mod = i % 6u;
    let rgb = select(
        select(
            select(
                select(
                    select(vec3<f32>(v, t, p), vec3<f32>(q, v, p), i_mod == 1u),
                    vec3<f32>(p, v, t), i_mod == 2u),
                vec3<f32>(p, q, v), i_mod == 3u),
            vec3<f32>(t, p, v), i_mod == 4u),
        vec3<f32>(v, p, q), i_mod == 5u);
    return rgb;
}

// Loxodrome point calculation
// θ(t) = 2*arctan(exp(t*cot(α))) - π/2
// φ(t) = φ₀ + t
fn loxo_latitude(t: f32) -> f32 {
    let exp_t = exp(t * COT_ALPHA);
    let theta = 2.0 * atan(exp_t) - PI * 0.5;
    return theta;
}

fn loxo_point(t: f32, phi_0: f32) -> vec3<f32> {
    let theta = loxo_latitude(t);
    let phi = phi_0 + t;
    
    let cos_theta = cos(theta);
    let sin_theta = sin(theta);
    let cos_phi = cos(phi);
    let sin_phi = sin(phi);
    
    let x = cos_theta * cos_phi;
    let y = cos_theta * sin_phi;
    let z = sin_theta;
    
    return vec3<f32>(x, y, z);
}

// Distance from point to loxodrome curve (nearest point approximation)
fn distance_to_spiral(p: vec3<f32>, spiral_idx: u32) -> f32 {
    let phi_0 = TAU * f32(spiral_idx) / f32(NUM_SPIRALS);
    
    var min_dist = 1e10;
    var closest_t = T_MIN;
    
    // Sample spiral curve to find closest point
    let step_size = (T_MAX - T_MIN) / f32(T_SAMPLES);
    for (var i: u32 = 0u; i < T_SAMPLES; i = i + 1u) {
        let t = T_MIN + step_size * f32(i);
        let spiral_p = loxo_point(t, phi_0);
        let dist = length(p - spiral_p);
        
        if (dist < min_dist) {
            min_dist = dist;
            closest_t = t;
        }
    }
    
    // Refine around closest point
    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
        for (var j: i32 = -1; j <= 1; j = j + 1) {
            let t = closest_t + f32(j) * step_size * 0.25;
            if (t >= T_MIN && t <= T_MAX) {
                let spiral_p = loxo_point(t, phi_0);
                min_dist = min(min_dist, length(p - spiral_p));
            }
        }
    }
    
    return min_dist;
}

// Get spiral color based on longitude
fn spiral_color(spiral_idx: u32, theta: f32) -> vec3<f32> {
    let h = f32(spiral_idx) / f32(NUM_SPIRALS);
    let s = 0.9;
    
    // Brightness varies with latitude
    let lat_brightness = 0.7 + 0.3 * cos(theta * 2.0);
    
    return hsv_to_rgb(h, s, lat_brightness);
}

// Ray-sphere intersection
fn ray_sphere_intersect(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> f32 {
    let b = 2.0 * dot(ray_origin, ray_dir);
    let c = dot(ray_origin, ray_origin) - SPHERE_RADIUS * SPHERE_RADIUS;
    let discriminant = b * b - 4.0 * c;
    
    if (discriminant < 0.0) {
        return 1e10;
    }
    
    let t1 = (-b - sqrt(discriminant)) * 0.5;
    let t2 = (-b + sqrt(discriminant)) * 0.5;
    
    if (t1 > 0.001) {
        return t1;
    }
    return t2;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize screen coordinates
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Camera setup
    let cam_pos = vec3<f32>(2.5, 1.5, 2.0);
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_up = vec3<f32>(0.0, 1.0, 0.0);
    
    // Construct camera basis
    let cam_z = normalize(cam_pos - cam_target);
    let cam_x = normalize(cross(cam_up, cam_z));
    let cam_y = cross(cam_z, cam_x);
    
    // Ray direction (45° FOV)
    let ray_dir = normalize(
        uv.x * cam_x * 0.8 +
        uv.y * cam_y * 0.8 -
        cam_z
    );
    
    // Intersect sphere
    let t_sphere = ray_sphere_intersect(cam_pos, ray_dir);
    
    if (t_sphere > 1e9) {
        // Background: dark with stars
        let stars = sin(uv.x * 13.0) * sin(uv.y * 17.0) * sin(uv.x * 23.0 + uv.y * 29.0);
        let star_brightness = smoothstep(0.8, 1.0, stars * 0.5 + 0.5);
        return vec4<f32>(vec3<f32>(star_brightness * 0.3), 1.0);
    }
    
    // Surface point on sphere
    let surface_p = cam_pos + ray_dir * t_sphere;
    let theta = asin(clamp(surface_p.z, -1.0, 1.0));
    
    // Find closest spiral and distance
    var min_spiral_dist = 1e10;
    var closest_spiral = 0u;
    
    for (var s: u32 = 0u; s < NUM_SPIRALS; s = s + 1u) {
        let dist = distance_to_spiral(surface_p, s);
        if (dist < min_spiral_dist) {
            min_spiral_dist = dist;
            closest_spiral = s;
        }
    }
    
    // Tube rendering
    let tube_threshold = TUBE_RADIUS;
    var color = vec3<f32>(0.05, 0.05, 0.08);  // Dark background
    
    if (min_spiral_dist < tube_threshold) {
        // Inside tube
        let spiral_color_val = spiral_color(closest_spiral, theta);
        
        // Emissive intensity
        let intensity = 1.0 - (min_spiral_dist / tube_threshold) * 0.7;
        let emissive = intensity * intensity;
        
        color = spiral_color_val * (0.8 + 1.5 * emissive);
    } else {
        // On sphere surface
        let phi = atan2(surface_p.y, surface_p.x);
        
        // Subtle grid on sphere
        let grid_u = sin(phi * 6.0) * 0.1;
        let grid_v = sin(theta * 6.0) * 0.1;
        let grid = grid_u + grid_v;
        
        color = vec3<f32>(0.15, 0.15, 0.2) + vec3<f32>(grid * 0.05);
    }
    
    // Glow for nearby spirals
    if (min_spiral_dist < TUBE_RADIUS * 3.0) {
        let glow = exp(-min_spiral_dist * min_spiral_dist * 5.0);
        let glow_color = spiral_color(closest_spiral, theta);
        color = color + glow_color * glow * 0.5;
    }
    
    return vec4<f32>(color, 1.0);
}