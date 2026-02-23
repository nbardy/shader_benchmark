// Weierstrass Function Seismograph - Mathematical Fractality Visualizer
// W(x) = Σ(n=0 to 50) a^n * cos(b^n * π * x), where a = 0.5, b = 3
// Domain: x ∈ [-2, 2], rendered as 8192-point panoramic trace with Catmull-Rom smoothing

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

// Compute Weierstrass function: W(x) = Σ a^n * cos(b^n * π * x)
fn weierstrass(x: f32) -> f32 {
    let a = 0.5;
    let b = 3.0;
    let pi = 3.14159265359;
    
    var result = 0.0;
    var a_power = 1.0;
    var b_power = 1.0;
    
    // Sum 51 terms (n=0 to 50)
    for (var n: u32 = 0u; n < 51u; n = n + 1u) {
        result = result + a_power * cos(b_power * pi * x);
        a_power = a_power * a;
        b_power = b_power * b;
    }
    
    return result;
}

// Catmull-Rom cubic interpolation for smooth curve resampling
fn catmull_rom(p0: f32, p1: f32, p2: f32, p3: f32, t: f32) -> f32 {
    let t2 = t * t;
    let t3 = t2 * t;
    
    let coeff0 = -0.5 * t3 + t2 - 0.5 * t;
    let coeff1 = 1.5 * t3 - 2.5 * t2 + 1.0;
    let coeff2 = -1.5 * t3 + 2.0 * t2 + 0.5 * t;
    let coeff3 = 0.5 * t3 - 0.5 * t2;
    
    return coeff0 * p0 + coeff1 * p1 + coeff2 * p2 + coeff3 * p3;
}

// Sample Weierstrass at discrete point index (0..8192)
fn sample_weierstrass_at_index(idx: u32) -> f32 {
    let t = f32(idx) / 8192.0;  // t ∈ [0, 1]
    let x = -2.0 + t * 4.0;      // x ∈ [-2, 2]
    return weierstrass(x);
}

// Distance from point to line segment (for stroke rendering)
fn distance_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Anti-aliased stroke: 3px wide mandarin-orange line
fn stroke_mask(dist: f32, width: f32) -> f32 {
    let half_width = width * 0.5;
    return smoothstep(half_width + 0.5, half_width - 0.5, dist);
}

// Apply subtle drop-shadow (1px offset, 20% opacity, 90° down)
fn shadow_contribution(dist: f32, shadow_offset: f32) -> f32 {
    let shadow_width = 1.5;
    let shadow_alpha = 0.2;
    let shadow_dist = distance_falloff(dist - shadow_offset);
    return shadow_alpha * smoothstep(shadow_width + 0.5, shadow_width - 0.5, shadow_dist);
}

fn distance_falloff(d: f32) -> f32 {
    return max(0.0, d);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let screen_size = params.resolution;
    let aspect = screen_size.x / screen_size.y;  // 2400/1200 = 2.0
    
    // Normalize to seismograph domain: x ∈ [-2, 2], y ∈ [-0.5, 0.5] (panoramic)
    let uv_x = (pos.x / screen_size.x) * 4.0 - 2.0;                    // [-2, 2]
    let uv_y = ((screen_size.y - pos.y) / screen_size.y) - 0.5;         // [-0.5, 0.5]
    
    let background_color = vec3<f32>(1.0, 1.0, 1.0);  // Pure white
    let axis_color = vec3<f32>(0.5647, 0.5647, 0.5647);  // Grey #909090
    let curve_color = vec3<f32>(1.0, 0.4, 0.0);  // Mandarin-orange #FF6600
    
    var final_color = background_color;
    
    // Draw horizontal axis at y=0 (thin 1px grey line)
    let axis_tolerance = 0.5 / screen_size.y;
    let axis_mask = smoothstep(axis_tolerance + 0.001, axis_tolerance - 0.001, abs(uv_y));
    final_color = mix(final_color, axis_color, axis_mask * 0.6);
    
    // Draw tick marks every 0.5 units on x-axis
    let tick_spacing = 0.5;
    let tick_phase = (uv_x + 2.0) % tick_spacing;
    let near_tick = min(abs(tick_phase - 0.0), abs(tick_phase - tick_spacing));
    let tick_size = 0.03;
    let tick_height = 0.02 / screen_size.y;
    
    if (near_tick < 0.01 && abs(uv_y) < tick_height) {
        final_color = mix(final_color, axis_color, 0.5);
    }
    
    // Sample Weierstrass curve and render with Catmull-Rom smoothing
    // Find closest point on the curve to current pixel
    let sample_resolution = 8192u;
    let pixel_tolerance = 2.0 / screen_size.x;  // 2px tolerance for curve detection
    
    var min_curve_dist = 1000.0;
    var curve_contribution = 0.0;
    
    // Scan through sample points to find nearby segments
    for (var i: u32 = 0u; i < sample_resolution - 1u; i = i + 1u) {
        // Current and next sample indices
        let idx0 = i;
        let idx1 = i + 1u;
        
        // Get x coordinates
        let t0 = f32(idx0) / f32(sample_resolution);
        let t1 = f32(idx1) / f32(sample_resolution);
        let x0 = -2.0 + t0 * 4.0;
        let x1 = -2.0 + t1 * 4.0;
        
        // Sample Weierstrass with extra neighbors for Catmull-Rom
        let idx_prev = select(idx0 - 1u, idx0, idx0 == 0u);
        let idx_next = select(idx1 + 1u, idx1, idx1 == sample_resolution - 1u);
        
        let w_prev = sample_weierstrass_at_index(idx_prev);
        let w0 = sample_weierstrass_at_index(idx0);
        let w1 = sample_weierstrass_at_index(idx1);
        let w_next = sample_weierstrass_at_index(idx_next);
        
        // Build interpolated segment using Catmull-Rom (subdivide for smoothness)
        let subdivisions = 4u;
        for (var sub: u32 = 0u; sub < subdivisions; sub = sub + 1u) {
            let local_t = f32(sub) / f32(subdivisions);
            let interp_w0 = catmull_rom(w_prev, w0, w1, w_next, local_t);
            
            let local_t_next = f32(sub + 1u) / f32(subdivisions);
            let interp_w1 = catmull_rom(w_prev, w0, w1, w_next, local_t_next);
            
            let interp_x0 = x0 + local_t * (x1 - x0);
            let interp_x1 = x0 + local_t_next * (x1 - x0);
            
            // Check if current pixel is near this curve segment
            let seg_a = vec2<f32>(interp_x0, interp_w0);
            let seg_b = vec2<f32>(interp_x1, interp_w1);
            let pixel_pos = vec2<f32>(uv_x, uv_y);
            
            let dist = distance_to_segment(pixel_pos, seg_a, seg_b);
            
            if (dist < min_curve_dist) {
                min_curve_dist = dist;
            }
        }
    }
    
    // Render orange curve with 3px anti-aliased stroke
    let stroke_width = 3.0 / screen_size.y;  // 3px in normalized coords
    let curve_mask = stroke_mask(min_curve_dist, stroke_width);
    
    // Add drop-shadow (1px offset, 20% opacity, downward)
    let shadow_offset = 1.0 / screen_size.y;
    let shadow_mask = shadow_contribution(min_curve_dist, shadow_offset);
    
    // Composite: shadow first, then orange curve
    final_color = mix(final_color, vec3<f32>(0.0), shadow_mask);
    final_color = mix(final_color, curve_color, curve_mask);
    
    return vec4<f32>(final_color, 1.0);
}