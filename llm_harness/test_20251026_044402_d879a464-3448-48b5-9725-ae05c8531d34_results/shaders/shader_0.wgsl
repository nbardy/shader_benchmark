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
fn distanceToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * t);
}

// Rotation matrix around X axis
fn rotX(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

// Rotation matrix around Z axis
fn rotZ(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize to [-1, 1] range, accounting for aspect ratio
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Camera parameters: elevated view from upper-right, looking down at cube corner
    // ~45° elevation, ~30° azimuth
    let elevationAngle = 0.785398; // ~45 degrees
    let azimuthAngle = 0.523599;   // ~30 degrees
    
    // Combine rotations: first rotate around Z for azimuth, then around X for elevation
    let rotAzimuth = rotZ(azimuthAngle);
    let rotElevation = rotX(elevationAngle);
    let rotation = rotElevation * rotAzimuth;
    
    // Cube vertices (side = 2, centered at origin)
    let v0 = rotation * vec3<f32>(-1.0, -1.0, -1.0);
    let v1 = rotation * vec3<f32>( 1.0, -1.0, -1.0);
    let v2 = rotation * vec3<f32>( 1.0,  1.0, -1.0);
    let v3 = rotation * vec3<f32>(-1.0,  1.0, -1.0);
    let v4 = rotation * vec3<f32>(-1.0, -1.0,  1.0);
    let v5 = rotation * vec3<f32>( 1.0, -1.0,  1.0);
    let v6 = rotation * vec3<f32>( 1.0,  1.0,  1.0);
    let v7 = rotation * vec3<f32>(-1.0,  1.0,  1.0);
    
    // Project to 2D (orthographic)
    let p0 = v0.xy;
    let p1 = v1.xy;
    let p2 = v2.xy;
    let p3 = v3.xy;
    let p4 = v4.xy;
    let p5 = v5.xy;
    let p6 = v6.xy;
    let p7 = v7.xy;
    
    // Z-depths for determining visible edges and dashing
    let z0 = v0.z;
    let z1 = v1.z;
    let z2 = v2.z;
    let z3 = v3.z;
    let z4 = v4.z;
    let z5 = v5.z;
    let z6 = v6.z;
    let z7 = v7.z;
    
    // Calculate distances to all 12 edges
    var distEdges = array<f32, 12>(
        distanceToSegment(uv, p0, p1),  // 0
        distanceToSegment(uv, p1, p2),  // 1
        distanceToSegment(uv, p2, p3),  // 2
        distanceToSegment(uv, p3, p0),  // 3
        distanceToSegment(uv, p4, p5),  // 4
        distanceToSegment(uv, p5, p6),  // 5
        distanceToSegment(uv, p6, p7),  // 6
        distanceToSegment(uv, p7, p4),  // 7
        distanceToSegment(uv, p0, p4),  // 8
        distanceToSegment(uv, p1, p5),  // 9
        distanceToSegment(uv, p2, p6),  // 10
        distanceToSegment(uv, p3, p7)   // 11
    );
    
    // Determine edge visibility (front vs back)
    // Front face z > back face z
    var edgeVisible = array<bool, 12>(
        z0 > -0.9 && z1 > -0.9,  // back bottom
        z1 > -0.9 && z2 > -0.9,  // back right
        z2 > -0.9 && z3 > -0.9,  // back top
        z3 > -0.9 && z0 > -0.9,  // back left
        z4 > -0.9 && z5 > -0.9,  // front bottom
        z5 > -0.9 && z6 > -0.9,  // front right
        z6 > -0.9 && z7 > -0.9,  // front top
        z7 > -0.9 && z4 > -0.9,  // front left
        z0 > -0.9 && z4 > -0.9,  // left vertical
        z1 > -0.9 && z5 > -0.9,  // right-bottom vertical
        z2 > -0.9 && z6 > -0.9,  // right-top vertical
        z3 > -0.9 && z7 > -0.9   // left-top vertical
    );
    
    // Find minimum distance to visible edges (solid lines)
    var minDistVisible = 1000.0;
    for (var i = 0u; i < 12u; i = i + 1u) {
        if (edgeVisible[i]) {
            minDistVisible = min(minDistVisible, distEdges[i]);
        }
    }
    
    // Find minimum distance to hidden edges (for dashing)
    var minDistHidden = 1000.0;
    for (var i = 0u; i < 12u; i = i + 1u) {
        if (!edgeVisible[i]) {
            minDistHidden = min(minDistHidden, distEdges[i]);
        }
    }
    
    // Edge rendering parameters
    let edgeWidth = 0.008;
    let dashPeriod = 0.06;
    
    // Render visible edges (solid midnight-blue)
    let midnightBlue = vec3<f32>(0.0, 0.2, 0.4);
    let visibleAlpha = 1.0 - smoothstep(0.0, edgeWidth, minDistVisible);
    
    // Render hidden edges (dashed)
    let dashPhase = fract((uv.x + uv.y) / dashPeriod);
    let dashVisible = select(0.0, 1.0, dashPhase < 0.5);
    let hiddenAlpha = (1.0 - smoothstep(0.0, edgeWidth, minDistHidden)) * dashVisible * 0.4;
    
    // Combine edge contributions
    let edgeAlpha = max(visibleAlpha, hiddenAlpha);
    let edgeColor = mix(vec3<f32>(0.0), midnightBlue, edgeAlpha);
    
    // Face rendering (semi-transparent sky-blue)
    let skyBlue = vec3<f32>(0.5, 0.8, 1.0);
    let faceAlpha = 0.1;
    
    // Determine if inside cube faces (simplified: check proximity to center)
    let distToCubeFront = abs(uv.x) + abs(uv.y);
    let faceColor = select(vec3<f32>(0.0), skyBlue, distToCubeFront < 1.2);
    
    // Blend: edges over faces
    let finalColor = mix(faceColor * faceAlpha, edgeColor, edgeAlpha);
    
    return vec4<f32>(finalColor, 1.0);
}