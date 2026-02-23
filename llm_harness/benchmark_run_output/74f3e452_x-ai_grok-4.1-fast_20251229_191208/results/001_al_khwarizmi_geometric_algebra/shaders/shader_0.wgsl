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
    aspect: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn sd_box(p: vec2<f32>, b: vec2<f32>) -> f32 {
    let q = abs(p) - b;
    return length(max(q, vec2<f32>(0.0))) + min(max(q.x, q.y), 0.0);
}

fn line_sdf(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    let t = params.time;

    // Colors
    const BG_COLOR: vec3<f32> = vec3<f32>(0.996, 0.953, 0.780);
    const BLUE: vec3<f32> = vec3<f32>(0.118, 0.227, 0.541);
    const GOLD: vec3<f32> = vec3<f32>(0.961, 0.620, 0.043);
    const WHITE: vec3<f32> = vec3<f32>(1.000, 1.000, 1.000);
    const BLACK: vec3<f32> = vec3<f32>(0.000, 0.000, 0.000);
    const DARK_BLUE: vec3<f32> = vec3<f32>(0.080, 0.160, 0.400);
    const LABEL_GOLD: vec3<f32> = vec3<f32>(0.900, 0.700, 0.100);

    var color: vec3<f32> = BG_COLOR;

    let fw = 0.0025;

    // Decorative border and Islamic patterns
    let r = length(uv);
    let a = atan2(uv.y, uv.x);
    let border_d = abs(r - 0.92);
    let border = 1.0 - smoothstep(0.0, fw * 2.0, border_d);
    color = mix(color, GOLD * 0.6, border * 0.4);

    let marg = 1.0 - smoothstep(0.75, 0.93, r);
    let pat_a = sin(a * 8.0 * 6.283185) * 0.5 + 0.5;
    let pat_r = sin(r * 25.0 + t * 2.0) * sin(a * 16.0);
    let pattern = smoothstep(0.45, 0.55, pat_r) * marg;
    color = mix(color, vec3<f32>(0.70, 0.50, 0.30), pattern * 0.3);

    let duv = uv;

    // Diagram constants (scaled to fit ~0.7 of screen)
    const HALF_LARGE_UNIT: f32 = 0.35;
    const UNIT: f32 = HALF_LARGE_UNIT / 4.0;
    let half_x: f32 = 1.5 * UNIT;
    let half_add: f32 = 1.25 * UNIT;

    // Animation progress
    let cycle = 5.0;
    let ft = fract(t / cycle);
    let square_prog = min(1.0, ft / 0.20);
    let rect_prog = min(1.0, max(0.0, (ft - 0.20) / 0.30));
    let corner_prog = min(1.0, max(0.0, (ft - 0.50) / 0.30));
    let solve_prog = min(1.0, max(0.0, (ft - 0.80) / 0.20));

    let curr_half_x = half_x * square_prog;

    // Original square (x², deep blue)
    let d_square = sd_box(duv, vec2<f32>(curr_half_x));
    let square_fill = (1.0 - smoothstep(0.0, fw, d_square)) * square_prog;
    color = mix(color, BLUE, square_fill);

    // Rectangles (10x total, gold) - slide out
    let rect_pos_prog = rect_prog;

    // Left rect
    let left_pos = vec2<f32>(mix(-half_x, -half_x - half_add, rect_pos_prog), 0.0);
    let left_size = vec2<f32>(half_add, half_x);
    let d_left = sd_box(duv - left_pos, left_size);
    let left_fill = (1.0 - smoothstep(0.0, fw, d_left)) * rect_prog;
    color = mix(color, GOLD, left_fill);

    // Right rect
    let right_pos = vec2<f32>(mix(half_x, half_x + half_add, rect_pos_prog), 0.0);
    let d_right = sd_box(duv - right_pos, left_size);
    let right_fill = (1.0 - smoothstep(0.0, fw, d_right)) * rect_prog;
    color = mix(color, GOLD, right_fill);

    // Bottom rect
    let bottom_pos = vec2<f32>(0.0, mix(-half_x, -half_x - half_add, rect_pos_prog));
    let bottom_size = vec2<f32>(half_x, half_add);
    let d_bottom = sd_box(duv - bottom_pos, bottom_size);
    let bottom_fill = (1.0 - smoothstep(0.0, fw, d_bottom)) * rect_prog;
    color = mix(color, GOLD, bottom_fill);

    // Top rect
    let top_pos = vec2<f32>(0.0, mix(half_x, half_x + half_add, rect_pos_prog));
    let d_top = sd_box(duv - top_pos, bottom_size);
    let top_fill = (1.0 - smoothstep(0.0, fw, d_top)) * rect_prog;
    color = mix(color, GOLD, top_fill);

    // Corner squares (25 total, white)
    let bl_pos = vec2<f32>(-(half_x + half_add), -(half_x + half_add));
    let bl_size = vec2<f32>(half_add);
    let d_bl = sd_box(duv - bl_pos, bl_size);
    let bl_fill = (1.0 - smoothstep(0.0, fw, d_bl)) * corner_prog;
    color = mix(color, WHITE, bl_fill);

    let br_pos = vec2<f32>(half_x + half_add, -(half_x + half_add));
    let d_br = sd_box(duv - br_pos, bl_size);
    let br_fill = (1.0 - smoothstep(0.0, fw, d_br)) * corner_prog;
    color = mix(color, WHITE, br_fill);

    let tl_pos = vec2<f32>(-(half_x + half_add), half_x + half_add);
    let d_tl = sd_box(duv - tl_pos, bl_size);
    let tl_fill = (1.0 - smoothstep(0.0, fw, d_tl)) * corner_prog;
    color = mix(color, WHITE, tl_fill);

    let tr_pos = vec2<f32>(half_x + half_add, half_x + half_add);
    let d_tr = sd_box(duv - tr_pos, bl_size);
    let tr_fill = (1.0 - smoothstep(0.0, fw, d_tr)) * corner_prog;
    color = mix(color, WHITE, tr_fill);

    // Outlines / strokes
    let stroke_w = 0.009;
    let stroke_fw = fw * 3.0;

    // Square stroke (darker blue)
    let s_square = abs(d_square) - stroke_w;
    let a_square_s = 1.0 - smoothstep(0.0, stroke_fw, s_square);
    color = mix(color, DARK_BLUE, a_square_s * square_prog * 0.6);

    // Large square highlight (pulsing gold when solved)
    let large_half = half_x + half_add;
    let d_large = sd_box(duv, vec2<f32>(large_half));
    let large_stroke_w = 0.016 + 0.004 * sin(t * 8.0);
    let s_large = abs(d_large) - large_stroke_w;
    let a_large_s = (1.0 - smoothstep(0.0, stroke_fw * 2.0, s_large)) * solve_prog;
    color = mix(color, LABEL_GOLD, a_large_s * 0.7);

    // Corner strokes (blue)
    let s_corner_bl = abs(d_bl) - stroke_w;
    let a_corner_bl = 1.0 - smoothstep(0.0, stroke_fw, s_corner_bl);
    color = mix(color, BLUE, a_corner_bl * corner_prog * 0.5);

    let s_corner_br = abs(d_br) - stroke_w;
    let a_corner_br = 1.0 - smoothstep(0.0, stroke_fw, s_corner_br);
    color = mix(color, BLUE, a_corner_br * corner_prog * 0.5);

    let s_corner_tl = abs(d_tl) - stroke_w;
    let a_corner_tl = 1.0 - smoothstep(0.0, stroke_fw, s_corner_tl);
    color = mix(color, BLUE, a_corner_tl * corner_prog * 0.5);

    let s_corner_tr = abs(d_tr) - stroke_w;
    let a_corner_tr = 1.0 - smoothstep(0.0, stroke_fw, s_corner_tr);
    color = mix(color, BLUE, a_corner_tr * corner_prog * 0.5);

    // Labels: "39" (for right side of equation) - appears with rects
    let label39_pos = vec2<f32>(-0.68, 0.62);
    let label39_scale = 0.022;
    let lp39 = (duv - label39_pos) / label39_scale;
    let label39_mask = rect_prog * 0.8;
    let lfw = 0.018;
    let lwidth = 0.11;

    // Digit 3 for 39
    let p3_39 = lp39 - vec2<f32>(0.0, 0.0);
    var d3_39: f32 = 1e10;
    d3_39 = min(d3_39, line_sdf(p3_39, vec2<f32>(-0.32, 0.32), vec2<f32>(0.32, 0.32)));
    d3_39 = min(d3_39, line_sdf(p3_39, vec2<f32>(-0.18, 0.0), vec2<f32>(0.18, 0.0)));
    d3_39 = min(d3_39, line_sdf(p3_39, vec2<f32>(-0.32, -0.32), vec2<f32>(0.32, -0.32)));
    d3_39 = min(d3_39, line_sdf(p3_39, vec2<f32>(0.28, 0.28), vec2<f32>(0.28, 0.02)));
    d3_39 = min(d3_39, line_sdf(p3_39, vec2<f32>(0.28, 0.02), vec2<f32>(0.28, -0.28)));
    let stroke3_39 = (1.0 - smoothstep(0.0, lfw, abs(d3_39) - lwidth * 0.5)) * label39_mask;
    color = mix(color, BLACK, stroke3_39 * 0.9);

    // Digit 9 for 39
    let p9_39 = lp39 - vec2<f32>(0.75, 0.0);
    var d9_39: f32 = 1e10;
    d9_39 = min(d9_39, line_sdf(p9_39, vec2<f32>(-0.32, 0.32), vec2<f32>(0.32, 0.32)));
    d9_39 = min(d9_39, line_sdf(p9_39, vec2<f32>(-0.28, 0.28), vec2<f32>(-0.28, 0.02)));
    d9_39 = min(d9_39, line_sdf(p9_39, vec2<f32>(0.28, 0.28), vec2<f32>(0.28, 0.02)));
    d9_39 = min(d9_39, line_sdf(p9_39, vec2<f32>(-0.18, 0.0), vec2<f32>(0.18, 0.0)));
    d9_39 = min(d9_39, line_sdf(p9_39, vec2<f32>(0.28, 0.02), vec2<f32>(0.28, -0.28)));
    d9_39 = min(d9_39, line_sdf(p9_39, vec2<f32>(-0.32, -0.32), vec2<f32>(0.32, -0.32)));
    let stroke9_39 = (1.0 - smoothstep(0.0, lfw, abs(d9_39) - lwidth * 0.5)) * label39_mask;
    color = mix(color, BLACK, stroke9_39 * 0.9);

    // Solution label "x = 3" ornate frame and text
    let label_pos = vec2<f32>(0.0, -0.63);
    let label_scale = 0.038;
    let lp = (duv - label_pos) / label_scale;
    let label_mask = solve_prog;

    // Ornate gold frame
    let frame_size = vec2<f32>(0.16, 0.055);
    let frame_d = sd_box(duv - label_pos, frame_size);
    let frame_stroke_w = 0.004;
    let frame_a = (1.0 - smoothstep(0.0, fw * 4.0, abs(frame_d) - frame_stroke_w)) * label_mask;
    color = mix(color, LABEL_GOLD, frame_a * 0.8);

    // x symbol (cross)
    let px_center = vec2<f32>(-1.4, 0.0);
    let px = lp - px_center;
    let dx1 = line_sdf(px, vec2<f32>(-0.35, -0.35), vec2<f32>(0.35, 0.35));
    let dx2 = line_sdf(px, vec2<f32>(-0.35, 0.35), vec2<f32>(0.35, -0.35));
    let dx = min(dx1, dx2);
    let stroke_x = (1.0 - smoothstep(0.0, lfw * 1.2, abs(dx) - lwidth * 0.5)) * label_mask;
    color = mix(color, BLACK, stroke_x * 0.9);

    // = symbol (two horiz lines)
    let eq_center = vec2<f32>(0.22, 0.0);
    let peq = lp - eq_center;
    let deq1 = line_sdf(peq, vec2<f32>(-0.38, 0.16), vec2<f32>(0.38, 0.16));
    let deq2 = line_sdf(peq, vec2<f32>(-0.38, -0.16), vec2<f32>(0.38, -0.16));
    let deq = min(deq1, deq2);
    let stroke_eq = (1.0 - smoothstep(0.0, lfw * 1.2, abs(deq) - lwidth * 0.5)) * label_mask;
    color = mix(color, BLACK, stroke_eq * 0.9);

    // 3 digit
    let p3 = lp - vec2<f32>(1.25, 0.0);
    var d3: f32 = 1e10;
    d3 = min(d3, line_sdf(p3, vec2<f32>(-0.35, 0.35), vec2<f32>(0.35, 0.35)));
    d3 = min(d3, line_sdf(p3, vec2<f32>(-0.20, 0.0), vec2<f32>(0.20, 0.0)));
    d3 = min(d3, line_sdf(p3, vec2<f32>(-0.35, -0.35), vec2<f32>(0.35, -0.35)));
    d3 = min(d3, line_sdf(p3, vec2<f32>(0.30, 0.30), vec2<f32>(0.30, 0.02)));
    d3 = min(d3, line_sdf(p3, vec2<f32>(0.30, 0.02), vec2<f32>(0.30, -0.30)));
    let stroke3 = (1.0 - smoothstep(0.0, lfw * 1.2, abs(d3) - lwidth * 0.5)) * label_mask;
    color = mix(color, BLACK, stroke3 * 0.9);

    return vec4<f32>(color, 1.0);
}