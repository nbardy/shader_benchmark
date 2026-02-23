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

fn point_to_segment_dist(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn epicycloid(theta: f32) -> vec2<f32> {
    let R = 4.0;
    let r = 1.0;
    let k = (R + r) / r;
    
    let x = (R + r) * cos(theta) - r * cos(k * theta);
    let y = (R + r) * sin(theta) - r * sin(k * theta);
    
    return vec2<f32>(x, y);
}

fn ref_circle_dist(p: vec2<f32>) -> f32 {
    let R = 4.0;
    let dist_to_center = length(p);
    return abs(dist_to_center - R);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    
    let uv = (pos.xy - res * 0.5) / res.y;
    
    let scale = 6.5;
    let p = uv * scale;
    
    var pixel_color = vec3<f32>(0.05, 0.05, 0.05);
    
    let ref_dist = ref_circle_dist(p);
    let R = 4.0;
    let dash_period = 0.3;
    let dash_phase = (atan2(p.y, p.x) / 6.28318530718) * dash_period;
    let dash_pattern = fract(dash_phase);
    let is_dash = select(0.0, 1.0, dash_pattern < 0.15);
    let ref_circle_line = smoothstep(0.08, 0.04, ref_dist) * is_dash;
    pixel_color = mix(pixel_color, vec3<f32>(0.3, 0.3, 0.3), ref_circle_line * 0.6);
    
    let num_segments = 512u;
    var min_curve_dist = 1000.0;
    var seg_idx = 0u;
    loop {
        if seg_idx >= num_segments { break; }
        
        let t0 = (f32(seg_idx) / f32(num_segments)) * 6.28318530718;
        let t1 = (f32(seg_idx + 1u) / f32(num_segments)) * 6.28318530718;
        
        let p0 = epicycloid(t0);
        let p1 = epicycloid(t1);
        
        let dist = point_to_segment_dist(p, p0, p1);
        min_curve_dist = min(min_curve_dist, dist);
        
        seg_idx = seg_idx + 1u;
    }
    
    let stroke_width = 0.008;
    let curve_line = smoothstep(stroke_width * 1.5, 0.0, min_curve_dist);
    let cyan = vec3<f32>(0.0, 0.733, 1.0);
    pixel_color = mix(pixel_color, cyan, curve_line);
    
    let cusp_offsets = array<f32, 4>(0.0, 1.5708, 3.14159, 4.71239);
    var cusp_idx = 0u;
    loop {
        if cusp_idx >= 4u { break; }
        
        let theta = cusp_offsets[cusp_idx];
        let cusp_pos = epicycloid(theta);
        let cusp_dist = length(p - cusp_pos);
        
        let cusp_radius = 0.013;
        let cusp_dot = smoothstep(cusp_radius, 0.0, cusp_dist);
        let red = vec3<f32>(1.0, 0.1, 0.1);
        pixel_color = mix(pixel_color, red, cusp_dot);
        
        cusp_idx = cusp_idx + 1u;
    }
    
    return vec4<f32>(pixel_color, 1.0);
}