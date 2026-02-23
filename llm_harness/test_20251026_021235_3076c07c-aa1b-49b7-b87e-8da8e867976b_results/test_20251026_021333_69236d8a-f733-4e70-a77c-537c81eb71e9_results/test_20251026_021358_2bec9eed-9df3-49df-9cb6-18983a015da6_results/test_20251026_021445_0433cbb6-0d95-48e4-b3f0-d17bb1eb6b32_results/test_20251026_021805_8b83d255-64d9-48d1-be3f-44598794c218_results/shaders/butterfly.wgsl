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
    let cos_t = cos(t);
    let sin_t = sin(t);
    let sin_t_12 = sin(t / 12.0);
    let sin_t_12_5 = sin_t_12 * sin_t_12 * sin_t_12 * sin_t_12 * sin_t_12;
    
    let r = exp(cos_t) - 2.0 * cos(4.0 * t) - sin_t_12_5;
    
    let x = sin_t * r;
    let y = cos_t * r;
    
    return vec2<f32>(x, y);
}

fn sample_curve(t: f32) -> vec2<f32> {
    return butterfly_curve(t);
}

fn distance_to_curve(uv: vec2<f32>, t: f32, dt: f32) -> f32 {
    let p0 = sample_curve(t);
    let p1 = sample_curve(t + dt);
    
    let pa = uv - p0;
    let ba = p1 - p0;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let dist = length(pa - ba * h);
    
    return dist;
}

fn get_curve_color(t: f32, dist_from_center: f32) -> vec3<f32> {
    let hue = fract(t / (2.0 * 3.14159265359) + dist_from_center * 0.3);
    let r = 0.5 + 0.5 * sin(hue * 6.28318530718);
    let g = 0.5 + 0.5 * sin((hue + 0.333) * 6.28318530718);
    let b = 0.5 + 0.5 * sin((hue + 0.666) * 6.28318530718);
    
    return vec3<f32>(r, g, b);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let time = params.time * 0.5;
    let animation_progress = fract(time / 12.0);
    let max_t = 12.0 * 3.14159265359 * animation_progress;
    
    var min_dist = 1000.0;
    var closest_t = 0.0;
    var closest_color = vec3<f32>(0.0);
    
    let num_samples = 200u;
    let dt = 12.0 * 3.14159265359 / f32(num_samples);
    
    for (var i = 0u; i < num_samples; i = i + 1u) {
        let t = f32(i) * dt;
        
        if (t > max_t) {
            break;
        }
        
        let dist = distance_to_curve(uv, t, dt * 0.5);
        
        if (dist < min_dist) {
            min_dist = dist;
            closest_t = t;
            
            let pos_on_curve = sample_curve(t);
            let dist_from_center = length(pos_on_curve);
            closest_color = get_curve_color(t, dist_from_center);
        }
    }
    
    let line_width = 0.015;
    let glow_width = 0.08;
    let curve_alpha = 1.0 - smoothstep(0.0, line_width, min_dist);
    let glow_alpha = 0.6 * (1.0 - smoothstep(0.0, glow_width, min_dist));
    
    let curve_contrib = closest_color * (curve_alpha + glow_alpha * 0.5);
    
    let center_dist = length(uv);
    let zoom_scale = 0.8 + 0.5 * sin(time * 0.3);
    let scaled_uv = uv / zoom_scale;
    let scaled_dist = length(scaled_uv);
    
    let bg_pattern = sin(scaled_uv.x * 5.0 + time) * cos(scaled_uv.y * 5.0 + time * 0.7);
    let bg_color = vec3<f32>(
        0.08 + 0.05 * sin(time * 0.2),
        0.08 + 0.05 * cos(time * 0.15),
        0.12 + 0.05 * sin(time * 0.25 + 2.0)
    );
    let bg_color_enhanced = bg_color + vec3<f32>(bg_pattern * 0.05);
    
    let vignette = 1.0 - smoothstep(0.5, 2.0, scaled_dist) * 0.4;
    let final_bg = bg_color_enhanced * vignette;
    
    let alpha_blend = curve_alpha + glow_alpha;
    let final_color = mix(final_bg, closest_color * (1.0 + glow_alpha * 0.3), alpha_blend);
    
    return vec4<f32>(final_color, 1.0);
}