// Apollonius's Conic Sections - Ancient Greek Mathematical Visualization
// A shader rendering the three conic sections (ellipse, parabola, hyperbola)
// emerging from a double cone through different cutting planes

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
// GEOMETRIC PRIMITIVES AND UTILITIES
// ============================================================================

// Distance to cone surface: x² + y² = (z·tan(30°))²
// Cone half-angle: 30° from vertical (tan(30°) ≈ 0.577)
fn cone_sdf(p: vec3<f32>) -> f32 {
    let cone_angle = 0.57735; // tan(30°)
    let cone_dist = sqrt(p.x * p.x + p.y * p.y) - abs(p.z) * cone_angle;
    return cone_dist;
}

// Distance to ellipse cutting plane (45° to cone axis, z-offset)
fn ellipse_plane_sdf(p: vec3<f32>) -> f32 {
    let plane_normal = normalize(vec3<f32>(0.7071, 0.0, 0.7071));
    let plane_point = vec3<f32>(0.0, 0.0, 1.5);
    let dist_to_plane = dot(p - plane_point, plane_normal);
    return dist_to_plane;
}

// Distance to parabola cutting plane (parallel to cone generator, 30° from vertical)
fn parabola_plane_sdf(p: vec3<f32>) -> f32 {
    let plane_normal = normalize(vec3<f32>(0.866, 0.0, 0.5));
    let plane_point = vec3<f32>(0.0, 0.0, 0.0);
    let dist_to_plane = dot(p - plane_point, plane_normal);
    return dist_to_plane;
}

// Distance to hyperbola cutting plane (15° to cone axis, steeper than cone)
fn hyperbola_plane_sdf(p: vec3<f32>) -> f32 {
    let plane_normal = normalize(vec3<f32>(0.2588, 0.0, 0.9659));
    let plane_point = vec3<f32>(0.0, 0.0, 0.0);
    let dist_to_plane = dot(p - plane_point, plane_normal);
    return dist_to_plane;
}

// Ray-cone intersection for 3D raymarching
fn ray_march(ro: vec3<f32>, rd: vec3<f32>, max_steps: u32) -> f32 {
    var t = 0.0;
    var _unused_step = 0u;
    
    loop {
        if (_unused_step >= max_steps) { break; }
        
        let p = ro + rd * t;
        let d = cone_sdf(p);
        
        if (abs(d) < 0.01 || t > 8.0) { break; }
        
        t = t + d * 0.5;
        _unused_step = _unused_step + 1u;
    }
    
    return t;
}

// Calculate normal on cone surface via finite differences
fn cone_normal(p: vec3<f32>) -> vec3<f32> {
    let eps = 0.001;
    let dx = cone_sdf(p + vec3<f32>(eps, 0.0, 0.0)) - cone_sdf(p - vec3<f32>(eps, 0.0, 0.0));
    let dy = cone_sdf(p + vec3<f32>(0.0, eps, 0.0)) - cone_sdf(p - vec3<f32>(0.0, eps, 0.0));
    let dz = cone_sdf(p + vec3<f32>(0.0, 0.0, eps)) - cone_sdf(p - vec3<f32>(0.0, 0.0, eps));
    return normalize(vec3<f32>(dx, dy, dz));
}

// ============================================================================
// COLOR MAPPING AND RENDERING
// ============================================================================

// Get section type at point p (which plane is closest)
fn get_section_type(p: vec3<f32>) -> i32 {
    let d_ellipse = abs(ellipse_plane_sdf(p));
    let d_parabola = abs(parabola_plane_sdf(p));
    let d_hyperbola = abs(hyperbola_plane_sdf(p));
    
    var min_dist = d_ellipse;
    var section_type = 0i; // ellipse
    
    if (d_parabola < min_dist) {
        min_dist = d_parabola;
        section_type = 1i; // parabola
    }
    
    if (d_hyperbola < min_dist) {
        min_dist = d_hyperbola;
        section_type = 2i; // hyperbola
    }
    
    return section_type;
}

// Ancient Greek color scheme
fn section_color(section_type: i32) -> vec3<f32> {
    if (section_type == 0i) {
        return vec3<f32>(0.0, 0.2, 0.6); // Deep blue (celestial)
    } else if (section_type == 1i) {
        return vec3<f32>(0.2, 0.6, 0.2); // Green (earthly)
    } else {
        return vec3<f32>(0.8, 0.1, 0.1); // Red (infinite)
    }
}

// Wireframe cone generator lines
fn cone_generator_visibility(p: vec3<f32>) -> f32 {
    let angle = atan2(p.y, p.x);
    let wrapped = angle % 1.5708; // π/2 intervals
    let generator_width = 0.05;
    let stripe = smoothstep(generator_width, 0.0, abs(wrapped - 0.7854));
    return stripe * (1.0 - smoothstep(0.01, 0.0, cone_sdf(p)));
}

// ============================================================================
// 3D SCENE CONSTRUCTION
// ============================================================================

fn scene_color(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    // Raymarch to find cone surface
    let t = ray_march(ro, rd, 128u);
    let p = ro + rd * t;
    
    // Background: parchment color
    let bg_color = vec3<f32>(0.956, 0.910, 0.816); // #F4E8D0
    
    // If no hit, return background
    if (t > 7.9) {
        return vec4<f32>(bg_color, 1.0);
    }
    
    // Cone hit: compute lighting
    let cone_d = cone_sdf(p);
    if (abs(cone_d) > 0.1) {
        return vec4<f32>(bg_color, 1.0);
    }
    
    // Determine which conic section this point belongs to
    let section = get_section_type(p);
    let section_col = section_color(section);
    
    // Surface normal
    let n = cone_normal(p);
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
    
    // Lambertian shading
    let diffuse = max(0.0, dot(n, light_dir)) * 0.7 + 0.3;
    
    // Add cone generator visibility (wireframe effect)
    let generator = cone_generator_visibility(p);
    
    // Plane intersection emphasis: fade color toward white at plane intersection
    let ellipse_d = abs(ellipse_plane_sdf(p));
    let parabola_d = abs(parabola_plane_sdf(p));
    let hyperbola_d = abs(hyperbola_plane_sdf(p));
    
    let plane_emphasis = smoothstep(0.3, 0.0, min(min(ellipse_d, parabola_d), hyperbola_d));
    
    let lit_color = section_col * diffuse;
    let emphasized = mix(lit_color, vec3<f32>(1.0), plane_emphasis * 0.4);
    let with_generator = mix(emphasized, vec3<f32>(0.3, 0.3, 0.3), generator * 0.6);
    
    return vec4<f32>(with_generator, 1.0);
}

// ============================================================================
// VIEWPORT PROJECTION
// ============================================================================

fn setup_camera(uv: vec2<f32>, time: f32) -> array<vec3<f32>, 2> {
    // Orthographic projection mimicking ancient Greek geometric diagrams
    // Rotation for 3D viewing
    let angle_x = sin(time * 0.3) * 0.5;
    let angle_y = time * 0.2;
    
    let cos_x = cos(angle_x);
    let sin_x = sin(angle_x);
    let cos_y = cos(angle_y);
    let sin_y = sin(angle_y);
    
    // Ray origin at distance
    let distance = 4.0;
    let ro_raw = vec3<f32>(
        distance * sin_y,
        distance * sin_x,
        distance * cos_y * cos_x
    );
    
    // Rotate to face origin
    let ro_x = ro_raw.x;
    let ro_y = ro_raw.y * cos_x - ro_raw.z * sin_x;
    let ro_z = ro_raw.y * sin_x + ro_raw.z * cos_x;
    
    let ro = vec3<f32>(ro_x, ro_y, ro_z);
    
    // Ray direction from orthographic view
    // Map screen coordinates to view plane
    let view_scale = 2.0;
    let right = vec3<f32>(cos_y, 0.0, sin_y);
    let up = vec3<f32>(-sin_y * sin_x, cos_x, cos_y * sin_x);
    let forward = normalize(-ro);
    
    let screen_x = right * (uv.x * view_scale);
    let screen_y = up * (uv.y * view_scale);
    
    let rd = normalize(forward + screen_x + screen_y);
    
    // Return as array: [ro, rd]
    var result: array<vec3<f32>, 2>;
    result[0u] = ro;
    result[1u] = rd;
    return result;
}

// ============================================================================
// MAIN FRAGMENT SHADER
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize screen coordinates
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    let aspect = params.resolution.x / params.resolution.y;
    let uv_corrected = vec2<f32>(uv.x * aspect, uv.y);
    
    // Setup camera (orthographic projection)
    let cam = setup_camera(uv_corrected, params.time);
    let ro = cam[0u];
    let rd = cam[1u];
    
    // Render scene
    let scene_result = scene_color(ro, rd);
    
    // Optional: Add border frame for "ancient diagram" aesthetic
    let border_dist = min(
        min(abs(uv.x) - 0.95, abs(uv.y) - 0.95),
        max(abs(uv.x) - 0.98, abs(uv.y) - 0.98)
    );
    let border = smoothstep(0.02, 0.0, border_dist);
    
    let final_color = mix(scene_result.xyz, vec3<f32>(0.3, 0.2, 0.1), border * 0.3);
    
    return vec4<f32>(final_color, 1.0);
}