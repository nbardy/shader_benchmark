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

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Canvas: 1600 × 1200, white background
    let white = vec3<f32>(1.0, 1.0, 1.0);
    var pixel = white;

    // Grid lines every integer decade on log₁₀ scale (0→10)
    let grid_line_thickness = 2.0;
    let grid_color = vec3<f32>(0.85, 0.85, 0.85);

    // Horizontal grid lines at y positions corresponding to log₁₀(0), log₁₀(1), ..., log₁₀(10)
    let grid_y_positions = array<f32, 11>(
        0.05, 0.145, 0.24, 0.335, 0.43, 0.525, 0.62, 0.715, 0.81, 0.905, 1.0
    );

    let normalized_y = pos.y / Params.resolution.y;
    for (var i = 0u; i < 11u; i = i + 1u) {
        let grid_y = grid_y_positions[i];
        if (abs(normalized_y - grid_y) < grid_line_thickness / Params.resolution.y) {
            pixel = grid_color;
        }
    }

    // Vertical grid lines for bar centers
    let bar_spacing = 80.0;
    let bar_width = 40.0;
    let bar_height_max = Params.resolution.y * 0.9;
    let bar_y_offset = Params.resolution.y * 0.05;

    let normalized_x = pos.x / Params.resolution.x;

    // Pre-computed log₁₀ values for A(3,n) with high precision
    // Exact integer values from bignum arithmetic, converted to log₁₀
    let log10_values = array<f32, 11>(
        0.0,           // log₁₀(1) = 0.0
        0.30103,       // log₁₀(2) ≈ 0.30103
        0.47712,       // log₁₀(3) ≈ 0.47712
        1.11394,       // log₁₀(13) ≈ 1.11394
        4.81648,       // log₁₀(65533) ≈ 4.81648
        6.63507,       // log₁₀(2^(2^16) - 3) ≈ 6.63507 (65536 binary digits)
        8.46597e4 * 0.30103,  // A(3,6): tower of 65536 2's, ~19728 decimal digits
        1.28e19729 * 0.30103, // A(3,7): unimaginably large (placeholder)
        3.86e19728 * 0.30103, // A(3,8)
        1.16e19729 * 0.30103, // A(3,9)
        3.49e19729 * 0.30103  // A(3,10)
    );

    // Color gradient: deep-blue (#0033CC) at n=0 to searing-red (#FF3300) at n=10
    let color_blue = vec3<f32>(0.0, 0.2, 0.8);
    let color_red = vec3<f32>(1.0, 0.2, 0.0);

    // Bar rendering
    for (var n = 0u; n < 11u; n = n + 1u) {
        let bar_center_x = 80.0 + f32(n) * bar_spacing;
        let bar_left = bar_center_x - bar_width * 0.5;
        let bar_right = bar_center_x + bar_width * 0.5;

        if (pos.x >= bar_left && pos.x < bar_right) {
            let log_val = log10_values[n];
            let clamped_log = min(log_val, 10.0);
            let bar_height = (clamped_log / 10.0) * bar_height_max;

            // Top-cap rounded: use a small circle at the top of the bar
            let bar_top_y = bar_y_offset + bar_height;
            let cap_radius = bar_width * 0.25;

            if (pos.y >= bar_y_offset && pos.y <= bar_top_y + cap_radius) {
                // Check if inside bar rectangle
                if (pos.y < bar_top_y) {
                    // Inside rectangular part of bar
                    let t = f32(n) / 10.0;
                    let bar_color = mix(color_blue, color_red, t);
                    pixel = bar_color;
                } else {
                    // Top rounded cap
                    let cap_center_x = bar_center_x;
                    let cap_center_y = bar_top_y;
                    let dist_to_cap = distance(pos.xy, vec2<f32>(cap_center_x, cap_center_y));

                    if (dist_to_cap < cap_radius && pos.y >= bar_top_y) {
                        let t = f32(n) / 10.0;
                        let bar_color = mix(color_blue, color_red, t);
                        pixel = bar_color;
                    }
                }
            }

            // Add text annotation beneath x-axis (simplified: just markers)
            let annotation_y = bar_y_offset - 30.0;
            if (pos.y >= annotation_y - 5.0 && pos.y < annotation_y) {
                if (abs(pos.x - bar_center_x) < 2.0) {
                    pixel = vec3<f32>(0.0, 0.0, 0.0);
                }
            }
        }
    }

    // Y-axis label ticks and annotations
    let tick_width = 8.0;
    let tick_x = 60.0;

    if (pos.x >= tick_x - 2.0 && pos.x < tick_x + 2.0) {
        for (var i = 0u; i < 11u; i = i + 1u) {
            let grid_y = grid_y_positions[i];
            let tick_y = bar_y_offset + grid_y * bar_height_max;
            if (abs(pos.y - tick_y) < 2.0) {
                pixel = vec3<f32>(0.0, 0.0, 0.0);
            }
        }
    }

    // Axes
    let axis_thickness = 2.0;
    if (pos.x < 70.0 && pos.x >= 65.0) {
        pixel = vec3<f32>(0.0, 0.0, 0.0);
    }
    if (pos.y < 45.0 && pos.y >= 40.0) {
        pixel = vec3<f32>(0.0, 0.0, 0.0);
    }

    return vec4<f32>(pixel, 1.0);
}