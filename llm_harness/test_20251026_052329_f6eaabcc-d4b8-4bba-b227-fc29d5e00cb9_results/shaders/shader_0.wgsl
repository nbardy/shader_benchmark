// 4D Hyper Menger Cube intersected with 3-Sphere, stereographically projected to 3D
// Renders a cross-section of the 4D fractal structure with proper coloring and lighting

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
    _padding: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Check if point belongs to 4D Menger cube
fn menger4D(p: vec4<f32>, iterations: i32) -> f32 {
    var pos = p;
    var scale = 1.0;
    var removed = 0.0;
    
    for (var i: i32 = 0; i < iterations; i = i + 1) {
        var count = 0;
        
        // Check x coordinate
        let x_mod = abs(pos.x) % (3.0 * scale);
        if (x_mod >= scale && x_mod < 2.0 * scale) {
            count = count + 1;
        }
        
        // Check y coordinate
        let y_mod = abs(pos.y) % (3.0 * scale);
        if (y_mod >= scale && y_mod < 2.0 * scale) {
            count = count + 1;
        }
        
        // Check z coordinate
        let z_mod = abs(pos.z) % (3.0 * scale);
        if (z_mod >= scale && z_mod < 2.0 * scale) {
            count = count + 1;
        }
        
        // Check w coordinate
        let w_mod = abs(pos.w) % (3.0 * scale);
        if (w_mod >= scale && w_mod < 2.0 * scale) {
            count = count + 1;
        }
        
        // Remove if more than 2 coordinates are in removed region
        if (count > 2) {
            removed = 1.0;
            break;
        }
        
        scale = scale / 3.0;
    }
    
    return 1.0 - removed;
}

// Stereographic projection from (0,0,0,1) to 3D
fn stereographicProject(p4d: vec4<f32>) -> vec3<f32> {
    let w = p4d.w;
    let denom = 1.0 - w;
    
    // Handle near-singularity
    if (abs(denom) < 0.01) {
        return p4d.xyz * 10.0;
    }
    
    return p4d.xyz / denom;
}

// Inverse stereographic projection to find 4D point on sphere
fn inverseStereographic(p3d: vec3<f32>) -> vec4<f32> {
    let r_sq = dot(p3d, p3d);
    let denom = 1.0 + r_sq;
    
    let x = 2.0 * p3d.x / denom;
    let y = 2.0 * p3d.y / denom;
    let z = 2.0 * p3d.z / denom;
    let w = (r_sq - 1.0) / denom;
    
    return vec4<f32>(x, y, z, w);
}

// Color based on w coordinate
fn colorFromW(w: f32) -> vec3<f32> {
    let normalized_w = (w + 1.0) * 0.5; // Map [-1, 1] to [0, 1]
    
    // Color gradient: purple -> orange -> yellow
    let purple = vec3<f32>(0.29, 0.08, 0.55);    // #4a148c
    let orange = vec3<f32>(1.0, 0.34, 0.13);     // #ff5722
    let yellow = vec3<f32>(1.0, 0.92, 0.23);     // #ffeb3b
    
    if (normalized_w < 0.5) {
        let t = normalized_w * 2.0;
        return mix(purple, orange, t);
    } else {
        let t = (normalized_w - 0.5) * 2.0;
        return mix(orange, yellow, t);
    }
}

// Simple ray marching in 3D space
fn rayMarch(origin: vec3<f32>, direction: vec3<f32>) -> vec4<f32> {
    var pos = origin;
    var t = 0.0;
    let max_steps = 64;
    let max_dist = 20.0;
    let hit_threshold = 0.02;
    
    for (var step: i32 = 0; step < max_steps; step = step + 1) {
        // Convert 3D position back to 4D
        let p4d = inverseStereographic(pos);
        let radius = length(p4d);
        
        // Check if on sphere and in Menger set
        let on_sphere = abs(radius - 1.0);
        let in_menger = menger4D(p4d, 3);
        
        let dist = on_sphere * (1.0 - in_menger * 0.8);
        
        if (dist < hit_threshold || t > max_dist) {
            let hit_color = colorFromW(p4d.w);
            let brightness = 1.0 - (t / max_dist) * 0.5;
            return vec4<f32>(hit_color * brightness, 1.0);
        }
        
        t = t + max(dist * 0.5, 0.01);
        pos = origin + direction * t;
    }
    
    return vec4<f32>(0.0, 0.0, 0.0, 0.0);
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Camera setup with rotation
    let time = params.time * 0.3;
    let cos_t = cos(time);
    let sin_t = sin(time);
    
    // Rotating camera
    let cam_dist = 2.5;
    let cam_x = cam_dist * cos_t;
    let cam_z = cam_dist * sin_t;
    let cam_y = 0.5 + 0.3 * sin(time * 0.7);
    
    let camera = vec3<f32>(cam_x, cam_y, cam_z);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let up = vec3<f32>(0.0, 1.0, 0.0);
    
    // Construct camera basis
    let forward = normalize(target_var - camera);
    let right = normalize(cross(forward, up));
    let camera_up = cross(right, forward);
    
    // Ray direction
    let direction = normalize(
        forward + right * uv.x * 0.8 + camera_up * uv.y * 0.8
    );
    
    // Ray march
    let color = rayMarch(camera, direction);
    
    if (color.a > 0.0) {
        // Add lighting effects
        let ambient = vec3<f32>(0.2, 0.15, 0.25);
        let light1 = vec3<f32>(0.7, 0.8, 0.6);
        
        let final_color = color.xyz * (ambient + light1 * 0.8);
        
        // Apply subtle subsurface scattering effect
        let scatter = mix(color.xyz, vec3<f32>(1.0), 0.1);
        return vec4<f32>(mix(final_color, scatter, 0.15), 0.85);
    } else {
        // Space gradient background
        let dark_blue = vec3<f32>(0.05, 0.28, 0.63);   // #0d47a1
        let black = vec3<f32>(0.0, 0.0, 0.0);
        let bg = mix(dark_blue, black, length(uv) * 0.5);
        return vec4<f32>(bg, 1.0);
    }
}