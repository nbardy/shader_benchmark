// Menger Cube Fractal - 4+ iterations with ray marching
// High-quality 3D rendering with proper lighting and material properties

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

// ============================================================================
// MENGER CUBE DISTANCE FIELD
// ============================================================================

fn menger_fold(p: vec3<f32>) -> vec3<f32> {
    var pos = p;
    // Apply folding based on the cross-removal rule
    if (pos.x > 0.0) { pos.x = 1.0 - pos.x; }
    if (pos.y > 0.0) { pos.y = 1.0 - pos.y; }
    if (pos.z > 0.0) { pos.z = 1.0 - pos.z; }
    return pos;
}

fn menger_distance(p: vec3<f32>, iterations: i32) -> f32 {
    var pos = p;
    var scale = 1.0;
    var distance = 1.0e38;
    
    for (var i = 0i; i < iterations; i = i + 1i) {
        pos = menger_fold(pos);
        
        // Box distance for this iteration level
        let box_size = 0.3333333;
        let d = max(max(abs(pos.x) - box_size, abs(pos.y) - box_size), abs(pos.z) - box_size);
        
        distance = min(distance, d / scale);
        
        // Subdivide for next iteration
        pos = pos * 3.0;
        scale = scale * 3.0;
    }
    
    return distance;
}

fn distance_to_menger(p: vec3<f32>) -> f32 {
    return menger_distance(p, 4i);
}

// ============================================================================
// RAY MARCHING
// ============================================================================

struct RayMarchResult {
    distance: f32,
    hits: bool,
    depth: f32,
};

fn ray_march(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> RayMarchResult {
    var pos = ray_origin;
    var total_distance = 0.0;
    var march_steps = 0u;
    let max_steps = 256u;
    let max_distance = 20.0;
    let epsilon = 0.0001;
    
    for (var step = 0u; step < max_steps; step = step + 1u) {
        let dist = distance_to_menger(pos);
        
        if (dist < epsilon) {
            return RayMarchResult(total_distance, true, total_distance);
        }
        
        total_distance = total_distance + dist * 0.8;
        pos = pos + ray_dir * dist * 0.8;
        
        if (total_distance > max_distance) {
            return RayMarchResult(total_distance, false, max_distance);
        }
    }
    
    return RayMarchResult(total_distance, false, max_distance);
}

// ============================================================================
// NORMAL ESTIMATION & LIGHTING
// ============================================================================

fn estimate_normal(p: vec3<f32>) -> vec3<f32> {
    let epsilon = 0.001;
    let d = distance_to_menger(p);
    
    let dx = distance_to_menger(p + vec3<f32>(epsilon, 0.0, 0.0)) - d;
    let dy = distance_to_menger(p + vec3<f32>(0.0, epsilon, 0.0)) - d;
    let dz = distance_to_menger(p + vec3<f32>(0.0, 0.0, epsilon)) - d;
    
    let normal = normalize(vec3<f32>(dx, dy, dz));
    return normal;
}

fn get_iteration_level(p: vec3<f32>) -> i32 {
    var pos = p;
    var level = 0i;
    var min_dist = 1.0e38;
    
    for (var i = 0i; i < 5i; i = i + 1i) {
        let d = distance_to_menger(p);
        if (d < min_dist) {
            min_dist = d;
            level = i;
        }
        pos = pos * 3.0;
    }
    
    return level;
}

fn get_color_for_level(level: i32) -> vec3<f32> {
    let lv = i32(clamp(level, 0i, 4i));
    
    if (lv == 0i) {
        return vec3<f32>(0.1, 0.14, 0.49); // Deep blue #1a237e
    } else if (lv == 1i) {
        return vec3<f32>(0.16, 0.21, 0.58); // Blue #283593
    } else if (lv == 2i) {
        return vec3<f32>(0.22, 0.29, 0.67); // Light blue #3949ab
    } else if (lv == 3i) {
        return vec3<f32>(0.15, 0.78, 0.86); // Cyan #26c6da
    } else {
        return vec3<f32>(1.0, 1.0, 1.0); // White
    }
}

fn three_point_lighting(normal: vec3<f32>, view_dir: vec3<f32>, base_color: vec3<f32>) -> vec3<f32> {
    // Key light: upper-left-front
    let key_light_dir = normalize(vec3<f32>(-0.5, 0.8, -0.3));
    let key_intensity = 1.0;
    
    // Fill light: lower-right
    let fill_light_dir = normalize(vec3<f32>(0.6, -0.4, 0.2));
    let fill_intensity = 0.3;
    
    // Rim light: behind for edge definition
    let rim_light_dir = normalize(vec3<f32>(0.2, 0.1, 0.9));
    let rim_intensity = 0.4;
    
    // Calculate lighting
    let key_light = max(0.0, dot(normal, key_light_dir)) * key_intensity;
    let fill_light = max(0.0, dot(normal, fill_light_dir)) * fill_intensity;
    let rim_light = max(0.0, dot(normal, -view_dir)) * rim_intensity;
    
    let ambient = 0.15;
    let total_light = ambient + key_light + fill_light + rim_light;
    
    let lit_color = base_color * vec3<f32>(total_light);
    
    // Add specular highlights for metallic appearance
    let spec_dir = normalize(key_light_dir + view_dir);
    let spec = pow(max(0.0, dot(normal, spec_dir)), 32.0) * 0.5;
    
    return lit_color + vec3<f32>(spec);
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Normalize screen coordinates
    let screen_coords = (uv - 0.5) * 2.0;
    var screen_x = screen_coords.x * aspect;
    let screen_y = screen_coords.y;
    
    // Camera setup with rotation for dynamic perspective
    let time = 0.0; // Static view
    let rot_x = 0.4;
    let rot_y = 0.3;
    let rot_z = 0.1;
    
    let cos_rx = cos(rot_x);
    let sin_rx = sin(rot_x);
    let cos_ry = cos(rot_y);
    let sin_ry = sin(rot_y);
    let cos_rz = cos(rot_z);
    let sin_rz = sin(rot_z);
    
    // Rotation matrices
    let rot_x_mat = mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, cos_rx, -sin_rx),
        vec3<f32>(0.0, sin_rx, cos_rx)
    );
    
    let rot_y_mat = mat3x3<f32>(
        vec3<f32>(cos_ry, 0.0, sin_ry),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sin_ry, 0.0, cos_ry)
    );
    
    let rot_z_mat = mat3x3<f32>(
        vec3<f32>(cos_rz, -sin_rz, 0.0),
        vec3<f32>(sin_rz, cos_rz, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
    
    // Camera ray direction
    var ray_dir = normalize(vec3<f32>(screen_x, screen_y, 1.0));
    ray_dir = rot_z_mat * (rot_y_mat * (rot_x_mat * ray_dir));
    
    let ray_origin = vec3<f32>(0.0, 0.0, -3.0);
    
    // Ray march
    let march_result = ray_march(ray_origin, ray_dir);
    
    var final_color = vec3<f32>(0.0);
    
    if (march_result.hits) {
        // Hit the fractal
        let hit_pos = ray_origin + ray_dir * march_result.distance;
        let normal = estimate_normal(hit_pos);
        let level = get_iteration_level(hit_pos);
        let base_color = get_color_for_level(level);
        
        // Apply lighting
        final_color = three_point_lighting(normal, ray_dir, base_color);
    } else {
        // Background gradient
        let bg_top = vec3<f32>(0.05, 0.07, 0.09); // #0d1117
        let bg_bottom = vec3<f32>(0.13, 0.15, 0.18); // #21262d
        final_color = mix(bg_bottom, bg_top, screen_y * 0.5 + 0.5);
    }
    
    // Bloom effect on bright areas
    let bloom_factor = clamp(length(final_color) - 0.5, 0.0, 1.0);
    final_color = final_color + bloom_factor * 0.15;
    
    // Tone mapping and gamma correction
    final_color = final_color / (final_color + vec3<f32>(1.0));
    final_color = pow(final_color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(final_color, 1.0);
}