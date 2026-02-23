// Mandelbulb Order-8 Fractal Renderer with Ray Marching
// =====================================================

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

// Constants
const MAX_ITERATIONS: u32 = 18u;
const ESCAPE_RADIUS: f32 = 4.0;
const MIN_DISTANCE: f32 = 0.001;
const BOUNDING_RADIUS: f32 = 5.0;
const MAX_STEPS: u32 = 256u;
const POWER: f32 = 8.0;

// ============ Spherical Coordinate Conversion ============
fn cartesian_to_spherical(p: vec3<f32>) -> vec3<f32> {
    let r = length(p);
    let theta = atan2(length(vec2<f32>(p.x, p.y)), p.z);
    let phi = atan2(p.y, p.x);
    return vec3<f32>(r, theta, phi);
}

fn spherical_to_cartesian(r: f32, theta: f32, phi: f32) -> vec3<f32> {
    let sin_theta = sin(theta);
    let cos_theta = cos(theta);
    let sin_phi = sin(phi);
    let cos_phi = cos(phi);
    
    return vec3<f32>(
        r * sin_theta * cos_phi,
        r * sin_theta * sin_phi,
        r * cos_theta
    );
}

// ============ Mandelbulb Power Function ============
fn mandelbulb_power_map(r: f32, theta: f32, phi: f32) -> vec3<f32> {
    let r8 = pow(r, POWER);
    let theta_8 = POWER * theta;
    let phi_8 = POWER * phi;
    
    let sin_theta_8 = sin(theta_8);
    let cos_theta_8 = cos(theta_8);
    let sin_phi_8 = sin(phi_8);
    let cos_phi_8 = cos(phi_8);
    
    return vec3<f32>(
        r8 * sin_theta_8 * cos_phi_8,
        r8 * sin_theta_8 * sin_phi_8,
        r8 * cos_theta_8
    );
}

// ============ Distance Estimator ============
struct IterationResult {
    z: vec3<f32>,
    norm: f32,
    derivative: f32,
    escaped: bool,
    iterations: u32,
};

fn mandelbulb_distance_estimator(p: vec3<f32>) -> IterationResult {
    var z = p;
    var derivative: f32 = 1.0;
    var escaped: bool = false;
    var iter: u32 = 0u;
    
    loop {
        if (iter >= MAX_ITERATIONS) { break; }
        if (length(z) > ESCAPE_RADIUS) {
            escaped = true;
            break;
        }
        
        let z_norm = length(z);
        let sph = cartesian_to_spherical(z);
        let z_new = mandelbulb_power_map(sph.x, sph.y, sph.z);
        
        // Analytic derivative: |dF/dz| ≈ |z|^(8-1) * 8 = |z|^7 * 8
        derivative *= POWER * pow(z_norm, POWER - 1.0);
        
        z = z_new + p;
        iter = iter + 1u;
    }
    
    let final_norm = length(z);
    
    return IterationResult(
        z,
        final_norm,
        max(derivative, 0.001),
        escaped,
        iter
    );
}

fn compute_distance(p: vec3<f32>) -> f32 {
    let result = mandelbulb_distance_estimator(p);
    
    if (!result.escaped || result.norm < 0.001) {
        return -1.0; // Inside
    }
    
    // Distance estimator: d = |z| * ln|z| / |dz|
    let ln_norm = log(result.norm);
    let distance = result.norm * ln_norm / result.derivative;
    
    return max(distance, 0.0);
}

// ============ Ray Marching ============
struct RayMarchResult {
    hit: bool,
    distance: f32,
    iterations: u32,
    escape_value: f32,
};

fn ray_march(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> RayMarchResult {
    var current_pos = ray_origin;
    var total_distance: f32 = 0.0;
    var march_count: u32 = 0u;
    var escape_value: f32 = 0.0;
    
    loop {
        if (march_count >= MAX_STEPS) { break; }
        if (total_distance > BOUNDING_RADIUS * 2.0) { break; }
        
        let dist = compute_distance(current_pos);
        
        if (dist < 0.0) {
            // Inside fractal
            return RayMarchResult(true, total_distance, march_count, 0.0);
        }
        
        let threshold = MIN_DISTANCE * BOUNDING_RADIUS;
        if (dist < threshold) {
            // Hit surface
            let result = mandelbulb_distance_estimator(current_pos);
            escape_value = f32(result.iterations) + 1.0;
            if (result.escaped) {
                let ln_norm = log(result.norm);
                let ln_ln = log(ln_norm);
                escape_value = escape_value - ln_ln / log(POWER);
            }
            return RayMarchResult(true, total_distance, march_count, escape_value);
        }
        
        let step_size = max(dist * 0.8, 0.001);
        current_pos = current_pos + ray_dir * step_size;
        total_distance = total_distance + step_size;
        march_count = march_count + 1u;
    }
    
    return RayMarchResult(false, total_distance, march_count, 0.0);
}

// ============ Camera Setup ============
fn get_camera_ray(uv: vec2<f32>) -> vec3<f32> {
    let fov = 45.0 * 3.14159 / 180.0;
    let h = tan(fov * 0.5);
    let w = h * (params.resolution.x / params.resolution.y);
    
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), vec3<f32>(-1.0, -1.0, -0.5)));
    let up = normalize(cross(vec3<f32>(-1.0, -1.0, -0.5), right));
    let forward = normalize(vec3<f32>(-1.0, -1.0, -0.5));
    
    return normalize(forward + right * uv.x * w + up * uv.y * h);
}

// ============ Lighting (Phong) ============
fn phong_lighting(normal: vec3<f32>, view_dir: vec3<f32>, light_pos: vec3<f32>, surface_pos: vec3<f32>) -> vec3<f32> {
    let light_dir = normalize(light_pos - surface_pos);
    let ambient: f32 = 0.1;
    let diffuse_coeff: f32 = 0.7;
    let diffuse = diffuse_coeff * max(dot(normal, light_dir), 0.0);
    
    let reflect_dir = normalize(reflect(-light_dir, normal));
    let specular_coeff: f32 = 0.2;
    let shininess: f32 = 32.0;
    let specular = specular_coeff * pow(max(dot(view_dir, reflect_dir), 0.0), shininess);
    
    return vec3<f32>(ambient + diffuse + specular);
}

// ============ Normal Estimation via Finite Differences ============
fn estimate_normal(p: vec3<f32>) -> vec3<f32> {
    let eps: f32 = 0.001;
    let dx = compute_distance(p + vec3<f32>(eps, 0.0, 0.0)) - compute_distance(p - vec3<f32>(eps, 0.0, 0.0));
    let dy = compute_distance(p + vec3<f32>(0.0, eps, 0.0)) - compute_distance(p - vec3<f32>(0.0, eps, 0.0));
    let dz = compute_distance(p + vec3<f32>(0.0, 0.0, eps)) - compute_distance(p - vec3<f32>(0.0, 0.0, eps));
    return normalize(vec3<f32>(dx, dy, dz));
}

// ============ HSV to sRGB ============
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let h_wrapped = fract(h) * 6.0;
    let h_int = u32(h_wrapped);
    let f = fract(h_wrapped);
    
    let p = v * (1.0 - s);
    let q = v * (1.0 - f * s);
    let t = v * (1.0 - (1.0 - f) * s);
    
    var result: vec3<f32> = vec3<f32>(0.0);
    if (h_int == 0u) {
        result = vec3<f32>(v, t, p);
    } else if (h_int == 1u) {
        result = vec3<f32>(q, v, p);
    } else if (h_int == 2u) {
        result = vec3<f32>(p, v, t);
    } else if (h_int == 3u) {
        result = vec3<f32>(p, q, v);
    } else if (h_int == 4u) {
        result = vec3<f32>(t, p, v);
    } else {
        result = vec3<f32>(v, p, q);
    }
    
    return result;
}

// ============ Gamma Correction ============
fn apply_gamma(color: vec3<f32>, gamma: f32) -> vec3<f32> {
    return pow(color, vec3<f32>(1.0 / gamma));
}

// ============ Fragment Shader ============
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Camera setup
    let camera_pos = vec3<f32>(3.0, 3.0, 2.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let camera_forward = normalize(camera_target - camera_pos);
    let camera_right = normalize(cross(vec3<f32>(0.0, 0.0, 1.0), camera_forward));
    let camera_up = cross(camera_forward, camera_right);
    
    let fov = 45.0 * 3.14159 / 180.0;
    let ray_dir = normalize(
        camera_forward + 
        camera_right * uv.x * tan(fov * 0.5) + 
        camera_up * uv.y * tan(fov * 0.5)
    );
    
    // Ray march
    let march_result = ray_march(camera_pos, ray_dir);
    
    var final_color = vec3<f32>(1.0, 1.0, 1.0); // White background
    
    if (march_result.hit) {
        let hit_pos = camera_pos + ray_dir * march_result.distance;
        let norm = estimate_normal(hit_pos);
        
        let result = mandelbulb_distance_estimator(hit_pos);
        
        if (!result.escaped) {
            // Inside: dark color
            final_color = vec3<f32>(0.0625, 0.0625, 0.0625); // #101010
        } else {
            // Outside: compute smooth escape value and color
            let escape_iterations = f32(result.iterations);
            var smooth_escape = escape_iterations + 1.0;
            
            if (result.norm > 0.001) {
                let ln_norm = log(result.norm);
                let ln_ln = log(ln_norm);
                smooth_escape = escape_iterations + 1.0 - ln_ln / log(POWER);
            }
            
            // Map to HSV
            let hue = smooth_escape / 18.0;
            let sat: f32 = 1.0;
            let val: f32 = 1.0;
            
            let hsv_rgb = hsv_to_rgb(hue, sat, val);
            
            // Apply lighting
            let light_pos = vec3<f32>(4.0, 4.0, 4.0);
            let view_dir = normalize(camera_pos - hit_pos);
            let lighting = phong_lighting(norm, view_dir, light_pos, hit_pos);
            
            final_color = hsv_rgb * lighting;
        }
    }
    
    // Apply gamma correction
    final_color = apply_gamma(final_color, 2.2);
    
    return vec4<f32>(final_color, 1.0);
}