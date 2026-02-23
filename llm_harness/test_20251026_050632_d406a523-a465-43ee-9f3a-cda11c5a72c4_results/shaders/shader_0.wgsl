// Apollonius's Conic Sections - Ancient Greek Mathematical Visualization
// A shader honoring Apollonius of Perga's revolutionary treatise "Conics" (~200 BCE)

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
};

@group(0) @binding(0) var<uniform> params: Params;

// Helper: Distance from point to line segment in 3D
fn distanceToLineSegment3D(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / (dot(ba, ba) + 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

// Helper: Distance from point to plane
fn distanceToPlane(p: vec3<f32>, planePos: vec3<f32>, planeNormal: vec3<f32>) -> f32 {
    return abs(dot(p - planePos, normalize(planeNormal)));
}

// Helper: Project 3D point to screen using orthographic projection
fn project3D(p: vec3<f32>, scale: f32) -> vec2<f32> {
    let rotY = 0.5;
    let rotX = 0.3;
    let cosY = cos(rotY);
    let sinY = sin(rotY);
    let cosX = cos(rotX);
    let sinX = sin(rotX);
    
    var rotated = p;
    rotated = vec3<f32>(
        rotated.x * cosY - rotated.z * sinY,
        rotated.y,
        rotated.x * sinY + rotated.z * cosY
    );
    rotated = vec3<f32>(
        rotated.x,
        rotated.y * cosX - rotated.z * sinX,
        rotated.y * sinX + rotated.z * cosX
    );
    
    return rotated.xy * scale;
}

// Helper: Check if point is on the double cone surface
fn isOnCone(p: vec3<f32>) -> f32 {
    let coneAngle = 0.5;  // 30 degrees in radians (~0.524)
    let r = length(p.xy);
    let z_abs = abs(p.z);
    let expected_r = z_abs * coneAngle;
    let diff = abs(r - expected_r);
    return smoothstep(0.08, 0.0, diff);
}

// Helper: Check if point is on cutting plane (Ellipse: 45 degrees)
fn isOnEllipsePlane(p: vec3<f32>) -> f32 {
    let planeNormal = normalize(vec3<f32>(1.0, 0.0, 1.0));  // 45 degree angle
    let planePos = vec3<f32>(0.0, 0.0, 0.5);
    let dist = distanceToPlane(p, planePos, planeNormal);
    return smoothstep(0.06, 0.0, dist);
}

// Helper: Check if point is on cutting plane (Parabola: parallel to generator, 30 degrees)
fn isOnParabolaPlane(p: vec3<f32>) -> f32 {
    let planeNormal = normalize(vec3<f32>(1.0, 0.0, 0.0));  // Vertical plane
    let planePos = vec3<f32>(0.8, 0.0, 0.0);
    let dist = distanceToPlane(p, planePos, planeNormal);
    return smoothstep(0.06, 0.0, dist);
}

// Helper: Check if point is on cutting plane (Hyperbola: 15 degrees to axis, steeper)
fn isOnHyperbolaPlane(p: vec3<f32>) -> f32 {
    let planeNormal = normalize(vec3<f32>(0.26, 0.0, 1.0));  // ~15 degree angle
    let planePos = vec3<f32>(0.0, 0.0, 0.0);
    let dist = distanceToPlane(p, planePos, planeNormal);
    return smoothstep(0.06, 0.0, dist);
}

// Helper: Approximate intersection curve (Ellipse)
fn ellipseIntersection(p: vec3<f32>) -> f32 {
    let angle = atan2(p.y, p.x);
    let r_ideal = 0.5 * (2.0 + cos(angle * 2.0));
    let r_actual = length(p.xy);
    let diff = abs(r_actual - r_ideal * 0.6);
    
    let onPlane = isOnEllipsePlane(p);
    let onCone = isOnCone(p);
    let curve = smoothstep(0.1, 0.0, diff);
    
    return onPlane * onCone * curve;
}

// Helper: Approximate intersection curve (Parabola)
fn parabolaIntersection(p: vec3<f32>) -> f32 {
    let z = abs(p.z);
    let x = p.x;
    let y = p.y;
    let r = length(p.xy);
    
    // Parabolic shape: y^2 ~ z
    let parabolicShape = length(vec2<f32>(y * y - z, 0.0));
    let curve = smoothstep(0.15, 0.0, parabolicShape);
    
    let onPlane = isOnParabolaPlane(p);
    let onCone = isOnCone(p);
    
    return onPlane * onCone * curve;
}

// Helper: Approximate intersection curve (Hyperbola)
fn hyperbolaIntersection(p: vec3<f32>) -> f32 {
    let x = p.x;
    let z = p.z;
    let y = p.y;
    
    // Hyperbolic shape: x^2 - z^2 ~ constant
    let hyperbolicShape = abs(x * x - z * z - 0.3);
    let curve = smoothstep(0.12, 0.0, hyperbolicShape);
    
    let onPlane = isOnHyperbolaPlane(p);
    let onCone = isOnCone(p);
    
    return onPlane * onCone * curve;
}

// Helper: Render cone wireframe
fn renderConeWireframe(p: vec3<f32>) -> f32 {
    let coneGenerators = 12u;
    let angle = atan2(p.y, p.x);
    
    var minDist = 1000.0;
    for (var i: u32 = 0u; i < coneGenerators; i = i + 1u) {
        let generatorAngle = f32(i) * 6.28318 / f32(coneGenerators);
        let angleDiff = abs(angle - generatorAngle);
        let minAngleDiff = min(angleDiff, 6.28318 - angleDiff);
        let r = length(p.xy);
        let expectedR = abs(p.z) * 0.5;
        let onGenerator = minAngleDiff < 0.15 && abs(r - expectedR) < 0.1;
        minDist = select(minDist, 1.0, onGenerator);
    }
    
    return select(0.0, 1.0, minDist < 0.5);
}

// Helper: Greek letter rendering (simplified)
fn renderGreekAlpha(uv: vec2<f32>) -> f32 {
    let dist = length(uv - vec2<f32>(-0.35, 0.7));
    return smoothstep(0.08, 0.05, dist);
}

fn renderGreekBeta(uv: vec2<f32>) -> f32 {
    let dist = length(uv - vec2<f32>(0.0, 0.7));
    return smoothstep(0.08, 0.05, dist);
}

fn renderGreekGamma(uv: vec2<f32>) -> f32 {
    let dist = length(uv - vec2<f32>(0.35, 0.7));
    return smoothstep(0.08, 0.05, dist);
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Parchment background
    var color = vec3<f32>(0.96, 0.90, 0.80);
    
    // Sample 3D space along ray
    let rayDir = normalize(vec3<f32>(uv, 1.5));
    let rayOrigin = vec3<f32>(0.0, 0.0, -3.0);
    
    var maxIntensity = 0.0;
    var ellipseIntensity = 0.0;
    var parabolaIntensity = 0.0;
    var hyperbolaIntensity = 0.0;
    var coneIntensity = 0.0;
    
    // Ray marching through scene
    for (var t: f32 = 0.0; t < 6.0; t = t + 0.15) {
        let p = rayOrigin + rayDir * t;
        
        // Check intersections
        let ellipse = ellipseIntersection(p);
        let parabola = parabolaIntersection(p);
        let hyperbola = hyperbolaIntersection(p);
        let cone = isOnCone(p) * 0.15;
        
        ellipseIntensity = max(ellipseIntensity, ellipse);
        parabolaIntensity = max(parabolaIntensity, parabola);
        hyperbolaIntensity = max(hyperbolaIntensity, hyperbola);
        coneIntensity = max(coneIntensity, cone);
    }
    
    // Blend results
    color = mix(color, vec3<f32>(0.1, 0.3, 0.7), ellipseIntensity * 0.8);  // Blue ellipse
    color = mix(color, vec3<f32>(0.2, 0.7, 0.3), parabolaIntensity * 0.8);  // Green parabola
    color = mix(color, vec3<f32>(0.8, 0.2, 0.2), hyperbolaIntensity * 0.8);  // Red hyperbola
    color = mix(color, vec3<f32>(0.3, 0.3, 0.3), coneIntensity * 0.6);  // Gray cone
    
    // Add annotations in corner (simplified)
    let cornerUV = uv + vec2<f32>(0.3, -0.3);
    if (length(cornerUV - vec2<f32>(-0.35, 0.0)) < 0.12) {
        color = mix(color, vec3<f32>(0.0, 0.0, 0.0), 0.7);  // α label area
    }
    if (length(cornerUV - vec2<f32>(0.0, 0.0)) < 0.12) {
        color = mix(color, vec3<f32>(0.0, 0.0, 0.0), 0.7);  // β label area
    }
    if (length(cornerUV - vec2<f32>(0.35, 0.0)) < 0.12) {
        color = mix(color, vec3<f32>(0.0, 0.0, 0.0), 0.7);  // γ label area
    }
    
    // Add subtle vignette
    let vignette = 1.0 - length(uv) * 0.3;
    color = color * vignette;
    
    return vec4<f32>(color, 1.0);
}