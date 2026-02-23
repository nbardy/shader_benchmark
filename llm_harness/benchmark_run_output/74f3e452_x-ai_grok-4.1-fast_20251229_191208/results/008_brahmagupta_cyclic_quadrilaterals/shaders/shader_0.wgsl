@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    var vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    time: f32,
    pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn draw_segment(col: ptr<function, vec4<f32>>, p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, seg_color: vec3<f32>, thickness: f32) {
    let pa = p - a;
    let ab = b - a;
    let h = clamp(dot(pa, ab) / dot(ab, ab), 0.0, 1.0);
    let closest = a + ab * h;
    let d = length(p - closest);
    let alpha = 1.0 - smoothstep(0.0, thickness, d);
    (*col).rgb = mix((*col).rgb, seg_color, alpha);
}

fn draw_circle_line(col: ptr<function, vec4<f32>>, p: vec2<f32>, cen: vec2<f32>, rad: f32, line_color: vec3<f32>, thick: f32) {
    let d = length(p - cen) - rad;
    let alpha = 1.0 - smoothstep(0.0, thick, abs(d));
    (*col).rgb = mix((*col).rgb, line_color, alpha);
}

fn draw_filled_circle(col: ptr<function, vec4<f32>>, p: vec2<f32>, cen: vec2<f32>, rad: f32, fill_color: vec3<f32>, edge: f32) {
    let dd = length(p - cen) - rad;
    let alpha = 1.0 - smoothstep(0.0, edge, max(dd, 0.0));
    (*col).rgb = mix((*col).rgb, fill_color, alpha);
}

fn draw_box(col: ptr<function, vec4<f32>>, p: vec2<f32>, bcenter: vec2<f32>, bsize: vec2<f32>, bcolor: vec3<f32>, edge: f32) {
    let q = abs(p - bcenter) - bsize * 0.5;
    let d = length(max(q, vec2<f32>(0.0))) + min(max(q.x, q.y), 0.0);
    let alpha = 1.0 - smoothstep(0.0, edge, d);
    (*col).rgb = mix((*col).rgb, bcolor, alpha);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let frag_uv = pos.xy / params.resolution;
    let center = vec2<f32>(0.5, 0.5);
    let t = params.time * 0.15;
    let pi = 3.141592653589793;
    let tau = pi * 2.0;
    let theta0 = fmod(t * 0.1, tau);
    let theta1 = fmod(1.3 + 0.45 * sin(t * 0.7), tau);
    let theta2 = fmod(2.9 + 0.35 * cos(t * 1.1), tau);
    let theta3 = fmod(5.2 + 0.55 * sin(t * 1.4), tau);
    let r = 0.28;
    let p0 = center + r * vec2<f32>(cos(theta0), sin(theta0));
    let p1 = center + r * vec2<f32>(cos(theta1), sin(theta1));
    let p2 = center + r * vec2<f32>(cos(theta2), sin(theta2));
    let p3 = center + r * vec2<f32>(cos(theta3), sin(theta3));
    let a_len = distance(p0, p1);
    let b_len = distance(p1, p2);
    let c_len = distance(p2, p3);
    let d_len = distance(p3, p0);
    let peri = a_len + b_len + c_len + d_len;
    let s = peri * 0.5;
    let area = sqrt((s - a_len) * (s - b_len) * (s - c_len) * (s - d_len));
    let diag1 = distance(p0, p2);
    let diag2 = distance(p1, p3);
    let p_left = diag1 * diag2;
    let p_right = a_len * c_len + b_len * d_len;
    let bg_y = smoothstep(0.0, 1.0, frag_uv.y);
    var col: vec4<f32> = vec4<f32>(
        mix(vec3<f32>(0.0, 0.02, 0.05), vec3<f32>(0.08, 0.1, 0.18), bg_y),
        1.0
    );
    draw_circle_line(&col, frag_uv, center, r, vec3<f32>(0.9, 0.95, 1.0), 0.0025);
    draw_segment(&col, frag_uv, p0, p1, vec3<f32>(1.0, 0.2, 0.2), 0.007);
    draw_segment(&col, frag_uv, p1, p2, vec3<f32>(0.2, 1.0, 0.2), 0.007);
    draw_segment(&col, frag_uv, p2, p3, vec3<f32>(0.2, 0.2, 1.0), 0.007);
    draw_segment(&col, frag_uv, p3, p0, vec3<f32>(1.0, 0.2, 1.0), 0.007);
    draw_segment(&col, frag_uv, p0, p2, vec3<f32>(1.0, 0.7, 0.3), 0.004);
    draw_segment(&col, frag_uv, p1, p3, vec3<f32>(0.3, 0.7, 1.0), 0.004);
    draw_filled_circle(&col, frag_uv, p0, 0.009, vec3<f32>(1.0), 0.002);
    draw_filled_circle(&col, frag_uv, p1, 0.009, vec3<f32>(1.0), 0.002);
    draw_filled_circle(&col, frag_uv, p2, 0.009, vec3<f32>(1.0), 0.002);
    draw_filled_circle(&col, frag_uv, p3, 0.009, vec3<f32>(1.0), 0.002);
    let bar_thick = 0.0015;
    let bar_max_side = 0.65;
    let norm_a = min(a_len / bar_max_side, 1.0);
    let norm_b = min(b_len / bar_max_side, 1.0);
    let norm_c = min(c_len / bar_max_side, 1.0);
    let norm_d = min(d_len / bar_max_side, 1.0);
    let bar_max_s = 1.3;
    let norm_s = min(s / bar_max_s, 1.0);
    let bar_max_p = 0.5;
    let norm_p = min(p_left / bar_max_p, 1.0);
    let bar_w = 0.03;
    let bar_mh = 0.11;
    let bar_bl_a = vec2<f32>(0.035, 0.035);
    let fill_h_a = norm_a * bar_mh;
    let bar_center_a = vec2<f32>(bar_bl_a.x + bar_w * 0.5, bar_bl_a.y + fill_h_a * 0.5);
    draw_box(&col, frag_uv, bar_center_a, vec2<f32>(bar_w, fill_h_a), vec3<f32>(1.0, 0.4, 0.4), bar_thick);
    let bar_bl_b = vec2<f32>(0.935, 0.035);
    let fill_h_b = norm_b * bar_mh;
    let bar_center_b = vec2<f32>(bar_bl_b.x + bar_w * 0.5, bar_bl_b.y + fill_h_b * 0.5);
    draw_box(&col, frag_uv, bar_center_b, vec2<f32>(bar_w, fill_h_b), vec3<f32>(0.4, 1.0, 0.4), bar_thick);
    let bar_bl_c = vec2<f32>(0.035, 0.835);
    let fill_h_c = norm_c * bar_mh;
    let bar_center_c = vec2<f32>(bar_bl_c.x + bar_w * 0.5, bar_bl_c.y + fill_h_c * 0.5);
    draw_box(&col, frag_uv, bar_center_c, vec2<f32>(bar_w, fill_h_c), vec3<f32>(0.4, 0.4, 1.0), bar_thick);
    let bar_bl_d = vec2<f32>(0.935, 0.835);
    let fill_h_d = norm_d * bar_mh;
    let bar_center_d = vec2<f32>(bar_bl_d.x + bar_w * 0.5, bar_bl_d.y + fill_h_d * 0.5);
    draw_box(&col, frag_uv, bar_center_d, vec2<f32>(bar_w, fill_h_d), vec3<f32>(1.0, 0.4, 1.0), bar_thick);
    let s_bar_bl = vec2<f32>(0.41, 0.03);
    let s_bar_h = 0.022;
    let s_fill_w = norm_s * 0.18;
    let s_center = vec2<f32>(s_bar_bl.x + s_fill_w * 0.5, s_bar_bl.y + s_bar_h * 0.5);
    draw_box(&col, frag_uv, s_center, vec2<f32>(s_fill_w, s_bar_h), vec3<f32>(0.9, 0.9, 0.9), bar_thick);
    let p_bar_bl = vec2<f32>(0.41, 0.945);
    let p_fill_w = norm_p * 0.18;
    let p_center = vec2<f32>(p_bar_bl.x + p_fill_w * 0.5, p_bar_bl.y + s_bar_h * 0.5);
    draw_box(&col, frag_uv, p_center, vec2<f32>(p_fill_w, s_bar_h), vec3<f32>(1.0, 0.9, 0.4), bar_thick);
    let area_center = vec2<f32>(0.5, 0.12);
    let area_r = area * 1.4;
    draw_filled_circle(&col, frag_uv, area_center, area_r, vec3<f32>(1.0, 0.9, 0.6), 0.003);
    return col;
}