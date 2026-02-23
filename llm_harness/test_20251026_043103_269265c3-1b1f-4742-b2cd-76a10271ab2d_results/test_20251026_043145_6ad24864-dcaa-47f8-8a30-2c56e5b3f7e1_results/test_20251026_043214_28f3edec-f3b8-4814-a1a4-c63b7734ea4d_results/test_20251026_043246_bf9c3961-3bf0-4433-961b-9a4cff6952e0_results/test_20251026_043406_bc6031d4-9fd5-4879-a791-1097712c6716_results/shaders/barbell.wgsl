// Barbell/Dumbbell Visualization - High-Quality PBR Metallic Rendering
// Raymarched signed distance field with smooth blending

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

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

fn smin(a: f32, b: f32, k: f32) -> f32 {
    let ka = clamp(-k * a, -80.0, 80.0);
    let kb = clamp(-k * b, -80.0, 80.0);
    let exp_a = exp(ka);
    let exp_b = exp(kb);
    let sum_exp = exp_a + exp_b;
    return select(a, b, sum_exp < 1e-20) - log(select(sum_exp, 1e-20, sum_exp < 1e-20)) / k;
}

fn rotate_z(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(
        p.x * c - p.y * s,
        p.x * s + p.y * c,
        p.z
    );
}

fn rotate_y(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(
        p.x * c + p.z * s,
        p.y,
        -p.x * s + p.z * c
    );
}

// ============================================================================
// SIGNED DISTANCE FUNCTIONS
// ============================================================================

fn sd_sphere(p: vec3<f32>, r: f32) -> f32 {
    return length(p) - r;
}

fn sd_cylinder(p: vec3<f32>, r: f32, h: f32) -> f32 {
    let d = abs(vec2<f32>(length(p.yz), p.x)) - vec2<f32>(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

// ============================================================================
// BARBELL SDF
// ============================================================================

fn barbell_sdf(p: vec3<f32>) -> vec4<f32> {
    let p_left = p - vec3<f32>(-2.5, 0.0, 0.0);
    let d_sphere_left = sd_sphere(p_left, 0.8);
    
    let p_right = p - vec3<f32>(2.5, 0.0, 0.0);
    let d_sphere_right = sd_sphere(p_right, 0.8);
    
    let p_cyl = p;
    let d_cylinder = sd_cylinder(p_cyl, 0.3, 1.7);
    
    let k_blend = 2.0;
    var d_distance = smin(d_sphere_left, d_sphere_right, k_blend);
    d_distance = smin(d_distance, d_cylinder, k_blend);
    
    var material = 0u;
    if d_cylinder < d_sphere_left && d_cylinder < d_sphere_right {
        material = 1u;
    }
    
    return vec4<f32>(d_distance, f32(material), 0.0, 0.0);
}

// ============================================================================
// RAYMARCHING
// ============================================================================

fn raymarch(ro: vec3<f32>, rd: vec3<f32>, max_dist: f32) -> vec4<f32> {
    var t = 0.1;
    var material_id = 0u;
    
    for (var i = 0u; i < 256u; i = i + 1u) {
        if t > max_dist {
            break;
        }
        
        let p = ro + rd * t;
        let sdf_result = barbell_sdf(p);
        let d = sdf_result.x;
        material_id = u32(sdf_result.y);
        
        if d < 0.001 {
            return vec4<f32>(t, f32(material_id), 0.0, 1.0);
        }
        
        t = t + max(d * 0.8, 0.002);
    }
    
    return vec4<f32>(t, -1.0, 0.0, 0.0);
}

// ============================================================================
// NORMAL CALCULATION
// ============================================================================

fn compute_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let n = vec3<f32>(
        barbell_sdf(p + vec3<f32>(eps, 0.0, 0.0)).x - barbell_sdf(p - vec3<f32>(eps, 0.0, 0.0)).x,
        barbell_sdf(p + vec3<f32>(0.0, eps, 0.0)).x - barbell_sdf(p - vec3<f32>(0.0, eps, 0.0)).x,
        barbell_sdf(p + vec3<f32>(0.0, 0.0, eps)).x - barbell_sdf(p - vec3<f32>(0.0, 0.0, eps)).x
    );
    return normalize(n);
}

// ============================================================================
// LIGHTING & PBR
// ============================================================================

fn pbr_light(normal: vec3<f32>, view_dir: vec3<f32>, light_dir: vec3<f32>, 
             light_color: vec3<f32>, metalness: f32, roughness: f32) -> vec3<f32> {
    let half_dir = normalize(view_dir + light_dir);
    let n_dot_l = max(dot(normal, light_dir), 0.0);
    let n_dot_h = max(dot(normal, half_dir), 0.0);
    let v_dot_h = max(dot(view_dir, half_dir), 0.0);
    
    let f0 = mix(vec3<f32>(0.04), vec3<f32>(0.7, 0.7, 0.8), metalness);
    let fresnel = f0 + (vec3<f32>(1.0) - f0) * pow(1.0 - v_dot_h, 5.0);
    
    let spec_factor = pow(n_dot_h, mix(100.0, 10.0, roughness));
    
    let diffuse = (1.0 - metalness) * n_dot_l / 3.14159;
    let specular = fresnel * spec_factor * 0.5;
    
    return (diffuse + specular) * light_color * n_dot_l;
}

// ============================================================================
// FRAGMENT SHADER
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    let cam_pos = vec3<f32>(4.0, 3.0, 5.0);
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_up = vec3<f32>(0.0, 1.0, 0.0);
    
    let ndc = (uv - 0.5) * 2.0;
    let ndc_adj = vec3<f32>(ndc.x * aspect, ndc.y, 1.0);
    
    let f = normalize(cam_target - cam_pos);
    let r = normalize(cross(f, cam_up));
    let u = cross(r, f);
    
    let ray_dir = normalize(r * ndc_adj.x + u * ndc_adj.y + f * ndc_adj.z);
    
    let march = raymarch(cam_pos, ray_dir, 50.0);
    let hit_dist = march.x;
    let material = u32(march.y);
    let hit = march.w > 0.5;
    
    var bg_color = mix(
        vec3<f32>(0.9, 0.9, 0.95),
        vec3<f32>(1.0, 1.0, 1.0),
        length(uv - vec2<f32>(0.5)) * 0.4
    );
    
    if !hit {
        return vec4<f32>(bg_color, 1.0);
    }
    
    let hit_pos = cam_pos + ray_dir * hit_dist;
    let normal = compute_normal(hit_pos);
    let view_dir = normalize(cam_pos - hit_pos);
    
    var metalness = 0.9;
    var roughness = 0.2;
    var base_color = vec3<f32>(0.7, 0.7, 0.8);
    
    if material == 1u {
        roughness = 0.3;
    }
    
    let light1_dir = normalize(vec3<f32>(1.0, 2.0, 1.0));
    let light1_color = vec3<f32>(0.8, 0.8, 0.8);
    
    let light2_pos = vec3<f32>(-3.0, 1.0, 2.0);
    let light2_dir = normalize(light2_pos - hit_pos);
    let light2_color = vec3<f32>(0.3, 0.3, 0.4);
    
    let light3_dir = normalize(vec3<f32>(-1.0, 0.0, -1.0));
    let light3_color = vec3<f32>(0.2, 0.2, 0.25);
    
    var final_color = base_color * 0.1;
    
    final_color = final_color + pbr_light(normal, view_dir, light1_dir, light1_color, metalness, roughness) * 0.8;
    final_color = final_color + pbr_light(normal, view_dir, light2_dir, light2_color, metalness, roughness) * 0.4;
    final_color = final_color + pbr_light(normal, view_dir, light3_dir, light3_color, metalness, roughness) * 0.3;
    
    let shadow_march = raymarch(hit_pos + normal * 0.02, light1_dir, 20.0);
    let in_shadow = select(1.0, 0.7, shadow_march.w > 0.5);
    final_color = final_color * in_shadow;
    
    return vec4<f32>(final_color, 1.0);
}