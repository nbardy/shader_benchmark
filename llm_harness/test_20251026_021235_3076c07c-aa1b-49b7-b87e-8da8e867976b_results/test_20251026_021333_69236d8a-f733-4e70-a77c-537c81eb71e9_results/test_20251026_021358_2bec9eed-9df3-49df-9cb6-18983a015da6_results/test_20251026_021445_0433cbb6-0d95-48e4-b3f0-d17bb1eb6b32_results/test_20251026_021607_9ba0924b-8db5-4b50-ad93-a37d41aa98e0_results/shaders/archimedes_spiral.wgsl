// Archimedes' Spiral - Historical Visualization
// Syracuse, c. 225 BCE
// r = θ/π for θ ∈ [0, 8π]

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
    _pad: f32,
}

@group(0) @binding(0) var<uniform> params: Params;

// Constants
const PI = 3.14159265359;
const TAU = 6.28318530718;
const PAPYRUS = vec3<f32>(0.96, 0.91, 0.83);
const INK_BLUE = vec3<f32>(0.12, 0.20, 0.39);
const FADED_RED = vec3<f32>(0.55, 0.27, 0.07);
const GOLD = vec3<f32>(0.85, 0.75, 0.30);

// Archimedes spiral: r = a*theta where a = 1/PI
fn archimedes_radius(theta: f32) -> f32 {
    return theta / PI;
}

// Distance from point to line segment
fn distance_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / (dot(ba, ba) + 0.0001), 0.0, 1.0);
    return length(pa - ba * h);
}

// Smooth step with antialiasing
fn line_stroke(dist: f32, width: f32) -> f32 {
    return smoothstep(width + 0.002, width - 0.002, dist);
}

// Draw a point with cross-hair
fn draw_point(uv: vec2<f32>, center: vec2<f32>, radius_px: f32) -> f32 {
    let dist = length(uv - center);
    let circle = smoothstep(radius_px + 0.002, radius_px - 0.002, dist);
    let cross_h = line_stroke(abs(uv.y - center.y), 0.001);
    let cross_v = line_stroke(abs(uv.x - center.x), 0.001);
    let crosshair = step(0.001, abs(uv.x - center.x) - 0.01) * step(0.001, abs(uv.y - center.y) - 0.01) * (cross_h + cross_v);
    return max(circle, crosshair);
}

// Papyrus texture overlay
fn papyrus_texture(uv: vec2<f32>) -> f32 {
    let noise = sin(uv.x * 50.0) * sin(uv.y * 50.0) * sin(uv.x * uv.y * 20.0);
    let water_damage = smoothstep(0.95, 0.85, length(uv - vec2<f32>(0.5, 0.5)));
    return 0.98 + noise * 0.01 + water_damage * 0.02;
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Normalize to [-1, 1] centered coordinate system
    let coord = (uv - vec2<f32>(0.5, 0.5)) * 2.0;
    let coord_aspect = vec2<f32>(coord.x * aspect, coord.y);
    
    // Convert to polar coordinates
    let r_dist = length(coord_aspect);
    let theta = atan2(coord_aspect.y, coord_aspect.x);
    
    // Normalize theta to [0, 8π]
    var theta_norm = theta;
    if (theta_norm < 0.0) {
        theta_norm = theta_norm + TAU;
    }
    
    // Background: aged papyrus
    var color = PAPYRUS;
    let texture_factor = papyrus_texture(uv);
    color = color * texture_factor;
    
    // Animation parameter: spiral generation
    let anim_phase = params.time * 0.3; // ~7 second cycle at 60fps
    let max_theta = clamp(anim_phase * 3.0, 0.0, 8.0 * PI);
    
    // Draw Archimedes' spiral (4 complete turns)
    let spiral_width = 0.003;
    var spiral_alpha = 0.0;
    
    if (theta_norm <= max_theta) {
        let r_spiral = archimedes_radius(theta_norm);
        let dist_to_spiral = abs(r_dist - r_spiral);
        spiral_alpha = line_stroke(dist_to_spiral, spiral_width);
    }
    
    // Highlight current spiral point (animating outward)
    let current_theta = (anim_phase % 8.0 * PI);
    let current_r = archimedes_radius(current_theta);
    let current_point = vec2<f32>(
        current_r * cos(current_theta) / aspect,
        current_r * sin(current_theta)
    );
    let point_highlight = draw_point(coord_aspect, current_point, 0.015);
    
    // Angle Trisection Construction (60° angle)
    let trisection_alpha = step(max_theta, PI * 4.0);
    
    // Reference angle: 60° = π/3 radians
    let ref_angle = PI / 3.0;
    let ref_ray_angle = ref_angle / 2.0;
    
    // Ray from origin at 30° (half of 60°)
    let ray_dir = vec2<f32>(cos(ref_ray_angle), sin(ref_ray_angle));
    
    // Construction ray (red dashed)
    let ray_t = clamp(dot(coord_aspect, ray_dir) / length(ray_dir), 0.0, 0.4);
    let ray_point = ray_dir * ray_t;
    let dist_to_ray = distance_to_segment(coord_aspect, vec2<f32>(0.0, 0.0), ray_point);
    var ray_alpha = line_stroke(dist_to_ray, 0.002) * trisection_alpha;
    
    // Dashing pattern
    let dash_phase = (ray_t * 30.0 % 0.2);
    ray_alpha = ray_alpha * step(dash_phase, 0.1);
    
    // Trisection point P: where OP = (1/3)OC on spiral
    let c_r = archimedes_radius(ref_angle);
    let p_r = c_r / 3.0;
    let p_theta = ref_angle / 3.0;
    let p_point = vec2<f32>(
        p_r * cos(p_theta) / aspect,
        p_r * sin(p_theta)
    );
    let trisection_point = draw_point(coord_aspect, p_point, 0.012) * trisection_alpha;
    
    // First turn area visualization (exhaustion method)
    let first_turn_alpha = step(max_theta, 2.0 * PI);
    
    // Polygon approximations visualization
    let first_turn_r = archimedes_radius(2.0 * PI) / 2.0;
    let dist_to_polygon = abs(r_dist - first_turn_r);
    let poly_outline = line_stroke(dist_to_polygon, 0.004);
    
    // Grid for exhaustion visualization
    let grid_intensity = 0.15;
    let grid_lines = abs(sin(coord_aspect.x * 8.0)) + abs(sin(coord_aspect.y * 8.0));
    let grid = step(0.98, grid_lines) * grid_intensity * first_turn_alpha;
    
    // Tangent line visualization (at current point)
    let tangent_alpha = step(max_theta, 4.0 * PI);
    
    // Archimedes' result: tan(ψ) = r/a, where a = 1/π
    let psi = atan(current_r * PI);
    let tangent_angle = current_theta + psi;
    let tangent_dir = vec2<f32>(cos(tangent_angle), sin(tangent_angle));
    
    // Draw tangent line
    let dist_to_tangent = distance_to_segment(
        coord_aspect,
        current_point - tangent_dir * 0.2,
        current_point + tangent_dir * 0.2
    );
    let tangent_stroke = line_stroke(dist_to_tangent, 0.002) * tangent_alpha;
    
    // Origin point and radial guide
    let origin_point = draw_point(coord_aspect, vec2<f32>(0.0, 0.0), 0.008);
    let radial_guide = line_stroke(abs(length(coord_aspect) - current_r), 0.0015);
    
    // Combine all elements
    var final_color = color;
    
    // Layer spiral
    final_color = mix(final_color, INK_BLUE, spiral_alpha * 0.9);
    
    // Layer construction elements
    final_color = mix(final_color, FADED_RED, ray_alpha * 0.7);
    final_color = mix(final_color, GOLD, trisection_point * 0.8);
    final_color = mix(final_color, FADED_RED, poly_outline * 0.5 * first_turn_alpha);
    final_color = mix(final_color, vec3<f32>(0.8, 0.7, 0.6), grid);
    
    // Layer current animation elements
    final_color = mix(final_color, GOLD, point_highlight * 0.9);
    final_color = mix(final_color, vec3<f32>(0.9, 0.8, 0.4), radial_guide * 0.6);
    final_color = mix(final_color, vec3<f32>(0.7, 0.6, 0.5), tangent_stroke * 0.7);
    final_color = mix(final_color, GOLD, origin_point * 0.9);
    
    // Edge vignette (water damage effect)
    let edge_dist = max(abs(coord.x), abs(coord.y));
    let vignette = smoothstep(1.05, 0.85, edge_dist);
    final_color = final_color * vignette + vec3<f32>(0.92, 0.88, 0.80) * (1.0 - vignette);
    
    return vec4<f32>(final_color, 1.0);
}