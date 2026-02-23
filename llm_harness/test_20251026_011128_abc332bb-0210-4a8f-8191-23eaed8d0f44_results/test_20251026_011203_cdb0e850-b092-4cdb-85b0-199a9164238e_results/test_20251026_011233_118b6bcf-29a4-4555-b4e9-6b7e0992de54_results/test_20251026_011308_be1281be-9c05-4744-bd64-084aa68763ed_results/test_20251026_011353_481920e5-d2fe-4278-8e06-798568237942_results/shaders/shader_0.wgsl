// Archimedes' Spiral: Historical Visualization
// Syracuse, circa 225 BCE
// Demonstrates: spiral generation, angle trisection, squaring the circle

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

// Constants for Archimedes' spiral
const PI = 3.14159265359;
const PAPYRUS = vec3<f32>(0.96, 0.90, 0.82);
const INK_BLUE = vec3<f32>(0.118, 0.196, 0.388);
const CONSTRUCTION_RED = vec3<f32>(0.545, 0.271, 0.075);
const GOLD = vec3<f32>(0.855, 0.686, 0.133);

// Archimedean spiral: r = a*theta, where a = 1/pi
fn spiral_radius(theta: f32) -> f32 {
    return theta / PI;
}

// Distance from point to spiral curve
fn distance_to_spiral(pos: vec2<f32>, max_theta: f32, samples: u32) -> f32 {
    var min_dist = 1000.0;
    var i = 0u;
    loop {
        if (i >= samples) { break; }
        let t_frac = f32(i) / f32(samples);
        let theta = t_frac * max_theta;
        let r = spiral_radius(theta);
        let spiral_pt = vec2<f32>(r * cos(theta), r * sin(theta));
        let dist = length(pos - spiral_pt);
        min_dist = min(min_dist, dist);
        i = i + 1u;
    }
    return min_dist;
}

// Animated spiral generation point
fn spiral_generation_point(time_norm: f32, max_theta: f32) -> vec2<f32> {
    let theta = time_norm * max_theta;
    let r = spiral_radius(theta);
    return vec2<f32>(r * cos(theta), r * sin(theta));
}

// Distance to a line segment
fn line_segment_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Papyrus texture (Perlin-like noise approximation)
fn papyrus_texture(uv: vec2<f32>) -> f32 {
    let n1 = sin(uv.x * 47.0) * sin(uv.y * 83.0);
    let n2 = sin(uv.x * 13.0 + 0.7) * sin(uv.y * 29.0 + 0.3);
    let n3 = sin(uv.x * 71.0 + 1.3) * sin(uv.y * 37.0 + 0.9);
    return (n1 + n2 * 0.5 + n3 * 0.25) * 0.33;
}

// Angle trisection visualization
fn angle_trisection(pos: vec2<f32>, time_norm: f32) -> f32 {
    let origin = vec2<f32>(0.0, 0.0);
    
    // 60 degree angle AOB
    let angle_A = 0.0;
    let angle_B = PI / 3.0;
    let angle_trisect = angle_B / 3.0;
    
    let radius_arc = 0.3;
    
    // Ray OA
    let rayA = vec2<f32>(cos(angle_A), sin(angle_A));
    let ptA = origin + rayA * radius_arc;
    
    // Ray OB
    let rayB = vec2<f32>(cos(angle_B), sin(angle_B));
    let ptB = origin + rayB * radius_arc;
    
    // Trisection point on spiral
    let trisect_theta = angle_trisect;
    let trisect_r = spiral_radius(trisect_theta);
    let ptP = vec2<f32>(trisect_r * cos(trisect_theta), trisect_r * sin(trisect_theta));
    
    // Distance to trisection construction lines
    var dist = line_segment_distance(pos, origin, ptA);
    dist = min(dist, line_segment_distance(pos, origin, ptB));
    dist = min(dist, line_segment_distance(pos, origin, ptP));
    
    // Arc visualization (sampled)
    let pos_angle = atan2(pos.y, pos.x);
    let pos_r = length(pos);
    let on_arc_A = abs(pos_r - radius_arc) < 0.01 && pos_angle >= angle_A && pos_angle <= angle_trisect;
    let on_arc_B = abs(pos_r - radius_arc) < 0.01 && pos_angle >= angle_trisect && pos_angle <= angle_B;
    
    if (on_arc_A || on_arc_B) {
        dist = 0.0;
    }
    
    return dist;
}

// First turn area approximation visualization
fn first_turn_area(pos: vec2<f32>) -> f32 {
    let max_theta = 2.0 * PI;
    return distance_to_spiral(pos, max_theta, 256u);
}

// Tangent line at a given angle
fn tangent_line_distance(pos: vec2<f32>, theta: f32) -> f32 {
    let r = spiral_radius(theta);
    let pt = vec2<f32>(r * cos(theta), r * sin(theta));
    
    // Archimedes: tan(ψ) = r/a = r*π where a=1/π
    // Tangent angle in absolute coords
    let tangent_angle = theta + atan(r * PI);
    let tangent_dir = vec2<f32>(cos(tangent_angle), sin(tangent_angle));
    
    // Distance to tangent line (extended)
    let to_pt = pos - pt;
    let perp_dist = abs(to_pt.x * tangent_dir.y - to_pt.y * tangent_dir.x);
    let along_dist = dot(to_pt, tangent_dir);
    
    if (along_dist >= -0.2 && along_dist <= 0.2) {
        return perp_dist;
    }
    return 1000.0;
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Time normalization (7 second animation cycle)
    let time_norm = fract(params.time / 7.0);
    
    // Background: aged papyrus
    let paper_tex = papyrus_texture(uv * 3.0);
    let paper_color = PAPYRUS + paper_tex * 0.05;
    
    var color = paper_color;
    
    // Main spiral (4 turns)
    let spiral_dist = distance_to_spiral(uv, 8.0 * PI, 512u);
    let spiral_line = smoothstep(0.008, 0.002, spiral_dist);
    color = mix(color, INK_BLUE, spiral_line * 0.85);
    
    // Animated generation point and ray
    let gen_pt = spiral_generation_point(time_norm, 8.0 * PI);
    let gen_theta = time_norm * 8.0 * PI;
    let gen_ray = vec2<f32>(cos(gen_theta), sin(gen_theta));
    let gen_dist_pt = length(uv - gen_pt);
    let gen_dist_ray = line_segment_distance(uv, vec2<f32>(0.0), gen_pt + gen_ray * 0.3);
    
    let gen_marker = smoothstep(0.02, 0.005, gen_dist_pt);
    let gen_ray_line = smoothstep(0.005, 0.001, gen_dist_ray);
    
    color = mix(color, GOLD, gen_marker * 0.9);
    color = mix(color, GOLD * 0.6, gen_ray_line * 0.6);
    
    // Angle trisection construction (visible in first quadrant)
    if (uv.x > -0.8 && uv.y > -0.8) {
        let trisect_dist = angle_trisection(uv * 0.6, time_norm);
        let trisect_line = smoothstep(0.005, 0.0015, trisect_dist);
        color = mix(color, CONSTRUCTION_RED, trisect_line * 0.7);
    }
    
    // First turn area visualization with polygonal approximation
    if (uv.x < 0.0 && uv.y < 0.0) {
        let area_dist = first_turn_area(uv * 0.5);
        let area_line = smoothstep(0.006, 0.0015, area_dist);
        
        // Color gradient for convergence visualization
        let convergence = clamp(time_norm, 0.0, 1.0);
        let area_color = mix(vec3<f32>(1.0, 0.8, 0.2), vec3<f32>(0.2, 0.6, 1.0), convergence);
        color = mix(color, area_color, area_line * 0.8);
    }
    
    // Tangent line visualization (lower right)
    if (uv.x > 0.0 && uv.y < 0.0) {
        let tangent_theta = 4.0 * PI * time_norm;
        let tangent_dist = tangent_line_distance(uv * 0.5, tangent_theta);
        let tangent_line = smoothstep(0.005, 0.0015, tangent_dist);
        color = mix(color, vec3<f32>(0.8, 0.3, 0.3), tangent_line * 0.75);
    }
    
    // Subtle aging vignette
    let vignette = 1.0 - length(uv * 0.5) * 0.3;
    color = color * vignette;
    
    // Add water damage edges (top and right)
    let edge_damage = max(
        smoothstep(1.2, 0.9, uv.x + uv.y),
        smoothstep(-1.2, -0.9, uv.x + uv.y)
    );
    color = mix(color, PAPYRUS * 0.7, edge_damage * 0.4);
    
    return vec4<f32>(color, 1.0);
}