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

struct SDFRes {
    dist: f32,
    id: u32,
};

fn sdHelix(p: vec3<f32>, phase: f32, r_cyl: f32, tube_r: f32) -> f32 {
    let rho: f32 = length(p.xz);
    let phi: f32 = atan2(p.z, p.x);
    let freq: f32 = 6.283185307 / 1.8;
    let twist: f32 = phi - freq * p.y - phase;
    let PI2: f32 = 6.283185307;
    let dphi: f32 = twist - PI2 * round(twist / PI2);
    let dr: f32 = rho - r_cyl;
    let helix_d: f32 = sqrt(dr * dr + (r_cyl * dphi) * (r_cyl * dphi));
    return helix_d - tube_r;
}

fn sceneSDF(p: vec3<f32>) -> SDFRes {
    let r_cyl: f32 = 0.6;
    let tube_r: f32 = 0.15;
    var res: SDFRes = SDFRes(dist: 1e10, id: 0u);
    let d0: f32 = sdHelix(p, 0.0, r_cyl, tube_r);
    if (d0 < res.dist) {
        res.dist = d0;
        res.id = 0u;
    }
    let d1: f32 = sdHelix(p, 2.094395102, r_cyl, tube_r);
    if (d1 < res.dist) {
        res.dist = d1;
        res.id = 1u;
    }
    let d2: f32 = sdHelix(p, 4.188790205, r_cyl, tube_r);
    if (d2 < res.dist) {
        res.dist = d2;
        res.id = 2u;
    }
    return res;
}

fn calc_normal(p: vec3<f32>) -> vec3<f32> {
    let eps: f32 = 0.001;
    let d: f32 = sceneSDF(p).dist;
    return normalize(vec3<f32>(
        sceneSDF(p + vec3<f32>(eps, 0.0, 0.0)).dist - d,
        sceneSDF(p + vec3<f32>(0.0, eps, 0.0)).dist - d,
        sceneSDF(p + vec3<f32>(0.0, 0.0, eps)).dist - d
    ));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let cam_pos: vec3<f32> = vec3<f32>(3.0, 2.0, 2.0);
    let look_at: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
    let cam_dir: vec3<f32> = normalize(look_at - cam_pos);
    let cam_target_up: vec3<f32> = vec3<f32>(0.0, 1.0, 0.0);
    let cam_right: vec3<f32> = normalize(cross(cam_dir, cam_target_up));
    let cam_up: vec3<f32> = cross(cam_right, cam_dir);
    let aspect: f32 = params.resolution.x / params.resolution.y;
    let uv: vec2<f32> = (2.0 * pos.xy / params.resolution - 1.0) * vec2<f32>(aspect, 1.0);
    let focal: f32 = 1.8;
    let rd: vec3<f32> = normalize(cam_dir * focal + cam_right * uv.x + cam_up * uv.y);
    let ro: vec3<f32> = cam_pos;

    var t: f32 = 0.0;
    let tmax: f32 = 50.0;
    let max_iter: u32 = 256u;
    for (var i: u32 = 0u; i < max_iter; i = i + 1u) {
        let p: vec3<f32> = ro + rd * t;
        let h: f32 = sceneSDF(p).dist;
        if (h < 0.001) {
            break;
        }
        t = t + h;
        if (t > tmax) {
            break;
        }
    }

    var color: vec3<f32> = vec3<f32>(0.05, 0.08, 0.15);
    if (t < tmax) {
        let hit_pos: vec3<f32> = ro + rd * t;
        let nor: vec3<f32> = calc_normal(hit_pos);
        let fresnel: f32 = pow(clamp(1.0 + dot(nor, rd), 0.0, 1.0), 2.0);
        let light_dir: vec3<f32> = normalize(vec3<f32>(0.4, 0.7, 0.2));
        let diff: f32 = clamp(dot(nor, light_dir), 0.0, 1.0);
        let spec: f32 = pow(clamp(dot(reflect(-light_dir, nor), rd), 0.0, 1.0), 16.0);
        let amb: f32 = 0.5 + 0.5 * nor.y;
        let res: SDFRes = sceneSDF(hit_pos);
        var mat_col: vec3<f32>;
        if (res.id == 0u) {
            mat_col = vec3<f32>(0.80, 0.60, 0.40);
        } else if (res.id == 1u) {
            mat_col = vec3<f32>(0.40, 0.80, 0.60);
        } else {
            mat_col = vec3<f32>(0.60, 0.40, 0.80);
        }
        color = mat_col * (amb * 0.5 + diff * 0.6 + spec * 0.4);
        color = mix(color, vec3<f32>(0.1), pow(t * 0.02, 2.0));
    } else {
        color = mix(vec3<f32>(0.7, 0.8, 1.0), vec3<f32>(0.2, 0.3, 0.5), t * 0.05);
    }
    return vec4<f32>(color, 1.0);
}