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

fn cdiv(num: vec2<f32>, den: vec2<f32>) -> vec2<f32> {
    let abs2 = dot(den, den);
    if (abs2 < 1e-12) {
        return vec2<f32>(1e6, 0.0);
    }
    let re_part = dot(num, vec2<f32>(den.x, den.y)) / abs2;
    let im_part = dot(num, vec2<f32>(-den.y, den.x)) / abs2;
    return vec2<f32>(re_part, im_part);
}

fn apply_m1(z: vec2<f32>) -> vec2<f32> {
    let num = 2.0 * z + vec2<f32>(1.0, 0.0);
    let den = z + vec2<f32>(1.0, 0.0);
    return cdiv(num, den);
}

fn apply_m2(z: vec2<f32>) -> vec2<f32> {
    let num = 2.0 * z - vec2<f32>(1.0, 0.0);
    let den = z - vec2<f32>(1.0, 0.0);
    return cdiv(num, den);
}

fn get_rand(p: vec2<f32>, s: f32) -> f32 {
    let h = dot(p, vec2<f32>(12.9898, 78.233)) + s;
    return fract(sin(h) * 43758.5453123);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let half_extent: f32 = 2.0;
    let pad_target_px: f32 = 120.0;
    let target_content_px: f32 = 2400.0;
    let pad_px = pad_target_px * (res.x / (target_content_px + 2.0 * pad_target_px));
    let content_size = res.x - 2.0 * pad_px;
    let px_scale = content_size / (2.0 * half_extent);
    let center = res * 0.5;

    var z: vec2<f32> = vec2<f32>(0.0, 0.0);
    var accum: vec3<f32> = vec3<f32>(0.0);
    let transient_steps: u32 = 12u;
    let plot_steps: u32 = 9u;
    var depth: u32 = 0u;

    let norm_pos = pos.xy / res;
    let sigma_sharp: f32 = 0.6;
    let sigma_blur: f32 = 1.0;
    let sigma_bloomed: f32 = sqrt(sigma_sharp * sigma_sharp + sigma_blur * sigma_blur);
    let point_intensity: f32 = 0.18;
    let red: vec3<f32> = vec3<f32>(1.0, 0.2, 0.33);
    let green: vec3<f32> = vec3<f32>(0.2, 1.0, 0.33);
    let mix_sharp: f32 = 0.6;
    let mix_bloom: f32 = 0.4;

    for (var step: u32 = 0u; step < transient_steps + plot_steps; step = step + 1u) {
        let r = get_rand(norm_pos, f32(step) * 1.6180339887);
        if (r < 0.5) {
            z = apply_m1(z);
        } else {
            z = apply_m2(z);
        }
        depth = depth + 1u;
        if (step >= transient_steps) {
            let screen_pos = center + z * px_scale;
            let dist_vec = pos.xy - screen_pos;
            let dist_sq = dot(dist_vec, dist_vec);
            let g_sharp = exp(-dist_sq / (2.0 * sigma_sharp * sigma_sharp));
            let g_bloomed = exp(-dist_sq / (2.0 * sigma_bloomed * sigma_bloomed));
            let parity_even = ((depth & 1u) == 0u);
            let point_color = select(red, green, parity_even);
            accum = accum + point_color * point_intensity * (mix_sharp * g_sharp + mix_bloom * g_bloomed);
        }
    }

    let final_color = accum / (1.0 + accum);
    return vec4<f32>(final_color, 1.0);
}