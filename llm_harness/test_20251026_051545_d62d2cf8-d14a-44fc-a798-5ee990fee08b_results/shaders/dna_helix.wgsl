// DNA Double Helix Renderer
// Two anti-parallel helices with connecting rungs
// Strand 1: Blue (#2e8bff), Strand 2: Red (#ff5a5a)
// Rungs: Gray (#dddddd)

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
const PI: f32 = 3.14159265359;
const HELIX_RADIUS: f32 = 1.0;
const STRAND_TUBE_RADIUS: f32 = 0.12;
const RUNG_RADIUS: f32 = 0.05;
const PITCH_FACTOR: f32 = 0.54;
const MAX_T: f32 = 37.699111842;
const RUNG_SPACING: f32 = 3.14159265359;

// Camera setup
const CAMERA_POS: vec3<f32> = vec3<f32>(5.0, 0.0, 2.0);
const LOOK_AT: vec3<f32> = vec3<f32>(0.0, 0.0, 5.0);
const FOV: f32 = 0.6108652382;

// Starfield generation
fn starfield(ray_dir: vec3<f32>) -> f32 {
    let seed1 = fract(sin(dot(ray_dir.xy, vec2<f32>(12.9898, 78.233))) * 43758.5453);
    let seed2 = fract(sin(dot(ray_dir.yz, vec2<f32>(12.9898, 78.233))) * 43758.5453);
    let seed3 = fract(sin(dot(ray_dir.zx, vec2<f32>(12.9898, 78.233))) * 43758.5453);
    
    let stars = step(0.995, max(max(seed1, seed2), seed3));
    return stars * 0.3;
}

// Ray-sphere intersection
fn ray_sphere(ray_origin: vec3<f32>, ray_dir: vec3<f32>, sphere_center: vec3<f32>, sphere_radius: f32) -> vec2<f32> {
    let oc = ray_origin - sphere_center;
    let a = dot(ray_dir, ray_dir);
    let b = 2.0 * dot(oc, ray_dir);
    let c = dot(oc, oc) - sphere_radius * sphere_radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return vec2<f32>(1e10, 1e10);
    }
    
    let sqrt_disc = sqrt(discriminant);
    let t1 = (-b - sqrt_disc) / (2.0 * a);
    let t2 = (-b + sqrt_disc) / (2.0 * a);
    
    return vec2<f32>(t1, t2);
}

// Ray-cylinder intersection
fn ray_cylinder(ray_origin: vec3<f32>, ray_dir: vec3<f32>, cyl_center: vec3<f32>, cyl_radius: f32, cyl_height: f32) -> vec2<f32> {
    let rc = ray_origin - cyl_center;
    let a = dot(ray_dir.xy, ray_dir.xy);
    let b = 2.0 * dot(rc.xy, ray_dir.xy);
    let c = dot(rc.xy, rc.xy) - cyl_radius * cyl_radius;
    let discriminant = b * b - 4.0 * a * c;
    
    var result = vec2<f32>(1e10, 1e10);
    
    if (discriminant >= 0.0) {
        let sqrt_disc = sqrt(discriminant);
        let t1 = (-b - sqrt_disc) / (2.0 * a);
        let t2 = (-b + sqrt_disc) / (2.0 * a);
        
        let z1 = ray_origin.z + t1 * ray_dir.z;
        let z2 = ray_origin.z + t2 * ray_dir.z;
        
        if (z1 >= cyl_center.z && z1 <= cyl_center.z + cyl_height) {
            result.x = select(result.x, t1, t1 > 0.0);
        }
        if (z2 >= cyl_center.z && z2 <= cyl_center.z + cyl_height) {
            result.y = select(result.y, t2, t2 > 0.0);
        }
    }
    
    return result;
}

// Helix position at parameter t
fn helix1_pos(t: f32) -> vec3<f32> {
    return vec3<f32>(
        HELIX_RADIUS * cos(t),
        HELIX_RADIUS * sin(t),
        PITCH_FACTOR * t
    );
}

fn helix2_pos(t: f32) -> vec3<f32> {
    return vec3<f32>(
        HELIX_RADIUS * cos(t + PI),
        HELIX_RADIUS * sin(t + PI),
        PITCH_FACTOR * t
    );
}

// Main ray marching
fn trace_ray(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec3<f32> {
    var min_t = 1e10;
    var final_color = vec3<f32>(0.0);
    var hit = false;
    
    // Sample helix strands at discrete points
    let num_samples: i32 = 120;
    let t_step = MAX_T / f32(num_samples);
    
    var t_idx: i32 = 0;
    loop {
        if (t_idx >= num_samples) { break; }
        
        let t = f32(t_idx) * t_step;
        
        // Helix 1 strand (blue)
        let h1_center = helix1_pos(t);
        let h1_intersect = ray_sphere(ray_origin, ray_dir, h1_center, STRAND_TUBE_RADIUS);
        if (h1_intersect.x < min_t && h1_intersect.x > 0.01) {
            min_t = h1_intersect.x;
            final_color = vec3<f32>(0.18, 0.545, 1.0);
            hit = true;
        }
        
        // Helix 2 strand (red)
        let h2_center = helix2_pos(t);
        let h2_intersect = ray_sphere(ray_origin, ray_dir, h2_center, STRAND_TUBE_RADIUS);
        if (h2_intersect.x < min_t && h2_intersect.x > 0.01) {
            min_t = h2_intersect.x;
            final_color = vec3<f32>(1.0, 0.353, 0.353);
            hit = true;
        }
        
        // Rungs every PI
        let rung_t_floor = f32(i32(t / RUNG_SPACING)) * RUNG_SPACING;
        if (abs(t - rung_t_floor) < t_step * 0.5) {
            let h1_rung = helix1_pos(rung_t_floor);
            let h2_rung = helix2_pos(rung_t_floor);
            let rung_center = (h1_rung + h2_rung) * 0.5;
            let rung_height = distance(h1_rung, h2_rung);
            
            let rung_intersect = ray_cylinder(ray_origin, ray_dir, rung_center, RUNG_RADIUS, rung_height);
            if (rung_intersect.x < min_t && rung_intersect.x > 0.01) {
                min_t = rung_intersect.x;
                final_color = vec3<f32>(0.867, 0.867, 0.867);
                hit = true;
            }
        }
        
        t_idx = t_idx + 1;
    }
    
    // Add starfield background
    if (!hit) {
        final_color = vec3<f32>(0.0) + starfield(ray_dir) * vec3<f32>(1.0);
    } else {
        final_color = final_color * 0.85 + vec3<f32>(0.15);
    }
    
    return final_color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Build camera frame
    let forward = normalize(LOOK_AT - CAMERA_POS);
    let right = normalize(cross(forward, vec3<f32>(0.0, 0.0, 1.0)));
    let up = normalize(cross(right, forward));
    
    // Ray direction
    let ray_offset = right * uv.x * tan(FOV * 0.5) + up * uv.y * tan(FOV * 0.5);
    let ray_dir = normalize(forward + ray_offset);
    
    // Trace ray
    let color = trace_ray(CAMERA_POS, ray_dir);
    
    // Gamma correction
    let gamma_corrected = pow(color, vec3<f32>(0.454545));
    
    return vec4<f32>(gamma_corrected, 1.0);
}