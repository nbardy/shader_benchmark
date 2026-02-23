@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    resolution: vec2<f32>,
    time: f32,
    unused: f32,
};

fn hash21(p: vec2<f32>) -> f32 {
    let n = sin(dot(p, vec2<f32>(127.1, 311.7)));
    return fract(abs(n) * 43758.5453123);
}

fn noise2d(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    let a = hash21(i);
    let b = hash21(i + vec2<f32>(1.0, 0.0));
    let c = hash21(i + vec2<f32>(0.0, 1.0));
    let d = hash21(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

fn fbm(p: vec2<f32>) -> f32 {
    var x: f32 = 0.0;
    var amp: f32 = 0.5;
    var freq: f32 = 1.0;
    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
        x = x + amp * noise2d(p * freq);
        amp = amp * 0.5;
        freq = freq * 2.0;
    }
    return x;
}

fn sd_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn sd_ray(p: vec2<f32>, ang: f32) -> f32 {
    let dir = vec2<f32>(cos(ang), sin(ang));
    let proj: f32 = dot(p, dir);
    if (proj < 0.0) {
        return length(p);
    }
    let closest = proj * dir;
    return length(p - closest);
}

fn sd_circle(p: vec2<f32>, cen: vec2<f32>, rad: f32) -> f32 {
    return length(p - cen) - rad;
}

fn sd_arc(p: vec2<f32>, rad: f32, ang1: f32, ang2: f32) -> f32 {
    let phi = atan2(p.y, p.x);
    let dphi = clamp((phi - ang1) / (ang2 - ang1), 0.0, 1.0);
    let phi_proj = ang1 + dphi * (ang2 - ang1);
    let proj_pos = rad * vec2<f32>(cos(phi_proj), sin(phi_proj));
    return length(p - proj_pos);
}

fn spiral_sdf(p: vec2<f32>) -> f32 {
    let PI_local = 3.14159265359;
    let k = 1.0 / PI_local;
    let r = length(p);
    let phi = atan2(p.y, p.x);
    let nturns = floor(r / k + 0.5);
    let theta = phi + 2.0 * PI_local * nturns;
    let progress = 1.0;
    if (theta > progress * 8.0 * PI_local) {
        return 100.0;
    }
    let r_ideal = k * theta;
    let dr = r - r_ideal;
    return abs(dr) / sqrt(1.0 + k * k);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let PI = 3.14159265359;
    let TWO_PI = 2.0 * PI;
    let res = params.resolution;
    let p = (2.0 * pos.xy - res) / res.y;
    let spiral_scale = 0.11875;
    let q = p * spiral_scale;

    // Background papyrus
    let n = fbm(q * 30.0 + vec2<f32>(12.3, 45.6));
    let paper_base = vec3<f32>(0.9608, 0.8980, 0.8314);
    var color = paper_base * (0.93 + 0.07 * n);
    let vig = 0.5 + 0.5 * pow(1.0 - length(p) * 0.4, 2.0);
    color = color * vig;

    // Water damage edges
    let edge_f = max(0.0, length(p) - 0.85);
    let damage = fbm(p * 80.0 + vec2<f32>(3.14, 2.71)) * edge_f * 4.0;
    color = color - vec3<f32>(0.15, 0.1, 0.05) * damage;
    color = max(color, vec3<f32>(0.65));

    // Inside first turn shade
    let r = length(q);
    let phi = atan2(q.y, q.x);
    let nturns_inside = floor(r * PI + 0.5);
    let theta_inside = phi + TWO_PI * nturns_inside;
    let r_spiral_inside = theta_inside / PI;
    let dr_inside = r - r_spiral_inside;
    let inside_first_turn = select(0.0, 1.0, (dr_inside < 0.0) && (theta_inside < TWO_PI));
    color = mix(color, vec3<f32>(0.92, 0.94, 0.98) * 0.4, inside_first_turn * 0.8);

    // Spiral
    let d_spiral = spiral_sdf(q);
    let fw_spiral = length(fwidth(q)) * 2.0;
    let spiral_a = 1.0 - smoothstep(0.0, fw_spiral, d_spiral);
    let ink_blue = vec3<f32>(0.12, 0.20, 0.39);
    color = mix(color, ink_blue, spiral_a);

    // Exhaustion polygons
    let nsides_arr = array<u32, 3>(6u, 12u, 24u);
    for (var pi: u32 = 0u; pi < 3u; pi = pi + 1u) {
        let n = nsides_arr[pi];
        var min_d_poly: f32 = 100.0;
        for (var i: u32 = 0u; i < n; i = i + 1u) {
            let theta1 = (f32(i) / f32(n)) * TWO_PI;
            let theta2 = (f32(i + 1u) / f32(n)) * TWO_PI;
            let r1 = theta1 / PI;
            let r2 = theta2 / PI;
            if (r2 > 2.0) {
                continue;
            }
            let v1 = r1 * vec2<f32>(cos(theta1), sin(theta1));
            let v2 = r2 * vec2<f32>(cos(theta2), sin(theta2));
            let d_edge = sd_segment(q, v1, v2);
            min_d_poly = min(min_d_poly, d_edge);
        }
        let poly_fw = length(fwidth(q)) * 3.0;
        let poly_a = (1.0 - smoothstep(0.0, poly_fw, min_d_poly)) * 0.7;
        let poly_tint = f32(pi) * 0.4;
        let poly_col = mix(ink_blue * 0.6, vec3<f32>(0.85, 0.9, 1.0), poly_tint);
        color = mix(color, poly_col, poly_a);
    }

    // Trisection construction
    let beta = PI / 3.0;
    let r_C = beta / PI;
    let theta_P = beta / 3.0;
    let r_P = theta_P / PI;
    let pos_P = r_P * vec2<f32>(cos(theta_P), sin(theta_P));
    let pos_C = r_C * vec2<f32>(cos(beta), sin(beta));
    let pos_A = vec2<f32>(r_C, 0.0);
    let pos_O = vec2<f32>(0.0);

    // Rays
    let faded_red = vec3<f32>(0.54, 0.27, 0.07);
    let gold_line = vec3<f32>(1.0, 0.84, 0.0);
    let ray_fw = length(fwidth(q)) * 1.5;
    let d_ray_A = sd_ray(q, 0.0);
    let a_ray_A = 1.0 - smoothstep(0.0, ray_fw, d_ray_A);
    color = mix(color, faded_red, a_ray_A * 0.9);
    let d_ray_P = sd_ray(q, theta_P);
    let a_ray_P = 1.0 - smoothstep(0.0, ray_fw * 1.3, d_ray_P);
    color = mix(color, gold_line * 0.9, a_ray_P);
    let d_ray_B = sd_ray(q, beta);
    let a_ray_B = 1.0 - smoothstep(0.0, ray_fw, d_ray_B);
    color = mix(color, faded_red, a_ray_B * 0.9);

    // Arc
    let d_arc = sd_arc(q, r_C, 0.0, beta);
    let arc_fw = length(fwidth(q));
    let a_arc = 1.0 - smoothstep(0.0, arc_fw * 1.5, d_arc);
    color = mix(color, faded_red * 0.8, a_arc);

    // Tangent at P
    let theta_tan = theta_P;
    let tan_dx = cos(theta_tan) - theta_tan * sin(theta_tan);
    let tan_dy = sin(theta_tan) + theta_tan * cos(theta_tan);
    let tan_norm = sqrt(1.0 + theta_tan * theta_tan);
    let dir_tan = vec2<f32>(tan_dx, tan_dy) / tan_norm;
    let tan_start = pos_P - dir_tan * 0.18;
    let tan_end = pos_P + dir_tan * 0.18;
    let d_tan = sd_segment(q, tan_start, tan_end);
    let a_tan = 1.0 - smoothstep(0.0, 0.0025, d_tan);
    color = mix(color, ink_blue * 0.85, a_tan);

    // Points
    let pt_fw = length(fwidth(q));
    let d_O = sd_circle(q, pos_O, 0.012);
    let a_O = 1.0 - smoothstep(0.0, pt_fw, d_O);
    color = mix(color, ink_blue, a_O);
    let d_P = sd_circle(q, pos_P, 0.009);
    let a_P = 1.0 - smoothstep(0.0, pt_fw * 0.8, d_P);
    color = mix(color, gold_line, a_P);
    let d_C = sd_circle(q, pos_C, 0.009);
    let a_C = 1.0 - smoothstep(0.0, pt_fw * 0.8, d_C);
    color = mix(color, gold_line * 0.7, a_C);
    let d_A = sd_circle(q, pos_A, 0.007);
    let a_A = 1.0 - smoothstep(0.0, pt_fw * 0.7, d_A);
    color = mix(color, faded_red * 0.6, a_A);

    // Uniform spacing marks
    for (var k: u32 = 1u; k <= 4u; k = k + 1u) {
        let theta_k = TWO_PI * f32(k);
        let r_k = theta_k / PI;
        let pos_k = vec2<f32>(r_k, 0.0);
        // Radial tick
        let dir_rad = vec2<f32>(1.0, 0.0);
        let tick_s_r = pos_k - dir_rad * 0.018;
        let tick_e_r = pos_k + dir_rad * 0.018;
        let d_tr = sd_segment(q, tick_s_r, tick_e_r);
        let a_tr = 1.0 - smoothstep(0.0, 0.0012, d_tr);
        color = mix(color, faded_red * 0.7, a_tr);
        // Perp tick
        let dir_perp = vec2<f32>(0.0, 1.0);
        let tick_s_p = pos_k - dir_perp * 0.025;
        let tick_e_p = pos_k + dir_perp * 0.025;
        let d_tp = sd_segment(q, tick_s_p, tick_e_p);
        let a_tp = 1.0 - smoothstep(0.0, 0.0012, d_tp);
        color = mix(color, faded_red * 0.7, a_tp);
    }

    return vec4<f32>(color, 1.0);
}