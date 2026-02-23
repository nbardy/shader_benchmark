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

fn butterfly_curve(t: f32) -> vec2<f32> {
    let cost = cos(t);
    let sint = sin(t);
    let sint12 = sin(t / 12.0);
    let sint12_5 = sint12 * sint12 * sint12 * sint12 * sint12;
    let exp_term = exp(cost) - 2.0 * cos(4.0 * t) - sint12_5;
    
    let x = sint * exp_term;
    let y = cost * exp_term;
    
    return vec2<f32>(x, y);
}

fn sample_butterfly_distance(uv: vec2<f32>, time: f32) -> f32 {
    let aspect = params.resolution.x / params.resolution.y;
    let scaled_uv = vec2<f32>(uv.x * aspect, uv.y);
    
    var closest_dist = 1e10;
    let samples = 360u;
    
    for (var i: u32 = 0u; i < samples; i = i + 1u) {
        let t = f32(i) / f32(samples) * 12.0 * 3.14159265359;
        let p = butterfly_curve(t);
        
        let zoom = 0.15 + 0.1 * sin(time * 0.5);
        let angle_offset = time * 0.2;
        let rotated = vec2<f32>(
            p.x * cos(angle_offset) - p.y * sin(angle_offset),
            p.x * sin(angle_offset) + p.y * cos(angle_offset)
        );
        let pos = rotated * zoom;
        
        let dist = length(scaled_uv - pos);
        closest_dist = min(closest_dist, dist);
    }
    
    return closest_dist;
}

fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let hprime = h * 6.0;
    let x = c * (1.0 - abs(hprime % 2.0 - 1.0));
    
    var rgb = vec3<f32>(0.0);
    if (hprime < 1.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (hprime < 2.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (hprime < 3.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (hprime < 4.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (hprime < 5.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    let m = v - c;
    return rgb + vec3<f32>(m);
}

fn color_gradient(pos: vec2<f32>, dist_from_center: f32) -> vec3<f32> {
    let angle = atan2(pos.y, pos.x);
    let radius = length(pos);
    
    let hue = (angle + 3.14159265359) / 6.28318530718;
    let saturation = 0.8 + 0.2 * sin(radius * 4.0);
    let brightness = 0.6 + 0.4 * cos(radius * 2.5);
    
    return hsv_to_rgb(hue, saturation, brightness);
}

fn glow_effect(dist: f32) -> f32 {
    let line_width = 0.015;
    let glow_falloff = 0.12;
    
    let line_contribution = smoothstep(line_width, -line_width, dist);
    let glow_contribution = exp(-dist * dist / (glow_falloff * glow_falloff)) * 0.75;
    
    return line_contribution + glow_contribution;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let curve_dist = sample_butterfly_distance(uv, params.time);
    let glow = glow_effect(curve_dist);
    
    let curve_color = color_gradient(uv, length(uv));
    
    let t_anim = params.time * 0.4;
    let pulse = 0.6 + 0.4 * sin(t_anim);
    let curve_intensity = glow * pulse;
    
    let bg_wave_x = sin(uv.x * 2.5 + params.time * 0.25);
    let bg_wave_y = cos(uv.y * 2.5 - params.time * 0.2);
    let bg_pattern = bg_wave_x * bg_wave_y;
    
    let bg_base = vec3<f32>(0.03, 0.01, 0.06);
    let bg_accent = vec3<f32>(0.08 * bg_pattern, 0.04 * bg_pattern, 0.12 * bg_pattern);
    let bg_color = bg_base + bg_accent;
    
    let blended = mix(bg_color, curve_color, curve_intensity);
    
    let center_dist = length(uv);
    let vignette = 1.0 - center_dist * 0.25;
    let final_color = blended * vignette;
    
    return vec4<f32>(final_color, 1.0);
}