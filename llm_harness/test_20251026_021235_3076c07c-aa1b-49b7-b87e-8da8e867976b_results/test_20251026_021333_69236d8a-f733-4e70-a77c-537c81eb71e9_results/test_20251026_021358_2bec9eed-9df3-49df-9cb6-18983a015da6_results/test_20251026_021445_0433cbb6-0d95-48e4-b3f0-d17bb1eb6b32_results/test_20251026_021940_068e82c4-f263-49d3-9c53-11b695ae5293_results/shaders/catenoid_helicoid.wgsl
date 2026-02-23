// Catenoid-Helicoid Minimal Surface Animation
// Demonstrates smooth transformation between two isometric minimal surfaces
// with soap bubble rendering and wireframe overlay

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

// Minimal surface parametric equations
fn catenoidHelicoidSurface(u: f32, v: f32, theta: f32) -> vec3<f32> {
    let cos_theta = cos(theta);
    let sin_theta = sin(theta);
    let sinh_v = sinh(v);
    let cosh_v = cosh(v);
    let sin_u = sin(u);
    let cos_u = cos(u);
    
    let x = cos_theta * sinh_v * sin_u + sin_theta * cosh_v * cos_u;
    let y = -cos_theta * sinh_v * cos_u + sin_theta * cosh_v * sin_u;
    let z = u * cos_theta + v * sin_theta;
    
    return vec3<f32>(x, y, z);
}

// Thin film interference based on thickness
fn thinFilmInterference(thickness: f32, view_angle: f32) -> vec3<f32> {
    let wavelength_r = 700.0;
    let wavelength_g = 550.0;
    let wavelength_b = 450.0;
    
    let path_diff = 2.0 * thickness * cos(view_angle);
    
    let phase_r = (path_diff % wavelength_r) / wavelength_r * 6.28318;
    let phase_g = (path_diff % wavelength_g) / wavelength_g * 6.28318;
    let phase_b = (path_diff % wavelength_b) / wavelength_b * 6.28318;
    
    let intensity_r = 0.5 + 0.5 * sin(phase_r);
    let intensity_g = 0.5 + 0.5 * sin(phase_g + 2.09439);
    let intensity_b = 0.5 + 0.5 * sin(phase_b + 4.18879);
    
    return vec3<f32>(intensity_r, intensity_g, intensity_b);
}

// Normal computation via finite differences
fn computeNormal(u: f32, v: f32, theta: f32, delta: f32) -> vec3<f32> {
    let p = catenoidHelicoidSurface(u, v, theta);
    let pu = catenoidHelicoidSurface(u + delta, v, theta);
    let pv = catenoidHelicoidSurface(u, v + delta, theta);
    
    let du = (pu - p) / delta;
    let dv = (pv - p) / delta;
    
    let normal = normalize(cross(du, dv));
    return normal;
}

// Wireframe pattern generation
fn wireframePattern(u: f32, v: f32, scale: f32) -> f32 {
    let u_grid = fract(u * scale);
    let v_grid = fract(v * scale);
    
    let u_line = smoothstep(0.02, 0.0, u_grid) + smoothstep(0.98, 1.0, u_grid);
    let v_line = smoothstep(0.02, 0.0, v_grid) + smoothstep(0.98, 1.0, v_grid);
    
    return max(u_line, v_line);
}

// Particle effect for air flow visualization
fn particleEffect(pos: vec3<f32>, time: f32) -> f32 {
    let freq = 3.0;
    let particle_pos = pos + vec3<f32>(sin(time * freq), cos(time * freq * 0.7), sin(time * freq * 0.5)) * 0.5;
    
    let dist = length(particle_pos);
    let glow = exp(-dist * dist * 2.0) * 0.3;
    
    return glow;
}

// Helper function: sinh
fn sinh(x: f32) -> f32 {
    return (exp(x) - exp(-x)) * 0.5;
}

// Helper function: cosh
fn cosh(x: f32) -> f32 {
    return (exp(x) + exp(-x)) * 0.5;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let center = vec2<f32>(0.5, 0.5);
    let uv_centered = (uv - center) * 2.5;
    
    // Animation parameters
    let time = params.time * 0.5;
    let theta = sin(time) * 1.5707963;  // π/2 * sin(time) for smooth oscillation
    
    // Sample surface in UV parameter space
    let u = atan2(uv_centered.y, uv_centered.x);
    let r = length(uv_centered);
    let v = clamp(r * 2.0 - 1.0, -2.0, 2.0);
    
    // Get surface point and normal
    let surface_point = catenoidHelicoidSurface(u, v, theta);
    let surface_normal = computeNormal(u, v, theta, 0.01);
    
    // View direction
    let view_dir = normalize(vec3<f32>(0.0, 0.0, 1.0));
    let fresnel = pow(abs(dot(surface_normal, view_dir)), 0.5);
    
    // Thin film interference
    let film_color = thinFilmInterference(abs(v) * 100.0, fresnel);
    let iridescence = mix(vec3<f32>(1.0), film_color, fresnel);
    
    // Soap bubble transparency
    let depth_fade = smoothstep(3.0, 0.0, abs(surface_point.z));
    let transparency = mix(0.3, 0.8, depth_fade);
    
    // Wireframe overlay
    let wire = wireframePattern(u, v, 3.0 + sin(time) * 2.0);
    let wire_color = mix(iridescence, vec3<f32>(0.9, 0.95, 1.0), wire * 0.6);
    
    // Particle glow
    let glow = particleEffect(surface_point, time);
    let particle_color = mix(vec3<f32>(0.2, 0.4, 0.8), vec3<f32>(0.9), glow);
    
    // Ambient contribution
    let ambient = vec3<f32>(0.1, 0.15, 0.2);
    let reflection = vec3<f32>(0.3, 0.5, 0.7) * fresnel;
    
    // Combine effects
    let surface_color = wire_color + particle_color + reflection;
    let final_color = mix(ambient, surface_color, depth_fade);
    
    // Distance-based fade for clean edges
    let edge_fade = smoothstep(1.5, 0.5, r);
    
    // Final composition
    let output = final_color * edge_fade;
    
    return vec4<f32>(output, transparency * edge_fade);
}