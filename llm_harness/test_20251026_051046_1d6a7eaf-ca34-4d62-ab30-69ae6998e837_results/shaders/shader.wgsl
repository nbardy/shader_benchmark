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

fn sdCapsule(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>, r: f32) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

fn rayMarch(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var t = 0.0;
    var hit_dist = 0.0;
    let max_steps = 128u;
    
    for (var i = 0u; i < max_steps; i = i + 1u) {
        let p = ro + rd * t;
        let d = sdCapsule(p, vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8);
        
        if (d < 0.001 || t > 20.0) {
            hit_dist = d;
            break;
        }
        t = t + d * 0.8;
    }
    
    if (abs(hit_dist) < 0.001 && t < 20.0) {
        return vec4<f32>(t, 1.0, 0.0, 0.0);
    } else {
        return vec4<f32>(t, 0.0, 0.0, 0.0);
    }
}

fn getNormal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let d = sdCapsule(p, vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8);
    
    let n = vec3<f32>(
        sdCapsule(p + vec3<f32>(eps, 0.0, 0.0), vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8) - d,
        sdCapsule(p + vec3<f32>(0.0, eps, 0.0), vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8) - d,
        sdCapsule(p + vec3<f32>(0.0, 0.0, eps), vec3<f32>(0.0, -1.5, 0.0), vec3<f32>(0.0, 1.5, 0.0), 0.8) - d
    );
    
    return normalize(n);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let ro = vec3<f32>(2.0 * sin(0.5), 1.2, 3.5 * cos(0.5));
    let target_var = vec3<f32>(0.0, 0.3, 0.0);
    let forward = normalize(target_var - ro);
    let right = normalize(cross(forward, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, forward);
    
    let rd = normalize(forward + uv.x * right + uv.y * up);
    
    let march_result = rayMarch(ro, rd);
    let t = march_result.x;
    let hit = march_result.y;
    
    if (hit < 0.5) {
        let p = ro + rd * t;
        let normal = getNormal(p);
        
        // Three-point lighting
        let light_main = normalize(vec3<f32>(2.0, 3.0, 2.0));
        let light_fill = normalize(vec3<f32>(-1.5, 1.0, -2.0));
        let light_rim = normalize(vec3<f32>(-2.0, 1.5, -3.0));
        
        let diff_main = max(0.0, dot(normal, light_main)) * 0.8;
        let diff_fill = max(0.0, dot(normal, light_fill)) * 0.3;
        let diff_rim = max(0.0, dot(normal, light_rim)) * 0.4;
        
        let rim_light = pow(max(0.0, dot(normal, light_rim)), 2.0) * 0.6;
        
        // Material: semi-glossy porcelain white with blue undertones
        let base_color = vec3<f32>(0.95, 0.94, 0.92);
        let blue_tint = vec3<f32>(0.85, 0.88, 0.98);
        
        let material_color = mix(base_color, blue_tint, 0.15);
        let lighting = diff_main + diff_fill + rim_light;
        
        let final_color = material_color * (0.3 + lighting);
        
        // Fade with distance for depth
        let fade = exp(-t * 0.08);
        
        return vec4<f32>(final_color * fade, 1.0);
    } else {
        // Dark gradient background
        let horizon = mix(vec3<f32>(0.05, 0.05, 0.08), vec3<f32>(0.12, 0.11, 0.15), smoothstep(-1.0, 1.0, uv.y));
        return vec4<f32>(horizon, 1.0);
    }
}