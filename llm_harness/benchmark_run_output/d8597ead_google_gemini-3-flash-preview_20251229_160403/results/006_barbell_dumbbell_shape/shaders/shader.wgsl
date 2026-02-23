struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let res = exp(-k * a) + exp(-k * b);
    return -log(res) / k;
}

fn sd_sphere(p: vec3<f32>, r: f32) -> f32 {
    return length(p) - r;
}

fn sd_cylinder_x(p: vec3<f32>, r: f32, limit: f32) -> f32 {
    let d = vec2<f32>(length(p.yz) - r, abs(p.x) - limit);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

fn scene_sdf(p: vec3<f32>) -> vec2<f32> {
    // Sphere 1
    let s1 = sd_sphere(p - vec3<f32>(-2.5, 0.0, 0.0), 0.8);
    // Sphere 2
    let s2 = sd_sphere(p - vec3<f32>(2.5, 0.0, 0.0), 0.8);
    // Cylinder shaft
    let shaft = sd_cylinder_x(p, 0.3, 1.7);
    
    let spheres = min(s1, s2);
    let d = smin(spheres, shaft, 2.0);
    
    // ID 1.0 for spheres, 2.0 for shaft for material differentiation
    let material_id = select(2.0, 1.0, spheres < shaft);
    return vec2<f32>(d, material_id);
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    return normalize(vec3<f32>(
        scene_sdf(p + e.xyy).x - scene_sdf(p - e.xyy).x,
        scene_sdf(p + e.yxy).x - scene_sdf(p - e.yxy).x,
        scene_sdf(p + e.yyx).x - scene_sdf(p - e.yyx).x
    ));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Background Radial Gradient
    let bg_dist = length(uv);
    let bg_color = mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0, 1.0, 1.0), smoothstep(0.0, 1.0, bg_dist));
    
    // Camera setup
    let ro = vec3<f32>(4.0, 3.0, 5.0);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let ww = normalize(target_var - ro);
    let uu = normalize(cross(ww, vec3<f32>(0.0, 1.0, 0.0)));
    let vv = normalize(cross(uu, ww));
    let rd = normalize(uv.x * uu + uv.y * vv + 1.5 * ww);
    
    // Animation: Tilt 15 deg and Rotate
    let tilt_angle = 15.0 * (3.14159 / 180.0);
    let cos_t = cos(tilt_angle);
    let sin_t = sin(tilt_angle);
    let rot_z = mat3x3<f32>(
        vec3<f32>(cos_t, -sin_t, 0.0),
        vec3<f32>(sin_t, cos_t, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
    
    // Simulation of time for static image output based on context
    let time_val = 0.5; 
    let rot_angle = time_val * (2.0 * 3.14159 / 6.0);
    let cos_r = cos(rot_angle);
    let sin_r = sin(rot_angle);
    let rot_y = mat3x3<f32>(
        vec3<f32>(cos_r, 0.0, sin_r),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sin_r, 0.0, cos_r)
    );
    let obj_rot = rot_y * rot_z;
    let inv_rot = transpose(obj_rot);

    // Raymarching
    var t: f32 = 0.0;
    var d_res: vec2<f32>;
    var hit: bool = false;
    for (var i: i32 = 0; i < 100; i = i + 1) {
        let p = inv_rot * (ro + rd * t);
        d_res = scene_sdf(p);
        if (d_res.x < 0.001) {
            hit = true;
            break;
        }
        t = t + d_res.x;
        if (t > 20.0) { break; }
    }
    
    var color = bg_color;
    if (hit) {
        let p_world = ro + rd * t;
        let p_local = inv_rot * p_world;
        let n_local = get_normal(p_local);
        let n = obj_rot * n_local;
        let r_vec = reflect(rd, n);
        
        // PBR Properties
        var base_color = vec3<f32>(0.7, 0.7, 0.8);
        var roughness = 0.2;
        let metalness = 0.9;
        
        // Brushed metal effect for cylinder
        if (d_res.y > 1.5) {
            let brush = sin(p_local.x * 100.0) * 0.05;
            roughness = 0.4 + brush;
        } else {
            roughness = 0.05; // Polished chrome
        }
        
        // Lighting
        let light_dir = normalize(vec3<f32>(1.0, 2.0, 1.0));
        let fill_dir = normalize(vec3<f32>(-3.0, 1.0, 2.0) - p_world);
        let rim_dir = normalize(vec3<f32>(-1.0, 0.0, -1.0));
        
        // Simple BRDF
        let diff = max(dot(n, light_dir), 0.0) * 0.8;
        let fill = max(dot(n, fill_dir), 0.0) * 0.4;
        let rim = pow(max(0.0, 1.0 - max(dot(n, -rd), 0.0)), 4.0) * 0.3;
        
        // Reflections (Procedural environment)
        let sky_reflection = mix(vec3<f32>(0.5, 0.6, 0.8), vec3<f32>(1.0), smoothstep(-0.2, 0.2, r_vec.y));
        
        let specular = pow(max(dot(r_vec, light_dir), 0.0), 32.0 / roughness);
        
        let lighting = (diff + fill) * base_color + rim * vec3<f32>(1.0) + specular * 0.5;
        let reflected_part = sky_reflection * base_color;
        
        color = mix(lighting, reflected_part, metalness * (1.0 - roughness));
        
        // Subtle ambient occlusion
        let ao = clamp(d_res.x * 10.0, 0.5, 1.0);
        color = color * ao;
    }
    
    // Output with simple Gamma Correction
    return vec4<f32>(pow(color, vec3<f32>(0.4545)), 1.0);
}