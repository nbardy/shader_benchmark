// Al-Khwarizmi's Geometric Algebra: x^2 + 10x = 39 -> (x + 5)^2 = 64
// Visualizing the birth of Algebra in 9th Century Baghdad

struct Params {
    resolution: vec2<f32>,
    time: f32, // Assuming seconds passed for animation
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

fn sd_rect(p: vec2<f32>, b: vec2<f32>) -> f32 {
    let d = abs(p) - b;
    return length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0);
}

fn draw_star_8(p: vec2<f32>, size: f32) -> f32 {
    let p_rot = p * 0.7071 + vec2<f32>(p.y, -p.x) * 0.7071;
    let box1 = sd_rect(p, vec2<f32>(size, size * 0.4));
    let box2 = sd_rect(p, vec2<f32>(size * 0.4, size));
    let box3 = sd_rect(p_rot, vec2<f32>(size, size * 0.4));
    let box4 = sd_rect(p_rot, vec2<f32>(size * 0.4, size));
    return min(min(box1, box2), min(box3, box4));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv_raw = (pos.xy * 2.0 - params.resolution) / min(params.resolution.x, params.resolution.y);
    let uv = uv_raw * 10.0; // Scale to coordinate system
    
    // Background: Traditional Islamic manuscript color (#FEF3C7)
    let manuscript_bg = vec3<f32>(0.996, 0.953, 0.780);
    var color = manuscript_bg;

    // Geometric constants for x^2 + 10x = 39 (x = 3)
    let x_val = 3.0;
    let half_coeff = 2.5; // 10x / 4 sides
    let t = params.time % 10.0;
    
    // Animation phases
    let phase1 = smoothstep(0.0, 2.0, t); // x^2 appears
    let phase2 = smoothstep(2.5, 4.5, t); // 4 rectangles added
    let phase3 = smoothstep(5.0, 7.0, t); // corners completed
    let phase4 = smoothstep(7.5, 9.0, t); // final solution highlighting

    // 1. Central Square (x^2)
    let d_sq = sd_rect(uv, vec2<f32>(x_val * 0.5 * phase1));
    let blue_sq = vec3<f32>(0.118, 0.227, 0.541); // #1E3A8A
    color = mix(color, blue_sq, 1.0 - smoothstep(0.0, 0.05, d_sq));

    // 2. Four Rectangles (10x is 4 pieces of 2.5 * x)
    let rect_size = vec2<f32>(x_val * 0.5, half_coeff * 0.5);
    let off = (x_val + half_coeff) * 0.5;
    
    let d_r1 = sd_rect(uv - vec2<f32>(0.0, off * phase2), rect_size);
    let d_r2 = sd_rect(uv - vec2<f32>(0.0, -off * phase2), rect_size);
    let d_r3 = sd_rect(uv - vec2<f32>(off * phase2, 0.0), rect_size.yx);
    let d_r4 = sd_rect(uv - vec2<f32>(-off * phase2, 0.0), rect_size.yx);
    
    let gold_rect = vec3<f32>(0.961, 0.620, 0.043); // #F59E0B
    let d_rects = min(min(d_r1, d_r2), min(d_r3, d_r4));
    color = mix(color, gold_rect, (1.0 - smoothstep(0.0, 0.05, d_rects)) * phase2);

    // 3. Corner Squares (Completing the square: 2.5 * 2.5 * 4 = 25)
    let corner_off = off;
    let c_size = vec2<f32>(half_coeff * 0.5);
    let d_c1 = sd_rect(uv - vec2<f32>(corner_off, corner_off), c_size * phase3);
    let d_c2 = sd_rect(uv - vec2<f32>(-corner_off, corner_off), c_size * phase3);
    let d_c3 = sd_rect(uv - vec2<f32>(corner_off, -corner_off), c_size * phase3);
    let d_c4 = sd_rect(uv - vec2<f32>(-corner_off, -corner_off), c_size * phase3);
    
    let d_corners = min(min(d_c1, d_c2), min(d_c3, d_c4));
    let corner_col = vec3<f32>(1.0, 1.0, 1.0);
    color = mix(color, blue_sq, 1.0 - smoothstep(0.0, 0.08, d_corners)); // Border
    color = mix(color, corner_col, 1.0 - smoothstep(0.0, 0.04, d_corners));

    // Decorative Islamic border logic
    let grid_uv = fract(uv_raw * 4.0) - 0.5;
    let border_mask = step(0.85, max(abs(uv_raw.x), abs(uv_raw.y)));
    let pattern = draw_star_8(grid_uv, 0.3);
    let pattern_col = mix(manuscript_bg, blue_sq, 1.0 - smoothstep(0.0, 0.02, pattern));
    color = mix(color, pattern_col, border_mask);

    // Vignette/Internal frame for the solution
    let frame = sd_rect(uv, vec2<f32>(8.0, 8.0));
    let frame_stroke = abs(frame) - 0.05;
    color = mix(color, blue_sq, 1.0 - smoothstep(0.0, 0.02, frame_stroke));
    
    // Final solution emphasis (Outer square boundary)
    let total_sq = sd_rect(uv, vec2<f32>(4.0));
    let highlight = abs(total_sq) - 0.1;
    let pulse = 0.5 + 0.5 * sin(params.time * 3.0);
    color = mix(color, gold_rect, (1.0 - smoothstep(0.0, 0.05, highlight)) * phase4 * pulse);

    return vec4<f32>(color, 1.0);
}