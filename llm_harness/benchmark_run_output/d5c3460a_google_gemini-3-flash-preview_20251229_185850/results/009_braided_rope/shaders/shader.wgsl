// BRAIDED ROPE SHADER - SPEC COMPLIANT WGSL
// Geometry: 3 Helices, Radius 0.6, Pitch 1.8, Phase Offsets 0, 120, 240.

struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

// Distance Function for a single helix strand
// p: world position
// phase: rotation offset in radians
// tube_r: thickness of the strand
fn sd_helix(p: vec3<f32>, phase: f32, tube_r: f32) -> f32 {
    let cylinder_r = 0.6;
    let pitch = 1.8;
    let k = 6.283185307 / pitch;
    
    // Smooth twisting coordinate system
    let a = (p.y * k) + phase;
    let target_pos = vec3<f32>(cylinder_r * cos(a), p.y, cylinder_r * sin(a));
    
    // Approximation of distance to helical curve
    // We treat the helix locally as a line segment or circle arc
    // Since pitch is relatively high, simple distance works well
    let dist_to_curve = length(p - target_pos);
    return dist_to_curve - tube_r;
}

fn map(p: vec3<f32>) -> vec4<f32> {
    let tube_radius = 0.15;
    let d1 = sd_helix(p, 0.0, tube_radius);             // 0 degrees
    let d2 = sd_helix(p, 2.094395102, tube_radius);     // 120 degrees
    let d3 = sd_helix(p, 4.188790205, tube_radius);     // 240 degrees
    
    // Colors converted from Hex
    let col1 = vec3<f32>(0.8, 0.6, 0.4); // #c96 approx
    let col2 = vec3<f32>(0.4, 0.8, 0.6); // #6c9 approx
    let col3 = vec3<f32>(0.6, 0.4, 0.8); // #96c approx
    
    var res = vec4<f32>(d1, col1);
    
    if (d2 < res.x) {
        res = vec4<f32>(d2, col2);
    }
    if (d3 < res.x) {
        res = vec4<f32>(d3, col3);
    }
    
    return res;
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    return normalize(vec3<f32>(
        map(p + e.xyy).x - map(p - e.xyy).x,
        map(p + e.yxy).x - map(p - e.yxy).x,
        map(p + e.yyx).x - map(p - e.yyx).x
    ));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - 0.5 * params.resolution.xy) / min(params.resolution.y, params.resolution.x);
    
    // Camera setup: Position (3, 2, 2)
    let ro = vec3<f32>(3.0, 2.0, 2.0);
    let lookat = vec3<f32>(0.0, 0.0, 0.0);
    let fwd = normalize(lookat - ro);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), fwd));
    let up = cross(fwd, right);
    let rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Raymarching
    var t = 0.0;
    var res = vec4<f32>(0.0);
    for (var i = 0u; i < 100u; i = i + 1u) {
        let p = ro + rd * t;
        res = map(p);
        if (res.x < 0.001 || t > 20.0) { break; }
        t = t + res.x;
    }
    
    var color = vec3<f32>(0.05, 0.05, 0.07); // Dark background
    
    if (t < 20.0) {
        let p = ro + rd * t;
        let n = get_normal(p);
        let light_dir = normalize(vec3<f32>(5.0, 10.0, 2.0));
        
        let diff = max(dot(n, light_dir), 0.0);
        let amb = 0.2;
        let spec = pow(max(dot(reflect(-light_dir, n), -rd), 0.0), 32.0);
        
        let strand_color = res.yzw;
        color = strand_color * (diff + amb) + vec3<f32>(spec * 0.4);
        
        // Simple fog for depth
        color = mix(color, vec3<f32>(0.05, 0.05, 0.07), 1.0 - exp(-0.02 * t));
    }
    
    // Final output gamma correction
    return vec4<f32>(pow(color, vec3<f32>(0.4545)), 1.0);
}