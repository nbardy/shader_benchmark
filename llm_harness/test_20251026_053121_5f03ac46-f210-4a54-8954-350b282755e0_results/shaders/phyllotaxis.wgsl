// Phyllotactic Spiral Pattern - Golden Angle Sunflower Seeds
// Renders 500 seeds arranged by Fibonacci spiral arms with golden angle distribution

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

// Constants for phyllotactic pattern
const GOLDEN_ANGLE: f32 = 137.50776405026109f;
const GOLDEN_ANGLE_RAD: f32 = 2.39996322972865f;
const SCALE_FACTOR: f32 = 0.15f;
const NUM_SEEDS: u32 = 500u;
const SEED_BASE_RADIUS: f32 = 0.02f;
const SEED_GROWTH: f32 = 0.01f;

const FIB_8: u32 = 8u;
const FIB_13: u32 = 13u;
const FIB_21: u32 = 21u;
const FIB_34: u32 = 34u;
const FIB_55: u32 = 55u;

fn get_seed_position(n: u32) -> vec2<f32> {
    let n_f = f32(n);
    let theta = n_f * GOLDEN_ANGLE_RAD;
    let r = SCALE_FACTOR * sqrt(n_f);
    
    let x = r * cos(theta);
    let y = r * sin(theta);
    
    return vec2<f32>(x, y);
}

fn get_seed_radius(n: u32) -> f32 {
    let n_f = f32(n);
    let growth = SEED_GROWTH * sqrt(n_f / f32(NUM_SEEDS));
    return SEED_BASE_RADIUS + growth;
}

fn get_fibonacci_spiral_arm(n: u32) -> u32 {
    return n % FIB_55;
}

fn get_spiral_color(arm_55: u32) -> vec3<f32> {
    let color_index = arm_55 % 5u;
    
    if (color_index == 0u) {
        return vec3<f32>(1.0, 0.42f, 0.42f);
    } else if (color_index == 1u) {
        return vec3<f32>(0.31f, 0.80f, 0.77f);
    } else if (color_index == 2u) {
        return vec3<f32>(0.27f, 0.72f, 0.82f);
    } else if (color_index == 3u) {
        return vec3<f32>(0.97f, 0.86f, 0.44f);
    } else {
        return vec3<f32>(0.73f, 0.56f, 0.81f);
    }
}

fn radial_gradient_background(uv: vec2<f32>) -> vec3<f32> {
    let center_color = vec3<f32>(0.17f, 0.24f, 0.31f);
    let edge_color = vec3<f32>(0.10f, 0.15f, 0.19f);
    
    let dist_from_center = length(uv);
    let gradient_t = smoothstep(0.0, 1.5, dist_from_center);
    
    return mix(center_color, edge_color, gradient_t);
}

fn distance_to_circle(p: vec2<f32>, center: vec2<f32>, radius: f32) -> f32 {
    return abs(length(p - center) - radius);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5f) / params.resolution.y * 2.0f;
    
    var final_color = radial_gradient_background(uv);
    
    var min_distance = 1000.0f;
    var closest_color = vec3<f32>(0.0f);
    var closest_glow = 0.0f;
    
    var n = 0u;
    loop {
        if (n >= NUM_SEEDS) { break; }
        
        let seed_pos = get_seed_position(n);
        let seed_radius = get_seed_radius(n);
        let dist = distance_to_circle(uv, seed_pos, seed_radius);
        
        let spiral_arm = get_fibonacci_spiral_arm(n);
        let seed_color = get_spiral_color(spiral_arm);
        
        let glow_falloff = 0.008f;
        let glow = exp(-dist * dist / (glow_falloff * glow_falloff)) * 0.6f;
        
        if (dist < min_distance) {
            min_distance = dist;
            closest_color = seed_color;
            closest_glow = glow;
        }
        
        n = n + 1u;
    }
    
    let seed_edge_width = 0.003f;
    let seed_alpha = select(0.0f, 1.0f, min_distance < seed_edge_width);
    
    let glow_intensity = closest_glow * 0.3f;
    final_color = mix(final_color, closest_color, glow_intensity);
    final_color = mix(final_color, closest_color, seed_alpha);
    
    return vec4<f32>(final_color, 1.0f);
}