// Al-Khwarizmi's Geometric Algebra Shader
// Visualization of solving x² + 10x = 39 through geometric construction
// Problem: x² + 10x = 39
// Solution: Complete the square to get (x+5)² = 64, so x = 3

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
    _pad: f32,
}

@group(0) @binding(0) var<uniform> params: Params;

fn rect(p: vec2<f32>, center: vec2<f32>, size: vec2<f32>) -> f32 {
    let d = abs(p - center) - size * 0.5;
    let outside = length(max(d, vec2<f32>(0.0)));
    let inside = max(d.x, d.y);
    return max(outside, -inside);
}

fn line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, width: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - width;
}

fn circle(p: vec2<f32>, center: vec2<f32>, r: f32) -> f32 {
    return length(p - center) - r;
}

fn drawIslamicPattern(p: vec2<f32>, scale: f32) -> f32 {
    var result = 1000.0;
    
    let angle = atan2(p.y, p.x);
    let radius = length(p);
    
    let folds = 8.0;
    let folded_angle = abs(angle - round(angle / (6.28318 / folds)) * (6.28318 / folds));
    
    let star_dist = radius * cos(folded_angle * 2.0) - 0.3 * scale;
    result = min(result, abs(star_dist) - 0.02);
    
    let circle_pattern = abs(mod(radius * 3.0, 0.15) - 0.075) - 0.01;
    result = min(result, circle_pattern);
    
    return result;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    var p = (uv - vec2<f32>(0.5)) * 2.0;
    p.x *= aspect;
    
    let t = fract(params.time / 5.0);
    
    // Background - Islamic manuscript color
    var color = vec3<f32>(0.996, 0.949, 0.78);
    
    let base_size = 0.25;
    
    // Step 1: Initial square (x²)
    let step1_progress = smoothstep(0.0, 0.15, t);
    let square_x_size = base_size * step1_progress;
    let square_x = rect(p, vec2<f32>(0.0), vec2<f32>(square_x_size));
    
    // Step 2: Four rectangles
    let step2_progress = smoothstep(0.15, 0.35, t);
    let rect_width = base_size * 0.1 * step2_progress;
    let rect_length = square_x_size;
    
    let rect_top = rect(p, vec2<f32>(0.0, square_x_size + rect_width * 0.5), 
                        vec2<f32>(rect_length, rect_width));
    let rect_bottom = rect(p, vec2<f32>(0.0, -square_x_size - rect_width * 0.5), 
                           vec2<f32>(rect_length, rect_width));
    let rect_right = rect(p, vec2<f32>(square_x_size + rect_width * 0.5, 0.0), 
                          vec2<f32>(rect_width, rect_length));
    let rect_left = rect(p, vec2<f32>(-square_x_size - rect_width * 0.5, 0.0), 
                         vec2<f32>(rect_width, rect_length));
    
    var rectangles = min(rect_top, min(rect_bottom, min(rect_right, rect_left)));
    
    // Step 3: Corner squares
    let step3_progress = smoothstep(0.35, 0.55, t);
    let corner_size = base_size * 0.1 * step3_progress;
    
    let corner_tl = rect(p, vec2<f32>(-square_x_size - corner_size, square_x_size + corner_size), 
                         vec2<f32>(corner_size, corner_size));
    let corner_tr = rect(p, vec2<f32>(square_x_size + corner_size, square_x_size + corner_size), 
                         vec2<f32>(corner_size, corner_size));
    let corner_bl = rect(p, vec2<f32>(-square_x_size - corner_size, -square_x_size - corner_size), 
                         vec2<f32>(corner_size, corner_size));
    let corner_br = rect(p, vec2<f32>(square_x_size + corner_size, -square_x_size - corner_size), 
                         vec2<f32>(corner_size, corner_size));
    
    var corners = min(corner_tl, min(corner_tr, min(corner_bl, corner_br)));
    
    // Step 4 & 5: Complete square
    let step45_progress = smoothstep(0.55, 0.95, t);
    let complete_size = (square_x_size + corner_size) * step45_progress;
    let outline_dist = rect(p, vec2<f32>(0.0), vec2<f32>(complete_size));
    
    var geometry_color = vec3<f32>(0.0);
    var alpha = 0.0;
    
    // Original square - deep blue
    if (square_x < 0.005) {
        geometry_color = vec3<f32>(0.118, 0.227, 0.537);
        alpha = max(alpha, 0.9);
    }
    
    // Rectangles - gold
    if (rectangles < 0.005) {
        geometry_color = vec3<f32>(0.957, 0.619, 0.067);
        alpha = max(alpha, 0.8);
    }
    
    // Corners - white
    if (corners < 0.005) {
        geometry_color = vec3<f32>(1.0, 1.0, 1.0);
        alpha = max(alpha, 0.7);
    }
    
    // Outlines
    if (abs(square_x) < 0.008 && step1_progress > 0.1) {
        geometry_color = mix(geometry_color, vec3<f32>(0.118, 0.227, 0.537), 0.3);
        alpha = max(alpha, 0.5);
    }
    
    if (abs(rectangles) < 0.008 && step2_progress > 0.1) {
        geometry_color = mix(geometry_color, vec3<f32>(0.957, 0.619, 0.067), 0.3);
        alpha = max(alpha, 0.4);
    }
    
    if (abs(outline_dist) < 0.015 && step45_progress > 0.1) {
        geometry_color = vec3<f32>(0.0, 0.0, 0.0);
        alpha = max(alpha, 0.6);
    }
    
    // Border decoration
    let border_outer = max(abs(p.x) - aspect * 0.95, abs(p.y) - 0.95);
    let border_inner = max(abs(p.x) - aspect * 0.9, abs(p.y) - 0.9);
    
    if (border_outer < 0.05 && border_inner > -0.02) {
        let pattern_p = p * 8.0;
        let pattern = drawIslamicPattern(pattern_p, 1.0);
        if (pattern < 0.01) {
            geometry_color = vec3<f32>(0.118, 0.227, 0.537);
            alpha = max(alpha, 0.4);
        }
    }
    
    // Solution highlight at end
    if (t > 0.85) {
        let solution_fade = smoothstep(0.85, 0.95, t);
        let sol_color = vec3<f32>(0.957, 0.619, 0.067) * solution_fade;
        geometry_color = mix(geometry_color, sol_color, solution_fade * 0.5);
        alpha = max(alpha, 0.3 * solution_fade);
    }
    
    let final_color = mix(color, geometry_color, alpha);
    
    return vec4<f32>(final_color, 1.0);
}