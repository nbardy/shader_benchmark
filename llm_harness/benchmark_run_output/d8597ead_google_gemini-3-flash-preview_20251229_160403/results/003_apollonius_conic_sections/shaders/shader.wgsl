// Apollonius's Conic Sections: Infinite Oblique Double Cone Visualization
// A tribute to Apollonius of Perga (c. 240-190 BCE)

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

// Distance to a line segment for curve drawing
fn sd_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Ray-Plane Intersection
fn intersect_plane(ro: vec3<f32>, rd: vec3<f32>, p_norm: vec3<f32>, p_dist: f32) -> f32 {
    let denom = dot(rd, p_norm);
    return select(-1.0, (p_dist - dot(ro, p_norm)) / denom, abs(denom) > 0.0001);
}

// Cone Surface Function: x^2 + y^2 = (z * tan(30))^2
// Simplified: x^2 + y^2 - z^2 * 0.333333 = 0
fn sd_cone(p: vec3<f32>) -> f32 {
    let tan30 = 0.577350269;
    let r = length(p.xy);
    return r - abs(p.z) * tan30;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - 0.5 * params.resolution.xy) / min(params.resolution.y, params.resolution.x);
    
    // Background: Parchment Color #F4E8D0
    let bg_color = vec3<f32>(0.957, 0.910, 0.816);
    var color = bg_color;

    // View Setup (Orthographic-ish for geometric diagram feel)
    let zoom = 6.0;
    let ro = vec3<f32>(uv * zoom, 10.0);
    let rd = vec3<f32>(0.0, 0.0, -1.0);

    // Rotation for better 3D visualization
    let cos_t = 0.866; // 30 deg
    let sin_t = 0.5;
    let rot_x = mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, cos_t, -sin_t),
        vec3<f32>(0.0, sin_t, cos_t)
    );
    let rot_y = mat3x3<f32>(
        vec3<f32>(0.866, 0.0, 0.5),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-0.5, 0.0, 0.866)
    );
    let rot = rot_y * rot_x;

    // Raycast Scene
    var min_t = 100.0;
    
    // 1. Plane Definitions (Normal vectors and offsets)
    // Degrees: Ellipse (45), Parabola (30), Hyperbola (15) relative to Z
    let n_ellipse   = rot * vec3<f32>(0.0, 0.707, 0.707); // 45 deg
    let n_parabola  = rot * vec3<f32>(0.0, 0.5, 0.866);   // 30 deg (parallel to generator)
    let n_hyperbola = rot * vec3<f32>(0.0, 0.259, 0.966); // 15 deg
    
    let plane_d = 0.8;

    // 2. Fragment logic for intersection curves
    // Sampling the cone surface at the plane intersections
    let t_e = intersect_plane(ro, rd, n_ellipse, plane_d);
    let t_p = intersect_plane(ro, rd, n_parabola, plane_d);
    let t_h = intersect_plane(ro, rd, n_hyperbola, plane_d);

    // Colors
    let blue  = vec3<f32>(0.1, 0.2, 0.6); // Ellipse
    let green = vec3<f32>(0.1, 0.5, 0.2); // Parabola
    let red   = vec3<f32>(0.7, 0.1, 0.1); // Hyperbola

    // Grid / Ink lines
    let grid = step(0.99, fract(uv.x * 10.0)) + step(0.99, fract(uv.y * 10.0));
    color = mix(color, vec3<f32>(0.8, 0.75, 0.65), grid * 0.5);

    // Render Cone Wireframe (Translucent)
    for (var i: i32 = 0; i < 12; i = i + 1) {
        let angle = f32(i) * 0.523598; // 30 degrees in radians
        let dir = vec3<f32>(cos(angle), sin(angle), 1.732); // Generator vector
        let p1 = rot * (dir * 2.0);
        let p2 = rot * (dir * -2.0);
        
        // Orthographic projection of the 3D lines
        let d = sd_segment(ro.xy, p1.xy, p2.xy);
        color = mix(color, vec3<f32>(0.4, 0.35, 0.3), 1.0 - smoothstep(0.01, 0.02, d));
    }

    // Render Planes and their Intersections
    // Ellipse Line
    if (t_e > 0.0) {
        let p = ro + rd * t_e;
        let dist_to_cone = abs(sd_cone(transpose(rot) * p));
        color = mix(color, blue, 1.0 - smoothstep(0.0, 0.06, dist_to_cone));
    }
    
    // Parabola Line
    if (t_p > 0.0) {
        let p = ro + rd * t_p;
        let dist_to_cone = abs(sd_cone(transpose(rot) * p));
        color = mix(color, green, 1.0 - smoothstep(0.0, 0.06, dist_to_cone));
    }
    
    // Hyperbola Line
    if (t_h > 0.0) {
        let p = ro + rd * t_h;
        let dist_to_cone = abs(sd_cone(transpose(rot) * p));
        color = mix(color, red, 1.0 - smoothstep(0.0, 0.06, dist_to_cone));
    }

    // Border and Vignette
    let edge = smoothstep(0.48, 0.5, max(abs(uv.x), abs(uv.y)));
    color = mix(color, vec3<f32>(0.2, 0.15, 0.1), edge);

    return vec4<f32>(color, 1.0);
}