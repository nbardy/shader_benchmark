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

fn helix_centerline_dist(p: vec3<f32>, phase: f32, r_cyl: f32, pitch: f32) -> f32 {
    let t = p.z / pitch;
    var min_d2: f32 = 1e20;
    let pi2: f32 = 6.28318530718;
    for (var i: u32 = 0u; i < 3u; i = i + 1u) {
        let ii: f32 = f32(i) - 1.0;
        let tt: f32 = t + ii;
        let phi: f32 = phase + pi2 * tt;
        let cx: f32 = r_cyl * cos(phi);
        let cy: f32 = r_cyl * sin(phi);
        let cz: f32 = pitch * tt;
        let dx: f32 = p.x - cx;
        let dy: f32 = p.y - cy;
        let dz: f32 = p.z - cz;
        let d2: f32 = dx * dx + dy * dy + dz * dz;
        min_d2 = select(min_d2, d2, d2 < min_d2);
    }
    return sqrt(min_d2);
}

fn scene_sdf(p: vec3<f32>) -> f32 {
    let r_cyl: f32 = 0.6;
    let tube_r: f32 = 0.15;
    let pitch: f32 = 1.8;
    let pi2: f32 = 6.28318530718;
    let phase1: f32 = 0.0;
    let phase2: f32 = pi2 / 3.0;
    let phase3: f32 = pi2 * 2.0 / 3.0;
    let slab_h: f32 = 3.0;
    let dc1: f32 = helix_centerline_dist(p, phase1, r_cyl, pitch);
    let dc2: f32 = helix_centerline_dist(p, phase2, r_cyl, pitch);
    let dc3: f32 = helix_centerline_dist(p, phase3, r_cyl, pitch);
    let d_tubes: f32 = min(min(dc1, dc2) - tube_r, dc3 - tube_r);
    let d_slab: f32 = abs(p.z) - slab_h;
    return max(d_tubes, d_slab);
}

fn get_color(p: vec3<f32>) -> vec3<f32> {
    let r_cyl: f32 = 0.6;
    let pitch: f32 = 1.8;
    let pi2: f32 = 6.28318530718;
    let phase1: f32 = 0.0;
    let phase2: f32 = pi2 / 3.0;
    let phase3: f32 = pi2 * 2.0 / 3.0;
    let dc1: f32 = helix_centerline_dist(p, phase1, r_cyl, pitch);
    let dc2: f32 = helix_centerline_dist(p, phase2, r_cyl, pitch);
    let dc3: f32 = helix_centerline_dist(p, phase3, r_cyl, pitch);
    var best_d: f32 = dc1;
    var col: vec3<f32> = vec3<f32>(0.8, 0.6, 0.4);
    if (dc2 < best_d) {
        best_d = dc2;
        col = vec3<f32>(0.4, 0.8, 0.6);
    }
    if (dc3 < best_d) {
        col = vec3<f32>(0.6, 0.4, 0.8);
    }
    return col;
}

fn calc_normal(p: vec3<f32>) -> vec3<f32> {
    let eps: f32 = 0.0005;
    let p_x: vec3<f32> = vec3<f32>(eps, 0.0, 0.0);
    let p_y: vec3<f32> = vec3<f32>(0.0, eps, 0.0);
    let p_z: vec3<f32> = vec3<f32>(0.0, 0.0, eps);
    let nx: f32 = scene_sdf(p + p_x) - scene_sdf(p - p_x);
    let ny: f32 = scene_sdf(p + p_y) - scene_sdf(p - p_y);
    let nz: f32 = scene_sdf(p + p_z) - scene_sdf(p - p_z);
    return normalize(vec3<f32>(nx, ny, nz));
}

fn soft_shadow(ro: vec3<f32>, rd: vec3<f32>) -> f32 {
    var res: f32 = 1.0;
    var t: f32 = 0.05;
    var i: u32 = 0u;
    loop {
        if (i >= 40u) { break; }
        let h: f32 = scene_sdf(ro + rd * t);
        let k: f32 = 32.0;
        res = min(res, k * h / t);
        t += clamp(h, 0.05, 0.2);
        if (t > 4.0) { break; }
        i = i + 1u;
    }
    return res * res * (3.0 + res) * 0.25;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res: vec2<f32> = params.resolution;
    let q: vec2<f32> = (pos.xy / res.yy) * 2.0 - 1.0;
    let cam_pos: vec3<f32> = vec3<f32>(3.0, 2.0, 2.0);
    let look_at: vec3<f32> = vec3<f32>(0.0);
    let cam_fwd: vec3<f32> = normalize(look_at - cam_pos);
    let cam_ref: vec3<f32> = vec3<f32>(0.0, 1.0, 0.0);
    let cam_right: vec3<f32> = normalize(cross(cam_ref, cam_fwd));
    let cam_up: vec3<f32> = cross(cam_fwd, cam_right);
    let focal: f32 = 2.2;
    let rd: vec3<f32> = normalize(cam_fwd * focal + cam_right * q.x + cam_up * q.y);
    let ro: vec3<f32> = cam_pos;
    var t: f32 = 0.0;
    var mint: f32 = 1e20;
    var i: u32 = 0u;
    loop {
        if (i >= 256u) { break; }
        let p: vec3<f32> = ro + t * rd;
        let d: f32 = scene_sdf(p);
        if (d < 0.001) { break; }
        mint = min(mint, d);
        t += d * 0.75;
        if (t > 30.0) { break; }
        i = i + 1u;
    }
    var color: vec3<f32> = vec3<f32>(0.02, 0.01, 0.05);
    if (t < 29.0) {
        let p: vec3<f32> = ro + t * rd;
        let n: vec3<f32> = calc_normal(p);
        let albedo: vec3<f32> = get_color(p);
        let light_dir: vec3<f32> = normalize(vec3<f32>(0.6, 1.2, 0.3));
        let dif: f32 = max(dot(n, light_dir), 0.0);
        let sh: f32 = soft_shadow(p + n * 0.01, light_dir);
        let ao: f32 = 1.0 / (1.0 + mint * 30.0);
        color = albedo * (0.1 + dif * 0.7 * sh) * ao;
    }
    let fog_amt: f32 = 1.0 - exp(-t * 0.02);
    color = mix(color, vec3<f32>(0.03, 0.02, 0.04), fog_amt);
    color = pow(color, vec3<f32>(0.4545));
    return vec4<f32>(color, 1.0);
}