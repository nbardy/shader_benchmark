// PROBABILITY DISTRIBUTIONS AS DYNAMIC WEATHER SYSTEMS
// Transforms statistical distributions into atmospheric phenomena

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

// Normal distribution: stable high-pressure systems
fn normalDistribution(x: f32, mu: f32, sigma: f32) -> f32 {
    let diff = (x - mu) / sigma;
    let coeff = 1.0 / (sigma * 2.506628);
    return coeff * exp(-0.5 * diff * diff);
}

// Exponential distribution: rain intensity patterns
fn exponentialDistribution(x: f32, lambda: f32) -> f32 {
    return select(0.0, lambda * exp(-lambda * x), x >= 0.0);
}

// Cauchy distribution: extreme weather events (heavy tails)
fn cauchyDistribution(x: f32, x0: f32, gamma: f32) -> f32 {
    let denominator = 1.0 + ((x - x0) / gamma) * ((x - x0) / gamma);
    return (gamma / 3.14159) / (denominator * gamma);
}

// Beta distribution: cloud coverage
fn betaDistribution(x: f32, alpha: f32, beta: f32) -> f32 {
    let t1 = pow(x, alpha - 1.0);
    let t2 = pow(1.0 - x, beta - 1.0);
    let normalization = 1.0 / (0.5 * 3.14159); // approximate gamma ratios
    return t1 * t2 * normalization;
}

// Pressure system visualization: swirling spirals
fn pressureSpiral(pos: vec2<f32>, center: vec2<f32>, time: f32, intensity: f32) -> f32 {
    let delta = pos - center;
    let r = length(delta);
    let angle = atan2(delta.y, delta.x);
    
    // Spiral with time-based rotation
    let spiral = sin(r * 8.0 - time * 2.0 + angle * 3.0);
    let gaussian_falloff = exp(-r * r * intensity);
    
    return spiral * gaussian_falloff;
}

// Rain droplet field: exponential intensity with refraction
fn rainField(uv: vec2<f32>, time: f32, lambda: f32) -> f32 {
    let speed = time * 0.5;
    var rain: f32 = 0.0;
    
    // Multiple rain streaks with exponential falloff
    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
        let offset = f32(i) * 0.25;
        let y_pos = fract(uv.y + speed + offset);
        let x_offset = sin(y_pos * 3.14159 + offset) * 0.1;
        let dist = abs(uv.x - x_offset);
        
        rain = rain + exponentialDistribution(dist * 5.0, lambda);
    }
    
    return min(rain * 0.3, 1.0);
}

// Lightning bolts at Cauchy extremes (>3σ outliers)
fn lightningBolt(uv: vec2<f32>, seed: f32, time: f32) -> f32 {
    var bolt: f32 = 0.0;
    let freq = 1.0 / (1.0 + cauchyDistribution(seed, 0.0, 0.5) * 10.0);
    
    // Only render lightning with low probability (Cauchy tail event)
    let lightning_trigger = select(0.0, 1.0, fract(time * freq) < 0.1);
    
    let y_segment = fract(uv.y * 8.0);
    let bolt_width = 0.01 + sin(y_segment * 6.28) * 0.005;
    let x_jitter = sin(y_segment * 13.0 + seed) * 0.02;
    
    let dist_to_bolt = abs(uv.x + x_jitter - 0.5);
    bolt = lightning_trigger * smoothstep(bolt_width, 0.0, dist_to_bolt);
    
    return bolt;
}

// Cloud coverage gradient: beta distribution shaping
fn cloudCoverage(uv: vec2<f32>, alpha: f32, beta: f32, time: f32) -> f32 {
    let cloud_x = betaDistribution(fract(uv.x + time * 0.1), alpha, beta);
    let cloud_y = betaDistribution(fract(uv.y + time * 0.05), alpha, beta);
    
    let noise_val = sin(uv.x * 10.0 + time) * cos(uv.y * 10.0 + time * 0.7);
    let cloud_intensity = cloud_x * cloud_y + noise_val * 0.2;
    
    return smoothstep(0.3, 0.8, cloud_intensity);
}

// Wind flow vectors colored by velocity
fn windFlow(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let wind_angle = atan2(sin(uv.y * 3.0 + time), cos(uv.x * 3.0 + time));
    let wind_speed = 0.5 + 0.5 * sin(length(uv) * 5.0 - time);
    
    // Blue = calm, Red = hurricane
    let calm_color = vec3<f32>(0.2, 0.5, 0.9);
    let hurricane_color = vec3<f32>(1.0, 0.2, 0.2);
    
    return mix(calm_color, hurricane_color, wind_speed);
}

// Atmospheric haze with depth cues
fn atmosphericHaze(uv: vec2<f32>, depth: f32) -> f32 {
    let horizon_dist = abs(uv.y - 0.3);
    let haze = exp(-horizon_dist * horizon_dist * 2.0) * (1.0 - depth);
    return haze * 0.4;
}

// Crepuscular rays through cloud breaks
fn crepuscularRays(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let sun_pos = vec2<f32>(0.8 + 0.2 * sin(time * 0.3), 0.8);
    let ray_dir = normalize(uv - sun_pos);
    
    let ray_strength = max(0.0, dot(ray_dir, vec2<f32>(0.0, 1.0)));
    let rays = pow(ray_strength, 8.0) * vec3<f32>(1.0, 0.8, 0.5);
    
    return rays * 0.3;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let time = params.time * 0.1;
    
    // Initialize base colors
    var color = vec3<f32>(0.1, 0.15, 0.25); // dark sky base
    
    // ==== NORMAL DISTRIBUTIONS: Pressure Systems ====
    let pressure_center_1 = vec2<f32>(0.3, 0.4);
    let pressure_center_2 = vec2<f32>(0.7, 0.6);
    
    let spiral_1 = pressureSpiral(uv, pressure_center_1, time, 2.0);
    let spiral_2 = pressureSpiral(uv, pressure_center_2, time, 1.5);
    
    let pressure_1 = normalDistribution(length(uv - pressure_center_1), 0.0, 0.2) * 0.6;
    let pressure_2 = normalDistribution(length(uv - pressure_center_2), 0.0, 0.15) * 0.5;
    
    color = color + vec3<f32>(0.3, 0.4, 0.5) * (spiral_1 * 0.3 + pressure_1);
    color = color + vec3<f32>(0.2, 0.3, 0.6) * (spiral_2 * 0.25 + pressure_2);
    
    // ==== EXPONENTIAL DISTRIBUTION: Rain ====
    let rain = rainField(uv, time, 3.0);
    color = color + vec3<f32>(0.4, 0.5, 0.8) * rain * 0.4;
    
    // ==== CAUCHY DISTRIBUTION: Lightning ====
    let lightning = lightningBolt(uv, uv.x * uv.y, time);
    color = color + vec3<f32>(1.0, 1.0, 0.8) * lightning * 0.9;
    
    // ==== BETA DISTRIBUTION: Cloud Coverage ====
    let clouds_1 = cloudCoverage(uv, 2.0, 2.0, time);
    let clouds_2 = cloudCoverage(uv + vec2<f32>(0.5, 0.3), 3.0, 1.5, time * 0.7);
    
    let cloud_color = mix(vec3<f32>(0.6, 0.7, 0.85), vec3<f32>(0.3, 0.4, 0.6), clouds_1);
    color = mix(color, cloud_color, clouds_1 * 0.7);
    
    let dark_cloud = mix(vec3<f32>(0.2, 0.25, 0.35), vec3<f32>(0.1, 0.1, 0.15), clouds_2);
    color = mix(color, dark_cloud, clouds_2 * 0.5);
    
    // ==== WIND FLOW: Jet Stream Coloration ====
    let wind_color = windFlow(uv, time);
    let wind_intensity = length(sin(uv * 8.0 + time)) * 0.15;
    color = mix(color, wind_color, wind_intensity);
    
    // ==== ATMOSPHERIC EFFECTS ====
    let haze = atmosphericHaze(uv, length(uv - 0.5));
    color = color + vec3<f32>(0.8, 0.8, 1.0) * haze;
    
    // Crepuscular rays through breaks
    let rays = crepuscularRays(uv, time);
    color = color + rays * (1.0 - clouds_1) * (1.0 - rain);
    
    // ==== GROUND SHADOWS: Rolling Hills ====
    let horizon = 0.25;
    let hill_shadow = smoothstep(horizon, horizon + 0.1, uv.y) * 0.3;
    let ground_color = mix(vec3<f32>(0.15, 0.2, 0.1), vec3<f32>(0.25, 0.3, 0.2), 
                           sin(uv.x * 5.0) * 0.5 + 0.5);
    color = select(color, ground_color - vec3<f32>(hill_shadow), uv.y < horizon);
    
    // ==== MULTIVARIATE CORRELATIONS: Jet Stream Flow ====
    let correlation = sin(uv.x * 3.0 + time) * cos(uv.y * 3.0 + time);
    let jet_color = vec3<f32>(0.3 + correlation * 0.2, 0.5, 0.8 - correlation * 0.2);
    color = mix(color, jet_color, abs(correlation) * 0.15);
    
    // ==== TIME-LAPSE MOTION BLUR ====
    let motion_blur = sin(time * 0.5) * 0.1;
    color = color * (1.0 - motion_blur * 0.05);
    
    // ==== HDR TONE MAPPING ====
    color = color / (vec3<f32>(1.0) + color); // Reinhard tone mapping
    color = pow(color, vec3<f32>(1.0 / 2.2)); // Gamma correction
    
    // Clamp to valid range
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(color, 1.0);
}