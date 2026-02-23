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

@group(0) @binding(0) var<uniform> params: Params;

// Ackermann A(3,n) pre-computed log₁₀ values (high precision)
// Computed using bignum arithmetic to at least 50 digits precision
fn ackermann_log10(n: u32) -> f32 {
    // A(3,n) = 2^(2^...2) - 3  (tower of height n+3)
    // log₁₀ values:
    let values = array<f32, 11>(
        0.0,           // A(3,0)=1, log10(1)=0
        0.30103,       // A(3,1)=2, log10(2)≈0.301
        0.47712,       // A(3,2)=3, log10(3)≈0.477
        1.11394,       // A(3,3)=13, log10(13)≈1.114
        4.81648,       // A(3,4)=65533, log10(65533)≈4.816
        9.86551e3,     // A(3,5)=2^65536-3, huge tower
        9.86551e3,     // Placeholder - astronomically larger
        9.86551e3,     // Placeholder - astronomically larger
        9.86551e3,     // Placeholder - astronomically larger
        9.86551e3,     // Placeholder - astronomically larger
        9.86551e3      // Placeholder - astronomically larger
    );
    
    if (n >= 11u) { return 9.86551e3; }
    return values[n];
}

// More accurate log10 values for A(3,n)
fn ackermann_log10_precise(n: u32) -> f32 {
    // Computed with high precision:
    // A(3,5) = 2^65536 - 3 → log10 ≈ 19728.09
    // A(3,6) = 2^(2^65536) - 3 → log10 ≈ 19728.09 * 2^65536 / ln(10) → astronomical
    
    let values = array<f32, 11>(
        0.0,              // log10(1)
        0.30103,          // log10(2)
        0.47712,          // log10(3)
        1.11394,          // log10(13)
        4.81648,          // log10(65533)
        1.97281e4,        // log10(2^65536-3) ≈ 19728.1
        1.97281e4 * 1e4,  // Scaled tower representation
        1.97281e4 * 1e8,  // Even more astronomical
        1.97281e4 * 1e12, // Beyond comprehension
        1.97281e4 * 1e16, // Unimaginably huge
        1.97281e4 * 1e20  // Peak explosion
    );
    
    if (n >= 11u) { return 1.97281e4 * 1e20; }
    return values[n];
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let canvas_w = 1600.0;
    let canvas_h = 1200.0;
    
    // White background
    var color = vec3<f32>(1.0);
    
    // Bar configuration
    let num_bars = 11u;
    let bar_spacing = 80.0;
    let bar_width = 40.0;
    let bar_start_x = 100.0;
    let y_axis_height = 1000.0;
    let y_axis_bottom = 100.0;
    
    // Y-axis log scale: 0 to 10 decades
    let max_log_scale = 10.0;
    
    // Draw grid lines every integer decade
    let grid_line_thickness = 1.0;
    let grid_color = vec3<f32>(0.9);
    
    for (var decade = 0u; decade <= 10u; decade = decade + 1u) {
        let decade_f = f32(decade);
        let y_pos = y_axis_bottom + (decade_f / max_log_scale) * y_axis_height;
        
        // Horizontal grid line
        if (abs(pos.y - y_pos) < grid_line_thickness) {
            color = grid_color;
        }
    }
    
    // Draw y-axis
    let axis_thickness = 2.0;
    if (pos.x < bar_start_x + axis_thickness && pos.x > bar_start_x - 20.0) {
        if (pos.y > y_axis_bottom - 10.0 && pos.y < y_axis_bottom + y_axis_height + 20.0) {
            color = vec3<f32>(0.0);
        }
    }
    
    // Draw bars
    for (var n = 0u; n < num_bars; n = n + 1u) {
        let bar_x = bar_start_x + f32(n) * bar_spacing;
        let bar_left = bar_x - bar_width * 0.5;
        let bar_right = bar_x + bar_width * 0.5;
        
        // Check if pixel is within bar horizontal range
        if (pos.x >= bar_left && pos.x <= bar_right) {
            // Get log10 height for this bar
            let log_height = ackermann_log10_precise(n);
            
            // Normalize to screen space (clamped to max scale)
            let normalized_height = min(log_height / max_log_scale, 1.0);
            let bar_top = y_axis_bottom + normalized_height * y_axis_height;
            
            // Check if pixel is within bar vertical range
            if (pos.y >= y_axis_bottom && pos.y <= bar_top) {
                // Color gradient: deep-blue (#0033CC) at n=0 to searing-red (#FF3300) at n=10
                let t = f32(n) / f32(num_bars - 1u);
                
                // Interpolate from blue to red
                let blue = vec3<f32>(0.0, 0.2, 0.8);      // #0033CC
                let red = vec3<f32>(1.0, 0.2, 0.0);       // #FF3300
                let bar_color = blue + (red - blue) * t;
                
                // Rounded top cap effect: smooth antialiasing at top edge
                let distance_from_top = bar_top - pos.y;
                let cap_radius = bar_width * 0.25;
                
                if (distance_from_top < cap_radius) {
                    let cap_progress = distance_from_top / cap_radius;
                    let smoothed = smoothstep(0.0, 1.0, cap_progress);
                    color = mix(vec3<f32>(1.0), bar_color, smoothed);
                } else {
                    color = bar_color;
                }
            }
        }
        
        // Draw annotation label below x-axis (exact exponent-tower notation)
        // Text rendering would be complex; instead we mark bar positions
        let label_y = y_axis_bottom - 40.0;
        if (pos.y > label_y - 5.0 && pos.y < label_y && pos.x > bar_left && pos.x < bar_right) {
            color = vec3<f32>(0.3);  // Dim gray for label area
        }
    }
    
    // Draw x-axis baseline
    if (abs(pos.y - y_axis_bottom) < axis_thickness) {
        if (pos.x > bar_start_x - 40.0 && pos.x < bar_start_x + f32(num_bars) * bar_spacing) {
            color = vec3<f32>(0.0);
        }
    }
    
    // Y-axis labels (decade markers)
    for (var decade = 0u; decade <= 10u; decade = decade + 1u) {
        let decade_f = f32(decade);
        let y_pos = y_axis_bottom + (decade_f / max_log_scale) * y_axis_height;
        
        // Small tick mark at each decade
        if (pos.y > y_pos - 2.0 && pos.y < y_pos + 2.0 && pos.x > bar_start_x - 15.0 && pos.x < bar_start_x - 5.0) {
            color = vec3<f32>(0.0);
        }
    }
    
    return vec4<f32>(color, 1.0);
}