// Chinese Remainder Theorem Visualization - Ancient Chinese Mathematical Heritage
// Sunzi Suanjing (3rd-5th century CE) - The Da-yan (Great Extension) Algorithm
// Visualization of: x ≡ 2 (mod 3), x ≡ 3 (mod 5), x ≡ 2 (mod 7)
// Solution: x ≡ 23 (mod 105)

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
}

@group(0) @binding(0) var<uniform> params: Params;

// Helper: distance to line segment
fn line_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Helper: draw circle
fn circle_sdf(p: vec2<f32>, center: vec2<f32>, radius: f32) -> f32 {
    return length(p - center) - radius;
}

// Helper: modulo operation for integer values
fn mod_i32(a: i32, b: i32) -> i32 {
    let r = a % b;
    return select(r, r + b, r < 0);
}

// Draw a modular circle with marked positions
fn draw_modular_circle(uv: vec2<f32>, center: vec2<f32>, modulus: f32, remainder: f32, 
                       offset_angle: f32, time: f32) -> vec4<f32> {
    let circle_radius = 0.08;
    let mark_radius = 0.012;
    let line_width = 0.003;
    
    // Main circle
    let dist_to_circle = abs(circle_sdf(uv, center, circle_radius)) - line_width;
    let circle_color = smoothstep(line_width * 2.0, 0.0, dist_to_circle);
    
    // Draw position markers on circle
    var result = vec4<f32>(0.2, 0.15, 0.1, circle_color * 0.8); // Rice paper background tint
    
    // Draw modulus marks (0 to modulus-1)
    for (var i: i32 = 0; i < i32(modulus); i = i + 1) {
        let angle = (f32(i) / modulus) * 6.28318530718 + offset_angle;
        let mark_pos = center + vec2<f32>(cos(angle), sin(angle)) * circle_radius;
        
        // Mark circle
        let mark_dist = circle_sdf(uv, mark_pos, mark_radius);
        let is_mark = smoothstep(line_width, -line_width, mark_dist);
        
        // Highlight the required remainder in red
        let is_remainder = select(
            0.0,
            1.0,
            f32(i) == remainder
        );
        
        let mark_color = vec3<f32>(
            0.8 + is_remainder * 0.2,
            0.2 + is_remainder * (-0.1),
            0.2 + is_remainder * (-0.1)
        );
        
        result = mix(result, vec4<f32>(mark_color, 1.0), is_mark * 0.9);
    }
    
    return result;
}

// Spiral position for number line visualization
fn spiral_position(n: i32, spiral_radius: f32, density: f32) -> vec2<f32> {
    let angle = f32(n) * density;
    let r = spiral_radius + f32(n) * 0.0015;
    return vec2<f32>(cos(angle), sin(angle)) * r;
}

// Check if number satisfies all three congruences
fn check_solution(n: i32) -> vec3<f32> {
    let m3 = mod_i32(n, 3);
    let m5 = mod_i32(n, 5);
    let m7 = mod_i32(n, 7);
    
    // Check remainders: 2 (mod 3), 3 (mod 5), 2 (mod 7)
    let satisfies_3 = select(0.0, 1.0, m3 == 2);
    let satisfies_5 = select(0.0, 1.0, m5 == 3);
    let satisfies_7 = select(0.0, 1.0, m7 == 2);
    
    // Red tint for x ≡ 2 (mod 3)
    let color_r = vec3<f32>(satisfies_3, 0.0, 0.0);
    // Blue tint for x ≡ 3 (mod 5)
    let color_b = vec3<f32>(0.0, 0.0, satisfies_5);
    // Green tint for x ≡ 2 (mod 7)
    let color_g = vec3<f32>(0.0, satisfies_7, 0.0);
    
    return color_r + color_b + color_g;
}

// Draw spiral number line
fn draw_spiral_line(uv: vec2<f32>, time: f32) -> vec4<f32> {
    let spiral_radius = 0.15;
    let density = 0.3;
    let point_size = 0.008;
    
    var color = vec4<f32>(0.0);
    
    // Draw 0-105 on spiral
    for (var n: i32 = 0; n < 106; n = n + 1) {
        let pos = spiral_position(n, spiral_radius, density);
        let dist = length(uv - pos);
        
        let solution_color = check_solution(n);
        let is_solution = select(
            0.0,
            1.0,
            n == 23
        );
        
        // Draw point
        let point_alpha = smoothstep(point_size, point_size * 0.5, dist);
        let point_col = mix(
            solution_color + vec3<f32>(0.1, 0.1, 0.1),
            vec3<f32>(1.0, 1.0, 0.0),
            is_solution
        );
        
        color = mix(color, vec4<f32>(point_col, 1.0), point_alpha * 0.7);
    }
    
    return color;
}

// Draw algorithm animation
fn draw_algorithm_steps(uv: vec2<f32>, time: f32) -> vec4<f32> {
    var result = vec4<f32>(0.0);
    
    // Step labels and visualization
    let _step_time = mod(time * 0.5, 5.0);
    
    // Three modular circles: M=3, M=5, M=7
    let circle_y_positions = vec3<f32>(-0.6, 0.0, 0.6);
    let circle_x = -0.45;
    
    // Circle 1: mod 3
    let circle1 = draw_modular_circle(
        uv,
        vec2<f32>(circle_x, circle_y_positions.x),
        3.0,
        2.0,
        time * 1.5,
        time
    );
    result = mix(result, circle1, circle1.a);
    
    // Circle 2: mod 5
    let circle2 = draw_modular_circle(
        uv,
        vec2<f32>(circle_x, circle_y_positions.y),
        5.0,
        3.0,
        time * 1.2,
        time
    );
    result = mix(result, circle2, circle2.a);
    
    // Circle 3: mod 7
    let circle3 = draw_modular_circle(
        uv,
        vec2<f32>(circle_x, circle_y_positions.z),
        7.0,
        2.0,
        time * 0.9,
        time
    );
    result = mix(result, circle3, circle3.a);
    
    // Spiral number line on right side
    let spiral_uv = uv - vec2<f32>(0.45, 0.0);
    let spiral = draw_spiral_line(spiral_uv, time);
    result = mix(result, spiral, spiral.a * 0.6);
    
    return result;
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Rice paper background
    let bg_color = vec4<f32>(0.99, 0.96, 0.90, 1.0);
    
    // Draw algorithm visualization
    let algo_viz = draw_algorithm_steps(uv, params.time);
    
    // Blend with background
    let result = mix(bg_color, algo_viz, algo_viz.a);
    
    // Add subtle border pattern (traditional seal)
    let border_dist = max(abs(uv.x), abs(uv.y));
    let border = smoothstep(0.98, 0.96, border_dist);
    let final = mix(result, vec4<f32>(0.2, 0.15, 0.1, 1.0), border * 0.3);
    
    return final;
}