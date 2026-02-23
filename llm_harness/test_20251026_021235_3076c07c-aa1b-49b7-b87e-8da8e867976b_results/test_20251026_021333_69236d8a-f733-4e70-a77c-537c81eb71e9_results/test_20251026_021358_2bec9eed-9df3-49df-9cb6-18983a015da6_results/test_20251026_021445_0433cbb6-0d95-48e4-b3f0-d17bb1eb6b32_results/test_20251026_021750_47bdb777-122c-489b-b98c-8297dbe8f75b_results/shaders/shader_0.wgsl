// Three-strand braided rope with helical geometry
// Strands: #c96 (coral), #6c9 (sage), #96c (lavender)
// Cylinder radius: 0.6, Pitch: 1.8, Tube radius: 0.15

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

// Ray-sphere intersection
fn raySphere(ro: vec3<f32>, rd: vec3<f32>, center: vec3<f32>, radius: f32) -> f32 {
    let oc = ro - center;
    let a = dot(rd, rd);
    let b = 2.0 * dot(oc, rd);
    let c = dot(oc, oc) - radius * radius;
    let disc = b * b - 4.0 * a * c;
    
    if (disc < 0.0) {
        return 1e30;
    }
    
    let t1 = (-b - sqrt(disc)) / (2.0 * a);
    let t2 = (-b + sqrt(disc)) / (2.0 * a);
    
    if (t1 > 0.001) {
        return t1;
    }
    return select(1e30, t2, t2 > 0.001);
}

// Distance from point to line segment
fn distToSegment(p: vec3<f32>, a: vec3<f32>, b: vec3<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

// Signed distance to torus (tube around helix)
fn torusSDF(p: vec3<f32>, center: vec3<f32>, axis: vec3<f32>, majorR: f32, minorR: f32) -> f32 {
    let pc = p - center;
    let proj = dot(pc, axis) * axis;
    let radial = pc - proj;
    let distToAxis = length(radial);
    let distToSurface = abs(distToAxis - majorR) - minorR;
    return distToSurface;
}

// Helix point at parameter t
fn helixPoint(t: f32, phase: f32) -> vec3<f32> {
    let angle = t + phase;
    let x = 0.6 * cos(angle);
    let z = 0.6 * sin(angle);
    let y = t / (2.0 * 3.14159) * 1.8; // pitch = 1.8
    return vec3<f32>(x, y, z);
}

// Helix tangent
fn helixTangent(t: f32, phase: f32) -> vec3<f32> {
    let angle = t + phase;
    let dx = -0.6 * sin(angle);
    let dz = 0.6 * cos(angle);
    let dy = 1.8 / (2.0 * 3.14159);
    return normalize(vec3<f32>(dx, dy, dz));
}

// Distance to helix tube (strand)
fn distToHelix(p: vec3<f32>, phase: f32, samples: i32) -> f32 {
    var minDist = 1e30;
    var prevP = helixPoint(0.0, phase);
    
    for (var i: i32 = 1; i <= samples; i = i + 1) {
        let t = f32(i) * 6.28318 / f32(samples);
        let currP = helixPoint(t, phase);
        let d = distToSegment(p, prevP, currP);
        minDist = min(minDist, d);
        prevP = currP;
    }
    
    return minDist - 0.15; // tube radius = 0.15
}

// Color strand based on phase
fn strandColor(phase: f32) -> vec3<f32> {
    // phase 0 -> #c96, phase 2π/3 -> #6c9, phase 4π/3 -> #96c
    let phaseNorm = (phase % 6.28318) / 6.28318;
    
    if (phaseNorm < 0.34) {
        // #c96 (coral): rgb(204, 153, 102)
        return vec3<f32>(0.8, 0.6, 0.4);
    } else if (phaseNorm < 0.67) {
        // #6c9 (sage): rgb(102, 204, 153)
        return vec3<f32>(0.4, 0.8, 0.6);
    } else {
        // #96c (lavender): rgb(153, 102, 204)
        return vec3<f32>(0.6, 0.4, 0.8);
    }
}

// Find closest strand and its color
fn closestStrand(p: vec3<f32>) -> vec4<f32> {
    let phase0 = 0.0;
    let phase1 = 2.0943; // 2π/3
    let phase2 = 4.1888; // 4π/3
    
    let d0 = distToHelix(p, phase0, 64);
    let d1 = distToHelix(p, phase1, 64);
    let d2 = distToHelix(p, phase2, 64);
    
    let minDist = min(d0, min(d1, d2));
    
    var color = vec3<f32>(0.0);
    if (abs(minDist - d0) < 0.001) {
        color = strandColor(phase0);
    } else if (abs(minDist - d1) < 0.001) {
        color = strandColor(phase1);
    } else {
        color = strandColor(phase2);
    }
    
    return vec4<f32>(color, minDist);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Camera: (3, 2, 2), looking at origin
    let ro = normalize(vec3<f32>(3.0, 2.0, 2.0)) * 2.5;
    let target_var = vec3<f32>(0.0, 0.0, 0.0);
    let fwd = normalize(target_var - ro);
    let right = normalize(cross(fwd, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, fwd);
    
    let rd = normalize(fwd + uv.x * right + uv.y * up);
    
    // Ray march
    var t = 0.1;
    var color = vec3<f32>(0.05, 0.05, 0.08); // dark background
    var hitDist = 1e30;
    
    for (var step: i32 = 0; step < 128; step = step + 1) {
        let p = ro + rd * t;
        
        // Check distance to any strand
        let strandInfo = closestStrand(p);
        let d = strandInfo.w;
        
        if (d < 0.01) {
            // Hit strand
            color = strandInfo.xyz;
            
            // Simple shading
            let normal = normalize(cross(
                closestStrand(p + vec3<f32>(0.01, 0.0, 0.0)).xyz,
                closestStrand(p + vec3<f32>(0.0, 0.01, 0.0)).xyz
            ));
            let light = normalize(vec3<f32>(1.0, 1.0, 1.0));
            let diff = max(0.2, dot(normal, light));
            color = color * (0.6 + 0.4 * diff);
            
            hitDist = t;
            break;
        }
        
        t = t + max(0.01, d * 0.5);
        
        if (t > 20.0) {
            break;
        }
    }
    
    // Fog
    let fogAmount = 1.0 - exp(-t * 0.1);
    color = mix(color, vec3<f32>(0.05, 0.05, 0.08), fogAmount);
    
    return vec4<f32>(color, 1.0);
}