// Catenoid-Helicoid Minimal Surface with Soap Bubble Material
// Animated transformation between isometric minimal surfaces

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

// Thin film interference color based on optical path
fn thinFilmColor(thickness: f32) -> vec3<f32> {
    let wavelengths = vec3<f32>(650.0, 510.0, 475.0); // R, G, B nm
    let phase = 2.0 * 3.14159265 * thickness / wavelengths;
    let amplitude = 0.5 * sin(phase) + 0.5;
    return amplitude;
}

// Parametric surface: catenoid-helicoid transformation
fn surfacePoint(u: f32, v: f32, theta: f32) -> vec3<f32> {
    let cos_theta = cos(theta);
    let sin_theta = sin(theta);
    let sinh_v = sinh(v);
    let cosh_v = cosh(v);
    
    let sin_u = sin(u);
    let cos_u = cos(u);
    
    let x = cos_theta * sinh_v * sin_u + sin_theta * cosh_v * cos_u;
    let y = -cos_theta * sinh_v * cos_u + sin_theta * cosh_v * sin_u;
    let z = u * cos_theta + v * sin_theta;
    
    return vec3<f32>(x, y, z);
}

// Compute surface normal via finite differences
fn surfaceNormal(u: f32, v: f32, theta: f32) -> vec3<f32> {
    let eps = 0.01;
    let p0 = surfacePoint(u, v, theta);
    let p1 = surfacePoint(u + eps, v, theta);
    let p2 = surfacePoint(u, v + eps, theta);
    
    let du = p1 - p0;
    let dv = p2 - p0;
    let normal = normalize(cross(du, dv));
    return normal;
}

// Approximate sinh function
fn sinh(x: f32) -> f32 {
    return (exp(x) - exp(-x)) * 0.5;
}

// Approximate cosh function
fn cosh(x: f32) -> f32 {
    return (exp(x) + exp(-x)) * 0.5;
}

// Ray-surface intersection via marching
fn rayMarch(ray_origin: vec3<f32>, ray_dir: vec3<f32>, theta: f32) -> vec4<f32> {
    var t = 0.0;
    var steps = 0u;
    let max_steps = 128u;
    let max_dist = 10.0;
    
    var closest_point = vec3<f32>(0.0);
    var min_dist = 1000.0;
    
    // Grid sampling to find closest surface point
    for (var i = 0u; i < 32u; i = i + 1u) {
        for (var j = 0u; j < 32u; j = j + 1u) {
            let u = (f32(i) / 32.0 - 0.5) * 6.28318530718;
            let v = (f32(j) / 32.0 - 0.5) * 4.0;
            let p = surfacePoint(u, v, theta);
            let d = distance(p, ray_origin);
            
            if (d < min_dist) {
                min_dist = d;
                closest_point = p;
            }
        }
    }
    
    let hit_dist = min_dist;
    let hit_normal = surfaceNormal(atan2(closest_point.y, closest_point.x), 
                                    length(vec2<f32>(closest_point.x, closest_point.y)), theta);
    
    return vec4<f32>(closest_point, hit_dist);
}

// Fresnel effect for soap bubble appearance
fn fresnel(normal: vec3<f32>, view_dir: vec3<f32>) -> f32 {
    let ndotv = abs(dot(normal, view_dir));
    return pow(1.0 - ndotv, 5.0) * 0.8 + 0.2;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    
    // Smooth animation between helicoid (0) and catenoid (π/2)
    let theta = sin(params.time * 0.5) * 1.57079632679 * 0.5 + 1.57079632679 * 0.5;
    
    // Ray setup
    let ray_origin = vec3<f32>((uv.x - 0.5) * aspect * 3.0, (uv.y - 0.5) * 3.0, 3.0);
    let ray_dir = normalize(vec3<f32>(0.0, 0.0, -1.0));
    
    // Perform ray march
    let hit = rayMarch(ray_origin, ray_dir, theta);
    let hit_point = hit.xyz;
    let hit_dist = hit.w;
    
    // Early exit for far objects
    let is_hit = select(false, true, hit_dist < 8.0);
    
    if (!is_hit) {
        // Minimalist background: subtle gradient
        let bg = mix(
            vec3<f32>(0.95, 0.95, 0.98),
            vec3<f32>(0.92, 0.94, 0.97),
            uv.y
        );
        return vec4<f32>(bg, 1.0);
    }
    
    // Compute lighting
    let normal = surfaceNormal(
        atan2(hit_point.y, hit_point.x),
        length(vec2<f32>(hit_point.x, hit_point.y)),
        theta
    );
    
    let light_dir = normalize(vec3<f32>(1.0, 1.0, 1.0));
    let view_dir = -ray_dir;
    
    // Phong lighting
    let ambient = 0.3;
    let diffuse = max(dot(normal, light_dir), 0.0) * 0.6;
    let spec = pow(max(dot(reflect(-light_dir, normal), view_dir), 0.0), 32.0) * 0.8;
    
    // Thin film interference
    let film_thickness = abs(hit_point.z) * 0.1 + params.time * 0.5;
    let film_color = thinFilmColor(film_thickness);
    
    // Fresnel effect
    let fres = fresnel(normal, view_dir);
    
    // Soap bubble material: iridescent + transparent
    let base_color = film_color * vec3<f32>(1.0, 0.9, 0.85);
    let surface_color = base_color * (ambient + diffuse) + vec3<f32>(1.0) * spec;
    
    // Add wireframe effect to show surface structure
    let u_coord = atan2(hit_point.y, hit_point.x) / 6.28318530718;
    let v_coord = length(vec2<f32>(hit_point.x, hit_point.y)) / 4.0;
    
    let grid_u = step(0.95, fract(u_coord * 8.0));
    let grid_v = step(0.95, fract(v_coord * 8.0));
    let wireframe = max(grid_u, grid_v) * 0.3;
    
    let final_color = surface_color + vec3<f32>(wireframe);
    
    // Transparency based on fresnel
    let alpha = 0.7 + fres * 0.3;
    
    return vec4<f32>(final_color, alpha);
}