// Rhombic Penrose Tiling P3 - Three Deflation Steps
// Generates finite patch with thick/thin rhombi, arrows, and styling

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

const PI = 3.14159265359;
const TAU = 6.28318530718;
const PHI = 1.61803398875;
const ANGLE_72 = 1.25663706144;
const ANGLE_36 = 0.62831853072;
const SQRT5 = 2.23606797750;
const CANVAS_SIZE = 2500.0;
const RADIUS_LIMIT = 8.0;
const STROKE_WIDTH = 1.5;
const ARROW_LENGTH = 0.3;

struct Rhombus {
    p0: vec2<f32>,
    p1: vec2<f32>,
    p2: vec2<f32>,
    p3: vec2<f32>,
    is_thick: bool,
    centroid: vec2<f32>,
};

fn rotate_point(p: vec2<f32>, angle: f32) -> vec2<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec2<f32>(p.x * c - p.y * s, p.x * s + p.y * c);
}

fn rhombus_centroid(r: Rhombus) -> vec2<f32> {
    return (r.p0 + r.p1 + r.p2 + r.p3) * 0.25;
}

fn within_radius_limit(centroid: vec2<f32>) -> bool {
    return length(centroid) <= RADIUS_LIMIT;
}

fn point_in_rhombus(p: vec2<f32>, r: Rhombus) -> bool {
    let eps = 0.001;
    
    let cross0 = (r.p1 - r.p0).x * (p.y - r.p0.y) - (r.p1 - r.p0).y * (p.x - r.p0.x);
    let cross1 = (r.p2 - r.p1).x * (p.y - r.p1.y) - (r.p2 - r.p1).y * (p.x - r.p1.x);
    let cross2 = (r.p3 - r.p2).x * (p.y - r.p2.y) - (r.p3 - r.p2).y * (p.x - r.p2.x);
    let cross3 = (r.p0 - r.p3).x * (p.y - r.p3.y) - (r.p0 - r.p3).y * (p.x - r.p3.x);
    
    let all_positive = cross0 >= -eps && cross1 >= -eps && cross2 >= -eps && cross3 >= -eps;
    let all_negative = cross0 <= eps && cross1 <= eps && cross2 <= eps && cross3 <= eps;
    
    return all_positive || all_negative;
}

fn distance_to_segment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn deflate_thick_child_0(r: Rhombus) -> Rhombus {
    let scale = PHI;
    let center = rhombus_centroid(r);
    
    var scaled: Rhombus;
    scaled.p0 = center + (r.p0 - center) * scale;
    scaled.p1 = center + (r.p1 - center) * scale;
    scaled.p2 = center + (r.p2 - center) * scale;
    scaled.p3 = center + (r.p3 - center) * scale;
    
    let mid01 = (scaled.p0 + scaled.p1) * 0.5;
    let mid12 = (scaled.p1 + scaled.p2) * 0.5;
    let mid23 = (scaled.p2 + scaled.p3) * 0.5;
    let mid30 = (scaled.p3 + scaled.p0) * 0.5;
    
    var result: Rhombus;
    result.p0 = mid01;
    result.p1 = mid12;
    result.p2 = mid23;
    result.p3 = mid30;
    result.is_thick = true;
    result.centroid = rhombus_centroid(result);
    return result;
}

fn deflate_thick_child_1(r: Rhombus) -> Rhombus {
    let scale = PHI;
    let center = rhombus_centroid(r);
    
    var scaled: Rhombus;
    scaled.p0 = center + (r.p0 - center) * scale;
    scaled.p1 = center + (r.p1 - center) * scale;
    scaled.p2 = center + (r.p2 - center) * scale;
    scaled.p3 = center + (r.p3 - center) * scale;
    
    let mid01 = (scaled.p0 + scaled.p1) * 0.5;
    let mid30 = (scaled.p3 + scaled.p0) * 0.5;
    
    var result: Rhombus;
    result.p0 = scaled.p0;
    result.p1 = mid01;
    result.p2 = mid30;
    result.p3 = scaled.p3;
    result.is_thick = false;
    result.centroid = rhombus_centroid(result);
    return result;
}

fn deflate_thick_child_2(r: Rhombus) -> Rhombus {
    let scale = PHI;
    let center = rhombus_centroid(r);
    
    var scaled: Rhombus;
    scaled.p0 = center + (r.p0 - center) * scale;
    scaled.p1 = center + (r.p1 - center) * scale;
    scaled.p2 = center + (r.p2 - center) * scale;
    scaled.p3 = center + (r.p3 - center) * scale;
    
    let mid12 = (scaled.p1 + scaled.p2) * 0.5;
    let mid23 = (scaled.p2 + scaled.p3) * 0.5;
    
    var result: Rhombus;
    result.p0 = scaled.p1;
    result.p1 = scaled.p2;
    result.p2 = mid23;
    result.p3 = mid12;
    result.is_thick = false;
    result.centroid = rhombus_centroid(result);
    return result;
}

fn deflate_thin_child_0(r: Rhombus) -> Rhombus {
    let scale = PHI;
    let center = rhombus_centroid(r);
    
    var scaled: Rhombus;
    scaled.p0 = center + (r.p0 - center) * scale;
    scaled.p1 = center + (r.p1 - center) * scale;
    scaled.p2 = center + (r.p2 - center) * scale;
    scaled.p3 = center + (r.p3 - center) * scale;
    
    let mid01 = (scaled.p0 + scaled.p1) * 0.5;
    let mid23 = (scaled.p2 + scaled.p3) * 0.5;
    
    var result: Rhombus;
    result.p0 = scaled.p0;
    result.p1 = mid01;
    result.p2 = scaled.p2;
    result.p3 = mid23;
    result.is_thick = true;
    result.centroid = rhombus_centroid(result);
    return result;
}

fn deflate_thin_child_1(r: Rhombus) -> Rhombus {
    let scale = PHI;
    let center = rhombus_centroid(r);
    
    var scaled: Rhombus;
    scaled.p0 = center + (r.p0 - center) * scale;
    scaled.p1 = center + (r.p1 - center) * scale;
    scaled.p2 = center + (r.p2 - center) * scale;
    scaled.p3 = center + (r.p3 - center) * scale;
    
    let mid01 = (scaled.p0 + scaled.p1) * 0.5;
    let mid23 = (scaled.p2 + scaled.p3) * 0.5;
    
    var result: Rhombus;
    result.p0 = mid01;
    result.p1 = scaled.p1;
    result.p2 = mid23;
    result.p3 = scaled.p3;
    result.is_thick = false;
    result.centroid = rhombus_centroid(result);
    return result;
}

fn get_rhombus_color(is_thick: bool) -> vec3<f32> {
    if (is_thick) {
        return vec3<f32>(1.0, 0.8, 0.4);
    } else {
        return vec3<f32>(0.4, 0.667, 1.0);
    }
}

fn sample_tiling(uv: vec2<f32>) -> vec3<f32> {
    let canvas_pos = uv * CANVAS_SIZE - CANVAS_SIZE * 0.5;
    
    var rhombi: array<Rhombus, 100u>;
    var count: u32 = 0u;
    
    let init_size = 1.0;
    let angle_offset = ANGLE_72;
    rhombi[count].p0 = rotate_point(vec2<f32>(init_size, 0.0), 0.0);
    rhombi[count].p1 = rotate_point(vec2<f32>(init_size, 0.0), angle_offset);
    rhombi[count].p2 = rotate_point(vec2<f32>(-init_size, 0.0), angle_offset);
    rhombi[count].p3 = rotate_point(vec2<f32>(-init_size, 0.0), 0.0);
    rhombi[count].is_thick = true;
    rhombi[count].centroid = vec2<f32>(0.0, 0.0);
    count = count + 1u;
    
    // Deflation iteration 1
    var new_rhombi: array<Rhombus, 100u>;
    var new_count: u32 = 0u;
    
    for (var i: u32 = 0u; i < count; i = i + 1u) {
        if (rhombi[i].is_thick) {
            let c0 = deflate_thick_child_0(rhombi[i]);
            if (within_radius_limit(c0.centroid)) {
                new_rhombi[new_count] = c0;
                new_count = new_count + 1u;
            }
            let c1 = deflate_thick_child_1(rhombi[i]);
            if (within_radius_limit(c1.centroid)) {
                new_rhombi[new_count] = c1;
                new_count = new_count + 1u;
            }
            let c2 = deflate_thick_child_2(rhombi[i]);
            if (within_radius_limit(c2.centroid)) {
                new_rhombi[new_count] = c2;
                new_count = new_count + 1u;
            }
        } else {
            let c0 = deflate_thin_child_0(rhombi[i]);
            if (within_radius_limit(c0.centroid)) {
                new_rhombi[new_count] = c0;
                new_count = new_count + 1u;
            }
            let c1 = deflate_thin_child_1(rhombi[i]);
            if (within_radius_limit(c1.centroid)) {
                new_rhombi[new_count] = c1;
                new_count = new_count + 1u;
            }
        }
    }
    rhombi = new_rhombi;
    count = new_count;
    
    // Deflation iteration 2
    new_rhombi = array<Rhombus, 100u>();
    new_count = 0u;
    
    for (var i: u32 = 0u; i < count; i = i + 1u) {
        if (rhombi[i].is_thick) {
            let c0 = deflate_thick_child_0(rhombi[i]);
            if (within_radius_limit(c0.centroid)) {
                new_rhombi[new_count] = c0;
                new_count = new_count + 1u;
            }
            let c1 = deflate_thick_child_1(rhombi[i]);
            if (within_radius_limit(c1.centroid)) {
                new_rhombi[new_count] = c1;
                new_count = new_count + 1u;
            }
            let c2 = deflate_thick_child_2(rhombi[i]);
            if (within_radius_limit(c2.centroid)) {
                new_rhombi[new_count] = c2;
                new_count = new_count + 1u;
            }
        } else {
            let c0 = deflate_thin_child_0(rhombi[i]);
            if (within_radius_limit(c0.centroid)) {
                new_rhombi[new_count] = c0;
                new_count = new_count + 1u;
            }
            let c1 = deflate_thin_child_1(rhombi[i]);
            if (within_radius_limit(c1.centroid)) {
                new_rhombi[new_count] = c1;
                new_count = new_count + 1u;
            }
        }
    }
    rhombi = new_rhombi;
    count = new_count;
    
    // Deflation iteration 3
    new_rhombi = array<Rhombus, 100u>();
    new_count = 0u;
    
    for (var i: u32 = 0u; i < count; i = i + 1u) {
        if (rhombi[i].is_thick) {
            let c0 = deflate_thick_child_0(rhombi[i]);
            if (within_radius_limit(c0.centroid)) {
                new_rhombi[new_count] = c0;
                new_count = new_count + 1u;
            }
            let c1 = deflate_thick_child_1(rhombi[i]);
            if (within_radius_limit(c1.centroid)) {
                new_rhombi[new_count] = c1;
                new_count = new_count + 1u;
            }
            let c2 = deflate_thick_child_2(rhombi[i]);
            if (within_radius_limit(c2.centroid)) {
                new_rhombi[new_count] = c2;
                new_count = new_count + 1u;
            }
        } else {
            let c0 = deflate_thin_child_0(rhombi[i]);
            if (within_radius_limit(c0.centroid)) {
                new_rhombi[new_count] = c0;
                new_count = new_count + 1u;
            }
            let c1 = deflate_thin_child_1(rhombi[i]);
            if (within_radius_limit(c1.centroid)) {
                new_rhombi[new_count] = c1;
                new_count = new_count + 1u;
            }
        }
    }
    rhombi = new_rhombi;
    count = new_count;
    
    // Find containing rhombus
    for (var i: u32 = 0u; i < count; i = i + 1u) {
        if (point_in_rhombus(canvas_pos, rhombi[i])) {
            var color = get_rhombus_color(rhombi[i].is_thick);
            
            var min_edge_dist = 1000.0;
            min_edge_dist = min(min_edge_dist, distance_to_segment(canvas_pos, rhombi[i].p0, rhombi[i].p1));
            min_edge_dist = min(min_edge_dist, distance_to_segment(canvas_pos, rhombi[i].p1, rhombi[i].p2));
            min_edge_dist = min(min_edge_dist, distance_to_segment(canvas_pos, rhombi[i].p2, rhombi[i].p3));
            min_edge_dist = min(min_edge_dist, distance_to_segment(canvas_pos, rhombi[i].p3, rhombi[i].p0));
            
            let stroke_blend = smoothstep(STROKE_WIDTH, 0.0, min_edge_dist);
            color = mix(color, vec3<f32>(0.0, 0.0, 0.0), stroke_blend);
            
            return color;
        }
    }
    
    return vec3<f32>(1.0, 1.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let color = sample_tiling(uv);
    return vec4<f32>(color, 1.0);
}