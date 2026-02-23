// Mechanical Gear Assembly - Kinematic Visualization
// Three meshed gears with angular velocity glyphs
// Orthographic top-down view with 15° tilt

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

// Constants for gear geometry
const PI = 3.14159265359;
const GEAR_A_TEETH = 24u;
const GEAR_A_RADIUS = 2.0;
const GEAR_B_TEETH = 16u;
const GEAR_B_RADIUS = 1.4;
const GEAR_C_TEETH = 12u;
const GEAR_C_RADIUS = 1.0;
const MODULE = 0.26;

// Angular velocities (rad/s)
const OMEGA_A = 1.0;
const OMEGA_B = -1.5;
const OMEGA_C = 1.333;

// Gear centers along x-axis
const CENTER_A = vec2<f32>(0.0, 0.0);
const CENTER_B = vec2<f32>(3.4, 0.0);
const CENTER_C = vec2<f32>(5.4, 0.0);

// 15° tilt for isometric view
const TILT_ANGLE = 0.261799;

fn rotate_2d(p: vec2<f32>, angle: f32) -> vec2<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec2<f32>(c * p.x - s * p.y, s * p.x + c * p.y);
}

fn apply_tilt(p: vec2<f32>) -> vec2<f32> {
    let c = cos(TILT_ANGLE);
    let s = sin(TILT_ANGLE);
    return vec2<f32>(c * p.x - s * p.y, s * p.x + c * p.y);
}

fn distance_to_circle(p: vec2<f32>, center: vec2<f32>, radius: f32) -> f32 {
    return abs(length(p - center) - radius);
}

fn draw_gear_teeth(p: vec2<f32>, center: vec2<f32>, radius: f32, num_teeth: u32, phase: f32) -> f32 {
    let local = p - center;
    let r = length(local);
    let angle = atan2(local.y, local.x) - phase;
    
    let tooth_angle = 2.0 * PI / f32(num_teeth);
    let normalized_angle = angle % tooth_angle;
    let tooth_dev = abs(normalized_angle - tooth_angle * 0.5) / (tooth_angle * 0.5);
    
    let r_outer = radius + 0.15;
    let r_inner = radius - 0.15;
    
    let target_r = mix(r_inner, r_outer, smoothstep(0.0, 1.0, tooth_dev));
    return abs(r - target_r);
}

fn draw_gear(p: vec2<f32>, center: vec2<f32>, radius: f32, num_teeth: u32, phase: f32) -> f32 {
    let circle_dist = distance_to_circle(p, center, radius);
    let tooth_dist = draw_gear_teeth(p, center, radius, num_teeth, phase);
    return min(circle_dist, tooth_dist);
}

fn draw_arrow(p: vec2<f32>, origin: vec2<f32>, direction: vec2<f32>, length: f32, width: f32) -> f32 {
    let to_point = p - origin;
    let dir_norm = normalize(direction);
    let proj = dot(to_point, dir_norm);
    
    let along_dist = abs(proj);
    if (along_dist > length) {
        return 1000.0;
    }
    
    let perp_vec = to_point - dir_norm * proj;
    let perp_dist = length(perp_vec);
    
    let body_width = width * 0.4;
    let body_cond = select(0.0, 1.0, along_dist < length * 0.7);
    let body_dist = select(1000.0, perp_dist - body_width, body_cond > 0.5);
    
    let head_start = length * 0.7;
    var head_dist = 1000.0;
    if (along_dist >= head_start && along_dist <= length) {
        let head_progress = (along_dist - head_start) / (length - head_start);
        let head_taper = width * (1.0 - head_progress);
        if (perp_dist <= head_taper) {
            head_dist = 0.0;
        }
    }
    
    return min(body_dist, head_dist);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy / params.resolution - 0.5) * 2.0;
    let screen_pos = vec2<f32>(uv.x * aspect, uv.y);
    
    let p = apply_tilt(screen_pos * 2.5);
    
    let gear_a_phase = 0.0;
    let gear_b_phase = PI / f32(GEAR_B_TEETH);
    let gear_c_phase = PI / f32(GEAR_C_TEETH);
    
    let dist_a = draw_gear(p, CENTER_A, GEAR_A_RADIUS, GEAR_A_TEETH, gear_a_phase);
    let dist_b = draw_gear(p, CENTER_B, GEAR_B_RADIUS, GEAR_B_TEETH, gear_b_phase);
    let dist_c = draw_gear(p, CENTER_C, GEAR_C_RADIUS, GEAR_C_TEETH, gear_c_phase);
    
    let min_gear_dist = min(dist_a, min(dist_b, dist_c));
    
    let arrow_scale = 1.2;
    let arrow_len_a = abs(OMEGA_A) * arrow_scale;
    let arrow_len_b = abs(OMEGA_B) * arrow_scale;
    let arrow_len_c = abs(OMEGA_C) * arrow_scale;
    
    let dir_a = select(vec2<f32>(0.0, -1.0), vec2<f32>(0.0, 1.0), OMEGA_A > 0.0);
    let dir_b = select(vec2<f32>(0.0, -1.0), vec2<f32>(0.0, 1.0), OMEGA_B > 0.0);
    let dir_c = select(vec2<f32>(0.0, -1.0), vec2<f32>(0.0, 1.0), OMEGA_C > 0.0);
    
    let arrow_a = draw_arrow(p, apply_tilt(CENTER_A * 2.5), dir_a, arrow_len_a, 0.25);
    let arrow_b = draw_arrow(p, apply_tilt(CENTER_B * 2.5), dir_b, arrow_len_b, 0.25);
    let arrow_c = draw_arrow(p, apply_tilt(CENTER_C * 2.5), dir_c, arrow_len_c, 0.25);
    
    let min_arrow_dist = min(arrow_a, min(arrow_b, arrow_c));
    
    let metal_grey = vec3<f32>(0.65, 0.65, 0.68);
    let dark_grey = vec3<f32>(0.35, 0.35, 0.37);
    let accent_color = vec3<f32>(0.95, 0.80, 0.2);
    let bg_color = vec3<f32>(0.15, 0.15, 0.16);
    
    let line_width = 0.08;
    let arrow_width = 0.06;
    
    var color = bg_color;
    
    if (min_gear_dist < line_width) {
        let gear_intensity = 1.0 - smoothstep(0.0, line_width, min_gear_dist);
        let shade = mix(dark_grey, metal_grey, gear_intensity * 0.5);
        color = mix(color, shade, 0.9);
    }
    
    if (min_arrow_dist < arrow_width) {
        let arrow_intensity = 1.0 - smoothstep(0.0, arrow_width, min_arrow_dist);
        color = mix(color, accent_color, arrow_intensity * 0.95);
    }
    
    let grid_freq = 0.5;
    let grid_x = step(0.9, fract(p.x * grid_freq));
    let grid_y = step(0.9, fract(p.y * grid_freq));
    let grid = (grid_x + grid_y) * 0.08;
    color = color + grid * bg_color;
    
    return vec4<f32>(color, 1.0);
}