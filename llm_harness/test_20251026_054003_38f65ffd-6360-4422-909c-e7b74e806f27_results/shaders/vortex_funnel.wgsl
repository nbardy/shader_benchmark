// Vortex Funnel Fluid Flow Visualization
// Scalar field: ρ(r,z) = exp(-(r/2)²) * exp(-(z/6)²)
// Tangential velocity: v_θ = 4/r
// 150 streamlines from r=0.5-3.0, z=0 to z=-6

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

fn scalarField(r: f32, z: f32) -> f32 {
    let r_term = (r / 2.0) * (r / 2.0);
    let z_term = (z / 6.0) * (z / 6.0);
    return exp(-r_term) * exp(-z_term);
}

fn tangentialVelocity(r: f32) -> f32 {
    return select(0.0, 4.0 / r, r > 0.01);
}

fn cylindricalToCartesian(r: f32, theta: f32, z: f32) -> vec3<f32> {
    return vec3<f32>(r * cos(theta), z, r * sin(theta));
}

fn cartesianToCylindrical(pos: vec3<f32>) -> vec3<f32> {
    let r = length(vec2<f32>(pos.x, pos.z));
    let theta = atan2(pos.z, pos.x);
    return vec3<f32>(r, theta, pos.y);
}

fn projectToScreen(pos: vec3<f32>, aspect: f32) -> vec2<f32> {
    let scale = 0.15;
    let x = pos.x * scale * aspect;
    let y = (pos.y / 6.0 + 0.5) * 0.8;
    return vec2<f32>(0.5 + x, 0.5 + y);
}

fn sampleStreamline(r_start: f32, theta_start: f32, t: f32) -> vec3<f32> {
    var r = r_start;
    var theta = theta_start;
    var z = 0.0;
    
    let dt = 0.02;
    let steps = u32(t / dt);
    
    var iter: u32 = 0u;
    loop {
        if (iter >= steps || iter >= 300u) { break; }
        
        let v_theta = tangentialVelocity(r);
        let dtheta = v_theta / max(r, 0.1);
        
        let sinking = -0.15;
        let dz = sinking;
        
        theta = theta + dtheta * dt;
        z = z + dz * dt;
        
        if (z < -6.5 || r > 3.5) { break; }
        
        iter = iter + 1u;
    }
    
    return vec3<f32>(r, theta, z);
}

fn distanceToStreamline(
    screen_pos: vec2<f32>,
    r_start: f32,
    theta_start: f32,
    aspect: f32
) -> f32 {
    var min_dist = 1000.0;
    
    let num_points = 120u;
    var i: u32 = 0u;
    loop {
        if (i >= num_points) { break; }
        
        let t = f32(i) / f32(num_points) * 4.0;
        let cyl_pos = sampleStreamline(r_start, theta_start, t);
        
        let cart_pos = cylindricalToCartesian(cyl_pos.x, cyl_pos.y, cyl_pos.z);
        let proj = projectToScreen(cart_pos, aspect);
        
        let dist = length(screen_pos - proj);
        min_dist = min(min_dist, dist);
        
        i = i + 1u;
    }
    
    return min_dist;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let screen_uv = pos.xy / params.resolution;
    
    // Background: dark gradient
    var color = vec3<f32>(0.05, 0.08, 0.12);
    
    // Sample 150 streamlines
    let num_streamlines = 150u;
    var streamline_idx: u32 = 0u;
    loop {
        if (streamline_idx >= num_streamlines) { break; }
        
        let t = f32(streamline_idx) / f32(num_streamlines);
        
        let r_start = 0.5 + t * 2.5;
        let theta_start = (t * 6.283185307);
        
        let dist = distanceToStreamline(pos.xy, r_start, theta_start, aspect);
        
        let line_width = 1.2;
        let streamline_alpha = smoothstep(line_width, 0.0, dist);
        
        let line_color = vec3<f32>(0.2, 0.6 + 0.3 * sin(t * 3.14159), 0.9);
        color = mix(color, line_color, streamline_alpha * 0.7);
        
        streamline_idx = streamline_idx + 1u;
    }
    
    // Sample scalar field density for background coloring
    let center_uv = screen_uv - vec2<f32>(0.5, 0.5);
    let sample_r = length(center_uv) * 4.0;
    let sample_z = (screen_uv.y - 0.5) * -6.0;
    
    let rho = scalarField(max(sample_r, 0.1), sample_z);
    let density_color = vec3<f32>(0.1, 0.15 + rho * 0.3, 0.25 + rho * 0.4);
    
    color = mix(color, density_color, 0.3);
    
    // Add subtle vignette
    let vignette = 1.0 - length(center_uv) * 0.4;
    color = color * vignette;
    
    // Ensure color stays in valid range
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(color, 1.0);
}