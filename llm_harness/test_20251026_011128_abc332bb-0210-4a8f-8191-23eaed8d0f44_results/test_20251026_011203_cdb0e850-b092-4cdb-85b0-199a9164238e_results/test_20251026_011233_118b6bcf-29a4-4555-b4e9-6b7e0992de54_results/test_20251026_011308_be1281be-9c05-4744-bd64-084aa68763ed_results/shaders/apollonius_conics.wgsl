// Apollonius's Conic Sections - Ancient Greek Mathematical Visualization
// A shader honoring the geometric constructions of Apollonius of Perga (~200 BCE)
// Rendering the double cone and three classical conic sections

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

// Parchment background color
fn parchmentColor() -> vec3<f32> {
    return vec3<f32>(0.956, 0.910, 0.816);
}

// Cone angle: 30 degrees from vertical
fn coneAngle() -> f32 {
    return 0.5236;
}

// Check if point is on or inside cone surface
fn distanceToCone(p: vec3<f32>) -> f32 {
    let tanAngle = tan(coneAngle());
    let rho = sqrt(p.x * p.x + p.y * p.y);
    let coneRadius = abs(p.z) * tanAngle;
    return abs(rho - coneRadius);
}

// Distance to ellipse cutting plane (45° to cone axis)
fn distanceToEllipsePlane(p: vec3<f32>) -> f32 {
    let normalizedZ = (p.z + 0.5) * 0.7071;
    let normalizedXY = (p.x * 0.7071 + p.y * 0.0) * 0.5;
    return abs(normalizedZ - normalizedXY);
}

// Distance to parabola cutting plane (30° to cone axis)
fn distanceToParabolaPlane(p: vec3<f32>) -> f32 {
    let tanAngle = tan(coneAngle());
    let planeNormal = normalize(vec3<f32>(tanAngle, 0.0, 1.0));
    let pointToPlane = p - vec3<f32>(0.0, 0.0, 1.5);
    return abs(dot(pointToPlane, planeNormal));
}

// Distance to hyperbola cutting plane (15° to cone axis)
fn distanceToHyperbolaPlane(p: vec3<f32>) -> f32 {
    let angleRad = 0.2618;
    let planeNormal = normalize(vec3<f32>(sin(angleRad), 0.0, cos(angleRad)));
    let pointToPlane = p - vec3<f32>(0.0, 0.0, -1.5);
    return abs(dot(pointToPlane, planeNormal));
}

// Cone generator lines visualization
fn coneGeneratorPattern(p: vec3<f32>) -> f32 {
    let angle = atan2(p.y, p.x);
    let generatorCount = 16.0;
    let generatorPattern = sin(angle * generatorCount * 0.5) * 0.5 + 0.5;
    return generatorPattern;
}

// 3D rotation around Y axis
fn rotateY(p: vec3<f32>, angle: f32) -> vec3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return vec3<f32>(
        p.x * c + p.z * s,
        p.y,
        -p.x * s + p.z * c
    );
}

// Orthographic projection
fn getWorldRay(uv: vec2<f32>) -> vec3<f32> {
    let rotation = params.time * 0.3;
    let aspect = params.resolution.x / params.resolution.y;
    
    let p = vec3<f32>(
        uv.x * aspect * 3.5,
        uv.y * 3.5,
        2.5
    );
    
    return rotateY(p, rotation);
}

// Main fragment shader
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let rayOrigin = vec3<f32>(0.0, 0.0, 0.0);
    let rayDir = normalize(getWorldRay(uv));
    
    var color = parchmentColor();
    
    var t = 0.0;
    var minDist = 1000.0;
    var activeSurface = 0u;
    var surfaceT = 0.0;
    
    for (var step = 0u; step < 64u; step = step + 1u) {
        t = f32(step) * 0.1;
        let p = rayOrigin + rayDir * t;
        
        if (abs(p.z) > 3.5 || length(vec2<f32>(p.x, p.y)) > 4.0) {
            continue;
        }
        
        let distCone = distanceToCone(p);
        let distEllipse = distanceToEllipsePlane(p);
        let distParabola = distanceToParabolaPlane(p);
        let distHyperbola = distanceToHyperbolaPlane(p);
        
        if (distCone < minDist) {
            minDist = distCone;
            activeSurface = 1u;
            surfaceT = t;
        }
        if (distEllipse < minDist * 0.8) {
            minDist = distEllipse;
            activeSurface = 2u;
            surfaceT = t;
        }
        if (distParabola < minDist * 0.8) {
            minDist = distParabola;
            activeSurface = 3u;
            surfaceT = t;
        }
        if (distHyperbola < minDist * 0.8) {
            minDist = distHyperbola;
            activeSurface = 4u;
            surfaceT = t;
        }
    }
    
    let p = rayOrigin + rayDir * surfaceT;
    
    if (activeSurface == 1u && minDist < 0.08) {
        let generatorIntensity = coneGeneratorPattern(p);
        let coneEdge = smoothstep(0.0, 0.03, minDist);
        let coneGray = vec3<f32>(0.3, 0.3, 0.3);
        color = mix(vec3<f32>(0.1, 0.1, 0.1), coneGray, generatorIntensity);
        color = mix(color, parchmentColor(), coneEdge);
    } else if (activeSurface == 2u && minDist < 0.12) {
        let ellipseBlue = vec3<f32>(0.1, 0.2, 0.6);
        let planeTransparency = 1.0 - smoothstep(0.0, 0.1, minDist);
        color = mix(parchmentColor(), ellipseBlue, planeTransparency * 0.5);
        
        if (minDist < 0.02) {
            color = vec3<f32>(0.0, 0.1, 0.9);
        }
    } else if (activeSurface == 3u && minDist < 0.12) {
        let parabolaGreen = vec3<f32>(0.1, 0.6, 0.2);
        let planeTransparency = 1.0 - smoothstep(0.0, 0.1, minDist);
        color = mix(parchmentColor(), parabolaGreen, planeTransparency * 0.5);
        
        if (minDist < 0.02) {
            color = vec3<f32>(0.0, 0.9, 0.1);
        }
    } else if (activeSurface == 4u && minDist < 0.12) {
        let hyperbolaRed = vec3<f32>(0.6, 0.1, 0.1);
        let planeTransparency = 1.0 - smoothstep(0.0, 0.1, minDist);
        color = mix(parchmentColor(), hyperbolaRed, planeTransparency * 0.5);
        
        if (minDist < 0.02) {
            color = vec3<f32>(0.9, 0.0, 0.0);
        }
    }
    
    let depthShading = 1.0 - clamp(surfaceT * 0.15, 0.0, 0.3);
    color = color * depthShading;
    
    let cornerDist = length(uv - vec2<f32>(1.4, 1.4));
    if (cornerDist < 0.15) {
        color = mix(color, vec3<f32>(0.0, 0.2, 0.8), 0.3);
    }
    
    let cornerDist2 = length(uv - vec2<f32>(0.0, 1.4));
    if (cornerDist2 < 0.15) {
        color = mix(color, vec3<f32>(0.1, 0.7, 0.2), 0.3);
    }
    
    let cornerDist3 = length(uv - vec2<f32>(-1.4, 1.4));
    if (cornerDist3 < 0.15) {
        color = mix(color, vec3<f32>(0.8, 0.1, 0.1), 0.3);
    }
    
    return vec4<f32>(color, 1.0);
}