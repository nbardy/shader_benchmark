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

fn sd_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ab = b - a;
    let proj = clamp(dot(pa, ab) / dot(ab, ab), 0.0, 1.0);
    return length(pa - proj * ab);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let fit = min(params.resolution.x, params.resolution.y);
    let diagram_uv = (pos.xy / fit * 2.0) - 1.0;
    let world_pos = diagram_uv * 4.0;

    let cycle_time = 5.0;
    let progress = fract(params.time / cycle_time);

    let p_central = smoothstep(0.0, 0.12, progress);
    let p_rects = smoothstep(0.12, 0.45, progress);
    let p_corners = smoothstep(0.45, 0.70, progress);
    let p_lines = smoothstep(0.70, 0.85, progress);
    let p_solution = smoothstep(0.85, 1.0, progress);

    const central_side: f32 = 3.0;
    const rect_side: f32 = 2.5;
    const large_half: f32 = 4.0;

    let central_half_curr = (central_side / 2.0) * p_central;
    let rect_w_curr = rect_side * p_rects;
    let corner_w_curr = rect_side * p_corners;

    var color: vec3<f32> = vec3<f32>(0.996, 0.953, 0.780);

    // Central square (deep blue, x²)
    let central_d = sd_box(world_pos, vec2<f32>(central_half_curr));
    if (central_d < 0.0) {
        color = vec3<f32>(0.118, 0.227, 0.541);
    }

    // Right rectangle (gold)
    let right_center = vec2<f32>(central_half_curr + rect_w_curr / 2.0, 0.0);
    let right_half = vec2<f32>(rect_w_curr / 2.0, central_half_curr);
    let right_d = sd_box(world_pos - right_center, right_half);
    if (right_d < 0.0) {
        color = vec3<f32>(0.961, 0.620, 0.043);
    }

    // Left rectangle (gold)
    let left_center = vec2<f32>(-central_half_curr - rect_w_curr / 2.0, 0.0);
    let left_half = vec2<f32>(rect_w_curr / 2.0, central_half_curr);
    let left_d = sd_box(world_pos - left_center, left_half);
    if (left_d < 0.0) {
        color = vec3<f32>(0.961, 0.620, 0.043);
    }

    // Top rectangle (gold)
    let top_center = vec2<f32>(0.0, central_half_curr + rect_w_curr / 2.0);
    let top_half = vec2<f32>(central_half_curr, rect_w_curr / 2.0);
    let top_d = sd_box(world_pos - top_center, top_half);
    if (top_d < 0.0) {
        color = vec3<f32>(0.961, 0.620, 0.043);
    }

    // Bottom rectangle (gold)
    let bottom_center = vec2<f32>(0.0, -central_half_curr - rect_w_curr / 2.0);
    let bottom_half = vec2<f32>(central_half_curr, rect_w_curr / 2.0);
    let bottom_d = sd_box(world_pos - bottom_center, bottom_half);
    if (bottom_d < 0.0) {
        color = vec3<f32>(0.961, 0.620, 0.043);
    }

    // Top-right corner (white)
    let tr_center = vec2<f32>(central_half_curr + corner_w_curr / 2.0, central_half_curr + corner_w_curr / 2.0);
    let corner_half = vec2<f32>(corner_w_curr / 2.0);
    let tr_d = sd_box(world_pos - tr_center, corner_half);
    if (tr_d < 0.0) {
        color = vec3<f32>(1.0);
    }

    // Top-left corner (white)
    let tl_center = vec2<f32>(-central_half_curr - corner_w_curr / 2.0, central_half_curr + corner_w_curr / 2.0);
    let tl_d = sd_box(world_pos - tl_center, corner_half);
    if (tl_d < 0.0) {
        color = vec3<f32>(1.0);
    }

    // Bottom-right corner (white)
    let br_center = vec2<f32>(central_half_curr + corner_w_curr / 2.0, -central_half_curr - corner_w_curr / 2.0);
    let br_d = sd_box(world_pos - br_center, corner_half);
    if (br_d < 0.0) {
        color = vec3<f32>(1.0);
    }

    // Bottom-left corner (white)
    let bl_center = vec2<f32>(-central_half_curr - corner_w_curr / 2.0, -central_half_curr - corner_w_curr / 2.0);
    let bl_d = sd_box(world_pos - bl_center, corner_half);
    if (bl_d < 0.0) {
        color = vec3<f32>(1.0);
    }

    // Strokes
    let stroke_w = 0.03 * p_lines;
    let dark_blue = vec3<f32>(0.05, 0.10, 0.20);

    // Central stroke
    let central_full_half = vec2<f32>(central_side / 2.0);
    let central_stroke_d = sd_box(world_pos, central_full_half);
    let central_stroke_mask = smoothstep(stroke_w * 2.0, 0.0, abs(central_stroke_d));
    color = mix(color, dark_blue, central_stroke_mask);

    // Large square stroke (black, thicker)
    let large_stroke_d = sd_box(world_pos, vec2<f32>(large_half));
    let large_stroke_mask = smoothstep(stroke_w * 3.0, 0.0, abs(large_stroke_d));
    color = mix(color, vec3<f32>(0.0), large_stroke_mask);

    // Corners stroke (blue)
    let min_corner_d = min(min(tr_d, tl_d), min(br_d, bl_d));
    let corner_stroke_mask = smoothstep(stroke_w, 0.0, abs(min_corner_d));
    color = mix(color, dark_blue, corner_stroke_mask);

    // Islamic geometric border patterns
    let r = length(diagram_uv);
    let border_inner = 0.82;
    let border_outer = 0.98;
    let border_mask = smoothstep(border_outer, border_inner, r) * select(0.0, 1.0, p_central > 0.3);
    if (border_mask > 0.01) {
        let a = atan2(diagram_uv.y, diagram_uv.x);
        let pat1 = 0.5 + 0.5 * sin(8.0 * a + params.time * 0.1);
        let pat2 = 0.5 + 0.5 * sin((r - 0.88) * 20.0 + params.time * 0.2);
        let combined_pat = pat1 * pat2;
        let gold = vec3<f32>(0.961, 0.620, 0.043);
        let pat_mask = smoothstep(0.45, 0.55, combined_pat);
        let border_color = mix(dark_blue, gold, pat_mask);
        color = mix(color, border_color, border_mask);
    }

    // Solution label "x = 3" stylized with segments (gold, appears at end)
    let text_scale = 0.15;
    let text_base = vec2<f32>(0.0, -4.7);
    let local_p = (world_pos - text_base) / text_scale;

    // "x" (cross diagonals)
    let dx1 = sd_segment(local_p, vec2<f32>(-0.35, 0.35), vec2<f32>(0.35, -0.35));
    let dx2 = sd_segment(local_p, vec2<f32>(-0.35, -0.35), vec2<f32>(0.35, 0.35));
    let d_x = min(dx1, dx2);

    // "="
    let p_eq = local_p - vec2<f32>(0.75, 0.0);
    let de1 = sd_segment(p_eq, vec2<f32>(-0.35, 0.15), vec2<f32>(0.35, 0.15));
    let de2 = sd_segment(p_eq, vec2<f32>(-0.35, -0.15), vec2<f32>(0.35, -0.15));
    let d_eq = min(de1, de2);

    // "3" (7-segment approximation)
    let p_3 = local_p - vec2<f32>(1.45, 0.0);
    let d3a = sd_segment(p_3, vec2<f32>(-0.25, 0.45), vec2<f32>(0.25, 0.45)); // top
    let d3b = sd_segment(p_3, vec2<f32>(0.25, 0.45), vec2<f32>(0.25, -0.05)); // upper right
    let d3c = sd_segment(p_3, vec2<f32>(-0.25, 0.0), vec2<f32>(0.25, 0.0)); // middle
    let d3d = sd_segment(p_3, vec2<f32>(0.25, -0.45), vec2<f32>(0.25, 0.05)); // lower right
    let d3e = sd_segment(p_3, vec2<f32>(-0.25, -0.45), vec2<f32>(0.25, -0.45)); // bottom
    let d_3 = min(d3a, min(d3b, min(d3c, min(d3d, d3e))));

    let text_w = 0.018;
    let mask_x = smoothstep(text_w, 0.0, d_x);
    let mask_eq = smoothstep(text_w, 0.0, d_eq);
    let mask_3 = smoothstep(text_w, 0.0, d_3);
    let text_mask = max(max(mask_x, mask_eq), mask_3) * p_solution;
    let gold = vec3<f32>(0.961, 0.620, 0.043);
    color = mix(color, gold, text_mask);

    // Subtle paper texture
    let tex = sin(pos.x * 0.02) * sin(pos.y * 0.02) * 0.03;
    color = mix(color, vec3<f32>(0.98, 0.94, 0.77), tex);

    return vec4<f32>(color, 1.0);
}