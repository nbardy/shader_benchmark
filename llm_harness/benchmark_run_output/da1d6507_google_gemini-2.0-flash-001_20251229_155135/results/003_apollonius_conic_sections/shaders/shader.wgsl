@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    time: f32,
    aspect: f32,
    resolution: vec2<f32>,
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

fn cone_surface(uv: vec2<f32>, z: f32) -> f32 {
    let cone_angle = radians(30.0);
    let radius = abs(z) * tan(cone_angle);
    let dist = length(uv);
    return smoothstep(radius - 0.01, radius + 0.01, dist);
}

fn plane_distance(point: vec3<f32>, normal: vec3<f32>, offset: f32) -> f32 {
    return abs(dot(point, normal) + offset);
}

fn wireframe(value: f32, thickness: f32) -> f32 {
    return smoothstep(thickness, 0.0, value);
}

fn radians(degrees: f32) -> f32 {
    return degrees * 3.14159265359 / 180.0;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    let background_color = vec3<f32>(0.95686, 0.90980, 0.81569); // Parchment color
    var col: vec3<f32> = background_color;

    let cone_start_z = -3.0;
    let cone_end_z = 3.0;
    let num_segments = 20.0;
    let z_step = (cone_end_z - cone_start_z) / num_segments;
    
    // Cone wireframe
    let wireframe_thickness = 0.005;
    var cone_color : vec3<f32> = vec3<f32>(0.8, 0.8, 0.8); // Light gray
    for (var i: f32 = 0.0; i < num_segments; i = i + 1.0) {
        let z = cone_start_z + i * z_step;
        let cone_val = cone_surface(uv, z);
        let cone_wire = wireframe(cone_val, wireframe_thickness);
        col = mix(col, cone_color, cone_wire);
    }

    // Ellipse plane
    let ellipse_angle = radians(45.0);
    let ellipse_normal = normalize(vec3<f32>(0.0, sin(ellipse_angle), cos(ellipse_angle)));
    let ellipse_offset = 0.0;
    let ellipse_point = vec3<f32>(uv.x, uv.y, 0.0);
    let ellipse_dist = plane_distance(ellipse_point, ellipse_normal, ellipse_offset);
    let ellipse_plane_color = vec3<f32>(0.2, 0.2, 0.8); //Deep blue - Celestial motion
    let ellipse_plane_alpha = smoothstep(0.02, 0.0, ellipse_dist);
    col = mix(col, ellipse_plane_color, ellipse_plane_alpha * 0.5); // Semi-transparent

     // Parabola plane
    let parabola_angle = radians(30.0);
    let parabola_normal = normalize(vec3<f32>(0.0, sin(parabola_angle), cos(parabola_angle)));
    let parabola_offset = 0.0;
    let parabola_dist = plane_distance(ellipse_point, parabola_normal, parabola_offset);
    let parabola_plane_color = vec3<f32>(0.2, 0.8, 0.2); //Green - Earthly trajectories
    let parabola_plane_alpha = smoothstep(0.02, 0.0, parabola_dist);
    col = mix(col, parabola_plane_color, parabola_plane_alpha * 0.5);

    // Hyperbola plane
    let hyperbola_angle = radians(15.0);
    let hyperbola_normal = normalize(vec3<f32>(0.0, sin(hyperbola_angle), cos(hyperbola_angle)));
    let hyperbola_offset = 0.0;
    let hyperbola_dist = plane_distance(ellipse_point, hyperbola_normal, hyperbola_offset);
    let hyperbola_plane_color = vec3<f32>(0.8, 0.2, 0.2); //Red - Infinite extension
    let hyperbola_plane_alpha = smoothstep(0.02, 0.0, hyperbola_dist);
    col = mix(col, hyperbola_plane_color, hyperbola_plane_alpha * 0.5);

    // Conic section intersections (highlighted)
    //Approximation of the conic section curves by identifying areas close to both cone and plane
    let curve_thickness = 0.01;

    for (var i: f32 = 0.0; i < num_segments; i = i + 1.0) {
        let z = cone_start_z + i * z_step;
        let cone_val = cone_surface(uv, z);

        // Ellipse
        let ellipse_point_z = vec3<f32>(uv.x, uv.y, z);
        let ellipse_dist_z = plane_distance(ellipse_point_z, ellipse_normal, ellipse_offset);
        let ellipse_curve = wireframe(cone_val + ellipse_dist_z, curve_thickness);
        col = mix(col, ellipse_plane_color, ellipse_curve);

        // Parabola
        let parabola_point_z = vec3<f32>(uv.x, uv.y, z);
        let parabola_dist_z = plane_distance(parabola_point_z, parabola_normal, parabola_offset);
        let parabola_curve = wireframe(cone_val + parabola_dist_z, curve_thickness);
        col = mix(col, parabola_plane_color, parabola_curve);

        //Hyperbola
        let hyperbola_point_z = vec3<f32>(uv.x, uv.y, z);
         let hyperbola_dist_z = plane_distance(hyperbola_point_z, hyperbola_normal, hyperbola_offset);
        let hyperbola_curve = wireframe(cone_val + hyperbola_dist_z, curve_thickness);
        col = mix(col, hyperbola_plane_color, hyperbola_curve);
    }

    return vec4<f32>(col, 1.0);
}