// Apollonius's Conic Sections - Ancient Greek Mathematical Visualization
// Showing ellipse, parabola, and hyperbola emerging from a double cone

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

// Constants
const PI: f32 = 3.14159265359;
const CONE_ANGLE: f32 = 0.5236; // 30 degrees in radians
const PARCHMENT: vec3<f32> = vec3<f32>(0.957, 0.910, 0.816); // #F4E8D0

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

// Distance from point to line segment
fn distToSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Project 3D point to 2D using orthographic projection
fn project(p: vec3<f32>, viewMat: mat3x3<f32>) -> vec2<f32> {
    let rotated = viewMat * p;
    return rotated.xy;
}

// Signed distance to cone surface (for visualization)
fn coneSDF(p: vec3<f32>) -> f32 {
    let tanA = tan(CONE_ANGLE);
    let r = length(p.xy);
    let expectedR = abs(p.z) * tanA;
    return r - expectedR;
}

// Generate point on cone surface
fn conePoint(theta: f32, z: f32) -> vec3<f32> {
    let r = abs(z) * tan(CONE_ANGLE);
    return vec3<f32>(r * cos(theta), r * sin(theta), z);
}

// Ellipse cutting plane intersection (45 degrees to axis)
fn ellipsePlanePoint(t: f32) -> vec3<f32> {
    let planeAngle = 0.785; // 45 degrees
    let a = 1.2;
    let b = 0.8;
    let x = a * cos(t);
    let y = b * sin(t);
    let z = x * tan(planeAngle) - 0.3;
    return vec3<f32>(x, y, z);
}

// Parabola cutting plane intersection (parallel to generator, 30 degrees)
fn parabolaPlanePoint(t: f32) -> vec3<f32> {
    let scale = 0.15;
    let x = t;
    let y = scale * t * t;
    let z = t * 0.8 + 0.5;
    return vec3<f32>(x * 0.6, y - 0.8, z);
}

// Hyperbola cutting plane intersection (15 degrees, steeper than cone)
fn hyperbolaPlanePoint(t: f32, branch: f32) -> vec3<f32> {
    let a = 0.4;
    let b = 0.6;
    let x = a * cosh(t);
    let y = b * sinh(t);
    let z = branch * (x * 0.3 + 1.2);
    return vec3<f32>(x * branch, y, z);
}

fn cosh(x: f32) -> f32 {
    return (exp(x) + exp(-x)) * 0.5;
}

fn sinh(x: f32) -> f32 {
    return (exp(x) - exp(-x)) * 0.5;
}

// Draw anti-aliased line
fn drawLine(uv: vec2<f32>, a: vec2<f32>, b: vec2<f32>, width: f32, color: vec3<f32>, currentColor: vec3<f32>) -> vec3<f32> {
    let d = distToSegment(uv, a, b);
    let alpha = 1.0 - smoothstep(0.0, width, d);
    return mix(currentColor, color, alpha);
}

// Draw anti-aliased point/dot
fn drawDot(uv: vec2<f32>, center: vec2<f32>, radius: f32, color: vec3<f32>, currentColor: vec3<f32>) -> vec3<f32> {
    let d = length(uv - center);
    let alpha = 1.0 - smoothstep(radius - 0.003, radius + 0.003, d);
    return mix(currentColor, color, alpha);
}

// Draw dashed line
fn drawDashedLine(uv: vec2<f32>, a: vec2<f32>, b: vec2<f32>, width: f32, dashLen: f32, color: vec3<f32>, currentColor: vec3<f32>) -> vec3<f32> {
    let pa = uv - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let d = length(pa - ba * h);
    let linePos = h * length(ba);
    let dashPhase = linePos / dashLen;
    let isDash = step(0.5, fract(dashPhase));
    let alpha = (1.0 - smoothstep(0.0, width, d)) * isDash;
    return mix(currentColor, color, alpha);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // View transformation - slight rotation for 3D effect while maintaining diagram clarity
    let viewMat = rotateX(-0.3) * rotateY(0.4);
    
    // Colors following ancient symbolism
    let ellipseColor = vec3<f32>(0.1, 0.2, 0.6);    // Deep blue - celestial
    let parabolaColor = vec3<f32>(0.1, 0.5, 0.2);   // Green - earthly
    let hyperbolaColor = vec3<f32>(0.7, 0.15, 0.1); // Red - infinite
    let coneWireColor = vec3<f32>(0.4, 0.35, 0.3);  // Brown wireframe
    let constructionColor = vec3<f32>(0.6, 0.55, 0.5); // Light construction lines
    let planeAlpha = 0.15;
    
    var color = PARCHMENT;
    
    // Scale factor for the visualization
    let scale = 0.25;
    
    // Draw cone wireframe - generators (straight lines on cone surface)
    let numGenerators = 12;
    for (var i = 0; i < numGenerators; i = i + 1) {
        let theta = f32(i) * 2.0 * PI / f32(numGenerators);
        let topPoint = conePoint(theta, 2.5) * scale;
        let bottomPoint = conePoint(theta, -2.5) * scale;
        let apex = vec3<f32>(0.0, 0.0, 0.0);
        
        let p1 = project(topPoint, viewMat);
        let p2 = project(apex, viewMat);
        let p3 = project(bottomPoint, viewMat);
        
        color = drawLine(uv, p1, p2, 0.002, coneWireColor * 0.7, color);
        color = drawLine(uv, p2, p3, 0.002, coneWireColor * 0.7, color);
    }
    
    // Draw cone circular cross-sections
    let numCirclePoints = 48;
    for (var ring = 0; ring < 5; ring = ring + 1) {
        let z = f32(ring - 2) * 1.0;
        if (abs(z) > 0.1) {
            for (var i = 0; i < numCirclePoints; i = i + 1) {
                let theta1 = f32(i) * 2.0 * PI / f32(numCirclePoints);
                let theta2 = f32(i + 1) * 2.0 * PI / f32(numCirclePoints);
                
                let p1 = project(conePoint(theta1, z) * scale, viewMat);
                let p2 = project(conePoint(theta2, z) * scale, viewMat);
                
                color = drawDashedLine(uv, p1, p2, 0.0015, 0.015, coneWireColor * 0.5, color);
            }
        }
    }
    
    // Draw cone apex
    let apexProj = project(vec3<f32>(0.0, 0.0, 0.0), viewMat);
    color = drawDot(uv, apexProj, 0.008, coneWireColor, color);
    
    // Draw cutting planes as semi-transparent regions
    // Ellipse plane (45 degrees)
    let ellipsePlaneNormal = normalize(vec3<f32>(0.707, 0.0, 0.707));
    let ellipsePlaneD = -0.15;
    
    // Parabola plane (30 degrees - parallel to generator)
    let parabolaPlaneNormal = normalize(vec3<f32>(0.5, 0.0, 0.866));
    let parabolaPlaneD = 0.3;
    
    // Hyperbola plane (15 degrees)
    let hyperbolaPlaneNormal = normalize(vec3<f32>(0.259, 0.0, 0.966));
    let hyperbolaPlaneD = 0.0;
    
    // Draw the conic section curves with bold strokes
    let curveWidth = 0.006;
    let numCurvePoints = 64;
    
    // ELLIPSE - bold blue curve
    for (var i = 0; i < numCurvePoints; i = i + 1) {
        let t1 = f32(i) * 2.0 * PI / f32(numCurvePoints);
        let t2 = f32(i + 1) * 2.0 * PI / f32(numCurvePoints);
        
        let ep1 = ellipsePlanePoint(t1) * scale;
        let ep2 = ellipsePlanePoint(t2) * scale;
        
        let p1 = project(ep1, viewMat);
        let p2 = project(ep2, viewMat);
        
        color = drawLine(uv, p1, p2, curveWidth, ellipseColor, color);
    }
    
    // PARABOLA - bold green curve
    for (var i = 0; i < numCurvePoints; i = i + 1) {
        let t1 = (f32(i) / f32(numCurvePoints) - 0.5) * 4.0;
        let t2 = (f32(i + 1) / f32(numCurvePoints) - 0.5) * 4.0;
        
        let pp1 = parabolaPlanePoint(t1) * scale;
        let pp2 = parabolaPlanePoint(t2) * scale;
        
        let p1 = project(pp1, viewMat);
        let p2 = project(pp2, viewMat);
        
        color = drawLine(uv, p1, p2, curveWidth, parabolaColor, color);
    }
    
    // HYPERBOLA - bold red curves (two branches)
    for (var i = 0; i < numCurvePoints; i = i + 1) {
        let t1 = (f32(i) / f32(numCurvePoints) - 0.5) * 3.0;
        let t2 = (f32(i + 1) / f32(numCurvePoints) - 0.5) * 3.0;
        
        // Upper branch
        let hp1u = hyperbolaPlanePoint(t1, 1.0) * scale;
        let hp2u = hyperbolaPlanePoint(t2, 1.0) * scale;
        let p1u = project(hp1u, viewMat);
        let p2u = project(hp2u, viewMat);
        color = drawLine(uv, p1u, p2u, curveWidth, hyperbolaColor, color);
        
        // Lower branch
        let hp1l = hyperbolaPlanePoint(t1, -1.0) * scale;
        let hp2l = hyperbolaPlanePoint(t2, -1.0) * scale;
        let p1l = project(hp1l, viewMat);
        let p2l = project(hp2l, viewMat);
        color = drawLine(uv, p1l, p2l, curveWidth, hyperbolaColor, color);
    }
    
    // Draw axis line (cone axis)
    let axisTop = project(vec3<f32>(0.0, 0.0, 2.8) * scale, viewMat);
    let axisBottom = project(vec3<f32>(0.0, 0.0, -2.8) * scale, viewMat);
    color = drawDashedLine(uv, axisTop, axisBottom, 0.002, 0.02, constructionColor, color);
    
    // Add labels region indicators
    let labelOffset = 0.42;
    
    // Ellipse label position
    let ellipseLabelPos = vec2<f32>(-labelOffset, 0.35);
    let ellipseDist = length(uv - ellipseLabelPos);
    if (ellipseDist < 0.025) {
        color = mix(color, ellipseColor, 0.8);
    }
    
    // Parabola label position  
    let parabolaLabelPos = vec2<f32>(labelOffset, 0.15);
    let parabolaDist = length(uv - parabolaLabelPos);
    if (parabolaDist < 0.025) {
        color = mix(color, parabolaColor, 0.8);
    }
    
    // Hyperbola label position
    let hyperbolaLabelPos = vec2<f32>(0.0, -0.42);
    let hyperbolaDist = length(uv - hyperbolaLabelPos);
    if (hyperbolaDist < 0.025) {
        color = mix(color, hyperbolaColor, 0.8);
    }
    
    // Draw small inset showing original cone diagram style (bottom right)
    let insetCenter = vec2<f32>(0.35, -0.35);
    let insetSize = 0.12;
    let insetUV = (uv - insetCenter) / insetSize;
    
    if (abs(insetUV.x) < 1.0 && abs(insetUV.y) < 1.0) {
        // Inset background
        let insetBg = PARCHMENT * 0.95;
        color = mix(color, insetBg, 0.9);
        
        // Simple cone outline in ancient style
        let coneLeft = vec2<f32>(-0.5, -0.8);
        let coneRight = vec2<f32>(0.5, -0.8);
        let coneApex = vec2<f32>(0.0, 0.8);
        
        color = drawLine(insetUV, coneLeft, coneApex, 0.03, coneWireColor, color);
        color = drawLine(insetUV, coneRight, coneApex, 0.03, coneWireColor, color);
        color = drawLine(insetUV, coneLeft, coneRight, 0.03, coneWireColor, color);
        
        // Simple cutting line
        let cutLeft = vec2<f32>(-0.6, 0.0);
        let cutRight = vec2<f32>(0.6, 0.3);
        color = drawLine(insetUV, cutLeft, cutRight, 0.025, ellipseColor * 0.8, color);
        
        // Inset border
        let borderDist = max(abs(insetUV.x) - 0.95, abs(insetUV.y) - 0.95);
        if (borderDist > -0.05) {
            color = mix(color, coneWireColor, smoothstep(-0.05, 0.0, borderDist));
        }
    }
    
    // Title area indicator (top)
    let titleY = 0.44;
    if (uv.y > titleY && uv.y < titleY + 0.04) {
        let titleX = abs(uv.x);
        if (titleX < 0.35) {
            color = mix(color, coneWireColor * 0.6, 0.3);
        }
    }
    
    // Angle annotation indicators (Greek letter positions)
    // α for ellipse plane angle
    let alphaPos = vec2<f32>(-0.25, 0.22);
    color = drawDot(uv, alphaPos, 0.012, ellipseColor * 0.7, color);
    
    // β for parabola plane angle  
    let betaPos = vec2<f32>(0.18, 0.08);
    color = drawDot(uv, betaPos, 0.012, parabolaColor * 0.7, color);
    
    // γ for hyperbola plane angle
    let gammaPos = vec2<f32>(0.08, -0.18);
    color = drawDot(uv, gammaPos, 0.012, hyperbolaColor * 0.7, color);
    
    // Add subtle vignette for aged parchment effect
    let vignette = 1.0 - length(uv) * 0.3;
    color = color * vignette;
    
    // Add very subtle paper texture
    let noise = fract(sin(dot(uv * 100.0, vec2<f32>(12.9898, 78.233))) * 43758.5453);
    color = color + (noise - 0.5) * 0.02;
    
    return vec4<f32>(color, 1.0);
}