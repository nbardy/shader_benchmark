// Crystalline Sierpinski Tetrahedron - WGSL Implementation
// Recursive depth 4, 341 total tetrahedra, icy quartz aesthetic

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

// Ray-tetrahedron intersection for raymarched Sierpinski tetrahedron
struct Ray {
    origin: vec3<f32>,
    direction: vec3<f32>,
};

struct Hit {
    distance: f32,
    depth: i32,
    normal: vec3<f32>,
};

// Standard tetrahedron vertices (regular, edge length ~2, base parallel to ground)
fn tet_vertex_0() -> vec3<f32> {
    return vec3<f32>(0.0, -0.408, -0.707);
}

fn tet_vertex_1() -> vec3<f32> {
    return vec3<f32>(0.816, 0.408, -0.707);
}

fn tet_vertex_2() -> vec3<f32> {
    return vec3<f32>(-0.408, 0.408, 0.816);
}

fn tet_vertex_3() -> vec3<f32> {
    return vec3<f32>(-0.408, 0.408, -0.707);
}

// Distance from point to tet face (plane)
fn distance_to_plane(p: vec3<f32>, v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>) -> f32 {
    let e1 = v1 - v0;
    let e2 = v2 - v0;
    let n = normalize(cross(e1, e2));
    return abs(dot(p - v0, n));
}

// Distance to tetrahedron surface (min of 4 faces)
fn distance_to_tet(p: vec3<f32>, v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>, v3: vec3<f32>) -> f32 {
    var min_d = 1e10;
    min_d = min(min_d, distance_to_plane(p, v0, v1, v2));
    min_d = min(min_d, distance_to_plane(p, v0, v1, v3));
    min_d = min(min_d, distance_to_plane(p, v0, v2, v3));
    min_d = min(min_d, distance_to_plane(p, v1, v2, v3));
    return min_d;
}

// Recursive Sierpinski tetrahedron distance field (depth 0-4)
fn sierpinski_distance(p: vec3<f32>, v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>, v3: vec3<f32>, depth: i32) -> Hit {
    var result: Hit;
    result.distance = 1e10;
    result.depth = -1;
    result.normal = vec3<f32>(0.0, 1.0, 0.0);
    
    // Leaf node: compute distance to this tet shell
    if (depth >= 4) {
        result.distance = distance_to_tet(p, v0, v1, v2, v3);
        result.depth = 4;
        
        // Approximate normal via gradient
        let eps = 0.001;
        let dx = distance_to_tet(p + vec3<f32>(eps, 0.0, 0.0), v0, v1, v2, v3)
               - distance_to_tet(p - vec3<f32>(eps, 0.0, 0.0), v0, v1, v2, v3);
        let dy = distance_to_tet(p + vec3<f32>(0.0, eps, 0.0), v0, v1, v2, v3)
               - distance_to_tet(p - vec3<f32>(0.0, eps, 0.0), v0, v1, v2, v3);
        let dz = distance_to_tet(p + vec3<f32>(0.0, 0.0, eps), v0, v1, v2, v3)
               - distance_to_tet(p - vec3<f32>(0.0, 0.0, eps), v0, v1, v2, v3);
        result.normal = normalize(vec3<f32>(dx, dy, dz));
        return result;
    }
    
    // Recursive: four children at vertices (midpoint subdivision)
    let c01 = (v0 + v1) * 0.5;
    let c02 = (v0 + v2) * 0.5;
    let c03 = (v0 + v3) * 0.5;
    let c12 = (v1 + v2) * 0.5;
    let c13 = (v1 + v3) * 0.5;
    let c23 = (v2 + v3) * 0.5;
    
    // Child 0: v0, c01, c02, c03
    var h0 = sierpinski_distance(p, v0, c01, c02, c03, depth + 1);
    if (h0.distance < result.distance) { result = h0; }
    
    // Child 1: v1, c01, c12, c13
    var h1 = sierpinski_distance(p, v1, c01, c12, c13, depth + 1);
    if (h1.distance < result.distance) { result = h1; }
    
    // Child 2: v2, c02, c12, c23
    var h2 = sierpinski_distance(p, v2, c02, c12, c23, depth + 1);
    if (h2.distance < result.distance) { result = h2; }
    
    // Child 3: v3, c03, c13, c23
    var h3 = sierpinski_distance(p, v3, c03, c13, c23, depth + 1);
    if (h3.distance < result.distance) { result = h3; }
    
    return result;
}

// Depth-mapped glass-blue color: depth 0 → #cce6ff, depth 4 → #0040ff
fn depth_color(depth: i32) -> vec3<f32> {
    let t = f32(depth) / 4.0;
    let c0 = vec3<f32>(0.8, 0.902, 1.0);     // #cce6ff
    let c4 = vec3<f32>(0.0, 0.251, 1.0);     // #0040ff
    return mix(c0, c4, t);
}

// Main scene raymarching
fn raymarch(ray: Ray, max_dist: f32) -> Hit {
    var result: Hit;
    result.distance = max_dist;
    result.depth = -1;
    result.normal = vec3<f32>(0.0, 1.0, 0.0);
    
    var t = 0.1;
    var step_count = 0;
    
    loop {
        if (t >= max_dist || step_count >= 200) { break; }
        
        let p = ray.origin + ray.direction * t;
        
        // Root tetrahedron (scaled)
        let scale = 1.2;
        let v0 = tet_vertex_0() * scale;
        let v1 = tet_vertex_1() * scale;
        let v2 = tet_vertex_2() * scale;
        let v3 = tet_vertex_3() * scale;
        
        let hit = sierpinski_distance(p, v0, v1, v2, v3, 0);
        
        if (hit.distance < 0.001) {
            result = hit;
            return result;
        }
        
        t = t + hit.distance * 0.5;
        step_count = step_count + 1;
    }
    
    return result;
}

// Fresnel glass effect
fn fresnel(normal: vec3<f32>, view: vec3<f32>, ior: f32) -> f32 {
    let cos_theta = max(dot(-view, normal), 0.0);
    let r0 = (1.0 - ior) / (1.0 + ior);
    let r0_sq = r0 * r0;
    return r0_sq + (1.0 - r0_sq) * pow(1.0 - cos_theta, 5.0);
}

// Key light: white at (6,4,9)
fn key_light(p: vec3<f32>, normal: vec3<f32>) -> f32 {
    let light_pos = vec3<f32>(6.0, 4.0, 9.0);
    let light_dir = normalize(light_pos - p);
    return max(dot(normal, light_dir), 0.0) * 0.8;
}

// Ambient + HDRI
fn ambient_light(normal: vec3<f32>) -> f32 {
    return 0.5 + 0.3 * (normal.y * 0.5 + 0.5);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Camera setup: position (4,4,3), focal length 50mm, FOV ~39°
    let cam_pos = vec3<f32>(4.0, 4.0, 3.0);
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_up = vec3<f32>(0.0, 1.0, 0.0);
    
    let cam_fwd = normalize(cam_target - cam_pos);
    let cam_right = normalize(cross(cam_fwd, cam_up));
    let cam_up_actual = cross(cam_right, cam_fwd);
    
    let fov = 0.68;  // ~39°
    let ray_dir = normalize(
        cam_fwd * (1.0 / tan(fov * 0.5)) +
        cam_right * uv.x * aspect +
        cam_up_actual * uv.y
    );
    
    var ray: Ray;
    ray.origin = cam_pos;
    ray.direction = ray_dir;
    
    // Raymarch
    let hit = raymarch(ray, 50.0);
    
    // No hit: sky gradient
    if (hit.depth < 0) {
        let sky_color = mix(
            vec3<f32>(0.7, 0.85, 1.0),
            vec3<f32>(0.4, 0.6, 0.9),
            clamp(ray_dir.y + 0.5, 0.0, 1.0)
        );
        return vec4<f32>(sky_color * 0.6, 1.0);
    }
    
    // Hit geometry
    let p_hit = ray.origin + ray.direction * hit.distance;
    let base_color = depth_color(hit.depth);
    
    // Lighting
    let diffuse = key_light(p_hit, hit.normal) + ambient_light(hit.normal);
    let fres = fresnel(hit.normal, ray.direction, 1.33);
    
    // Glass refraction + reflection blend
    let light_contrib = base_color * diffuse * (1.0 - fres * 0.5) + vec3<f32>(1.0) * fres * 0.3;
    
    // Depth cueing for icy mist
    let fog = 1.0 - exp(-hit.distance * hit.distance * 0.01);
    let final_color = mix(light_contrib, vec3<f32>(0.85, 0.92, 1.0), fog * 0.3);
    
    return vec4<f32>(final_color, 1.0);
}