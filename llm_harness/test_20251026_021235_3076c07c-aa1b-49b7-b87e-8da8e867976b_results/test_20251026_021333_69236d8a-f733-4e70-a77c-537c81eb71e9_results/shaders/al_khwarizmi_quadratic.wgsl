// Al-Khwarizmi's Geometric Solution to Quadratic Equations
// Visualizing x² + 10x = 39 through Islamic geometric algebra
// Historical shader: 9th century Baghdad mathematics in modern GPU code

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
}

@group(0) @binding(0) var<uniform> params: Params;

// ============================================================================
// Utility Functions
// ============================================================================

fn smoothstep_custom(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

fn draw_rectangle(uv: vec2<f32>, center: vec2<f32>, half_size: vec2<f32>) -> f32 {
    let delta = abs(uv - center);
    let edge = max(delta - half_size, vec2<f32>(0.0, 0.0));
    let outside = length(edge);
    let inside = max(delta.x, delta.y) - max(half_size.x, half_size.y);
    return smoothstep(0.01, -0.01, select(outside, inside, inside > 0.0));
}

fn draw_rectangle_outline(uv: vec2<f32>, center: vec2<f32>, half_size: vec2<f32>, thickness: f32) -> f32 {
    let delta = abs(uv - center);
    let border = max(delta - half_size, vec2<f32>(0.0, 0.0));
    let outside_dist = length(border);
    let inside_delta = delta - half_size;
    let inside_dist = max(inside_delta.x, inside_delta.y);
    
    let on_boundary = select(outside_dist, -inside_dist, inside_dist < 0.0);
    return smoothstep(thickness, thickness - 0.005, abs(on_boundary));
}

fn draw_line(uv: vec2<f32>, p0: vec2<f32>, p1: vec2<f32>, thickness: f32) -> f32 {
    let pa = uv - p0;
    let ba = p1 - p0;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let dist = length(pa - ba * h);
    return smoothstep(thickness, thickness - 0.003, dist);
}

fn draw_circle(uv: vec2<f32>, center: vec2<f32>, radius: f32) -> f32 {
    let dist = length(uv - center);
    return smoothstep(radius + 0.01, radius - 0.01, dist);
}

fn draw_circle_outline(uv: vec2<f32>, center: vec2<f32>, radius: f32, thickness: f32) -> f32 {
    let dist = abs(length(uv - center) - radius);
    return smoothstep(thickness, thickness - 0.003, dist);
}

// ============================================================================
// Islamic Geometric Pattern Functions
// ============================================================================

fn eight_fold_star(uv: vec2<f32>, center: vec2<f32>, size: f32) -> f32 {
    let local_uv = uv - center;
    let angle = atan2(local_uv.y, local_uv.x);
    let radius = length(local_uv);
    
    let normalized_angle = (angle + 3.14159) / (2.0 * 3.14159);
    let fold_angle = (normalized_angle * 8.0) % 1.0;
    let min_fold = min(fold_angle, 1.0 - fold_angle);
    
    let star_width = 0.15 * size;
    let ray_length = size;
    
    let in_ray = select(0.0, 1.0, min_fold < star_width / size);
    let radius_fade = smoothstep(ray_length + 0.05, ray_length - 0.05, radius) * smoothstep(-0.02, 0.02, radius - 0.1 * size);
    
    return in_ray * radius_fade;
}

fn arabesque_vine(uv: vec2<f32>, time: f32) -> f32 {
    var pattern = 0.0;
    
    let x_wave = sin(uv.x * 3.0 + time) * 0.1;
    let y_curve = uv.y + x_wave;
    
    let vine_line1 = smoothstep(0.015, 0.0, abs(y_curve - 0.3));
    let vine_line2 = smoothstep(0.015, 0.0, abs(y_curve - 0.7));
    
    pattern = max(vine_line1, vine_line2);
    
    return pattern;
}

// ============================================================================
// Animation State Functions
// ============================================================================

fn animate_phase(time: f32, phase_duration: f32) -> f32 {
    return (time % phase_duration) / phase_duration;
}

fn get_animation_phase(time: f32) -> u32 {
    let cycle_time = (time % 5.0);
    let phase = u32(cycle_time);
    return select(phase, 4u, phase >= 5u);
}

// ============================================================================
// Main Fragment Shader
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = pos.xy / params.resolution;
    let centered_uv = uv - vec2<f32>(0.5, 0.5);
    let aspect = params.resolution.x / params.resolution.y;
    let aspect_uv = vec2<f32>(centered_uv.x * aspect, centered_uv.y);
    
    // Background - traditional Islamic manuscript color
    var bg_color = vec3<f32>(0.996, 0.949, 0.78);  // #FEF3C7
    var final_color = bg_color;
    
    // Animation parameters
    let time = params.time;
    let phase = get_animation_phase(time);
    let phase_progress = animate_phase(time, 1.0);
    
    // ========================================================================
    // Core Geometric Construction
    // ========================================================================
    
    // Scale for visibility
    let scale = 0.15;
    let scaled_uv = aspect_uv / scale;
    
    // Dimensions from al-Khwarizmi's problem: x² + 10x = 39
    // Solution: x = 3
    let x_val = 3.0;
    let rect_width = 2.5;  // 10x / 4 = 2.5 for each rectangle
    
    // Central square (x²)
    let square_size = x_val * 0.5;
    let central_square = draw_rectangle(scaled_uv, vec2<f32>(0.0, 0.0), vec2<f32>(square_size, square_size));
    
    // Animation: central square appears in phase 0
    let central_alpha = select(0.0, phase_progress, phase == 0u);
    let central_color = vec3<f32>(0.118, 0.227, 0.537);  // #1E3A8A - deep blue
    final_color = mix(final_color, central_color, central_square * central_alpha);
    
    // Four rectangles (each 2.5 × x, representing part of 10x)
    let rect_size_x = rect_width * 0.5;
    let rect_size_y = x_val * 0.5;
    
    // Rectangle positions (top, right, bottom, left)
    let rect_top = draw_rectangle(scaled_uv, vec2<f32>(0.0, square_size + rect_size_y), vec2<f32>(rect_size_x, rect_size_y));
    let rect_right = draw_rectangle(scaled_uv, vec2<f32>(square_size + rect_size_x, 0.0), vec2<f32>(rect_size_x, rect_size_y));
    let rect_bottom = draw_rectangle(scaled_uv, vec2<f32>(0.0, -square_size - rect_size_y), vec2<f32>(rect_size_x, rect_size_y));
    let rect_left = draw_rectangle(scaled_uv, vec2<f32>(-square_size - rect_size_x, 0.0), vec2<f32>(rect_size_x, rect_size_y));
    
    let rect_combined = max(rect_top, max(rect_right, max(rect_bottom, rect_left)));
    
    // Animation: rectangles appear in phase 1
    let rect_alpha = select(0.0, phase_progress, phase == 1u);
    let rect_color = vec3<f32>(0.945, 0.618, 0.067);  // #F59E0B - gold
    final_color = mix(final_color, rect_color, rect_combined * rect_alpha);
    
    // Four corner squares (2.5 × 2.5, completing the larger square)
    let corner_size = rect_width * 0.5;
    let corner_top_right = draw_rectangle(scaled_uv, vec2<f32>(square_size + corner_size, square_size + corner_size), vec2<f32>(corner_size, corner_size));
    let corner_top_left = draw_rectangle(scaled_uv, vec2<f32>(-square_size - corner_size, square_size + corner_size), vec2<f32>(corner_size, corner_size));
    let corner_bottom_right = draw_rectangle(scaled_uv, vec2<f32>(square_size + corner_size, -square_size - corner_size), vec2<f32>(corner_size, corner_size));
    let corner_bottom_left = draw_rectangle(scaled_uv, vec2<f32>(-square_size - corner_size, -square_size - corner_size), vec2<f32>(corner_size, corner_size));
    
    let corner_combined = max(corner_top_right, max(corner_top_left, max(corner_bottom_right, corner_bottom_left)));
    
    // Animation: corners appear in phase 2
    let corner_alpha = select(0.0, phase_progress, phase == 2u);
    let corner_color = vec3<f32>(1.0, 1.0, 1.0);  // white
    final_color = mix(final_color, corner_color, corner_combined * corner_alpha);
    
    // Corner square outlines in blue
    let corner_outline = max(draw_rectangle_outline(scaled_uv, vec2<f32>(square_size + corner_size, square_size + corner_size), vec2<f32>(corner_size, corner_size), 0.08),
                        max(draw_rectangle_outline(scaled_uv, vec2<f32>(-square_size - corner_size, square_size + corner_size), vec2<f32>(corner_size, corner_size), 0.08),
                        max(draw_rectangle_outline(scaled_uv, vec2<f32>(square_size + corner_size, -square_size - corner_size), vec2<f32>(corner_size, corner_size), 0.08),
                            draw_rectangle_outline(scaled_uv, vec2<f32>(-square_size - corner_size, -square_size - corner_size), vec2<f32>(corner_size, corner_size), 0.08))));
    
    let corner_outline_alpha = select(0.0, phase_progress, phase == 2u);
    let corner_outline_color = vec3<f32>(0.118, 0.227, 0.537);  // #1E3A8A
    final_color = mix(final_color, corner_outline_color, corner_outline * corner_outline_alpha);
    
    // ========================================================================
    // Decorative Border & Islamic Patterns
    // ========================================================================
    
    // Outer decorative frame
    let margin = 0.4;
    let border_left = smoothstep(-margin - 0.02, -margin + 0.02, aspect_uv.x);
    let border_right = smoothstep(margin + 0.02, margin - 0.02, aspect_uv.x);
    let border_top = smoothstep(0.35 + 0.02, 0.35 - 0.02, aspect_uv.y);
    let border_bottom = smoothstep(-0.35 - 0.02, -0.35 + 0.02, aspect_uv.y);
    
    let border_mask = max(border_left * 0.5, max(border_right * 0.5, max(border_top * 0.5, border_bottom * 0.5)));
    let border_color = mix(vec3<f32>(0.118, 0.227, 0.537), vec3<f32>(0.945, 0.618, 0.067), border_mask);
    final_color = mix(final_color, border_color, border_mask * 0.4);
    
    // Eight-fold stars in corners (decorative)
    let star_tl = eight_fold_star(aspect_uv, vec2<f32>(-margin + 0.08, 0.32), 0.06);
    let star_tr = eight_fold_star(aspect_uv, vec2<f32>(margin - 0.08, 0.32), 0.06);
    let star_bl = eight_fold_star(aspect_uv, vec2<f32>(-margin + 0.08, -0.32), 0.06);
    let star_br = eight_fold_star(aspect_uv, vec2<f32>(margin - 0.08, -0.32), 0.06);
    
    let star_pattern = max(star_tl, max(star_tr, max(star_bl, star_br)));
    let star_color = vec3<f32>(0.945, 0.618, 0.067);  // gold
    final_color = mix(final_color, star_color, star_pattern * 0.7);
    
    // Arabesque vine patterns in margins
    let vine_pattern = arabesque_vine(aspect_uv, time * 0.5);
    let vine_color = vec3<f32>(0.118, 0.227, 0.537);
    final_color = mix(final_color, vine_color, vine_pattern * 0.4);
    
    // ========================================================================
    // Construction Lines & Visual Flow
    // ========================================================================
    
    // Dashed line showing construction
    if (phase >= 1u) {
        let line_alpha = select(0.0, 1.0 - abs(phase_progress - 0.5) * 2.0, phase == 1u || phase == 2u);
        
        // Vertical construction lines
        let v_line_left = draw_line(scaled_uv, vec2<f32>(-square_size - corner_size, -square_size - corner_size), vec2<f32>(-square_size - corner_size, square_size + corner_size), 0.05);
        let v_line_right = draw_line(scaled_uv, vec2<f32>(square_size + corner_size, -square_size - corner_size), vec2<f32>(square_size + corner_size, square_size + corner_size), 0.05);
        
        // Horizontal construction lines
        let h_line_top = draw_line(scaled_uv, vec2<f32>(-square_size - corner_size, square_size + corner_size), vec2<f32>(square_size + corner_size, square_size + corner_size), 0.05);
        let h_line_bottom = draw_line(scaled_uv, vec2<f32>(-square_size - corner_size, -square_size - corner_size), vec2<f32>(square_size + corner_size, -square_size - corner_size), 0.05);
        
        let construction_lines = max(v_line_left, max(v_line_right, max(h_line_top, h_line_bottom)));
        let line_color = vec3<f32>(0.945, 0.618, 0.067);
        final_color = mix(final_color, line_color, construction_lines * line_alpha * 0.5);
    }
    
    // ========================================================================
    // Solution Display (Phase 4)
    // ========================================================================
    
    // Final solution frame
    let solution_scale = select(0.0, phase_progress * 1.5, phase == 4u);
    let solution_frame_size = 0.15 * solution_scale;
    let solution_frame = draw_rectangle_outline(aspect_uv, vec2<f32>(0.0, 0.0), vec2<f32>(solution_frame_size, solution_frame_size), 0.06);
    
    let frame_color = vec3<f32>(0.945, 0.618, 0.067);
    final_color = mix(final_color, frame_color, solution_frame * 0.8);
    
    // Inner solution decoration
    let solution_inner_circle = draw_circle(aspect_uv, vec2<f32>(0.0, 0.0), solution_frame_size * 0.6);
    let inner_circle_color = vec3<f32>(1.0, 1.0, 1.0);
    final_color = mix(final_color, inner_circle_color, solution_inner_circle * solution_scale * 0.6);
    
    // ========================================================================
    // Subtle background gradient pattern
    // ========================================================================
    
    let pattern = sin(aspect_uv.x * 8.0) * cos(aspect_uv.y * 8.0) * 0.02;
    final_color = final_color + vec3<f32>(pattern, pattern * 0.5, pattern);
    
    return vec4<f32>(final_color, 1.0);
}