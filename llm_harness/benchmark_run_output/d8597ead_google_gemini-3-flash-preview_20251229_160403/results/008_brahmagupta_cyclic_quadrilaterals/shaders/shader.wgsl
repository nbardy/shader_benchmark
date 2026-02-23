// BRAHMAGUPTA'S CYCLIC QUADRILATERAL VISUALIZATION
// Formula: Area = sqrt((s-a)(s-b)(s-c)(s-d))
// Ptolemy's Theorem: ac + bd = ef

struct Params {
    resolution: vec2<f32>,
    time: f32,
    mode: f32, // 0: Irregular, 1: Rectangle, 2: Square
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

fn sd_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn get_pts(t: f32) -> array<vec2<f32>, 4> {
    var pts: array<vec2<f32>, 4>;
    let radius = 0.4;
    
    // Smooth orchestration of movement
    let phase = params.time * 0.5;
    
    // Dynamic angles
    let a1 = phase + 0.5 * sin(phase * 0.7);
    let a2 = phase + 2.1 + 0.3 * cos(phase * 0.8);
    let a3 = phase + 3.5 + 0.4 * sin(phase * 1.1);
    let a4 = phase + 5.2 + 0.2 * cos(phase * 0.9);
    
    // Square configuration logic
    let sq_offset = phase;
    let pts_sq = array<vec2<f32>, 4>(
        vec2<f32>(cos(sq_offset), sin(sq_offset)) * radius,
        vec2<f32>(cos(sq_offset + 1.5708), sin(sq_offset + 1.5708)) * radius,
        vec2<f32>(cos(sq_offset + 3.1416), sin(sq_offset + 3.1416)) * radius,
        vec2<f32>(cos(sq_offset + 4.7124), sin(sq_offset + 4.7124)) * radius
    );

    pts[0] = vec2<f32>(cos(a1), sin(a1)) * radius;
    pts[1] = vec2<f32>(cos(a2), sin(a2)) * radius;
    pts[2] = vec2<f32>(cos(a3), sin(a3)) * radius;
    pts[3] = vec2<f32>(cos(a4), sin(a4)) * radius;

    // Morph towards square based on mode
    let morph = smoothstep(0.0, 1.0, sin(params.time * 0.2) * 0.5 + 0.5);
    pts[0] = mix(pts[0], pts_sq[0], morph);
    pts[1] = mix(pts[1], pts_sq[1], morph);
    pts[2] = mix(pts[2], pts_sq[2], morph);
    pts[3] = mix(pts[3], pts_sq[3], morph);
    
    return pts;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - 0.5 * params.resolution.xy) / min(params.resolution.x, params.resolution.y);
    
    let pts = get_pts(params.time);
    
    // Geometry calculations
    let a = distance(pts[0], pts[1]);
    let b = distance(pts[1], pts[2]);
    let c = distance(pts[2], pts[3]);
    let d = distance(pts[3], pts[0]);
    let s = (a + b + c + d) * 0.5;
    let area_sq = (s - a) * (s - b) * (s - c) * (s - d);
    let area = sqrt(max(0.0, area_sq));

    // Ptolemy's
    let e = distance(pts[0], pts[2]);
    let f = distance(pts[1], pts[3]);
    let ptolemy_diff = abs((a * c + b * d) - (e * f));

    // Background and Circle
    var color = vec3<f32>(0.08, 0.09, 0.12);
    let circle_dist = abs(length(uv) - 0.4);
    color = mix(color, vec3<f32>(0.3, 0.3, 0.3), 1.0 - smoothstep(0.002, 0.004, circle_dist));

    // Diagonals (Ptolemy)
    let d1 = sd_line(uv, pts[0], pts[2]);
    let d2 = sd_line(uv, pts[1], pts[3]);
    let diag_mask = min(d1, d2);
    color = mix(color, vec3<f32>(0.2, 0.2, 0.25), 1.0 - smoothstep(0.001, 0.003, diag_mask));

    // Side drawing and Coloring
    let s1 = sd_line(uv, pts[0], pts[1]);
    let s2 = sd_line(uv, pts[1], pts[2]);
    let s3 = sd_line(uv, pts[2], pts[3]);
    let s4 = sd_line(uv, pts[3], pts[0]);

    color = mix(color, vec3<f32>(0.9, 0.3, 0.3), 1.0 - smoothstep(0.003, 0.006, s1));
    color = mix(color, vec3<f32>(0.3, 0.9, 0.3), 1.0 - smoothstep(0.003, 0.006, s2));
    color = mix(color, vec3<f32>(0.3, 0.3, 0.9), 1.0 - smoothstep(0.003, 0.006, s3));
    color = mix(color, vec3<f32>(0.9, 0.9, 0.3), 1.0 - smoothstep(0.003, 0.006, s4));

    // Vertices
    var v_dist = 1.0;
    v_dist = min(v_dist, length(uv - pts[0]));
    v_dist = min(v_dist, length(uv - pts[1]));
    v_dist = min(v_dist, length(uv - pts[2]));
    v_dist = min(v_dist, length(uv - pts[3]));
    color = mix(color, vec3<f32>(1.0, 1.0, 1.0), 1.0 - smoothstep(0.01, 0.012, v_dist));

    // Math Visualization UI (Conceptual Area Meter)
    let meter_uv = uv - vec2<f32>(-0.7, -0.4);
    let area_bar = step(meter_uv.x, 0.0) * step(-0.05, meter_uv.x) * step(0.0, meter_uv.y) * step(meter_uv.y, area * 2.5);
    color = mix(color, vec3<f32>(0.0, 0.8, 1.0), area_bar);

    // Vignette
    let vignette = 1.0 - length(uv * 0.8);
    return vec4<f32>(color * vignette, 1.0);
}