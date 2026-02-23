// Apollonian Gasket - Rank-2 Kleinian Group Limit Set
// Red/Green interlaced facets via parity encoding

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
    _pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Möbius transformation: (az+b)/(cz+d)
fn mobius_apply(z: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>, d: vec2<f32>) -> vec2<f32> {
    let num_r = a.x * z.x - a.y * z.y + b.x;
    let num_i = a.x * z.y + a.y * z.x + b.y;
    let den_r = c.x * z.x - c.y * z.y + d.x;
    let den_i = c.x * z.y + c.y * z.x + d.y;
    let denom = den_r * den_r + den_i * den_i;
    if (denom < 1e-8) {
        return vec2<f32>(1e6, 1e6);
    }
    return vec2<f32>(
        (num_r * den_r + num_i * den_i) / denom,
        (num_i * den_r - num_r * den_i) / denom
    );
}

// Gaussian kernel for bloom
fn gaussian_blur_kernel(d: f32, sigma: f32) -> f32 {
    let sigma2 = sigma * sigma;
    return exp(-(d * d) / (2.0 * sigma2)) / (sigma * sqrt(6.28318530718));
}

// Hash-based pseudo-random for trajectory selection
fn hash_seed(seed: u32) -> f32 {
    let x = sin(f32(seed)) * 43758.5453;
    return fract(x);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    
    // Canvas: 2400×2400 with 120px padding → scale to fit [-3, 3]²
    let canvas_size = 2400.0;
    let padding = 120.0;
    let content_size = canvas_size - 2.0 * padding;
    let scale_factor = 6.0 / content_size;
    
    let px = (pos.x - padding) * scale_factor - 3.0;
    let py = (pos.y - padding) * scale_factor - 3.0;
    let sample_point = vec2<f32>(px, py);
    
    // Möbius generators (rank-2 Kleinian group)
    // M₁(z) = (2z+1)/(z+1)
    let m1_a = vec2<f32>(2.0, 0.0);
    let m1_b = vec2<f32>(1.0, 0.0);
    let m1_c = vec2<f32>(1.0, 0.0);
    let m1_d = vec2<f32>(1.0, 0.0);
    
    // M₂(z) = (2z-1)/(z-1)
    let m2_a = vec2<f32>(2.0, 0.0);
    let m2_b = vec2<f32>(-1.0, 0.0);
    let m2_c = vec2<f32>(1.0, 0.0);
    let m2_d = vec2<f32>(-1.0, 0.0);
    
    // Accumulate orbit density with color parity
    var color_accum = vec3<f32>(0.0, 0.0, 0.0);
    let num_trajectories = 128u;
    let depth_limit = 9u;
    let transient_skip = 12u;
    
    for (var traj = 0u; traj < num_trajectories; traj = traj + 1u) {
        let seed = traj + u32(params.time * 60.0) * 137u;
        var rng = hash_seed(seed);
        
        var z = vec2<f32>(0.0, 0.0);
        var parity = 0u;
        
        // Skip transient region
        for (var iter = 0u; iter < transient_skip; iter = iter + 1u) {
            rng = fract(rng * 6.18033988749895);
            if (rng < 0.5) {
                z = mobius_apply(z, m1_a, m1_b, m1_c, m1_d);
                parity = parity + 1u;
            } else {
                z = mobius_apply(z, m2_a, m2_b, m2_c, m2_d);
                parity = parity + 1u;
            }
        }
        
        // Plot orbit points with depth limit
        for (var depth = 0u; depth < depth_limit; depth = depth + 1u) {
            rng = fract(rng * 6.18033988749895);
            if (rng < 0.5) {
                z = mobius_apply(z, m1_a, m1_b, m1_c, m1_d);
                parity = (parity + 1u) & 1u;
            } else {
                z = mobius_apply(z, m2_a, m2_b, m2_c, m2_d);
                parity = (parity + 1u) & 1u;
            }
            
            let delta = z - sample_point;
            let dist_sq = delta.x * delta.x + delta.y * delta.y;
            let disk_radius_sq = 0.36 * scale_factor * scale_factor;
            
            if (dist_sq < disk_radius_sq) {
                let intensity = exp(-dist_sq / (2.0 * disk_radius_sq * 0.3));
                
                if (parity == 0u) {
                    color_accum = color_accum + vec3<f32>(1.0, 0.2, 0.33) * intensity * 0.01;
                } else {
                    color_accum = color_accum + vec3<f32>(0.2, 1.0, 0.33) * intensity * 0.01;
                }
            }
        }
    }
    
    // Bloom pass
    let bloom_sigma = 1.0;
    let bloom_radius = 3.0;
    var bloom_color = vec3<f32>(0.0, 0.0, 0.0);
    let bloom_samples = 16u;
    
    for (var i = 0u; i < bloom_samples; i = i + 1u) {
        let angle = f32(i) / f32(bloom_samples) * 6.28318530718;
        let r = bloom_radius;
        let offset = vec2<f32>(cos(angle) * r, sin(angle) * r) * scale_factor;
        let gauss_weight = gaussian_blur_kernel(r, bloom_sigma);
        bloom_color = bloom_color + color_accum * gauss_weight;
    }
    
    let final_color = color_accum + bloom_color * 0.4;
    let clamped = clamp(final_color, vec3<f32>(0.0), vec3<f32>(1.0));
    let gamma = pow(clamped, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(gamma, 1.0);
}