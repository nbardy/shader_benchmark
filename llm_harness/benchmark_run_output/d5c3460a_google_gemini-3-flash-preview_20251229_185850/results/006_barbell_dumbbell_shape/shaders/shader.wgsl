// Vertex Shader: Full-screen triangle logic
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// Global Uniforms
struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

// Smooth minimum function for seamless blending
fn smin(d1: f32, d2: f32, k: f32) -> f32 {
    let res = exp(-k * d1) + exp(-k * d2);
    return -log(res) / k;
}

// Signed Distance Functions
fn sd_sphere(p: vec3<f32>, s: f32) -> f32 {
    return length(p) - s;
}

fn sd_cylinder_x(p: vec3<f32>, h: f32, r: f32) -> f32 {
    let d = abs(vec2<f32>(length(p.yz), p.x)) - vec2<f32>(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, vec2<f32>(0.0)));
}

// Scene definition (SDF)
fn scene(p: vec3<f32>) -> vec2<f32> {
    // Rotation logic: Tilt 15 deg (0.26 rad) and spin
    // Note: In static image, we treat time as 0 or a fixed constant since it's a single raw image.
    let tilt_angle = 0.2618;
    let rotation_angle = 1.2; // Fixed rotation for better visual angle in single frame
    
    let cos_t = cos(tilt_angle);
    let sin_t = sin(tilt_angle);
    let cos_r = cos(rotation_angle);
    let sin_r = sin(rotation_angle);
    
    // RotateAroundY then RotateAroundZ
    var pr = p;
    pr = vec3<f32>(pr.x * cos_r + pr.z * sin_r, pr.y, -pr.x * sin_r + pr.z * cos_r);
    pr = vec3<f32>(pr.x * cos_t - pr.y * sin_t, pr.x * sin_t + pr.y * cos_t, pr.z);

    // Geometry components
    let d_sphere1 = sd_sphere(pr - vec3<f32>(-2.5, 0.0, 0.0), 0.8);
    let d_sphere2 = sd_sphere(pr - vec3<f32>(2.5, 0.0, 0.0), 0.8);
    let d_shaft = sd_cylinder_x(pr, 1.7, 0.3);

    // Blending
    let spheres = min(d_sphere1, d_sphere2);
    let d_total = smin(spheres, d_shaft, 2.0);

    // Material ID: 1.0 for spheres, 2.0 for shaft (using distance heuristic)
    let m_id = select(2.0, 1.0, spheres < d_shaft);

    return vec2<f32>(d_total, m_id);
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    return normalize(vec3<f32>(
        scene(p + e.xyy).x - scene(p - e.xyy).x,
        scene(p + e.yxy).x - scene(p - e.yxy).x,
        scene(p + e.yyx).x - scene(p - e.yyx).x
    ));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - 0.5 * params.resolution.xy) / params.resolution.y;

    // Camera setup
    let ro = vec3<f32>(4.0, 3.0, 5.0);
    let look_at = vec3<f32>(0.0, 0.0, 0.0);
    let fwd = normalize(look_at - ro);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), fwd));
    let up = cross(fwd, right);
    let rd = normalize(fwd + uv.x * right + uv.y * up);

    // Raymarching
    var t = 0.0;
    var res = vec2<f32>(-1.0, -1.0);
    for (var i = 0; i < 128; i++) {
        let p = ro + rd * t;
        let d = scene(p);
        if (d.x < 0.001) {
            res = vec2<f32>(t, d.y);
            break;
        }
        if (t > 20.0) { break; }
        t = t + d.x;
    }

    // Background Gradient
    let sky_grad = clamp(0.5 + 0.5 * rd.y, 0.0, 1.0);
    let bg_color = mix(vec3<f32>(0.9, 0.9, 0.95), vec3<f32>(1.0, 1.0, 1.0), sky_grad);
    var color = bg_color;

    if (res.x > 0.0) {
        let p = ro + rd * res.x;
        let n = get_normal(p);
        let v = -rd;

        // PBR Logic
        var base_color = vec3<f32>(0.7, 0.7, 0.82);
        var roughness = 0.2;
        let metalness = 0.9;

        if (res.y > 1.5) { // Shaft logic
            roughness = 0.4; // Brushed metal
            base_color = vec3<f32>(0.65, 0.65, 0.7);
        }

        // Lights
        let l1_dir = normalize(vec3<f32>(1.0, 2.0, 1.0));
        let l2_pos = vec3<f32>(-3.0, 1.0, 2.0);
        let l3_dir = normalize(vec3<f32>(-1.0, 0.0, -1.0));

        // Primary Directional
        let diff1 = max(dot(n, l1_dir), 0.0) * 0.8;
        let r1 = reflect(-l1_dir, n);
        let spec1 = pow(max(dot(r1, v), 0.0), 32.0) * metalness;

        // Fill Point Light
        let l2_lv = l2_pos - p;
        let l2_dist = length(l2_lv);
        let l2_dir = normalize(l2_lv);
        let diff2 = max(dot(n, l2_dir), 0.0) * (0.4 / (1.0 + l2_dist * l2_dist));

        // Rim Light
        let rim = pow(1.0 - max(dot(n, v), 0.0), 4.0) * 0.3 * max(dot(n, l3_dir), 0.0);

        // Ambient / Environment Reflection
        let ref_dir = reflect(rd, n);
        let env = mix(vec3<f32>(0.2, 0.2, 0.25), vec3<f32>(0.8, 0.8, 0.9), ref_dir.y * 0.5 + 0.5);
        let reflection = env * metalness * (1.0 - roughness);

        // Final Composition
        let diffuse = (diff1 + diff2) * base_color * (1.0 - metalness);
        let specular = (spec1 + rim) * vec3<f32>(1.0);
        
        color = diffuse + specular + reflection + base_color * 0.05;
    }

    // Tonemapping and Gamma
    color = color / (color + vec3<f32>(1.0));
    color = pow(color, vec3<f32>(1.0 / 2.2));

    return vec4<f32>(color, 1.0);
}