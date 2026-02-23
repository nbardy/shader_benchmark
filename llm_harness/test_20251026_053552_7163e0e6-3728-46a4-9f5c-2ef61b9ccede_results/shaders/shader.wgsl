// Riemann surface of w = sqrt(z)
// Two sheets with branch cut along negative real axis
// Height = Re(w), Color = arg(w) via HSV

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

fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let hh = h * 6.0;
    let x = c * (1.0 - abs((hh % 2.0) - 1.0));
    
    var rgb: vec3<f32>;
    if (hh < 1.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (hh < 2.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (hh < 3.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (hh < 4.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (hh < 5.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    let m = v - c;
    return rgb + vec3<f32>(m);
}

fn complex_sqrt(z_real: f32, z_imag: f32, sheet: i32) -> vec3<f32> {
    let r = sqrt(z_real * z_real + z_imag * z_imag);
    let phi = atan2(z_imag, z_real);
    
    let sqrt_r = sqrt(r);
    let sqrt_r_signed = select(-sqrt_r, sqrt_r, sheet == 0);
    
    let half_phi = phi * 0.5;
    let w_real = sqrt_r_signed * cos(half_phi);
    let w_imag = sqrt_r_signed * sin(half_phi);
    
    return vec3<f32>(w_real, w_imag, half_phi);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let r_max = 4.5;
    let screen_r = sqrt(uv.x * uv.x + uv.y * uv.y) * r_max;
    let screen_phi = atan2(uv.y, uv.x);
    
    let r = clamp(screen_r, 0.0, 4.0);
    let phi = screen_phi;
    
    let z_real = r * cos(phi);
    let z_imag = r * sin(phi);
    
    let is_cut = (phi > 1.5707963 || phi < -1.5707963) && (z_real < 0.01);
    let sheet = select(1, 0, is_cut);
    
    let w_components = complex_sqrt(z_real, z_imag, sheet);
    let w_real = w_components.x;
    let w_imag = w_components.y;
    let arg_w = w_components.z;
    
    let height = w_real;
    
    let hue = (arg_w + 3.14159265) / 6.28318530;
    let saturation = 1.0;
    let value = 1.0;
    
    var rgb = hsv_to_rgb(hue, saturation, value);
    
    let opacity = select(0.7, 1.0, sheet == 0);
    
    let ambient = 0.2;
    let light_dir = normalize(vec3<f32>(-0.3, -0.4, -1.0));
    
    let epsilon = 0.01;
    let z_real_eps = (r + epsilon) * cos(phi);
    let z_imag_eps = (r + epsilon) * sin(phi);
    let w_eps = complex_sqrt(z_real_eps, z_imag_eps, sheet);
    let height_eps = w_eps.x;
    
    let dh_dr = (height_eps - height) / epsilon;
    let normal = normalize(vec3<f32>(-dh_dr * cos(phi), -dh_dr * sin(phi), 1.0));
    
    let diffuse = max(0.0, dot(normal, light_dir));
    let lighting = ambient + diffuse * 0.8;
    
    rgb = rgb * vec3<f32>(lighting);
    
    return vec4<f32>(rgb, opacity);
}