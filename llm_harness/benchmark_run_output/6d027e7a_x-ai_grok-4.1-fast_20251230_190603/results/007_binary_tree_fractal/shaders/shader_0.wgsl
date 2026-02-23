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

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    var eye: vec3<f32> = vec3<f32>(3.0, -6.0, 2.5);
    let forward: vec3<f32> = normalize(-eye);
    let world_up: vec3<f32> = vec3<f32>(0.0, 1.0, 0.0);
    let right: vec3<f32> = normalize(cross(forward, world_up));
    let up_vec: vec3<f32> = cross(right, forward);
    let aspect: f32 = params.resolution.x / params.resolution.y;
    let fovy: f32 = radians(40.0);
    let tan_half_fov: f32 = tan(fovy * 0.5);
    let screen_x: f32 = (2.0 * pos.x / params.resolution.x - 1.0) * aspect * tan_half_fov;
    let screen_y: f32 = (2.0 * pos.y / params.resolution.y - 1.0) * (-1.0) * tan_half_fov;
    let ray_dir: vec3<f32> = normalize(forward + right * screen_x + up_vec * screen_y);

    // Raymarch
    let max_dist: f32 = 50.0;
    let min_surf: f32 = 0.001;
    let max_steps: u32 = 200u;
    var t: f32 = 0.0;
    var stepped: u32 = 0u;
    loop {
        if (stepped >= max_steps || t > max_dist) {
            break;
        }
        let h: f32 = map(eye + ray_dir * t);
        if (h <= min_surf) {
            break;
        }
        t = t + h;
        stepped = stepped + 1u;
    }

    var color: vec3<f32>;
    if (t > max_dist) {
        // Sky gradient
        let sky_t: f32 = pow(clamp(ray_dir.y * 0.5 + 0.5, 0.0, 1.0), 0.4);
        let zenith: vec3<f32> = vec3<f32>(215.0 / 255.0, 236.0 / 255.0, 255.0 / 255.0);
        let horizon: vec3<f32> = vec3<f32>(1.0);
        color = mix(horizon, zenith, sky_t);
    } else {
        let hit_pos: vec3<f32> = eye + ray_dir * t;
        let n: vec3<f32> = normal(hit_pos);
        let v: vec3<f32> = normalize(eye - hit_pos);
        color = shade(hit_pos, n, v);
    }
    return vec4<f32>(color, 1.0);
}

fn map(p: vec3<f32>) -> f32 {
    return sdBranch(p, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(0.0, 1.0, 0.0), 1.0, 0.08, 0u);
}

fn sdBranch(p: vec3<f32>, start_pos: vec3<f32>, dir: vec3<f32>, len: f32, rad: f32, level: u32) -> f32 {
    let end_pos: vec3<f32> = start_pos + dir * len;
    let cap_d: f32 = capsule(p, start_pos, end_pos, rad * 0.9);
    if (level >= 7u) {
        return cap_d;
    }
    let tangent: vec3<f32> = getTangent(dir);
    let bitangent: vec3<f32> = cross(dir, tangent);
    let theta: f32 = radians(45.0);
    let phi: f32 = radians(35.0);
    let c_theta: f32 = cos(theta);
    let s_theta: f32 = sin(theta);
    let c_phi: f32 = cos(phi);
    let s_phi: f32 = sin(phi);
    let left_perp: vec3<f32> = c_phi * tangent + s_phi * bitangent;
    let right_perp: vec3<f32> = c_phi * tangent - s_phi * bitangent;
    let child_dir_l: vec3<f32> = normalize(c_theta * dir + s_theta * left_perp);
    let child_dir_r: vec3<f32> = normalize(c_theta * dir + s_theta * right_perp);
    let child_len: f32 = len * 0.7;
    let child_rad: f32 = rad * 0.6;
    let child_l: f32 = sdBranch(p, end_pos, child_dir_l, child_len, child_rad, level + 1u);
    let child_r: f32 = sdBranch(p, end_pos, child_dir_r, child_len, child_rad, level + 1u);
    let k: f32 = 0.01;
    var d: f32 = smin(cap_d, child_l, k);
    d = smin(d, child_r, k);
    return d;
}

fn getTangent(dir: vec3<f32>) -> vec3<f32> {
    let ref_vec: vec3<f32> = select(vec3<f32>(0.0, 1.0, 0.0), vec3<f32>(0.0, 0.0, 1.0), abs(dir.y) > 0.99);
    return normalize(cross(dir, ref_vec));
}

fn capsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
    let pa: vec3<f32> = p - a;
    let ba: vec3<f32> = b - a;
    let h: f32 = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - h * ba) - r;
}

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h: f32 = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

fn normal(p: vec3<f32>) -> vec3<f32> {
    let e: vec2<f32> = vec2<f32>(0.001, 0.0);
    let n: vec3<f32> = vec3<f32>(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    );
    return normalize(n);
}

fn shade(pos: vec3<f32>, n: vec3<f32>, v: vec3<f32>) -> vec3<f32> {
    let albedo: vec3<f32> = vec3<f32>(75.0 / 255.0, 55.0 / 255.0, 38.0 / 255.0);
    let roughness: f32 = 0.7;
    let spec_pow: f32 = 80.0 * (1.0 - roughness);

    // Key light
    let lpos1: vec3<f32> = vec3<f32>(3.0, -5.0, 5.0);
    let lcol1: vec3<f32> = vec3<f32>(1.0, 1.0, 1.0);
    var col: vec3<f32> = light_contrib(pos, lpos1, lcol1, n, v, albedo, spec_pow);

    // Fill light
    let lpos2: vec3<f32> = vec3<f32>(-2.0, -6.0, 4.0);
    let lcol2: vec3<f32> = vec3<f32>(0.4, 0.4, 0.4);
    col = col + light_contrib(pos, lpos2, lcol2, n, v, albedo, spec_pow);

    // Rim light
    let lpos3: vec3<f32> = vec3<f32>(0.0, 0.0, 6.0);
    let lcol3: vec3<f32> = vec3<f32>(0.3, 0.4, 0.5);
    col = col + light_contrib(pos, lpos3, lcol3, n, v, albedo, spec_pow);

    // Ambient
    let ambient: vec3<f32> = 0.05 * albedo + 0.1 * albedo * max(0.0, n.y);

    col = col + ambient;

    // Rim enhancement
    let rim: f32 = 1.0 - max(0.0, dot(n, v));
    col = col + vec3<f32>(0.1, 0.15, 0.2) * pow(rim, 2.0);

    return col;
}

fn light_contrib(pos: vec3<f32>, lpos: vec3<f32>, lcol: vec3<f32>, n: vec3<f32>, v: vec3<f32>, albedo: vec3<f32>, spec_pow: f32) -> vec3<f32> {
    let lvec: vec3<f32> = lpos - pos;
    let ldist: f32 = length(lvec);
    let ldir: vec3<f32> = lvec / ldist;
    let atten: f32 = 1.0 / (1.0 + 0.22 * ldist + 0.20 * ldist * ldist);
    let ndotl: f32 = max(0.0, dot(n, ldir));
    let h: vec3<f32> = normalize(ldir + v);
    let ndoth: f32 = max(0.0, dot(n, h));
    let spec: f32 = pow(ndoth, spec_pow);
    let diff: vec3<f32> = albedo * (ndotl * 0.5);
    return (diff + spec * 0.5) * atten * lcol;
}