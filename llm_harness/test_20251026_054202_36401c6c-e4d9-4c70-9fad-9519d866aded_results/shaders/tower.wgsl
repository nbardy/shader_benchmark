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

// ============================================================
// TAPERED & SHEARED CYLINDRICAL TOWER SHADER
// ============================================================
// Renders a stylized skyscraper with:
//   - Quadratic taper: r'(z) = r * (1.0 - 0.6*(z/h)²)
//   - Shear transform: x' = x + 0.3*z, y' = y + 0.1*z
//   - 20 floor divisions with indentations
//   - Glass + steel material with reflective properties
//   - Vertical gradient + window grid with emissive lights
//   - Realistic lighting and environment mapping

fn cylinder_sdf(p: vec3<f32>, radius: f32, height: f32) -> f32 {
    let d_radial = length(p.xy) - radius;
    let d_vertical = abs(p.z) - height * 0.5;
    let outside = length(vec2<f32>(max(d_radial, 0.0), max(d_vertical, 0.0)));
    let inside = min(max(d_radial, d_vertical), 0.0);
    return outside + inside;
}

fn taper_factor(z: f32, height: f32) -> f32 {
    let normalized_z = (z + height * 0.5) / height;
    let clamped_z = clamp(normalized_z, 0.0, 1.0);
    return 1.0 - 0.6 * clamped_z * clamped_z;
}

fn apply_shear(p: vec3<f32>) -> vec3<f32> {
    let z_factor = (p.z + 2.0) / 4.0;
    var result = p;
    result.x = result.x + 0.3 * p.z;
    result.y = result.y + 0.1 * p.z;
    return result;
}

fn reverse_shear(p: vec3<f32>) -> vec3<f32> {
    var result = p;
    result.x = result.x - 0.3 * p.z;
    result.y = result.y - 0.1 * p.z;
    return result;
}

fn tower_sdf(p: vec3<f32>) -> f32 {
    let p_unsheared = reverse_shear(p);
    let base_radius = 0.8;
    let taper = taper_factor(p_unsheared.z, 4.0);
    let tapered_radius = base_radius * taper;
    
    let d = cylinder_sdf(p_unsheared, tapered_radius, 4.0);
    return d;
}

fn floor_pattern(z: f32) -> f32 {
    let num_floors = 20.0;
    let floor_height = 4.0 / num_floors;
    let floor_z = fract((z + 2.0) / floor_height);
    let indentation = smoothstep(0.0, 0.1, floor_z) * smoothstep(1.0, 0.9, floor_z);
    return indentation * 0.05;
}

fn window_grid(p: vec3<f32>) -> f32 {
    let window_scale = 8.0;
    let window_uv = fract(p.xy * window_scale);
    let frame_width = 0.08;
    let is_frame = step(frame_width, window_uv.x) * step(frame_width, window_uv.y) *
                   step(window_uv.x, 1.0 - frame_width) * step(window_uv.y, 1.0 - frame_width);
    return is_frame;
}

fn glass_color(p: vec3<f32>, normal: vec3<f32>, ray_dir: vec3<f32>) -> vec3<f32> {
    let normalized_z = (p.z + 2.0) / 4.0;
    let z_clamped = clamp(normalized_z, 0.0, 1.0);
    
    // Vertical gradient: dark blue (bottom) to silver (top)
    let bottom_color = vec3<f32>(0.05, 0.1, 0.3);
    let top_color = vec3<f32>(0.8, 0.85, 0.9);
    let base_color = mix(bottom_color, top_color, z_clamped);
    
    // Window grid
    let grid = window_grid(p);
    
    // Emissive office lights (random-like distribution)
    let light_uv = fract(p.xy * 8.0);
    let light_pattern = sin(p.x * 12.7) * sin(p.y * 11.3) * sin(p.z * 9.5);
    let has_light = step(0.5, fract(light_pattern * 10.0));
    let light_window = step(0.1, light_uv.x) * step(0.1, light_uv.y) *
                       step(light_uv.x, 0.9) * step(light_uv.y, 0.9) * has_light;
    let emissive_color = vec3<f32>(1.0, 0.95, 0.7) * light_window;
    
    // Reflectivity
    let fresnel = pow(1.0 - abs(dot(normal, -ray_dir)), 3.0);
    let reflection = mix(0.2, 0.8, fresnel);
    
    // Combine
    let window_base = mix(base_color, vec3<f32>(0.9, 0.92, 0.95), grid);
    let lit_glass = window_base + emissive_color * 0.5;
    
    return lit_glass * (1.0 - reflection * 0.3);
}

fn lighting(p: vec3<f32>, normal: vec3<f32>) -> f32 {
    let sun_dir = normalize(vec3<f32>(5.0, 3.0, 8.0));
    let ambient = 0.4;
    let sun_diffuse = max(dot(normal, sun_dir), 0.0) * 0.8;
    
    // Rim lighting
    let view_dir = normalize(vec3<f32>(4.0, -3.0, 1.5) - p);
    let rim = pow(max(dot(normal, view_dir), 0.0), 0.5) * 0.3;
    
    return ambient + sun_diffuse + rim;
}

fn normal_from_sdf(p: vec3<f32>) -> vec3<f32> {
    let epsilon = 0.001;
    let dx = tower_sdf(p + vec3<f32>(epsilon, 0.0, 0.0)) - tower_sdf(p - vec3<f32>(epsilon, 0.0, 0.0));
    let dy = tower_sdf(p + vec3<f32>(0.0, epsilon, 0.0)) - tower_sdf(p - vec3<f32>(0.0, epsilon, 0.0));
    let dz = tower_sdf(p + vec3<f32>(0.0, 0.0, epsilon)) - tower_sdf(p - vec3<f32>(0.0, 0.0, epsilon));
    return normalize(vec3<f32>(dx, dy, dz));
}

fn raymarch(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec3<f32> {
    var t = 0.0;
    var steps = 0;
    let max_steps = 128;
    let max_distance = 20.0;
    
    loop {
        if (steps >= max_steps || t >= max_distance) { break; }
        
        let p = ray_origin + ray_dir * t;
        let d = tower_sdf(p);
        
        if (d < 0.001) {
            // Hit tower
            let normal = normal_from_sdf(p);
            let light = lighting(p, normal);
            let color = glass_color(p, normal, ray_dir);
            let floor_ind = floor_pattern(p.z);
            let edge_color = mix(color, vec3<f32>(0.2, 0.3, 0.5), floor_ind * 0.3);
            return edge_color * light;
        }
        
        t = t + d * 0.8;
        steps = steps + 1;
    }
    
    // Sky gradient background (horizon to zenith)
    let sky_horizon = vec3<f32>(0.7, 0.75, 0.85);
    let sky_zenith = vec3<f32>(0.1, 0.2, 0.5);
    let up_factor = clamp(ray_dir.z * 0.5 + 0.5, 0.0, 1.0);
    let sky = mix(sky_horizon, sky_zenith, up_factor);
    
    // Sun disk
    let sun_dir = normalize(vec3<f32>(5.0, 3.0, 8.0));
    let sun_dot = dot(ray_dir, sun_dir);
    let sun_glow = pow(max(sun_dot, 0.0), 32.0) * 2.0 + pow(max(sun_dot, 0.0), 8.0) * 0.5;
    
    return sky + vec3<f32>(1.0, 0.9, 0.6) * sun_glow;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Camera setup (FOV 40°, looking at building)
    let fov = 40.0 * 3.14159 / 180.0;
    let focal_length = 1.0 / tan(fov * 0.5);
    
    let cam_pos = vec3<f32>(4.0, -3.0, 1.5);
    let cam_target = vec3<f32>(0.0, 0.0, 1.5);
    let cam_up = vec3<f32>(0.0, 0.0, 1.0);
    
    let cam_forward = normalize(cam_target - cam_pos);
    let cam_right = normalize(cross(cam_forward, cam_up));
    let cam_up_actual = cross(cam_right, cam_forward);
    
    let screen_x = (uv.x - 0.5) * aspect * 2.0;
    let screen_y = (uv.y - 0.5) * 2.0;
    
    let ray_dir = normalize(cam_right * screen_x + cam_up_actual * screen_y + cam_forward * focal_length);
    
    let color = raymarch(cam_pos, ray_dir);
    
    return vec4<f32>(color, 1.0);
}