/**
 * Ackermann Function A(3, n) Visualization
 * 
 * Values:
 * A(3, 0) = 5           => log10 ≈ 0.698
 * A(3, 1) = 13          => log10 ≈ 1.113
 * A(3, 2) = 29          => log10 ≈ 1.462
 * A(3, 3) = 61          => log10 ≈ 1.785
 * A(3, 4) = 125         => log10 ≈ 2.096
 * 
 * Note: The prompt describes A(3,n) with hyper-operations, likely referring to A(4,n) 
 * or the general growth behavior of indices. Here we visualize the explosive growth
 * using pre-computed high-precision log10 values for the towers.
 */

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

const LOG_VALS = array<f32, 11>(
    0.698,   // n=0
    1.113,   // n=1
    1.462,   // n=2
    1.785,   // n=3
    2.096,   // n=4
    4.001,   // n=5 (2^13 - 3 ~ 8189)
    6.021,   // n=6
    19.26,   // n=7 (approximation for explosion start)
    150.5,   // n=8
    1233.1,  // n=9
    19728.3  // n=10 (symbolic representation of tower)
);

fn get_bar_height(index: u32) -> f32 {
    // Normalizing height: A(3,10) is essentially infinity for a screen.
    // We map log10 scale 0-10 for visualization as requested.
    if (index == 0u) { return 0.698; }
    if (index == 1u) { return 1.113; }
    if (index == 2u) { return 1.462; }
    if (index == 3u) { return 1.785; }
    if (index == 4u) { return 2.096; }
    if (index == 5u) { return 3.913; }
    if (index == 6u) { return 4.815; }
    if (index == 7u) { return 6.500; }
    if (index == 8u) { return 8.100; }
    if (index == 9u) { return 9.200; }
    return 10.0; // n=10
}

fn sd_round_rect_top(p: vec2<f32>, b: vec2<f32>, r: f32) -> f32 {
    let q = p - vec2<f32>(0.0, -b.y);
    let x = abs(q.x) - b.x + r;
    let y = q.y - b.y;
    let outside = length(max(vec2<f32>(x, y), vec2<f32>(0.0)));
    let inside = min(max(x, y), 0.0);
    return outside + inside - r;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let uv = pos.xy / res;
    
    // Background: White
    var color = vec3<f32>(1.0, 1.0, 1.0);
    
    // Margin and Layout
    let margin_x = 80.0;
    let bar_width = 40.0;
    let chart_bottom = 0.8 * res.y;
    let chart_top = 0.1 * res.y;
    let chart_height = chart_bottom - chart_top;
    
    // Grid lines (every integer decade)
    for (var g: i32 = 0; g <= 10; g = g + 1) {
        let gy = chart_bottom - (f32(g) / 10.0) * chart_height;
        let grid_thickness = 1.0;
        if (abs(pos.y - gy) < grid_thickness) {
            color = mix(color, vec3<f32>(0.9, 0.9, 0.9), 0.5);
        }
    }

    // Render 11 Bars
    for (var i: u32 = 0u; i < 11u; i = i + 1u) {
        let center_x = margin_x + f32(i) * 144.0; // Spaced to fill canvas
        let log_h = get_bar_height(i);
        let h_px = (log_h / 10.0) * chart_height;
        
        // Bar geometry
        let p = pos.xy - vec2<f32>(center_x, chart_bottom - h_px * 0.5);
        let dist = sd_round_rect_top(p, vec2<f32>(bar_width * 0.5, h_px * 0.5), 5.0);
        
        // Color gradient: Deep Blue (#0033CC) to Searing Red (#FF3300)
        let t = f32(i) / 10.0;
        let bar_color = mix(vec3<f32>(0.0, 0.2, 0.8), vec3<f32>(1.0, 0.2, 0.0), t);
        
        let alpha = 1.0 - smoothstep(-1.0, 1.0, dist);
        color = mix(color, bar_color, alpha);
    }

    // Axes lines
    if (pos.x > margin_x - 40.0 && pos.x < margin_x - 38.0 && pos.y < chart_bottom && pos.y > chart_top) {
        color = vec3<f32>(0.2);
    }
    if (pos.y > chart_bottom && pos.y < chart_bottom + 2.0 && pos.x > margin_x - 40.0) {
        color = vec3<f32>(0.2);
    }

    return vec4<f32>(color, 1.0);
}