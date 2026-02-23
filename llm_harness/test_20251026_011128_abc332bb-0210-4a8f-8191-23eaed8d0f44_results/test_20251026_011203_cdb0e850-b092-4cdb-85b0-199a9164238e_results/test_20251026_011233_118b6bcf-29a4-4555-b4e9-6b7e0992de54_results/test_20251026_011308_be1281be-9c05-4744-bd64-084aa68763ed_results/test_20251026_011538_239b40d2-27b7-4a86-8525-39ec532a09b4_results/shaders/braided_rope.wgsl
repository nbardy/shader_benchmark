// Three-strand braided rope with helical geometry
// Strands: #c96 (coral), #6c9 (sage), #96c (lavender)
// Cylinder radius: 0.6, Pitch: 1.8, Tube radius: 0.15
// Camera: (3, 2, 2), Output: 2000×1800 PNG

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

// Constants for braided rope geometry
const CYLINDER_RADIUS: f32 = 0.6;
const TUBE_RADIUS: f32 = 0.15;
const PITCH: f32 = 1.8;
const NUM_STRANDS: u32 = 3u;
const PHASE_OFFSET: f32 = 2.0943951023931953; // 120 degrees in radians

// Camera position
const CAMERA_POS: vec3<f32> = vec3<f32>(3.0, 2.0, 2.0);
const CAMERA_TARGET: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);

// Strand colors: #c96, #6c9, #96c
const COLOR_0: vec3<f32> = vec3<f32>(0.8, 0.6, 0.4);    // #c96 - coral
const COLOR_1: vec3<f32> = vec3<f32>(0.4, 0.8, 0.6);    // #6c9 - sage
const COLOR_2: vec3<f32> = vec3<f32>(0.6, 0.4, 0.8);    // #96c - lavender

fn build_camera_matrix() -> mat3x3<f32> {
    let forward = normalize(CAMERA_TARGET - CAMERA_POS);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = normalize(cross(right, forward));
    return mat3x3<f32>(right, up, -forward);
}

fn trace_ray(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec4<f32> {
    var closest_dist: f32 = 1e10;
    var closest_color: vec3<f32> = vec3<f32>(0.1, 0.1, 0.15);
    var closest_normal: vec3<f32> = vec3<f32>(0.0);
    var hit: bool = false;

    // Raymarch along ray
    var t: f32 = 0.1;
    let t_max: f32 = 20.0;
    let step_size: f32 = 0.05;

    loop {
        if (t >= t_max) { break; }
        
        let pos = ray_origin + ray_dir * t;
        let dist_to_rope = distance_to_braided_rope(pos);
        
        if (dist_to_rope < 0.01) {
            let strand_info = get_strand_at_position(pos);
            let strand_idx = u32(strand_info.w);
            var strand_color: vec3<f32> = COLOR_0;
            
            if (strand_idx == 1u) {
                strand_color = COLOR_1;
            } else if (strand_idx == 2u) {
                strand_color = COLOR_2;
            }
            
            let normal = compute_normal(pos);
            let lighting = max(0.3, dot(normal, normalize(vec3<f32>(1.0, 1.0, 1.0))));
            
            closest_color = strand_color * lighting;
            closest_dist = t;
            closest_normal = normal;
            hit = true;
            break;
        }
        
        t = t + step_size;
    }

    if (hit) {
        return vec4<f32>(closest_color, 1.0);
    } else {
        // Background gradient
        let sky_color = mix(
            vec3<f32>(0.2, 0.2, 0.3),
            vec3<f32>(0.5, 0.6, 0.8),
            0.5 + 0.5 * ray_dir.y
        );
        return vec4<f32>(sky_color, 1.0);
    }
}

fn distance_to_braided_rope(pos: vec3<f32>) -> f32 {
    var min_dist: f32 = 1e10;
    
    // Check distance to each of the 3 helical strands
    for (var i: u32 = 0u; i < NUM_STRANDS; i = i + 1u) {
        let phase: f32 = f32(i) * PHASE_OFFSET;
        let dist = distance_to_helix(pos, phase);
        min_dist = min(min_dist, dist);
    }
    
    return min_dist;
}

fn distance_to_helix(pos: vec3<f32>, phase: f32) -> f32 {
    // Find closest point on helix to pos
    let z = pos.z;
    let t = z / PITCH; // Parameter along helix
    let angle = t + phase;
    
    // Helix center at this z
    let helix_x = CYLINDER_RADIUS * cos(angle);
    let helix_y = CYLINDER_RADIUS * sin(angle);
    let helix_center = vec3<f32>(helix_x, helix_y, z);
    
    // Distance from pos to helix center, then subtract tube radius
    let dist_to_center = distance(pos, helix_center);
    return dist_to_center - TUBE_RADIUS;
}

fn get_strand_at_position(pos: vec3<f32>) -> vec4<f32> {
    var min_dist: f32 = 1e10;
    var closest_strand: u32 = 0u;
    
    for (var i: u32 = 0u; i < NUM_STRANDS; i = i + 1u) {
        let phase: f32 = f32(i) * PHASE_OFFSET;
        let dist = distance_to_helix(pos, phase);
        
        if (dist < min_dist) {
            min_dist = dist;
            closest_strand = i;
        }
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, f32(closest_strand));
}

fn compute_normal(pos: vec3<f32>) -> vec3<f32> {
    let eps: f32 = 0.001;
    let dx = distance_to_braided_rope(pos + vec3<f32>(eps, 0.0, 0.0)) - 
             distance_to_braided_rope(pos - vec3<f32>(eps, 0.0, 0.0));
    let dy = distance_to_braided_rope(pos + vec3<f32>(0.0, eps, 0.0)) - 
             distance_to_braided_rope(pos - vec3<f32>(0.0, eps, 0.0));
    let dz = distance_to_braided_rope(pos + vec3<f32>(0.0, 0.0, eps)) - 
             distance_to_braided_rope(pos - vec3<f32>(0.0, 0.0, eps));
    
    return normalize(vec3<f32>(dx, dy, dz));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize screen coordinates to [-1, 1]
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Build camera matrix
    let cam_matrix = build_camera_matrix();
    
    // Create ray direction
    let ray_dir_local = normalize(vec3<f32>(uv.x, uv.y, 1.0));
    let ray_dir = cam_matrix * ray_dir_local;
    
    // Trace ray and get color
    let result = trace_ray(CAMERA_POS, ray_dir);
    
    return result;
}