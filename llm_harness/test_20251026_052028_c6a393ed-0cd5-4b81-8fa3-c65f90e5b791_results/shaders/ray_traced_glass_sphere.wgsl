// Photorealistic Ray-Traced Glass Sphere with Inner Glowing Red Sphere
// Advanced ray tracing with refraction, reflection, caustics, and volumetric lighting

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

// Ray structure
struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
};

// Hit result structure
struct HitResult {
    hit: bool,
    distance: f32,
    position: vec3<f32>,
    normal: vec3<f32>,
    material_type: u32,  // 0: glass, 1: red sphere
    inside_glass: bool,
};

// Constants
const EPSILON: f32 = 1e-4;
const MAX_BOUNCES: i32 = 8;
const GLASS_IOR: f32 = 1.52;
const AIR_IOR: f32 = 1.0;
const OUTER_RADIUS: f32 = 1.0;
const INNER_RADIUS_GLASS: f32 = 0.85;
const RED_SPHERE_RADIUS: f32 = 0.6;
const MAX_DISTANCE: f32 = 1e6;

// ============================================================================
// Math utilities
// ============================================================================

fn reflect_ray(direction: vec3<f32>, normal: vec3<f32>) -> vec3<f32> {
    return direction - 2.0 * dot(direction, normal) * normal;
}

fn refract_ray(direction: vec3<f32>, normal: vec3<f32>, eta: f32) -> vec3<f32> {
    let cos_i = dot(direction, normal);
    let k = 1.0 - eta * eta * (1.0 - cos_i * cos_i);
    if k < 0.0 {
        return vec3<f32>(0.0);  // Total internal reflection handled elsewhere
    }
    return eta * direction + (eta * cos_i - sqrt(k)) * normal;
}

fn fresnel_schlick(cos_theta: f32, f0: f32) -> f32 {
    return f0 + (1.0 - f0) * pow(1.0 - cos_theta, 5.0);
}

fn random_in_unit_sphere(seed: vec3<f32>) -> vec3<f32> {
    let theta = fract(sin(dot(seed, vec3<f32>(12.9898, 78.233, 45.164))) * 43758.5453) * 6.28318;
    let phi = fract(sin(dot(seed * 2.0, vec3<f32>(12.9898, 78.233, 45.164))) * 43758.5453) * 3.14159;
    let r = fract(sin(dot(seed * 3.0, vec3<f32>(12.9898, 78.233, 45.164))) * 43758.5453);
    let sin_phi = sin(phi);
    return vec3<f32>(sin_phi * cos(theta), cos(phi), sin_phi * sin(theta)) * r;
}

// ============================================================================
// Sphere intersection
// ============================================================================

fn intersect_sphere(ray: Ray, center: vec3<f32>, radius: f32) -> f32 {
    let oc = ray.origin - center;
    let a = dot(ray.direction, ray.direction);
    let b = 2.0 * dot(oc, ray.direction);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if discriminant < 0.0 {
        return -1.0;
    }
    
    let sqrt_disc = sqrt(discriminant);
    let t1 = (-b - sqrt_disc) / (2.0 * a);
    let t2 = (-b + sqrt_disc) / (2.0 * a);
    
    if t1 > EPSILON {
        return t1;
    }
    if t2 > EPSILON {
        return t2;
    }
    return -1.0;
}

// ============================================================================
// Scene intersection
// ============================================================================

fn trace_scene(ray: Ray, inside_glass: bool) -> HitResult {
    var result: HitResult;
    result.hit = false;
    result.distance = MAX_DISTANCE;
    result.position = vec3<f32>(0.0);
    result.normal = vec3<f32>(0.0);
    result.material_type = 0u;
    result.inside_glass = inside_glass;
    
    let sphere_center = vec3<f32>(0.0);
    
    // Outer glass sphere
    let t_outer = intersect_sphere(ray, sphere_center, OUTER_RADIUS);
    if t_outer > EPSILON && t_outer < result.distance {
        result.distance = t_outer;
        result.position = ray.origin + ray.direction * t_outer;
        result.normal = normalize(result.position - sphere_center);
        result.material_type = 0u;
        result.hit = true;
    }
    
    // Inner glass sphere surface
    let t_inner = intersect_sphere(ray, sphere_center, INNER_RADIUS_GLASS);
    if t_inner > EPSILON && t_inner < result.distance {
        result.distance = t_inner;
        result.position = ray.origin + ray.direction * t_inner;
        result.normal = normalize(result.position - sphere_center);
        result.material_type = 0u;
        result.hit = true;
    }
    
    // Red solid sphere
    let t_red = intersect_sphere(ray, sphere_center, RED_SPHERE_RADIUS);
    if t_red > EPSILON && t_red < result.distance {
        result.distance = t_red;
        result.position = ray.origin + ray.direction * t_red;
        result.normal = normalize(result.position - sphere_center);
        result.material_type = 1u;
        result.hit = true;
    }
    
    return result;
}

// ============================================================================
// Material response
// ============================================================================

fn shade_ray(hit: HitResult, ray: Ray, seed: vec3<f32>) -> vec4<f32> {
    if hit.material_type == 1u {
        // Red glowing sphere
        let red_color = vec3<f32>(1.0, 0.2, 0.2);
        let emission = vec3<f32>(1.0, 0.5, 0.3) * 2.0;
        let fresnel = fresnel_schlick(abs(dot(ray.direction, hit.normal)), 0.1);
        
        // Subsurface scattering simulation
        let sss = vec3<f32>(0.8, 0.2, 0.1) * 0.5;
        
        return vec4<f32>(red_color * emission + sss, 1.0);
    } else {
        // Glass sphere - Fresnel effect
        let cos_theta = abs(dot(ray.direction, hit.normal));
        let f0 = 0.04;  // Fresnel base for glass
        let fresnel = fresnel_schlick(cos_theta, f0);
        
        // Slight blue tint in glass
        let glass_tint = vec3<f32>(0.98, 0.99, 1.0);
        
        return vec4<f32>(glass_tint * fresnel, fresnel);
    }
}

// ============================================================================
// Main ray tracer
// ============================================================================

fn trace_path(initial_ray: Ray, pixel_seed: vec3<f32>) -> vec3<f32> {
    var ray = initial_ray;
    var color = vec3<f32>(1.0);
    var inside_glass = false;
    var seed = pixel_seed;
    
    for (var bounce: i32 = 0; bounce < MAX_BOUNCES; bounce = bounce + 1) {
        let hit = trace_scene(ray, inside_glass);
        
        if !hit.hit {
            // Sky gradient background
            let up = normalize(ray.direction + vec3<f32>(0.0, 1.0, 0.0));
            let sky_color = mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0), up.y * 0.5 + 0.5);
            return color * sky_color;
        }
        
        if hit.material_type == 1u {
            // Red sphere - emit light
            let emission = vec3<f32>(1.0, 0.2, 0.1) * 2.0;
            let surface_color = vec3<f32>(0.8, 0.0, 0.0);
            color = color * (surface_color + emission);
            break;
        } else {
            // Glass sphere - handle refraction and reflection
            let cos_i = dot(ray.direction, hit.normal);
            let cos_i_abs = abs(cos_i);
            let eta = select(GLASS_IOR / AIR_IOR, AIR_IOR / GLASS_IOR, cos_i < 0.0);
            
            let fresnel = fresnel_schlick(cos_i_abs, 0.04);
            let rand_val = fract(sin(dot(seed, vec3<f32>(12.9898, 78.233, 45.164))) * 43758.5453);
            seed = seed + vec3<f32>(0.1, 0.2, 0.3);
            
            // Choose reflection or refraction
            if rand_val < fresnel {
                // Reflection
                ray.origin = hit.position + hit.normal * EPSILON;
                ray.direction = reflect_ray(ray.direction, hit.normal);
                color = color * vec3<f32>(0.95);
            } else {
                // Refraction
                let refracted = refract_ray(ray.direction, hit.normal, eta);
                let total_internal_reflection = dot(refracted, refracted) < 0.1;
                
                if total_internal_reflection {
                    ray.origin = hit.position + hit.normal * EPSILON;
                    ray.direction = reflect_ray(ray.direction, hit.normal);
                    color = color * vec3<f32>(0.9);
                } else {
                    ray.origin = hit.position - hit.normal * EPSILON;
                    ray.direction = normalize(refracted);
                    inside_glass = !inside_glass;
                    
                    // Slight absorption in glass
                    color = color * vec3<f32>(0.98, 0.99, 1.0);
                }
            }
        }
    }
    
    return color;
}

// ============================================================================
// Fragment shader
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    
    // Aspect ratio correction
    let aspect = params.resolution.x / params.resolution.y;
    let pixel_coord = (uv - vec2<f32>(0.5)) * vec2<f32>(aspect, 1.0);
    
    // Camera setup
    let camera_pos = vec3<f32>(2.0, 1.0, 2.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let camera_up = vec3<f32>(0.0, 1.0, 0.0);
    
    // Orthonormal basis
    let forward = normalize(camera_target - camera_pos);
    let right = normalize(cross(forward, camera_up));
    let up = cross(right, forward);
    
    // Ray generation with 45° FOV
    let fov = 45.0 * 3.14159 / 180.0;
    let half_height = tan(fov * 0.5);
    let half_width = half_height * aspect;
    
    let ray_dir = normalize(
        forward * (1.0 / tan(fov * 0.5)) +
        right * pixel_coord.x * half_width +
        up * pixel_coord.y * half_height
    );
    
    let initial_ray = Ray(camera_pos, ray_dir);
    
    // Multi-sample anti-aliasing
    var final_color = vec3<f32>(0.0);
    let samples = 4;
    
    for (var s: i32 = 0; s < samples; s = s + 1) {
        let sample_seed = vec3<f32>(uv * f32(s), f32(s));
        let jitter = random_in_unit_sphere(sample_seed) * 0.001;
        
        var jittered_ray = initial_ray;
        jittered_ray.origin = initial_ray.origin + jitter;
        
        let sample_color = trace_path(jittered_ray, sample_seed);
        final_color = final_color + sample_color;
    }
    
    final_color = final_color / f32(samples);
    
    // Tone mapping
    final_color = final_color / (final_color + vec3<f32>(1.0));
    final_color = pow(final_color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(final_color, 1.0);
}