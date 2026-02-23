// Lorenz System Integrator + Poincaré Section Renderer
// σ=10, ρ=28, β=8/3
// RK4 integration, Δt=0.005, total 100s
// Poincaré plane at z=27 with white points
// 3D trajectory colored by time (HSV hue), semi-transparent plane

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    var<function> vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    time_param: f32,
    _pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// ============================================================================
// Lorenz System ODE: dx/dt = σ(y-x), dy/dt = x(ρ-z)-y, dz/dt = xy - βz
// ============================================================================

fn lorenz_derivative(state: vec3<f32>) -> vec3<f32> {
    let sigma = 10.0;
    let rho = 28.0;
    let beta = 8.0 / 3.0;
    
    let x = state.x;
    let y = state.y;
    let z = state.z;
    
    let dx = sigma * (y - x);
    let dy = x * (rho - z) - y;
    let dz = x * y - beta * z;
    
    return vec3<f32>(dx, dy, dz);
}

// RK4 step: integrates from state by dt
fn rk4_step(state: vec3<f32>, dt: f32) -> vec3<f32> {
    let k1 = lorenz_derivative(state);
    let k2 = lorenz_derivative(state + k1 * (dt * 0.5));
    let k3 = lorenz_derivative(state + k2 * (dt * 0.5));
    let k4 = lorenz_derivative(state + k3 * dt);
    
    return state + (k1 + k2 * 2.0 + k3 * 2.0 + k4) * (dt / 6.0);
}

// Integrate trajectory and collect Poincaré section data
// Returns packed data: (count, point_data_buffer as flat array)
fn compute_trajectory() -> array<vec4<f32>, 8192> {
    var trajectory: array<vec4<f32>, 8192>;
    var trajectory_idx = 0u;
    
    var state = vec3<f32>(1.0, 1.0, 1.0);
    let dt = 0.005;
    let total_steps = u32(100.0 / dt); // 20000 steps
    let poincare_z = 27.0;
    
    var prev_state = state;
    var prev_sign = select(1.0, -1.0, state.z < poincare_z);
    
    for (var step = 0u; step < total_steps; step = step + 1u) {
        let new_state = rk4_step(state, dt);
        let curr_sign = select(1.0, -1.0, new_state.z < poincare_z);
        
        // Check for Poincaré crossing (z=27 with dz/dt > 0)
        if (prev_sign < 0.0 && curr_sign > 0.0 && trajectory_idx < 8190u) {
            // Linear interpolation to exact crossing
            let alpha = (poincare_z - prev_state.z) / (new_state.z - prev_state.z);
            let poincare_pt = prev_state + (new_state - prev_state) * alpha;
            
            // Encode as (x, y, z=27, time_normalized)
            let time_normalized = f32(step) / f32(total_steps);
            trajectory[trajectory_idx] = vec4<f32>(poincare_pt.x, poincare_pt.y, poincare_z, time_normalized);
            trajectory_idx = trajectory_idx + 1u;
        }
        
        prev_state = state;
        state = new_state;
        prev_sign = curr_sign;
    }
    
    // Store count in first element
    trajectory[0u].w = f32(trajectory_idx);
    
    return trajectory;
}

// HSV to RGB conversion
fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let h_prime = h / 60.0;
    let c = v * s;
    let x = c * (1.0 - abs(h_prime % 2.0 - 1.0));
    let m = v - c;
    
    var rgb_prime: vec3<f32>;
    if (h_prime < 1.0) {
        rgb_prime = vec3<f32>(c, x, 0.0);
    } else if (h_prime < 2.0) {
        rgb_prime = vec3<f32>(x, c, 0.0);
    } else if (h_prime < 3.0) {
        rgb_prime = vec3<f32>(0.0, c, x);
    } else if (h_prime < 4.0) {
        rgb_prime = vec3<f32>(0.0, x, c);
    } else if (h_prime < 5.0) {
        rgb_prime = vec3<f32>(x, 0.0, c);
    } else {
        rgb_prime = vec3<f32>(c, 0.0, x);
    }
    
    return rgb_prime + vec3<f32>(m);
}

// Project 3D point to 2D screen using spherical camera
// Camera: spherical coords (φ=40°, θ=30°) at radius 50
// FOV 60°, look at origin
fn project_3d(point_3d: vec3<f32>) -> vec2<f32> {
    // Camera position in spherical coords
    let phi_deg = 40.0;
    let theta_deg = 30.0;
    let radius = 50.0;
    
    let phi = phi_deg * 3.14159 / 180.0;
    let theta = theta_deg * 3.14159 / 180.0;
    
    let cam_x = radius * sin(phi) * cos(theta);
    let cam_y = radius * cos(phi);
    let cam_z = radius * sin(phi) * sin(theta);
    let cam_pos = vec3<f32>(cam_x, cam_y, cam_z);
    
    // View vector (looking at origin)
    let view_dir = normalize(vec3<f32>(0.0) - cam_pos);
    
    // Build orthonormal basis
    let up = vec3<f32>(0.0, 1.0, 0.0);
    let right = normalize(cross(view_dir, up));
    let actual_up = cross(right, view_dir);
    
    // Project point relative to camera
    let rel_pos = point_3d - cam_pos;
    let depth = dot(rel_pos, view_dir);
    
    // Avoid behind-camera points
    if (depth <= 0.1) {
        return vec2<f32>(-2.0); // off-screen
    }
    
    let fov_rad = 60.0 * 3.14159 / 180.0;
    let scale = 1.0 / tan(fov_rad * 0.5);
    
    let screen_x = (dot(rel_pos, right) * scale) / depth;
    let screen_y = (dot(rel_pos, actual_up) * scale) / depth;
    
    // Normalize to NDC [-1, 1]
    let aspect = params.resolution.x / params.resolution.y;
    return vec2<f32>(screen_x * aspect, screen_y);
}

// Rasterize trajectory line with thickness
fn line_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / (dot(ba, ba) + 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let screen_pos = uv * 2.0 - 1.0;
    screen_pos.y = screen_pos.y * (params.resolution.y / params.resolution.x);
    
    // White background
    var result = vec4<f32>(1.0, 1.0, 1.0, 1.0);
    
    // Compute trajectory (ideally cached, but re-compute for determinism)
    let trajectory_data = compute_trajectory();
    let point_count = u32(trajectory_data[0u].w);
    
    // Draw Poincaré plane (semi-transparent gray)
    let plane_color = vec4<f32>(0.267, 0.267, 0.267, 0.15);
    result = mix(result, plane_color, plane_color.w);
    
    // Draw trajectory line (sampled for performance)
    var closest_traj_dist = 1e6;
    var closest_hue = 0.0;
    
    let sample_step = max(1u, point_count / 100u); // Sample up to 100 trajectory points
    for (var i = 0u; i < point_count - 1u; i = i + sample_step) {
        let pt_a = trajectory_data[i];
        let pt_b = trajectory_data[i + 1u];
        
        if (pt_a.z > 10.0 && pt_b.z > 10.0) { // Only draw upper part
            let screen_a = project_3d(pt_a.xyz);
            let screen_b = project_3d(pt_b.xyz);
            
            if (screen_a.x > -2.0 && screen_b.x > -2.0) {
                let dist = line_distance(screen_pos, screen_a, screen_b);
                let line_thick = 0.01; // 1% of attractor
                
                if (dist < line_thick && dist < closest_traj_dist) {
                    closest_traj_dist = dist;
                    closest_hue = pt_a.w * 360.0; // Convert time to hue (0-360°)
                }
            }
        }
    }
    
    if (closest_traj_dist < 0.01) {
        let traj_color = hsv_to_rgb(closest_hue, 1.0, 0.9);
        result = vec4<f32>(traj_color, 1.0);
    }
    
    // Draw Poincaré section points (white circles, 4px)
    var closest_point_dist = 1e6;
    for (var i = 1u; i < point_count; i = i + 1u) {
        let pt = trajectory_data[i];
        let screen_pt = project_3d(pt.xyz);
        
        if (screen_pt.x > -2.0) {
            let dist = length(screen_pos - screen_pt);
            if (dist < 0.02 && dist < closest_point_dist) { // 4px @ 2000×1600
                closest_point_dist = dist;
            }
        }
    }
    
    if (closest_point_dist < 0.02) {
        let point_alpha = 1.0 - smoothstep(0.0, 0.02, closest_point_dist);
        result = mix(result, vec4<f32>(1.0, 1.0, 1.0, 1.0), point_alpha);
    }
    
    return result;
}