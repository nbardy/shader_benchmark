// Chinese Remainder Theorem Visualization - Sunzi Suanjing
// Historical visualization of ancient Chinese modular arithmetic

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
    _padding: f32,
}

@group(0) @binding(0) var<uniform> params: Params;

// Ancient Chinese modular arithmetic constants
const M: i32 = 105;      // 3 * 5 * 7 (product of moduli)
const M1: i32 = 35;      // M / 3
const M2: i32 = 21;      // M / 5
const M3: i32 = 15;      // M / 7
const TARGET_X: i32 = 23; // solution

// Rice paper background color (warm ivory)
const RICE_PAPER: vec3<f32> = vec3<f32>(1.0, 0.97, 0.92);

// Chinese ink colors
const INK_DARK: vec3<f32> = vec3<f32>(0.1, 0.1, 0.12);
const RED_SEAL: vec3<f32> = vec3<f32>(0.9, 0.2, 0.2);
const BLUE_INK: vec3<f32> = vec3<f32>(0.2, 0.4, 0.8);
const GREEN_INK: vec3<f32> = vec3<f32>(0.2, 0.7, 0.4);

fn sdf_circle(p: vec2<f32>, center: vec2<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

fn sdf_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, thickness: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - thickness;
}

fn smoothstep_edge(d: f32, edge: f32, smoothness: f32) -> f32 {
    let scaled = (d - edge + smoothness) / (2.0 * smoothness);
    return clamp(scaled, 0.0, 1.0);
}

fn draw_modular_circle(uv: vec2<f32>, center: vec2<f32>, radius: f32, modulus: i32, highlight_idx: i32, time_phase: f32) -> vec3<f32> {
    let d = sdf_circle(uv, center, radius);
    
    // Circle outline
    let outline = smoothstep_edge(d, 0.0, 0.004);
    var color = mix(RICE_PAPER, INK_DARK, outline);
    
    // Draw tick marks for each remainder position
    var i = 0;
    loop {
        if (i >= modulus) { break; }
        
        let angle = f32(i) / f32(modulus) * 6.28318530718 - 1.5707963267949;
        let mark_pos = center + vec2<f32>(cos(angle), sin(angle)) * radius;
        let tick_start = center + vec2<f32>(cos(angle), sin(angle)) * (radius - 0.03);
        let tick_end = mark_pos;
        
        let tick_dist = sdf_line(uv, tick_start, tick_end, 0.002);
        let tick = smoothstep_edge(tick_dist, 0.0, 0.003);
        
        color = mix(color, INK_DARK, tick * 0.6);
        
        i = i + 1;
    }
    
    // Highlight target remainder positions
    let target_angle = f32(highlight_idx) / f32(modulus) * 6.28318530718 - 1.5707963267949;
    let target_mark = center + vec2<f32>(cos(target_angle), sin(target_angle)) * radius;
    
    let mark_glow = sdf_circle(uv, target_mark, 0.015);
    let glow = smoothstep_edge(mark_glow, 0.0, 0.015);
    
    color = mix(color, RED_SEAL, glow * 0.8);
    
    // Pulsing animation on target marks
    let pulse = sin(time_phase * 3.14159265359 * 2.0) * 0.5 + 0.5;
    let glow_pulse = smoothstep_edge(mark_glow, 0.01 * pulse, 0.008);
    color = mix(color, RED_SEAL, glow_pulse * 0.4);
    
    return color;
}

fn spiral_position(n: i32, total_count: i32) -> vec2<f32> {
    let t = f32(n) / f32(total_count);
    let theta = t * 12.0;  // 2 full rotations
    let r = t * 0.3;
    return vec2<f32>(cos(theta) * r, sin(theta) * r);
}

fn get_modular_remainders(x: i32) -> vec3<i32> {
    let r3 = x % 3;
    let r5 = x % 5;
    let r7 = x % 7;
    return vec3<i32>(r3, r5, r7);
}

fn visualize_number_line(uv: vec2<f32>, y_offset: f32) -> vec3<f32> {
    var color = RICE_PAPER;
    
    // Draw spiral number line from 0 to 105
    var i = 0;
    loop {
        if (i >= 105) { break; }
        
        let pos = spiral_position(i, 105);
        let display_pos = vec2<f32>(pos.x * 0.25 - 0.3, y_offset + pos.y * 0.25);
        
        let remainders = get_modular_remainders(i);
        let contrib_r3 = select(0.0, 1.0, remainders.x == 2);
        let contrib_r5 = select(0.0, 1.0, remainders.y == 3);
        let contrib_r7 = select(0.0, 1.0, remainders.z == 2);
        
        let is_solution = select(0.0, 1.0, i == TARGET_X);
        
        // Number point coloring
        let point_color = vec3<f32>(
            contrib_r3 + is_solution * 0.5,
            contrib_r5 + is_solution * 0.5,
            contrib_r7 + is_solution * 0.5
        );
        
        let point_dist = length(uv - display_pos);
        let point = smoothstep(0.015, 0.012, point_dist);
        let point_glow = smoothstep(0.035, 0.015, point_dist) * 0.3;
        
        color = mix(color, normalize(point_color + vec3<f32>(0.3)), point);
        color = mix(color, point_color, point_glow * 0.5);
        
        i = i + 1;
    }
    
    return color;
}

fn da_yan_algorithm_visualization(uv: vec2<f32>, time: f32) -> vec3<f32> {
    var color = RICE_PAPER;
    
    // Title area
    let title_y = 0.85;
    let title_color = mix(RICE_PAPER, INK_DARK, smoothstep(0.1, 0.08, abs(uv.y - title_y)));
    color = mix(color, title_color, 0.3);
    
    // Three modular circles arranged horizontally
    let circle_y = 0.5;
    let circle_radius = 0.12;
    
    // Mod 3 circle (x ≡ 2 mod 3)
    let c1_pos = vec2<f32>(-0.5, circle_y);
    let c1_color = draw_modular_circle(uv, c1_pos, circle_radius, 3, 2, time);
    color = mix(color, c1_color, 0.7);
    
    // Mod 5 circle (x ≡ 3 mod 5)
    let c2_pos = vec2<f32>(0.0, circle_y);
    let c2_color = draw_modular_circle(uv, c2_pos, circle_radius, 5, 3, time + 0.3);
    color = mix(color, c2_color, 0.7);
    
    // Mod 7 circle (x ≡ 2 mod 7)
    let c3_pos = vec2<f32>(0.5, circle_y);
    let c3_color = draw_modular_circle(uv, c3_pos, circle_radius, 7, 2, time + 0.6);
    color = mix(color, c3_color, 0.7);
    
    // Connection lines animated
    let anim_pulse = sin(time * 2.0) * 0.5 + 0.5;
    let line1_dist = sdf_line(uv, c1_pos, c2_pos, 0.002 + anim_pulse * 0.001);
    let line2_dist = sdf_line(uv, c2_pos, c3_pos, 0.002 + anim_pulse * 0.001);
    
    let line1 = smoothstep_edge(line1_dist, 0.0, 0.003);
    let line2 = smoothstep_edge(line2_dist, 0.0, 0.003);
    
    color = mix(color, INK_DARK * vec3<f32>(0.6, 0.8, 1.0), line1 * 0.5);
    color = mix(color, INK_DARK * vec3<f32>(0.6, 0.8, 1.0), line2 * 0.5);
    
    return color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    let time = params.time * 0.5;
    
    var final_color = RICE_PAPER;
    
    // Three main sections with different visualizations
    if (uv.y > 0.1) {
        // Top: Da-yan algorithm with three circles
        final_color = da_yan_algorithm_visualization(uv, time);
    } else if (uv.y > -0.3) {
        // Middle: Number line spiral showing convergence
        final_color = visualize_number_line(uv, -0.1);
    } else {
        // Bottom: Solution display
        let solution_y = -0.6;
        let solution_dist = length(uv - vec2<f32>(0.0, solution_y));
        
        // Solution circle highlighting x = 23
        let sol_circle = smoothstep(0.08, 0.06, solution_dist);
        final_color = mix(final_color, RED_SEAL, sol_circle * 0.8);
        
        // Solution number text area
        let text_color = smoothstep(0.12, 0.08, solution_dist);
        final_color = mix(final_color, INK_DARK, text_color * 0.6);
    }
    
    // Decorative border (seal stamp effect)
    let border_dist = min(abs(uv.x) - 0.95, abs(uv.y) - 0.95);
    let border = smoothstep(0.015, 0.01, border_dist);
    final_color = mix(final_color, RED_SEAL, border * 0.3);
    
    // Subtle noise for rice paper texture
    let noise_seed = sin(uv.x * 73.1 + uv.y * 43.7 + time * 0.1) * 0.5 + 0.5;
    final_color = mix(final_color, final_color * 0.98, noise_seed * 0.05);
    
    return vec4<f32>(final_color, 1.0);
}