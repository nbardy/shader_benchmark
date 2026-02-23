// TORUS VISUALIZATION - Mathematical Parametric Surface Rendering
// Specification: Major radius R=2.0, Minor radius r=0.7
// Features: Gaussian curvature visualization, parametric coloring, grid overlay

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
    _padding: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Convert HSV to RGB
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let h_i = i32(h * 6.0) % 6;
    let f = h * 6.0 - f32(h_i);
    let p = v * (1.0 - s);
    let q = v * (1.0 - f * s);
    let t = v * (1.0 - (1.0 - f) * s);
    
    if (h_i == 0) {
        return vec3<f32>(v, t, p);
    } else if (h_i == 1) {
        return vec3<f32>(q, v, p);
    } else if (h_i == 2) {
        return vec3<f32>(p, v, t);
    } else if (h_i == 3) {
        return vec3<f32>(p, q, v);
    } else if (h_i == 4) {
        return vec3<f32>(t, p, v);
    } else {
        return vec3<f32>(v, p, q);
    }
}

// Torus parametric surface evaluation
fn torus_point(u: f32, v: f32, r_minor: f32) -> vec3<f32> {
    let R = 2.0;
    let cos_v = cos(v);
    let sin_v = sin(v);
    let cos_u = cos(u);
    let sin_u = sin(u);
    
    let x = (R + r_minor * cos_v) * cos_u;
    let y = (R + r_minor * cos_v) * sin_u;
    let z = r_minor * sin_v;
    
    return vec3<f32>(x, y, z);
}

// Compute torus normal via parametric derivatives
fn torus_normal(u: f32, v: f32, r_minor: f32) -> vec3<f32> {
    let R = 2.0;
    let eps = 0.001;
    
    let p_center = torus_point(u, v, r_minor);
    let p_u = torus_point(u + eps, v, r_minor);
    let p_v = torus_point(u, v + eps, r_minor);
    
    let du = (p_u - p_center) / eps;
    let dv = (p_v - p_center) / eps;
    
    return normalize(cross(du, dv));
}

// Gaussian curvature of torus
fn gaussian_curvature(u: f32, v: f32, r_minor: f32) -> f32 {
    let R = 2.0;
    let cos_v = cos(v);
    let denom = r_minor * (R + r_minor * cos_v);
    
    if (abs(denom) < 0.001) {
        return 0.0;
    }
    
    return cos_v / denom;
}

// Ray-torus intersection using parametric sampling
fn ray_torus_intersection(ray_origin: vec3<f32>, ray_dir: vec3<f32>, max_dist: f32) -> vec4<f32> {
    let R = 2.0;
    var r_minor = 0.7 + 0.1 * sin(2.0 * 3.14159 * params.time / 3.0);
    r_minor = clamp(r_minor, 0.5, 0.9);
    
    var best_dist = max_dist;
    var best_u = 0.0;
    var best_v = 0.0;
    var found = false;
    
    // Parametric sampling grid
    let u_steps = 96u;
    let v_steps = 96u;
    
    for (var i = 0u; i < u_steps; i = i + 1u) {
        let u = 2.0 * 3.14159 * f32(i) / f32(u_steps);
        
        for (var j = 0u; j < v_steps; j = j + 1u) {
            let v = 2.0 * 3.14159 * f32(j) / f32(v_steps);
            
            let point = torus_point(u, v, r_minor);
            let to_point = point - ray_origin;
            let dist = dot(to_point, ray_dir);
            
            if (dist > 0.0 && dist < best_dist) {
                let closest = ray_origin + ray_dir * dist;
                let error = length(closest - point);
                
                if (error < 0.15) {
                    best_dist = dist;
                    best_u = u;
                    best_v = v;
                    found = true;
                }
            }
        }
    }
    
    if (found) {
        return vec4<f32>(best_u, best_v, best_dist, 1.0);
    }
    return vec4<f32>(0.0, 0.0, max_dist, 0.0);
}

// Compute parametric grid line visibility
fn grid_lines(u: f32, v: f32) -> f32 {
    let grid_spacing = 3.14159 / 8.0;
    let line_width = 0.05;
    
    let u_grid = abs(fract(u / grid_spacing) - 0.5) * 2.0;
    let v_grid = abs(fract(v / grid_spacing) - 0.5) * 2.0;
    
    let u_line = smoothstep(line_width, 0.0, u_grid - (1.0 - line_width));
    let v_line = smoothstep(line_width, 0.0, v_grid - (1.0 - line_width));
    
    return max(u_line, v_line);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Camera setup
    let fov = 40.0 * 3.14159 / 180.0;
    let cam_z = 5.0 / tan(fov * 0.5);
    let ray_dir_x = (uv.x - 0.5) * aspect * 2.0 * tan(fov * 0.5);
    let ray_dir_y = (uv.y - 0.5) * 2.0 * tan(fov * 0.5);
    let ray_dir_z = -cam_z;
    
    let ray_dir = normalize(vec3<f32>(ray_dir_x, ray_dir_y, ray_dir_z));
    let ray_origin = vec3<f32>(0.0, 0.0, 0.0);
    
    // Apply camera rotation (orbit around origin)
    let cam_angle_y = params.time * 0.1;
    let cam_angle_x = 0.6;
    let cos_y = cos(cam_angle_y);
    let sin_y = sin(cam_angle_y);
    let cos_x = cos(cam_angle_x);
    let sin_x = sin(cam_angle_x);
    
    let rotated_origin = vec3<f32>(
        ray_origin.x * cos_y - ray_origin.z * sin_y,
        ray_origin.y,
        ray_origin.x * sin_y + ray_origin.z * cos_y
    );
    
    // Rotate ray direction
    let temp = vec3<f32>(
        ray_dir.x * cos_y - ray_dir.z * sin_y,
        ray_dir.y,
        ray_dir.x * sin_y + ray_dir.z * cos_y
    );
    let ray_dir_rotated = vec3<f32>(
        temp.x,
        temp.y * cos_x - temp.z * sin_x,
        temp.y * sin_x + temp.z * cos_x
    );
    
    let cam_pos = vec3<f32>(4.0 * cos_y, 3.0, 5.0 * sin_y);
    let final_ray_origin = cam_pos;
    let final_ray_dir = normalize(ray_dir_rotated);
    
    // Ray-torus intersection
    let intersection = ray_torus_intersection(final_ray_origin, final_ray_dir, 1000.0);
    
    if (intersection.w < 0.5) {
        // Background gradient
        let bg_top = vec3<f32>(0.1, 0.15, 0.3);
        let bg_bottom = vec3<f32>(0.4, 0.5, 0.7);
        let bg = mix(bg_top, bg_bottom, uv.y);
        return vec4<f32>(bg, 1.0);
    }
    
    let u = intersection.x;
    let v = intersection.y;
    
    // Parametric coloring
    let hue = u / 6.28319;
    let saturation = 0.5 + 0.5 * sin(v);
    let value = 0.7 + 0.3 * cos(v);
    
    var base_color = hsv_to_rgb(hue, saturation, value);
    
    // Gaussian curvature overlay
    let gauss_curv = gaussian_curvature(u, v, 0.7);
    let curv_factor = gauss_curv * 0.3;
    
    if (gauss_curv > 0.02) {
        base_color = mix(base_color, vec3<f32>(1.0, 0.3, 0.3), curv_factor * 0.5);
    } else if (gauss_curv < -0.02) {
        base_color = mix(base_color, vec3<f32>(0.3, 0.3, 1.0), -curv_factor * 0.5);
    }
    
    // Grid lines
    let grid = grid_lines(u, v);
    let grid_color = base_color * 0.8;
    let surface_color = mix(base_color, grid_color, grid * 0.3);
    
    // Lighting
    let surface_point = torus_point(u, v, 0.7 + 0.1 * sin(2.0 * 3.14159 * params.time / 3.0));
    let normal = torus_normal(u, v, 0.7);
    
    // Three-point lighting
    let light_key = normalize(vec3<f32>(3.0, 4.0, 2.0) - surface_point);
    let light_fill = normalize(vec3<f32>(-2.0, 1.0, 3.0) - surface_point);
    let light_back = normalize(vec3<f32>(0.0, -2.0, -4.0) - surface_point);
    
    let diffuse_key = max(0.0, dot(normal, light_key)) * 0.7;
    let diffuse_fill = max(0.0, dot(normal, light_fill)) * 0.4;
    let diffuse_back = max(0.0, dot(normal, light_back)) * 0.3;
    
    let diffuse_total = min(1.0, diffuse_key + diffuse_fill + diffuse_back + 0.2);
    
    let final_color = surface_color * diffuse_total;
    
    return vec4<f32>(final_color, 1.0);
}