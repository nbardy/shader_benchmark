// Fractal Loxodromic Möbius Transformation Spiral Renderer
// Generates self-similar spiral structures via complex iteration in 3D space

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
fn complex_mul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn complex_div(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = dot(b, b);
    return vec2<f32>(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / denom;
}

fn complex_add(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return a + b;
}

// Möbius transformation: f(z) = (az+b)/(cz+d)
// a = 1.2·exp(iπ/6), b = 0.1, c = 0.1i, d = 1.0
fn mobius_transform(z: vec2<f32>) -> vec2<f32> {
    // a = 1.2 * (cos(π/6) + i*sin(π/6)) ≈ 1.2 * (0.866 + 0.5i)
    let a = vec2<f32>(1.039, 0.6);
    let b = vec2<f32>(0.1, 0.0);
    let c = vec2<f32>(0.0, 0.1);
    let d = vec2<f32>(1.0, 0.0);
    
    let numerator = complex_add(complex_mul(a, z), b);
    let denominator = complex_add(complex_mul(c, z), d);
    return complex_div(numerator, denominator);
}

// Stereographic projection from complex plane to 3D sphere
fn stereographic_projection(z: vec2<f32>) -> vec3<f32> {
    let z_mag_sq = dot(z, z);
    let scale = 2.0 / (1.0 + z_mag_sq);
    let x = scale * z.x;
    let y = scale * z.y;
    let z_coord = (z_mag_sq - 1.0) / (z_mag_sq + 1.0);
    return vec3<f32>(x, y, z_coord);
}

// Color mapping by iteration count with purple→orange gradient
fn iteration_color(iter: u32, max_iter: u32) -> vec3<f32> {
    let t = f32(iter) / f32(max_iter);
    
    // Deep purple to bright orange
    let purple = vec3<f32>(0.4, 0.0, 0.8);
    let orange = vec3<f32>(1.0, 0.65, 0.0);
    
    let color = mix(purple, orange, t);
    
    // Add emission intensity near fixed points (higher iterations)
    let emission = pow(t, 0.5) * 0.4;
    
    return color + vec3<f32>(emission * 0.5);
}

// Distance field for glowing tubes
fn compute_trajectory_field(pixel_pos: vec2<f32>, trajectory_points: array<vec3<f32>, 50>, point_count: u32) -> f32 {
    var min_dist = 1000.0;
    
    // Sample trajectory distances (unrolled for WGSL constraints)
    for (var i = 0u; i < point_count; i = i + 1u) {
        let p = trajectory_points[i];
        let screen_pos = vec2<f32>(p.x, p.y) * 300.0 + params.resolution * 0.5;
        let dist = length(pixel_pos - screen_pos);
        let tube_radius = 3.0 * (1.0 - f32(i) / f32(point_count));
        min_dist = min(min_dist, max(0.0, dist - tube_radius));
    }
    
    return min_dist;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates with camera offset
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Black background with fog
    var final_color = vec3<f32>(0.0);
    var accumulated_alpha = 0.0;
    
    // Generate orbits from initial points on circle |z| = 1.5
    let num_initial_points = 12u;
    
    for (var init_idx = 0u; init_idx < num_initial_points; init_idx = init_idx + 1u) {
        // Initial point on circle
        let angle = 6.283185 * f32(init_idx) / f32(num_initial_points);
        var z = vec2<f32>(cos(angle), sin(angle)) * 1.5;
        
        var trajectory_points: array<vec3<f32>, 50>;
        var point_count = 0u;
        
        // Iterate transformation up to 50 times
        for (var iter = 0u; iter < 50u; iter = iter + 1u) {
            // Store point in trajectory
            if (point_count < 50u) {
                trajectory_points[point_count] = stereographic_projection(z);
                point_count = point_count + 1u;
            }
            
            // Apply Möbius transformation
            z = mobius_transform(z);
            
            // Bailout condition
            let mag = length(z);
            if (mag > 10.0) {
                break;
            }
        }
        
        // Compute distance field for this trajectory
        let traj_dist = compute_trajectory_field(pos.xy, trajectory_points, point_count);
        
        // Create glowing tube with anti-aliasing
        let tube_glow = exp(-traj_dist * traj_dist * 0.02);
        let glow_intensity = 1.0 - smoothstep(0.0, 8.0, traj_dist);
        
        // Get color from iteration count
        let traj_color = iteration_color(point_count, 50u);
        
        // Add glow with HDR bloom
        let bloom_factor = pow(glow_intensity, 2.0) * 1.5;
        let glowing_color = traj_color * bloom_factor;
        
        // Accumulate with depth sorting
        final_color = final_color + glowing_color * (1.0 - accumulated_alpha);
        accumulated_alpha = accumulated_alpha + glow_intensity * 0.3;
        
        if (accumulated_alpha >= 0.95) {
            break;
        }
    }
    
    // Add blue fog for depth
    let fog_color = vec3<f32>(0.1, 0.2, 0.4);
    let fog_strength = 0.3;
    final_color = mix(final_color, fog_color, fog_strength * (1.0 - accumulated_alpha));
    
    // Clamp to prevent overflow on very bright pixels
    final_color = min(final_color, vec3<f32>(2.0, 2.0, 2.0));
    
    return vec4<f32>(final_color, 1.0);
}