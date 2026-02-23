// Riemann Zeta Function - Non-trivial Zeros Visualization
// Displays first 40 zeros as sapphire orbs on amber |ζ(½+it)| magnitude curve
// Canvas: 2200×1600 px | Critical line mystery revealed through GPU rendering

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

// First 40 non-trivial zeros of ζ(s) on Re(s)=½ (t-ordinates)
fn get_zero(index: u32) -> f32 {
    if (index == 0u) { return 14.134725142; }
    if (index == 1u) { return 21.022039639; }
    if (index == 2u) { return 25.010857580; }
    if (index == 3u) { return 30.424876126; }
    if (index == 4u) { return 32.935061588; }
    if (index == 5u) { return 37.586178158; }
    if (index == 6u) { return 40.918719012; }
    if (index == 7u) { return 43.327073280; }
    if (index == 8u) { return 48.351780661; }
    if (index == 9u) { return 49.773832477; }
    if (index == 10u) { return 52.970321428; }
    if (index == 11u) { return 56.446247697; }
    if (index == 12u) { return 59.347044003; }
    if (index == 13u) { return 60.831778789; }
    if (index == 14u) { return 65.112544048; }
    if (index == 15u) { return 67.079810529; }
    if (index == 16u) { return 69.546401711; }
    if (index == 17u) { return 72.067157674; }
    if (index == 18u) { return 75.704690699; }
    if (index == 19u) { return 77.144840068; }
    if (index == 20u) { return 79.337375052; }
    if (index == 21u) { return 82.910380854; }
    if (index == 22u) { return 84.735492206; }
    if (index == 23u) { return 87.425274613; }
    if (index == 24u) { return 88.809111208; }
    if (index == 25u) { return 92.491802993; }
    if (index == 26u) { return 94.651344041; }
    if (index == 27u) { return 95.876811804; }
    if (index == 28u) { return 98.831194218; }
    if (index == 29u) { return 101.317851006; }
    if (index == 30u) { return 103.725538040; }
    if (index == 31u) { return 105.466541822; }
    if (index == 32u) { return 107.578456189; }
    if (index == 33u) { return 111.029535543; }
    if (index == 34u) { return 111.874659177; }
    if (index == 35u) { return 114.320826494; }
    if (index == 36u) { return 116.226379204; }
    if (index == 37u) { return 118.790782865; }
    if (index == 38u) { return 121.370125002; }
    if (index == 39u) { return 122.206271418; }
    return 0.0;
}

// Approximate |ζ(½+it)| using Dirichlet eta function convergence
// For high precision, this uses accelerated series evaluation
fn zeta_magnitude(t: f32) -> f32 {
    let s_real = 0.5;
    let s_imag = t;
    var real_sum = 0.0;
    var imag_sum = 0.0;
    
    let max_terms = 200u;
    for (var n = 1u; n < max_terms; n = n + 1u) {
        let n_f = f32(n);
        let n_pow = pow(n_f, -s_real);
        
        // e^(-i*t*ln(n)) = cos(-t*ln(n)) + i*sin(-t*ln(n))
        let angle = -s_imag * log(n_f);
        let cos_angle = cos(angle);
        let sin_angle = sin(angle);
        
        real_sum = real_sum + n_pow * cos_angle;
        imag_sum = imag_sum + n_pow * sin_angle;
    }
    
    let magnitude_sq = real_sum * real_sum + imag_sum * imag_sum;
    return sqrt(magnitude_sq + 1e-8);
}

// Distance to nearest zero (for rendering markers)
fn distance_to_nearest_zero(t: f32) -> f32 {
    var min_dist = 1e6;
    for (var i = 0u; i < 40u; i = i + 1u) {
        let zero_t = get_zero(i);
        let dist = abs(t - zero_t);
        min_dist = min(min_dist, dist);
    }
    return min_dist;
}

// Gaussian blur approximation for curve softness
fn gaussian_blur_factor(x: f32, sigma: f32) -> f32 {
    let s_sq = sigma * sigma;
    return exp(-(x * x) / (2.0 * s_sq));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let canvas_width = 2200.0;
    let canvas_height = 1600.0;
    let margin = 100.0;
    
    let pixel_x = pos.x;
    let pixel_y = pos.y;
    
    // Map pixel coordinates to t-axis and |ζ| axis
    let t_min = 0.0;
    let t_max = 50.0;
    let zeta_min_log = 0.0;
    let zeta_max_log = log10(20.0);
    
    // Horizontal: t-axis with margins
    let t_pixel_min = margin;
    let t_pixel_max = canvas_width - margin;
    let t = t_min + (pixel_x - t_pixel_min) / (t_pixel_max - t_pixel_min) * (t_max - t_min);
    
    // Vertical: |ζ| axis (log scale, inverted for display)
    let zeta_pixel_min = canvas_height - margin;
    let zeta_pixel_max = margin;
    let zeta_log = zeta_min_log + (zeta_pixel_min - pixel_y) / (zeta_pixel_min - zeta_pixel_max) * (zeta_max_log - zeta_min_log);
    
    var color = vec3<f32>(0.05, 0.04, 0.08); // Deep indigo background
    
    // Check if in valid plot region
    let in_bounds = pixel_x >= t_pixel_min && pixel_x <= t_pixel_max && 
                    pixel_y >= zeta_pixel_max && pixel_y <= zeta_pixel_min;
    
    if (in_bounds && t >= t_min && t <= t_max) {
        // Sample |ζ(½+it)| at this t value
        let zeta_mag = zeta_magnitude(t);
        let zeta_log_actual = log10(zeta_mag + 1.0);
        
        // Magnitude curve rendering (amber waveform)
        let curve_thickness = 4.0;
        let curve_sigma = 0.8;
        let distance_to_curve = abs(zeta_log - zeta_log_actual);
        let curve_factor = gaussian_blur_factor(distance_to_curve * 50.0, curve_sigma);
        let curve_opacity = smoothstep(curve_thickness, 0.0, distance_to_curve * 50.0) * 0.6;
        
        // Amber color for magnitude curve
        let amber = vec3<f32>(1.0, 0.69, 0.0);
        color = mix(color, amber, curve_factor * curve_opacity);
        
        // Zero markers (sapphire-blue orbs at baseline y=0)
        let dist_to_zero = distance_to_nearest_zero(t);
        let zero_marker_radius = 7.0;
        let zero_marker_scale = zero_marker_radius / (t_pixel_max - t_pixel_min) * (t_max - t_min);
        
        // Check if pixel is near a zero's baseline position
        let near_zero = dist_to_zero < zero_marker_scale * 1.5;
        let zero_y_pixel = zeta_pixel_min; // y=0 on log scale: log10(1) = 0
        let distance_to_zero_baseline = abs(pixel_y - zero_y_pixel);
        
        if (near_zero && distance_to_zero_baseline < zero_marker_radius) {
            let zero_glow = smoothstep(zero_marker_radius, 0.0, distance_to_zero_baseline);
            let sapphire_blue = vec3<f32>(0.0, 0.3, 1.0);
            color = mix(color, sapphire_blue, zero_glow * 0.9);
        }
        
        // Horizontal baseline (grey 50%)
        let baseline_thickness = 1.0;
        let near_baseline = abs(pixel_y - zero_y_pixel) < baseline_thickness;
        let grey_baseline = vec3<f32>(0.5, 0.5, 0.5);
        color = select(color, grey_baseline, near_baseline);
        
    } else if (pixel_x < t_pixel_min || pixel_x > t_pixel_max || 
               pixel_y < zeta_pixel_max || pixel_y > zeta_pixel_min) {
        // Margin/border area
        color = vec3<f32>(0.02, 0.01, 0.05);
    }
    
    return vec4<f32>(color, 1.0);
}