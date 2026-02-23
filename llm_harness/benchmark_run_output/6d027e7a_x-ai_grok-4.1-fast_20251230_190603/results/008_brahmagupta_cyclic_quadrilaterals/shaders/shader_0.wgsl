@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

fn sd_box(p: vec2<f32>, b: vec2<f32>) -> f32 {
    let q: vec2<f32> = abs(p) - b;
    return length(max(q, vec2<f32>(0.0))) + min(max(q.x, q.y), 0.0);
}

fn digit_dist(luv: vec2<f32>, dig: u32) -> f32 {
    let patterns: array<u32,10> = array<u32,10>(
        0x3Fu, 0x06u, 0x5Bu, 0x4Fu,
        0x66u, 0x6Du, 0x7Du, 0x07u,
        0x7Fu, 0x6Fu
    );
    let bits: u32 = patterns[dig];
    let seg_centers: array<vec2<f32>,7> = array<vec2<f32>,7>(
        vec2<f32>( 0.0,  0.62),
        vec2<f32>( 0.52,  0.32),
        vec2<f32>( 0.52, -0.32),
        vec2<f32>( 0.0, -0.62),
        vec2<f32>(-0.52, -0.32),
        vec2<f32>(-0.52,  0.32),
        vec2<f32>( 0.0,   0.0 )
    );
    let seg_halfsizes: array<vec2<f32>,7> = array<vec2<f32>,7>(
        vec2<f32>(0.44, 0.08),
        vec2<f32>(0.08, 0.28),
        vec2<f32>(0.08, 0.28),
        vec2<f32>(0.44, 0.08),
        vec2<f32>(0.08, 0.28),
        vec2<f32>(0.08, 0.28),
        vec2<f32>(0.44, 0.06)
    );
    var min_dist: f32 = 9e9;
    for(var i: u32 = 0u; i < 7u; i = i + 1u) {
        if ((bits & (1u << i)) != 0u) {
            let d: f32 = sd_box(luv - seg_centers[i], seg_halfsizes[i]);
            min_dist = min(min_dist, d);
        }
    }
    return min_dist;
}

fn render_number_dist(frag_uv: vec2<f32>, center: vec2<f32>, scale: f32, value: f32) -> f32 {
    let l_uv: vec2<f32> = (frag_uv - center) / scale;
    let v100: f32 = value * 100.0;
    let i100: f32 = floor(v100);
    let d_hund: u32 = u32(i100 % 10.0);
    let i10: f32 = floor(i100 / 10.0);
    let d_tenths: u32 = u32(i10 % 10.0);
    let i1: f32 = floor(i10 / 10.0);
    let d_int: u32 = u32(i1 % 10.0);
    var dist: f32 = 1e20;
    // integer digit
    let dc_int: vec2<f32> = vec2<f32>(-0.75, 0.0);
    let sub_uv_int: vec2<f32> = (l_uv - dc_int) * 1.2;
    dist = min(dist, digit_dist(sub_uv_int, d_int));
    // tenths digit
    let dc_tenths: vec2<f32> = vec2<f32>( 0.25, 0.0);
    let sub_uv_tenths: vec2<f32> = (l_uv - dc_tenths) * 1.2;
    dist = min(dist, digit_dist(sub_uv_tenths, d_tenths));
    // hundredths digit
    let dc_hund: vec2<f32> = vec2<f32>( 0.75, 0.0);
    let sub_uv_hund: vec2<f32> = (l_uv - dc_hund) * 1.2;
    dist = min(dist, digit_dist(sub_uv_hund, d_hund));
    // decimal point
    let dot_center: vec2<f32> = vec2<f32>(-0.25, -0.05);
    let dot_radius: f32 = 0.095;
    dist = min(dist, length(l_uv - dot_center) - dot_radius);
    return dist * scale;
}

fn sd_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa: vec2<f32> = p - a;
    let ba: vec2<f32> = b - a;
    let h: f32 = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

struct Params {
    resolution: vec2<f32>,
    time: f32,
    padding: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv: vec2<f32> = (pos.xy / params.resolution) * 2.0 - 1.0;
    var color: vec3<f32> = vec3<f32>(0.02, 0.02, 0.04);
    let circle_center: vec2<f32> = vec2<f32>(0.0, 0.0);
    let circle_radius: f32 = 0.70;
    let tau: f32 = 6.283185307179586;
    let base_angles: array<f32,4> = array<f32,4>(0.0, 1.2, 2.8, 4.7);
    let speeds: array<f32,4> = array<f32,4>(0.7, 0.9, 1.1, 1.3);
    let ang0: f32 = fract((base_angles[0u] + params.time * speeds[0u]) / tau) * tau;
    let ang1: f32 = fract((base_angles[1u] + params.time * speeds[1u]) / tau) * tau;
    let ang2: f32 = fract((base_angles[2u] + params.time * speeds[2u]) / tau) * tau;
    let ang3: f32 = fract((base_angles[3u] + params.time * speeds[3u]) / tau) * tau;
    let p0: vec2<f32> = circle_radius * vec2<f32>(cos(ang0), sin(ang0));
    let p1: vec2<f32> = circle_radius * vec2<f32>(cos(ang1), sin(ang1));
    let p2: vec2<f32> = circle_radius * vec2<f32>(cos(ang2), sin(ang2));
    let p3: vec2<f32> = circle_radius * vec2<f32>(cos(ang3), sin(ang3));
    let side_a: f32 = distance(p0, p1);
    let side_b: f32 = distance(p1, p2);
    let side_c: f32 = distance(p2, p3);
    let side_d: f32 = distance(p3, p0);
    let semiperim: f32 = (side_a + side_b + side_c + side_d) * 0.5;
    let area_term: f32 = (semiperim - side_a) * (semiperim - side_b) * (semiperim - side_c) * (semiperim - side_d);
    let area: f32 = sqrt(max(area_term, 0.0));
    let diag_p: f32 = distance(p0, p2);
    let diag_q: f32 = distance(p1, p3);
    let ptolemy_left: f32 = side_a * side_c + side_b * side_d;
    let ptolemy_right: f32 = diag_p * diag_q;
    // background gradient
    let gradient: f32 = (uv.y * 0.5 + 0.5);
    color += vec3<f32>(0.08, 0.06, 0.10) * gradient;
    // circle outline
    let circle_sdf: f32 = length(uv) - circle_radius;
    let circle_mask: f32 = 1.0 - smoothstep(0.0, 0.003, abs(circle_sdf));
    color += vec3<f32>(0.6, 0.6, 0.8) * circle_mask;
    // side lines
    let line_thick: f32 = 0.009;
    let seg_a: f32 = sd_segment(uv, p0, p1);
    let mask_a: f32 = 1.0 - smoothstep(0.0, line_thick, seg_a);
    color += vec3<f32>(1.0, 0.3, 0.3) * mask_a * 1.8;
    let seg_b: f32 = sd_segment(uv, p1, p2);
    let mask_b: f32 = 1.0 - smoothstep(0.0, line_thick, seg_b);
    color += vec3<f32>(0.3, 1.0, 0.3) * mask_b * 1.8;
    let seg_c: f32 = sd_segment(uv, p2, p3);
    let mask_c: f32 = 1.0 - smoothstep(0.0, line_thick, seg_c);
    color += vec3<f32>(0.3, 0.3, 1.0) * mask_c * 1.8;
    let seg_d: f32 = sd_segment(uv, p3, p0);
    let mask_d: f32 = 1.0 - smoothstep(0.0, line_thick, seg_d);
    color += vec3<f32>(1.0, 1.0, 0.3) * mask_d * 1.8;
    // diagonals
    let diag_thick: f32 = 0.006;
    let diag_p_seg: f32 = sd_segment(uv, p0, p2);
    let mask_diag_p: f32 = 1.0 - smoothstep(0.0, diag_thick, diag_p_seg);
    color += vec3<f32>(1.0, 0.4, 1.0) * mask_diag_p * 1.5;
    let diag_q_seg: f32 = sd_segment(uv, p1, p3);
    let mask_diag_q: f32 = 1.0 - smoothstep(0.0, diag_thick, diag_q_seg);
    color += vec3<f32>(0.4, 1.0, 1.0) * mask_diag_q * 1.5;
    // vertex dots
    let dot_rad: f32 = 0.012;
    let dot_thick: f32 = 0.004;
    var dp: f32 = length(uv - p0);
    var dot_mask: f32 = 1.0 - smoothstep(dot_rad - dot_thick, dot_rad + dot_thick, dp);
    color += vec3<f32>(1.0, 1.0, 1.0) * dot_mask * 3.0;
    dp = length(uv - p1);
    dot_mask = 1.0 - smoothstep(dot_rad - dot_thick, dot_rad + dot_thick, dp);
    color += vec3<f32>(1.0, 1.0, 1.0) * dot_mask * 3.0;
    dp = length(uv - p2);
    dot_mask = 1.0 - smoothstep(dot_rad - dot_thick, dot_rad + dot_thick, dp);
    color += vec3<f32>(1.0, 1.0, 1.0) * dot_mask * 3.0;
    dp = length(uv - p3);
    dot_mask = 1.0 - smoothstep(dot_rad - dot_thick, dot_rad + dot_thick, dp);
    color += vec3<f32>(1.0, 1.0, 1.0) * dot_mask * 3.0;
    // text labels
    let text_stroke: f32 = 0.003;
    let text_scale: f32 = 0.085;
    // a b c d
    let pos_a: vec2<f32> = vec2<f32>(-0.775, -0.82);
    let text_dist_a: f32 = render_number_dist(uv, pos_a, text_scale, side_a);
    let text_mask_a: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_a);
    color = mix(color, vec3<f32>(1.0, 0.5, 0.5), text_mask_a);
    let pos_b: vec2<f32> = vec2<f32>(-0.275, -0.82);
    let text_dist_b: f32 = render_number_dist(uv, pos_b, text_scale, side_b);
    let text_mask_b: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_b);
    color = mix(color, vec3<f32>(0.5, 1.0, 0.5), text_mask_b);
    let pos_c: vec2<f32> = vec2<f32>( 0.225, -0.82);
    let text_dist_c: f32 = render_number_dist(uv, pos_c, text_scale, side_c);
    let text_mask_c: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_c);
    color = mix(color, vec3<f32>(0.5, 0.5, 1.0), text_mask_c);
    let pos_d: vec2<f32> = vec2<f32>( 0.775, -0.82);
    let text_dist_d: f32 = render_number_dist(uv, pos_d, text_scale, side_d);
    let text_mask_d: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_d);
    color = mix(color, vec3<f32>(1.0, 1.0, 0.5), text_mask_d);
    // s area
    let pos_s: vec2<f32> = vec2<f32>(-0.5, -0.58);
    let text_dist_s: f32 = render_number_dist(uv, pos_s, text_scale, semiperim);
    let text_mask_s: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_s);
    color = mix(color, vec3<f32>(0.9, 0.9, 0.9), text_mask_s);
    let pos_area: vec2<f32> = vec2<f32>( 0.5, -0.58);
    let text_dist_area: f32 = render_number_dist(uv, pos_area, text_scale, area);
    let text_mask_area: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_area);
    color = mix(color, vec3<f32>(1.0, 0.8, 0.4), text_mask_area);
    // Ptolemy
    let pos_ptol_l: vec2<f32> = vec2<f32>(-0.5, -0.34);
    let text_dist_ptol_l: f32 = render_number_dist(uv, pos_ptol_l, text_scale, ptolemy_left);
    let text_mask_ptol_l: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_ptol_l);
    color = mix(color, vec3<f32>(0.6, 1.0, 0.6), text_mask_ptol_l);
    let pos_ptol_r: vec2<f32> = vec2<f32>( 0.5, -0.34);
    let text_dist_ptol_r: f32 = render_number_dist(uv, pos_ptol_r, text_scale, ptolemy_right);
    let text_mask_ptol_r: f32 = 1.0 - smoothstep(0.0, text_stroke, text_dist_ptol_r);
    color = mix(color, vec3<f32>(0.6, 1.0, 0.6), text_mask_ptol_r);
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
    return vec4<f32>(color, 1.0);
}