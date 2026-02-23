// Differential Equations as Living Water Surfaces
// Renders wave equation, heat equation, and Schrödinger equation as fluid dynamics
// Time frozen at t=2.5 with photorealistic water rendering

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

// Wave equation solution: ∂²u/∂t² = c²∇²u - γ∂u/∂t
fn wave_equation(pos: vec2<f32>, t: f32) -> f32 {
    let k = 2.0;  // wavenumber
    let omega = 1.5;  // frequency
    let gamma = 0.3;  // damping
    
    let wave_front = sin(k * length(pos) - omega * t) * exp(-gamma * t);
    let circular_wave = cos(k * pos.x - omega * t) * cos(k * pos.y - omega * t) * exp(-gamma * t);
    
    return wave_front * 0.6 + circular_wave * 0.4;
}

// Heat equation solution: ∂u/∂t = α∇²u (Gaussian diffusion)
fn heat_equation(pos: vec2<f32>, t: f32) -> f32 {
    let alpha = 0.5;  // diffusion coefficient
    let sigma = sqrt(4.0 * alpha * t);
    
    let gauss1 = exp(-dot(pos - vec2<f32>(1.5, 1.5), pos - vec2<f32>(1.5, 1.5)) / (sigma * sigma + 0.1));
    let gauss2 = exp(-dot(pos - vec2<f32>(-1.5, -1.5), pos - vec2<f32>(-1.5, -1.5)) / (sigma * sigma + 0.1));
    let gauss3 = exp(-dot(pos + vec2<f32>(0.8, 0.0), pos + vec2<f32>(0.8, 0.0)) / (sigma * sigma + 0.1));
    
    return gauss1 * 0.5 + gauss2 * 0.3 + gauss3 * 0.2;
}

// Schrödinger equation solution: i∂u/∂t = -∇²u + Vu (probability amplitude)
fn schrodinger_equation(pos: vec2<f32>, t: f32) -> f32 {
    let k = 1.8;
    let phase = sin(t * 2.0);
    
    let psi_real = sin(k * pos.x) * sin(k * pos.y) * cos(t);
    let psi_imag = sin(k * pos.x + 1.0) * sin(k * pos.y + 1.0) * sin(t);
    
    let probability = psi_real * psi_real + psi_imag * psi_imag;
    
    return probability;
}

// Compute solution gradient for foam detection
fn compute_gradient(eq_type: i32, pos: vec2<f32>, t: f32) -> vec2<f32> {
    let eps = 0.01;
    var u_center = 0.0;
    var u_x = 0.0;
    var u_y = 0.0;
    
    if (eq_type == 0) {
        u_center = wave_equation(pos, t);
        u_x = wave_equation(pos + vec2<f32>(eps, 0.0), t);
        u_y = wave_equation(pos + vec2<f32>(0.0, eps), t);
    } else if (eq_type == 1) {
        u_center = heat_equation(pos, t);
        u_x = heat_equation(pos + vec2<f32>(eps, 0.0), t);
        u_y = heat_equation(pos + vec2<f32>(0.0, eps), t);
    } else {
        u_center = schrodinger_equation(pos, t);
        u_x = schrodinger_equation(pos + vec2<f32>(eps, 0.0), t);
        u_y = schrodinger_equation(pos + vec2<f32>(0.0, eps), t);
    }
    
    return vec2<f32>((u_x - u_center) / eps, (u_y - u_center) / eps);
}

// Photorealistic water caustics based on solution
fn caustics(pos: vec2<f32>, u: f32) -> f32 {
    let freq = 8.0;
    let pattern = sin(pos.x * freq + u * 3.0) * sin(pos.y * freq + u * 3.0);
    let caustic = abs(pattern) * 0.6 + 0.2;
    
    return caustic;
}

// Convert solution value to water color with subsurface scattering
fn solution_to_color(eq_type: i32, u: f32, grad_mag: f32, pos: vec2<f32>) -> vec3<f32> {
    let t = 2.5;
    let grad = compute_gradient(eq_type, pos, t);
    let grad_magnitude = length(grad);
    
    // Golden hour lighting: sun at 15° elevation
    let sun_dir = normalize(vec3<f32>(0.86, 0.26, 0.43));
    let light_intensity = 0.8;
    
    var color = vec3<f32>(0.0);
    
    if (eq_type == 0) {
        // Wave equation: clear blue water
        let water_base = vec3<f32>(0.1, 0.4, 0.7);
        let depth_color = water_base * (0.8 + u * 0.2);
        let caustic = caustics(pos, u);
        
        color = depth_color * caustic + vec3<f32>(1.0, 0.95, 0.8) * (u * u) * 0.3;
    } else if (eq_type == 1) {
        // Heat equation: blue-green viscous flow
        let base = vec3<f32>(0.2, 0.5, 0.4);
        let heat_glow = vec3<f32>(1.0, 0.6, 0.2) * u * 0.4;
        
        color = mix(base, heat_glow, u);
    } else {
        // Schrödinger: violet quantum probability mist
        let quantum_base = vec3<f32>(0.3, 0.1, 0.6);
        let probability_glow = vec3<f32>(1.0, 0.5, 1.0) * u * 0.6;
        
        color = mix(quantum_base, probability_glow, u);
    }
    
    // Foam where gradient is large (discontinuities)
    let foam_threshold = 0.4;
    let foam = smoothstep(foam_threshold, 1.0, grad_magnitude);
    color = mix(color, vec3<f32>(1.0, 1.0, 1.0), foam * 0.7);
    
    // Subsurface scattering effect
    let sss = smoothstep(-0.5, 0.5, u) * 0.3;
    color = color + vec3<f32>(1.0, 0.8, 0.5) * sss;
    
    return color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    let t = 2.5;
    
    // Map three water regions for each equation type
    let region_x = uv.x;
    
    var final_color = vec3<f32>(0.0);
    var eq_type = 0i;
    var region_pos = uv;
    
    if (region_x < -0.2) {
        // Wave equation (left)
        eq_type = 0;
        region_pos = (uv + vec2<f32>(0.5, 0.0)) * 1.5;
    } else if (region_x < 0.2) {
        // Heat equation (center)
        eq_type = 1;
        region_pos = uv * 1.5;
    } else {
        // Schrödinger equation (right)
        eq_type = 2;
        region_pos = (uv - vec2<f32>(0.5, 0.0)) * 1.5;
    }
    
    // Compute solution at this point
    var u = 0.0;
    if (eq_type == 0) {
        u = wave_equation(region_pos, t);
    } else if (eq_type == 1) {
        u = heat_equation(region_pos, t);
    } else {
        u = schrodinger_equation(region_pos, t);
    }
    
    // Compute gradient for foam
    let grad = compute_gradient(eq_type, region_pos, t);
    let grad_mag = length(grad);
    
    // Get solution color
    final_color = solution_to_color(eq_type, u * 0.5 + 0.5, grad_mag, region_pos);
    
    // Atmospheric perspective: distant mist (golden hour)
    let mist_dist = length(region_pos);
    let mist = smoothstep(0.0, 3.0, mist_dist) * 0.3;
    final_color = mix(final_color, vec3<f32>(1.0, 0.85, 0.6), mist);
    
    // Region boundary glow
    let boundary_dist = min(abs(region_x + 0.2), abs(region_x - 0.2));
    let boundary_glow = exp(-boundary_dist * boundary_dist * 50.0) * 0.2;
    final_color = final_color + vec3<f32>(1.0, 0.9, 0.7) * boundary_glow;
    
    return vec4<f32>(final_color, 1.0);
}