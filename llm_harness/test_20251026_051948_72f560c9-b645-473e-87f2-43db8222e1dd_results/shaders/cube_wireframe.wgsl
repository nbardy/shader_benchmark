// Axis-aligned cube wireframe renderer
// Side = 2, centered at origin
// Elevated orthographic view: 45° elevation, 30° azimuth
// Midnight-blue edges (#003366), sky-blue faces (α=0.1)
// Dashed hidden edges

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

// Orthographic projection with 45° elevation, 30° azimuth
fn projectVertex(v: vec3<f32>) -> vec2<f32> {
    // Camera angles
    let elevation = 0.7854f;  // π/4 = 45°
    let azimuth = 0.5236f;    // π/6 = 30°
    
    let cosEl = cos(elevation);
    let sinEl = sin(elevation);
    let cosAz = cos(azimuth);
    let sinAz = sin(azimuth);
    
    // Rotation matrices
    let x = v.x * cosAz - v.y * sinAz;
    let y_temp = v.x * sinAz + v.y * cosAz;
    let z_temp = v.z;
    
    let y_rot = y_temp * cosEl - z_temp * sinEl;
    let z_rot = y_temp * sinEl + z_temp * cosEl;
    
    // Orthographic projection (ignore z for depth, use for visibility)
    return vec2<f32>(x, y_rot) * 0.4;
}

// Line segment distance (for wireframe rendering)
fn distToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / (dot(ba, ba) + 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// Check if edge is hidden (z-test for back-facing)
fn isEdgeHidden(v0: vec3<f32>, v1: vec3<f32>) -> bool {
    let elevation = 0.7854f;
    let azimuth = 0.5236f;
    let cosEl = cos(elevation);
    let sinEl = sin(elevation);
    let cosAz = cos(azimuth);
    let sinAz = sin(azimuth);
    
    let x0 = v0.x * cosAz - v0.y * sinAz;
    let y0_t = v0.x * sinAz + v0.y * cosAz;
    let z0_r = v0.x * sinAz + v0.y * cosEl - v0.z * sinEl;
    
    let x1 = v1.x * cosAz - v1.y * sinAz;
    let y1_t = v1.x * sinAz + v1.y * cosAz;
    let z1_r = v1.x * sinAz + v1.y * cosEl - v1.z * sinEl;
    
    let avgZ = (z0_r + z1_r) * 0.5;
    return avgZ < -0.5;
}

// Dashed line pattern
fn dashPattern(t: f32) -> f32 {
    let dashLen = 0.15;
    let gapLen = 0.1;
    let period = dashLen + gapLen;
    let phase = fract(t / period);
    return select(1.0, 0.0, phase < (dashLen / period));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution * 2.0;
    let aspect = params.resolution.x / params.resolution.y;
    let p = vec2<f32>(uv.x * aspect, uv.y);
    
    // Cube vertices: side = 2, centered at origin
    let v0 = vec3<f32>(-1.0, -1.0, -1.0);
    let v1 = vec3<f32>( 1.0, -1.0, -1.0);
    let v2 = vec3<f32>( 1.0,  1.0, -1.0);
    let v3 = vec3<f32>(-1.0,  1.0, -1.0);
    let v4 = vec3<f32>(-1.0, -1.0,  1.0);
    let v5 = vec3<f32>( 1.0, -1.0,  1.0);
    let v6 = vec3<f32>( 1.0,  1.0,  1.0);
    let v7 = vec3<f32>(-1.0,  1.0,  1.0);
    
    // Project to 2D
    let p0 = projectVertex(v0);
    let p1 = projectVertex(v1);
    let p2 = projectVertex(v2);
    let p3 = projectVertex(v3);
    let p4 = projectVertex(v4);
    let p5 = projectVertex(v5);
    let p6 = projectVertex(v6);
    let p7 = projectVertex(v7);
    
    // Edge list with visibility
    var minVisibleDist = 1e6;
    var minHiddenDist = 1e6;
    
    // Back face (z = -1)
    let d01 = distToSegment(p, p0, p1);
    let h01 = isEdgeHidden(v0, v1);
    minVisibleDist = select(min(minVisibleDist, d01), minVisibleDist, h01);
    minHiddenDist = select(min(minHiddenDist, d01), minHiddenDist, !h01);
    
    let d12 = distToSegment(p, p1, p2);
    let h12 = isEdgeHidden(v1, v2);
    minVisibleDist = select(min(minVisibleDist, d12), minVisibleDist, h12);
    minHiddenDist = select(min(minHiddenDist, d12), minHiddenDist, !h12);
    
    let d23 = distToSegment(p, p2, p3);
    let h23 = isEdgeHidden(v2, v3);
    minVisibleDist = select(min(minVisibleDist, d23), minVisibleDist, h23);
    minHiddenDist = select(min(minHiddenDist, d23), minHiddenDist, !h23);
    
    let d30 = distToSegment(p, p3, p0);
    let h30 = isEdgeHidden(v3, v0);
    minVisibleDist = select(min(minVisibleDist, d30), minVisibleDist, h30);
    minHiddenDist = select(min(minHiddenDist, d30), minHiddenDist, !h30);
    
    // Front face (z = 1)
    let d45 = distToSegment(p, p4, p5);
    let h45 = isEdgeHidden(v4, v5);
    minVisibleDist = select(min(minVisibleDist, d45), minVisibleDist, h45);
    minHiddenDist = select(min(minHiddenDist, d45), minHiddenDist, !h45);
    
    let d56 = distToSegment(p, p5, p6);
    let h56 = isEdgeHidden(v5, v6);
    minVisibleDist = select(min(minVisibleDist, d56), minVisibleDist, h56);
    minHiddenDist = select(min(minHiddenDist, d56), minHiddenDist, !h56);
    
    let d67 = distToSegment(p, p6, p7);
    let h67 = isEdgeHidden(v6, v7);
    minVisibleDist = select(min(minVisibleDist, d67), minVisibleDist, h67);
    minHiddenDist = select(min(minHiddenDist, d67), minHiddenDist, !h67);
    
    let d74 = distToSegment(p, p7, p4);
    let h74 = isEdgeHidden(v7, v4);
    minVisibleDist = select(min(minVisibleDist, d74), minVisibleDist, h74);
    minHiddenDist = select(min(minHiddenDist, d74), minHiddenDist, !h74);
    
    // Vertical edges
    let d04 = distToSegment(p, p0, p4);
    let h04 = isEdgeHidden(v0, v4);
    minVisibleDist = select(min(minVisibleDist, d04), minVisibleDist, h04);
    minHiddenDist = select(min(minHiddenDist, d04), minHiddenDist, !h04);
    
    let d15 = distToSegment(p, p1, p5);
    let h15 = isEdgeHidden(v1, v5);
    minVisibleDist = select(min(minVisibleDist, d15), minVisibleDist, h15);
    minHiddenDist = select(min(minHiddenDist, d15), minHiddenDist, !h15);
    
    let d26 = distToSegment(p, p2, p6);
    let h26 = isEdgeHidden(v2, v6);
    minVisibleDist = select(min(minVisibleDist, d26), minVisibleDist, h26);
    minHiddenDist = select(min(minHiddenDist, d26), minHiddenDist, !h26);
    
    let d37 = distToSegment(p, p3, p7);
    let h37 = isEdgeHidden(v3, v7);
    minVisibleDist = select(min(minVisibleDist, d37), minVisibleDist, h37);
    minHiddenDist = select(min(minHiddenDist, d37), minHiddenDist, !h37);
    
    // Render logic
    let lineWidth = 0.006;
    let edgePixels = 3.0 / params.resolution.x;
    
    // Visible edges: solid midnight-blue
    let visibleAlpha = smoothstep(edgePixels, 0.0, minVisibleDist - lineWidth);
    let midnightBlue = vec3<f32>(0.0, 0.2, 0.4);
    
    // Hidden edges: dashed with pattern
    let dashAlpha = smoothstep(edgePixels, 0.0, minHiddenDist - lineWidth);
    let dashMask = dashPattern(minHiddenDist * 50.0);
    let hiddenAlpha = dashAlpha * dashMask * 0.5;
    
    // Face fill: semi-transparent sky-blue
    let faceAlpha = 0.1;
    let skyBlue = vec3<f32>(0.53, 0.81, 0.92);
    
    var color = skyBlue * faceAlpha;
    color = mix(color, midnightBlue, visibleAlpha);
    color = mix(color, midnightBlue, hiddenAlpha);
    
    let alpha = faceAlpha + max(visibleAlpha, hiddenAlpha);
    
    return vec4<f32>(color, min(alpha, 1.0));
}