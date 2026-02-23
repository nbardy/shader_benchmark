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
};

fn sdSphere(p: vec3<f32>, r: f32) -> f32 {
    return length(p) - r;
}

fn sdCylinder(p: vec3<f32>, r: f32, h: f32) -> f32 {
    let d = length(p.yz) - r;
    let s = vec2<f32>(d, abs(p.x) - 0.5 * h);
    let x = length(max(s, vec2<f32>(0.0)));
    let y = min(max(s.x, s.y), 0.0);
    return x + y;
}

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

fn map(p_world: vec3<f32>) -> f32 {
    let time: f32 = 1.0;
    let angle_z: f32 = 0.261799;
    let angle_y: f32 = 1.047198;
    let cz: f32 = cos(angle_z);
    let sz: f32 = sin(angle_z);
    let cy: f32 = cos(angle_y);
    let sy: f32 = sin(angle_y);
    let rot_z: mat3x3<f32> = mat3x3<f32>(
        vec3<f32>(cz, -sz, 0.0),
        vec3<f32>(sz, cz, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
    let rot_y: mat3x3<f32> = mat3x3<f32>(
        vec3<f32>(cy, 0.0, sy),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sy, 0.0, cy)
    );
    let rot: mat3x3<f32> = rot_y * rot_z;
    let p: vec3<f32> = rot * p_world;
    let d1: f32 = sdSphere(p - vec3<f32>(-2.5, 0.0, 0.0), 0.8);
    let d2: f32 = sdSphere(p - vec3<f32>(2.5, 0.0, 0.0), 0.8);
    let dc: f32 = sdCylinder(p, 0.3, 3.4);
    let k: f32 = 2.0;
    return smin(d1, smin(d2, dc, k), k);
}

fn get_material(p_local: vec3<f32>) -> f32 {
    let d1: f32 = sdSphere(p_local - vec3<f32>(-2.5, 0.0, 0.0), 0.8);
    let d2: f32 = sdSphere(p_local - vec3<f32>(2.5, 0.0, 0.0), 0.8);
    let dc: f32 = sdCylinder(p_local, 0.3, 3.4);
    let d_sphere: f32 = min(d1, d2);
    return select(1.0, 0.0, dc < d_sphere);
}

fn calc_normal(p_world: vec3<f32>) -> vec3<f32> {
    let eps: vec2<f32> = vec2<f32>(0.001, 0.0);
    let d: f32 = map(p_world);
    return normalize(vec3<f32>(
        map(p_world + eps.xyy) - d,
        map(p_world + eps.yxy) - d,
        map(p_world + eps.yyx) - d
    ));
}

fn raymarch(ro: vec3<f32>, rd: vec3<f32>) -> f32 {
    var t: f32 = 0.0;
    var steps: u32 = 0u;
    loop {
        if (steps >= 120u) {
            break;
        }
        let p: vec3<f32> = ro + t * rd;
        let d: f32 = map(p);
        if (d < 0.001) {
            return t;
        }
        t += d * 0.85;
        if (t > 20.0) {
            break;
        }
        steps = steps + 1u;
    }
    return -1.0;
}

fn softshadow(p_world: vec3<f32>, rd: vec3<f32>, mint: f32, tmax: f32) -> f32 {
    var res: f32 = 1.0;
    var t: f32 = mint;
    var ph: f32 = 1e20;
    var steps: u32 = 0u;
    loop {
        if (steps >= 48u) {
            break;
        }
        let h: f32 = map(p_world + rd * t);
        if (h < 0.0001) {
            return 0.0;
        }
        let y: f32 = h * h / (2.0 * ph);
        ph = h;
        res = min(res, 32.0 * h / t);
        t += clamp(y, 0.02, 0.1);
        if (t > tmax) {
            break;
        }
        steps = steps + 1u;
    }
    return res * res * (3.0 + res) / 4.0;
}

fn get_env(d: vec3<f32>) -> vec3<f32> {
    let t: f32 = clamp(d.y * 0.5 + 0.5, 0.0, 1.0);
    return mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0, 1.0, 1.0), t);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution: vec2<f32> = params.resolution;
    let aspect: f32 = resolution.x / resolution.y;
    let uv_ndc: vec2<f32> = (pos.xy / resolution) * 2.0 - 1.0;
    let uv: vec2<f32> = vec2<f32>(uv_ndc.x * aspect, uv_ndc.y);
    let cam_pos: vec3<f32> = vec3<f32>(4.0, 3.0, 5.0);
    let target_pos: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
    let forward_dir: vec3<f32> = normalize(target_pos - cam_pos);
    let right_dir: vec3<f32> = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), forward_dir));
    let up_dir: vec3<f32> = cross(forward_dir, right_dir);
    let focal: f32 = 2.0;
    let rd: vec3<f32> = normalize(focal * forward_dir + uv.x * right_dir + uv.y * up_dir);
    let ro: vec3<f32> = cam_pos;
    let t: f32 = raymarch(ro, rd);
    var col: vec3<f32> = vec3<f32>(0.0);
    if (t > 0.0) {
        let p_world: vec3<f32> = ro + t * rd;
        let time: f32 = 1.0;
        let angle_z: f32 = 0.261799;
        let angle_y: f32 = 1.047198;
        let cz: f32 = cos(angle_z);
        let sz: f32 = sin(angle_z);
        let cy: f32 = cos(angle_y);
        let sy: f32 = sin(angle_y);
        let rot_z: mat3x3<f32> = mat3x3<f32>(
            vec3<f32>(cz, -sz, 0.0),
            vec3<f32>(sz, cz, 0.0),
            vec3<f32>(0.0, 0.0, 1.0)
        );
        let rot_y: mat3x3<f32> = mat3x3<f32>(
            vec3<f32>(cy, 0.0, sy),
            vec3<f32>(0.0, 1.0, 0.0),
            vec3<f32>(-sy, 0.0, cy)
        );
        let rot: mat3x3<f32> = rot_y * rot_z;
        let p_local: vec3<f32> = rot * p_world;
        let N: vec3<f32> = calc_normal(p_world);
        let V: vec3<f32> = -rd;
        let mat_id: f32 = get_material(p_local);
        var albedo: vec3<f32> = vec3<f32>(0.7, 0.7, 0.8);
        let is_cyl: bool = mat_id < 0.5;
        let brush: f32 = sin(p_local.x * 25.0) * 0.5 + 0.5;
        albedo = mix(albedo, albedo * (0.92 + 0.08 * brush), select(0.0, 1.0, is_cyl));
        var rough: f32 = select(0.2, 0.4 + 0.15 * brush, is_cyl);
        let metallic: f32 = 0.9;
        let pi: f32 = 3.14159265;
        let shininess: f32 = (1.0 - rough) * 256.0;
        let R: vec3<f32> = normalize(reflect(-V, N));
        let amb: vec3<f32> = get_env(R) * 0.3;
        // main dir light
        let L1: vec3<f32> = normalize(vec3<f32>(1.0, 2.0, 1.0));
        let H1: vec3<f32> = normalize(L1 + V);
        let NdL1: f32 = max(dot(N, L1), 0.0);
        let NdH1: f32 = max(dot(N, H1), 0.0);
        let spec1: f32 = pow(NdH1, shininess);
        let sh1: f32 = softshadow(p_world + N * 0.02, L1, 0.05, 10.0);
        col += (albedo * NdL1 * (1.0 - metallic) * 0.3 + spec1 * (0.04 + 0.96 * metallic)) * sh1 * 0.8;
        // fill point
        let lp2: vec3<f32> = vec3<f32>(-3.0, 1.0, 2.0);
        let to_l2: vec3<f32> = lp2 - p_world;
        let dist2: f32 = length(to_l2);
        let L2: vec3<f32> = to_l2 / dist2;
        let att2: f32 = 1.0 / (1.0 + 0.22 * dist2 + 0.07 * dist2 * dist2);
        let NdL2: f32 = max(dot(N, L2), 0.0);
        let H2: vec3<f32> = normalize(L2 + V);
        let NdH2: f32 = max(dot(N, H2), 0.0);
        let spec2: f32 = pow(NdH2, shininess);
        let sh2: f32 = softshadow(p_world + N * 0.02, L2, 0.05, dist2 * 0.95);
        col += (albedo * NdL2 * (1.0 - metallic) * 0.3 + spec2 * (0.04 + 0.96 * metallic)) * sh2 * att2 * 0.4;
        // rim light
        let L3: vec3<f32> = normalize(vec3<f32>(-1.0, 0.0, -1.0));
        let NdL3: f32 = max(dot(N, L3), 0.0);
        let sh3: f32 = softshadow(p_world + N * 0.02, L3, 0.05, 10.0);
        let rim: f32 = pow(1.0 - max(dot(N, V), 0.0), 2.0);
        col += rim * sh3 * NdL3 * 0.3 * vec3<f32>(0.6, 0.7, 1.0);
        col = mix(col, amb, 0.4);
        col = clamp(col, 0.0, 1.0);
    } else {
        let sky: vec3<f32> = get_env(rd);
        let vignette: f32 = 1.0 - dot(uv_ndc, uv_ndc) * 0.3;
        col = sky * vignette;
        col = mix(col, vec3<f32>(0.9, 0.9, 0.95), pow(length(uv_ndc), 3.0) * 0.4);
    }
    col = pow(col, vec3<f32>(1.0 / 2.2));
    col = clamp(col, 0.0, 1.0);
    return vec4<f32>(col, 1.0);
}