// Möbius strip with 3 half-twists (540° total rotation)
// Color visualization along the midline showing the triple twist

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

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let h_prime = h / 60.0;
    let h_mod = h_prime - 2.0 * floor(h_prime / 2.0);
    let x = c * (1.0 - abs(h_mod - 1.0));
    let m = v - c;
    
    var rgb = vec3<f32>(0.0);
    if h < 60.0 {
        rgb = vec3<f32>(c, x, 0.0);
    } else if h < 120.0 {
        rgb = vec3<f32>(x, c, 0.0);
    } else if h < 180.0 {
        rgb = vec3<f32>(0.0, c, x);
    } else if h < 240.0 {
        rgb = vec3<f32>(0.0, x, c);
    } else if h < 300.0 {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    return rgb + vec3<f32>(m);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy / params.resolution - vec2<f32>(0.5)) * 2.0;
    let uv_aspect = vec2<f32>(uv.x * aspect, uv.y);
    
    // Ray marching parameters
    let ray_origin = vec3<f32>(uv_aspect, 2.0);
    let ray_dir = normalize(vec3<f32>(0.0) - ray_origin);
    
    var t = 0.1;
    var closest_dist = 1e10;
    var closest_u = 0.0;
    var closest_v = 0.0;
    var hit = false;
    
    // Ray marching loop
    for (var step = 0u; step < 256u; step = step + 1u) {
        let p = ray_origin + ray_dir * t;
        
        var min_dist_to_surface = 1e10;
        var best_u = 0.0;
        var best_v = 0.0;
        
        // Sample the Möbius strip surface
        for (var u_idx = 0u; u_idx < 32u; u_idx = u_idx + 1u) {
            let u = f32(u_idx) / 32.0 * 6.283185307179586; // 2π
            
            for (var v_idx = 0u; v_idx < 16u; v_idx = v_idx + 1u) {
                let v = (f32(v_idx) / 16.0 - 0.5) * 0.6; // Width of strip
                
                // Twist angle: 3π (540°) = 1.5 * u
                let twist_angle = 1.5 * u;
                
                let cos_twist = cos(twist_angle);
                let sin_twist = sin(twist_angle);
                let cos_u = cos(u);
                let sin_u = sin(u);
                
                // Möbius strip surface equation
                let r = 1.0 + v * cos_twist;
                let surface_x = r * cos_u;
                let surface_y = r * sin_u;
                let surface_z = v * sin_twist;
                
                let surface_point = vec3<f32>(surface_x, surface_y, surface_z);
                let dist = length(p - surface_point);
                
                if dist < min_dist_to_surface {
                    min_dist_to_surface = dist;
                    best_u = u;
                    best_v = v;
                }
            }
        }
        
        if min_dist_to_surface < 0.05 {
            hit = true;
            closest_dist = min_dist_to_surface;
            closest_u = best_u;
            closest_v = best_v;
            break;
        }
        
        t = t + 0.05;
        if t > 10.0 {
            break;
        }
    }
    
    // Color based on position
    var final_color = vec3<f32>(0.05, 0.05, 0.1); // Dark background
    
    if hit {
        // Hue cycles once per full loop around the Möbius strip (0→360°)
        let hue = (closest_u / 6.283185307179586) * 360.0;
        let saturation = 0.8 + 0.2 * closest_v;
        let value = 0.7 + 0.3 * smoothstep(0.05, 0.0, closest_dist);
        
        final_color = hsv_to_rgb(hue % 360.0, saturation, value);
    }
    
    return vec4<f32>(final_color, 1.0);
}