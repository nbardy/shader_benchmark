// Test shader following WGSL constraints - Procedural mandala pattern
// Vertex shader - full-screen triangle
struct VertexOut {
    @builtin(position) pos : vec4<f32>,
};

@vertex
fn main_vs(@builtin(vertex_index) vid : u32) -> VertexOut {
    var xy : vec2<f32>;
    if (vid == 0u) {
        xy = vec2<f32>(-1.0, -3.0);
    } else if (vid == 1u) {
        xy = vec2<f32>( 3.0,  1.0);
    } else {
        xy = vec2<f32>(-1.0,  1.0);
    }
    var o : VertexOut;
    o.pos = vec4<f32>(xy, 0.0, 1.0);
    return o;
}

// Safe constraint-compliant cube rendering
fn renderCubeConstraintCompliant(uv: vec2<f32>, time: f32) -> f32 {
    // Rotation matrices
    let rotX = time * 0.5;
    let rotY = time * 0.3;
    
    let cosX = cos(rotX);
    let sinX = sin(rotX);
    let cosY = cos(rotY);
    let sinY = sin(rotY);
    
    let rotMatX = mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, cosX, -sinX),
        vec3<f32>(0.0, sinX, cosX)
    );
    
    let rotMatY = mat3x3<f32>(
        vec3<f32>(cosY, 0.0, sinY),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-sinY, 0.0, cosY)
    );
    
    let rot = rotMatY * rotMatX;
    
    // CONSTRAINT-COMPLIANT: Explicit vertex handling instead of array indexing
    let v0 = rot * vec3<f32>(-1.0, -1.0, -1.0);
    let v1 = rot * vec3<f32>( 1.0, -1.0, -1.0);
    let v2 = rot * vec3<f32>( 1.0,  1.0, -1.0);
    let v3 = rot * vec3<f32>(-1.0,  1.0, -1.0);
    let v4 = rot * vec3<f32>(-1.0, -1.0,  1.0);
    let v5 = rot * vec3<f32>( 1.0, -1.0,  1.0);
    let v6 = rot * vec3<f32>( 1.0,  1.0,  1.0);
    let v7 = rot * vec3<f32>(-1.0,  1.0,  1.0);
    
    // Project to 2D
    let p0 = v0.xy * 0.4;
    let p1 = v1.xy * 0.4;
    let p2 = v2.xy * 0.4;
    let p3 = v3.xy * 0.4;
    let p4 = v4.xy * 0.4;
    let p5 = v5.xy * 0.4;
    let p6 = v6.xy * 0.4;
    let p7 = v7.xy * 0.4;
    
    // Distance to edges - explicit enumeration instead of loops
    var minDist = 1000.0;
    minDist = min(minDist, distanceToLine(uv, p0, p1));
    minDist = min(minDist, distanceToLine(uv, p1, p2));
    minDist = min(minDist, distanceToLine(uv, p2, p3));
    minDist = min(minDist, distanceToLine(uv, p3, p0));
    minDist = min(minDist, distanceToLine(uv, p4, p5));
    minDist = min(minDist, distanceToLine(uv, p5, p6));
    minDist = min(minDist, distanceToLine(uv, p6, p7));
    minDist = min(minDist, distanceToLine(uv, p7, p4));
    minDist = min(minDist, distanceToLine(uv, p0, p4));
    minDist = min(minDist, distanceToLine(uv, p1, p5));
    minDist = min(minDist, distanceToLine(uv, p2, p6));
    minDist = min(minDist, distanceToLine(uv, p3, p7));
    
    return minDist;
}

fn distanceToLine(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

@fragment
fn main_fs(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    // Convert screen coordinates to normalized coordinates
    let uv = (pos.xy - 512.0) / 512.0;
    
    // Simple time simulation
    let time = length(uv) * 10.0;
    
    // Test constraint-compliant cube rendering
    let cubeDistance = renderCubeConstraintCompliant(uv, time);
    
    // Colors
    let cubeColor = vec3<f32>(0.0, 0.4, 0.8);  // Blue
    let backgroundColor = vec3<f32>(0.1, 0.1, 0.1);  // Dark gray
    
    // Anti-aliased edge
    let lineWidth = 0.005;
    let alpha = 1.0 - smoothstep(0.0, lineWidth, cubeDistance);
    let finalColor = mix(backgroundColor, cubeColor, alpha);
    
    return vec4<f32>(finalColor, 1.0);
}