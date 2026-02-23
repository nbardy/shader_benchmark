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

fn sd_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ab = b - a;
    let h = clamp(dot(pa, ab) / dot(ab, ab), 0.0, 1.0);
    return length(pa - h * ab);
}

fn sd_box(p: vec2<f32>, b: vec2<f32>) -> f32 {
    let q = abs(p) - b;
    return length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0);
}

fn circle_sdf(p: vec2<f32>, r: f32) -> f32 {
    return length(p) - r;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let pi = 3.141592653589793;
    let tau = pi * 2.0;

    let grid_x = pos.x * 2.0 / params.resolution.x;
    let grid_y = pos.y * 2.0 / params.resolution.y;
    let quad_x = u32(floor(grid_x));
    let quad_y = u32(floor(grid_y));
    let config = quad_x + quad_y * 2u;

    let local_grid_x = fract(grid_x) * 2.0 - 1.0;
    let local_grid_y = fract(grid_y) * 2.0 - 1.0;

    let aspect = params.resolution.x / params.resolution.y;
    var local_uv = vec2<f32>(local_grid_x * aspect, local_grid_y);

    // Geometry parameters
    let radius = 0.55;
    let center = vec2<f32>(0.0, 0.0);

    // Angles per configuration
    var a0: f32 = 0.0;
    var a1: f32 = 0.0;
    var a2: f32 = 0.0;
    var a3: f32 = 0.0;
    if (config == 0u) {
        // Square
        let phi = 0.7853981633974483;
        a0 = phi;
        a1 = pi - phi;
        a2 = pi + phi;
        a3 = tau - phi;
    } else if (config == 1u) {
        // Wide rectangle
        let phi = 0.4636476090008061;
        a0 = phi;
        a1 = pi - phi;
        a2 = pi + phi;
        a3 = tau - phi;
    } else if (config == 2u) {
        // Tall rectangle
        let phi = 1.1071487177940904;
        a0 = phi;
        a1 = pi - phi;
        a2 = pi + phi;
        a3 = tau - phi;
    } else {
        // Irregular cyclic quad
        a0 = 0.3490658503988659;  // 20°
        a1 = 1.9198621771937625;  // 110°
        a2 = 3.490658503988659;   // 200°
        a3 = 5.235987755982988;   // 300°
    }

    let p0 = center + radius * vec2<f32>(cos(a0), sin(a0));
    let p1 = center + radius * vec2<f32>(cos(a1), sin(a1));
    let p2 = center + radius * vec2<f32>(cos(a2), sin(a2));
    let p3 = center + radius * vec2<f32>(cos(a3), sin(a3));

    // Side lengths
    let side_a = length(p1 - p0);
    let side_b = length(p2 - p1);
    let side_c = length(p3 - p2);
    let side_d = length(p0 - p3);
    let perim = side_a + side_b + side_c + side_d;
    let s = perim * 0.5;
    let term_a = s - side_a;
    let term_b = s - side_b;
    let term_c = s - side_c;
    let term_d = s - side_d;
    let area = sqrt(term_a * term_b * term_c * term_d);

    // Diagonals for Ptolemy
    let diag_e = length(p2 - p0);
    let diag_f = length(p3 - p1);
    let ptol_left = side_a * side_c + side_b * side_d;
    let ptol_right = diag_e * diag_f;

    // Max for scaling
    let max_side = max(side_a, max(side_b, max(side_c, side_d)));
    let bar_len_scale = 1.2 / max_side;
    let ptol_max = max(ptol_left, ptol_right);
    let vbar_scale = 0.9 / ptol_max;

    // Colors
    let col_a = vec3<f32>(1.0, 0.3, 0.3);
    let col_b = vec3<f32>(0.3, 1.0, 0.3);
    let col_c = vec3<f32>(0.3, 0.3, 1.0);
    let col_d = vec3<f32>(1.0, 1.0, 0.3);
    let col_s = (col_a * side_a + col_b * side_b + col_c * side_c + col_d * side_d) / perim;
    let col_diag1 = vec3<f32>(1.0, 0.4, 1.0);
    let col_diag2 = vec3<f32>(1.0, 0.6, 0.2);
    let col_ptol = vec3<f32>(0.9, 0.9, 0.9);
    let col_area = vec3<f32>(1.0, 0.9, 0.3);
    let col_point = vec3<f32>(1.0, 1.0, 1.0);
    let col_circle = vec3<f32>(0.4, 0.6, 1.0);
    let col_fill_base = vec3<f32>(0.15, 0.25, 0.4);

    // Background
    var color = vec3<f32>(0.02, 0.04, 0.08) + 0.15 * (local_uv.y * 0.5 + 0.5);

    // Circle fill colored by area
    let d_fill = circle_sdf(local_uv, radius * 0.92);
    let fill_cover = smoothstep(0.015, -0.015, d_fill);
    let fill_intensity = 0.3 + 0.7 * (area / (radius * radius * 2.0));
    let fill_col = col_fill_base * fill_intensity;
    color = mix(color, fill_col, fill_cover);

    // Circle stroke
    let d_circle = circle_sdf(local_uv, radius);
    let circle_w = 0.012;
    let circle_cover = 1.0 - smoothstep(0.0, circle_w, abs(d_circle));
    color = mix(color, col_circle, circle_cover);

    // Side segments (thick)
    let side_w = 0.018;
    let d_side_a = sd_segment(local_uv, p0, p1);
    let cover_a = 1.0 - smoothstep(0.0, side_w, abs(d_side_a));
    color = mix(color, col_a, cover_a);

    let d_side_b = sd_segment(local_uv, p1, p2);
    let cover_b = 1.0 - smoothstep(0.0, side_w, abs(d_side_b));
    color = mix(color, col_b, cover_b);

    let d_side_c = sd_segment(local_uv, p2, p3);
    let cover_c = 1.0 - smoothstep(0.0, side_w, abs(d_side_c));
    color = mix(color, col_c, cover_c);

    let d_side_d = sd_segment(local_uv, p3, p0);
    let cover_d = 1.0 - smoothstep(0.0, side_w, abs(d_side_d));
    color = mix(color, col_d, cover_d);

    // Diagonals (thinner)
    let diag_w = 0.010;
    let d_diag1 = sd_segment(local_uv, p0, p2);
    let cover_diag1 = 1.0 - smoothstep(0.0, diag_w, abs(d_diag1));
    color = mix(color, col_diag1, cover_diag1);

    let d_diag2 = sd_segment(local_uv, p1, p3);
    let cover_diag2 = 1.0 - smoothstep(0.0, diag_w, abs(d_diag2));
    color = mix(color, col_diag2, cover_diag2);

    // Vertices (points)
    let point_r = 0.014;
    let point_w = 0.006;
    let d_p0 = circle_sdf(local_uv - p0, point_r);
    let cover_p0 = 1.0 - smoothstep(0.0, point_w, abs(d_p0));
    color = mix(color, col_point, cover_p0);

    let d_p1 = circle_sdf(local_uv - p1, point_r);
    let cover_p1 = 1.0 - smoothstep(0.0, point_w, abs(d_p1));
    color = mix(color, col_point, cover_p1);

    let d_p2 = circle_sdf(local_uv - p2, point_r);
    let cover_p2 = 1.0 - smoothstep(0.0, point_w, abs(d_p2));
    color = mix(color, col_point, cover_p2);

    let d_p3 = circle_sdf(local_uv - p3, point_r);
    let cover_p3 = 1.0 - smoothstep(0.0, point_w, abs(d_p3));
    color = mix(color, col_point, cover_p3);

    // Side length bars (bottom, horizontal)
    let bar_thick = 0.028;
    let left_x = -0.88;
    let bar_y_base = -0.70;
    let bar_dy = 0.155;

    // a bar
    let bar_a_len = side_a * bar_len_scale;
    let bar_a_center = vec2<f32>(left_x + bar_a_len * 0.5, bar_y_base);
    let d_bar_a = sd_box(local_uv - bar_a_center, vec2<f32>(bar_a_len * 0.5, bar_thick));
    let cover_bar_a = 1.0 - smoothstep(0.0, 0.01, abs(d_bar_a));
    color = mix(color, col_a * 0.85, cover_bar_a);

    // b bar
    let bar_b_len = side_b * bar_len_scale;
    let bar_b_center = vec2<f32>(left_x + bar_b_len * 0.5, bar_y_base + bar_dy);
    let d_bar_b = sd_box(local_uv - bar_b_center, vec2<f32>(bar_b_len * 0.5, bar_thick));
    let cover_bar_b = 1.0 - smoothstep(0.0, 0.01, abs(d_bar_b));
    color = mix(color, col_b * 0.85, cover_bar_b);

    // c bar
    let bar_c_len = side_c * bar_len_scale;
    let bar_c_center = vec2<f32>(left_x + bar_c_len * 0.5, bar_y_base + 2.0 * bar_dy);
    let d_bar_c = sd_box(local_uv - bar_c_center, vec2<f32>(bar_c_len * 0.5, bar_thick));
    let cover_bar_c = 1.0 - smoothstep(0.0, 0.01, abs(d_bar_c));
    color = mix(color, col_c * 0.85, cover_bar_c);

    // d bar
    let bar_d_len = side_d * bar_len_scale;
    let bar_d_center = vec2<f32>(left_x + bar_d_len * 0.5, bar_y_base + 3.0 * bar_dy);
    let d_bar_d = sd_box(local_uv - bar_d_center, vec2<f32>(bar_d_len * 0.5, bar_thick));
    let cover_bar_d = 1.0 - smoothstep(0.0, 0.01, abs(d_bar_d));
    color = mix(color, col_d * 0.85, cover_bar_d);

    // s bar (below)
    let bar_s_len = s * bar_len_scale;
    let bar_s_center = vec2<f32>(left_x + bar_s_len * 0.5, bar_y_base - bar_dy);
    let d_bar_s = sd_box(local_uv - bar_s_center, vec2<f32>(bar_s_len * 0.5, bar_thick));
    let cover_bar_s = 1.0 - smoothstep(0.0, 0.01, abs(d_bar_s));
    color = mix(color, col_s * 0.9, cover_bar_s);

    // Ptolemy bars (right, vertical)
    let vbar_thick = 0.028;
    let vbar_left_x = 0.75;
    let vbar_right_x = 0.90;
    let vbar_y_c = 0.0;

    // Ptolemy left (ac + bd)
    let vbar_left_h = ptol_left * vbar_scale * 0.5;
    let vbar_left_size = vec2<f32>(vbar_thick, vbar_left_h);
    let d_vbar_left = sd_box(local_uv - vec2<f32>(vbar_left_x, vbar_y_c), vbar_left_size);
    let cover_vbar_left = 1.0 - smoothstep(0.0, 0.01, abs(d_vbar_left));
    color = mix(color, col_ptol, cover_vbar_left);

    // Ptolemy right (ef)
    let vbar_right_h = ptol_right * vbar_scale * 0.5;
    let vbar_right_size = vec2<f32>(vbar_thick, vbar_right_h);
    let d_vbar_right = sd_box(local_uv - vec2<f32>(vbar_right_x, vbar_y_c), vbar_right_size);
    let cover_vbar_right = 1.0 - smoothstep(0.0, 0.01, abs(d_vbar_right));
    color = mix(color, col_ptol, cover_vbar_right);

    // Area circle (top)
    let area_radius = area * 0.5;
    let area_center = vec2<f32>(0.0, 0.68);
    let d_area = circle_sdf(local_uv - area_center, area_radius);
    let area_cover = smoothstep(0.015, -0.015, d_area);
    color = mix(color, col_area, area_cover);

    // Stroke for area circle
    let area_stroke_cover = 1.0 - smoothstep(0.0, 0.012, abs(d_area));
    color = mix(color, col_area * 1.3, area_stroke_cover);

    return vec4<f32>(color, 1.0);
}