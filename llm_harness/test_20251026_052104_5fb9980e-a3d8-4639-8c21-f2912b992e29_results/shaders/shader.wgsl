// Hyperbolic (2,3,∞) triangle group kaleidoscope
// Renders reflections of a (30°,60°,90°) fundamental triangle
// in the Poincaré disk, with depth-based coloring

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

// Reflect point p across line from a to b in hyperbolic geometry
fn hyperbolic_reflect(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let ap = p - a;
    let ab = b - a;
    let ab_len_sq = dot(ab, ab);
    
    var t = 0.0;
    if (ab_len_sq > 1e-8) {
        t = dot(ap, ab) / ab_len_sq;
    }
    
    let closest = a + ab * t;
    let reflected = 2.0 * closest - p;
    
    // Normalize to stay in disk
    let r = length(reflected);
    let max_r = 0.99;
    var result = reflected;
    if (r > max_r) {
        result = reflected * (max_r / r);
    }
    return result;
}

// Distance from point to line segment in Euclidean space
fn point_to_segment_dist(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let ap = p - a;
    let ab = b - a;
    let ab_len_sq = dot(ab, ab);
    
    if (ab_len_sq < 1e-8) {
        return length(ap);
    }
    
    let t = clamp(dot(ap, ab) / ab_len_sq, 0.0, 1.0);
    let closest = a + ab * t;
    return length(p - closest);
}

// Check if point is inside triangle (barycentric)
fn point_in_triangle(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> bool {
    let v0 = c - a;
    let v1 = b - a;
    let v2 = p - a;
    
    let dot00 = dot(v0, v0);
    let dot01 = dot(v0, v1);
    let dot02 = dot(v0, v2);
    let dot11 = dot(v1, v1);
    let dot12 = dot(v1, v2);
    
    var inv_denom = dot00 * dot11 - dot01 * dot01;
    if (inv_denom < 1e-8) {
        inv_denom = 1e-8;
    }
    inv_denom = 1.0 / inv_denom;
    
    let u = (dot11 * dot02 - dot01 * dot12) * inv_denom;
    let v = (dot00 * dot12 - dot01 * dot02) * inv_denom;
    
    return (u >= 0.0) && (v >= 0.0) && (u + v <= 1.0);
}

// HSL to RGB conversion
fn hsl_to_rgb(h: f32, s: f32, l: f32) -> vec3<f32> {
    let h_norm = h % 360.0;
    let c = (1.0 - abs(2.0 * l - 1.0)) * s;
    let h_prime = h_norm / 60.0;
    let x = c * (1.0 - abs(h_prime % 2.0 - 1.0));
    
    var rgb = vec3<f32>(0.0);
    let h_idx = u32(h_prime) % 6u;
    
    if (h_idx == 0u) {
        rgb = vec3<f32>(c, x, 0.0);
    } else if (h_idx == 1u) {
        rgb = vec3<f32>(x, c, 0.0);
    } else if (h_idx == 2u) {
        rgb = vec3<f32>(0.0, c, x);
    } else if (h_idx == 3u) {
        rgb = vec3<f32>(0.0, x, c);
    } else if (h_idx == 4u) {
        rgb = vec3<f32>(x, 0.0, c);
    } else {
        rgb = vec3<f32>(c, 0.0, x);
    }
    
    let m = l - c * 0.5;
    return rgb + vec3<f32>(m);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let disk_radius = 0.95 * res.x / 2.0;
    let center = res / 2.0;
    
    let px = pos.xy;
    let offset = px - center;
    
    // Check if outside disk
    let dist_from_center = length(offset);
    if (dist_from_center > disk_radius) {
        return vec4<f32>(1.0, 1.0, 1.0, 1.0); // white background
    }
    
    // Normalize to Poincaré disk coordinates [-0.95, 0.95]
    let disk_coord = offset / disk_radius;
    
    // Fundamental triangle vertices in Poincaré disk
    let v1 = vec2<f32>(0.0, 0.0);
    let v2 = vec2<f32>(0.6, 0.0);
    let v3 = vec2<f32>(0.2, 0.55);
    
    // Generate reflections and find closest triangle
    var best_depth = 0u;
    var best_color = vec3<f32>(1.0);
    var closest_edge_dist = 1000.0;
    
    // Depth 0: fundamental triangle
    if (point_in_triangle(disk_coord, v1, v2, v3)) {
        best_depth = 0u;
        let lum = 0.9;
        let hue = 200.0;
        best_color = hsl_to_rgb(hue, 0.8, lum * 0.5);
    }
    
    // Depth 1: direct reflections
    // Reflect across edge v1-v2 (bottom)
    let r1_v1 = v1;
    let r1_v2 = v2;
    let r1_v3 = hyperbolic_reflect(v3, v1, v2);
    if (point_in_triangle(disk_coord, r1_v1, r1_v2, r1_v3)) {
        best_depth = 1u;
        let lum = 0.9 * 0.7;
        let hue = 200.0 + 10.0;
        best_color = hsl_to_rgb(hue, 0.8, lum * 0.5);
    }
    
    // Reflect across edge v2-v3 (right)
    let r2_v1 = hyperbolic_reflect(v1, v2, v3);
    let r2_v2 = v2;
    let r2_v3 = v3;
    if (point_in_triangle(disk_coord, r2_v1, r2_v2, r2_v3)) {
        best_depth = 1u;
        let lum = 0.9 * 0.7;
        let hue = 200.0 + 10.0;
        best_color = hsl_to_rgb(hue, 0.8, lum * 0.5);
    }
    
    // Reflect across edge v3-v1 (left)
    let r3_v1 = v1;
    let r3_v2 = hyperbolic_reflect(v2, v3, v1);
    let r3_v3 = v3;
    if (point_in_triangle(disk_coord, r3_v1, r3_v2, r3_v3)) {
        best_depth = 1u;
        let lum = 0.9 * 0.7;
        let hue = 200.0 + 10.0;
        best_color = hsl_to_rgb(hue, 0.8, lum * 0.5);
    }
    
    // Depth 2: secondary reflections (simplified - 6 triangles)
    let d2_lum = 0.9 * 0.7 * 0.7;
    let d2_hue = 200.0 + 20.0;
    let d2_color = hsl_to_rgb(d2_hue, 0.8, d2_lum * 0.5);
    
    // Double reflection: reflect r1 across its edges
    let d2_v1a = hyperbolic_reflect(r1_v1, r1_v2, r1_v3);
    let d2_v2a = r1_v2;
    let d2_v3a = r1_v3;
    if (point_in_triangle(disk_coord, d2_v1a, d2_v2a, d2_v3a)) {
        best_depth = 2u;
        best_color = d2_color;
    }
    
    // Depth 3 & 4: tertiary and quaternary reflections
    let d3_lum = 0.9 * pow(0.7, 3.0);
    let d3_hue = 200.0 + 30.0;
    let d3_color = hsl_to_rgb(d3_hue, 0.8, d3_lum * 0.5);
    
    let d4_lum = 0.9 * pow(0.7, 4.0);
    let d4_hue = 200.0 + 40.0;
    let d4_color = hsl_to_rgb(d4_hue, 0.8, d4_lum * 0.5);
    
    // Sample several reflected triangles at depth 3+4
    var d3_hit = false;
    var d4_hit = false;
    
    // Tertiary reflection of r1
    let d3_v1b = hyperbolic_reflect(d2_v1a, d2_v2a, d2_v3a);
    let d3_v2b = d2_v2a;
    let d3_v3b = d2_v3a;
    if (point_in_triangle(disk_coord, d3_v1b, d3_v2b, d3_v3b) && !d3_hit) {
        best_depth = 3u;
        best_color = d3_color;
        d3_hit = true;
    }
    
    // Quaternary reflection
    if (!d4_hit && !d3_hit) {
        let d4_v1c = hyperbolic_reflect(d3_v1b, d3_v2b, d3_v3b);
        let d4_v2c = d3_v2b;
        let d4_v3c = d3_v3b;
        if (point_in_triangle(disk_coord, d4_v1c, d4_v2c, d4_v3c)) {
            best_depth = 4u;
            best_color = d4_color;
            d4_hit = true;
        }
    }
    
    // Edge rendering: check distance to nearest triangle edge
    var edge_dist = 1000.0;
    
    // Fundamental triangle edges
    edge_dist = min(edge_dist, point_to_segment_dist(disk_coord, v1, v2));
    edge_dist = min(edge_dist, point_to_segment_dist(disk_coord, v2, v3));
    edge_dist = min(edge_dist, point_to_segment_dist(disk_coord, v3, v1));
    
    // Reflected triangle edges (sample depth 1)
    edge_dist = min(edge_dist, point_to_segment_dist(disk_coord, r1_v1, r1_v2));
    edge_dist = min(edge_dist, point_to_segment_dist(disk_coord, r1_v2, r1_v3));
    edge_dist = min(edge_dist, point_to_segment_dist(disk_coord, r1_v3, r1_v1));
    
    // Edge stroke in pixels (1.5 px relative to disk radius)
    let edge_width = 1.5 / disk_radius;
    let edge_alpha = select(0.0, 1.0, edge_dist < edge_width);
    let edge_color = vec3<f32>(0.133, 0.133, 0.133); // #222222
    
    // Blend: edges over triangle color
    var final_color = best_color;
    if (edge_alpha > 0.0) {
        final_color = mix(best_color, edge_color, edge_alpha);
    }
    
    // Disk boundary: subtle vignette
    let boundary_fade = smoothstep(1.0, 0.85, dist_from_center / disk_radius);
    final_color = final_color * boundary_fade;
    
    return vec4<f32>(final_color, 1.0);
}