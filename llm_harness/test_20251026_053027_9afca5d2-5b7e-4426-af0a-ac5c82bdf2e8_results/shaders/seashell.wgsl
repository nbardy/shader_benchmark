// Parametric Seashell with Pearl-like Materials and Dynamic Lighting
// Implements realistic 3D seashell using parametric equations with iridescence and subsurface scattering

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
// Seashell Parametric Surface
// ============================================================================

fn seashell_surface(u: f32, v: f32) -> vec3<f32> {
    let n = 5.0;           // coiling parameter
    let a = 0.6;           // vertical amplitude
    let b = 0.8;           // height scale
    let c = 0.3;           // radial offset
    let pi2 = 6.28318530718;
    let v_norm = v / pi2;
    
    let radius = (1.0 - v_norm) * (1.0 + cos(u));
    let x = (1.0 - v_norm) * cos(n * v) * radius + c * cos(n * v);
    let y = (1.0 - v_norm) * sin(n * v) * radius + c * sin(n * v);
    let z = b * v_norm + a * (1.0 - v_norm) * sin(u);
    
    return vec3<f32>(x, y, z);
}

// Surface normal via finite differences
fn seashell_normal(u: f32, v: f32) -> vec3<f32> {
    let delta = 0.01;
    let p0 = seashell_surface(u, v);
    let p1 = seashell_surface(u + delta, v);
    let p2 = seashell_surface(u, v + delta);
    
    let du = p1 - p0;
    let dv = p2 - p0;
    return normalize(cross(du, dv));
}

// ============================================================================
// Pearl-like Material Properties
// ============================================================================

fn iridescent_color(normal: vec3<f32>, view_dir: vec3<f32>, v_param: f32) -> vec3<f32> {
    let nv = dot(normal, -view_dir);
    let fresnel = mix(0.3, 1.0, nv * nv);
    
    // Iridescent shift based on parametric v and normal
    let hue_shift = sin(v_param * 3.0 + normal.x * 4.0) * 0.5 + 0.5;
    
    // Pearlescent base colors
    let color1 = vec3<f32>(0.9, 0.85, 0.7);   // warm white
    let color2 = vec3<f32>(0.7, 0.85, 0.95);  // cool blue
    let color3 = vec3<f32>(0.85, 0.7, 0.85);  // soft pink
    
    var pearl_color = mix(color1, color2, hue_shift);
    pearl_color = mix(pearl_color, color3, abs(sin(hue_shift * 3.14159)));
    
    return pearl_color * fresnel;
}

// Subsurface scattering approximation
fn subsurface_scattering(normal: vec3<f32>, light_dir: vec3<f32>, thickness: f32) -> f32 {
    let nl = dot(normal, light_dir);
    let back_lit = max(0.0, -nl) * 0.5;
    return mix(0.0, back_lit, thickness);
}

// ============================================================================
// Lighting and Shading
// ============================================================================

fn compute_lighting(pos: vec3<f32>, normal: vec3<f32>, view_dir: vec3<f32>, time: f32) -> vec3<f32> {
    // Dynamic light source - orbiting around the seashell
    let light_angle = time * 0.5;
    let light_dist = 2.5;
    let light_pos = vec3<f32>(
        cos(light_angle) * light_dist,
        0.8 + sin(light_angle * 0.3) * 0.3,
        sin(light_angle) * light_dist
    );
    
    let light_dir = normalize(light_pos - pos);
    
    // Diffuse lighting
    let nl = max(0.0, dot(normal, light_dir));
    let diffuse = nl * 0.8;
    
    // Specular highlights - pearl-like
    let half_dir = normalize(light_dir - view_dir);
    let nh = max(0.0, dot(normal, half_dir));
    let specular = pow(nh, 64.0) * 1.2;
    
    // Ambient occlusion approximation
    let ao = 0.4 + 0.6 * max(0.0, dot(normal, view_dir));
    
    // Subsurface scattering
    let sss = subsurface_scattering(normal, light_dir, 0.3);
    
    return (diffuse + specular) * ao + sss * 0.4;
}

// ============================================================================
// Surface Texture Details
// ============================================================================

fn surface_texture(pos: vec3<f32>, u: f32, v: f32) -> f32 {
    // Fine ripple texture
    let ripples = sin(u * 12.0) * 0.3 + cos(v * 8.0) * 0.3;
    
    // Growth rings
    let rings = sin(v * 20.0) * 0.2;
    
    // Small random variation
    let variation = sin(pos.x * 7.3 + pos.y * 11.1 + pos.z * 13.7) * 0.15;
    
    return ripples + rings + variation;
}

// ============================================================================
// Depth of Field Effect
// ============================================================================

fn depth_of_field(depth: f32, focus_depth: f32, focus_range: f32) -> f32 {
    let blur = smoothstep(focus_depth - focus_range, focus_depth + focus_range, abs(depth - focus_depth));
    return 1.0 - blur * 0.3;
}

// ============================================================================
// Main Fragment Shader
// ============================================================================

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let time = params.time;
    
    // Normalized screen coordinates
    let uv = (pos.xy - resolution * 0.5) / min(resolution.x, resolution.y);
    
    // Ray casting setup
    let ray_origin = vec3<f32>(0.0, 0.0, 3.0);
    let ray_dir = normalize(vec3<f32>(uv, -1.0));
    
    // Ocean background - gradient
    let ocean_horizon = mix(
        vec3<f32>(0.1, 0.2, 0.3),
        vec3<f32>(0.2, 0.4, 0.5),
        ray_dir.y * 0.5 + 0.5
    );
    
    // Add wave ripples to background
    let wave_ripple = sin(uv.x * 4.0 + time * 0.3) * 0.1 + cos(uv.y * 3.0 + time * 0.2) * 0.1;
    let ocean_color = ocean_horizon + wave_ripple * 0.05;
    
    // Seashell sampling - multiple rays for depth perception
    var shell_color = vec3<f32>(0.0);
    var shell_depth = 1000.0;
    var hit = false;
    
    // Sample parametric surface
    for (var i: u32 = 0u; i < 32u; i = i + 1u) {
        let u = f32(i) / 32.0 * 6.28318530718;
        
        for (var j: u32 = 0u; j < 20u; j = j + 1u) {
            let v = f32(j) / 20.0 * 6.28318530718;
            
            // Get seashell point
            let shell_pos = seashell_surface(u, v);
            
            // Rotate seashell slowly
            let rot_angle = time * 0.2;
            let rot_cos = cos(rot_angle);
            let rot_sin = sin(rot_angle);
            let rotated_pos = vec3<f32>(
                shell_pos.x * rot_cos - shell_pos.z * rot_sin,
                shell_pos.y,
                shell_pos.x * rot_sin + shell_pos.z * rot_cos
            );
            
            // Check intersection with ray
            let to_shell = rotated_pos - ray_origin;
            let shell_dist = length(to_shell);
            
            // Simple sphere intersection approximation
            let closest_dist = 0.15;
            if (shell_dist < closest_dist && shell_dist < shell_depth) {
                shell_depth = shell_dist;
                
                // Get surface normal
                let normal = seashell_normal(u, v);
                let rot_normal = vec3<f32>(
                    normal.x * rot_cos - normal.z * rot_sin,
                    normal.y,
                    normal.x * rot_sin + normal.z * rot_cos
                );
                
                let view_dir = normalize(rotated_pos - ray_origin);
                
                // Iridescent coloring
                let pearl_col = iridescent_color(rot_normal, view_dir, v);
                
                // Lighting
                let light_factor = compute_lighting(rotated_pos, rot_normal, view_dir, time);
                
                // Texture detail
                let tex = surface_texture(rotated_pos, u, v);
                let texture_factor = 0.9 + tex * 0.1;
                
                // Depth of field
                let dof = depth_of_field(shell_dist, 0.5, 0.2);
                
                shell_color = pearl_col * light_factor * texture_factor * dof;
                hit = true;
            }
        }
    }
    
    // Composite: seashell over ocean background
    let final_color = select(ocean_color, shell_color, hit);
    
    // Add subtle caustics to ocean background
    let caustic = abs(sin(uv.x * 8.0 + time * 0.4) * cos(uv.y * 6.0 + time * 0.3)) * 0.05;
    let output = final_color + caustic * select(0.0, 0.3, !hit);
    
    return vec4<f32>(output, 1.0);
}