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

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Canvas: 1600 x 1200, white background
    let canvas_width = 1600.0;
    let canvas_height = 1200.0;
    let bg_white = vec3<f32>(1.0, 1.0, 1.0);
    
    // Normalize coordinates to canvas space
    let canvas_pos = pos.xy;
    
    // Bar parameters
    let bar_count = 11u;
    let bar_spacing = 80.0;
    let bar_width = 40.0;
    let start_x = 80.0;
    
    // Log₁₀ scale: 0 to 10 (representing 10^0 to 10^10)
    let log_scale_min = 0.0;
    let log_scale_max = 10.0;
    
    // Canvas height available for plot (leave margin at bottom)
    let plot_height = 1000.0;
    let plot_bottom = 150.0;
    let plot_top = 150.0 + plot_height;
    
    // Pre-computed log₁₀ values for A(3,n) where n=0..10
    // A(3,0)=1 → log₁₀(1)=0
    // A(3,1)=2 → log₁₀(2)≈0.301
    // A(3,2)=3 → log₁₀(3)≈0.477
    // A(3,3)=13 → log₁₀(13)≈1.114
    // A(3,4)=65533 → log₁₀(65533)≈4.816
    // A(3,5)=2^65536-3 → log₁₀≈19728.09 (clamped to 10)
    // A(3,6) onwards: even more extreme, all clamped to 10
    
    let log_values = array<f32, 11>(
        0.0,      // A(3,0) = 1
        0.301,    // A(3,1) = 2
        0.477,    // A(3,2) = 3
        1.114,    // A(3,3) = 13
        4.816,    // A(3,4) = 65533
        10.0,     // A(3,5): 2^65536-3, towers explode
        10.0,     // A(3,6): 2^(2^65536)-3
        10.0,     // A(3,7)
        10.0,     // A(3,8)
        10.0,     // A(3,9)
        10.0      // A(3,10)
    );
    
    // Determine which bar (if any) the fragment is in
    var bar_index = 999u;
    var in_bar = false;
    var bar_x_min = 0.0;
    var bar_x_max = 0.0;
    var bar_log_height = 0.0;
    
    for (var i = 0u; i < bar_count; i = i + 1u) {
        let x_pos = start_x + f32(i) * bar_spacing;
        let x_min = x_pos - bar_width * 0.5;
        let x_max = x_pos + bar_width * 0.5;
        
        if (canvas_pos.x >= x_min && canvas_pos.x < x_max) {
            bar_index = i;
            bar_x_min = x_min;
            bar_x_max = x_max;
            bar_log_height = log_values[i];
            in_bar = true;
            break;
        }
    }
    
    // Grid line region (below plot area) + axis labels
    let in_grid_region = (canvas_pos.y < plot_bottom);
    
    // Determine final color
    var final_color = bg_white;
    
    if (in_bar) {
        // We're inside a bar's horizontal span
        // Calculate bar height in pixels based on log scale
        let normalized_height = bar_log_height / log_scale_max;
        let bar_height_px = normalized_height * plot_height;
        let bar_top_y = plot_bottom + bar_height_px;
        
        if (canvas_pos.y >= plot_bottom && canvas_pos.y < bar_top_y) {
            // Inside the bar fill region
            // Color gradient: deep blue (n=0) to searing red (n=10)
            let t = f32(bar_index) / 10.0;
            let blue = vec3<f32>(0.0, 0.2, 0.8);    // #0033CC normalized
            let red = vec3<f32>(1.0, 0.2, 0.0);     // #FF3300 normalized
            let bar_color = mix(blue, red, t);
            
            // Apply slight rounding to top cap
            let dist_from_top = bar_top_y - canvas_pos.y;
            let cap_radius = 4.0;
            
            if (dist_from_top < cap_radius) {
                let circle_center_x = start_x + f32(bar_index) * bar_spacing;
                let circle_center_y = bar_top_y;
                let dist_to_center = distance(canvas_pos, vec2<f32>(circle_center_x, circle_center_y));
                
                if (dist_to_center < cap_radius) {
                    final_color = bar_color;
                } else {
                    final_color = bg_white;
                }
            } else {
                final_color = bar_color;
            }
        }
    }
    
    // Draw grid lines (horizontal lines at each decade)
    let grid_line_thickness = 1.0;
    for (var decade = 0i; decade <= 10i; decade = decade + 1i) {
        let decade_y = plot_bottom + (f32(decade) / log_scale_max) * plot_height;
        if (abs(canvas_pos.y - decade_y) < grid_line_thickness * 0.5) {
            final_color = vec3<f32>(0.8, 0.8, 0.8);
        }
    }
    
    // Draw y-axis (left edge of plot)
    let axis_x = start_x - bar_spacing * 0.5;
    let axis_thickness = 2.0;
    if (abs(canvas_pos.x - axis_x) < axis_thickness && 
        canvas_pos.y >= plot_bottom && canvas_pos.y < plot_top) {
        final_color = vec3<f32>(0.0, 0.0, 0.0);
    }
    
    // Draw x-axis (bottom edge of plot)
    if (abs(canvas_pos.y - plot_bottom) < axis_thickness &&
        canvas_pos.x >= axis_x && canvas_pos.x < start_x + f32(bar_count - 1u) * bar_spacing + bar_spacing * 0.5) {
        final_color = vec3<f32>(0.0, 0.0, 0.0);
    }
    
    return vec4<f32>(final_color, 1.0);
}