// Möbius strip parametric surface with Blinn-Phong shading
// u ∈ [0, 2π], v ∈ [-0.2, 0.2]
// Grid: 800 × 80 samples
// Front: #66ccff, Back: #ff6699
// Camera: (4,3,2), FOV 40°, Light: (4,3,4)

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

fn mobius_surface(u: f32, v: f32) -> vec3<f32> {
    let half_u = u * 0.5;
    let cos_half_u = cos(half_u);
    let sin_half_u = sin(half_u);
    let cos_u = cos(u);
    let sin_u = sin(u);
    
    let r = 1.0 + v * 0.5 * cos_half_u;
    
    let x = r * cos_u;
    let y = r * sin_u;
    let z = v * 0.5 * sin_half_u;
    
    return vec3<f32>(x, y, z);
}

fn mobius_normal(u: f32, v: f32, delta: f32) -> vec3<f32> {
    let p_center = mobius_surface(u, v);
    let p_u = mobius_surface(u + delta, v);
    let p_v = mobius_surface(u, v + delta);
    
    let du = p_u - p_center;
    let dv = p_v - p_center;
    
    let normal = cross(du, dv);
    return normalize(normal);
}

fn sample_grid(pixel_idx: u32, grid_width: u32) -> vec4<f32> {
    let grid_height = 80u;
    let row = pixel_idx / grid_width;
    let col = pixel_idx % grid_width;
    
    let u_normalized = f32(col) / f32(grid_width - 1u);
    let v_normalized = f32(row) / f32(grid_height - 1u);
    
    let u = u_normalized * 6.283185307179586;
    let v = (v_normalized - 0.5) * 0.4;
    
    let pos = mobius_surface(u, v);
    let normal = mobius_normal(u, v, 0.001);
    
    return vec4<f32>(pos, f32(select(1.0, 0.0, dot(normal, vec3<f32>(0.0, 0.0, 1.0)) > 0.0)));
}

fn blinn_phong(
    normal: vec3<f32>,
    view_dir: vec3<f32>,
    light_dir: vec3<f32>,
    is_front: f32,
    front_color: vec3<f32>,
    back_color: vec3<f32>
) -> vec3<f32> {
    let base_color = select(back_color, front_color, is_front > 0.5);
    
    let amb = 0.1;
    let diff = 0.7;
    let spec = 0.2;
    let shin = 64.0;
    
    let n_dot_l = max(dot(normal, light_dir), 0.0);
    let diffuse = diff * n_dot_l;
    
    let half_vec = normalize(view_dir + light_dir);
    let n_dot_h = max(dot(normal, half_vec), 0.0);
    let specular = spec * pow(n_dot_h, shin);
    
    let intensity = amb + diffuse + specular;
    return base_color * intensity;
}

fn perspective_divide(p: vec3<f32>, fov: f32, aspect: f32) -> vec2<f32> {
    let focal = 1.0 / tan(fov * 0.5);
    let x_screen = p.x * focal / p.z;
    let y_screen = p.y * focal / (p.z * aspect);
    return vec2<f32>(x_screen, y_screen);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let fov = 40.0 * 3.141592653589793 / 180.0;
    
    let camera = vec3<f32>(4.0, 3.0, 2.0);
    let light = vec3<f32>(4.0, 3.0, 4.0);
    
    let front_color = vec3<f32>(0.4, 0.8, 1.0);
    let back_color = vec3<f32>(1.0, 0.4, 0.6);
    let bg_color = vec3<f32>(1.0, 1.0, 1.0);
    
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution;
    let uv_scaled = vec2<f32>(uv.x * aspect, uv.y) * tan(fov * 0.5) * 2.0;
    
    var closest_depth = 1e6;
    var closest_color = bg_color;
    
    let total_pixels = 800u * 80u;
    let samples_per_fragment = 16u;
    
    for (var i = 0u; i < samples_per_fragment; i = i + 1u) {
        let pixel_idx = (i * total_pixels) / samples_per_fragment;
        
        if (pixel_idx >= total_pixels) { break; }
        
        let surface_data = sample_grid(pixel_idx, 800u);
        let world_pos = surface_data.xyz;
        let is_front = surface_data.w;
        
        let cam_to_world = world_pos - camera;
        let z_dist = length(cam_to_world);
        
        if (z_dist < closest_depth) {
            let cam_dir = normalize(cam_to_world);
            let screen_proj = perspective_divide(cam_to_world, fov, aspect);
            
            let pixel_dist = length(screen_proj - uv_scaled);
            
            if (pixel_dist < 0.02) {
                let u_approx = atan2(world_pos.y, world_pos.x);
                let v_approx = world_pos.z * 2.0;
                let normal = mobius_normal(u_approx, v_approx, 0.001);
                
                let view_dir = -cam_dir;
                let light_dir = normalize(light - world_pos);
                
                let shaded = blinn_phong(
                    normal,
                    view_dir,
                    light_dir,
                    is_front,
                    front_color,
                    back_color
                );
                
                closest_color = shaded;
                closest_depth = z_dist;
            }
        }
    }
    
    return vec4<f32>(closest_color, 1.0);
}