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

const NUM_BARS: u32 = 11u;
const BAR_WIDTH: f32 = 40.0;
const BAR_SPACING: f32 = 80.0;
const LOG_MAX: f32 = 10.0;

fn rounded_rect(uv: vec2<f32>, center: vec2<f32>, width: f32, height: f32, radius: f32) -> f32 {
    let d = abs(uv - center) - vec2<f32>(width * 0.5, height * 0.5) + radius;
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / Params.resolution;
    let aspectRatio = Params.aspect;
    let x = uv.x * Params.resolution.x;
    let bar_index = floor(x / BAR_SPACING);

    var color = vec3<f32>(1.0); // White background

    if (bar_index < f32(NUM_BARS)) {
        let n = u32(bar_index); 
        let center_x = f32(n) * BAR_SPACING + BAR_SPACING * 0.5;
        let bar_x = center_x / Params.resolution.x;

        // Ackermann(3, n) log₁₀ values
        var log_value: f32;
        switch n {
            case 0u: { log_value = 0.0; }      // log10(1)
            case 1u: { log_value = 0.30103; } // log10(2)
            case 2u: { log_value = 0.47712; } // log10(3)
            case 3u: { log_value = 1.11394; } // log10(13)
            case 4u: { log_value = 5.81662; } // log10(65533)
            case 5u: { log_value = 19728.3; } // Approximation
            case 6u: { log_value = 3.4e38; } // Approximation
            case 7u: { log_value = 3.4e38; } // Approximation
            case 8u: { log_value = 3.4e38; } // Approximation
            case 9u: { log_value = 3.4e38; } // Approximation
            case 10u: { log_value = 3.4e38; } // Approximation
            default: { log_value = 0.0; } 
        }

        let bar_height = min(log_value / LOG_MAX, 1.0) * Params.resolution.y;
        let center_y = bar_height * 0.5;
        let bar_center = vec2<f32>(bar_x * Params.resolution.x, Params.resolution.y - center_y);

        let dist = rounded_rect(pos.xy, bar_center, BAR_WIDTH, bar_height, BAR_WIDTH * 0.5);

        if (dist < 1.0) {
            let t = f32(n) / f32(NUM_BARS - 1u);
            let blue = vec3<f32>(0.0, 0.2, 0.8);
            let red = vec3<f32>(1.0, 0.2, 0.0);
            color = blue + (red - blue) * t;
        }
    }

    // Y-axis gridlines
    for (var i = 0u; i <= 10u; i = i + 1u) {
        let grid_y = (f32(i) / LOG_MAX) * Params.resolution.y;
        let grid_pos = Params.resolution.y - grid_y;
        if (abs(pos.y - grid_pos) < 1.0) {
            color = vec3<f32>(0.8); // Light gray gridlines
        }
    }

    return vec4<f32>(color, 1.0);
}