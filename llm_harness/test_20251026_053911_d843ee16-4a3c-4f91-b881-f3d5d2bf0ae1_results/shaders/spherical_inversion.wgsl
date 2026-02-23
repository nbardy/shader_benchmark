// Spherical Inversion Visualization
// Renders a 3D grid with spherical inversion transformation

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

// Ray-sphere intersection returns (t_near, t_far)
fn raySphere(ro: vec3<f32>, rd: vec3<f32>, center: vec3<f32>, radius: f32) -> vec2<f32> {
    let oc = ro - center;
    let a = dot(rd, rd);
    let b = 2.0 * dot(oc, rd);
    let c = dot(oc, oc) - radius * radius;
    let discriminant = b * b - 4.0 * a * c;
    
    if (discriminant < 0.0) {
        return vec2<f32>(1e10, 1e10);
    }
    
    let sqrtD = sqrt(discriminant);
    let t1 = (-b - sqrtD) / (2.0 * a);
    let t2 = (-b + sqrtD) / (2.0 * a);
    return vec2<f32>(t1, t2);
}

// Ray-cylinder intersection (cylinder axis along Y)
fn rayCylinderY(ro: vec3<f32>, rd: vec3<f32>, center: vec3<f32>, radius: f32, height: f32) -> f32 {
    let oc = ro - center;
    
    let a = rd.x * rd.x + rd.z * rd.z;
    let b = 2.0 * (oc.x * rd.x + oc.z * rd.z);
    let c = oc.x * oc.x + oc.z * oc.z - radius * radius;
    
    let disc = b * b - 4.0 * a * c;
    if (disc < 0.0) {
        return 1e10;
    }
    
    let sqrtD = sqrt(disc);
    let t = (-b - sqrtD) / (2.0 * a);
    
    if (t < 0.01) {
        return 1e10;
    }
    
    let hitY = oc.y + rd.y * t;
    if (abs(hitY) > height * 0.5) {
        return 1e10;
    }
    
    return t;
}

// Spherical inversion: p' = (R^2 / |p|^2) * p
fn sphericalInversion(p: vec3<f32>, invRadius: f32) -> vec3<f32> {
    let distSq = dot(p, p);
    if (distSq < 0.001) {
        return p * 100.0;
    }
    return (invRadius * invRadius / distSq) * p;
}

// Color based on distance from origin
fn colorByDistance(p: vec3<f32>, inverted: bool) -> vec3<f32> {
    let dist = length(p);
    let t = clamp(dist / 5.0, 0.0, 1.0);
    
    if (inverted) {
        return mix(vec3<f32>(1.0, 0.1, 0.0), vec3<f32>(1.0, 1.0, 0.2), t);
    } else {
        return mix(vec3<f32>(0.9, 0.9, 1.0), vec3<f32>(0.1, 0.2, 0.8), t);
    }
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    let fragCoord = (uv - vec2<f32>(0.5)) * vec2<f32>(aspect, 1.0);
    
    // Camera setup: position (5, 4, 3), target (0, 0, 0), FOV 40°
    let cameraPos = vec3<f32>(5.0, 4.0, 3.0);
    let cameraTarget = vec3<f32>(0.0, 0.0, 0.0);
    let cameraUp = normalize(vec3<f32>(0.0, 1.0, 0.0));
    
    let cameraZ = normalize(cameraTarget - cameraPos);
    let cameraX = normalize(cross(cameraZ, cameraUp));
    let cameraY = cross(cameraX, cameraZ);
    
    let fov = 40.0 * 3.14159 / 180.0;
    let tanHalfFov = tan(fov * 0.5);
    let rayDir = normalize(
        cameraX * fragCoord.x * tanHalfFov + 
        cameraY * fragCoord.y * tanHalfFov + 
        cameraZ
    );
    
    // Background: deep black with subtle blue gradient
    var finalColor = vec3<f32>(0.01, 0.02, 0.08) + vec3<f32>(0.01, 0.03, 0.08) * uv.y * 0.3;
    
    let spacing = 0.4;
    let gridSize = 11u;
    let gridHalf = 5.0 * spacing;
    
    var minDist = 1e10;
    var bestColor = finalColor;
    var bestGlow = 0.0;
    
    // Trace grid cylinders (limited iteration for performance)
    for (var i = 0u; i < gridSize; i = i + 1u) {
        let x = f32(i) * spacing - gridHalf;
        
        for (var j = 0u; j < gridSize; j = j + 1u) {
            let y = f32(j) * spacing - gridHalf;
            
            for (var k = 0u; k < gridSize; k = k + 1u) {
                let z = f32(k) * spacing - gridHalf;
                let gridPos = vec3<f32>(x, y, z);
                
                // Original grid cylinders (Y-axis aligned)
                let t1 = rayCylinderY(cameraPos, rayDir, gridPos, 0.015, spacing * 0.2);
                if (t1 < minDist && t1 > 0.01) {
                    minDist = t1;
                    bestColor = colorByDistance(gridPos, false);
                    bestGlow = 0.0;
                }
                
                // Inverted grid cylinders
                let invPos = sphericalInversion(gridPos, 2.0);
                let t2 = rayCylinderY(cameraPos, rayDir, invPos, 0.015, spacing * 0.2);
                if (t2 < minDist && t2 > 0.01) {
                    minDist = t2;
                    bestColor = colorByDistance(gridPos, true);
                    bestGlow = 0.4;
                }
            }
        }
    }
    
    // Render inversion sphere (wireframe effect)
    let sphereHit = raySphere(cameraPos, rayDir, vec3<f32>(0.0), 2.0);
    if (sphereHit.x > 0.01 && sphereHit.x < minDist) {
        let hitPos = cameraPos + rayDir * sphereHit.x;
        let normal = normalize(hitPos);
        
        // Create wireframe pattern using latitude/longitude
        let phi = atan2(normal.z, normal.x);
        let theta = acos(clamp(normal.y, -1.0, 1.0));
        
        let wireX = abs(sin(phi * 8.0));
        let wireY = abs(sin(theta * 8.0));
        let wirePattern = select(0.0, 1.0, (wireX > 0.7) || (wireY > 0.7));
        
        if (wirePattern > 0.5) {
            finalColor = mix(finalColor, vec3<f32>(1.0, 1.0, 1.0), 0.3);
            minDist = sphereHit.x;
            bestGlow = 0.0;
        }
    }
    
    // Apply closest hit
    if (minDist < 1e9) {
        finalColor = bestColor;
        
        // Add glow to inverted elements
        if (bestGlow > 0.0) {
            let glowIntensity = bestGlow * (1.0 - clamp(minDist * 0.15, 0.0, 1.0));
            finalColor = finalColor + vec3<f32>(0.4, 0.2, 0.1) * glowIntensity;
        }
        
        // Ambient occlusion effect
        let aoFactor = 1.0 - minDist * 0.08;
        finalColor = finalColor * clamp(aoFactor, 0.3, 1.0);
    }
    
    // Vignette
    let vignetteUv = uv - vec2<f32>(0.5);
    let vignette = 1.0 - (vignetteUv.x * vignetteUv.x + vignetteUv.y * vignetteUv.y) * 0.6;
    finalColor = finalColor * vignette;
    
    // Clamp to valid range
    finalColor = clamp(finalColor, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(finalColor, 1.0);
}