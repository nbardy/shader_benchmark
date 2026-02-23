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

fn dist_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn catmull_rom(p0: vec2<f32>, p1: vec2<f32>, p2: vec2<f32>, p3: vec2<f32>, t: f32) -> vec2<f32> {
    let t2 = t * t;
    let t3 = t2 * t;
    let a = -0.5 * t3 + t2 - 0.5 * t;
    let b = 1.5 * t3 - 2.5 * t2 + 1.0;
    let c = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
    let d = 0.5 * t3 - 0.5 * t2;
    return a * p0 + b * p1 + c * p2 + d * p3;
}

fn sample_curve(theta: f32) -> vec2<f32> {
    let k = 7.0;
    let r = abs(cos(k * theta));
    let x = r * cos(theta);
    let y = r * sin(theta);
    return vec2<f32>(x, y);
}

fn draw_grid(uv: vec2<f32>) -> f32 {
    let dist_from_origin = length(uv);
    
    var grid_dist = 1000.0;
    
    // Concentric circles at 0.25, 0.5, 0.75, 1.0
    let circles = array<f32, 4>(0.25, 0.5, 0.75, 1.0);
    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
        let circle_r = circles[i];
        let d = abs(dist_from_origin - circle_r);
        grid_dist = min(grid_dist, d);
    }
    
    // Radial spokes every 15 degrees (π/12 radians)
    let angle = atan2(uv.y, uv.x);
    let spoke_interval = 3.1415926535 / 12.0;
    let angle_mod = abs((angle % spoke_interval) - spoke_interval * 0.5);
    let spoke_dist = angle_mod * dist_from_origin;
    grid_dist = min(grid_dist, spoke_dist);
    
    let line_width = 0.008;
    return select(0.0, 1.0, grid_dist < line_width);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let center = res * 0.5;
    let pixel_uv = (pos.xy - center) / res.x;
    
    // Scale factor: max r ≈ 1.0, want it at 90% of canvas half-width
    let scale = 0.9;
    let canvas_uv = pixel_uv / scale;
    
    // Sample curve at 8000 points with Catmull-Rom interpolation
    let num_samples = 8000u;
    var curve_dist = 1000.0;
    
    for (var i: u32 = 0u; i < num_samples; i = i + 1u) {
        let t_i = f32(i) / f32(num_samples);
        let theta_i = t_i * 2.0 * 3.1415926535;
        
        // Four consecutive samples for Catmull-Rom
        let i0 = select(num_samples - 1u, i - 1u, i > 0u);
        let i1 = i;
        let i2 = select(0u, i + 1u, i < num_samples - 1u);
        let i3 = select(1u, i + 2u, i < num_samples - 2u);
        
        let t0 = f32(i0) / f32(num_samples);
        let t1 = f32(i1) / f32(num_samples);
        let t2 = f32(i2) / f32(num_samples);
        let t3 = f32(i3) / f32(num_samples);
        
        let theta0 = t0 * 2.0 * 3.1415926535;
        let theta1 = t1 * 2.0 * 3.1415926535;
        let theta2 = t2 * 2.0 * 3.1415926535;
        let theta3 = t3 * 2.0 * 3.1415926535;
        
        let p0 = sample_curve(theta0);
        let p1 = sample_curve(theta1);
        let p2 = sample_curve(theta2);
        let p3 = sample_curve(theta3);
        
        // Interpolate within this segment
        for (var j: u32 = 0u; j < 4u; j = j + 1u) {
            let t_local = f32(j) / 4.0;
            let p_interp = catmull_rom(p0, p1, p2, p3, t_local);
            let d = dist_to_segment(canvas_uv, p_interp, p1);
            curve_dist = min(curve_dist, d);
        }
    }
    
    // Render curve
    let stroke_width = 0.015; // ~6px at 1800px resolution
    let curve_alpha = select(0.0, 0.9, curve_dist < stroke_width);
    let curve_color = vec3<f32>(1.0, 0.333, 0.667); // #ff55aa
    
    // Render grid
    let grid = draw_grid(canvas_uv);
    let grid_color = vec3<f32>(0.267, 0.267, 0.267); // #444444
    
    // Composite
    let bg_color = vec3<f32>(1.0, 1.0, 1.0); // white background
    var final_color = bg_color;
    
    // Grid first (lower layer)
    final_color = mix(final_color, grid_color, grid * 0.8);
    
    // Curve on top
    final_color = mix(final_color, curve_color, curve_alpha);
    
    return vec4<f32>(final_color, 1.0);
}