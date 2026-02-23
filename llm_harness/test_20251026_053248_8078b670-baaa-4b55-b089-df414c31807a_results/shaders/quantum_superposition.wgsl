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

fn magma_colormap(t: f32) -> vec3<f32> {
    let t_clamped = clamp(t, 0.0, 1.0);
    
    if (t_clamped < 0.25) {
        let s = t_clamped / 0.25;
        return mix(vec3<f32>(0.001, 0.0, 0.014), vec3<f32>(0.166, 0.035, 0.38), s);
    } else if (t_clamped < 0.5) {
        let s = (t_clamped - 0.25) / 0.25;
        return mix(vec3<f32>(0.166, 0.035, 0.38), vec3<f32>(0.666, 0.164, 0.324), s);
    } else if (t_clamped < 0.75) {
        let s = (t_clamped - 0.5) / 0.25;
        return mix(vec3<f32>(0.666, 0.164, 0.324), vec3<f32>(0.962, 0.487, 0.143), s);
    } else {
        let s = (t_clamped - 0.75) / 0.25;
        return mix(vec3<f32>(0.962, 0.487, 0.143), vec3<f32>(0.989, 0.998, 0.645), s);
    }
}

fn eigenstate(x: f32, y: f32, n: u32, m: u32) -> f32 {
    let n_f = f32(n);
    let m_f = f32(m);
    let pi = 3.14159265358979;
    return 2.0 * sin(n_f * pi * x) * sin(m_f * pi * y);
}

fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn superposition(x: f32, y: f32) -> vec2<f32> {
    let pi = 3.14159265358979;
    let inv_sqrt3 = 0.57735026918962;
    
    let psi11 = eigenstate(x, y, 1u, 1u);
    
    let phase23 = vec2<f32>(cos(pi / 3.0), sin(pi / 3.0));
    let psi23 = eigenstate(x, y, 2u, 3u);
    let term23 = cmul(phase23, vec2<f32>(psi23, 0.0));
    
    let phase32 = vec2<f32>(cos(-pi / 4.0), sin(-pi / 4.0));
    let psi32 = eigenstate(x, y, 3u, 2u);
    let term32 = cmul(phase32, vec2<f32>(psi32, 0.0));
    
    let sum_real = psi11 + term23.x + term32.x;
    let sum_imag = term23.y + term32.y;
    
    return vec2<f32>(sum_real * inv_sqrt3, sum_imag * inv_sqrt3);
}

fn probability_density(x: f32, y: f32) -> f32 {
    let psi = superposition(x, y);
    return psi.x * psi.x + psi.y * psi.y;
}

fn isoline_near(density: f32, level: f32, width: f32) -> f32 {
    let dist = abs(density - level);
    return select(0.0, 1.0, dist < width);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let frame_size = 60.0;
    
    let in_frame = (pos.x < frame_size) || (pos.x >= (res.x - frame_size)) || 
                   (pos.y < frame_size) || (pos.y >= (res.y - frame_size));
    
    if (in_frame) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    let plot_width = res.x - 2.0 * frame_size;
    let plot_height = res.y - 2.0 * frame_size;
    let plot_x = (pos.x - frame_size) / plot_width;
    let plot_y = 1.0 - (pos.y - frame_size) / plot_height;
    
    let density = probability_density(plot_x, plot_y);
    let max_density = 20.0;
    let normalized_density = clamp(density / max_density, 0.0, 1.0);
    
    var color = magma_colormap(normalized_density);
    
    let line_width = 0.01;
    let isoline = isoline_near(density, 0.2, line_width) + 
                  isoline_near(density, 0.4, line_width) + 
                  isoline_near(density, 0.6, line_width);
    
    color = mix(color, vec3<f32>(1.0, 1.0, 1.0), clamp(isoline, 0.0, 1.0));
    
    return vec4<f32>(color, 1.0);
}