// Cardioid and Limaçon Collection
// Interactive visualization of the limaçon family of curves
// General equation: r = a + b*cos(θ)

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
    _padding: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Distance to a point on a polar curve
fn distanceToPolarCurve(uv: vec2<f32>, a: f32, b: f32, sample_count: u32) -> f32 {
    var min_dist = 1000.0;
    var prev_point = vec2<f32>(0.0);
    
    var i: u32 = 0u;
    loop {
        if (i >= sample_count) { break; }
        
        let theta = f32(i) / f32(sample_count) * 6.283185307;
        let r = a + b * cos(theta);
        
        let point = vec2<f32>(r * cos(theta), r * sin(theta)) * 0.3;
        
        if (i > 0u) {
            let dist = distanceToLineSegment(uv, prev_point, point);
            min_dist = min(min_dist, dist);
        }
        
        prev_point = point;
        i = i + 1u;
    }
    
    // Close the loop
    let theta_start = 0.0;
    let r_start = a + b * cos(theta_start);
    let start_point = vec2<f32>(r_start * cos(theta_start), r_start * sin(theta_start)) * 0.3;
    let dist_close = distanceToLineSegment(uv, prev_point, start_point);
    min_dist = min(min_dist, dist_close);
    
    return min_dist;
}

fn distanceToLineSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let len_sq = dot(ba, ba);
    let t = clamp(dot(pa, ba) / len_sq, 0.0, 1.0);
    return length(pa - ba * t);
}

fn getCurveColor(curve_type: i32) -> vec3<f32> {
    if (curve_type == 0i) {
        return vec3<f32>(1.0, 0.2, 0.2);  // Cardioid - red
    } else if (curve_type == 1i) {
        return vec3<f32>(0.2, 1.0, 0.2);  // Inner loop - green
    } else if (curve_type == 2i) {
        return vec3<f32>(0.2, 0.2, 1.0);  // Dimpled - blue
    } else {
        return vec3<f32>(1.0, 1.0, 0.2);  // Convex - yellow
    }
}

fn drawPolarGrid(uv: vec2<f32>) -> f32 {
    let r = length(uv);
    let theta = atan2(uv.y, uv.x);
    
    // Radial grid lines
    let radial_grid = abs(sin(theta * 8.0)) * 0.3;
    
    // Circular grid lines
    let circle_grid = abs(sin(r * 20.0)) * 0.3;
    
    // Center point
    let center_dist = length(uv);
    let center_dot = smoothstep(0.01, 0.0, center_dist);
    
    return max(max(radial_grid, circle_grid), center_dot);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let bg_color = vec3<f32>(0.05, 0.05, 0.08);
    var final_color = bg_color;
    var min_dist_overall = 1000.0;
    var closest_color = bg_color;
    
    // Animation phase
    let phase = params.time * 0.5;
    
    // Cardioid (a = b)
    let a1 = 0.8;
    let b1 = 0.8;
    let dist1 = distanceToPolarCurve(uv, a1, b1, 256u);
    if (dist1 < min_dist_overall) {
        min_dist_overall = dist1;
        closest_color = getCurveColor(0i);
    }
    
    // Limaçon with inner loop (a < b) - animated
    let a2 = 0.4 + 0.2 * sin(phase);
    let b2 = 0.8;
    let dist2 = distanceToPolarCurve(uv, a2, b2, 256u);
    if (dist2 < min_dist_overall) {
        min_dist_overall = dist2;
        closest_color = getCurveColor(1i);
    }
    
    // Dimpled limaçon (a > b but a < 2b) - animated
    let a3 = 1.0 + 0.3 * sin(phase + 2.094);
    let b3 = 0.8;
    let dist3 = distanceToPolarCurve(uv, a3, b3, 256u);
    if (dist3 < min_dist_overall) {
        min_dist_overall = dist3;
        closest_color = getCurveColor(2i);
    }
    
    // Convex limaçon (a ≥ 2b) - animated
    let a4 = 1.6 + 0.2 * sin(phase + 4.189);
    let b4 = 0.8;
    let dist4 = distanceToPolarCurve(uv, a4, b4, 256u);
    if (dist4 < min_dist_overall) {
        min_dist_overall = dist4;
        closest_color = getCurveColor(3i);
    }
    
    // Draw grid/polar coordinate system
    let grid_intensity = drawPolarGrid(uv);
    
    // Render curves with anti-aliasing
    let line_width = 0.008;
    let curve_alpha = 1.0 - smoothstep(0.0, line_width, min_dist_overall);
    final_color = mix(final_color, closest_color, curve_alpha);
    
    // Add subtle grid
    let grid_color = vec3<f32>(0.2, 0.2, 0.25);
    final_color = mix(final_color, grid_color, grid_intensity * 0.3);
    
    // Add legend/labels area
    let label_area = step(0.35, abs(uv.y) + 0.01 * cos(uv.x * 10.0));
    if (label_area > 0.5) {
        // Darken label area slightly
        final_color = final_color * 0.8;
    }
    
    return vec4<f32>(final_color, 1.0);
}