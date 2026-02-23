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
}

@group(0) @binding(0) var<uniform> params: Params;

fn lissajous(t: f32, freq_x: f32, freq_y: f32, phase: f32) -> vec2<f32> {
    let x = sin(freq_x * t + phase);
    let y = sin(freq_y * t + phase + 0.5);
    return vec2<f32>(x, y);
}

fn distance_to_curve(uv: vec2<f32>, t: f32, freq_x: f32, freq_y: f32, phase: f32) -> f32 {
    var min_dist = 1000.0;
    
    let steps = 256u;
    var prev_pt = lissajous(0.0, freq_x, freq_y, phase);
    
    var i = 1u;
    loop {
        if (i > steps) { break; }
        let t_curr = f32(i) / f32(steps) * 6.28318;
        let curr_pt = lissajous(t_curr, freq_x, freq_y, phase);
        
        let pa = uv - prev_pt * 0.3;
        let ba = curr_pt * 0.3 - prev_pt * 0.3;
        let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        let dist = length(pa - ba * h);
        min_dist = min(min_dist, dist);
        
        prev_pt = curr_pt;
        i = i + 1u;
    }
    
    return min_dist;
}

fn hue_to_rgb(hue: f32) -> vec3<f32> {
    let h = hue % 6.0;
    let x = 1.0 - abs(h - 3.0);
    
    var rgb = vec3<f32>(0.0);
    if (h < 1.0) {
        rgb = vec3<f32>(1.0, h, 0.0);
    } else if (h < 2.0) {
        rgb = vec3<f32>(x, 1.0, 0.0);
    } else if (h < 3.0) {
        rgb = vec3<f32>(0.0, 1.0, h - 2.0);
    } else if (h < 4.0) {
        rgb = vec3<f32>(0.0, x, 1.0);
    } else if (h < 5.0) {
        rgb = vec3<f32>(h - 4.0, 0.0, 1.0);
    } else {
        rgb = vec3<f32>(1.0, 0.0, x);
    }
    
    return rgb;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let time = params.time * 0.5;
    
    var color = vec3<f32>(0.05, 0.05, 0.12);
    
    let phase1 = sin(time * 0.3) * 0.5;
    let dist1 = distance_to_curve(uv, time, 3.0, 2.0, phase1);
    let line1 = smoothstep(0.015, 0.002, dist1);
    let hue1 = atan2(uv.y, uv.x) * 0.955 + time * 0.5;
    let col1 = hue_to_rgb(hue1 * 3.0) * line1;
    color = color + col1 * 0.9;
    
    let phase2 = sin(time * 0.4 + 1.57) * 0.5;
    let dist2 = distance_to_curve(uv, time, 4.0, 3.0, phase2);
    let line2 = smoothstep(0.015, 0.002, dist2);
    let hue2 = atan2(uv.y, uv.x) * 0.955 + time * 0.4;
    let col2 = hue_to_rgb(hue2 * 3.0 + 2.0) * line2;
    color = color + col2 * 0.85;
    
    let phase3 = sin(time * 0.35 + 3.14) * 0.5;
    let dist3 = distance_to_curve(uv, time, 5.0, 4.0, phase3);
    let line3 = smoothstep(0.015, 0.002, dist3);
    let hue3 = atan2(uv.y, uv.x) * 0.955 + time * 0.3;
    let col3 = hue_to_rgb(hue3 * 3.0 + 4.0) * line3;
    color = color + col3 * 0.8;
    
    let phase4 = sin(time * 0.32 + 4.71) * 0.5;
    let dist4 = distance_to_curve(uv, time, 6.0, 5.0, phase4);
    let line4 = smoothstep(0.015, 0.002, dist4);
    let hue4 = atan2(uv.y, uv.x) * 0.955 + time * 0.25;
    let col4 = hue_to_rgb(hue4 * 3.0 + 1.0) * line4;
    color = color + col4 * 0.75;
    
    let phase5 = sin(time * 0.28 + 2.36) * 0.5;
    let dist5 = distance_to_curve(uv, time, 7.0, 6.0, phase5);
    let line5 = smoothstep(0.015, 0.002, dist5);
    let hue5 = atan2(uv.y, uv.x) * 0.955 + time * 0.2;
    let col5 = hue_to_rgb(hue5 * 3.0 + 3.0) * line5;
    color = color + col5 * 0.7;
    
    let glow = exp(-length(uv) * 1.5) * 0.15;
    color = color + vec3<f32>(glow * 0.3, glow * 0.2, glow * 0.5);
    
    let vignette = 1.0 - smoothstep(0.3, 1.2, length(uv));
    color = color * (0.7 + vignette * 0.3);
    
    return vec4<f32>(color, 1.0);
}