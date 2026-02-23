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

fn hash22(p: vec2<f32>) -> vec2<f32> {
    let dot1 = dot(p, vec2<f32>(127.1, 311.7));
    let dot2 = dot(p, vec2<f32>(269.5, 183.3));
    return fract(vec2<f32>(sin(dot1) * 43758.5453123, sin(dot2) * 43758.5453123));
}

fn worley(pos: vec2<f32>, scale: f32) -> f32 {
    let cell = floor(pos * scale);
    var min_dist: f32 = 1e20;
    let search_r: i32 = 1;
    for (var dx: i32 = -search_r; dx <= search_r; dx = dx + 1i) {
        for (var dy: i32 = -search_r; dy <= search_r; dy = dy + 1i) {
            let cell_id: vec2<f32> = cell + vec2<f32>(f32(dx), f32(dy));
            let jitter: vec2<f32> = hash22(cell_id);
            let point: vec2<f32> = (cell_id + jitter) / scale;
            let dist: f32 = length(point - pos);
            min_dist = min(min_dist, dist);
        }
    }
    return min_dist;
}

fn angle_wrap(diff: f32) -> f32 {
    let pi2: f32 = 6.283185307179586;
    return diff - pi2 * floor(0.5 + diff / pi2);
}

fn get_arm_density(r: f32, phi: f32, theta_c: f32) -> f32 {
    let pi: f32 = 3.141592653589793;
    let sigma_theta: f32 = 0.035;
    let decay: f32 = 1.0 / 3.0;
    let prefactor: f32 = 2800.0;
    let dphi1: f32 = angle_wrap(phi - theta_c);
    let dphi2: f32 = angle_wrap(phi - theta_c - pi);
    let g1: f32 = exp(-0.5 * dphi1 * dphi1 / (sigma_theta * sigma_theta));
    let g2: f32 = exp(-0.5 * dphi2 * dphi2 / (sigma_theta * sigma_theta));
    let gphi: f32 = 0.5 * (g1 + g2);
    let weight: f32 = exp(-decay * r);
    return prefactor * gphi * weight / max(r, 0.1);
}

fn get_bg_density(r: f32) -> f32 {
    let decay: f32 = 1.0 / 3.0;
    let prefactor: f32 = 45.0;
    return prefactor * exp(-decay * r);
}

fn star_color(temp: f32) -> vec3<f32> {
    let t = clamp((temp - 4700.0) / 2500.0, 0.0, 1.0);
    let cool: vec3<f32> = vec3<f32>(1.00, 0.55, 0.35);
    let hot: vec3<f32> = vec3<f32>(0.60, 0.85, 1.00);
    return mix(cool, hot, t);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let world_half: f32 = 10.0;
    let p: vec2<f32> = pos.xy / params.resolution * 2.0 * world_half - world_half;
    let r: f32 = length(p);
    if (r > 10.0) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    let phi: f32 = atan2(p.y, p.x);
    let theta_c: f32 = r / 0.25;

    // Core glow
    let core_color: vec3<f32> = vec3<f32>(1.0, 1.0, 0.6667);
    let core_intensity: f32 = 0.6 * (1.0 - smoothstep(0.0, 0.4, r));
    let core_contrib: vec3<f32> = core_color * core_intensity;

    // Star magnitude
    let mag: f32 = clamp(exp(-0.5 * r), 0.0, 1.0);

    // Arms
    let arm_rho_avg: f32 = 382.0;
    let arm_scale_uni: f32 = sqrt(arm_rho_avg);
    let uni_dist_arm: f32 = worley(p, arm_scale_uni);
    let rho_arm_local: f32 = get_arm_density(r, phi, theta_c);
    let rho_arm_safe: f32 = max(rho_arm_local, 1e-5);
    let local_dist_arm: f32 = uni_dist_arm * sqrt(arm_rho_avg / rho_arm_safe);
    let fwhm_arm: f32 = 0.03 + 0.004 * r;
    let sigma_arm: f32 = fwhm_arm / 2.355;
    let arm_gauss: f32 = exp(-0.5 * local_dist_arm * local_dist_arm / (sigma_arm * sigma_arm));
    let temp: f32 = 7200.0 - 250.0 * r;
    let arm_color: vec3<f32> = star_color(temp);
    let arm_contrib: vec3<f32> = arm_gauss * mag * arm_color;

    // Background halo
    let bg_rho_avg: f32 = 32.0;
    let bg_scale_uni: f32 = sqrt(bg_rho_avg);
    let uni_dist_bg: f32 = worley(p, bg_scale_uni);
    let rho_bg_local: f32 = get_bg_density(r);
    let rho_bg_safe: f32 = max(rho_bg_local, 1e-5);
    let local_dist_bg: f32 = uni_dist_bg * sqrt(bg_rho_avg / rho_bg_safe);
    let fwhm_bg: f32 = 0.015;
    let sigma_bg: f32 = fwhm_bg / 2.355;
    let bg_gauss: f32 = exp(-0.5 * local_dist_bg * local_dist_bg / (sigma_bg * sigma_bg));
    let bg_mag: f32 = 0.4 * mag;
    let bg_color: vec3<f32> = vec3<f32>(1.0, 0.96, 0.92);
    let bg_contrib: vec3<f32> = bg_gauss * bg_mag * bg_color;

    var col: vec3<f32> = core_contrib + arm_contrib + bg_contrib;
    col = clamp(col, vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(2.0, 2.0, 2.0));
    col = col / (1.0 + col * 0.3); // soft tone map
    return vec4<f32>(col, 1.0);
}