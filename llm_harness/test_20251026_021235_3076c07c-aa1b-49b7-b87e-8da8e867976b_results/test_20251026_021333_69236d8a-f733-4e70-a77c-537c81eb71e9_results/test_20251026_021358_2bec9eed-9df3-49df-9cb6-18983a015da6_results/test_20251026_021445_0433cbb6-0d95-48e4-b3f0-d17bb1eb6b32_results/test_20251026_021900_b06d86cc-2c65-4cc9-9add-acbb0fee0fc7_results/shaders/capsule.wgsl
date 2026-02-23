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

fn sdCapsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

fn raycast(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var t = 0.0;
    var steps = 0u;
    let max_steps = 128u;
    
    loop {
        if (steps >= max_steps || t > 100.0) { break; }
        
        let pos = ro + rd * t;
        let d = sdCapsule(pos, vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8);
        
        if (d < 0.001) {
            return vec4<f32>(pos, f32(steps));
        }
        
        t += d * 0.8;
        steps += 1u;
    }
    
    return vec4<f32>(vec3<f32>(0.0), -1.0);
}

fn normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let d = sdCapsule(p, vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8);
    
    let dx = sdCapsule(p + vec3<f32>(eps, 0.0, 0.0), vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8) - d;
    let dy = sdCapsule(p + vec3<f32>(0.0, eps, 0.0), vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8) - d;
    let dz = sdCapsule(p + vec3<f32>(0.0, 0.0, eps), vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8) - d;
    
    return normalize(vec3<f32>(dx, dy, dz));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Low-angle camera position and direction
    let ro = vec3<f32>(1.2 * sin(0.3), 0.8, 2.5);
    let target_var = vec3<f32>(0.0, 0.3, 0.0);
    
    let forward = normalize(target_var - ro);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let rd = normalize(right * uv.x + up * uv.y + forward * 1.2);
    
    // Raycast to capsule
    let hit = raycast(ro, rd);
    
    var color = vec3<f32>(0.08, 0.1, 0.15);
    
    if (hit.w >= 0.0) {
        let p = hit.xyz;
        let n = normal(p);
        
        // Material: porcelain white with blue undertone
        let base_color = vec3<f32>(0.95, 0.93, 0.92) + vec3<f32>(0.02, 0.04, 0.08);
        
        // Three-point lighting
        // Key light (warm, front-left)
        let key_light = normalize(vec3<f32>(-0.8, 1.5, -0.5));
        let key_intensity = 1.2;
        let key_color = vec3<f32>(1.0, 0.95, 0.85);
        
        // Fill light (soft, back-right)
        let fill_light = normalize(vec3<f32>(1.2, 0.5, 1.0));
        let fill_intensity = 0.4;
        let fill_color = vec3<f32>(0.6, 0.7, 0.9);
        
        // Rim light (back)
        let rim_light = normalize(vec3<f32>(0.0, 1.0, 1.0));
        let rim_intensity = 0.8;
        let rim_color = vec3<f32>(0.3, 0.5, 0.8);
        
        // Lambertian key lighting
        let key_diff = max(0.0, dot(n, key_light));
        let key = key_color * key_intensity * key_diff;
        
        // Fill lighting
        let fill_diff = max(0.0, dot(n, fill_light));
        let fill = fill_color * fill_intensity * fill_diff;
        
        // Rim lighting
        let rim_dot = 1.0 - max(0.0, dot(n, -rd));
        let rim = rim_color * rim_intensity * pow(rim_dot, 3.0);
        
        // Specular highlights (glossy)
        let h_key = normalize(-rd + key_light);
        let spec_key = pow(max(0.0, dot(n, h_key)), 32.0) * 0.4;
        
        let h_fill = normalize(-rd + fill_light);
        let spec_fill = pow(max(0.0, dot(n, h_fill)), 64.0) * 0.15;
        
        let lighting = key + fill + rim + spec_key * key_color + spec_fill * fill_color;
        
        // Ambient
        let ambient = vec3<f32>(0.15, 0.18, 0.25);
        
        color = base_color * (lighting + ambient);
        
        // Subtle subsurface for porcelain translucency
        let sss = max(0.0, dot(n, -key_light)) * 0.08;
        color = color + sss * vec3<f32>(0.1, 0.08, 0.05);
    }
    
    // Gradient background (dark)
    let bg_uv = (pos.xy / params.resolution);
    let bg_grad = mix(vec3<f32>(0.05, 0.08, 0.12), vec3<f32>(0.12, 0.1, 0.15), bg_uv.y);
    color = select(bg_grad, color, hit.w >= 0.0);
    
    // Slight vignette
    let vignette = 1.0 - length(uv) * 0.3;
    color = color * vignette;
    
    return vec4<f32>(color, 1.0);
}