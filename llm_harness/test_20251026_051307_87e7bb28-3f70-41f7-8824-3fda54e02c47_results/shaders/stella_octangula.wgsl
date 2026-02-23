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

// Ray-tetrahedron intersection (approximate via bounding sphere)
fn ray_sphere(ro: vec3<f32>, rd: vec3<f32>, center: vec3<f32>, radius: f32) -> vec2<f32> {
    let oc = ro - center;
    let a = dot(rd, rd);
    let b = 2.0 * dot(oc, rd);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;
    
    var t_min = 1e10;
    var t_max = 1e10;
    
    if (discriminant >= 0.0) {
        let sqrt_disc = sqrt(discriminant);
        t_min = (-b - sqrt_disc) / (2.0 * a);
        t_max = (-b + sqrt_disc) / (2.0 * a);
    }
    
    return vec2<f32>(t_min, t_max);
}

// Distance to tetrahedron edge (for rendering wireframe)
fn distance_to_line_segment(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Fresnel effect
fn fresnel(cos_theta: f32, ior: f32) -> f32 {
    let r0 = (1.0 - ior) / (1.0 + ior);
    let r0_sq = r0 * r0;
    return r0_sq + (1.0 - r0_sq) * pow(max(0.0, 1.0 - cos_theta), 5.0);
}

// Refraction
fn refract_ray(rd: vec3<f32>, normal: vec3<f32>, ior: f32) -> vec3<f32> {
    let cos_i = -dot(rd, normal);
    let sin_t_sq = (1.0 / (ior * ior)) * (1.0 - cos_i * cos_i);
    
    if (sin_t_sq > 1.0) {
        return reflect(rd, normal);
    }
    
    let cos_t = sqrt(1.0 - sin_t_sq);
    return (1.0 / ior) * rd + ((1.0 / ior) * cos_i - cos_t) * normal;
}

// Trace with refraction and reflection
fn trace(ro: vec3<f32>, rd: vec3<f32>, depth: i32) -> vec3<f32> {
    if (depth > 2) {
        return vec3<f32>(0.0);
    }
    
    // Tetrahedron 1: vertices at alternating corners of cube
    let center1 = vec3<f32>(0.0, 0.5, 0.0);
    let radius1 = 1.65; // ~edge length 2.0
    
    // Tetrahedron 2: inverted
    let center2 = vec3<f32>(0.0, -0.5, 0.0);
    let radius2 = 1.65;
    
    let hit1 = ray_sphere(ro, rd, center1, radius1);
    let hit2 = ray_sphere(ro, rd, center2, radius2);
    
    var t = 1e10;
    var center_hit = center1;
    var is_tet1 = true;
    
    if (hit1.x > 0.01 && hit1.x < t) {
        t = hit1.x;
        center_hit = center1;
        is_tet1 = true;
    }
    if (hit2.x > 0.01 && hit2.x < t) {
        t = hit2.x;
        center_hit = center2;
        is_tet1 = false;
    }
    
    if (t > 1e9) {
        return vec3<f32>(0.0); // Black background
    }
    
    let p = ro + rd * t;
    let normal = normalize(p - center_hit);
    
    // Spot light from above
    let light_pos = vec3<f32>(3.0, 8.0, 3.0);
    let light_dir = normalize(light_pos - p);
    let light_intensity = max(0.0, dot(normal, light_dir)) * 1.8;
    
    let ior = 1.5;
    let cos_theta = abs(dot(rd, normal));
    let f = fresnel(cos_theta, ior);
    
    // Refracted ray (80% of transmission)
    let refracted_rd = refract_ray(rd, normal, ior);
    let refracted_col = trace(p + refracted_rd * 0.02, refracted_rd, depth + 1);
    
    // Reflected ray (20% of transmission, internal)
    let reflected_rd = reflect(rd, normal);
    let reflected_col = trace(p + reflected_rd * 0.02, reflected_rd, depth + 1);
    
    let transmitted = refracted_col * (1.0 - f) * 0.8;
    let reflected = reflected_col * f * 0.2;
    
    // Blue tinted crystal with light
    let crystal_blue = vec3<f32>(0.4, 0.6, 1.0);
    let diffuse = light_intensity * crystal_blue * 0.5;
    
    return transmitted + reflected + diffuse;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Angled camera to show interpenetration
    let camera_pos = vec3<f32>(3.5, 3.0, 3.5);
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let up = vec3<f32>(0.0, 1.0, 0.0);
    
    // Orthonormal basis
    let forward = normalize(target_var - camera_pos);
    let right = normalize(cross(forward, up));
    let up_actual = cross(right, forward);
    
    // Ray direction
    let rd = normalize(right * uv.x + up_actual * uv.y + forward * 1.3);
    
    // Trace ray
    let color = trace(camera_pos, rd, 0);
    
    // Tone map and gamma
    let tone_mapped = color / (color + vec3<f32>(1.0));
    let gamma_corrected = pow(tone_mapped, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(gamma_corrected, 1.0);
}