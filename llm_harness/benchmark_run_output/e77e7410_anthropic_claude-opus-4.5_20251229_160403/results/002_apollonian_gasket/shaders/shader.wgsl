// Apollonian Gasket via Kleinian Group Limit Set
// Using Möbius transformations M₁(z) = (2z+1)/(z+1), M₂(z) = (2z-1)/(z-1)

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// Complex number operations
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cdiv(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = dot(b, b);
    if (denom < 1e-10) {
        return vec2<f32>(1e6, 0.0);
    }
    return vec2<f32>(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / denom;
}

// M₁(z) = (2z+1)/(z+1)
fn mobius1(z: vec2<f32>) -> vec2<f32> {
    let num = vec2<f32>(2.0 * z.x + 1.0, 2.0 * z.y);
    let den = vec2<f32>(z.x + 1.0, z.y);
    return cdiv(num, den);
}

// M₁⁻¹(z) = (1-z)/(z-2)
fn mobius1_inv(z: vec2<f32>) -> vec2<f32> {
    let num = vec2<f32>(1.0 - z.x, -z.y);
    let den = vec2<f32>(z.x - 2.0, z.y);
    return cdiv(num, den);
}

// M₂(z) = (2z-1)/(z-1)
fn mobius2(z: vec2<f32>) -> vec2<f32> {
    let num = vec2<f32>(2.0 * z.x - 1.0, 2.0 * z.y);
    let den = vec2<f32>(z.x - 1.0, z.y);
    return cdiv(num, den);
}

// M₂⁻¹(z) = (z-1)/(z-2)
fn mobius2_inv(z: vec2<f32>) -> vec2<f32> {
    let num = vec2<f32>(z.x - 1.0, z.y);
    let den = vec2<f32>(z.x - 2.0, z.y);
    return cdiv(num, den);
}

// Hash function for pseudo-random number generation
fn hash(p: vec2<f32>) -> f32 {
    var p3 = fract(vec3<f32>(p.x, p.y, p.x) * 0.1031);
    p3 = p3 + dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn hash2(seed: f32) -> vec2<f32> {
    let s = seed * 1.618033988749;
    return vec2<f32>(
        fract(sin(s * 12.9898) * 43758.5453),
        fract(sin(s * 78.233) * 43758.5453)
    );
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let size = min(res.x, res.y);
    
    // Map pixel to complex plane with padding
    let padding = 120.0;
    let scale = (size - 2.0 * padding) / 4.0;
    let center = res * 0.5;
    
    let pixel_z = vec2<f32>(
        (pos.x - center.x) / scale,
        (pos.y - center.y) / scale
    );
    
    // Accumulate color through orbit sampling
    var red_accum: f32 = 0.0;
    var green_accum: f32 = 0.0;
    
    // Multiple random walks to accumulate orbit points
    let num_walks = 64u;
    let steps_per_walk = 48u;
    let burn_in = 12u;
    
    for (var walk = 0u; walk < num_walks; walk = walk + 1u) {
        // Seed the walk with pixel-dependent randomness
        var seed = hash(pos.xy + vec2<f32>(f32(walk) * 7.31, f32(walk) * 13.17));
        
        // Start from seed point z₀ = 0
        var z = vec2<f32>(0.0, 0.0);
        var parity = 0u; // Track word length parity
        var last_gen = 0u; // Track which generator was last used
        
        // Random walk through the group
        for (var step = 0u; step < steps_per_walk + burn_in; step = step + 1u) {
            // Generate random choice for generator (4 choices: M1, M1^-1, M2, M2^-1)
            seed = fract(seed * 1.61803398875 + 0.31415926535);
            let choice = u32(seed * 4.0);
            
            // Apply chosen Möbius transformation
            if (choice == 0u) {
                z = mobius1(z);
                last_gen = 1u;
            } else if (choice == 1u) {
                z = mobius1_inv(z);
                last_gen = 1u;
            } else if (choice == 2u) {
                z = mobius2(z);
                last_gen = 2u;
            } else {
                z = mobius2_inv(z);
                last_gen = 2u;
            }
            
            parity = parity + 1u;
            
            // Skip burn-in period
            if (step < burn_in) {
                continue;
            }
            
            // Check if orbit point is near our pixel
            let dist = length(z - pixel_z);
            let radius = 0.6 / scale; // Sub-pixel disk radius
            
            if (dist < radius * 3.0) {
                // Soft falloff for anti-aliasing
                let intensity = exp(-dist * dist / (radius * radius * 2.0));
                
                // Color based on word length parity
                if ((parity % 2u) == 0u) {
                    red_accum = red_accum + intensity;
                } else {
                    green_accum = green_accum + intensity;
                }
            }
            
            // Clamp to prevent overflow
            if (length(z) > 100.0) {
                z = vec2<f32>(0.0, 0.0);
                parity = 0u;
            }
        }
    }
    
    // Additional dense sampling in local neighborhood for detail
    let local_samples = 128u;
    for (var s = 0u; s < local_samples; s = s + 1u) {
        var seed = hash(pos.xy * 0.01 + vec2<f32>(f32(s) * 0.173, f32(s) * 0.291));
        
        // Start from various seed points near the limit set
        var z = vec2<f32>(
            (seed - 0.5) * 0.1,
            (fract(seed * 7.31) - 0.5) * 0.1
        );
        var parity = 0u;
        
        for (var step = 0u; step < 64u; step = step + 1u) {
            seed = fract(seed * 2.618033988749 + 0.577215664901);
            let choice = u32(seed * 4.0);
            
            if (choice == 0u) {
                z = mobius1(z);
            } else if (choice == 1u) {
                z = mobius1_inv(z);
            } else if (choice == 2u) {
                z = mobius2(z);
            } else {
                z = mobius2_inv(z);
            }
            
            parity = parity + 1u;
            
            if (step < 8u) {
                continue;
            }
            
            let dist = length(z - pixel_z);
            let radius = 0.6 / scale;
            
            if (dist < radius * 4.0) {
                let intensity = exp(-dist * dist / (radius * radius * 1.5)) * 0.5;
                
                if ((parity % 2u) == 0u) {
                    red_accum = red_accum + intensity;
                } else {
                    green_accum = green_accum + intensity;
                }
            }
            
            if (length(z) > 50.0) {
                z = vec2<f32>(0.0, 0.0);
                parity = 0u;
            }
        }
    }
    
    // Normalize and apply tone mapping
    let norm_factor = 0.15;
    red_accum = red_accum * norm_factor;
    green_accum = green_accum * norm_factor;
    
    // Apply soft tone mapping for HDR-like glow
    let red_mapped = 1.0 - exp(-red_accum);
    let green_mapped = 1.0 - exp(-green_accum);
    
    // Target colors: red (#ff3355) and green (#33ff55)
    let red_color = vec3<f32>(1.0, 0.2, 0.333);
    let green_color = vec3<f32>(0.2, 1.0, 0.333);
    
    // Combine colors with additive blending
    var color = red_color * red_mapped + green_color * green_mapped;
    
    // Simple Gaussian bloom approximation
    // Sample neighboring accumulated values conceptually
    let bloom_intensity = (red_mapped + green_mapped) * 0.4;
    let bloom_color = (red_color * red_mapped + green_color * green_mapped) * 0.4;
    
    // Add glow effect for high-density regions
    let glow = max(red_mapped, green_mapped);
    let glow_boost = smoothstep(0.3, 0.8, glow) * 0.3;
    color = color + vec3<f32>(glow_boost * 0.5, glow_boost * 0.5, glow_boost * 0.8);
    
    // Clamp final color
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(color, 1.0);
}