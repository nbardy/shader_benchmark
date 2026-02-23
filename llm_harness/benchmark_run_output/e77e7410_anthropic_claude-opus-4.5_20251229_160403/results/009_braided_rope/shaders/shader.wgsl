// Three-strand braided rope using helical geometry
// Camera at (3, 2, 2), cylinder radius 0.6, pitch 1.8, tube radius 0.15

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

const PI: f32 = 3.14159265359;
const TWO_PI: f32 = 6.28318530718;

const HELIX_RADIUS: f32 = 0.6;
const HELIX_PITCH: f32 = 1.8;
const TUBE_RADIUS: f32 = 0.15;
const MAX_STEPS: i32 = 128;
const MAX_DIST: f32 = 20.0;
const SURF_DIST: f32 = 0.001;

// Strand colors
fn getStrandColor(strand: i32) -> vec3<f32> {
    if (strand == 0) {
        return vec3<f32>(0.8, 0.6, 0.4); // #c96 approximately
    } else if (strand == 1) {
        return vec3<f32>(0.4, 0.8, 0.6); // #6c9 approximately
    } else {
        return vec3<f32>(0.6, 0.4, 0.8); // #96c approximately
    }
}

// Distance to a single helix strand
fn helixDist(p: vec3<f32>, phaseOffset: f32) -> f32 {
    // Helix parameters
    let k = TWO_PI / HELIX_PITCH;
    
    // Find closest point on helix by iterating
    let theta = atan2(p.x, p.z) + phaseOffset;
    let y_base = p.y;
    
    // Calculate which "turn" we're closest to
    let turn = floor((y_base * k + theta) / TWO_PI);
    
    var minDist = MAX_DIST;
    
    // Check nearby turns
    for (var i: i32 = -1; i <= 1; i = i + 1) {
        let t = (turn + f32(i)) * TWO_PI;
        let angle = t - phaseOffset;
        let hy = angle / k;
        let hx = HELIX_RADIUS * sin(angle);
        let hz = HELIX_RADIUS * cos(angle);
        
        let helixPoint = vec3<f32>(hx, hy, hz);
        let d = length(p - helixPoint) - TUBE_RADIUS;
        minDist = min(minDist, d);
    }
    
    return minDist;
}

// SDF for the three-strand braid
fn braidSDF(p: vec3<f32>) -> vec2<f32> {
    // Phase offsets: 0, 120°, 240°
    let phase0 = 0.0;
    let phase1 = TWO_PI / 3.0;
    let phase2 = TWO_PI * 2.0 / 3.0;
    
    let d0 = helixDist(p, phase0);
    let d1 = helixDist(p, phase1);
    let d2 = helixDist(p, phase2);
    
    var minDist = d0;
    var strandId = 0.0;
    
    if (d1 < minDist) {
        minDist = d1;
        strandId = 1.0;
    }
    if (d2 < minDist) {
        minDist = d2;
        strandId = 2.0;
    }
    
    return vec2<f32>(minDist, strandId);
}

// Scene SDF - returns (distance, material_id)
fn sceneSDF(p: vec3<f32>) -> vec2<f32> {
    return braidSDF(p);
}

// Calculate normal using gradient
fn calcNormal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    let d = sceneSDF(p).x;
    let n = vec3<f32>(
        sceneSDF(p + e.xyy).x - sceneSDF(p - e.xyy).x,
        sceneSDF(p + e.yxy).x - sceneSDF(p - e.yxy).x,
        sceneSDF(p + e.yyx).x - sceneSDF(p - e.yyx).x
    );
    return normalize(n);
}

// Raymarching
fn rayMarch(ro: vec3<f32>, rd: vec3<f32>) -> vec3<f32> {
    var t = 0.0;
    var strandId = -1.0;
    
    for (var i: i32 = 0; i < MAX_STEPS; i = i + 1) {
        let p = ro + rd * t;
        let result = sceneSDF(p);
        let d = result.x;
        
        if (d < SURF_DIST) {
            strandId = result.y;
            break;
        }
        if (t > MAX_DIST) {
            break;
        }
        t = t + d * 0.8;
    }
    
    return vec3<f32>(t, strandId, select(0.0, 1.0, t < MAX_DIST));
}

// Soft shadow
fn softShadow(ro: vec3<f32>, rd: vec3<f32>, mint: f32, maxt: f32, k: f32) -> f32 {
    var res = 1.0;
    var t = mint;
    
    for (var i: i32 = 0; i < 32; i = i + 1) {
        if (t >= maxt) { break; }
        let h = sceneSDF(ro + rd * t).x;
        if (h < 0.001) {
            return 0.0;
        }
        res = min(res, k * h / t);
        t = t + h;
    }
    
    return res;
}

// Ambient occlusion
fn calcAO(p: vec3<f32>, n: vec3<f32>) -> f32 {
    var occ = 0.0;
    var sca = 1.0;
    
    for (var i: i32 = 0; i < 5; i = i + 1) {
        let h = 0.01 + 0.12 * f32(i) / 4.0;
        let d = sceneSDF(p + h * n).x;
        occ = occ + (h - d) * sca;
        sca = sca * 0.95;
    }
    
    return clamp(1.0 - 3.0 * occ, 0.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = vec2<f32>(2000.0, 1800.0);
    let uv = (pos.xy - resolution * 0.5) / min(resolution.x, resolution.y);
    
    // Camera setup at (3, 2, 2)
    let camPos = vec3<f32>(3.0, 2.0, 2.0);
    let camTarget = vec3<f32>(0.0, 0.0, 0.0);
    
    // Camera matrix
    let forward = normalize(camTarget - camPos);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), forward));
    let up = cross(forward, right);
    
    let rd = normalize(uv.x * right + uv.y * up + 1.5 * forward);
    
    // Raymarch
    let result = rayMarch(camPos, rd);
    let t = result.x;
    let strandId = i32(result.y);
    let hit = result.z > 0.5;
    
    var col = vec3<f32>(0.15, 0.15, 0.18); // Background
    
    if (hit) {
        let p = camPos + rd * t;
        let n = calcNormal(p);
        
        // Get strand color
        let baseColor = getStrandColor(strandId);
        
        // Lighting
        let lightDir = normalize(vec3<f32>(1.0, 2.0, 1.5));
        let lightColor = vec3<f32>(1.0, 0.98, 0.95);
        
        // Diffuse
        let diff = max(dot(n, lightDir), 0.0);
        
        // Specular
        let viewDir = normalize(camPos - p);
        let halfDir = normalize(lightDir + viewDir);
        let spec = pow(max(dot(n, halfDir), 0.0), 32.0);
        
        // Ambient occlusion
        let ao = calcAO(p, n);
        
        // Soft shadow
        let shadow = softShadow(p + n * 0.01, lightDir, 0.02, 5.0, 16.0);
        
        // Fresnel
        let fresnel = pow(1.0 - max(dot(n, viewDir), 0.0), 3.0);
        
        // Combine lighting
        let ambient = 0.25 * baseColor * ao;
        let diffuse = 0.7 * diff * baseColor * lightColor * shadow;
        let specular = 0.4 * spec * lightColor * shadow;
        let rim = 0.15 * fresnel * baseColor;
        
        col = ambient + diffuse + specular + rim;
        
        // Tone mapping
        col = col / (col + vec3<f32>(1.0));
        col = pow(col, vec3<f32>(0.4545)); // Gamma correction
    } else {
        // Gradient background
        col = mix(vec3<f32>(0.1, 0.1, 0.15), vec3<f32>(0.2, 0.2, 0.25), uv.y + 0.5);
    }
    
    return vec4<f32>(col, 1.0);
}