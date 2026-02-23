// Apollonius's Conic Sections - Ancient Greek Geometric Visualization
// Historical rendering of ellipse, parabola, and hyperbola from a double cone
// Following the mathematical treatise "Conics" (c. 200 BCE)

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

// Constants for cone geometry (Apollonius's construction)
const CONE_ANGLE: f32 = 0.523598776f;  // 30 degrees in radians: pi/6
const CONE_HEIGHT: f32 = 3.0;
const PARCHMENT_R: f32 = 0.956862745f;  // #F4E8D0
const PARCHMENT_G: f32 = 0.909803922f;
const PARCHMENT_B: f32 = 0.815686275f;

// Helper: project 3D point to 2D screen with isometric view
fn projectPoint(pos_3d: vec3<f32>, uv: vec2<f32>) -> f32 {
    // Rotation angles for isometric-like view
    let angle_x = 0.4;
    let angle_y = 0.6;
    
    let cos_x = cos(angle_x);
    let sin_x = sin(angle_x);
    let cos_y = cos(angle_y);
    let sin_y = sin(angle_y);
    
    // Apply rotations
    let rotated_x = vec3<f32>(
        pos_3d.x,
        pos_3d.y * cos_x - pos_3d.z * sin_x,
        pos_3d.y * sin_x + pos_3d.z * cos_x
    );
    
    let rotated = vec3<f32>(
        rotated_x.x * cos_y + rotated_x.z * sin_y,
        rotated_x.y,
        -rotated_x.x * sin_y + rotated_x.z * cos_y
    );
    
    // Orthographic projection
    let proj_xy = rotated.xy * 0.35;
    return length(uv - proj_xy);
}

// Helper: get conic curve intersection point
fn getConicPoint(angle: f32, z_sample: f32, conic_type: i32) -> vec3<f32> {
    let cone_r = abs(z_sample) * tan(CONE_ANGLE);
    
    var r_adjust = cone_r;
    
    if (conic_type == 0) {
        // Ellipse: reduce radius as z increases
        r_adjust = cone_r * (1.0 - abs(z_sample) * 0.15);
    } else if (conic_type == 1) {
        // Parabola: gradual deformation
        r_adjust = cone_r * (1.0 + z_sample * z_sample * 0.05);
    } else {
        // Hyperbola: increase radius
        r_adjust = cone_r * (1.0 + abs(z_sample) * 0.2);
    }
    
    let x = cos(angle) * r_adjust;
    let y = sin(angle) * r_adjust;
    
    return vec3<f32>(x, y, z_sample);
}

// Helper: render conic intersection curve
fn renderConicCurve(uv: vec2<f32>, conic_type: i32) -> vec3<f32> {
    var curve_color = vec3<f32>(0.0, 0.0, 0.0);
    var max_intensity = 0.0;
    
    let num_z_samples = 12.0;
    let num_angle_samples = 96.0;
    
    var min_curve_dist = 1000.0;
    
    for (var iz: i32 = 0; iz < 12; iz = iz + 1) {
        let z_sample = -CONE_HEIGHT + f32(iz) * (2.0 * CONE_HEIGHT) / num_z_samples;
        
        for (var ia: i32 = 0; ia < 96; ia = ia + 1) {
            let angle = f32(ia) * 6.283185307f / num_angle_samples;
            let pos_3d = getConicPoint(angle, z_sample, conic_type);
            
            let screen_dist = projectPoint(pos_3d, uv);
            
            if (screen_dist < min_curve_dist) {
                min_curve_dist = screen_dist;
            }
        }
    }
    
    let curve_width = 0.01;
    let curve_alpha = smoothstep(curve_width, 0.0, min_curve_dist);
    
    if (conic_type == 0) {
        // Ellipse: deep blue
        curve_color = vec3<f32>(0.1, 0.25, 0.7);
    } else if (conic_type == 1) {
        // Parabola: green
        curve_color = vec3<f32>(0.25, 0.6, 0.25);
    } else {
        // Hyperbola: red
        curve_color = vec3<f32>(0.8, 0.15, 0.15);
    }
    
    return curve_color * curve_alpha;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Start with parchment background
    var color = vec3<f32>(PARCHMENT_R, PARCHMENT_G, PARCHMENT_B);
    
    // Add subtle texture
    let texture_scale = 15.0;
    let texture_x = sin(uv.x * texture_scale * 6.283185307f) * 0.03;
    let texture_y = cos(uv.y * texture_scale * 6.283185307f) * 0.03;
    color = color + vec3<f32>(texture_x * 0.01, texture_y * 0.01, 0.0);
    
    // Render cone wireframe
    var max_cone_intensity = 0.0;
    let cone_samples = 32.0;
    let cone_angles = 16.0;
    
    for (var sample: i32 = 0; sample < 16; sample = sample + 1) {
        let z_norm = f32(sample) / cone_samples;
        let z = -CONE_HEIGHT + z_norm * 2.0 * CONE_HEIGHT;
        let cone_r = abs(z) * tan(CONE_ANGLE);
        
        let sample_angle = atan2(uv.y, uv.x);
        let x = cos(sample_angle) * cone_r;
        let y = sin(sample_angle) * cone_r;
        
        let pos_3d = vec3<f32>(x, y, z);
        let proj_dist = projectPoint(pos_3d, uv);
        let cone_intensity = smoothstep(0.025, -0.005, proj_dist) * (1.0 - z_norm * 0.4);
        
        max_cone_intensity = max(max_cone_intensity, cone_intensity);
    }
    
    // Blend cone
    let cone_color = vec3<f32>(0.35, 0.3, 0.22);
    color = mix(color, cone_color, max_cone_intensity * 0.5);
    
    // Render conic curves
    let ellipse = renderConicCurve(uv, 0);
    let parabola = renderConicCurve(uv, 1);
    let hyperbola = renderConicCurve(uv, 2);
    
    color = color + ellipse + parabola + hyperbola;
    
    // Add subtle vignette for depth
    let vignette_dist = length(uv);
    let vignette = 1.0 - vignette_dist * 0.25;
    color = color * mix(vec3<f32>(0.85), vec3<f32>(1.0), vignette);
    
    // Clamp to valid range
    color = clamp(color, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(color, 1.0);
}