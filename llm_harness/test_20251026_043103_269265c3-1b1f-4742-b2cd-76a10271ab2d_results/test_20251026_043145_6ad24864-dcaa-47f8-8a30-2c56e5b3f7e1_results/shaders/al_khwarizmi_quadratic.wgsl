// Al-Khwarizmi's Geometric Solution to Quadratic Equations
// Visualizing x² + 10x = 39 through Islamic geometric algebra
// Historical shader honoring the 9th century House of Wisdom

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

// Islamic geometric pattern - 8-fold star tessellation
fn islamicPattern(uv: vec2<f32>, freq: f32) -> f32 {
    let angle = atan2(uv.y, uv.x);
    let r = length(uv);
    let pattern = sin(angle * 8.0) * cos(r * freq);
    return smoothstep(-0.3, 0.3, pattern);
}

// Smooth step with easing for animation
fn smoothAnimationStep(t: f32, start: f32, end: f32) -> f32 {
    let clamped = clamp((t - start) / (end - start), 0.0, 1.0);
    return clamped * clamped * (3.0 - 2.0 * clamped);
}

// Draw rectangle outline
fn drawRect(p: vec2<f32>, center: vec2<f32>, width: f32, height: f32, thickness: f32) -> f32 {
    let local = abs(p - center);
    let edge = abs(max(local.x - width * 0.5, local.y - height * 0.5));
    let inside = max(local.x - width * 0.5, local.y - height * 0.5);
    return smoothstep(thickness, thickness - 0.002, 
                      select(edge, -inside, inside < 0.0));
}

// Draw filled rectangle
fn fillRect(p: vec2<f32>, center: vec2<f32>, width: f32, height: f32) -> f32 {
    let local = abs(p - center);
    return select(0.0, 1.0, local.x <= width * 0.5 && local.y <= height * 0.5);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let center = vec2<f32>(0.5, 0.5);
    let aspect = params.resolution.x / params.resolution.y;
    
    // Normalize coordinates to maintain aspect ratio
    let norm_uv = (uv - center) * vec2<f32>(aspect, 1.0);
    
    // Animation timeline (5 seconds total cycle)
    let cycle_time = params.time % 5.0;
    let t0 = smoothAnimationStep(cycle_time, 0.0, 0.8);     // Step 1: initial square
    let t1 = smoothAnimationStep(cycle_time, 0.8, 1.6);     // Step 2: rectangles appear
    let t2 = smoothAnimationStep(cycle_time, 1.6, 2.4);     // Step 3: corner squares
    let t3 = smoothAnimationStep(cycle_time, 2.4, 3.2);     // Step 4: highlight total area
    let t4 = smoothAnimationStep(cycle_time, 3.2, 5.0);     // Step 5: solution reveal
    
    // Background color - traditional Islamic manuscript
    var bg = vec3<f32>(0.996, 0.949, 0.780); // #FEF3C7
    
    // Add subtle Islamic pattern to background
    let border_pattern = islamicPattern(norm_uv * 3.0, 2.0) * 0.05;
    bg = bg - vec3<f32>(border_pattern);
    
    var color = bg;
    
    // Step 1: Draw initial square x² (deep blue)
    let square_side = 0.15;
    let square_x_pos = vec2<f32>(-0.35, 0.0);
    let x_square = drawRect(norm_uv, square_x_pos, square_side * 2.0, square_side * 2.0, 0.004);
    let x_square_fill = fillRect(norm_uv, square_x_pos, square_side * 2.0 - 0.01, square_side * 2.0 - 0.01);
    
    if (t0 > 0.0) {
        let fade = t0;
        let deep_blue = vec3<f32>(0.118, 0.227, 0.537); // #1E3A8A
        color = mix(color, deep_blue, x_square_fill * fade * 0.6);
        color = mix(color, deep_blue, x_square * fade);
    }
    
    // Step 2: Draw four rectangles 10x (gold colored)
    let rect_height = 0.1;
    let rect_width = 0.075;
    let gold = vec3<f32>(0.960, 0.618, 0.047); // #F59E0B
    
    // Top rectangle
    if (t1 > 0.0) {
        let top_rect_pos = mix(square_x_pos, vec2<f32>(-0.35, 0.25), t1);
        let top_rect = drawRect(norm_uv, top_rect_pos, rect_width * 2.0, rect_height * 2.0, 0.003);
        let top_fill = fillRect(norm_uv, top_rect_pos, rect_width * 2.0 - 0.008, rect_height * 2.0 - 0.008);
        color = mix(color, gold, top_fill * t1 * 0.6);
        color = mix(color, gold, top_rect * t1);
    }
    
    // Bottom rectangle
    if (t1 > 0.0) {
        let bot_rect_pos = mix(square_x_pos, vec2<f32>(-0.35, -0.25), t1);
        let bot_rect = drawRect(norm_uv, bot_rect_pos, rect_width * 2.0, rect_height * 2.0, 0.003);
        let bot_fill = fillRect(norm_uv, bot_rect_pos, rect_width * 2.0 - 0.008, rect_height * 2.0 - 0.008);
        color = mix(color, gold, bot_fill * t1 * 0.6);
        color = mix(color, gold, bot_rect * t1);
    }
    
    // Left rectangle
    if (t1 > 0.0) {
        let left_rect_pos = mix(square_x_pos, vec2<f32>(-0.6, 0.0), t1);
        let left_rect = drawRect(norm_uv, left_rect_pos, rect_height * 2.0, rect_width * 2.0, 0.003);
        let left_fill = fillRect(norm_uv, left_rect_pos, rect_height * 2.0 - 0.008, rect_width * 2.0 - 0.008);
        color = mix(color, gold, left_fill * t1 * 0.6);
        color = mix(color, gold, left_rect * t1);
    }
    
    // Right rectangle
    if (t1 > 0.0) {
        let right_rect_pos = mix(square_x_pos, vec2<f32>(-0.1, 0.0), t1);
        let right_rect = drawRect(norm_uv, right_rect_pos, rect_height * 2.0, rect_width * 2.0, 0.003);
        let right_fill = fillRect(norm_uv, right_rect_pos, rect_height * 2.0 - 0.008, rect_width * 2.0 - 0.008);
        color = mix(color, gold, right_fill * t1 * 0.6);
        color = mix(color, gold, right_rect * t1);
    }
    
    // Step 3: Draw four corner squares (white with blue outline)
    let corner_side = 0.05;
    let white = vec3<f32>(1.0, 1.0, 1.0);
    let blue_outline = vec3<f32>(0.118, 0.227, 0.537);
    
    // Top-left corner
    if (t2 > 0.0) {
        let tl_pos = vec2<f32>(-0.575, 0.275);
        let tl_rect = drawRect(norm_uv, tl_pos, corner_side * 2.0, corner_side * 2.0, 0.002);
        let tl_fill = fillRect(norm_uv, tl_pos, corner_side * 2.0 - 0.006, corner_side * 2.0 - 0.006);
        color = mix(color, white, tl_fill * t2 * 0.7);
        color = mix(color, blue_outline, tl_rect * t2);
    }
    
    // Top-right corner
    if (t2 > 0.0) {
        let tr_pos = vec2<f32>(-0.125, 0.275);
        let tr_rect = drawRect(norm_uv, tr_pos, corner_side * 2.0, corner_side * 2.0, 0.002);
        let tr_fill = fillRect(norm_uv, tr_pos, corner_side * 2.0 - 0.006, corner_side * 2.0 - 0.006);
        color = mix(color, white, tr_fill * t2 * 0.7);
        color = mix(color, blue_outline, tr_rect * t2);
    }
    
    // Bottom-left corner
    if (t2 > 0.0) {
        let bl_pos = vec2<f32>(-0.575, -0.275);
        let bl_rect = drawRect(norm_uv, bl_pos, corner_side * 2.0, corner_side * 2.0, 0.002);
        let bl_fill = fillRect(norm_uv, bl_pos, corner_side * 2.0 - 0.006, corner_side * 2.0 - 0.006);
        color = mix(color, white, bl_fill * t2 * 0.7);
        color = mix(color, blue_outline, bl_rect * t2);
    }
    
    // Bottom-right corner
    if (t2 > 0.0) {
        let br_pos = vec2<f32>(-0.125, -0.275);
        let br_rect = drawRect(norm_uv, br_pos, corner_side * 2.0, corner_side * 2.0, 0.002);
        let br_fill = fillRect(norm_uv, br_pos, corner_side * 2.0 - 0.006, corner_side * 2.0 - 0.006);
        color = mix(color, white, br_fill * t2 * 0.7);
        color = mix(color, blue_outline, br_rect * t2);
    }
    
    // Step 4: Highlight the completed square (x+5)² = 64
    let completed_square_side = 0.35;
    let completed_pos = vec2<f32>(-0.35, 0.0);
    if (t3 > 0.0) {
        let highlight = drawRect(norm_uv, completed_pos, completed_square_side * 2.0, completed_square_side * 2.0, 0.005);
        let highlight_color = mix(gold, white, sin(params.time * 3.0) * 0.5 + 0.5) * t3;
        color = mix(color, highlight_color, highlight * 0.5 * t3);
    }
    
    // Step 5: Display solution (x = 3)
    if (t4 > 0.0) {
        // Draw ornate frame for solution
        let solution_pos = vec2<f32>(0.35, 0.0);
        let frame_w = 0.25;
        let frame_h = 0.25;
        let frame = drawRect(norm_uv, solution_pos, frame_w, frame_h, 0.004);
        let frame_inner = drawRect(norm_uv, solution_pos, frame_w - 0.02, frame_h - 0.02, 0.002);
        
        color = mix(color, gold, frame * t4);
        color = mix(color, deep_blue, frame_inner * t4 * 0.3);
        
        // Solution box background
        let solution_bg = fillRect(norm_uv, solution_pos, frame_w - 0.024, frame_h - 0.024);
        color = mix(color, white, solution_bg * t4 * 0.8);
    }
    
    // Add decorative border
    let border_thickness = 0.015;
    let dist_to_edge = min(
        min(norm_uv.x + aspect * 0.49, aspect * 0.49 - norm_uv.x),
        min(norm_uv.y + 0.49, 0.49 - norm_uv.y)
    );
    
    if (dist_to_edge < border_thickness && dist_to_edge > border_thickness - 0.008) {
        let border_pattern_val = islamicPattern(norm_uv * 8.0, 3.0) * 0.3;
        color = mix(color, gold, border_pattern_val * (1.0 - dist_to_edge / border_thickness));
    }
    
    // Add subtle glow effects during animation
    let glow_intensity = smoothstep(1.0, 0.0, abs(cycle_time - 2.0) * 0.5) * 0.15;
    color = color + vec3<f32>(glow_intensity * 0.2, glow_intensity * 0.15, glow_intensity * 0.1);
    
    return vec4<f32>(color, 1.0);
}