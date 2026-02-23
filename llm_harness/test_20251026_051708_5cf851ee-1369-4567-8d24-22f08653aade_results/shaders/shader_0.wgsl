// Euler's Polyhedron Formula Visualization (V - E + F = 2)
// A shader celebrating Leonhard Euler's 1752 discovery of topological invariants
// Through interactive rendering of the five Platonic solids with period-accurate styling

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

// Rotation matrix around Z axis
fn rotateZ(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

// Rotation matrix around X axis
fn rotateX(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

// Rotation matrix around Y axis
fn rotateY(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

// Distance from point to line segment
fn distanceToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Render tetrahedron (V=4, E=6, F=4)
fn renderTetrahedron(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let rot = rotateY(time * 0.7) * rotateX(time * 0.5);
    
    let v0 = rot * vec3<f32>( 1.0,  1.0,  1.0) * 0.35;
    let v1 = rot * vec3<f32>( 1.0, -1.0, -1.0) * 0.35;
    let v2 = rot * vec3<f32>(-1.0,  1.0, -1.0) * 0.35;
    let v3 = rot * vec3<f32>(-1.0, -1.0,  1.0) * 0.35;
    
    let p0 = v0.xy * 0.7;
    let p1 = v1.xy * 0.7;
    let p2 = v2.xy * 0.7;
    let p3 = v3.xy * 0.7;
    
    var minDist = 1000.0;
    minDist = min(minDist, distanceToSegment(uv, p0, p1));
    minDist = min(minDist, distanceToSegment(uv, p0, p2));
    minDist = min(minDist, distanceToSegment(uv, p0, p3));
    minDist = min(minDist, distanceToSegment(uv, p1, p2));
    minDist = min(minDist, distanceToSegment(uv, p1, p3));
    minDist = min(minDist, distanceToSegment(uv, p2, p3));
    
    let lineWidth = 0.008;
    let edgeColor = vec3<f32>(0.8, 0.8, 0.8);
    let vertexGlow = smoothstep(0.08, 0.02, distance(uv, p0)) +
                     smoothstep(0.08, 0.02, distance(uv, p1)) +
                     smoothstep(0.08, 0.02, distance(uv, p2)) +
                     smoothstep(0.08, 0.02, distance(uv, p3));
    let vertexColor = vec3<f32>(1.0, 0.84, 0.0) * clamp(vertexGlow, 0.0, 1.0);
    
    let edge = 1.0 - smoothstep(0.0, lineWidth, minDist);
    return mix(vec3<f32>(0.0), edgeColor, edge) + vertexColor * 0.3;
}

// Render cube (V=8, E=12, F=6)
fn renderCube(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let rot = rotateY(time * 0.6) * rotateX(time * 0.4);
    
    let v0 = rot * vec3<f32>(-1.0, -1.0, -1.0) * 0.35;
    let v1 = rot * vec3<f32>( 1.0, -1.0, -1.0) * 0.35;
    let v2 = rot * vec3<f32>( 1.0,  1.0, -1.0) * 0.35;
    let v3 = rot * vec3<f32>(-1.0,  1.0, -1.0) * 0.35;
    let v4 = rot * vec3<f32>(-1.0, -1.0,  1.0) * 0.35;
    let v5 = rot * vec3<f32>( 1.0, -1.0,  1.0) * 0.35;
    let v6 = rot * vec3<f32>( 1.0,  1.0,  1.0) * 0.35;
    let v7 = rot * vec3<f32>(-1.0,  1.0,  1.0) * 0.35;
    
    let p0 = v0.xy * 0.7;
    let p1 = v1.xy * 0.7;
    let p2 = v2.xy * 0.7;
    let p3 = v3.xy * 0.7;
    let p4 = v4.xy * 0.7;
    let p5 = v5.xy * 0.7;
    let p6 = v6.xy * 0.7;
    let p7 = v7.xy * 0.7;
    
    var minDist = 1000.0;
    minDist = min(minDist, distanceToSegment(uv, p0, p1));
    minDist = min(minDist, distanceToSegment(uv, p1, p2));
    minDist = min(minDist, distanceToSegment(uv, p2, p3));
    minDist = min(minDist, distanceToSegment(uv, p3, p0));
    minDist = min(minDist, distanceToSegment(uv, p4, p5));
    minDist = min(minDist, distanceToSegment(uv, p5, p6));
    minDist = min(minDist, distanceToSegment(uv, p6, p7));
    minDist = min(minDist, distanceToSegment(uv, p7, p4));
    minDist = min(minDist, distanceToSegment(uv, p0, p4));
    minDist = min(minDist, distanceToSegment(uv, p1, p5));
    minDist = min(minDist, distanceToSegment(uv, p2, p6));
    minDist = min(minDist, distanceToSegment(uv, p3, p7));
    
    let lineWidth = 0.008;
    let edgeColor = vec3<f32>(0.8, 0.8, 0.8);
    let vertexGlow = smoothstep(0.08, 0.02, distance(uv, p0)) +
                     smoothstep(0.08, 0.02, distance(uv, p1)) +
                     smoothstep(0.08, 0.02, distance(uv, p2)) +
                     smoothstep(0.08, 0.02, distance(uv, p3)) +
                     smoothstep(0.08, 0.02, distance(uv, p4)) +
                     smoothstep(0.08, 0.02, distance(uv, p5)) +
                     smoothstep(0.08, 0.02, distance(uv, p6)) +
                     smoothstep(0.08, 0.02, distance(uv, p7));
    let vertexColor = vec3<f32>(1.0, 0.84, 0.0) * clamp(vertexGlow, 0.0, 1.0);
    
    let edge = 1.0 - smoothstep(0.0, lineWidth, minDist);
    return mix(vec3<f32>(0.0), edgeColor, edge) + vertexColor * 0.3;
}

// Render octahedron (V=6, E=12, F=8)
fn renderOctahedron(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let rot = rotateY(time * 0.65) * rotateX(time * 0.45);
    
    let v0 = rot * vec3<f32>( 1.0,  0.0,  0.0) * 0.35;
    let v1 = rot * vec3<f32>(-1.0,  0.0,  0.0) * 0.35;
    let v2 = rot * vec3<f32>( 0.0,  1.0,  0.0) * 0.35;
    let v3 = rot * vec3<f32>( 0.0, -1.0,  0.0) * 0.35;
    let v4 = rot * vec3<f32>( 0.0,  0.0,  1.0) * 0.35;
    let v5 = rot * vec3<f32>( 0.0,  0.0, -1.0) * 0.35;
    
    let p0 = v0.xy * 0.7;
    let p1 = v1.xy * 0.7;
    let p2 = v2.xy * 0.7;
    let p3 = v3.xy * 0.7;
    let p4 = v4.xy * 0.7;
    let p5 = v5.xy * 0.7;
    
    var minDist = 1000.0;
    minDist = min(minDist, distanceToSegment(uv, p0, p2));
    minDist = min(minDist, distanceToSegment(uv, p0, p3));
    minDist = min(minDist, distanceToSegment(uv, p0, p4));
    minDist = min(minDist, distanceToSegment(uv, p0, p5));
    minDist = min(minDist, distanceToSegment(uv, p1, p2));
    minDist = min(minDist, distanceToSegment(uv, p1, p3));
    minDist = min(minDist, distanceToSegment(uv, p1, p4));
    minDist = min(minDist, distanceToSegment(uv, p1, p5));
    minDist = min(minDist, distanceToSegment(uv, p2, p4));
    minDist = min(minDist, distanceToSegment(uv, p2, p5));
    minDist = min(minDist, distanceToSegment(uv, p3, p4));
    minDist = min(minDist, distanceToSegment(uv, p3, p5));
    
    let lineWidth = 0.008;
    let edgeColor = vec3<f32>(0.8, 0.8, 0.8);
    let vertexGlow = smoothstep(0.08, 0.02, distance(uv, p0)) +
                     smoothstep(0.08, 0.02, distance(uv, p1)) +
                     smoothstep(0.08, 0.02, distance(uv, p2)) +
                     smoothstep(0.08, 0.02, distance(uv, p3)) +
                     smoothstep(0.08, 0.02, distance(uv, p4)) +
                     smoothstep(0.08, 0.02, distance(uv, p5));
    let vertexColor = vec3<f32>(1.0, 0.84, 0.0) * clamp(vertexGlow, 0.0, 1.0);
    
    let edge = 1.0 - smoothstep(0.0, lineWidth, minDist);
    return mix(vec3<f32>(0.0), edgeColor, edge) + vertexColor * 0.3;
}

// Render dodecahedron (V=20, E=30, F=12) - simplified icosahedron-like
fn renderDodecahedron(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let rot = rotateY(time * 0.55) * rotateX(time * 0.35);
    let phi = (1.0 + sqrt(5.0)) * 0.5;
    
    let v0 = rot * vec3<f32>( 1.0,  1.0,  1.0) * 0.25;
    let v1 = rot * vec3<f32>(-1.0,  1.0,  1.0) * 0.25;
    let v2 = rot * vec3<f32>( 1.0, -1.0,  1.0) * 0.25;
    let v3 = rot * vec3<f32>(-1.0, -1.0,  1.0) * 0.25;
    let v4 = rot * vec3<f32>( 1.0,  1.0, -1.0) * 0.25;
    let v5 = rot * vec3<f32>(-1.0,  1.0, -1.0) * 0.25;
    let v6 = rot * vec3<f32>( 1.0, -1.0, -1.0) * 0.25;
    let v7 = rot * vec3<f32>(-1.0, -1.0, -1.0) * 0.25;
    
    let v8 = rot * vec3<f32>( 0.0,  phi,  1.0/phi) * 0.25;
    let v9 = rot * vec3<f32>( 0.0, -phi,  1.0/phi) * 0.25;
    
    let p0 = v0.xy * 0.7;
    let p1 = v1.xy * 0.7;
    let p2 = v2.xy * 0.7;
    let p3 = v3.xy * 0.7;
    let p4 = v4.xy * 0.7;
    let p5 = v5.xy * 0.7;
    let p6 = v6.xy * 0.7;
    let p7 = v7.xy * 0.7;
    let p8 = v8.xy * 0.7;
    let p9 = v9.xy * 0.7;
    
    var minDist = 1000.0;
    minDist = min(minDist, distanceToSegment(uv, p0, p1));
    minDist = min(minDist, distanceToSegment(uv, p0, p2));
    minDist = min(minDist, distanceToSegment(uv, p0, p4));
    minDist = min(minDist, distanceToSegment(uv, p0, p8));
    minDist = min(minDist, distanceToSegment(uv, p1, p3));
    minDist = min(minDist, distanceToSegment(uv, p1, p5));
    minDist = min(minDist, distanceToSegment(uv, p2, p6));
    minDist = min(minDist, distanceToSegment(uv, p2, p9));
    minDist = min(minDist, distanceToSegment(uv, p3, p5));
    minDist = min(minDist, distanceToSegment(uv, p4, p5));
    minDist = min(minDist, distanceToSegment(uv, p4, p6));
    minDist = min(minDist, distanceToSegment(uv, p6, p7));
    
    let lineWidth = 0.008;
    let edgeColor = vec3<f32>(0.8, 0.8, 0.8);
    let vertexGlow = smoothstep(0.08, 0.02, distance(uv, p0)) +
                     smoothstep(0.08, 0.02, distance(uv, p1)) +
                     smoothstep(0.08, 0.02, distance(uv, p2)) +
                     smoothstep(0.08, 0.02, distance(uv, p3)) +
                     smoothstep(0.08, 0.02, distance(uv, p4)) +
                     smoothstep(0.08, 0.02, distance(uv, p5));
    let vertexColor = vec3<f32>(1.0, 0.84, 0.0) * clamp(vertexGlow, 0.0, 1.0);
    
    let edge = 1.0 - smoothstep(0.0, lineWidth, minDist);
    return mix(vec3<f32>(0.0), edgeColor, edge) + vertexColor * 0.3;
}

// Render icosahedron (V=12, E=30, F=20)
fn renderIcosahedron(uv: vec2<f32>, time: f32) -> vec3<f32> {
    let rot = rotateY(time * 0.75) * rotateX(time * 0.55);
    let phi = (1.0 + sqrt(5.0)) * 0.5;
    
    let v0 = rot * vec3<f32>(-1.0,  phi, 0.0) * 0.25;
    let v1 = rot * vec3<f32>( 1.0,  phi, 0.0) * 0.25;
    let v2 = rot * vec3<f32>(-1.0, -phi, 0.0) * 0.25;
    let v3 = rot * vec3<f32>( 1.0, -phi, 0.0) * 0.25;
    let v4 = rot * vec3<f32>( 0.0, -1.0,  phi) * 0.25;
    let v5 = rot * vec3<f32>( 0.0,  1.0,  phi) * 0.25;
    let v6 = rot * vec3<f32>( 0.0, -1.0, -phi) * 0.25;
    let v7 = rot * vec3<f32>( 0.0,  1.0, -phi) * 0.25;
    let v8 = rot * vec3<f32>( phi,  0.0, -1.0) * 0.25;
    let v9 = rot * vec3<f32>( phi,  0.0,  1.0) * 0.25;
    let v10 = rot * vec3<f32>(-phi,  0.0, -1.0) * 0.25;
    let v11 = rot * vec3<f32>(-phi,  0.0,  1.0) * 0.25;
    
    let p0 = v0.xy * 0.7;
    let p1 = v1.xy * 0.7;
    let p2 = v2.xy * 0.7;
    let p3 = v3.xy * 0.7;
    let p4 = v4.xy * 0.7;
    let p5 = v5.xy * 0.7;
    let p6 = v6.xy * 0.7;
    let p7 = v7.xy * 0.7;
    let p8 = v8.xy * 0.7;
    let p9 = v9.xy * 0.7;
    let p10 = v10.xy * 0.7;
    let p11 = v11.xy * 0.7;
    
    var minDist = 1000.0;
    minDist = min(minDist, distanceToSegment(uv, p0, p1));
    minDist = min(minDist, distanceToSegment(uv, p0, p5));
    minDist = min(minDist, distanceToSegment(uv, p0, p7));
    minDist = min(minDist, distanceToSegment(uv, p0, p10));
    minDist = min(minDist, distanceToSegment(uv, p0, p11));
    minDist = min(minDist, distanceToSegment(uv, p1, p5));
    minDist = min(minDist, distanceToSegment(uv, p1, p8));
    minDist = min(minDist, distanceToSegment(uv, p1, p9));
    minDist = min(minDist, distanceToSegment(uv, p2, p3));
    minDist = min(minDist, distanceToSegment(uv, p2, p4));
    minDist = min(minDist, distanceToSegment(uv, p2, p6));
    minDist = min(minDist, distanceToSegment(uv, p3, p4));
    minDist = min(minDist, distanceToSegment(uv, p3, p9));
    minDist = min(minDist, distanceToSegment(uv, p4, p5));
    minDist = min(minDist, distanceToSegment(uv, p6, p7));
    minDist = min(minDist, distanceToSegment(uv, p6, p8));
    minDist = min(minDist, distanceToSegment(uv, p6, p10));
    minDist = min(minDist, distanceToSegment(uv, p7, p8));
    minDist = min(minDist, distanceToSegment(uv, p7, p10));
    minDist = min(minDist, distanceToSegment(uv, p8, p9));
    
    let lineWidth = 0.008;
    let edgeColor = vec3<f32>(0.8, 0.8, 0.8);
    let vertexGlow = smoothstep(0.08, 0.02, distance(uv, p0)) +
                     smoothstep(0.08, 0.02, distance(uv, p1)) +
                     smoothstep(0.08, 0.02, distance(uv, p2)) +
                     smoothstep(0.08, 0.02, distance(uv, p3)) +
                     smoothstep(0.08, 0.02, distance(uv, p4)) +
                     smoothstep(0.08, 0.02, distance(uv, p5)) +
                     smoothstep(0.08, 0.02, distance(uv, p6)) +
                     smoothstep(0.08, 0.02, distance(uv, p7)) +
                     smoothstep(0.08, 0.02, distance(uv, p8)) +
                     smoothstep(0.08, 0.02, distance(uv, p9)) +
                     smoothstep(0.08, 0.02, distance(uv, p10)) +
                     smoothstep(0.08, 0.02, distance(uv, p11));
    let vertexColor = vec3<f32>(1.0, 0.84, 0.0) * clamp(vertexGlow, 0.0, 1.0);
    
    let edge = 1.0 - smoothstep(0.0, lineWidth, minDist);
    return mix(vec3<f32>(0.0), edgeColor, edge) + vertexColor * 0.3;
}

// Render Euler formula text visualization
fn renderFormulaDisplay(uv: vec2<f32>, cycleTime: f32) -> vec3<f32> {
    let centerY = -0.55;
    let textDist = distance(uv, vec2<f32>(0.0, centerY));
    let glow = exp(-textDist * textDist * 8.0) * 0.4;
    return vec3<f32>(1.0, 0.9, 0.7) * glow;
}

// Render formula data for each polyhedron
fn renderFormulaData(uv: vec2<f32>, solidsIndex: u32, cycleTime: f32) -> vec3<f32> {
    let baseColor = vec3<f32>(0.3, 0.4, 0.6);
    let highlightColor = vec3<f32>(1.0, 0.8, 0.2);
    
    var yOffset = 0.4;
    let ySpacing = 0.22;
    
    if (solidsIndex == 0u) {
        yOffset = yOffset - 0.0 * ySpacing;
    } else if (solidsIndex == 1u) {
        yOffset = yOffset - 1.0 * ySpacing;
    } else if (solidsIndex == 2u) {
        yOffset = yOffset - 2.0 * ySpacing;
    } else if (solidsIndex == 3u) {
        yOffset = yOffset - 3.0 * ySpacing;
    } else {
        yOffset = yOffset - 4.0 * ySpacing;
    }
    
    let textDist = distance(uv, vec2<f32>(0.0, yOffset));
    let glow = exp(-textDist * textDist * 15.0);
    return mix(baseColor, highlightColor, glow) * 0.5;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let time = params.time;
    
    // Normalize coordinates with proper aspect ratio
    let uv = (pos.xy - resolution * 0.5) / min(resolution.x, resolution.y);
    
    // Aged paper background
    let paperColor = vec3<f32>(0.98, 0.96, 0.90);
    var color = paperColor;
    
    // Add subtle paper texture
    let paperTexture = sin(uv.x * 50.0) * sin(uv.y * 50.0) * 0.01;
    color = color - paperTexture;
    
    // Calculate cycle phase (0-1) in 15 seconds, but we'll subdivide for clarity
    let cycleTime = (time % 15.0) / 15.0;
    
    // Position offset for circular arrangement
    let angle1 = cycleTime * 6.28318530718 + 0.0;
    let angle2 = cycleTime * 6.28318530718 + 1.25663706144;
    let angle3 = cycleTime * 6.28318530718 + 2.51327412288;
    let angle4 = cycleTime * 6.28318530718 + 3.76991118432;
    let angle5 = cycleTime * 6.28318530718 + 5.02654824576;
    
    let radius = 0.5;
    let center1 = vec2<f32>(cos(angle1) * radius, sin(angle1) * radius);
    let center2 = vec2<f32>(cos(angle2) * radius, sin(angle2) * radius);
    let center3 = vec2<f32>(cos(angle3) * radius, sin(angle3) * radius);
    let center4 = vec2<f32>(cos(angle4) * radius, sin(angle4) * radius);
    let center5 = vec2<f32>(cos(angle5) * radius, sin(angle5) * radius);
    
    // Relative coordinates for each polyhedron
    let uv1 = uv - center1;
    let uv2 = uv - center2;
    let uv3 = uv - center3;
    let uv4 = uv - center4;
    let uv5 = uv - center5;
    
    let boundingRadius = 0.25;
    
    // Render each solid if within its region
    if (distance(uv, center1) < boundingRadius) {
        let solid = renderTetrahedron(uv1, time);
        color = mix(color, solid, 0.8);
    } else if (distance(uv, center2) < boundingRadius) {
        let solid = renderCube(uv2, time);
        color = mix(color, solid, 0.8);
    } else if (distance(uv, center3) < boundingRadius) {
        let solid = renderOctahedron(uv3, time);
        color = mix(color, solid, 0.8);
    } else if (distance(uv, center4) < boundingRadius) {
        let solid = renderDodecahedron(uv4, time);
        color = mix(color, solid, 0.8);
    } else if (distance(uv, center5) < boundingRadius) {
        let solid = renderIcosahedron(uv5, time);
        color = mix(color, solid, 0.8);
    }
    
    // Central Euler formula display
    let centralFormula = renderFormulaDisplay(uv, cycleTime);
    color = color + centralFormula;
    
    // Add decorative border
    let distFromEdge = min(
        min(abs(uv.x) - 1.0, abs(uv.y) - 1.0),
        min(1.0 - abs(uv.x), 1.0 - abs(uv.y))
    );
    let border = smoothstep(-0.02, 0.0, distFromEdge);
    let borderColor = vec3<f32>(0.7, 0.6, 0.5);
    color = mix(color, borderColor, (1.0 - border) * 0.3);
    
    // Soft vignette suggesting candlelight
    let vignette = smoothstep(1.5, 0.5, length(uv));
    color = color * (0.6 + vignette * 0.4);
    
    return vec4<f32>(color, 1.0);
}