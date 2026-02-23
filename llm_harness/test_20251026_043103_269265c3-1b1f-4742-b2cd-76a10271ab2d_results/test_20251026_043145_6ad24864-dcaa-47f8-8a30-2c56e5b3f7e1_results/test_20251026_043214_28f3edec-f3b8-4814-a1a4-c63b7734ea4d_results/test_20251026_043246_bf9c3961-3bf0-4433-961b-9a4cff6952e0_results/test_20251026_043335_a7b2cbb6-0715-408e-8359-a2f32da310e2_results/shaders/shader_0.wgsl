// Archimedes' Spiral Visualization
// Historical mathematical recreation of the spiral discovered circa 225 BCE in Syracuse
// Features: spiral generation, angle trisection, area calculation (exhaustion method)

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

// Distance to line segment (for rendering)
fn distance_to_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Archimedean spiral: r = a * theta
fn spiral_radius(theta: f32, a: f32) -> f32 {
    return a * theta;
}

// Convert polar to Cartesian coordinates
fn polar_to_cartesian(r: f32, theta: f32) -> vec2<f32> {
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

// Signed distance field for spiral curve
fn spiral_sdf(pos: vec2<f32>, time: f32) -> f32 {
    let max_theta = 8.0 * 3.14159265;
    let a = 0.15; // Spiral parameter
    let thickness = 0.008;
    
    var min_dist = 1000.0;
    
    // Trace spiral with animated generation
    let animation_theta = mix(0.0, max_theta, time);
    let step_size = 0.05;
    var theta = 0.0;
    
    loop {
        if (theta > animation_theta) { break; }
        
        let r1 = spiral_radius(theta, a);
        let r2 = spiral_radius(theta + step_size, a);
        
        let p1 = polar_to_cartesian(r1, theta);
        let p2 = polar_to_cartesian(r2, theta + step_size);
        
        min_dist = min(min_dist, distance_to_line(pos, p1, p2));
        
        theta = theta + step_size;
    }
    
    return min_dist - thickness;
}

// Draw radial construction lines for angle trisection
fn trisection_construction_sdf(pos: vec2<f32>) -> f32 {
    let min_dist = 1000.0;
    var dist = min_dist;
    
    // Reference angle: 60 degrees (pi/3)
    let base_angle = 1.047197551; // 60 degrees in radians
    
    // Ray OB at angle 0
    let ray_length = 0.6;
    let ray_b_end = polar_to_cartesian(ray_length, 0.0);
    dist = min(dist, distance_to_line(pos, vec2<f32>(0.0), ray_b_end));
    
    // Ray OA at angle 60 degrees
    let ray_a_end = polar_to_cartesian(ray_length, base_angle);
    dist = min(dist, distance_to_line(pos, vec2<f32>(0.0), ray_a_end));
    
    // Arc from O intersecting OB at point C (radius = ray_length)
    let arc_thickness = 0.005;
    for (var i: i32 = 0; i < 60; i = i + 1) {
        let angle_step = base_angle / 60.0;
        let a1 = f32(i) * angle_step;
        let a2 = f32(i + 1) * angle_step;
        let p1 = polar_to_cartesian(ray_length, a1);
        let p2 = polar_to_cartesian(ray_length, a2);
        dist = min(dist, distance_to_line(pos, p1, p2) - arc_thickness);
    }
    
    // Point P on spiral where trisection occurs (1/3 of OC distance)
    let p_radius = ray_length / 3.0;
    let p_angle = base_angle / 3.0; // This should equal 20 degrees
    let p_pos = polar_to_cartesian(p_radius, p_angle);
    
    // Small circle at point P
    let p_marker = length(pos - p_pos) - 0.015;
    dist = min(dist, p_marker);
    
    // Ray OP showing the trisected angle
    dist = min(dist, distance_to_line(pos, vec2<f32>(0.0), p_pos * 4.0));
    
    return dist;
}

// Exhaustion method visualization (inscribed polygons)
fn exhaustion_method_sdf(pos: vec2<f32>) -> f32 {
    let origin = vec2<f32>(0.0);
    let first_turn_radius = 1.2566371; // r at theta = 2π (one complete turn)
    var dist = 1000.0;
    
    // Draw inscribed polygon approximations (6, 12, 24 sides)
    let polygon_sides_array = array<i32, 3>(6, 12, 24);
    
    for (var p_idx: i32 = 0; p_idx < 3; p_idx = p_idx + 1) {
        let sides = polygon_sides_array[p_idx];
        let opacity_factor = f32(p_idx) / 3.0 + 0.33;
        
        for (var i: i32 = 0; i < sides; i = i + 1) {
            let a1 = 2.0 * 3.14159265 * f32(i) / f32(sides);
            let a2 = 2.0 * 3.14159265 * f32(i + 1) / f32(sides);
            
            let p1 = polar_to_cartesian(first_turn_radius, a1);
            let p2 = polar_to_cartesian(first_turn_radius, a2);
            
            let line_dist = distance_to_line(pos, p1, p2);
            dist = min(dist, line_dist - 0.003 * opacity_factor);
        }
    }
    
    return dist;
}

// Tangent properties visualization
fn tangent_properties_sdf(pos: vec2<f32>) -> f32 {
    let a = 0.15;
    let sample_theta = 3.14159265 * 2.0; // Point at theta = 2π
    let r = spiral_radius(sample_theta, a);
    let point = polar_to_cartesian(r, sample_theta);
    
    // Tangent angle: tan(ψ) = r/a = theta (for r = a*theta)
    let tangent_angle = atan(r / a);
    
    // Tangent line direction
    let tangent_dir = vec2<f32>(cos(sample_theta + tangent_angle), sin(sample_theta + tangent_angle));
    let tangent_end = point + tangent_dir * 0.3;
    
    // Draw radius vector
    var dist = distance_to_line(pos, vec2<f32>(0.0), point * 1.2) - 0.003;
    
    // Draw tangent line
    dist = min(dist, distance_to_line(pos, point - tangent_dir * 0.2, tangent_end) - 0.002);
    
    return dist;
}

// Papyrus background texture
fn papyrus_texture(uv: vec2<f32>) -> vec3<f32> {
    let base_color = vec3<f32>(0.96, 0.92, 0.82); // Aged papyrus
    
    // Add subtle noise and aging effects
    let noise = sin(uv.x * 100.0) * cos(uv.y * 100.0) * 0.02;
    let aging = smoothstep(1.0, 0.8, length(uv - vec2<f32>(0.5))) * 0.05;
    
    return base_color + vec3<f32>(noise) - vec3<f32>(aging);
}

// Ancient Greek styling
fn greek_ink_color(sdf_val: f32) -> vec3<f32> {
    // Deep blue ink (#1E3263)
    let ink_color = vec3<f32>(0.118, 0.196, 0.388);
    let alpha = smoothstep(0.01, -0.01, sdf_val);
    return mix(vec3<f32>(1.0), ink_color, alpha);
}

fn construction_red(sdf_val: f32) -> vec3<f32> {
    // Faded red for construction lines (#8B4513 - saddle brown)
    let red_color = vec3<f32>(0.545, 0.271, 0.075);
    let alpha = smoothstep(0.008, -0.008, sdf_val);
    return mix(vec3<f32>(1.0), red_color, alpha);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates with centered origin
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Background papyrus
    let bg_color = papyrus_texture(uv);
    var final_color = bg_color;
    
    // Time animation (0 to 1 in ~7 seconds)
    let animation_time = fract(length(uv) * 0.3) * 0.5; // Loop for visibility
    
    // Draw main Archimedean spiral
    let spiral_dist = spiral_sdf(uv, animation_time);
    let spiral_color = greek_ink_color(spiral_dist);
    final_color = mix(final_color, spiral_color, 1.0 - smoothstep(-0.05, 0.05, spiral_dist));
    
    // Draw angle trisection construction
    let trisection_dist = trisection_construction_sdf(uv);
    let trisection_color = construction_red(trisection_dist);
    final_color = mix(final_color, trisection_color, 1.0 - smoothstep(-0.03, 0.03, trisection_dist));
    
    // Draw exhaustion method polygons (for circle quadrature)
    let exhaustion_dist = exhaustion_method_sdf(uv);
    let exhaustion_color = vec3<f32>(0.8, 0.7, 0.2); // Golden color
    final_color = mix(final_color, exhaustion_color, 0.3 * (1.0 - smoothstep(-0.02, 0.02, exhaustion_dist)));
    
    // Draw tangent properties
    let tangent_dist = tangent_properties_sdf(uv);
    let tangent_color = vec3<f32>(0.3, 0.6, 0.9);
    final_color = mix(final_color, tangent_color, 0.4 * (1.0 - smoothstep(-0.015, 0.015, tangent_dist)));
    
    // Add water damage/aging at edges
    let edge_damage = smoothstep(1.2, 0.7, length(uv));
    final_color = mix(final_color, vec3<f32>(0.7, 0.65, 0.55), edge_damage * 0.3);
    
    // Subtle vignette for papyrus effect
    let vignette = 1.0 - smoothstep(0.5, 1.5, length(uv)) * 0.2;
    final_color = final_color * vignette;
    
    return vec4<f32>(final_color, 1.0);
}