// Menger Sponge Order-4 Ray Marcher with Phong Lighting
// Resolution: 2200×1500, 4×SSAA
// Eye: (4,3,2), Target: (0,0,0), FOV: 40°
// Light: (8,5,6), Phong: ambient=0.05, diffuse=0.75, specular=0.2, shininess=64

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

fn menger_sdf(p: vec3<f32>) -> f32 {
    var p_iter = abs(p);
    var scale = 1.0;
    
    for (var i: u32 = 0u; i < 4u; i = i + 1u) {
        // Sort coordinates
        if (p_iter.x < p_iter.y) {
            let tmp = p_iter.x;
            p_iter.x = p_iter.y;
            p_iter.y = tmp;
        }
        if (p_iter.x < p_iter.z) {
            let tmp = p_iter.x;
            p_iter.x = p_iter.z;
            p_iter.z = tmp;
        }
        
        // Menger iteration
        p_iter = p_iter * 3.0 - 2.0 * floor(p_iter * 3.0);
        scale = scale * 3.0;
    }
    
    return (length(p_iter) - 1.0) / scale;
}

fn compute_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.0001;
    let n = vec3<f32>(
        menger_sdf(p + vec3<f32>(eps, 0.0, 0.0)) - menger_sdf(p - vec3<f32>(eps, 0.0, 0.0)),
        menger_sdf(p + vec3<f32>(0.0, eps, 0.0)) - menger_sdf(p - vec3<f32>(0.0, eps, 0.0)),
        menger_sdf(p + vec3<f32>(0.0, 0.0, eps)) - menger_sdf(p - vec3<f32>(0.0, 0.0, eps))
    );
    return normalize(n);
}

fn ray_march(ro: vec3<f32>, rd: vec3<f32>, max_steps: u32, hit_threshold: f32) -> vec2<f32> {
    var t = 0.0;
    var step_count = 0u;
    
    loop {
        if (step_count >= max_steps) { break; }
        
        let p = ro + rd * t;
        let d = menger_sdf(p);
        
        if (d < hit_threshold) {
            return vec2<f32>(t, 1.0);
        }
        
        t = t + d * 0.8;
        step_count = step_count + 1u;
        
        if (t > 100.0) { break; }
    }
    
    return vec2<f32>(t, 0.0);
}

fn soft_shadow(p: vec3<f32>, light_dir: vec3<f32>, samples: u32) -> f32 {
    var shadow = 0.0;
    let light_dist = length(light_dir);
    let ld_norm = normalize(light_dir);
    
    for (var i: u32 = 0u; i < samples; i = i + 1u) {
        let angle_seed = f32(i) / f32(samples);
        let perturb = sin(angle_seed * 6.28318) * 0.1;
        let perturbed_dir = normalize(ld_norm + vec3<f32>(perturb, perturb * 0.5, perturb));
        let march_result = ray_march(p + ld_norm * 0.01, perturbed_dir, 64u, 0.001);
        
        if (march_result.y > 0.5 && march_result.x < light_dist) {
            shadow = shadow + 1.0;
        }
    }
    
    return 1.0 - (shadow / f32(samples)) * 0.7;
}

fn phong_lighting(p: vec3<f32>, n: vec3<f32>, camera_pos: vec3<f32>, light_pos: vec3<f32>) -> vec3<f32> {
    let light_dir = light_pos - p;
    let light_dist = length(light_dir);
    let l = normalize(light_dir);
    let v = normalize(camera_pos - p);
    let h = normalize(l + v);
    
    // Ambient
    var color = vec3<f32>(0.05, 0.05, 0.05);
    
    // Diffuse
    let n_dot_l = max(0.0, dot(n, l));
    color = color + vec3<f32>(0.75, 0.75, 0.75) * n_dot_l;
    
    // Specular
    let n_dot_h = max(0.0, dot(n, h));
    let spec = pow(n_dot_h, 64.0);
    color = color + vec3<f32>(0.2, 0.2, 0.2) * spec;
    
    // Soft shadow
    let shadow = soft_shadow(p, light_dir, 32u);
    color = color * shadow;
    
    return color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Camera setup
    let eye = vec3<f32>(4.0, 3.0, 2.0);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let up = vec3<f32>(0.0, 1.0, 0.0);
    
    // Basis vectors
    let f = normalize(target_var - eye);
    let r = normalize(cross(f, up));
    let u = cross(r, f);
    
    // FOV = 40° → tan(20°) ≈ 0.364
    let fov_factor = 0.364;
    
    // 4×SSAA: 2×2 subpixel samples
    var final_color = vec3<f32>(0.0, 0.0, 0.0);
    
    for (var sy: u32 = 0u; sy < 2u; sy = sy + 1u) {
        for (var sx: u32 = 0u; sx < 2u; sx = sx + 1u) {
            let subpixel_x = f32(sx) * 0.5 - 0.25;
            let subpixel_y = f32(sy) * 0.5 - 0.25;
            let screen_pos = pos.xy + vec2<f32>(subpixel_x, subpixel_y);
            
            // Normalize to [-1, 1]
            let aspect = params.resolution.x / params.resolution.y;
            let ndc_x = (screen_pos.x / params.resolution.x - 0.5) * 2.0 * aspect * fov_factor;
            let ndc_y = -(screen_pos.y / params.resolution.y - 0.5) * 2.0 * fov_factor;
            
            let rd = normalize(r * ndc_x + u * ndc_y + f);
            
            // Ray march
            let march_result = ray_march(eye, rd, 256u, 0.0005);
            
            if (march_result.y > 0.5) {
                // Hit surface
                let hit_pos = eye + rd * march_result.x;
                let normal = compute_normal(hit_pos);
                let light_pos = vec3<f32>(8.0, 5.0, 6.0);
                
                let color = phong_lighting(hit_pos, normal, eye, light_pos);
                final_color = final_color + color;
            } else {
                // Background: #e0f5ff
                final_color = final_color + vec3<f32>(0.878, 0.961, 1.0);
            }
        }
    }
    
    // Average 4 samples
    final_color = final_color * 0.25;
    
    // Tone mapping
    final_color = final_color / (final_color + vec3<f32>(1.0, 1.0, 1.0));
    
    return vec4<f32>(final_color, 1.0);
}