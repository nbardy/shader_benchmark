// Archimedean spiral galaxy renderer
// Two-arm spiral with stellar populations and black-body color mapping

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

// Pseudo-random number generator (xorshift64)
fn prng(seed: ptr<function, u64>) -> f32 {
    var x = *seed;
    x = x ^ (x << 13u);
    x = x ^ (x >> 7u);
    x = x ^ (x << 17u);
    *seed = x;
    return f32(x & 0xFFFFFFFFu) / 4294967296.0;
}

fn prng_seed(pixel_id: u32, frame: u32) -> u64 {
    let a = u64(pixel_id) * 73856093u;
    let b = u64(frame) * 19349663u;
    return a ^ b ^ 0x9e3779b97f4a7c15u;
}

// Black-body radiation to sRGB approximation
fn blackbody_to_rgb(temp_k: f32) -> vec3<f32> {
    let t = temp_k / 1000.0;
    
    var r = 1.0;
    var g = 1.0;
    var b = 1.0;
    
    if (t < 6.6) {
        r = 1.0;
        g = clamp(0.39008157876901960784 * log(t) - 0.63184144378862883141, 0.0, 1.0);
        b = select(0.0, clamp(0.54320678911019814727 * log(t - 10.0) + 0.988081746769100725, 0.0, 1.0), t > 19.0);
    } else {
        r = clamp(1.29293618606274127089 * pow(t - 60.0, -0.1332047592), 0.0, 1.0);
        g = clamp(0.97540615450934413434 * pow(t - 60.0, -0.0755148492), 0.0, 1.0);
        b = 1.0;
    }
    
    return vec3<f32>(r, g, b);
}

// Gaussian function for star sprites
fn gaussian_2d(dx: f32, dy: f32, fwhm: f32) -> f32 {
    let sigma = fwhm / 2.355;
    let sigma2 = sigma * sigma;
    let dist2 = dx * dx + dy * dy;
    return exp(-dist2 / (2.0 * sigma2));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let uv = pos.xy / res;
    let pixel_coord = pos.xy;
    
    // Map to galaxy coordinates: [-10, 10] in both axes
    let galaxy_x = (uv.x - 0.5) * 20.0;
    let galaxy_y = (uv.y - 0.5) * 20.0;
    
    var accum_color = vec3<f32>(0.0);
    var accum_alpha = 0.0;
    
    // Constants
    let spiral_a = 0.25;
    let theta_max = 8.0 * 3.141592653589793;
    let sigma_theta = 0.035;
    let sigma_r_base = 0.025;
    let radial_falloff = 3.0;
    let halo_r_max = 10.0;
    let halo_falloff = 3.0;
    
    // Stellar arms generation
    var seed = prng_seed(u32(pixel_coord.x + pixel_coord.y * 3000.0), 0u);
    
    let num_samples = 40u;
    for (var sample_idx = 0u; sample_idx < num_samples; sample_idx = sample_idx + 1u) {
        let theta_norm = prng(&seed);
        let theta = theta_norm * theta_max;
        
        let r_spiral = spiral_a * theta;
        
        let u1 = prng(&seed);
        let u2 = prng(&seed);
        let z0 = sqrt(-2.0 * log(max(u1, 1e-6)));
        let z1 = 6.283185307179586 * u2;
        let delta_theta = z0 * cos(z1) * sigma_theta;
        
        let u3 = prng(&seed);
        let u4 = prng(&seed);
        let z2 = sqrt(-2.0 * log(max(u3, 1e-6)));
        let z3 = 6.283185307179586 * u4;
        let sigma_r = sigma_r_base * (1.0 + 0.5 * theta / theta_max);
        let delta_r = z2 * cos(z3) * sigma_r;
        
        let r_perturbed = r_spiral + delta_r;
        let theta_perturbed = theta + delta_theta;
        
        let density_weight = exp(-r_perturbed / radial_falloff);
        let u_keep = prng(&seed);
        if (u_keep >= density_weight) {
            continue;
        }
        
        for (var arm_idx = 0u; arm_idx < 2u; arm_idx = arm_idx + 1u) {
            let arm_offset = f32(arm_idx) * 3.141592653589793;
            let theta_arm = theta_perturbed + arm_offset;
            
            let star_x = r_perturbed * cos(theta_arm);
            let star_y = r_perturbed * sin(theta_arm);
            
            let dx = galaxy_x - star_x;
            let dy = galaxy_y - star_y;
            
            let brightness = exp(-0.5 * r_perturbed);
            let temp_k = 7200.0 - 250.0 * r_perturbed;
            let star_color = blackbody_to_rgb(max(temp_k, 2000.0)) * brightness;
            
            let fwhm = 0.03 + 0.004 * r_perturbed;
            let sprite_intensity = gaussian_2d(dx, dy, fwhm);
            
            accum_color = accum_color + star_color * sprite_intensity;
            accum_alpha = accum_alpha + sprite_intensity;
        }
    }
    
    // Halo stars
    let num_halo_samples = 3u;
    for (var halo_idx = 0u; halo_idx < num_halo_samples; halo_idx = halo_idx + 1u) {
        let u_angle = prng(&seed);
        let angle = u_angle * 6.283185307179586;
        
        let u_radius = prng(&seed);
        let r_halo = -halo_falloff * log(1.0 - u_radius * (1.0 - exp(-halo_r_max / halo_falloff)));
        
        let halo_x = r_halo * cos(angle);
        let halo_y = r_halo * sin(angle);
        
        let dx = galaxy_x - halo_x;
        let dy = galaxy_y - halo_y;
        let dist = sqrt(dx * dx + dy * dy);
        
        if (dist < 0.1) {
            accum_color = accum_color + vec3<f32>(1.0);
            accum_alpha = accum_alpha + 1.0;
        }
    }
    
    // Core glow
    let dist_core = sqrt(galaxy_x * galaxy_x + galaxy_y * galaxy_y);
    let bloom_radius = 0.4;
    let bloom_intensity = exp(-dist_core * dist_core / (2.0 * bloom_radius * bloom_radius));
    let bloom_color = vec3<f32>(1.0, 1.0, 0.66667) * 0.6 * bloom_intensity;
    
    accum_color = accum_color + bloom_color;
    
    var final_color = vec3<f32>(0.0);
    if (accum_alpha > 0.0) {
        final_color = accum_color / (accum_alpha + 1.0);
    } else {
        final_color = accum_color;
    }
    
    // sRGB gamma correction
    final_color = pow(final_color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(final_color, 1.0);
}