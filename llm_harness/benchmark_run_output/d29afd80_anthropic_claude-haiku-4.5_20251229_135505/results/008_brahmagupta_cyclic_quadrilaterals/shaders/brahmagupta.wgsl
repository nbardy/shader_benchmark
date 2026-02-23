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
    mode: f32,
}

@group(0) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Center coordinates
    let center = vec2<f32>(0.0, 0.0);
    let radius = 0.6;
    
    // Generate cyclic quadrilateral vertices based on mode
    let t = params.time * 0.0005;
    
    var angle0 = 0.0;
    var angle1 = 1.57079632679;
    var angle2 = 3.14159265359;
    var angle3 = 4.71238898038;
    
    if (i32(params.mode) == 1) {
        // Rectangle
        angle0 = atan(0.5);
        angle1 = 3.14159265359 - atan(0.5);
        angle2 = 3.14159265359 + atan(0.5);
        angle3 = 6.28318530718 - atan(0.5);
    } else if (i32(params.mode) == 2) {
        // Irregular
        angle0 = 0.2;
        angle1 = 1.3;
        angle2 = 3.5;
        angle3 = 5.2;
    } else if (i32(params.mode) == 3) {
        // Animated
        angle0 = t;
        angle1 = t + 1.88495559215 + 0.3 * sin(t * 0.7);
        angle2 = t + 4.08407044967 + 0.4 * sin(t * 0.5);
        angle3 = t + 6.59734457541 + 0.3 * sin(t * 0.6);
    }
    
    let v0 = center + vec2<f32>(radius * cos(angle0), radius * sin(angle0));
    let v1 = center + vec2<f32>(radius * cos(angle1), radius * sin(angle1));
    let v2 = center + vec2<f32>(radius * cos(angle2), radius * sin(angle2));
    let v3 = center + vec2<f32>(radius * cos(angle3), radius * sin(angle3));
    
    // Distance to circle
    let distToCircle = abs(length(uv - center) - radius);
    let circleColor = select(vec3<f32>(0.0), vec3<f32>(0.267, 0.267, 0.267), distToCircle < 0.01);
    
    // Distance to sides
    let dist0 = distanceToSegment(uv, v0, v1);
    let dist1 = distanceToSegment(uv, v1, v2);
    let dist2 = distanceToSegment(uv, v2, v3);
    let dist3 = distanceToSegment(uv, v3, v0);
    
    let minDist = min(min(dist0, dist1), min(dist2, dist3));
    
    var sideColor = vec3<f32>(0.0);
    if (minDist == dist0) {
        sideColor = vec3<f32>(1.0, 0.42, 0.42);
    } else if (minDist == dist1) {
        sideColor = vec3<f32>(0.31, 0.80, 0.77);
    } else if (minDist == dist2) {
        sideColor = vec3<f32>(0.27, 0.72, 0.82);
    } else if (minDist == dist3) {
        sideColor = vec3<f32>(1.0, 0.63, 0.48);
    }
    
    let sideAlpha = 1.0 - smoothstep(0.0, 0.02, minDist);
    
    // Distance to vertices
    let vdist0 = length(uv - v0);
    let vdist1 = length(uv - v1);
    let vdist2 = length(uv - v2);
    let vdist3 = length(uv - v3);
    
    let minVdist = min(min(vdist0, vdist1), min(vdist2, vdist3));
    let vertexAlpha = 1.0 - smoothstep(0.0, 0.03, minVdist);
    
    // Combine colors
    let baseColor = circleColor + sideColor * sideAlpha + vec3<f32>(0.565, 0.725, 0.96) * vertexAlpha;
    
    return vec4<f32>(baseColor, 1.0);
}

fn distanceToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}