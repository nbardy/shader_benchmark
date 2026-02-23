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
    aspect: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Distance from point to line segment
fn distToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// 3D point projection to 2D with perspective
fn project(p: vec3<f32>) -> vec2<f32> {
    let scale = 1.0 / (2.0 + p.z);
    return p.xy * scale;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to [-0.9, 0.9] range, centered
    let uv = (pos.xy - params.resolution * 0.5) / (params.resolution.y * 0.55);
    
    // Camera setup: elevated view from upper-right
    // Azimuth ~30°, elevation ~45°
    let azimuth = 0.5236;  // 30° in radians
    let elevation = 0.7854; // 45° in radians
    
    let cosAz = cos(azimuth);
    let sinAz = sin(azimuth);
    let cosEl = cos(elevation);
    let sinEl = sin(elevation);
    
    // Rotation matrix: first azimuth around Z, then elevation around X
    // This gives the elevated view from upper-right looking at cube corner
    
    // Cube vertices: axis-aligned, side=2, centered at origin
    // Range: [-1, 1] in each dimension
    let vertices = array<vec3<f32>, 8>(
        vec3<f32>(-1.0, -1.0, -1.0),  // 0: back-bottom-left
        vec3<f32>( 1.0, -1.0, -1.0),  // 1: back-bottom-right
        vec3<f32>( 1.0,  1.0, -1.0),  // 2: back-top-right
        vec3<f32>(-1.0,  1.0, -1.0),  // 3: back-top-left
        vec3<f32>(-1.0, -1.0,  1.0),  // 4: front-bottom-left
        vec3<f32>( 1.0, -1.0,  1.0),  // 5: front-bottom-right
        vec3<f32>( 1.0,  1.0,  1.0),  // 6: front-top-right
        vec3<f32>(-1.0,  1.0,  1.0)   // 7: front-top-left
    );
    
    // Apply rotation to all vertices
    var rotated = array<vec3<f32>, 8>();
    for (var i = 0u; i < 8u; i = i + 1u) {
        let v = vertices[i];
        
        // Azimuth rotation (around Z axis)
        let x1 = v.x * cosAz - v.y * sinAz;
        let y1 = v.x * sinAz + v.y * cosAz;
        let z1 = v.z;
        
        // Elevation rotation (around X axis, but on rotated coordinates)
        let x2 = x1;
        let y2 = y1 * cosEl - z1 * sinEl;
        let z2 = y1 * sinEl + z1 * cosEl;
        
        rotated[i] = vec3<f32>(x2, y2, z2 + 3.5);  // Move forward for perspective
    }
    
    // Project vertices to 2D
    var projected = array<vec2<f32>, 8>();
    for (var i = 0u; i < 8u; i = i + 1u) {
        projected[i] = project(rotated[i]);
    }
    
    // Compute z-depths for back-face culling and dashing
    var depths = array<f32, 8>();
    for (var i = 0u; i < 8u; i = i + 1u) {
        depths[i] = rotated[i].z;
    }
    
    // Edge list: (vertex0, vertex1, is_back_edge)
    // Back edges: 0-1, 1-2, 2-3, 3-0, 0-4, 1-5, 2-6, 3-7
    // Front edges: 4-5, 5-6, 6-7, 7-4, 4-0, 5-1, 6-2, 7-3
    
    var minDist = 1000.0;
    var isBackEdge = false;
    
    // Back face edges (z < 0 after rotation)
    var d = distToSegment(uv, projected[0], projected[1]);
    if (d < minDist) { minDist = d; isBackEdge = true; }
    
    d = distToSegment(uv, projected[1], projected[2]);
    if (d < minDist) { minDist = d; isBackEdge = true; }
    
    d = distToSegment(uv, projected[2], projected[3]);
    if (d < minDist) { minDist = d; isBackEdge = true; }
    
    d = distToSegment(uv, projected[3], projected[0]);
    if (d < minDist) { minDist = d; isBackEdge = true; }
    
    // Front face edges
    d = distToSegment(uv, projected[4], projected[5]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    d = distToSegment(uv, projected[5], projected[6]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    d = distToSegment(uv, projected[6], projected[7]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    d = distToSegment(uv, projected[7], projected[4]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    // Connecting edges (some visible, some hidden)
    d = distToSegment(uv, projected[0], projected[4]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    d = distToSegment(uv, projected[1], projected[5]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    d = distToSegment(uv, projected[2], projected[6]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    d = distToSegment(uv, projected[3], projected[7]);
    if (d < minDist) { minDist = d; isBackEdge = false; }
    
    // Rendering
    let lineWidth = 0.015; // 3px equivalent at 1800×1800
    let edgeAlpha = 1.0 - smoothstep(0.0, lineWidth, minDist);
    
    // Midnight blue edge color: #003366
    let edgeColor = vec3<f32>(0.0, 0.2, 0.4);
    
    // Sky blue face color: #87CEEB with transparency
    let faceColor = vec3<f32>(0.53, 0.81, 0.92);
    
    // Apply dashing to back edges
    var edgeAlphaFinal = edgeAlpha;
    if (isBackEdge && edgeAlpha > 0.1) {
        let dashPhase = fract((uv.x + uv.y) * 15.0);
        edgeAlphaFinal = edgeAlpha * step(0.5, dashPhase);
    }
    
    // Composite: edges over semi-transparent faces
    var finalColor = vec3<f32>(0.96, 0.96, 0.96);  // Light background
    
    // Face contribution (very subtle)
    finalColor = mix(finalColor, faceColor, 0.08);
    
    // Edge contribution
    finalColor = mix(finalColor, edgeColor, edgeAlphaFinal);
    
    return vec4<f32>(finalColor, 1.0);
}