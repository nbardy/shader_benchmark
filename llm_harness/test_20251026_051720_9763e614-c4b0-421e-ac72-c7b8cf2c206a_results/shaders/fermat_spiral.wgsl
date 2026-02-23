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
    let x = c * (1.0 - abs(hh % 2.0 - 1.0));
    
    var rgb = vec3<f32>(0.0);
    let h_int = u32(hh) % 6u;
    
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
    
    let m = v - c;
    return rgb + m;
}

fn distance_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn fermat_spiral_point(theta: f32, a: f32) -> vec2<f32> {
    let r_squared = a * a * theta;
    let r = sqrt(r_squared);
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let center = resolution * 0.5;
    let pixel_pos = pos.xy - center;
    
    let bg_color = vec3<f32>(0.02, 0.02, 0.05);
    var color = bg_color;
    
    let a = 0.5;
    let theta_max = 8.0 * 3.141592653589793;
    let num_segments = 512u;
    let line_width = 3.0;
    
    var min_dist = line_width;
    var closest_t = 0.0;
    
    for (var i = 0u; i < num_segments; i = i + 1u) {
        let t0 = f32(i) / f32(num_segments) * theta_max;
        let t1 = f32(i + 1u) / f32(num_segments) * theta_max;
        
        let p0 = fermat_spiral_point(t0, a) * 200.0;
        let p1 = fermat_spiral_point(t1, a) * 200.0;
        
        let dist = distance_to_segment(pixel_pos, p0, p1);
        
        if dist < min_dist {
            min_dist = dist;
            closest_t = (f32(i) + 0.5) / f32(num_segments);
        }
    }
    
    let stroke_alpha = smoothstep(line_width, line_width - 2.0, min_dist);
    let stroke_color = hsv_to_rgb(closest_t, 0.95, 1.0);
    
    color = mix(bg_color, stroke_color, stroke_alpha);
    
    return vec4<f32>(color, 1.0);
}