// Archimedes' Spiral Visualization
// Historical geometry: r = θ/π for θ ∈ [0, 8π]
// Features: Angle trisection, circle squaring, tangent properties
// Ancient Greek styling with papyrus texture and construction marks

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

// Ancient papyrus texture - aged parchment effect
fn papyrus_texture(uv: vec2<f32>) -> f32 {
    let noise1 = sin(uv.x * 73.0) * cos(uv.y * 127.0);
    let noise2 = sin(uv.x * 0.7 + uv.y * 0.3) * 0.5;
    let aging = sin(uv.x * 0.3) * cos(uv.y * 0.2) * 0.3;
    return 0.5 + noise1 * 0.15 + noise2 * 0.1 + aging * 0.08;
}

// Water damage edge effect
fn water_damage(uv: vec2<f32>) -> f32 {
    let edge_dist = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
    let damage = sin(uv.x * 20.0 + uv.y * 30.0) * 0.5 + 0.5;
    return smoothstep(-0.1, 0.05, edge_dist) * (1.0 - damage * 0.3);
}

// Archimedes spiral: r = θ/π
fn archimedes_spiral(theta: f32) -> f32 {
    return theta / 3.14159265;
}

// Distance to spiral curve
fn distance_to_spiral(uv: vec2<f32>) -> f32 {
    let r = length(uv);
    let theta = atan2(uv.y, uv.x);
    let theta_norm = select(theta, theta + 6.28318531, theta < 0.0);
    
    let spiral_r = archimedes_spiral(theta_norm);
    
    // Check if within valid spiral range (0 to 8π)
    let in_range = select(1.0, 0.0, theta_norm > 25.13274123);
    
    let dist = abs(r - spiral_r) * in_range;
    return dist;
}

// Uniform spacing property visualization
fn spiral_turn_markers(uv: vec2<f32>) -> f32 {
    let r = length(uv);
    let theta = atan2(uv.y, uv.x);
    let theta_norm = select(theta, theta + 6.28318531, theta < 0.0);
    
    // Mark each complete turn (2π spacing in θ)
    let turn_index = floor(theta_norm / 6.28318531);
    let turn_pos = turn_index * 6.28318531;
    let spacing_r = archimedes_spiral(turn_pos);
    
    let marker_dist = abs(r - spacing_r);
    return smoothstep(0.02, 0.0, marker_dist);
}

// Angle trisection construction (60° → 20°)
fn angle_trisection(uv: vec2<f32>) -> f32 {
    let r = length(uv);
    let theta = atan2(uv.y, uv.x);
    
    // Reference angle: 60° = π/3
    let ref_angle = 1.0471975;
    let trisect_angle = 0.34906585; // 20° = π/9
    
    // Construction lines for trisection
    let line_60 = abs(theta - ref_angle);
    let line_20 = abs(theta - trisect_angle);
    let line_0 = abs(theta);
    
    let construction_60 = smoothstep(0.015, 0.0, line_60);
    let construction_20 = smoothstep(0.015, 0.0, line_20);
    let construction_0 = smoothstep(0.015, 0.0, line_0);
    
    return max(max(construction_60, construction_20), construction_0);
}

// Circle squaring visualization (first turn area = πr²/3)
fn circle_squaring(uv: vec2<f32>) -> f32 {
    let r = length(uv);
    let theta = atan2(uv.y, uv.x);
    let theta_norm = select(theta, theta + 6.28318531, theta < 0.0);
    
    // First turn: θ ∈ [0, 2π]
    let in_first_turn = select(1.0, 0.0, theta_norm > 6.28318531);
    
    // Inscribed polygon approximation (show convergence)
    let polygon_sides = 6.0;
    let polygon_angle = theta_norm % (6.28318531 / polygon_sides);
    let polygon_dist = abs(polygon_angle - 3.14159265 / polygon_sides);
    
    let polygon_vis = smoothstep(0.05, 0.0, polygon_dist) * in_first_turn;
    
    return polygon_vis * 0.6;
}

// Tangent property visualization: tan(ψ) = r/a where a=1
fn tangent_property(uv: vec2<f32>) -> f32 {
    let r = length(uv);
    let theta = atan2(uv.y, uv.x);
    let theta_norm = select(theta, theta + 6.28318531, theta < 0.0);
    
    let spiral_r = archimedes_spiral(theta_norm);
    
    // Only show near the spiral
    let on_spiral = smoothstep(0.03, 0.0, abs(r - spiral_r));
    
    // Tangent angle: ψ = arctan(r) for a=1
    let tangent_angle = atan(spiral_r);
    let tangent_line_angle = theta_norm + tangent_angle;
    
    // Small tangent indicator lines
    let tangent_dist = abs(atan2(uv.y, uv.x) - tangent_line_angle);
    let tangent_vis = smoothstep(0.04, 0.0, tangent_dist);
    
    return on_spiral * tangent_vis * 0.8;
}

// Greek letter annotations (simplified)
fn greek_annotations(uv: vec2<f32>) -> vec3<f32> {
    var annotation = vec3<f32>(0.0);
    
    // Label key points with simplified Greek letters
    // θ marker near angle display
    let theta_pos = vec2<f32>(0.8, 0.8);
    let theta_dist = length(uv - theta_pos);
    annotation += vec3<f32>(0.3, 0.1, 0.5) * smoothstep(0.15, 0.1, theta_dist);
    
    // π marker for scaling
    let pi_pos = vec2<f32>(0.7, 0.2);
    let pi_dist = length(uv - pi_pos);
    annotation += vec3<f32>(0.8, 0.4, 0.1) * smoothstep(0.12, 0.08, pi_dist);
    
    return annotation;
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates [-1, 1]
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Ancient papyrus background
    let papyrus = papyrus_texture(uv * 5.0);
    let papyrus_color = vec3<f32>(0.96, 0.93, 0.82) * papyrus; // #F5E6D3
    
    // Water damage edges
    let damage = water_damage((uv + 1.0) * 0.5);
    
    // Main spiral curve - deep blue ink
    let spiral_dist = distance_to_spiral(uv);
    let spiral_line = smoothstep(0.012, 0.0, spiral_dist);
    let spiral_color = vec3<f32>(0.12, 0.2, 0.38) * spiral_line; // #1E3263
    
    // Uniform spacing markers - golden accents
    let spacing_marks = spiral_turn_markers(uv);
    let spacing_color = vec3<f32>(0.8, 0.7, 0.2) * spacing_marks;
    
    // Angle trisection construction - faded red
    let trisect = angle_trisection(uv);
    let trisect_color = vec3<f32>(0.55, 0.27, 0.08) * trisect * 0.7; // #8B4513 faded
    
    // Circle squaring visualization
    let squaring = circle_squaring(uv);
    let squaring_color = vec3<f32>(0.2, 0.4, 0.7) * squaring;
    
    // Tangent property lines
    let tangent = tangent_property(uv);
    let tangent_color = vec3<f32>(0.7, 0.3, 0.3) * tangent;
    
    // Animated spiral generation effect (7 second cycle)
    let anim_time = params.time % 7.0;
    let max_theta_anim = (anim_time / 7.0) * 25.13274123; // 8π
    let r_anim = length(uv);
    let theta_anim = atan2(uv.y, uv.x);
    let theta_anim_norm = select(theta_anim, theta_anim + 6.28318531, theta_anim < 0.0);
    
    let anim_visible = select(1.0, 0.0, theta_anim_norm > max_theta_anim);
    let spiral_generation = (1.0 - spiral_line) * anim_visible;
    
    // Greek annotations
    let annotations = greek_annotations((uv + 1.0) * 0.5);
    
    // Combine all layers
    var final_color = papyrus_color;
    final_color = mix(final_color, final_color + spiral_color, spiral_line);
    final_color = mix(final_color, final_color + spacing_color, spacing_marks * 0.6);
    final_color = mix(final_color, final_color + trisect_color, trisect * 0.8);
    final_color = mix(final_color, final_color + squaring_color, squaring * 0.5);
    final_color = mix(final_color, final_color + tangent_color, tangent * 0.6);
    final_color = mix(final_color, final_color + annotations, length(annotations) * 0.4);
    
    // Apply water damage vignette
    final_color = final_color * damage;
    
    // Add subtle glow around spiral
    let glow = exp(-spiral_dist * spiral_dist * 3.0) * 0.15;
    final_color = final_color + vec3<f32>(0.2, 0.3, 0.4) * glow;
    
    // Archimedes' portrait medallion (simplified circle in corner)
    let medallion_pos = vec2<f32>(-0.85, 0.85);
    let medallion_dist = length(uv - medallion_pos);
    let medallion = smoothstep(0.15, 0.12, medallion_dist);
    let medallion_inner = smoothstep(0.12, 0.1, medallion_dist);
    final_color = mix(final_color, vec3<f32>(0.7, 0.6, 0.4), medallion * 0.3);
    final_color = mix(final_color, vec3<f32>(0.3, 0.2, 0.1), medallion_inner * 0.5);
    
    // Clamp and return
    let clamped = clamp(final_color, vec3<f32>(0.0), vec3<f32>(1.0));
    return vec4<f32>(clamped, 1.0);
}