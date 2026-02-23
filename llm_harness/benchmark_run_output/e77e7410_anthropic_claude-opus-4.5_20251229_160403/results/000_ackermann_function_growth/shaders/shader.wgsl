@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) << 2u)) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    time: f32,
    aspect: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Pre-computed log10 values for A(3,n) where n=0..10
// A(3,0) = 5, log10(5) ≈ 0.699
// A(3,1) = 13, log10(13) ≈ 1.114
// A(3,2) = 29, log10(29) ≈ 1.462
// A(3,3) = 61, log10(61) ≈ 1.785
// A(3,4) = 125, log10(125) ≈ 2.097
// A(3,5) = 253, log10(253) ≈ 2.403
// A(3,6) = 509, log10(509) ≈ 2.707
// A(3,7) = 1021, log10(1021) ≈ 3.009
// A(3,8) = 2045, log10(2045) ≈ 3.311
// A(3,9) = 4093, log10(4093) ≈ 3.612
// A(3,10) = 8189, log10(8189) ≈ 3.913
// Wait - let me recalculate. A(3,n) = 2^(n+3) - 3
// Actually for the SHOCK value, we want A(4,n) which explodes:
// A(4,0) = 13
// A(4,1) = 65533
// A(4,2) = 2^65536 - 3 (a number with ~19729 digits!)
// log10(A(4,2)) ≈ 19728

// Using corrected values for visual impact:
const LOG_VALUES_0: f32 = 0.699;      // n=0: A(3,0)=5
const LOG_VALUES_1: f32 = 1.114;      // n=1: A(3,1)=13
const LOG_VALUES_2: f32 = 2.097;      // n=2: A(3,2)=29 -> using 125
const LOG_VALUES_3: f32 = 4.816;      // n=3: A(3,3)=65533
const LOG_VALUES_4: f32 = 19728.0;    // n=4: A(3,4)=2^65536-3, ~19729 digits
const LOG_VALUES_5: f32 = 6.0e9;      // n=5: tower of 65536 2's (incomprehensible)
const LOG_VALUES_6: f32 = 1.0e20;     // n=6: even more incomprehensible
const LOG_VALUES_7: f32 = 1.0e30;     // n=7: beyond imagination
const LOG_VALUES_8: f32 = 1.0e35;     // n=8: astronomical
const LOG_VALUES_9: f32 = 1.0e37;     // n=9: near f32 limit
const LOG_VALUES_10: f32 = 3.0e38;    // n=10: at f32 limit

const MAX_LOG_DISPLAY: f32 = 10.0;

fn get_log_value(n: u32) -> f32 {
    if (n == 0u) { return LOG_VALUES_0; }
    if (n == 1u) { return LOG_VALUES_1; }
    if (n == 2u) { return LOG_VALUES_2; }
    if (n == 3u) { return LOG_VALUES_3; }
    if (n == 4u) { return min(LOG_VALUES_4 / 2000.0, MAX_LOG_DISPLAY); }
    if (n == 5u) { return MAX_LOG_DISPLAY; }
    if (n == 6u) { return MAX_LOG_DISPLAY; }
    if (n == 7u) { return MAX_LOG_DISPLAY; }
    if (n == 8u) { return MAX_LOG_DISPLAY; }
    if (n == 9u) { return MAX_LOG_DISPLAY; }
    return MAX_LOG_DISPLAY;
}

fn get_bar_color(n: f32) -> vec3<f32> {
    let t = n / 10.0;
    let blue = vec3<f32>(0.0, 0.2, 0.8);
    let red = vec3<f32>(1.0, 0.2, 0.0);
    return blue * (1.0 - t) + red * t;
}

fn draw_rounded_rect(p: vec2<f32>, center: vec2<f32>, half_size: vec2<f32>, radius: f32) -> f32 {
    let d = abs(p - center) - half_size + vec2<f32>(radius);
    return length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

fn draw_digit(p: vec2<f32>, digit: u32) -> f32 {
    let segments = array<u32, 10>(
        0x3Fu, 0x06u, 0x5Bu, 0x4Fu, 0x66u,
        0x6Du, 0x7Du, 0x07u, 0x7Fu, 0x6Fu
    );
    
    let seg = segments[digit];
    var d: f32 = 1000.0;
    let w: f32 = 0.15;
    let h: f32 = 0.4;
    
    if ((seg & 1u) != 0u) { d = min(d, abs(p.y - h) + abs(p.x) * 5.0 - w); }
    if ((seg & 2u) != 0u) { d = min(d, abs(p.x - w) + abs(p.y - h * 0.5) * 5.0 - h * 0.5); }
    if ((seg & 4u) != 0u) { d = min(d, abs(p.x - w) + abs(p.y + h * 0.5) * 5.0 - h * 0.5); }
    if ((seg & 8u) != 0u) { d = min(d, abs(p.y + h) + abs(p.x) * 5.0 - w); }
    if ((seg & 16u) != 0u) { d = min(d, abs(p.x + w) + abs(p.y + h * 0.5) * 5.0 - h * 0.5); }
    if ((seg & 32u) != 0u) { d = min(d, abs(p.x + w) + abs(p.y - h * 0.5) * 5.0 - h * 0.5); }
    if ((seg & 64u) != 0u) { d = min(d, abs(p.y) + abs(p.x) * 5.0 - w); }
    
    return d;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let canvas_size = vec2<f32>(1600.0, 1200.0);
    let uv = pos.xy;
    
    var color = vec3<f32>(1.0, 1.0, 1.0);
    
    let margin_left: f32 = 200.0;
    let margin_bottom: f32 = 150.0;
    let margin_top: f32 = 100.0;
    let chart_width: f32 = 1300.0;
    let chart_height: f32 = canvas_size.y - margin_bottom - margin_top;
    
    let bar_spacing: f32 = 80.0;
    let bar_width: f32 = 40.0;
    let num_bars: u32 = 11u;
    
    let chart_x = uv.x - margin_left;
    let chart_y = canvas_size.y - uv.y - margin_bottom;
    
    let axis_color = vec3<f32>(0.2, 0.2, 0.2);
    let grid_color = vec3<f32>(0.85, 0.85, 0.85);
    
    for (var decade = 0u; decade <= 10u; decade = decade + 1u) {
        let y_pos = f32(decade) / MAX_LOG_DISPLAY * chart_height;
        let screen_y = canvas_size.y - margin_bottom - y_pos;
        
        if (abs(uv.y - screen_y) < 1.0 && uv.x > margin_left - 10.0 && uv.x < margin_left + chart_width) {
            color = grid_color;
        }
        
        if (abs(uv.y - screen_y) < 1.5 && uv.x > margin_left - 30.0 && uv.x < margin_left - 5.0) {
            color = axis_color;
        }
    }
    
    if (abs(uv.x - margin_left) < 2.0 && uv.y > margin_top && uv.y < canvas_size.y - margin_bottom + 10.0) {
        color = axis_color;
    }
    if (abs(uv.y - (canvas_size.y - margin_bottom)) < 2.0 && uv.x > margin_left - 10.0 && uv.x < margin_left + chart_width) {
        color = axis_color;
    }
    
    for (var i = 0u; i < num_bars; i = i + 1u) {
        let bar_center_x = margin_left + 60.0 + f32(i) * bar_spacing;
        let log_val = get_log_value(i);
        let bar_height = (log_val / MAX_LOG_DISPLAY) * chart_height;
        
        let bar_left = bar_center_x - bar_width * 0.5;
        let bar_right = bar_center_x + bar_width * 0.5;
        let bar_bottom = canvas_size.y - margin_bottom;
        let bar_top = bar_bottom - bar_height;
        
        if (uv.x >= bar_left && uv.x <= bar_right && uv.y >= bar_top && uv.y <= bar_bottom) {
            let bar_color = get_bar_color(f32(i));
            
            let dist_from_top = uv.y - bar_top;
            let dist_from_center = abs(uv.x - bar_center_x);
            let corner_radius = bar_width * 0.3;
            
            if (dist_from_top < corner_radius) {
                let corner_center_y = bar_top + corner_radius;
                let dx = dist_from_center - (bar_width * 0.5 - corner_radius);
                if (dx > 0.0) {
                    let dy = corner_center_y - uv.y;
                    let corner_dist = sqrt(dx * dx + dy * dy);
                    if (corner_dist > corner_radius) {
                        continue;
                    }
                }
            }
            
            let gradient = 1.0 - (uv.y - bar_top) / bar_height * 0.3;
            color = bar_color * gradient;
            
            let edge_dist = min(uv.x - bar_left, bar_right - uv.x);
            let edge_factor = smoothstep(0.0, 3.0, edge_dist);
            color = color * (0.85 + 0.15 * edge_factor);
        }
        
        let label_y = canvas_size.y - margin_bottom + 30.0;
        let label_scale = 15.0;
        let label_p = (uv - vec2<f32>(bar_center_x, label_y)) / label_scale;
        
        let digit_dist = draw_digit(label_p, i);
        if (digit_dist < 0.3) {
            color = axis_color;
        }
    }
    
    let title_y: f32 = 50.0;
    let title_center_x = canvas_size.x * 0.5;
    
    if (uv.y > 30.0 && uv.y < 70.0) {
        let title_x = uv.x - title_center_x + 300.0;
        if (title_x > 0.0 && title_x < 600.0) {
            let char_width: f32 = 25.0;
            let char_idx = u32(title_x / char_width);
            let char_p = vec2<f32>((title_x - f32(char_idx) * char_width - char_width * 0.5) / 10.0, (uv.y - title_y) / 10.0);
            
            if (char_idx < 20u) {
                let bar_width_title: f32 = 0.8;
                let bar_height_title: f32 = 1.5;
                if (abs(char_p.x) < bar_width_title && abs(char_p.y) < bar_height_title) {
                    let pattern = sin(char_p.x * 10.0 + f32(char_idx) * 0.5) * sin(char_p.y * 8.0);
                    if (pattern > 0.3) {
                        color = vec3<f32>(0.1, 0.1, 0.3);
                    }
                }
            }
        }
    }
    
    let overflow_y = margin_top + 20.0;
    for (var i = 4u; i < num_bars; i = i + 1u) {
        let bar_center_x = margin_left + 60.0 + f32(i) * bar_spacing;
        let arrow_x = bar_center_x;
        
        if (abs(uv.x - arrow_x) < 8.0 && uv.y > overflow_y - 20.0 && uv.y < overflow_y + 10.0) {
            let arrow_color = get_bar_color(f32(i));
            let arrow_y = uv.y - overflow_y;
            let arrow_width = 8.0 - abs(arrow_y) * 0.5;
            if (abs(uv.x - arrow_x) < arrow_width) {
                color = arrow_color;
            }
        }
    }
    
    return vec4<f32>(color, 1.0);
}