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

// Signed distance function for rounded box
fn sdRoundedBox(p: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
    let q = abs(p) - b;
    return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

// Estimate normal via central differences
fn estimateNormal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let nx = sdRoundedBox(p + vec3<f32>(eps, 0.0, 0.0), vec3<f32>(1.0, 1.5, 0.75), 0.3) 
           - sdRoundedBox(p - vec3<f32>(eps, 0.0, 0.0), vec3<f32>(1.0, 1.5, 0.75), 0.3);
    let ny = sdRoundedBox(p + vec3<f32>(0.0, eps, 0.0), vec3<f32>(1.0, 1.5, 0.75), 0.3)
           - sdRoundedBox(p - vec3<f32>(0.0, eps, 0.0), vec3<f32>(1.0, 1.5, 0.75), 0.3);
    let nz = sdRoundedBox(p + vec3<f32>(0.0, 0.0, eps), vec3<f32>(1.0, 1.5, 0.75), 0.3)
           - sdRoundedBox(p - vec3<f32>(0.0, 0.0, eps), vec3<f32>(1.0, 1.5, 0.75), 0.3);
    return normalize(vec3<f32>(nx, ny, nz));
}

// Raymarching using_var sphere tracing
fn rayMarch(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var t = 0.0;
    var step_count = 0u;
    let max_steps = 128u;
    let max_dist = 100.0;
    let surf_dist = 0.0001;
    
    loop {
        if (step_count >= max_steps || t >= max_dist) { break; }
        
        let p = ro + rd * t;
        let d = sdRoundedBox(p, vec3<f32>(1.0, 1.5, 0.75), 0.3);
        
        if (d < surf_dist) {
            let surface_p = p;
            let normal = estimateNormal(surface_p);
            
            // Ambient light
            let ambient = 0.3;
            
            // Key light from top-right
            let light_dir = normalize(vec3<f32>(1.0, 1.0, 0.8));
            let diff = max(dot(normal, light_dir), 0.0) * 0.7;
            
            // Lighting total
            let lighting = ambient + diff;
            
            // Mint green material: RGB (0.3, 0.8, 0.6)
            let material = vec3<f32>(0.3, 0.8, 0.6);
            let color = material * lighting;
            
            return vec4<f32>(color, 1.0);
        }
        
        t = t + d * 0.8;
        step_count = step_count + 1u;
    }
    
    // Background: light gray gradient
    let grad_factor = (rd.y + 1.0) * 0.5;
    let bg_color = mix(vec3<f32>(0.75), vec3<f32>(0.9), grad_factor);
    return vec4<f32>(bg_color, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Camera setup: perspective view at (4, 3, 5) looking at origin
    let camera_pos = vec3<f32>(4.0, 3.0, 5.0);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let up_dir = vec3<f32>(0.0, 1.0, 0.0);
    
    // Build camera frame
    let forward = normalize(target_var - camera_pos);
    let right = normalize(cross(forward, up_dir));
    let up = cross(right, forward);
    
    // Ray direction with perspective
    let fov = 0.8;
    let ray_dir = normalize(right * uv.x * fov + up * uv.y * fov + forward);
    
    // Raymarch
    let result = rayMarch(camera_pos, ray_dir);
    
    return result;
}