// Conformal Spiral Mapping Visualization
// Maps rectangular grid via w = exp(α·z) where α = 0.2 + 0.3i
// Visualizes logarithmic spirals and radial rays with conformal geometry

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

// Complex number multiplication: (a + bi)(c + di)
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Complex exponential: exp(a + bi) = exp(a) * (cos(b) + i*sin(b))
fn cexp(z: vec2<f32>) -> vec2<f32> {
    let exp_a = exp(z.x);
    return vec2<f32>(exp_a * cos(z.y), exp_a * sin(z.y));
}

// Conformal spiral transformation: w = exp(α·z) where α = 0.2 + 0.3i
fn conformal_spiral(z: vec2<f32>) -> vec2<f32> {
    let alpha = vec2<f32>(0.2, 0.3);
    let alpha_z = cmul(alpha, z);
    return cexp(alpha_z);
}

// Height function: h(w) = 0.5 * log(1 + |w|)
fn height_func(w: vec2<f32>) -> f32 {
    let mag = length(w);
    return 0.5 * log(1.0 + mag);
}

// Distance to grid line (tube rendering)
fn distance_to_grid_line(pos: vec2<f32>, grid_pos: vec2<f32>, grid_spacing: f32) -> f32 {
    let grid_dist = abs(pos - grid_pos);
    return min(grid_dist.x, grid_dist.y) - grid_spacing * 0.05;
}

// Signed distance field to nearest grid line in original space
fn grid_distance(z: vec2<f32>) -> f32 {
    let spacing = 0.1;
    let grid_x = abs(z.x - round(z.x / spacing) * spacing);
    let grid_y = abs(z.y - round(z.y / spacing) * spacing);
    let min_dist = min(grid_x, grid_y);
    return min_dist - 0.008;
}

// Color based on grid line type (vertical=blue-cyan, horizontal=red-orange)
fn grid_color(z: vec2<f32>) -> vec3<f32> {
    let spacing = 0.1;
    let grid_x = abs(z.x - round(z.x / spacing) * spacing);
    let grid_y = abs(z.y - round(z.y / spacing) * spacing);
    
    let is_vertical = select(false, true, grid_x < grid_y);
    
    let vertical_color = mix(
        vec3<f32>(0.0, 0.3, 0.8),
        vec3<f32>(0.0, 0.9, 1.0),
        length(z) / 4.0
    );
    
    let horizontal_color = mix(
        vec3<f32>(0.9, 0.2, 0.0),
        vec3<f32>(1.0, 0.6, 0.0),
        length(z) / 4.0
    );
    
    return select(horizontal_color, vertical_color, is_vertical);
}

// Radial gradient background
fn background_color(uv: vec2<f32>) -> vec3<f32> {
    let center = vec2<f32>(0.5, 0.5);
    let dist = length(uv - center);
    let dark = vec3<f32>(0.05, 0.05, 0.08);
    let slightly_less_dark = vec3<f32>(0.1, 0.1, 0.15);
    return mix(dark, slightly_less_dark, smoothstep(0.0, 1.0, dist * 0.5));
}

// Caustic lighting effect based on spiral structure
fn caustic_light(w: vec2<f32>, h: f32) -> f32 {
    let angle = atan2(w.y, w.x);
    let radius = length(w);
    
    let caustic = sin(angle * 8.0 + radius * 6.0) * 0.5 + 0.5;
    let height_modulation = 1.0 - h * 0.3;
    
    return caustic * height_modulation;
}

// Central singularity glow
fn singularity_glow(w: vec2<f32>) -> f32 {
    let dist_to_center = length(w);
    let glow = exp(-dist_to_center * 4.0);
    return glow * 0.8;
}

// Height-based fog
fn fog_effect(h: f32) -> f32 {
    return exp(-h * h * 0.5);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    let z = uv * 2.0;
    
    let w = conformal_spiral(z);
    let h = height_func(w);
    
    let grid_dist = grid_distance(z);
    let tube_alpha = 1.0 - smoothstep(-0.002, 0.002, grid_dist);
    let grid_col = grid_color(z);
    
    let caustic = caustic_light(w, h);
    let lit_grid = grid_col * caustic;
    
    let glow = singularity_glow(w);
    let singularity_col = mix(lit_grid, vec3<f32>(1.0, 1.0, 1.0), glow);
    
    let bg = background_color(pos.xy / params.resolution);
    let final_col = mix(bg, singularity_col, tube_alpha);
    
    let fog = fog_effect(h);
    let foggy_col = mix(final_col, bg, 1.0 - fog);
    
    let saturated = mix(vec3<f32>(dot(foggy_col, vec3<f32>(0.299, 0.587, 0.114))), foggy_col, 1.2);
    let contrast = mix(vec3<f32>(0.5, 0.5, 0.5), saturated, 1.1);
    
    return vec4<f32>(clamp(contrast, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}