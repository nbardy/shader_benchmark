// COMPLEX ANALYSIS STAINED GLASS: f(z) = (z² - 1)/(z² + 1)
// Domain coloring with singularities as rose windows and lead came

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

// Complex number operations
fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cdiv(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = dot(b, b);
    return vec2<f32>(dot(a, b), a.y * b.x - a.x * b.y) / denom;
}

fn cabs(z: vec2<f32>) -> f32 {
    return length(z);
}

fn carg(z: vec2<f32>) -> f32 {
    return atan2(z.y, z.x);
}

// f(z) = (z² - 1)/(z² + 1)
fn complexFunction(z: vec2<f32>) -> vec2<f32> {
    let z2 = cmul(z, z);
    let numerator = z2 - vec2<f32>(1.0, 0.0);
    let denominator = z2 + vec2<f32>(1.0, 0.0);
    return cdiv(numerator, denominator);
}

// Domain coloring: hue from argument, brightness from magnitude
fn domainColor(z: vec2<f32>) -> vec3<f32> {
    let f_z = complexFunction(z);
    let magnitude = cabs(f_z);
    let argument = carg(f_z);
    
    // Hue from argument: map [-π, π] to [0, 1]
    let hue = (argument + 3.14159265359) / 6.28318530718;
    
    // HSV to RGB conversion
    let h = hue * 6.0;
    let i = floor(h);
    let f = h - i;
    let p = 0.0;
    let q = 1.0 - f;
    let t = f;
    
    var rgb = vec3<f32>(0.0);
    let idx = u32(i) % 6u;
    
    if (idx == 0u) {
        rgb = vec3<f32>(1.0, t, p);
    } else if (idx == 1u) {
        rgb = vec3<f32>(q, 1.0, p);
    } else if (idx == 2u) {
        rgb = vec3<f32>(p, 1.0, t);
    } else if (idx == 3u) {
        rgb = vec3<f32>(p, q, 1.0);
    } else if (idx == 4u) {
        rgb = vec3<f32>(t, p, 1.0);
    } else {
        rgb = vec3<f32>(1.0, p, q);
    }
    
    return rgb;
}

// Lead came at contours where |f(z)| = 2^n
fn leadCame(z: vec2<f32>) -> f32 {
    let f_z = complexFunction(z);
    let magnitude = cabs(f_z);
    let log_mag = log2(magnitude + 0.001);
    let frac = fract(log_mag);
    
    // Thin dark lines at integer powers
    let contour = smoothstep(0.05, 0.0, abs(frac - 0.5) - 0.02);
    return contour;
}

// Rose window pattern at poles (z = ±i)
fn roseWindow(z: vec2<f32>) -> f32 {
    let pole_i = vec2<f32>(0.0, 1.0);
    let pole_neg_i = vec2<f32>(0.0, -1.0);
    
    let dist_i = length(z - pole_i);
    let dist_neg_i = length(z - pole_neg_i);
    
    // Radial petals: 6-fold symmetry for simple poles
    let angle_i = atan2(z.y - pole_i.y, z.x - pole_i.x);
    let angle_neg_i = atan2(z.y - pole_neg_i.y, z.x - pole_neg_i.x);
    
    let petals = 6.0;
    let petal_i = sin(angle_i * petals) * 0.5 + 0.5;
    let petal_neg_i = sin(angle_neg_i * petals) * 0.5 + 0.5;
    
    // Radial gradient for rose window
    let rose_i = smoothstep(0.3, 0.1, dist_i) * petal_i;
    let rose_neg_i = smoothstep(0.3, 0.1, dist_neg_i) * petal_neg_i;
    
    return max(rose_i, rose_neg_i);
}

// Branch point spiral at z = ±1
fn branchSpiral(z: vec2<f32>) -> f32 {
    let bp_pos = vec2<f32>(1.0, 0.0);
    let bp_neg = vec2<f32>(-1.0, 0.0);
    
    let dist_pos = length(z - bp_pos);
    let dist_neg = length(z - bp_neg);
    
    let angle_pos = atan2(z.y - bp_pos.y, z.x - bp_pos.x);
    let angle_neg = atan2(z.y - bp_neg.y, z.x - bp_neg.x);
    
    // Logarithmic spiral: r ~ exp(θ)
    let spiral_pos = sin(angle_pos * 8.0 - log(dist_pos + 0.01) * 4.0) * 0.5 + 0.5;
    let spiral_neg = sin(angle_neg * 8.0 - log(dist_neg + 0.01) * 4.0) * 0.5 + 0.5;
    
    let branch_spiral_pos = smoothstep(0.25, 0.05, dist_pos) * spiral_pos;
    let branch_spiral_neg = smoothstep(0.25, 0.05, dist_neg) * spiral_neg;
    
    return max(branch_spiral_pos, branch_spiral_neg);
}

// Glass thickness variation: opacity modulated by |f(z)|
fn glassOpacity(z: vec2<f32>) -> f32 {
    let f_z = complexFunction(z);
    let magnitude = cabs(f_z);
    
    // Darker (opaque) where |f(z)| is small, transparent elsewhere
    let opacity = 1.0 - exp(-magnitude * 0.5);
    return clamp(opacity, 0.2, 1.0);
}

// Caustics: subtle wave pattern from light refraction
fn caustics(z: vec2<f32>, intensity: f32) -> f32 {
    let wave = sin(z.x * 8.0) * cos(z.y * 8.0) * 0.5 + 0.5;
    return wave * intensity;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates: center at origin, scale to view window
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Scale: zoom to show interesting features
    let zoom = 0.8;
    let z = uv / zoom;
    
    // Domain coloring
    let domain_color = domainColor(z);
    
    // Lead came overlay
    let lead = leadCame(z);
    
    // Singularity structures
    let rose = roseWindow(z);
    let spiral = branchSpiral(z);
    
    // Glass properties
    let opacity = glassOpacity(z);
    let caustic_intensity = caustics(z, 0.15);
    
    // Composite: domain color + lead came + singularity structures
    var glass_color = domain_color;
    
    // Add lead came as dark grid
    glass_color = mix(glass_color, vec3<f32>(0.1, 0.08, 0.05), lead * 0.8);
    
    // Brighten rose windows with gold/amber light
    let rose_color = vec3<f32>(1.0, 0.85, 0.3) * rose;
    glass_color = mix(glass_color, rose_color, rose * 0.6);
    
    // Branch spirals in pale violet
    let spiral_color = vec3<f32>(0.9, 0.7, 1.0) * spiral;
    glass_color = mix(glass_color, spiral_color, spiral * 0.5);
    
    // Caustic shimmer
    glass_color = glass_color + vec3<f32>(caustic_intensity) * 0.1;
    
    // Stone frame border (pointed arch)
    let frame_width = 0.15;
    let frame_dist = min(
        min(abs(uv.x) - 0.9, abs(uv.y) - 1.1),
        length(uv - vec2<f32>(0.0, 0.9)) - 0.3
    );
    
    if (frame_dist > -frame_width) {
        // Stone color: gray with slight texture
        let stone_noise = sin(z.x * 15.0) * sin(z.y * 15.0) * 0.1 + 0.5;
        let stone_color = vec3<f32>(0.4, 0.38, 0.35) * stone_noise;
        glass_color = mix(glass_color, stone_color, smoothstep(0.0, frame_width, -frame_dist));
    }
    
    // Final composite: realistic glass with depth
    let final_color = glass_color * opacity;
    
    // Subtle vignette for cathedral interior
    let vignette = 1.0 - length(uv) * 0.3;
    let cathedral_lighting = final_color * vignette * 0.95 + vec3<f32>(0.05);
    
    return vec4<f32>(cathedral_lighting, 1.0);
}