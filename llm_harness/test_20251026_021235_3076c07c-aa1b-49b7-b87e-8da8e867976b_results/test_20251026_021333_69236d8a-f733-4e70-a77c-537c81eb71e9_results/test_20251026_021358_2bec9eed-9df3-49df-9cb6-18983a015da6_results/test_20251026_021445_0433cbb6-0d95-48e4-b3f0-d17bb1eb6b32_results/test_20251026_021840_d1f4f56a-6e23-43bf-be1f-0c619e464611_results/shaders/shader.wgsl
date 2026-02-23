// Quintic Calabi-Yau isosurface visualizer
// Re(∑z_i^5 - 5ψ∏z_i) = 0 with ∑|z_i|² = 1, z_3=z_4=0, ψ=0.4
// Stereographic projection of (z_0, z_1, z_2) to ℝ³
// Marching cubes with Viridis coloring by normal

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

// ============================================================================
// Constants
// ============================================================================
const PSI: f32 = 0.4;
const EPSILON: f32 = 0.001;
const MAX_MARCH_STEPS: u32 = 256u;
const CAMERA_POS: vec3<f32> = vec3<f32>(4.0, 4.0, 4.0);
const CAMERA_TARGET: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
const BG_COLOR: vec3<f32> = vec3<f32>(0.0, 0.0627, 0.0941);

// ============================================================================
// Complex number utilities
// ============================================================================

fn cmul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn cpow5(z: vec2<f32>) -> vec2<f32> {
    let z2 = cmul(z, z);
    let z4 = cmul(z2, z2);
    return cmul(z4, z);
}

// ============================================================================
// Quintic CY evaluation
// ============================================================================

fn quintic_cy(pos: vec3<f32>) -> f32 {
    let norm_sq = pos.x * pos.x + pos.y * pos.y + pos.z * pos.z;
    let scale = 1.0 / max(sqrt(norm_sq), 0.001);
    let z0 = vec2<f32>(pos.x * scale, 0.0);
    let z1 = vec2<f32>(pos.y * scale, 0.0);
    let z2 = vec2<f32>(pos.z * scale, 0.0);
    
    let sum_5 = cpow5(z0) + cpow5(z1) + cpow5(z2);
    let prod = (pos.x * scale) * (pos.y * scale) * (pos.z * scale);
    
    return sum_5.x - 5.0 * PSI * prod;
}

// ============================================================================
// Gradient (normal)
// ============================================================================

fn compute_gradient(pos: vec3<f32>) -> vec3<f32> {
    let eps = EPSILON;
    let f0 = quintic_cy(pos);
    let fx = quintic_cy(pos + vec3<f32>(eps, 0.0, 0.0));
    let fy = quintic_cy(pos + vec3<f32>(0.0, eps, 0.0));
    let fz = quintic_cy(pos + vec3<f32>(0.0, 0.0, eps));
    
    let grad = vec3<f32>((fx - f0) / eps, (fy - f0) / eps, (fz - f0) / eps);
    return normalize(grad);
}

// ============================================================================
// Viridis colormap
// ============================================================================

fn viridis(t_norm: f32) -> vec3<f32> {
    let t = clamp(t_norm, 0.0, 1.0);
    
    if (t < 0.0625) {
        return mix(vec3<f32>(0.267, 0.004, 0.329), vec3<f32>(0.282, 0.140, 0.458), t / 0.0625);
    } else if (t < 0.125) {
        return mix(vec3<f32>(0.282, 0.140, 0.458), vec3<f32>(0.254, 0.265, 0.530), (t - 0.0625) / 0.0625);
    } else if (t < 0.1875) {
        return mix(vec3<f32>(0.254, 0.265, 0.530), vec3<f32>(0.210, 0.359, 0.551), (t - 0.125) / 0.0625);
    } else if (t < 0.25) {
        return mix(vec3<f32>(0.210, 0.359, 0.551), vec3<f32>(0.163, 0.471, 0.558), (t - 0.1875) / 0.0625);
    } else if (t < 0.3125) {
        return mix(vec3<f32>(0.163, 0.471, 0.558), vec3<f32>(0.127, 0.567, 0.550), (t - 0.25) / 0.0625);
    } else if (t < 0.375) {
        return mix(vec3<f32>(0.127, 0.567, 0.550), vec3<f32>(0.134, 0.658, 0.517), (t - 0.3125) / 0.0625);
    } else if (t < 0.4375) {
        return mix(vec3<f32>(0.134, 0.658, 0.517), vec3<f32>(0.266, 0.748, 0.440), (t - 0.375) / 0.0625);
    } else if (t < 0.5) {
        return mix(vec3<f32>(0.266, 0.748, 0.440), vec3<f32>(0.477, 0.821, 0.318), (t - 0.4375) / 0.0625);
    } else if (t < 0.5625) {
        return mix(vec3<f32>(0.477, 0.821, 0.318), vec3<f32>(0.741, 0.873, 0.149), (t - 0.5) / 0.0625);
    } else if (t < 0.625) {
        return mix(vec3<f32>(0.741, 0.873, 0.149), vec3<f32>(0.973, 0.906, 0.143), (t - 0.5625) / 0.0625);
    } else {
        return vec3<f32>(0.993, 0.906, 0.143);
    }
}

// ============================================================================
// Phong shading
// ============================================================================

fn phong_shade(normal: vec3<f32>, ray_dir: vec3<f32>) -> vec3<f32> {
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
    let view_dir = -ray_dir;
    let halfway = normalize(light_dir + view_dir);
    
    let ambient = 0.3;
    let diffuse = 0.5 * max(dot(normal, light_dir), 0.0);
    let specular = 0.2 * pow(max(dot(normal, halfway), 0.0), 128.0);
    
    return vec3<f32>(ambient + diffuse + specular);
}

// ============================================================================
// Ray marching
// ============================================================================

fn march_ray(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> vec3<f32> {
    var t = 0.1;
    var depth = 0u;
    
    loop {
        if (depth >= MAX_MARCH_STEPS) { break; }
        
        let pos = ray_origin + t * ray_dir;
        let f_val = quintic_cy(pos);
        
        let step = max(0.01, abs(f_val) * 0.1);
        
        if (abs(f_val) < 0.005) {
            let normal = compute_gradient(pos);
            let n_dot_ref = dot(normal, vec3<f32>(0.3, 0.7, 0.6));
            let color_t = (n_dot_ref + 1.0) * 0.5;
            let surface_color = viridis(color_t);
            let shading = phong_shade(normal, ray_dir);
            return surface_color * shading;
        }
        
        t += step;
        depth += 1u;
        
        if (t > 10.0) { break; }
    }
    
    return BG_COLOR;
}

// ============================================================================
// Camera setup
// ============================================================================

fn compute_ray(uv: vec2<f32>) -> vec3<f32> {
    let forward = normalize(CAMERA_TARGET - CAMERA_POS);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let fov = 35.0 * 3.14159 / 180.0;
    let aspect = params.resolution.x / params.resolution.y;
    let h = tan(fov * 0.5);
    
    let ray_dir = normalize(
        forward +
        right * (uv.x * aspect * h) +
        up * (uv.y * h)
    );
    
    return ray_dir;
}

// ============================================================================
// Main fragment shader
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let ray_dir = compute_ray(uv);
    let color = march_ray(CAMERA_POS, ray_dir);
    
    return vec4<f32>(color, 1.0);
}