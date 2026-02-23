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

fn cylindrical_bend(pos: vec3<f32>, radius: f32) -> vec3<f32> {
    let x_input = pos.x;
    let y_input = pos.y;
    let z_input = pos.z;
    
    let theta = clamp(x_input / radius, -3.0, 3.0);
    
    let x_new = radius * sin(theta);
    let y_new = y_input;
    let z_new = radius * (1.0 - cos(theta));
    
    return vec3<f32>(x_new, y_new, z_new);
}

fn compute_normal(pos: vec3<f32>, radius: f32) -> vec3<f32> {
    let epsilon = 0.01;
    
    let pos_dx_plus = cylindrical_bend(pos + vec3<f32>(epsilon, 0.0, 0.0), radius);
    let pos_dx_minus = cylindrical_bend(pos - vec3<f32>(epsilon, 0.0, 0.0), radius);
    let dx = (pos_dx_plus - pos_dx_minus) / (2.0 * epsilon);
    
    let pos_dy_plus = cylindrical_bend(pos + vec3<f32>(0.0, epsilon, 0.0), radius);
    let pos_dy_minus = cylindrical_bend(pos - vec3<f32>(0.0, epsilon, 0.0), radius);
    let dy = (pos_dy_plus - pos_dy_minus) / (2.0 * epsilon);
    
    return normalize(cross(dx, dy));
}

fn srgb_to_linear(c: vec3<f32>) -> vec3<f32> {
    return select(
        c / 12.92,
        pow((c + 0.055) / 1.055, vec3<f32>(2.4)),
        c > vec3<f32>(0.04045)
    );
}

fn linear_to_srgb(c: vec3<f32>) -> vec3<f32> {
    return select(
        c * 12.92,
        1.055 * pow(c, vec3<f32>(1.0 / 2.4)) - 0.055,
        c > vec3<f32>(0.0031308)
    );
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    
    let grid_uv = uv - 0.5;
    let x_grid = grid_uv.x * 4.0;
    let y_grid = grid_uv.y * 2.0;
    
    let camera_pos = vec3<f32>(2.5, 2.0, 3.0);
    let camera_target = vec3<f32>(0.0, 0.0, 0.0);
    let camera_up = vec3<f32>(0.0, 1.0, 0.0);
    
    let camera_z = normalize(camera_pos - camera_target);
    let camera_x = normalize(cross(camera_up, camera_z));
    let camera_y = cross(camera_z, camera_x);
    
    let fov = 0.698;
    let aspect = params.resolution.x / params.resolution.y;
    let ray_dir = normalize(
        camera_x * tan(fov * 0.5) * aspect * (uv.x - 0.5) * 2.0 +
        camera_y * tan(fov * 0.5) * (uv.y - 0.5) * 2.0 -
        camera_z
    );
    
    let radius = 1.5;
    let segments_x = 40u;
    let segments_y = 20u;
    
    var closest_dist = 1e10;
    var closest_color = vec3<f32>(0.3, 0.3, 0.35);
    var closest_normal = vec3<f32>(0.0, 0.0, 1.0);
    var is_grid_line = false;
    
    let ray_steps = 200u;
    var ray_t = 0.1;
    
    for (var step = 0u; step < ray_steps; step = step + 1u) {
        let ray_point = camera_pos + ray_dir * ray_t;
        
        let angle_approx = atan2(ray_point.z, ray_point.x);
        let x_flat = radius * angle_approx;
        let y_flat = ray_point.y;
        
        if (x_flat > -2.0 && x_flat < 2.0 && y_flat > -1.0 && y_flat < 1.0) {
            let grid_x = fract(x_flat * f32(segments_x) / 4.0);
            let grid_y = fract(y_flat * f32(segments_y) / 2.0);
            
            let line_thickness = 0.02;
            let on_x_line = grid_x < line_thickness || grid_x > (1.0 - line_thickness);
            let on_y_line = grid_y < line_thickness || grid_y > (1.0 - line_thickness);
            let is_line = on_x_line || on_y_line;
            
            let flat_pos = vec3<f32>(x_flat, y_flat, 0.0);
            let bent_pos = cylindrical_bend(flat_pos, radius);
            let dist_to_ray_point = length(bent_pos - ray_point);
            
            if (dist_to_ray_point < 0.1) {
                let surface_normal = compute_normal(flat_pos, radius);
                closest_dist = ray_t;
                closest_normal = surface_normal;
                is_grid_line = is_line;
                
                let angle_val = atan2(flat_pos.x, radius) * 0.5 + 0.5;
                let cool_blue = vec3<f32>(0.2, 0.4, 0.6);
                let warm_bronze = vec3<f32>(0.8, 0.5, 0.2);
                let base_color = mix(cool_blue, warm_bronze, angle_val);
                
                if (is_line) {
                    closest_color = base_color * 0.6;
                } else {
                    closest_color = base_color;
                }
                
                break;
            }
        }
        
        ray_t = ray_t + 0.02;
        if (ray_t > 10.0) { break; }
    }
    
    let light1_dir = normalize(vec3<f32>(1.0, 1.5, 1.0));
    let light2_dir = normalize(vec3<f32>(-1.0, 0.5, -1.0));
    let light3_dir = normalize(vec3<f32>(0.0, -1.0, 0.0));
    
    let light1_intensity = max(0.0, dot(closest_normal, light1_dir)) * 0.8;
    let light2_intensity = max(0.0, dot(closest_normal, light2_dir)) * 0.5;
    let light3_intensity = max(0.0, dot(-closest_normal, light3_dir)) * 0.3;
    
    let ambient = 0.2;
    let total_lighting = ambient + light1_intensity + light2_intensity + light3_intensity;
    
    let bend_dir = normalize(vec3<f32>(sin(0.5), 0.0, 1.0 - cos(0.5)));
    let specular_light = light1_dir;
    let aniso_factor = max(0.0, dot(closest_normal, normalize(specular_light + bend_dir * 0.5)));
    let highlight = pow(aniso_factor, 32.0) * select(0.3, 0.6, is_grid_line);
    
    var final_color = closest_color * total_lighting + highlight;
    
    let ao_factor = 0.85 + 0.15 * max(0.0, dot(closest_normal, vec3<f32>(0.0, 1.0, 0.0)));
    final_color = final_color * ao_factor;
    
    final_color = linear_to_srgb(final_color);
    
    return vec4<f32>(final_color, 1.0);
}