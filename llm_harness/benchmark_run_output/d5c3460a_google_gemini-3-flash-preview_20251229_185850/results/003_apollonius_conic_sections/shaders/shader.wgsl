// Apollonius of Perga's Conic Sections
// Visualization of Ecliptic, Parabolic, and Hyperbolic cuts on a double cone.

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

// Ray-Plane Intersection
fn intersect_plane(ro: vec3<f32>, rd: vec3<f32>, p_orig: vec3<f32>, p_normal: vec3<f32>) -> f32 {
    let denom = dot(p_normal, rd);
    let t = dot(p_orig - ro, p_normal) / denom;
    return select(-1.0, t, abs(denom) > 1e-6);
}

// Cone SDF for visualization (30-degree angle from axis)
fn cone_sdf(p: vec3<f32>) -> f32 {
    let angle = 0.5235987756; // 30 degrees in radians
    let c = sin(angle);
    let s = cos(angle);
    let q = length(p.xy);
    return max(dot(vec2<f32>(s, -c), vec2<f32>(q, abs(p.z))), -10.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy * 2.0 - params.resolution) / min(params.resolution.x, params.resolution.y);
    
    // Background: Ancient Parchment
    var final_color = vec3<f32>(0.957, 0.910, 0.816);
    
    // Camera: Orthographic Projection
    let scale = 4.0;
    let ro = vec3<f32>(uv * scale, 10.0);
    let rd = vec3<f32>(0.0, 0.0, -1.0);
    
    // Rotate scene slightly for perspective
    let rot_x = 0.6;
    let rot_z = 0.4;
    let cos_x = cos(rot_x);
    let sin_x = sin(rot_x);
    let cos_z = cos(rot_z);
    let sin_z = sin(rot_z);
    
    let p_x = ro.x * cos_z - ro.y * sin_z;
    let p_y = ro.x * sin_z + ro.y * cos_z;
    let p_z = ro.z;
    
    let q_x = p_x;
    let q_y = p_y * cos_x - p_z * sin_x;
    let q_z = p_y * sin_x + p_z * cos_x;
    
    let d_px = rd.x * cos_z - rd.y * sin_z;
    let d_py = rd.x * sin_z + rd.y * cos_z;
    let d_pz = rd.z;
    
    let d_qx = d_px;
    let d_qy = d_py * cos_x - d_pz * sin_x;
    let d_qz = d_py * sin_x + d_pz * cos_x;
    
    let ro_prime = vec3<f32>(q_x, q_y, q_z);
    let rd_prime = vec3<f32>(d_qx, d_qy, d_qz);

    // 1. Render Double Cone (Wireframe/Translucent)
    // We sample along the ray to find the surface for the cone
    var dist = 0.0;
    var cone_mask = 0.0;
    for(var i: i32 = 0; i < 40; i = i + 1) {
        let p = ro_prime + rd_prime * dist;
        let d = cone_sdf(p);
        if (d < 0.005) {
            // Check for "grid" lines on the cone
            let angle_radial = atan2(p.y, p.x);
            let grid = sin(angle_radial * 8.0) * sin(p.z * 5.0);
            cone_mask = select(0.0, 0.15, grid > 0.9 && abs(p.z) < 3.0);
            break;
        }
        dist = dist + max(d, 0.01);
        if (dist > 20.0) { break; }
    }
    final_color = mix(final_color, vec3<f32>(0.4, 0.3, 0.2), cone_mask);

    // 2. Planes and Intersections
    // Ellipse Plane: 45°
    let p_ell_n = normalize(vec3<f32>(0.0, 1.0, 1.0));
    let t_ell = intersect_plane(ro_prime, rd_prime, vec3<f32>(0.0, 0.0, 0.5), p_ell_n);
    
    // Parabola Plane: 30° (Parallel to generator)
    let p_par_n = normalize(vec3<f32>(0.0, sin(0.5236), cos(0.5236)));
    let t_par = intersect_plane(ro_prime, rd_prime, vec3<f32>(0.0, 0.0, -0.5), p_par_n);
    
    // Hyperbola Plane: 15° (Steeper than cone angle)
    let p_hyp_n = normalize(vec3<f32>(0.0, 1.0, 0.2));
    let t_hyp = intersect_plane(ro_prime, rd_prime, vec3<f32>(0.0, 1.0, 0.0), p_hyp_n);

    // Intersection logic and coloring
    let thickness = 0.04;

    // Hyperbola (Red)
    if (t_hyp > 0.0) {
        let p = ro_prime + rd_prime * t_hyp;
        if (abs(p.x) < 2.5 && abs(p.y) < 2.5 && abs(p.z) < 3.0) {
            let d_cone = abs(cone_sdf(p));
            let edge = smoothstep(thickness, 0.0, d_cone);
            final_color = mix(final_color, vec3<f32>(0.8, 0.1, 0.1), edge * 0.8);
            final_color = mix(final_color, vec3<f32>(0.8, 0.1, 0.1), 0.05); // Plane tint
        }
    }

    // Parabola (Green)
    if (t_par > 0.0) {
        let p = ro_prime + rd_prime * t_par;
        if (abs(p.x) < 2.5 && abs(p.y) < 2.5 && abs(p.z) < 3.0) {
            let d_cone = abs(cone_sdf(p));
            let edge = smoothstep(thickness, 0.0, d_cone);
            final_color = mix(final_color, vec3<f32>(0.1, 0.6, 0.1), edge * 0.8);
            final_color = mix(final_color, vec3<f32>(0.1, 0.6, 0.1), 0.05);
        }
    }

    // Ellipse (Blue)
    if (t_ell > 0.0) {
        let p = ro_prime + rd_prime * t_ell;
        if (abs(p.x) < 2.5 && abs(p.y) < 2.5 && abs(p.z) < 3.0) {
            let d_cone = abs(cone_sdf(p));
            let edge = smoothstep(thickness, 0.0, d_cone);
            final_color = mix(final_color, vec3<f32>(0.1, 0.2, 0.8), edge * 0.9);
            final_color = mix(final_color, vec3<f32>(0.1, 0.2, 0.8), 0.05);
        }
    }

    // Add Axes / Geometric frame
    let axis_x = smoothstep(0.02, 0.0, length(uv - vec2<f32>(clamp(uv.x, -1.5, 1.5), 0.0)));
    final_color = mix(final_color, vec3<f32>(0.3), axis_x * 0.2);

    return vec4<f32>(final_color, 1.0);
}