// Regular Dodecahedron Renderer
// Golden ratio φ = (1+√5)/2 ≈ 1.618
// Bronze material with HDR studio lighting

const PHI: f32 = 1.618033988749895;
const PI: f32 = 3.141592653589793;

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

// Dodecahedron vertices (20 vertices, circumsphere radius = 1)
fn getDodecahedronVertex(idx: u32) -> vec3<f32> {
    let i = idx % 20u;
    
    // Cube vertices scaled by 1/PHI
    let cube_scale = 1.0 / PHI;
    if (i == 0u) { return vec3<f32>(cube_scale, cube_scale, cube_scale); }
    if (i == 1u) { return vec3<f32>(-cube_scale, cube_scale, cube_scale); }
    if (i == 2u) { return vec3<f32>(-cube_scale, -cube_scale, cube_scale); }
    if (i == 3u) { return vec3<f32>(cube_scale, -cube_scale, cube_scale); }
    if (i == 4u) { return vec3<f32>(cube_scale, cube_scale, -cube_scale); }
    if (i == 5u) { return vec3<f32>(-cube_scale, cube_scale, -cube_scale); }
    if (i == 6u) { return vec3<f32>(-cube_scale, -cube_scale, -cube_scale); }
    if (i == 7u) { return vec3<f32>(cube_scale, -cube_scale, -cube_scale); }
    
    // Rectangle vertices in each orthogonal plane
    let rect_scale = PHI;
    if (i == 8u) { return vec3<f32>(0.0, rect_scale, 1.0 / rect_scale); }
    if (i == 9u) { return vec3<f32>(0.0, -rect_scale, 1.0 / rect_scale); }
    if (i == 10u) { return vec3<f32>(0.0, -rect_scale, -1.0 / rect_scale); }
    if (i == 11u) { return vec3<f32>(0.0, rect_scale, -1.0 / rect_scale); }
    if (i == 12u) { return vec3<f32>(rect_scale, 1.0 / rect_scale, 0.0); }
    if (i == 13u) { return vec3<f32>(-rect_scale, 1.0 / rect_scale, 0.0); }
    if (i == 14u) { return vec3<f32>(-rect_scale, -1.0 / rect_scale, 0.0); }
    if (i == 15u) { return vec3<f32>(rect_scale, -1.0 / rect_scale, 0.0); }
    if (i == 16u) { return vec3<f32>(1.0 / rect_scale, 0.0, rect_scale); }
    if (i == 17u) { return vec3<f32>(-1.0 / rect_scale, 0.0, rect_scale); }
    if (i == 18u) { return vec3<f32>(-1.0 / rect_scale, 0.0, -rect_scale); }
    if (i == 19u) { return vec3<f32>(1.0 / rect_scale, 0.0, -rect_scale); }
    
    return vec3<f32>(0.0);
}

// Dodecahedron face edge connectivity
fn getEdgeVertices(edge_idx: u32) -> vec2<u32> {
    let idx = edge_idx % 30u;
    
    // Face 1 (top pentagon): indices 0,1,8,12,4
    if (idx == 0u) { return vec2<u32>(0u, 1u); }
    if (idx == 1u) { return vec2<u32>(1u, 8u); }
    if (idx == 2u) { return vec2<u32>(8u, 12u); }
    if (idx == 3u) { return vec2<u32>(12u, 4u); }
    if (idx == 4u) { return vec2<u32>(4u, 0u); }
    
    // Face 2 (bottom pentagon): indices 2,3,9,15,7
    if (idx == 5u) { return vec2<u32>(2u, 3u); }
    if (idx == 6u) { return vec2<u32>(3u, 9u); }
    if (idx == 7u) { return vec2<u32>(9u, 15u); }
    if (idx == 8u) { return vec2<u32>(15u, 7u); }
    if (idx == 9u) { return vec2<u32>(7u, 2u); }
    
    // Face 3 (front pentagon): indices 0,3,16,12,4
    if (idx == 10u) { return vec2<u32>(0u, 3u); }
    if (idx == 11u) { return vec2<u32>(3u, 16u); }
    if (idx == 12u) { return vec2<u32>(16u, 12u); }
    if (idx == 13u) { return vec2<u32>(12u, 4u); }
    if (idx == 14u) { return vec2<u32>(4u, 0u); }
    
    // Face 4 (back pentagon): indices 1,2,18,13,5
    if (idx == 15u) { return vec2<u32>(1u, 2u); }
    if (idx == 16u) { return vec2<u32>(2u, 18u); }
    if (idx == 17u) { return vec2<u32>(18u, 13u); }
    if (idx == 18u) { return vec2<u32>(13u, 5u); }
    if (idx == 19u) { return vec2<u32>(5u, 1u); }
    
    // Face 5 (left pentagon): indices 1,17,13,5,8
    if (idx == 20u) { return vec2<u32>(1u, 17u); }
    if (idx == 21u) { return vec2<u32>(17u, 13u); }
    if (idx == 22u) { return vec2<u32>(13u, 5u); }
    if (idx == 23u) { return vec2<u32>(5u, 8u); }
    if (idx == 24u) { return vec2<u32>(8u, 1u); }
    
    // Face 6 (right pentagon): indices 0,16,12,4,9
    if (idx == 25u) { return vec2<u32>(0u, 16u); }
    if (idx == 26u) { return vec2<u32>(16u, 12u); }
    if (idx == 27u) { return vec2<u32>(12u, 4u); }
    if (idx == 28u) { return vec2<u32>(4u, 9u); }
    if (idx == 29u) { return vec2<u32>(9u, 0u); }
    
    return vec2<u32>(0u, 1u);
}

// Ray-sphere intersection
fn raySphere(ro: vec3<f32>, rd: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    let oc = ro - center;
    let a = dot(rd, rd);
    let b = 2.0 * dot(oc, rd);
    let c = dot(oc, oc) - radius * radius;
    let disc = b * b - 4.0 * a * c;
    
    if (disc < 0.0) { return 1e10; }
    
    let t1 = (-b - sqrt(disc)) / (2.0 * a);
    let t2 = (-b + sqrt(disc)) / (2.0 * a);
    
    if (t1 > 0.01) { return t1; }
    if (t2 > 0.01) { return t2; }
    return 1e10;
}

// Line segment distance (for edge rendering)
fn distToSegment(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Blinn-Phong with metallic parameters
fn shade(n: vec3<f32>, v: vec3<f32>, l: vec3<f32>, metallic: f32, roughness: f32) -> f32 {
    let nl = max(dot(n, l), 0.0);
    let h = normalize(l + v);
    let nh = max(dot(n, h), 0.0);
    
    // Specular falloff based on roughness
    let shininess = 1.0 / (roughness * roughness + 0.001);
    let spec = pow(nh, shininess * 32.0) * metallic;
    
    return nl * 0.7 + spec * 0.8;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalized screen coordinates
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    let ndc = vec2<f32>((uv.x - 0.5) * aspect, uv.y - 0.5) * 2.0;
    
    // Camera setup: position (4, -3, 2.5), FOV 30°
    let cam_pos = vec3<f32>(4.0, -3.0, 2.5);
    let cam_target = vec3<f32>(0.0, 0.0, 0.0);
    let cam_up = vec3<f32>(0.0, 0.0, 1.0);
    
    let cam_forward = normalize(cam_target - cam_pos);
    let cam_right = normalize(cross(cam_forward, cam_up));
    let cam_up_actual = cross(cam_right, cam_forward);
    
    // FOV = 30° → focal length
    let fov_angle = 30.0 * PI / 180.0;
    let focal_length = 1.0 / tan(fov_angle * 0.5);
    
    let ray_dir = normalize(
        cam_forward * focal_length +
        cam_right * ndc.x +
        cam_up_actual * ndc.y
    );
    
    // Ray-sphere intersection with dodecahedron circumsphere (radius=1)
    let t_hit = raySphere(cam_pos, ray_dir, vec3<f32>(0.0), 1.0);
    
    var color = vec3<f32>(0.05, 0.04, 0.03); // Dark background
    
    if (t_hit < 1e9) {
        let hit_point = cam_pos + ray_dir * t_hit;
        let n = normalize(hit_point);
        
        // Key light position (4, 4, 6) normalized
        let key_light = normalize(vec3<f32>(4.0, 4.0, 6.0));
        let key_intensity = 1.2;
        
        // Fill light (opposite, weaker)
        let fill_light = normalize(vec3<f32>(-2.0, -2.0, -1.0));
        let fill_intensity = 0.3;
        
        // View direction
        let v_dir = normalize(cam_pos - hit_point);
        
        // Bronze material: #b57b33 = rgb(181, 123, 51) / 255
        let bronze = vec3<f32>(181.0 / 255.0, 123.0 / 255.0, 51.0 / 255.0);
        
        // Metallic roughness parameters
        let metallic = 0.8;
        let roughness = 0.25;
        
        // Shading
        let key_shade = shade(n, v_dir, key_light, metallic, roughness) * key_intensity;
        let fill_shade = shade(n, v_dir, fill_light, metallic, roughness) * fill_intensity;
        let ambient = 0.15;
        
        let total_light = key_shade + fill_shade + ambient;
        color = bronze * total_light;
        
        // Edge highlight based on distance to nearest edge
        var min_edge_dist = 1e10;
        for (var e = 0u; e < 30u; e = e + 1u) {
            let edge = getEdgeVertices(e);
            let v0 = getDodecahedronVertex(edge.x);
            let v1 = getDodecahedronVertex(edge.y);
            let edge_dist = distToSegment(hit_point, v0, v1);
            min_edge_dist = min(min_edge_dist, edge_dist);
        }
        
        // Edge line rendering
        let edge_width = 0.02;
        let edge_alpha = smoothstep(edge_width, 0.0, min_edge_dist);
        let edge_color = vec3<f32>(1.0, 1.0, 0.95);
        
        color = mix(color, edge_color, edge_alpha * 0.6);
    }
    
    // Tonemap (simple Reinhard)
    color = color / (color + vec3<f32>(1.0));
    
    // Gamma correction
    color = pow(color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(color, 1.0);
}