@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

fn klein_bottle_4d(u: f32, v: f32) -> vec4<f32> {
    let pi = 3.14159265359;
    let r = 2.0 + 1.5 * cos(u);
    
    let x = r * cos(v);
    let y = r * sin(v);
    let z = 1.5 * sin(u);
    let w = 0.5 * sin(u % 2.0 * pi) * sin(v);
    
    return vec4<f32>(x, y, z, w);
}

fn thread_direction_from_generator(p: vec3<f32>, generator_id: u32) -> vec3<f32> {
    var direction = vec3<f32>(0.0, 0.0, 1.0);
    
    let a = atan2(p.y, p.x);
    let r = length(p.xy);
    
    if (generator_id == 0u) {
        direction = normalize(vec3<f32>(cos(a), sin(a), 0.2));
    } else if (generator_id == 1u) {
        direction = normalize(vec3<f32>(-sin(a), cos(a), 0.3));
    } else {
        direction = normalize(vec3<f32>(sin(a + r), cos(a - r), 0.1));
    }
    
    return direction;
}

fn homology_color(dimension: u32, u: f32, v: f32) -> vec3<f32> {
    var color = vec3<f32>(0.0);
    
    if (dimension == 0u) {
        color = vec3<f32>(0.95, 0.95, 0.95);
    } else if (dimension == 1u) {
        let hue = (u % 1.0);
        color = vec3<f32>(
            0.5 + 0.5 * sin(hue * 6.28318 + 0.0),
            0.5 + 0.5 * sin(hue * 6.28318 + 2.09),
            0.5 + 0.5 * sin(hue * 6.28318 + 4.19)
        );
    } else {
        color = vec3<f32>(0.85, 0.65, 0.13);
    }
    
    return color;
}

fn thread_density(chi: f32) -> f32 {
    let density_factor = 100.0 / max(abs(chi - 2.0), 0.1);
    return clamp(density_factor, 1.0, 50.0);
}

fn thread_twist(is_orientable: bool, u: f32, v: f32, t: f32) -> f32 {
    var twist = 0.0;
    
    if (is_orientable) {
        twist = sin(u * 8.0 + v * 3.0) * 0.3 + 0.5;
    } else {
        let switch = step(0.5, fract(u * 2.0));
        let s_twist = sin(u * 8.0 + v * 3.0) * 0.3;
        let z_twist = sin(u * 8.0 - v * 3.0) * 0.3;
        twist = mix(s_twist, z_twist, switch) + 0.5;
    }
    
    return twist;
}

fn fiber_texture(uv: vec2<f32>, thread_scale: f32) -> f32 {
    let fiber_freq = 15.0 * thread_scale;
    let fiber_x = fract(uv.x * fiber_freq);
    let fiber_y = fract(uv.y * fiber_freq);
    
    let fiber_width = 0.15;
    let x_profile = exp(-pow(fiber_x - 0.5, 2.0) / (2.0 * fiber_width * fiber_width));
    let y_profile = exp(-pow(fiber_y - 0.5, 2.0) / (2.0 * fiber_width * fiber_width));
    
    return x_profile * y_profile;
}

fn subsurface_scattering(normal: vec3<f32>, light_dir: vec3<f32>, thickness: f32) -> f32 {
    let backlit = -dot(normal, light_dir);
    let sss = smoothstep(-0.1, 0.3, backlit) * 0.6;
    return sss * thickness;
}

fn iridescence(view_dir: vec3<f32>, normal: vec3<f32>, u: f32, v: f32) -> vec3<f32> {
    let fresnel = pow(1.0 - abs(dot(view_dir, normal)), 2.5);
    let irid_angle = atan2(v, u) * 3.0 + length(view_dir.xy) * 5.0;
    
    let irid_r = 0.5 + 0.5 * sin(irid_angle + 0.0);
    let irid_g = 0.5 + 0.5 * sin(irid_angle + 2.09);
    let irid_b = 0.5 + 0.5 * sin(irid_angle + 4.19);
    
    return vec3<f32>(irid_r, irid_g, irid_b) * fresnel * 0.4;
}

fn stress_wrinkles(uv: vec2<f32>, u: f32, v: f32) -> f32 {
    let wrinkle_freq = 0.8;
    let wrinkle_strength = sin(u * 3.5) * cos(v * 2.5) * 0.15;
    let noise = sin(uv.x * 12.0 + wrinkle_strength) * sin(uv.y * 8.0 + u);
    return noise * 0.1;
}

fn render_fabric(uv: vec2<f32>, center: vec2<f32>, scale: f32) -> vec4<f32> {
    let u_param = (uv.x - center.x) * scale * 6.28318;
    let v_param = (uv.y - center.y) * scale * 6.28318;
    
    let kb_pos = klein_bottle_4d(u_param * 0.3, v_param * 0.3);
    let fabric_pos = kb_pos.xyz;
    
    let gen_id = u32(mod(floor(u_param * 0.5), 3.0));
    let thread_dir = thread_direction_from_generator(fabric_pos, gen_id);
    
    let homology_dim = u32(mod(floor(v_param * 0.4), 3.0));
    let homo_color = homology_color(homology_dim, u_param, v_param);
    
    let chi = 0.0;
    let density = thread_density(chi);
    
    let is_orientable = false;
    let twist = thread_twist(is_orientable, u_param, v_param, 0.0);
    
    let fiber_uv = fract(vec2<f32>(u_param * 2.0, v_param * 2.0));
    let fiber = fiber_texture(fiber_uv, 1.0 / density);
    
    let normal = normalize(thread_dir);
    let light_dir = normalize(vec3<f32>(0.707, 0.5, -0.707));
    let fill_dir = normalize(vec3<f32>(-0.4, -0.8, 0.3));
    
    let key_light = max(0.0, dot(normal, light_dir)) * 0.8;
    let fill_light = max(0.0, dot(normal, fill_dir)) * 0.3;
    let ambient = 0.2;
    let diffuse = ambient + key_light + fill_light;
    
    let half_vec = normalize(light_dir - fabric_pos);
    let specular = pow(max(0.0, dot(normal, half_vec)), 12.0) * 0.4;
    
    let thickness = 0.3 + 0.7 * fiber;
    let sss = subsurface_scattering(normal, light_dir, thickness);
    
    let irid = iridescence(-fabric_pos, normal, u_param, v_param);
    
    let wrinkle = stress_wrinkles(uv, u_param, v_param);
    
    var color = homo_color * (diffuse + wrinkle * 0.1);
    color = color * (0.85 + 0.15 * fiber);
    color = color + specular * vec3<f32>(1.0, 0.95, 0.9);
    color = color + sss * homo_color;
    color = color + irid;
    
    let alpha = 0.3 + 0.7 * (f32(homology_dim) + 1.0) / 3.0;
    
    let depth_fade = smoothstep(-2.0, 2.0, fabric_pos.z);
    
    return vec4<f32>(color, alpha * depth_fade);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    
    let center = vec2<f32>(0.5, 0.5);
    let aspect = params.resolution.x / params.resolution.y;
    let scale = 0.8;
    
    var color_acc = vec4<f32>(0.0);
    let samples = 4u;
    
    for (var i = 0u; i < samples; i = i + 1u) {
        let offset_x = (f32(i % 2u) - 0.5) * 0.25 / params.resolution.x;
        let offset_y = (f32(i / 2u) - 0.5) * 0.25 / params.resolution.y;
        let sample_uv = uv + vec2<f32>(offset_x, offset_y);
        
        color_acc = color_acc + render_fabric(sample_uv, center, scale);
    }
    
    let final_color = color_acc / f32(samples);
    
    let gamma = 1.0 / 2.2;
    let linear_color = pow(final_color.rgb, vec3<f32>(gamma));
    
    return vec4<f32>(linear_color, final_color.a);
}