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

fn sdBox(p: vec2<f32>, b: vec2<f32>) -> f32 {
    let q: vec2<f32> = abs(p) - b;
    return length(max(q, vec2<f32>(0.0))) + min(max(q.x, q.y), 0.0);
}

fn stroke(d: f32, w: f32) -> f32 {
    return 1.0 - smoothstep(0.0, w, abs(d));
}

fn fill(d: f32, w: f32) -> f32 {
    return smoothstep(w, -w, d);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv: vec2<f32> = pos.xy / params.resolution;
    var col: vec3<f32> = vec3<f32>(0.996, 0.953, 0.780);  // #FEF3C7

    // Border with Islamic-inspired pattern
    let border_dist: f32 = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
    let border_mask: f32 = smoothstep(0.06, 0.04, border_dist);
    let border_pat: f32 = sin(uv.x * 60.0) * sin(uv.y * 40.0) * 0.5 + 0.5;
    let border_col: vec3<f32> = mix(vec3<f32>(0.961, 0.620, 0.043), vec3<f32>(0.118, 0.227, 0.541), step(0.5, border_pat));
    col = mix(col, border_col, border_mask);

    // Main figure
    let pix_scale: f32 = 0.38;
    let pix: vec2<f32> = (uv - 0.5) / pix_scale;
    let t: f32 = fract(params.time * 0.15);
    let central_prog: f32 = smoothstep(0.0, 0.25, t);
    let rect_prog: f32 = smoothstep(0.25, 0.60, t);
    let corner_prog: f32 = smoothstep(0.60, 0.85, t);
    let reveal_prog: f32 = smoothstep(0.85, 1.0, t);

    let x_half: f32 = 1.5;
    let rect_half_perp: f32 = 1.25 * rect_prog;
    let corner_half: f32 = 1.25 * corner_prog;
    let line_w: f32 = 0.008;
    let fill_w: f32 = 0.015;

    // Central square (x², deep blue)
    let central_center: vec2<f32> = vec2<f32>(0.0);
    let central_half: vec2<f32> = vec2<f32>(x_half * central_prog);
    let central_d: f32 = sdBox(pix - central_center, central_half);
    let central_fill: f32 = fill(central_d, fill_w);
    let central_stroke: f32 = stroke(central_d, line_w);
    let central_pat: f32 = 0.7 + 0.3 * sin(pix.x * 12.0) * sin(pix.y * 12.0);
    let blue: vec3<f32> = vec3<f32>(0.118, 0.227, 0.541) * central_pat;
    col = mix(col, blue, central_fill);
    col = mix(col, vec3<f32>(0.05, 0.1, 0.2), central_stroke * (1.0 - central_fill));

    // Rectangles (gold, 2.5x each)
    let gold_base: vec3<f32> = vec3<f32>(0.961, 0.620, 0.043);

    // Left
    let left_center: vec2<f32> = vec2<f32>(-x_half - rect_half_perp, 0.0);
    let left_size: vec2<f32> = vec2<f32>(rect_half_perp * 2.0, x_half * 2.0);
    let left_d: f32 = sdBox(pix - left_center, left_size);
    let left_fill: f32 = fill(left_d, fill_w);
    let left_stroke: f32 = stroke(left_d, line_w);
    let left_pat: f32 = 0.6 + 0.4 * sin(length(pix - left_center) * 15.0 + atan2(pix.y - left_center.y, pix.x - left_center.x) * 6.0);
    col = mix(col, gold_base * left_pat, left_fill);
    col = mix(col, vec3<f32>(0.7, 0.4, 0.0), left_stroke * (1.0 - left_fill));

    // Right
    let right_center: vec2<f32> = vec2<f32>(x_half + rect_half_perp, 0.0);
    let right_size: vec2<f32> = vec2<f32>(rect_half_perp * 2.0, x_half * 2.0);
    let right_d: f32 = sdBox(pix - right_center, right_size);
    let right_fill: f32 = fill(right_d, fill_w);
    let right_stroke: f32 = stroke(right_d, line_w);
    let right_pat: f32 = 0.6 + 0.4 * sin(length(pix - right_center) * 15.0 + atan2(pix.y - right_center.y, pix.x - right_center.x) * 6.0);
    col = mix(col, gold_base * right_pat, right_fill);
    col = mix(col, vec3<f32>(0.7, 0.4, 0.0), right_stroke * (1.0 - right_fill));

    // Bottom
    let bottom_center: vec2<f32> = vec2<f32>(0.0, -x_half - rect_half_perp);
    let bottom_size: vec2<f32> = vec2<f32>(x_half * 2.0, rect_half_perp * 2.0);
    let bottom_d: f32 = sdBox(pix - bottom_center, bottom_size);
    let bottom_fill: f32 = fill(bottom_d, fill_w);
    let bottom_stroke: f32 = stroke(bottom_d, line_w);
    let bottom_pat: f32 = 0.6 + 0.4 * sin(length(pix - bottom_center) * 15.0 + atan2(pix.y - bottom_center.y, pix.x - bottom_center.x) * 6.0);
    col = mix(col, gold_base * bottom_pat, bottom_fill);
    col = mix(col, vec3<f32>(0.7, 0.4, 0.0), bottom_stroke * (1.0 - bottom_fill));

    // Top
    let top_center: vec2<f32> = vec2<f32>(0.0, x_half + rect_half_perp);
    let top_size: vec2<f32> = vec2<f32>(x_half * 2.0, rect_half_perp * 2.0);
    let top_d: f32 = sdBox(pix - top_center, top_size);
    let top_fill: f32 = fill(top_d, fill_w);
    let top_stroke: f32 = stroke(top_d, line_w);
    let top_pat: f32 = 0.6 + 0.4 * sin(length(pix - top_center) * 15.0 + atan2(pix.y - top_center.y, pix.x - top_center.x) * 6.0);
    col = mix(col, gold_base * top_pat, top_fill);
    col = mix(col, vec3<f32>(0.7, 0.4, 0.0), top_stroke * (1.0 - top_fill));

    // Corner squares (white)
    let white: vec3<f32> = vec3<f32>(1.0);
    let dark_blue: vec3<f32> = vec3<f32>(0.05, 0.1, 0.2);

    // BL
    let bl_center: vec2<f32> = vec2<f32>(-x_half - corner_half, -x_half - corner_half);
    let bl_size: vec2<f32> = vec2<f32>(corner_half * 2.0);
    let bl_d: f32 = sdBox(pix - bl_center, bl_size);
    let bl_fill: f32 = fill(bl_d, fill_w);
    let bl_stroke: f32 = stroke(bl_d, line_w);
    col = mix(col, white, bl_fill);
    col = mix(col, dark_blue, bl_stroke * (1.0 - bl_fill));

    // BR
    let br_center: vec2<f32> = vec2<f32>(x_half + corner_half, -x_half - corner_half);
    let br_d: f32 = sdBox(pix - br_center, bl_size);
    let br_fill: f32 = fill(br_d, fill_w);
    let br_stroke: f32 = stroke(br_d, line_w);
    col = mix(col, white, br_fill);
    col = mix(col, dark_blue, br_stroke * (1.0 - br_fill));

    // TL
    let tl_center: vec2<f32> = vec2<f32>(-x_half - corner_half, x_half + corner_half);
    let tl_d: f32 = sdBox(pix - tl_center, bl_size);
    let tl_fill: f32 = fill(tl_d, fill_w);
    let tl_stroke: f32 = stroke(tl_d, line_w);
    col = mix(col, white, tl_fill);
    col = mix(col, dark_blue, tl_stroke * (1.0 - tl_fill));

    // TR
    let tr_center: vec2<f32> = vec2<f32>(x_half + corner_half, x_half + corner_half);
    let tr_d: f32 = sdBox(pix - tr_center, bl_size);
    let tr_fill: f32 = fill(tr_d, fill_w);
    let tr_stroke: f32 = stroke(tr_d, line_w);
    col = mix(col, white, tr_fill);
    col = mix(col, dark_blue, tr_stroke * (1.0 - tr_fill));

    // Large completing square outline
    let large_half: vec2<f32> = vec2<f32>(4.0);
    let large_d: f32 = sdBox(pix, large_half);
    let large_w: f32 = line_w * (1.0 + reveal_prog * 3.0);
    let large_stroke: f32 = stroke(large_d, large_w);
    col = mix(col, dark_blue, large_stroke);

    // Highlight solution x=3 (bottom edge of central square, red pulse)
    let sol_line_center: vec2<f32> = vec2<f32>(0.0, -x_half);
    let sol_line_half: vec2<f32> = vec2<f32>(x_half, 0.006);
    let sol_d: f32 = sdBox(pix - sol_line_center, sol_line_half);
    let sol_stroke: f32 = stroke(sol_d, 0.012) * reveal_prog;
    let pulse: f32 = 0.5 + 0.5 * sin(params.time * 4.0);
    col = mix(col, vec3<f32>(1.0, 0.3, 0.3) * pulse, sol_stroke);

    // Subtle vignette
    let vig: f32 = length(uv - 0.5) * 2.0;
    col *= 1.0 - smoothstep(0.0, 1.0, vig) * 0.3;

    return vec4<f32>(col, 1.0);
}