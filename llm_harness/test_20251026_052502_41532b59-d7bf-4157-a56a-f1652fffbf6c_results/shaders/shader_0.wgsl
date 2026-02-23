// Logarithmic Spiral Motion Visualization
// 8 particle streams following exponential spiral trajectories
// with HDR emission, motion trails, and radial gradient background

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

// Constants for spiral mathematics
const K_GROWTH: f32 = 0.15;           // Exponential growth rate
const OMEGA: f32 = 1.5707963267949;  // Angular velocity (π/2)
const V_VERTICAL: f32 = 0.3;          // Vertical velocity
const T_MAX: f32 = 20.0;              // Time parameter max
const NUM_STREAMS: f32 = 8.0;         // Number of spiral arms
const PARTICLES_PER_STREAM: f32 = 100.0;

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let hp = (h % 6.283185307) / 1.047197551;  // 2π / 6
    let x = c * (1.0 - abs((hp % 2.0) - 1.0));
    
    var rgb = vec3<f32>(0.0);
    if (hp < 1.0) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (hp < 2.0) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (hp < 3.0) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (hp < 4.0) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (hp < 5.0) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    let m = v - c;
    return rgb + vec3<f32>(m);
}

// Logarithmic spiral in cylindrical coordinates
fn spiral_position(stream_idx: f32, particle_idx: f32, t: f32) -> vec3<f32> {
    let theta_offset = (stream_idx / NUM_STREAMS) * 6.283185307;  // 2π
    let t_offset = (particle_idx / PARTICLES_PER_STREAM) * T_MAX;
    
    let time_param = t_offset + t;
    
    // Spiral equations:
    // r(t) = exp(k*t)
    // θ(t) = θ₀ + ω*t
    // z(t) = h₀ + v*t
    let r = exp(K_GROWTH * time_param);
    let theta = theta_offset + OMEGA * time_param;
    let z = V_VERTICAL * time_param;
    
    // Convert cylindrical to Cartesian
    let x = r * cos(theta);
    let y = r * sin(theta);
    
    return vec3<f32>(x, z - 3.0, y);
}

// Particle size scaling
fn particle_size(t: f32) -> f32 {
    // Size shrinks as spiral expands: exp(-k*t/2)
    return exp(-K_GROWTH * t / 2.0) * 0.1;
}

// Ray-sphere intersection for particle rendering
fn ray_sphere(ray_pos: vec3<f32>, ray_dir: vec3<f32>, sphere_center: vec3<f32>, radius: f32) -> f32 {
    let oc = ray_pos - sphere_center;
    let a = dot(ray_dir, ray_dir);
    let b = 2.0 * dot(oc, ray_dir);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return -1.0;
    }
    
    let t1 = (-b - sqrt(discriminant)) / (2.0 * a);
    let t2 = (-b + sqrt(discriminant)) / (2.0 * a);
    
    if (t1 > 0.0001) { return t1; }
    if (t2 > 0.0001) { return t2; }
    return -1.0;
}

// Glow contribution from a particle
fn glow_contribution(ray_origin: vec3<f32>, particle_pos: vec3<f32>, particle_size_val: f32, stream_idx: f32) -> vec3<f32> {
    let to_particle = particle_pos - ray_origin;
    let dist = length(to_particle);
    
    // Exponential falloff with distance
    let glow_radius = particle_size_val * 2.5;
    let attenuation = exp(-dist / (glow_radius + 0.01));
    
    // Color based on stream index
    let hue = (stream_idx / NUM_STREAMS) * 6.283185307;
    let color = hsv_to_rgb(hue, 0.8, 1.0);
    
    // Intensity fades exponentially from center
    let center_dist = length(particle_pos);
    let intensity = exp(-center_dist * 0.1) * attenuation;
    
    return color * intensity * 2.0;  // HDR emission
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates to [-1, 1]
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    let aspect = params.resolution.x / params.resolution.y;
    let uv_corrected = vec2<f32>(uv.x * aspect, uv.y);
    
    // Background: radial gradient
    let center_dist = length(uv_corrected);
    let bg_intensity = exp(-center_dist * center_dist * 0.5);
    let bg_color = vec3<f32>(0.01, 0.01, 0.03) * (0.2 + bg_intensity * 0.3);
    
    var accumulated_color = bg_color;
    
    // Simple time parameter (animation)
    let time_anim = 0.0;  // Static frame; can be animated externally
    
    // Ray parameters (simple orthographic projection)
    let ray_origin = vec3<f32>(uv_corrected.x * 3.0, uv_corrected.y * 3.0, 5.0);
    let ray_dir = normalize(vec3<f32>(0.0, 0.0, -1.0));
    
    // Iterate through all particle streams
    var stream_idx: u32 = 0u;
    loop {
        if (stream_idx >= 8u) { break; }
        
        let stream_f = f32(stream_idx);
        
        // Iterate through particles in stream
        var particle_idx: u32 = 0u;
        loop {
            if (particle_idx >= 100u) { break; }
            
            let particle_f = f32(particle_idx);
            let t_param = particle_f / PARTICLES_PER_STREAM * T_MAX;
            
            // Get particle position
            let pos_particle = spiral_position(stream_f, particle_f, time_anim);
            
            // Calculate particle size
            let p_size = particle_size(t_param);
            
            // Add glow from this particle
            let glow = glow_contribution(ray_origin, pos_particle, p_size, stream_f);
            accumulated_color = accumulated_color + glow;
            
            particle_idx = particle_idx + 1u;
        }
        
        stream_idx = stream_idx + 1u;
    }
    
    // Central attractor: bright white sphere
    let attractor_pos = vec3<f32>(0.0, -3.0, 0.0);
    let attractor_dist = length(ray_origin - attractor_pos);
    let attractor_glow = exp(-attractor_dist * 0.5) * vec3<f32>(2.0, 2.0, 2.0);
    accumulated_color = accumulated_color + attractor_glow;
    
    // Tone mapping for HDR
    let mapped = accumulated_color / (accumulated_color + vec3<f32>(1.0));
    
    // Gamma correction
    let final_color = pow(mapped, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(final_color, 1.0);
}