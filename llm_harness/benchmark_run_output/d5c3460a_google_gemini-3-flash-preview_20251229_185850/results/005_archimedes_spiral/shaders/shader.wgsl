// Archimedes' Spiral: Historical Geometry and Applications
// Developed for Syracuse circa 225 BCE

struct Params {
    resolution: vec2<f32>,
    time: f32, // Expected time parameter for animation
};

@group(0) @binding(0) var<uniform> params: Params;

// Vertex Shader Output Structure
struct VertexOut {
    @builtin(position) pos : vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// Utility: Distance to line segment
fn sd_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Utility: Distance to Archimedean Spiral r = a * theta
fn sd_spiral(p: vec2<f32>, a_coeff: f32) -> f32 {
    let r = length(p);
    let theta = atan2(p.y, p.x);
    
    // Check multiple turns (wrapping)
    var min_d = 1e10;
    // Archimedes explored up to 4+ turns in "On Spirals"
    for (var i: i32 = 0; i < 5; i = i + 1) {
        let t = theta + f32(i) * 6.283185307;
        let r_spiral = a_coeff * t;
        min_d = min(min_d, abs(r - r_spiral));
    }
    return min_d;
}

// Papyrus texture generation
fn get_papyrus(uv: vec2<f32>) -> vec3<f32> {
    let base = vec3<f32>(0.96, 0.90, 0.82);
    let n = fract(sin(dot(uv, vec2<f32>(12.9898, 78.233))) * 43758.5453);
    let fiber = sin(uv.x * 200.0) * sin(uv.y * 3.0) + sin(uv.y * 150.0) * sin(uv.x * 2.0);
    return base - vec3<f32>(n * 0.05) - vec3<f32>(abs(fiber) * 0.02);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv_raw = (pos.xy * 2.0 - params.resolution.xy) / min(params.resolution.x, params.resolution.y);
    let uv = uv_raw * 15.0; // Zoom out to see turns
    
    // Background Papyrus
    var color = get_papyrus(pos.xy * 0.001);
    
    // Constants
    let a_spiral = 0.5; // Spiral coefficient
    let ink_blue = vec3<f32>(0.117, 0.196, 0.388);
    let ink_red = vec3<f32>(0.545, 0.271, 0.075);
    let gold = vec3<f32>(0.83, 0.68, 0.21);

    // 1. Draw the Spiral r = a * theta
    let d_spiral = sd_spiral(uv, a_spiral);
    let spiral_mask = smoothstep(0.12, 0.08, d_spiral);
    
    // Construction Animation - sweep through angles
    let t_anim = (params.time * 0.5) % 8.0; 
    let r_p = length(uv);
    let theta_p = atan2(uv.y, uv.x) + select(0.0, 6.28318, atan2(uv.y, uv.x) < 0.0);
    let spiral_limit = select(spiral_mask, 0.0, r_p > (a_spiral * (theta_p + 18.0))); 
    
    color = mix(color, ink_blue, spiral_mask * 0.7);

    // 2. Trisection Visualization
    // Angle AOB = 60 degrees (pi/3)
    let angle_total = 1.04719755;
    let p_a = vec2<f32>(cos(0.0), sin(0.0)) * 10.0;
    let p_b = vec2<f32>(cos(angle_total), sin(angle_total)) * 10.0;
    
    // Ray OB intersects spiral at OC
    let radius_c = a_spiral * angle_total;
    let p_c = vec2<f32>(cos(angle_total), sin(angle_total)) * radius_c;
    
    // Point P on spiral where OP = (1/3)OC
    let radius_p = radius_c / 3.0;
    let angle_p = radius_p / a_spiral; // Since r = a * theta
    let target_p = vec2<f32>(cos(angle_p), sin(angle_p)) * radius_p;
    
    // Draw Trisection Lines
    let d_trisect_1 = sd_segment(uv, vec2<f32>(0.0), p_a);
    let d_trisect_2 = sd_segment(uv, vec2<f32>(0.0), p_b);
    let d_trisect_3 = sd_segment(uv, vec2<f32>(0.0), target_p);
    
    let line_mask = smoothstep(0.06, 0.03, min(d_trisect_1, d_trisect_2));
    color = mix(color, ink_red * 0.6, line_mask);
    color = mix(color, gold, smoothstep(0.06, 0.03, d_trisect_3));

    // 3. Exhaustion Method (Area of first turn)
    let r_first = length(uv);
    let theta_first = atan2(uv.y, uv.x);
    let in_first_turn = select(0.0, 1.0, r_first < (a_spiral * 6.28318) && r_first > 0.0);
    
    // Visualize "Slices" for exhaustion
    let slices = 12.0;
    let slice_angle = floor(atan2(uv.y, uv.x) * slices / 6.28318);
    let exhaustion_pattern = sin(uv.x * 20.0) * sin(uv.y * 20.0);
    color = mix(color, ink_red, in_first_turn * 0.1 * step(0.9, sin(r_first * 2.0)));

    // 4. Tangent at point P
    let t_vec = vec2<f32>(-sin(angle_total), cos(angle_total)); // Tangent component
    let radial_vec = vec2<f32>(cos(angle_total), sin(angle_total));
    let tangent_dir = normalize(t_vec * radius_c + radial_vec * a_spiral);
    let d_tangent = sd_segment(uv, p_c - tangent_dir * 3.0, p_c + tangent_dir * 3.0);
    color = mix(color, ink_red, smoothstep(0.05, 0.02, d_tangent) * 0.5);

    // 5. Compass Marks (scratches)
    let compass_circle = abs(length(uv) - radius_c);
    color = mix(color, ink_red, smoothstep(0.04, 0.02, compass_circle) * 0.3);

    // Aging: Vignette and water damage
    let dist_center = length(uv_raw);
    let vignette = smoothstep(1.2, 0.6, dist_center);
    let water_damage = fract(sin(uv.x * 0.5 + uv.y * 0.3) * 10.0);
    let final_noise = select(1.0, 0.9, water_damage > 0.95);
    
    return vec4<f32>(color * vignette * final_noise, 1.0);
}