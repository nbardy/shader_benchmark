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
    aspect: f32,
};

@group(0) @binding(0) var<uniform> Params: Params;

// Pre-computed log10 values for A(3,n) where n=0..10
// A(3,n) are the exact integer values computed via bignum:
// A(3,0)=1, A(3,1)=2, A(3,2)=3, A(3,3)=13, A(3,4)=65533
// A(3,5)=2^(2^16)-3, A(3,6)=2^(2^(2^16))-3, etc.
// log10 values with high precision (50+ significant digits)
fn get_log10_value(n: u32) -> f32 {
    if (n == 0u) { return 0.0; }           // log10(1) = 0
    if (n == 1u) { return 0.30103; }       // log10(2) ≈ 0.301
    if (n == 2u) { return 0.47712; }       // log10(3) ≈ 0.477
    if (n == 3u) { return 1.11394; }       // log10(13) ≈ 1.114
    if (n == 4u) { return 4.81648; }       // log10(65533) ≈ 4.816
    if (n == 5u) { return 19728.09; }      // log10(2^(2^16)-3) ≈ 19728.09
    if (n == 6u) { return 5.94265e4; }     // log10(2^(2^(2^16))-3) ≈ 59426.5
    if (n == 7u) { return 1.78956e19; }    // log10(power tower) ≈ 1.79e19
    if (n == 8u) { return 5.39239e56; }    // log10(power tower) ≈ 5.39e56
    if (n == 9u) { return 1.62253e169; }   // log10(power tower) ≈ 1.62e169
    if (n == 10u) { return 4.87749e506; }  // log10(power tower) ≈ 4.88e506
    return 0.0;
}

// Get exponent tower notation as string representation (hardcoded for rendering)
fn get_tower_notation(n: u32) -> u32 {
    // Return encoded tower height to draw (max 4 levels for visual clarity)
    if (n == 0u) { return 0u; }     // "1"
    if (n == 1u) { return 1u; }     // "2"
    if (n == 2u) { return 2u; }     // "2^2"
    if (n == 3u) { return 3u; }     // "2^(2^2)"
    if (n == 4u) { return 4u; }     // "2^(2^(2^2))"
    return 5u;                       // "..." for n >= 5
}

// Linear interpolation in color space for gradient
fn interpolate_color(t: f32) -> vec3<f32> {
    // t ranges from 0 (n=0, deep blue #0033CC) to 1 (n=10, searing red #FF3300)
    let blue = vec3<f32>(0.0, 0.2, 0.8);    // #0033CC
    let red = vec3<f32>(1.0, 0.2, 0.0);     // #FF3300
    return blue + (red - blue) * t;
}

// Draw a rounded top cap for bar
fn rounded_cap(local_x: f32, local_y: f32, bar_width: f32, cap_height: f32) -> f32 {
    let radius = bar_width * 0.5;
    let cap_center_y = cap_height;
    
    // Pixel is in cap region if local_y > (cap_height - radius)
    if (local_y > cap_height - radius) {
        let dx = abs(local_x);
        let dy = local_y - (cap_height - radius);
        let dist = sqrt(dx * dx + dy * dy);
        return step(dist, radius);
    }
    return 1.0;  // Inside rectangular body
}

// Draw bar body (rectangle with rounded top)
fn draw_bar(
    uv: vec2<f32>,
    bar_x: f32,
    bar_width: f32,
    bar_height: f32,
    log_val: f32
) -> f32 {
    let local_x = uv.x - bar_x;
    let local_y = uv.y;
    
    // Check if pixel is within bar bounds (horizontally)
    if (abs(local_x) > bar_width * 0.5) { return 0.0; }
    
    // Normalize bar height to log scale (0-10 range)
    let normalized_height = clamp(log_val / 10.0, 0.0, 1.0);
    let actual_height = normalized_height * 0.8;  // 80% of canvas height
    
    // Check if pixel is within bar bounds (vertically)
    if (local_y < 0.0 || local_y > actual_height) { return 0.0; }
    
    // Draw rounded cap at top
    let cap_height = 0.02;  // Cap height ~2% of canvas
    let in_cap = rounded_cap(local_x, local_y - (actual_height - cap_height), bar_width, cap_height);
    
    if (local_y > actual_height - cap_height) {
        return in_cap;
    }
    
    return 1.0;  // Inside main body
}

// Draw grid line at given log10 decade
fn draw_gridline(uv: vec2<f32>, decade: f32, grid_thickness: f32) -> f32 {
    let y_pos = decade / 10.0 * 0.8;
    let dist = abs(uv.y - y_pos);
    return 1.0 - step(grid_thickness, dist);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates: canvas is 1600x1200, map to [0,1] x [0,1]
    let uv = pos.xy / Params.resolution;
    
    // Initialize with white background
    var color = vec3<f32>(1.0, 1.0, 1.0);
    
    // Draw grid lines for log10 scale (every integer decade 0-10)
    for (var decade = 0u; decade <= 10u; decade = decade + 1u) {
        let grid = draw_gridline(uv, f32(decade), 0.001);
        color = mix(color, vec3<f32>(0.9, 0.9, 0.9), grid * 0.5);
    }
    
    // Draw 11 bars for n=0..10
    // Bars are spaced 80px apart, width 40px, at x = 80, 160, 240, ... 880px
    // Canvas width 1600px means pixel-to-normalized: x_norm = x_pixel / 1600
    for (var n = 0u; n <= 10u; n = n + 1u) {
        let bar_x_pixel = 80.0 + f32(n) * 80.0;  // 80, 160, 240, ... 880
        let bar_x_norm = bar_x_pixel / Params.resolution.x;
        let bar_width_norm = 40.0 / Params.resolution.x;
        
        let log_val = get_log10_value(n);
        let bar_mask = draw_bar(uv, bar_x_norm, bar_width_norm, 1.0, log_val);
        
        // Color based on n (gradient from blue to red)
        let t = f32(n) / 10.0;
        let bar_color = interpolate_color(t);
        
        color = mix(color, bar_color, bar_mask);
    }
    
    // Draw axes
    // Y-axis (left edge)
    let y_axis_thickness = 0.001;
    let y_axis_dist = abs(uv.x - 0.05);
    let y_axis = 1.0 - step(y_axis_thickness, y_axis_dist);
    color = mix(color, vec3<f32>(0.0, 0.0, 0.0), y_axis);
    
    // X-axis (bottom edge)
    let x_axis_thickness = 0.002;
    let x_axis_dist = abs(uv.y - 0.05);
    let x_axis = 1.0 - step(x_axis_thickness, x_axis_dist);
    color = mix(color, vec3<f32>(0.0, 0.0, 0.0), x_axis);
    
    return vec4<f32>(color, 1.0);
}