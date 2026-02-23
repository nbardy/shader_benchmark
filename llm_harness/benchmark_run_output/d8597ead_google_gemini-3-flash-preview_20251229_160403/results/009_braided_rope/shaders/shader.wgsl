// THREE-STRAND BRAIDED ROPE SHADER
// Following strict WGSL ABI Contract

struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
};

struct Hit {
    dist: f32,
    color: vec3<f32>,
};

// Distance Function for a single helix strand
// p: world position
// phase: rotation offset in radians
// col: strand color
fn sd_helix(p: vec3<f32>, phase: f32, col: vec3<f32>) -> Hit {
    let cylinder_radius = 0.6;
    let pitch = 1.8;
    let tube_radius = 0.15;
    
    // Convert pitch to angular velocity factor
    let k = 2.0 * 3.14159265 / pitch;
    
    // Angle based on vertical position
    let angle = p.z * k + phase;
    
    // Target position on the helical path
    let target_var = vec3<f32>(
        cos(angle) * cylinder_radius,
        sin(angle) * cylinder_radius,
        p.z
    );
    
    let d = length(p - target_var) - tube_radius;
    var h: Hit;
    h.dist = d;
    h.color = col;
    return h;
}

fn map(p: vec3<f32>) -> Hit {
    // Strand colors: #c96 (0.8, 0.6, 0.4), #6c9 (0.4, 0.8, 0.6), #96c (0.6, 0.4, 0.8)
    let c1 = vec3<f32>(0.8, 0.6, 0.4);
    let c2 = vec3<f32>(0.4, 0.8, 0.6);
    let c3 = vec3<f32>(0.6, 0.4, 0.8);
    
    // Phase offsets: 0, 120 (2pi/3), 240 (4pi/3)
    let h1 = sd_helix(p, 0.0, c1);
    let h2 = sd_helix(p, 2.094395, c2);
    let h3 = sd_helix(p, 4.188790, c3);
    
    // Smooth union or simple min? Requirement implies distinct strands.
    var res = h1;
    res = select(res, h2, h2.dist < res.dist);
    res = select(res, h3, h3.dist < res.dist);
    
    return res;
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    let n = vec3<f32>(
        map(p + e.xyy).dist - map(p - e.xyy).dist,
        map(p + e.yxy).dist - map(p - e.yxy).dist,
        map(p + e.yyx).dist - map(p - e.yyx).dist
    );
    return normalize(n);
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - 0.5 * params.resolution.xy) / min(params.resolution.y, params.resolution.x);
    
    // Camera setup (3, 2, 2)
    let ro = vec3<f32>(3.0, 2.0, 2.0);
    let ta = vec3<f32>(0.0, 0.0, 0.0);
    
    let cw = normalize(ta - ro);
    let cp = vec3<f32>(0.0, 0.0, 1.0);
    let cu = normalize(cross(cw, cp));
    let cv = normalize(cross(cu, cw));
    let rd = normalize(uv.x * cu + uv.y * cv + 1.5 * cw);
    
    // Raymarching
    var t = 0.01;
    var final_color = vec3<f32>(0.05, 0.05, 0.08); // Background
    
    for (var i: i32 = 0; i < 80; i = i + 1) {
        let p = ro + rd * t;
        let hit = map(p);
        
        if (hit.dist < 0.001) {
            let n = get_normal(p);
            let light_dir = normalize(vec3<f32>(5.0, 5.0, 2.0));
            
            // Simple diffuse + ambient
            let diff = max(dot(n, light_dir), 0.0);
            let amb = 0.2;
            
            final_color = hit.color * (diff + amb);
            
            // Basic Specular
            let ref = reflect(-light_dir, n);
            let spec = pow(max(dot(rd, ref), 0.0), 32.0);
            final_color = final_color + vec3<f32>(spec * 0.3);
            break;
        }
        
        if (t > 20.0) {
            break;
        }
        t = t + hit.dist;
    }
    
    // Output final color with gamma correction
    return vec4<f32>(pow(final_color, vec3<f32>(0.4545)), 1.0);
}