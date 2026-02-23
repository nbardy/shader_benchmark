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
    progress: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn hash11(n: f32) -> f32 {
    return fract(sin(n) * 43758.5453123);
}

fn noise2d(p: vec2<f32>) -> f32 {
    let i = vec2<i32>(floor(p));
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash11(f32(i.x) + hash11(f32(i.y))),
                hash11(f32(i.x + 1) + hash11(f32(i.y))), u.x),
             mix(hash11(f32(i.x) + hash11(f32(i.y + 1))),
                 hash11(f32(i.x + 1) + hash11(f32(i.y + 1))), u.x), u.y);
}

fn line_sdf(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - h * ba);
}

fn ray_dist(p: vec2<f32>, alpha: f32) -> f32 {
    let dir = vec2<f32>(cos(alpha), sin(alpha));
    let side_dir = vec2<f32>(-dir.y, dir.x);
    let proj = dot(p, dir);
    let dist_side = abs(dot(p, side_dir));
    return select(dist_side, 100.0, proj < 0.0);
}

fn arc_dist(p: vec2<f32>, rad: f32, ang1: f32, ang2: f32) -> f32 {
    let phi = atan2(p.y, p.x);
    let h = clamp((phi - ang1) / (ang2 - ang1), 0.0, 1.0);
    let a = mix(ang1, ang2, h);
    let arc_p = rad * vec2<f32>(cos(a), sin(a));
    return length(p - arc_p);
}

fn poly_dist(p: vec2<f32>, nsides: u32, R: f32, offset_ang: f32) -> f32 {
    var mind: f32 = 1e10;
    let step = 6.283185307179586 / f32(nsides);
    for (var i: u32 = 0u; i < nsides; i = i + 1u) {
        let a1 = offset_ang + f32(i) * step;
        let a2 = offset_ang + f32((i + 1u) % nsides) * step;
        let pa = R * vec2<f32>(cos(a1), sin(a1));
        let pb = R * vec2<f32>(cos(a2), sin(a2));
        let ld = line_sdf(p, pa, pb);
        mind = min(mind, ld);
    }
    return mind;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / params.resolution - 0.5) * 2.0;
    let p = uv * 8.0;
    let PI = 3.141592653589793;
    let TWO_PI = 6.283185307179586;
    let MAX_THETA = 8.0 * PI;
    let a = 1.0 / PI;
    let progress = 1.0;

    // Papyrus background
    var col: vec3<f32> = vec3<f32>(0.96, 0.902, 0.843);
    let q = pos.xy / params.resolution * vec2<f32>(100.0, 50.0);
    let n1 = noise2d(q * 0.02);
    let n2 = noise2d(q * 0.1);
    let grain = 1.0 - 0.1 * n1 + 0.05 * n2;
    col = col * grain;
    let vignette_f = length(uv) / 1.5;
    col = col * exp(-vignette_f * vignette_f * 0.3);
    let edge_mask = 1.0 - smoothstep(0.7, 1.2, 1.0 - length(uv));
    let damage_n = noise2d(pos.xy / params.resolution * vec2<f32>(3.0, 4.0));
    col = col * (1.0 - 0.3 * edge_mask * (0.5 + 0.5 * damage_n));

    // Archimedean spiral
    let r = length(p);
    let phi = atan2(p.y, p.x);
    let theta_guess = r * PI;
    let n = floor(theta_guess / TWO_PI + 0.5);
    let phi_unwrapped = phi + n * TWO_PI;
    let theta = phi_unwrapped;
    let r_spiral = theta * a;
    var d_spiral = abs(r - r_spiral);
    let in_range = select(0.0, 1.0, theta >= 0.0 && theta <= MAX_THETA * progress);
    d_spiral = mix(d_spiral, 100.0, 1.0 - in_range);
    let spiral_thick = 0.0025;
    let spiral_aa = 0.0005;
    let spiral_mask = smoothstep(spiral_thick + spiral_aa, spiral_thick - spiral_aa, d_spiral);
    let spiral_col = vec3<f32>(0.12, 0.20, 0.39);
    col = mix(col, spiral_col, spiral_mask);
    let glow = exp(-d_spiral * 20.0) * 0.3 * in_range;
    col = col + glow * vec3<f32>(0.3, 0.5, 0.8);

    // Construction color
    let construct_col = vec3<f32>(0.54, 0.27, 0.07);
    let thick_con = 0.004;

    // Rays OA and OB
    let d_oa = ray_dist(p, 0.0);
    col = mix(col, construct_col, 0.6 * smoothstep(thick_con * 2.0, 0.0, d_oa));
    let pi3 = PI / 3.0;
    let d_ob = ray_dist(p, pi3);
    col = mix(col, construct_col, 0.5 * smoothstep(thick_con * 1.5, 0.0, d_ob));

    // Arc center O radius r_c from 0 to pi/3
    let r_c = 1.0 / 3.0;
    let d_arc = arc_dist(p, r_c, 0.0, pi3);
    col = mix(col, construct_col, 0.7 * smoothstep(thick_con, 0.0, d_arc));

    // Points P and C
    let r_p = r_c / 3.0;
    let theta_p = PI * r_p;
    let pos_p = r_p * vec2<f32>(cos(theta_p), sin(theta_p));
    let d_p = length(p - pos_p) - 0.008;
    let mask_p = smoothstep(0.010, 0.006, d_p);
    col = mix(col, vec3<f32>(0.0), mask_p);
    let pos_c = r_c * vec2<f32>(cos(pi3), sin(pi3));
    let d_c = length(p - pos_c) - 0.008;
    let mask_c = smoothstep(0.010, 0.006, d_c);
    col = mix(col, vec3<f32>(0.0), mask_c);

    // Squaring the circle: inscribed polygons first turn R=2.0
    let R_poly = 2.0;
    let d_poly6 = poly_dist(p, 6u, R_poly, 0.0);
    col = mix(col, construct_col, 0.8 * smoothstep(0.0035, 0.0, d_poly6));
    let d_poly12 = poly_dist(p, 12u, R_poly, 0.0);
    col = mix(col, construct_col, 0.6 * smoothstep(0.0025, 0.0, d_poly12));
    let d_poly24 = poly_dist(p, 24u, R_poly, 0.0);
    col = mix(col, construct_col, 0.4 * smoothstep(0.0015, 0.0, d_poly24));
    let d_poly48 = poly_dist(p, 48u, R_poly, 0.0);
    col = mix(col, vec3<f32>(0.5, 0.4, 0.3), 0.2 * smoothstep(0.001, 0.0, d_poly48));

    // Tangent example at theta=PI/2
    let theta_t = PI / 2.0;
    let r_t = theta_t * a;
    let pos_t = r_t * vec2<f32>(cos(theta_t), sin(theta_t));
    let radial_t = vec2<f32>(cos(theta_t), sin(theta_t));
    let tang_t = vec2<f32>(-sin(theta_t), cos(theta_t));
    let t_dir = normalize(a * radial_t + r_t * tang_t);
    let len_t = 0.4;
    let t_start = pos_t - t_dir * len_t;
    let t_end = pos_t + t_dir * len_t;
    let d_tang = line_sdf(p, t_start, t_end);
    col = mix(col, vec3<f32>(1.0, 0.3, 0.3), 0.8 * smoothstep(0.002, 0.0, d_tang));
    let d_t = length(p - pos_t) - 0.012;
    let mask_t = smoothstep(0.014, 0.010, d_t);
    col = mix(col, vec3<f32>(0.0), mask_t);

    return vec4<f32>(col, 1.0);
}