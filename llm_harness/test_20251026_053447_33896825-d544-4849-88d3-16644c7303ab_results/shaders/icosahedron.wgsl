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

const PHI: f32 = 1.618033988749895;
const SQRT5: f32 = 2.236067977499790;
const INV_PHI_SQ_PLUS_1: f32 = 0.447213595499958;

fn hsv_to_rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let h_sector = h * 6.0;
    let i = u32(floor(h_sector)) % 6u;
    let f = h_sector - floor(h_sector);
    let p = v * (1.0 - s);
    let q = v * (1.0 - s * f);
    let t = v * (1.0 - s * (1.0 - f));
    
    var result = vec3<f32>(v, v, v);
    if (i == 0u) {
        result = vec3<f32>(v, t, p);
    } else if (i == 1u) {
        result = vec3<f32>(q, v, p);
    } else if (i == 2u) {
        result = vec3<f32>(p, v, t);
    } else if (i == 3u) {
        result = vec3<f32>(p, q, v);
    } else if (i == 4u) {
        result = vec3<f32>(t, p, v);
    } else {
        result = vec3<f32>(v, p, q);
    }
    return result;
}

fn rotate_y(v: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(
        v.x * c - v.z * s,
        v.y,
        v.x * s + v.z * c
    );
}

fn face_normal(v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>) -> vec3<f32> {
    let e1 = v1 - v0;
    let e2 = v2 - v0;
    return normalize(cross(e1, e2));
}

fn ray_triangle_distance(ray_origin: vec3<f32>, ray_dir: vec3<f32>, 
                         v0: vec3<f32>, v1: vec3<f32>, v2: vec3<f32>) -> f32 {
    let e1 = v1 - v0;
    let e2 = v2 - v0;
    let h = cross(ray_dir, e2);
    let a = dot(e1, h);
    
    if (abs(a) < 1e-6) {
        return 1e6;
    }
    
    let f = 1.0 / a;
    let s = ray_origin - v0;
    let u = f * dot(s, h);
    
    if (u < 0.0 || u > 1.0) {
        return 1e6;
    }
    
    let q = cross(s, e1);
    let v = f * dot(ray_dir, q);
    
    if (v < 0.0 || u + v > 1.0) {
        return 1e6;
    }
    
    let t = f * dot(e2, q);
    return select(1e6, t, t > 0.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let phi_inv = INV_PHI_SQ_PLUS_1;
    
    let v0 = normalize(vec3<f32>(0.0, 1.0, PHI)) * phi_inv;
    let v1 = normalize(vec3<f32>(0.0, -1.0, PHI)) * phi_inv;
    let v2 = normalize(vec3<f32>(0.0, -1.0, -PHI)) * phi_inv;
    let v3 = normalize(vec3<f32>(0.0, 1.0, -PHI)) * phi_inv;
    let v4 = normalize(vec3<f32>(1.0, PHI, 0.0)) * phi_inv;
    let v5 = normalize(vec3<f32>(-1.0, PHI, 0.0)) * phi_inv;
    let v6 = normalize(vec3<f32>(-1.0, -PHI, 0.0)) * phi_inv;
    let v7 = normalize(vec3<f32>(1.0, -PHI, 0.0)) * phi_inv;
    let v8 = normalize(vec3<f32>(PHI, 0.0, 1.0)) * phi_inv;
    let v9 = normalize(vec3<f32>(-PHI, 0.0, 1.0)) * phi_inv;
    let v10 = normalize(vec3<f32>(-PHI, 0.0, -1.0)) * phi_inv;
    let v11 = normalize(vec3<f32>(PHI, 0.0, -1.0)) * phi_inv;
    
    let angle = params.time * 0.785398163397448;
    
    let rv0 = rotate_y(v0, angle);
    let rv1 = rotate_y(v1, angle);
    let rv2 = rotate_y(v2, angle);
    let rv3 = rotate_y(v3, angle);
    let rv4 = rotate_y(v4, angle);
    let rv5 = rotate_y(v5, angle);
    let rv6 = rotate_y(v6, angle);
    let rv7 = rotate_y(v7, angle);
    let rv8 = rotate_y(v8, angle);
    let rv9 = rotate_y(v9, angle);
    let rv10 = rotate_y(v10, angle);
    let rv11 = rotate_y(v11, angle);
    
    let ray_origin = vec3<f32>(0.0, 0.0, 4.0);
    let ray_dir = normalize(vec3<f32>(uv.x, uv.y, -1.0));
    
    var min_dist = 1e6;
    var best_normal = vec3<f32>(0.0, 0.0, 1.0);
    
    // Face 1
    var norm = face_normal(rv0, rv1, rv8);
    var dist = ray_triangle_distance(ray_origin, ray_dir, rv0, rv1, rv8);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 2
    norm = face_normal(rv0, rv8, rv4);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv0, rv8, rv4);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 3
    norm = face_normal(rv0, rv4, rv5);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv0, rv4, rv5);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 4
    norm = face_normal(rv0, rv5, rv9);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv0, rv5, rv9);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 5
    norm = face_normal(rv0, rv9, rv1);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv0, rv9, rv1);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 6
    norm = face_normal(rv1, rv7, rv8);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv1, rv7, rv8);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 7
    norm = face_normal(rv1, rv6, rv7);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv1, rv6, rv7);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 8
    norm = face_normal(rv1, rv9, rv6);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv1, rv9, rv6);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 9
    norm = face_normal(rv2, rv11, rv3);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv2, rv11, rv3);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 10
    norm = face_normal(rv2, rv10, rv11);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv2, rv10, rv11);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 11
    norm = face_normal(rv2, rv6, rv10);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv2, rv6, rv10);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 12
    norm = face_normal(rv2, rv7, rv6);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv2, rv7, rv6);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 13
    norm = face_normal(rv3, rv11, rv4);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv3, rv11, rv4);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 14
    norm = face_normal(rv3, rv4, rv5);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv3, rv4, rv5);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 15
    norm = face_normal(rv3, rv5, rv10);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv3, rv5, rv10);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 16
    norm = face_normal(rv3, rv10, rv2);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv3, rv10, rv2);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 17
    norm = face_normal(rv4, rv11, rv8);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv4, rv11, rv8);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 18
    norm = face_normal(rv5, rv4, rv8);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv5, rv4, rv8);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 19
    norm = face_normal(rv6, rv2, rv11);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv6, rv2, rv11);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    // Face 20
    norm = face_normal(rv7, rv11, rv2);
    dist = ray_triangle_distance(ray_origin, ray_dir, rv7, rv11, rv2);
    if (dist < min_dist) {
        min_dist = dist;
        best_normal = norm;
    }
    
    var final_color = vec3<f32>(0.3, 0.4, 0.6);
    
    if (min_dist < 1e5) {
        let n = best_normal;
        let hue = (atan2(n.z, n.x) + 3.14159265359) / 6.28318530718;
        let sat = 0.7;
        let val = 0.5 + 0.5 * n.y;
        
        var face_color = hsv_to_rgb(hue, sat, val);
        
        let light_pos = normalize(vec3<f32>(2.0, 3.0, 2.0));
        let ambient = 0.3;
        let diffuse = max(0.0, dot(best_normal, light_pos)) * 0.6;
        let view_dir = -ray_dir;
        let reflect_dir = reflect(-light_pos, best_normal);
        let specular = pow(max(0.0, dot(view_dir, reflect_dir)), 32.0) * 0.1;
        
        face_color = face_color * (ambient + diffuse) + vec3<f32>(specular);
        final_color = face_color;
    }
    
    return vec4<f32>(final_color, 1.0);
}