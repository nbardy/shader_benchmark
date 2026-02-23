// Cycloid wave visualization with mirrored trough pattern
// Canvas: 2600×800 px with 100 px margins (left/right)
// Positive wave (orange #ffaa00, 5px), negative mirror (blue #0066ff, 5px)
// Grey baseline at y=0 (1px)

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

// Cycloid parametric equations: x(θ) = θ - sin(θ), y(θ) = 1 - cos(θ)
fn cycloid_point(theta: f32) -> vec2<f32> {
    let x = theta - sin(theta);
    let y = 1.0 - cos(theta);
    return vec2<f32>(x, y);
}

// Distance from point to line segment
fn distance_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Stroke rendering with anti-aliasing
fn stroke_alpha(dist: f32, stroke_width: f32) -> f32 {
    let half_width = stroke_width * 0.5;
    return smoothstep(half_width + 0.5, half_width - 0.5, dist);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Canvas dimensions
    let canvas_width = 2600.0;
    let canvas_height = 800.0;
    let margin = 100.0;
    
    // Draw area
    let draw_width = canvas_width - 2.0 * margin;
    let draw_height = canvas_height * 0.5 - 10.0;
    
    // Normalize coordinates relative to draw area
    let px = pos.x - margin;
    let py = pos.y - canvas_height * 0.5;
    
    // Background: white
    var color = vec3<f32>(1.0, 1.0, 1.0);
    
    // Baseline at y=0 (grey, 1px)
    let baseline_dist = abs(py);
    if baseline_dist < 0.5 {
        color = mix(color, vec3<f32>(0.7, 0.7, 0.7), stroke_alpha(baseline_dist, 1.0));
    }
    
    // Cycloid wave parameters
    let theta_per_pixel = 12.0 * 3.14159265359 / draw_width;
    let theta = px * theta_per_pixel;
    
    // Find closest point on cycloid curve
    var min_dist_positive = 1e6;
    var min_dist_negative = 1e6;
    
    // Adaptive sampling along cycloid
    let num_samples = 1200u;
    
    for (var i = 0u; i < num_samples; i = i + 1u) {
        let t = f32(i) / f32(num_samples) * 12.0 * 3.14159265359;
        let p = cycloid_point(t);
        
        // Map cycloid space to screen space
        let screen_x = (p.x / (12.0 * 3.14159265359)) * draw_width;
        let screen_y_pos = p.y * draw_height;
        let screen_y_neg = -p.y * draw_height;
        
        // Distance to positive wave
        let dist_pos = distance_to_segment(
            vec2<f32>(px, py),
            vec2<f32>(screen_x, screen_y_pos),
            vec2<f32>(screen_x + 2.0, screen_y_pos + 2.0)
        );
        min_dist_positive = min(min_dist_positive, dist_pos);
        
        // Distance to negative (mirrored) wave
        let dist_neg = distance_to_segment(
            vec2<f32>(px, py),
            vec2<f32>(screen_x, screen_y_neg),
            vec2<f32>(screen_x + 2.0, screen_y_neg - 2.0)
        );
        min_dist_negative = min(min_dist_negative, dist_neg);
    }
    
    // Stroke widths
    let stroke_width = 5.0;
    
    // Orange for positive wave (#ffaa00)
    let orange = vec3<f32>(1.0, 0.667, 0.0);
    let orange_alpha = stroke_alpha(min_dist_positive, stroke_width);
    color = mix(color, orange, orange_alpha);
    
    // Blue for negative wave (#0066ff)
    let blue = vec3<f32>(0.0, 0.4, 1.0);
    let blue_alpha = stroke_alpha(min_dist_negative, stroke_width);
    color = mix(color, blue, blue_alpha);
    
    // Clamp to canvas bounds
    if (px < 0.0 || px > draw_width || py < -canvas_height * 0.5 || py > canvas_height * 0.5) {
        color = vec3<f32>(1.0, 1.0, 1.0);
    }
    
    return vec4<f32>(color, 1.0);
}