// Thermogram on Poincaré disk: Hyperbolic heat kernel visualization
// Heat kernel K(r,t) = (1/√(4πt)) * exp(-t) * exp(-r²/(4t)) for t=0.2
// Hyperbolic distance r = 2*artanh(ρ), where ρ = |z| is Euclidean radius on disk

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

// Plasma colormap: K [0, 1.24] → RGBA
fn plasma_colormap(t: f32) -> vec3<f32> {
    var clamped_t = clamp(t / 1.24, 0.0, 1.0);
    
    // Plasma LUT approximation (Matplotlib)
    if (clamped_t < 0.25) {
        // Dark purple to purple
        let s = clamped_t / 0.25;
        return mix(vec3<f32>(0.05, 0.03, 0.53), vec3<f32>(0.34, 0.12, 0.87), s);
    } else if (clamped_t < 0.5) {
        // Purple to pink/red
        let s = (clamped_t - 0.25) / 0.25;
        return mix(vec3<f32>(0.34, 0.12, 0.87), vec3<f32>(0.89, 0.10, 0.48), s);
    } else if (clamped_t < 0.75) {
        // Pink to yellow
        let s = (clamped_t - 0.5) / 0.25;
        return mix(vec3<f32>(0.89, 0.10, 0.48), vec3<f32>(0.98, 0.68, 0.05), s);
    } else {
        // Yellow to white
        let s = (clamped_t - 0.75) / 0.25;
        return mix(vec3<f32>(0.98, 0.68, 0.05), vec3<f32>(1.0, 1.0, 1.0), s);
    }
}

// Hyperbolic distance from origin via Poincaré disk
// r = 2 * artanh(ρ) where ρ ∈ [0,1)
fn hyperbolic_distance(rho: f32) -> f32 {
    var clamped_rho = clamp(rho, 0.0, 0.9999);
    // artanh(x) = 0.5 * ln((1+x)/(1-x))
    let num = 1.0 + clamped_rho;
    let denom = 1.0 - clamped_rho;
    let ln_ratio = log(num / denom);
    return 2.0 * (0.5 * ln_ratio);
}

// Heat kernel K(r, t=0.2)
fn heat_kernel(r: f32) -> f32 {
    let t = 0.2;
    let sqrt_4pit = sqrt(4.0 * 3.14159265 * t);
    let exp_neg_t = exp(-t);
    let r_sq = r * r;
    let exp_diffusion = exp(-r_sq / (4.0 * t));
    return (1.0 / sqrt_4pit) * exp_neg_t * exp_diffusion;
}

// Check if point is within dashed circle (geodesic at hyperbolic radius 1.5)
// Euclidean radius ρ_c = tanh(1.5/2) ≈ 0.905
fn is_geodesic_circle(rho: f32, angle: f32) -> f32 {
    let rho_c = tanh(0.75); // ≈ 0.905
    let circle_thickness = 0.005;
    let circle_dist = abs(rho - rho_c);
    
    // Dashed pattern: 12 px per dash (assume pixel-scale ≈ 0.001 per px in [0,1])
    let dash_period = 0.012; // 12 px equivalent
    let dash_pattern = (angle + 0.0 % dash_period);
    let is_dash = select(0.0, 1.0, dash_pattern < 0.006); // 50% duty cycle
    
    let circle_alpha = select(0.0, 1.0, circle_dist < circle_thickness) * is_dash;
    return circle_alpha;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution; // 2048×2048 or 2200×2200
    let center = resolution * 0.5;
    let pixel_coords = pos.xy;
    
    // Normalize to [−1, 1] centered at disk origin
    let delta = pixel_coords - center;
    let max_dim = min(resolution.x, resolution.y) * 0.5;
    let uv = delta / max_dim;
    
    let rho = length(uv);
    let angle = atan2(uv.y, uv.x);
    
    // Disk boundary: cap outer 10 px to black
    let disk_radius_normalized = max_dim / max_dim; // = 1.0 (normalized disk edge)
    let outer_margin = 10.0 / max_dim;
    var color = vec3<f32>(0.0, 0.0, 0.0);
    
    if (rho < disk_radius_normalized - outer_margin) {
        // Inside disk (excluding outer frame)
        let r_hyp = hyperbolic_distance(rho);
        let K = heat_kernel(r_hyp);
        
        // Map heat kernel to plasma colormap
        color = plasma_colormap(K);
        
        // Overlay geodesic circle in gold
        let geo_alpha = is_geodesic_circle(rho, angle);
        let gold = vec3<f32>(1.0, 0.8, 0.2);
        color = mix(color, gold, geo_alpha * 0.95); // Gold overlay at 95% opacity
    }
    
    // Legend: colour bar at bottom-left (200×20 px region)
    let legend_x_min = 20.0;
    let legend_x_max = 220.0;
    let legend_y_min = resolution.y - 40.0;
    let legend_y_max = resolution.y - 20.0;
    
    if (pixel_coords.x >= legend_x_min && pixel_coords.x <= legend_x_max &&
        pixel_coords.y >= legend_y_min && pixel_coords.y <= legend_y_max) {
        // Horizontal gradient bar
        let bar_t = (pixel_coords.x - legend_x_min) / (legend_x_max - legend_x_min);
        let bar_k = bar_t * 1.24; // K range [0, 1.24]
        color = plasma_colormap(bar_k);
    }
    
    return vec4<f32>(color, 1.0);
}