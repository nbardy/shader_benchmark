// Parametric Gear Train - WGSL Implementation
// Generates animated interlocking gears with involute tooth profiles

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
};

@group(0) @binding(0) var<uniform> params: Params;

// Constants
const PI = 3.14159265359;
const TAU = 6.28318530718;
const TOOTH_COUNT_1 = 20u;
const TOOTH_COUNT_2 = 40u;
const TOOTH_COUNT_3 = 30u;
const TOOTH_COUNT_4 = 50u;

// Involute curve parameterization
fn involute_point(angle: f32, base_radius: f32, t: f32) -> vec2<f32> {
    let theta = angle + t;
    let x = base_radius * (cos(theta) + theta * sin(theta));
    let y = base_radius * (sin(theta) - theta * cos(theta));
    return vec2<f32>(x, y);
}

// Generate tooth profile using involute curves
fn tooth_profile(angle: f32, tooth_idx: f32, tooth_count: f32, pressure_angle: f32) -> f32 {
    let tooth_pitch = TAU / tooth_count;
    let local_angle = angle % tooth_pitch;
    let normalized = (local_angle - tooth_pitch * 0.5) / (tooth_pitch * 0.5);
    
    // Tooth width varies smoothly
    let tooth_width = 0.35 * cos(normalized * PI * 0.5);
    let involute_factor = abs(normalized) * 0.3;
    
    return tooth_width - involute_factor;
}

// Distance to gear boundary
fn gear_distance(pos: vec2<f32>, center: vec2<f32>, base_radius: f32, tooth_count: f32, time: f32, rotation: f32) -> f32 {
    let rel_pos = pos - center;
    let dist = length(rel_pos);
    let angle = atan2(rel_pos.y, rel_pos.x);
    let rotated_angle = angle - time * rotation;
    
    // Radial modulation for teeth
    let tooth_factor = tooth_profile(rotated_angle, 0.0, tooth_count, 0.2);
    let modulated_radius = base_radius * (1.0 + tooth_factor * 0.15);
    
    return abs(dist - modulated_radius);
}

// Gear mesh material shader
fn gear_material(distance: f32, normal_dir: vec2<f32>, depth: f32, wear: f32) -> vec3<f32> {
    // Brushed metal base
    let base_color = vec3<f32>(0.7, 0.7, 0.75);
    
    // Metallic reflection based on distance
    let reflection = exp(-distance * distance * 50.0) * 0.3;
    
    // Directional brushed effect
    let brush = abs(sin(normal_dir.x * 20.0)) * 0.1;
    
    // Wear marks from friction
    let wear_pattern = sin(normal_dir.y * 15.0) * wear * 0.15;
    let wear_color = vec3<f32>(0.4, 0.35, 0.3);
    
    let metal = base_color + reflection + brush;
    let worn = mix(metal, wear_color, wear_pattern);
    
    // Depth shadowing
    let shadow = exp(-depth * 3.0) * 0.2;
    
    return worn - shadow;
}

// Main gear rendering function
fn render_gear(pos: vec2<f32>, gear_idx: u32, time: f32) -> vec4<f32> {
    // Gear parameters: center, radius, tooth count, rotation speed
    var center = vec2<f32>(0.0);
    var base_radius = 0.15;
    var tooth_count = 20.0;
    var rotation_speed = 1.0;
    
    if (gear_idx == 0u) {
        // Gear 1: Driver (20 teeth)
        center = vec2<f32>(-0.35, 0.0);
        base_radius = 0.15;
        tooth_count = f32(TOOTH_COUNT_1);
        rotation_speed = 2.0;
    } else if (gear_idx == 1u) {
        // Gear 2: Driven (40 teeth) - half speed
        center = vec2<f32>(0.25, 0.0);
        base_radius = 0.30;
        tooth_count = f32(TOOTH_COUNT_2);
        rotation_speed = 1.0;
    } else if (gear_idx == 2u) {
        // Gear 3: Compound (30 teeth)
        center = vec2<f32>(0.0, 0.35);
        base_radius = 0.22;
        tooth_count = f32(TOOTH_COUNT_3);
        rotation_speed = 1.33;
    } else {
        // Gear 4: Final (50 teeth) - slow
        center = vec2<f32>(0.0, -0.4);
        base_radius = 0.38;
        tooth_count = f32(TOOTH_COUNT_4);
        rotation_speed = 0.8;
    }
    
    let dist = gear_distance(pos, center, base_radius, tooth_count, time, rotation_speed);
    let rel = pos - center;
    let normal = normalize(rel);
    let depth = length(rel) / base_radius;
    
    // Wear increases with rotation
    let wear = (0.3 + 0.2 * sin(time * rotation_speed * 0.5)) * 0.5;
    
    let is_tooth = dist < 0.02;
    let tooth_edge = smoothstep(0.025, 0.015, dist);
    
    if (!is_tooth && dist > 0.05) {
        return vec4<f32>(0.0, 0.0, 0.0, 0.0);
    }
    
    let material = gear_material(dist, normal, depth, wear);
    
    // Highlight on teeth edges
    let highlight = exp(-dist * 200.0) * 0.5 * tooth_edge;
    let final_color = material + highlight;
    
    return vec4<f32>(final_color, 1.0);
}

// Motion blur effect
fn motion_blur(pos: vec2<f32>, gear_idx: u32, time: f32) -> vec4<f32> {
    var color = vec4<f32>(0.0);
    let samples = 3u;
    
    for (var i = 0u; i < samples; i = i + 1u) {
        let offset = f32(i) / f32(samples) - 0.5;
        let blurred_time = time + offset * 0.01;
        let sample_color = render_gear(pos, gear_idx, blurred_time);
        color = color + sample_color * (1.0 / f32(samples));
    }
    
    return color;
}

// Industrial background
fn render_background(uv: vec2<f32>) -> vec3<f32> {
    // Grid pattern
    let grid_x = step(0.45, fract(uv.x * 8.0));
    let grid_y = step(0.45, fract(uv.y * 8.0));
    let grid = grid_x * grid_y * 0.1;
    
    // Radial vignette
    let center_dist = length(uv - vec2<f32>(0.5));
    let vignette = 1.0 - center_dist * 0.8;
    
    let base = vec3<f32>(0.1, 0.1, 0.12);
    let grid_color = vec3<f32>(0.2, 0.25, 0.3) * grid;
    
    return mix(base, grid_color, 0.5) * vignette;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    let screen_pos = (uv - vec2<f32>(0.5)) * vec2<f32>(aspect, 1.0);
    
    // Render background
    var final_color = render_background(uv);
    
    // Render all gears with motion blur
    for (var gear_idx = 0u; gear_idx < 4u; gear_idx = gear_idx + 1u) {
        let gear_color = motion_blur(screen_pos, gear_idx, params.time);
        final_color = mix(final_color, gear_color.rgb, gear_color.a);
    }
    
    // Overlay text indicator (simulated with patterns)
    let text_y = 0.9;
    let text_region = smoothstep(0.02, 0.0, abs(uv.y - text_y));
    let rpm_indicator = vec3<f32>(1.0, 0.8, 0.2) * text_region * 0.3;
    final_color = final_color + rpm_indicator;
    
    // Center crosshair for gear alignment reference
    let crosshair_x = smoothstep(0.002, 0.0, abs(uv.x - 0.5));
    let crosshair_y = smoothstep(0.002, 0.0, abs(uv.y - 0.5));
    let crosshair = (crosshair_x + crosshair_y) * 0.1;
    final_color = final_color + crosshair * vec3<f32>(0.5, 0.5, 0.5);
    
    return vec4<f32>(final_color, 1.0);
}