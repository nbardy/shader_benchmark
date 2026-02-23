// Superformula Explorer - Interactive Visualization
// Gielis' superformula: r(θ) = (|cos(m*θ/4)/a|^n2 + |sin(m*θ/4)/b|^n3)^(-1/n1)

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

fn superformula(theta: f32, m: f32, n1: f32, n2: f32, n3: f32, a: f32, b: f32) -> f32 {
    let pi = 3.14159265359;
    let angle_term = m * theta / 4.0;
    
    let cos_term = cos(angle_term) / a;
    let sin_term = sin(angle_term) / b;
    
    let cos_abs = abs(cos_term);
    let sin_abs = abs(sin_term);
    
    let cos_pow = pow(cos_abs, n2);
    let sin_pow = pow(sin_abs, n3);
    
    let sum = cos_pow + sin_pow;
    let eps = 1e-6;
    let safe_sum = max(sum, eps);
    
    let inv_n1 = 1.0 / max(n1, eps);
    let radius = pow(safe_sum, -inv_n1);
    
    return max(radius, 0.0);
}

fn hsl_to_rgb(h: f32, s: f32, l: f32) -> vec3<f32> {
    let h_norm = fract(h);
    let s_clamped = clamp(s, 0.0, 1.0);
    let l_clamped = clamp(l, 0.0, 1.0);
    
    let c = (1.0 - abs(2.0 * l_clamped - 1.0)) * s_clamped;
    let h_prime = h_norm * 6.0;
    let x = c * (1.0 - abs(fract(h_prime * 0.5) * 2.0 - 1.0));
    
    var rgb = vec3<f32>(0.0);
    let h_int = u32(h_prime);
    
    if h_int == 0u {
        rgb = vec3<f32>(c, x, 0.0);
    } else if h_int == 1u {
        rgb = vec3<f32>(x, c, 0.0);
    } else if h_int == 2u {
        rgb = vec3<f32>(0.0, c, x);
    } else if h_int == 3u {
        rgb = vec3<f32>(0.0, x, c);
    } else if h_int == 4u {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    let m = l_clamped - c * 0.5;
    return rgb + vec3<f32>(m);
}

fn render_superform(uv: vec2<f32>, shape_index: i32, time: f32) -> vec4<f32> {
    let pi = 3.14159265359;
    let r_uv = length(uv);
    let theta_uv = atan2(uv.y, uv.x);
    
    var m = 5.0;
    var n1 = 2.0;
    var n2 = 3.0;
    var n3 = 3.0;
    var a = 1.0;
    var b = 1.0;
    
    // Animate between different shape configurations
    let phase = sin(time * 0.5) * 0.5 + 0.5;
    let phase2 = cos(time * 0.3) * 0.5 + 0.5;
    let phase3 = sin(time * 0.7) * 0.5 + 0.5;
    
    if shape_index == 0i {
        // Star-like form
        m = 5.0 + phase * 3.0;
        n1 = 2.0;
        n2 = 2.5 + phase2;
        n3 = 2.5 + phase2;
    } else if shape_index == 1i {
        // Flower-like pattern
        m = 6.0 + phase * 2.0;
        n1 = 1.5;
        n2 = 0.5 + phase2 * 2.0;
        n3 = 0.5 + phase2 * 2.0;
    } else if shape_index == 2i {
        // Polygonal form
        m = 4.0;
        n1 = 1.0 + phase * 1.5;
        n2 = 2.0;
        n3 = 2.0;
    } else {
        // Asymmetric form
        m = 8.0 + phase * 4.0;
        n1 = 2.0;
        n2 = 1.5 + phase3;
        n3 = 2.5 + phase2;
        a = 0.8 + phase * 0.4;
        b = 1.2 - phase * 0.4;
    }
    
    let r_formula = superformula(theta_uv, m, n1, n2, n3, a, b);
    let eps = 0.01;
    let inside_shape = r_uv < r_formula + eps;
    
    // HSL color mapping
    let hue = (theta_uv / (2.0 * pi) + 0.5) % 1.0;
    let saturation = 0.6 + phase3 * 0.4;
    let lightness = select(0.3, 0.65 - r_uv * 0.3, inside_shape);
    
    let color = hsl_to_rgb(hue, saturation, lightness);
    let alpha = select(0.0, 1.0, inside_shape);
    
    return vec4<f32>(color, alpha);
}

fn render_particle_effect(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let pi = 3.14159265359;
    var total_glow = vec3<f32>(0.0);
    
    // Multiple particle rings
    for (var i = 0u; i < 5u; i = i + 1u) {
        let particle_time = time + f32(i) * 0.3;
        let ring_radius = 0.3 + f32(i) * 0.15;
        let angular_velocity = (2.0 - f32(i) * 0.2);
        
        let angle = particle_time * angular_velocity;
        let particle_pos = vec2<f32>(
            ring_radius * cos(angle),
            ring_radius * sin(angle)
        );
        
        let dist_to_particle = length(uv - particle_pos);
        let glow_falloff = exp(-dist_to_particle * dist_to_particle * 3.0);
        
        let hue = (f32(i) / 5.0 + particle_time * 0.1) % 1.0;
        let particle_color = hsl_to_rgb(hue, 0.8, 0.5);
        
        total_glow = total_glow + particle_color * glow_falloff * 0.2;
    }
    
    return total_glow;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    let time = params.time * 0.5;
    
    var final_color = vec3<f32>(0.05, 0.03, 0.08);
    var max_alpha = 0.0;
    
    // Render 4 different superforms in quadrants
    let quad_uv_0 = uv + vec2<f32>(-0.35, 0.35);
    let shape_0 = render_superform(quad_uv_0, 0i, time);
    final_color = mix(final_color, shape_0.xyz, shape_0.w);
    max_alpha = max(max_alpha, shape_0.w);
    
    let quad_uv_1 = uv + vec2<f32>(0.35, 0.35);
    let shape_1 = render_superform(quad_uv_1, 1i, time);
    final_color = mix(final_color, shape_1.xyz, shape_1.w);
    max_alpha = max(max_alpha, shape_1.w);
    
    let quad_uv_2 = uv + vec2<f32>(-0.35, -0.35);
    let shape_2 = render_superform(quad_uv_2, 2i, time);
    final_color = mix(final_color, shape_2.xyz, shape_2.w);
    max_alpha = max(max_alpha, shape_2.w);
    
    let quad_uv_3 = uv + vec2<f32>(0.35, -0.35);
    let shape_3 = render_superform(quad_uv_3, 3i, time);
    final_color = mix(final_color, shape_3.xyz, shape_3.w);
    max_alpha = max(max_alpha, shape_3.w);
    
    // Center organic particle effects
    let center_uv = uv * 0.5;
    let particle_glow = render_particle_effect(center_uv, time);
    final_color = final_color + particle_glow;
    
    // Add subtle grid lines for parameter display
    let grid_scale = 10.0;
    let grid_x = fract(uv.x * grid_scale);
    let grid_y = fract(uv.y * grid_scale);
    let grid_line = step(0.95, grid_x) + step(0.95, grid_y);
    final_color = final_color + vec3<f32>(grid_line * 0.03);
    
    // Vignette effect
    let vignette = 1.0 - length(uv) * 0.5;
    final_color = final_color * vignette;
    
    return vec4<f32>(final_color, 1.0);
}