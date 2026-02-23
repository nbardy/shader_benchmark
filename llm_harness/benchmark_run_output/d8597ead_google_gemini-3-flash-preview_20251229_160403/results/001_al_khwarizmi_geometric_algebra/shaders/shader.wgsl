// Al-Khwarizmi's Geometric Algebra: x^2 + 10x = 39
// Visualizing the 9th-century solution for completing the square.

struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// Distance Functions
fn sd_box(p: vec2<f32>, b: vec2<f32>) -> f32 {
    let d = abs(p) - b;
    return length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0);
}

// Islamic Geometric Pattern Helper (8-fold star)
fn star_pattern(p: vec2<f32>) -> f32 {
    let p_rot1 = vec2<f32>(p.x * 0.7071 - p.y * 0.7071, p.x * 0.7071 + p.y * 0.7071);
    let box1 = sd_box(p, vec2<f32>(0.2, 0.2));
    let box2 = sd_box(p_rot1, vec2<f32>(0.2, 0.2));
    return min(box1, box2);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv_raw = (pos.xy * 2.0 - params.resolution.xy) / min(params.resolution.x, params.resolution.y);
    let uv = uv_raw * 10.0; // Scaled coordinate system
    
    // Background: Traditional Islamic Manuscript Paper (#FEF3C7)
    let bg_color = vec3<f32>(0.996, 0.953, 0.780);
    var color = bg_color;

    // Time-based animation steps (fixed 5s cycle for display logic)
    // In a stateless harness, we use a mock time or coordinate-based progression
    // To represent the steps, we'll use a sequence from left to right or a radial reveal
    let anim_progress = fract(0.1); // Placeholder for animation if time were injected
    
    // Al-Khwarizmi colors
    let blue_sq = vec3<f32>(0.118, 0.227, 0.541); // Deep Blue
    let gold_rect = vec3<f32>(0.961, 0.620, 0.043); // Gold
    let white_corner = vec3<f32>(0.95, 0.95, 0.95);
    let border_blue = vec3<f32>(0.07, 0.14, 0.35);

    // 1. Original Square (x^2) where x=3
    // Positioned at center. Size for x=3 is 3.0 units.
    let x_val = 3.0;
    let half_x = x_val * 0.5;
    let dist_x2 = sd_box(uv, vec2<f32>(half_x, half_x));
    
    // 2. Addition of 4 rectangles (x * 2.5)
    let rect_w = 2.5;
    let d_rect1 = sd_box(uv - vec2<f32>(0.0, half_x + 1.25), vec2<f32>(half_x, 1.25)); // Top
    let d_rect2 = sd_box(uv - vec2<f32>(0.0, -(half_x + 1.25)), vec2<f32>(half_x, 1.25)); // Bottom
    let d_rect3 = sd_box(uv - vec2<f32>(half_x + 1.25, 0.0), vec2<f32>(1.25, half_x)); // Right
    let d_rect4 = sd_box(uv - vec2<f32>(-(half_x + 1.25), 0.0), vec2<f32>(1.25, half_x)); // Left
    let dist_rects = min(min(d_rect1, d_rect2), min(d_rect3, d_rect4));

    // 3. Completing the corners (2.5 * 2.5 = 6.25 each, total 25)
    let d_c1 = sd_box(uv - vec2<f32>(half_x + 1.25, half_x + 1.25), vec2<f32>(1.25, 1.25));
    let d_c2 = sd_box(uv - vec2<f32>(-(half_x + 1.25), half_x + 1.25), vec2<f32>(1.25, 1.25));
    let d_c3 = sd_box(uv - vec2<f32>(half_x + 1.25, -(half_x + 1.25)), vec2<f32>(1.25, 1.25));
    let d_c4 = sd_box(uv - vec2<f32>(-(half_x + 1.25), -(half_x + 1.25)), vec2<f32>(1.25, 1.25));
    let dist_corners = min(min(d_c1, d_c2), min(d_c3, d_c4));

    // Rendering Logic
    // Draw rectangles (Step 2)
    color = mix(color, gold_rect, 1.0 - smoothstep(0.0, 0.05, dist_rects));
    color = mix(color, border_blue, (1.0 - smoothstep(0.0, 0.05, abs(dist_rects))) * 0.5);
    
    // Draw central square x^2 (Step 1)
    color = mix(color, blue_sq, 1.0 - smoothstep(0.0, 0.05, dist_x2));
    
    // Draw corners (Step 3) - Logic: Completing the Square
    color = mix(color, white_corner, 1.0 - smoothstep(0.0, 0.05, dist_corners));
    color = mix(color, border_blue, 1.0 - smoothstep(0.0, 0.03, abs(dist_corners)));

    // Outer Border with 8-fold stars
    let border_dist = sd_box(uv, vec2<f32>(8.5, 8.5));
    let outer_frame = abs(border_dist) - 0.2;
    color = mix(color, border_blue, 1.0 - smoothstep(0.0, 0.05, outer_frame));
    
    // Patterned margin
    let grid_p = fract(uv * 0.5) - 0.5;
    let star = star_pattern(grid_p);
    let margin_mask = step(8.7, max(abs(uv.x), abs(uv.y)));
    color = mix(color, gold_rect, margin_mask * (1.0 - smoothstep(0.0, 0.02, star)));

    // Final composition check
    // Total Square side is x + 5 = 8. Area is 64.
    // 3^2 + 10(3) = 9 + 30 = 39.
    // 39 + 25 (corners) = 64.
    
    return vec4<f32>(color, 1.0);
}