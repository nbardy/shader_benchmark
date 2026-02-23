// Apollonius's Conic Sections - Ancient Greek Mathematical Visualization
// A shader honoring the geometric wisdom of Apollonius of Perga (~200 BCE)

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
    _pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Constants for ancient cone geometry
const CONE_ANGLE: f32 = 0.5236; // 30 degrees in radians
const CONE_HEIGHT: f32 = 3.0;
const CONE_RADIUS: f32 = 1.732; // tan(30°) * height
const EPSILON: f32 = 0.001;
const MAX_STEPS: i32 = 200;
const MAX_DIST: f32 = 10.0;

// Ray marching structure
struct RayMarchResult {
    distance: f32,
    material_id: i32,
};

// Sample point on the double cone surface
// Returns signed distance to cone surface
fn cone_distance(pos: vec3<f32>) -> f32 {
    let xy_dist = length(pos.xy);
    let cone_radius_at_z = abs(pos.z) * tan(CONE_ANGLE);
    return xy_dist - cone_radius_at_z;
}

// Ellipse cutting plane: 45° to vertical axis
// Normal: (sin(45°), 0, cos(45°)) = (0.707, 0, 0.707)
fn ellipse_plane_distance(pos: vec3<f32>) -> f32 {
    let plane_normal = normalize(vec3<f32>(0.707, 0.0, 0.707));
    let plane_offset = 0.5;
    return dot(pos, plane_normal) - plane_offset;
}

// Parabola cutting plane: parallel to cone generator (30° from vertical)
// Normal: (sin(30°), 0, cos(30°)) = (0.5, 0, 0.866)
fn parabola_plane_distance(pos: vec3<f32>) -> f32 {
    let plane_normal = normalize(vec3<f32>(0.5, 0.0, 0.866));
    let plane_offset = 0.3;
    return dot(pos, plane_normal) - plane_offset;
}

// Hyperbola cutting plane: 15° to vertical axis (steeper than cone)
// Normal: (sin(15°), 0, cos(15°)) = (0.259, 0, 0.966)
fn hyperbola_plane_distance(pos: vec3<f32>) -> f32 {
    let plane_normal = normalize(vec3<f32>(0.259, 0.0, 0.966));
    let plane_offset = 0.0;
    return dot(pos, plane_normal) - plane_offset;
}

// Signed distance to intersection curve (conic section)
// Returns positive when outside the region of interest
fn conic_section_distance(pos: vec3<f32>, section_type: i32) -> f32 {
    let cone_dist = cone_distance(pos);
    
    var plane_dist: f32;
    if section_type == 0i {
        plane_dist = ellipse_plane_distance(pos);
    } else if section_type == 1i {
        plane_dist = parabola_plane_distance(pos);
    } else {
        plane_dist = hyperbola_plane_distance(pos);
    }
    
    // Distance to intersection: max of distances (constructive geometry)
    return max(cone_dist, plane_dist);
}

// Ray marching with material tracking
fn ray_march(ray_origin: vec3<f32>, ray_dir: vec3<f32>) -> RayMarchResult {
    var current_dist: f32 = 0.0;
    var material_id: i32 = -1i;
    
    for (var step: i32 = 0i; step < MAX_STEPS; step = step + 1i) {
        let pos = ray_origin + ray_dir * current_dist;
        
        // Check all three conic sections
        let ellipse_d = conic_section_distance(pos, 0i);
        let parabola_d = conic_section_distance(pos, 1i);
        let hyperbola_d = conic_section_distance(pos, 2i);
        
        // Also check cone surface for wireframe
        let cone_d = cone_distance(pos);
        
        // Find nearest surface
        var min_d = ellipse_d;
        material_id = 0i;
        
        if parabola_d < min_d {
            min_d = parabola_d;
            material_id = 1i;
        }
        if hyperbola_d < min_d {
            min_d = hyperbola_d;
            material_id = 2i;
        }
        
        // Cone wireframe at low opacity
        if abs(cone_d) < 0.05 && cone_d < min_d {
            min_d = abs(cone_d);
            material_id = 3i;
        }
        
        current_dist = current_dist + min_d;
        
        if min_d < EPSILON {
            return RayMarchResult(current_dist, material_id);
        }
        if current_dist > MAX_DIST {
            return RayMarchResult(current_dist, -1i);
        }
    }
    
    return RayMarchResult(current_dist, -1i);
}

// Estimate normal via finite differences
fn estimate_normal(pos: vec3<f32>, material_id: i32) -> vec3<f32> {
    let dx = vec3<f32>(EPSILON, 0.0, 0.0);
    let dy = vec3<f32>(0.0, EPSILON, 0.0);
    let dz = vec3<f32>(0.0, 0.0, EPSILON);
    
    let d0 = conic_section_distance(pos, material_id);
    let d1 = conic_section_distance(pos + dx, material_id);
    let d2 = conic_section_distance(pos + dy, material_id);
    let d3 = conic_section_distance(pos + dz, material_id);
    
    return normalize(vec3<f32>(d1 - d0, d2 - d0, d3 - d0));
}

// Ancient Greek parchment color
fn parchment_color() -> vec3<f32> {
    return vec3<f32>(0.957, 0.910, 0.816); // #F4E8D0
}

// Material colors following ancient symbolism
fn material_color(material_id: i32) -> vec3<f32> {
    if material_id == 0i {
        // Ellipse: Deep blue (celestial motion)
        return vec3<f32>(0.1, 0.3, 0.8);
    } else if material_id == 1i {
        // Parabola: Green (earthly trajectories)
        return vec3<f32>(0.2, 0.7, 0.3);
    } else if material_id == 2i {
        // Hyperbola: Red (infinite extension)
        return vec3<f32>(0.9, 0.2, 0.2);
    } else if material_id == 3i {
        // Cone wireframe: Gray
        return vec3<f32>(0.5, 0.5, 0.5);
    }
    return vec3<f32>(0.0, 0.0, 0.0);
}

// Shading with ancient illumination model
fn shade_surface(pos: vec3<f32>, normal: vec3<f32>, material_id: i32) -> vec3<f32> {
    let base_color = material_color(material_id);
    
    // Direction to ancient light source (from upper left)
    let light_dir = normalize(vec3<f32>(-1.0, 1.0, 1.0));
    
    // Diffuse lighting
    let diff = max(dot(normal, light_dir), 0.0);
    let ambient = 0.3;
    let illumination = ambient + diff * 0.7;
    
    // Rim lighting for dramatic effect
    let view_dir = vec3<f32>(0.0, 0.0, 1.0);
    let rim = pow(max(1.0 - dot(normal, view_dir), 0.0), 3.0) * 0.3;
    
    return base_color * (illumination + rim);
}

// Greek letter approximation in screen space
fn draw_greek_letter_alpha(uv: vec2<f32>) -> f32 {
    let center = vec2<f32>(0.15, 0.85);
    let pos_rel = uv - center;
    let r = length(pos_rel);
    
    // Simple circle for α
    let circle = smoothstep(0.08, 0.07, r);
    // Inner dot
    let dot_val = smoothstep(0.025, 0.015, length(pos_rel - vec2<f32>(0.0, -0.02)));
    
    return max(circle, dot_val);
}

fn draw_greek_letter_beta(uv: vec2<f32>) -> f32 {
    let center = vec2<f32>(0.5, 0.85);
    let pos_rel = uv - center;
    
    // Vertical line
    let vert = smoothstep(0.015, 0.01, abs(pos_rel.x));
    // Upper bump
    let upper = smoothstep(0.06, 0.05, length(pos_rel - vec2<f32>(0.04, 0.03)));
    // Lower bump
    let lower = smoothstep(0.06, 0.05, length(pos_rel - vec2<f32>(0.04, -0.03)));
    
    return max(vert, max(upper, lower));
}

fn draw_greek_letter_gamma(uv: vec2<f32>) -> f32 {
    let center = vec2<f32>(0.85, 0.85);
    let pos_rel = uv - center;
    
    // Top horizontal
    let top_line = smoothstep(0.08, 0.07, abs(pos_rel.y - 0.05)) * smoothstep(0.08, -0.08, pos_rel.x);
    // Diagonal leg
    let leg = smoothstep(0.015, 0.01, abs(pos_rel.x * 0.707 + pos_rel.y * 0.707 + 0.02));
    
    return max(top_line, leg);
}

// Annotation text overlay
fn draw_annotations(uv: vec2<f32>) -> f32 {
    var annotation = 0.0;
    
    // Greek letters for plane angles
    annotation = max(annotation, draw_greek_letter_alpha(uv));
    annotation = max(annotation, draw_greek_letter_beta(uv));
    annotation = max(annotation, draw_greek_letter_gamma(uv));
    
    // Label regions
    let ellipse_label = smoothstep(0.3, 0.25, length(uv - vec2<f32>(0.2, 0.3)));
    let parabola_label = smoothstep(0.3, 0.25, length(uv - vec2<f32>(0.5, 0.2)));
    let hyperbola_label = smoothstep(0.3, 0.25, length(uv - vec2<f32>(0.8, 0.3)));
    
    annotation = max(annotation, ellipse_label * 0.3);
    annotation = max(annotation, parabola_label * 0.3);
    annotation = max(annotation, hyperbola_label * 0.3);
    
    return annotation;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize screen coordinates to [-1, 1] range
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    let uv_norm = pos.xy / params.resolution;
    
    // Construct ray for this pixel
    let ray_origin = vec3<f32>(uv.x * 2.0, uv.y * 2.0, -5.0);
    let ray_dir = normalize(vec3<f32>(0.0, 0.0, 1.0));
    
    // Apply rotation based on time for animation
    let theta = params.time * 0.3;
    let cos_t = cos(theta);
    let sin_t = sin(theta);
    let rot_y = mat3x3<f32>(
        vec3<f32>(cos_t, 0.0, sin_t),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sin_t, 0.0, cos_t)
    );
    
    let rotated_origin = rot_y * ray_origin;
    let rotated_dir = rot_y * ray_dir;
    
    // Ray march scene
    let march_result = ray_march(rotated_origin, rotated_dir);
    
    var final_color = parchment_color();
    
    // Hit surface
    if march_result.material_id >= 0i {
        let hit_pos = rotated_origin + rotated_dir * march_result.distance;
        let normal = estimate_normal(hit_pos, march_result.material_id);
        let shaded = shade_surface(hit_pos, normal, march_result.material_id);
        
        // Blend with background based on distance
        let depth_fade = exp(-march_result.distance * 0.2);
        final_color = mix(parchment_color(), shaded, depth_fade);
    }
    
    // Add annotations
    let annotation_intensity = draw_annotations(uv_norm);
    final_color = mix(final_color, vec3<f32>(0.2, 0.2, 0.2), annotation_intensity * 0.5);
    
    return vec4<f32>(final_color, 1.0);
}