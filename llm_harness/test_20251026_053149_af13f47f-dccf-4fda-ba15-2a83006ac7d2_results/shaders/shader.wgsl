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

fn point_in_triangle(pt: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> f32 {
    let v0 = c - a;
    let v1 = b - a;
    let v2 = pt - a;
    let dot00 = dot(v0, v0);
    let dot01 = dot(v0, v1);
    let dot02 = dot(v0, v2);
    let dot11 = dot(v1, v1);
    let dot12 = dot(v1, v2);
    let inv_denom = 1.0 / (dot00 * dot11 - dot01 * dot01 + 1e-6);
    let u = (dot11 * dot02 - dot01 * dot12) * inv_denom;
    let v = (dot00 * dot12 - dot01 * dot02) * inv_denom;
    return select(0.0, 1.0, (u >= 0.0) && (v >= 0.0) && (u + v <= 1.0));
}

fn edge_dist(pt: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = pt - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / (dot(ba, ba) + 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

fn is_on_boundary_circle(pt: vec2<f32>) -> f32 {
    let r = length(pt);
    let dist_to_circle = abs(r - 1.0);
    return select(0.0, 1.0, dist_to_circle < 0.006);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution;
    let pt = uv * 0.98;
    let r = length(pt);
    
    if (r >= 1.0) {
        return vec4<f32>(1.0, 1.0, 1.0, 1.0);
    }
    
    if (is_on_boundary_circle(pt) > 0.5) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    let pi = 3.14159265;
    let angle1 = 0.0;
    let angle2 = pi * 0.25;
    let angle3 = pi * 0.5;
    let seed_radius = 0.6;
    
    let v1 = vec2<f32>(cos(angle1), sin(angle1)) * seed_radius;
    let v2 = vec2<f32>(cos(angle2), sin(angle2)) * seed_radius;
    let v3 = vec2<f32>(cos(angle3), sin(angle3)) * seed_radius;
    
    var best_color = 0.5;
    var edge_line = false;
    
    let in_seed = point_in_triangle(pt, v1, v2, v3);
    if (in_seed > 0.5) {
        best_color = 0.0;
    }
    
    for (var rot_idx = 0i; rot_idx < 8i; rot_idx = rot_idx + 1i) {
        let angle = pi * 0.25 * f32(rot_idx);
        let c = cos(angle);
        let s = sin(angle);
        
        let rv1 = vec2<f32>(c * v1.x - s * v1.y, s * v1.x + c * v1.y);
        let rv2 = vec2<f32>(c * v2.x - s * v2.y, s * v2.x + c * v2.y);
        let rv3 = vec2<f32>(c * v3.x - s * v3.y, s * v3.x + c * v3.y);
        
        let in_tri = point_in_triangle(pt, rv1, rv2, rv3);
        if (in_tri > 0.5) {
            best_color = select(0.0, 1.0, rot_idx % 2i == 0i);
        }
        
        let d1 = edge_dist(pt, rv1, rv2);
        let d2 = edge_dist(pt, rv2, rv3);
        let d3 = edge_dist(pt, rv3, rv1);
        let min_d = min(min(d1, d2), d3);
        if (min_d < 0.003) {
            edge_line = true;
        }
    }
    
    for (var scale_idx = 1i; scale_idx < 6i; scale_idx = scale_idx + 1i) {
        let scale = 0.3 + 0.1 * f32(scale_idx);
        for (var rot_idx = 0i; rot_idx < 8i; rot_idx = rot_idx + 1i) {
            let angle = pi * 0.25 * f32(rot_idx);
            let c = cos(angle);
            let s = sin(angle);
            
            let sv1 = vec2<f32>(c, -s) * (v1 * scale).x + vec2<f32>(s, c) * (v1 * scale).y;
            let sv2 = vec2<f32>(c, -s) * (v2 * scale).x + vec2<f32>(s, c) * (v2 * scale).y;
            let sv3 = vec2<f32>(c, -s) * (v3 * scale).x + vec2<f32>(s, c) * (v3 * scale).y;
            
            let in_tri = point_in_triangle(pt, sv1, sv2, sv3);
            if (in_tri > 0.5) {
                best_color = select(0.0, 1.0, (rot_idx + scale_idx) % 2i == 0i);
            }
            
            let d1 = edge_dist(pt, sv1, sv2);
            let d2 = edge_dist(pt, sv2, sv3);
            let d3 = edge_dist(pt, sv3, sv1);
            let min_d = min(min(d1, d2), d3);
            if (min_d < 0.003) {
                edge_line = true;
            }
        }
    }
    
    if (edge_line) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    let color = mix(vec3<f32>(1.0, 1.0, 1.0), vec3<f32>(0.0, 0.0, 0.0), best_color);
    return vec4<f32>(color, 1.0);
}