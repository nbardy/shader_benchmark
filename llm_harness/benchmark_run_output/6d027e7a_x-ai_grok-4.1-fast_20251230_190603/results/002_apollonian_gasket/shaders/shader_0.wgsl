@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    dummy1: f32,
    dummy2: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn length2(v: vec2<f32>) -> f32 {
    return v.x * v.x + v.y * v.y;
}

fn mobius_div(num: vec2<f32>, den: vec2<f32>) -> vec2<f32> {
    let den2 = length2(den);
    if (den2 < 1e-12) {
        return vec2<f32>(1e6, 1e6);
    }
    let ix = den.x / den2;
    let iy = -den.y / den2;
    return vec2<f32>(
        num.x * ix - num.y * iy,
        num.x * iy + num.y * ix
    );
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let scale: f32 = 2.2;
    let z = (pos.xy / res - 0.5) * vec2<f32>(scale, scale);
    var current_z: vec2<f32> = z;
    var even_acc: f32 = 0.0;
    var odd_acc: f32 = 0.0;
    let num_iters: u32 = 80u;
    var i: u32 = 0u;
    loop {
        if (i >= num_iters) {
            break;
        }
        let dist_sq = length2(current_z);
        let contrib = exp(-dist_sq * 8.0);
        if (i >= 12u) {
            if (i % 2u == 0u) {
                even_acc = even_acc + contrib;
            } else {
                odd_acc = odd_acc + contrib;
            }
        }
        let num1: vec2<f32> = vec2<f32>(1.0 - current_z.x, -current_z.y);
        let den: vec2<f32> = vec2<f32>(current_z.x - 2.0, current_z.y);
        let inv1 = mobius_div(num1, den);
        let num2: vec2<f32> = vec2<f32>(current_z.x - 1.0, current_z.y);
        let inv2 = mobius_div(num2, den);
        let d1_sq = length2(inv1);
        let d2_sq = length2(inv2);
        let min_d_sq = min(d1_sq, d2_sq);
        if (min_d_sq > 200.0) {
            break;
        }
        current_z = select(inv1, inv2, d1_sq < d2_sq);
        i = i + 1u;
    }
    let mul: f32 = 5.0;
    let red_color: vec3<f32> = vec3<f32>(1.0, 0.20, 0.32);
    let green_color: vec3<f32> = vec3<f32>(0.20, 1.0, 0.32);
    var col: vec3<f32> = even_acc * mul * red_color + odd_acc * mul * green_color;
    col = pow(col, vec3<f32>(0.65));
    col = col * (1.0 + 0.4 * pow(max(length2((pos.xy / res - 0.5)), 0.0), 2.0));  // fake bloom glow at center
    return vec4<f32>(col, 1.0);
}