// Winter tree - recursive branching structure with ray marching
// Camera at (3,-6,2.5) looking at origin, FOV 40°

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
const MAX_STEPS: i32 = 200;
const MAX_DIST: f32 = 50.0;
const SURF_DIST: f32 = 0.001;

// Bark color
const BARK_COLOR: vec3<f32> = vec3<f32>(0.294, 0.216, 0.149);

// Rotation matrix around Y axis
fn rotY(a: f32) -> mat3x3<f32> {
    let c = cos(a);
    let s = sin(a);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

// Rotation matrix around X axis
fn rotX(a: f32) -> mat3x3<f32> {
    let c = cos(a);
    let s = sin(a);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

// Rotation matrix around Z axis
fn rotZ(a: f32) -> mat3x3<f32> {
    let c = cos(a);
    let s = sin(a);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

// Capped cone SDF (tapered cylinder for branches)
fn sdCappedCone(p: vec3<f32>, h: f32, r1: f32, r2: f32) -> f32 {
    let q = vec2<f32>(length(p.xz), p.y);
    let k1 = vec2<f32>(r2, h);
    let k2 = vec2<f32>(r2 - r1, 2.0 * h);
    let ca = vec2<f32>(q.x - min(q.x, select(r1, r2, q.y < 0.0)), abs(q.y) - h);
    let cb = q - k1 + k2 * clamp(dot(k1 - q, k2) / dot(k2, k2), 0.0, 1.0);
    let s = select(1.0, -1.0, cb.x < 0.0 && ca.y < 0.0);
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

// Sphere SDF for joints
fn sdSphere(p: vec3<f32>, r: f32) -> f32 {
    return length(p) - r;
}

// Smooth minimum for blending
fn smin(a: f32, b: f32, k: f32) -> f32 {
    let h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

// Single branch segment SDF
fn branchSDF(p: vec3<f32>, len: f32, r1: f32, r2: f32) -> f32 {
    // Branch goes from y=0 to y=len
    let bp = p - vec3<f32>(0.0, len * 0.5, 0.0);
    return sdCappedCone(bp, len * 0.5, r1, r2);
}

// Tree SDF with iterative branch evaluation
fn treeSDF(p: vec3<f32>) -> f32 {
    var d = MAX_DIST;
    
    // Branch angle parameters
    let bendAngle = PI * 0.25; // 45 degrees from parent
    let twistAngle = PI * 0.194; // ~35 degrees twist
    let lenScale = 0.7;
    let radScale = 0.6;
    
    // Level 0: Trunk
    let len0 = 1.0;
    let r0_base = 0.08;
    let r0_top = r0_base * radScale;
    
    var p0 = p;
    d = min(d, branchSDF(p0, len0, r0_base, r0_top));
    d = smin(d, sdSphere(p0, r0_base * 1.2), 0.02); // Base joint
    d = smin(d, sdSphere(p0 - vec3<f32>(0.0, len0, 0.0), r0_top * 1.2), 0.02); // Top joint
    
    // Level 1: Two branches
    let len1 = len0 * lenScale;
    let r1_base = r0_top;
    let r1_top = r1_base * radScale;
    
    // Branch 1a
    var p1a = p0 - vec3<f32>(0.0, len0, 0.0);
    p1a = rotZ(twistAngle) * rotX(bendAngle) * p1a;
    d = smin(d, branchSDF(p1a, len1, r1_base, r1_top), 0.015);
    
    // Branch 1b
    var p1b = p0 - vec3<f32>(0.0, len0, 0.0);
    p1b = rotZ(-twistAngle) * rotX(-bendAngle) * p1b;
    d = smin(d, branchSDF(p1b, len1, r1_base, r1_top), 0.015);
    
    // Level 2
    let len2 = len1 * lenScale;
    let r2_base = r1_top;
    let r2_top = r2_base * radScale;
    
    // From 1a
    var p2aa = p1a - vec3<f32>(0.0, len1, 0.0);
    p2aa = rotZ(twistAngle) * rotX(bendAngle) * p2aa;
    d = smin(d, branchSDF(p2aa, len2, r2_base, r2_top), 0.01);
    
    var p2ab = p1a - vec3<f32>(0.0, len1, 0.0);
    p2ab = rotZ(-twistAngle) * rotX(-bendAngle) * p2ab;
    d = smin(d, branchSDF(p2ab, len2, r2_base, r2_top), 0.01);
    
    // From 1b
    var p2ba = p1b - vec3<f32>(0.0, len1, 0.0);
    p2ba = rotZ(twistAngle) * rotX(bendAngle) * p2ba;
    d = smin(d, branchSDF(p2ba, len2, r2_base, r2_top), 0.01);
    
    var p2bb = p1b - vec3<f32>(0.0, len1, 0.0);
    p2bb = rotZ(-twistAngle) * rotX(-bendAngle) * p2bb;
    d = smin(d, branchSDF(p2bb, len2, r2_base, r2_top), 0.01);
    
    // Level 3
    let len3 = len2 * lenScale;
    let r3_base = r2_top;
    let r3_top = r3_base * radScale;
    
    // From 2aa
    var p3aaa = p2aa - vec3<f32>(0.0, len2, 0.0);
    p3aaa = rotZ(twistAngle) * rotX(bendAngle) * p3aaa;
    d = smin(d, branchSDF(p3aaa, len3, r3_base, r3_top), 0.008);
    
    var p3aab = p2aa - vec3<f32>(0.0, len2, 0.0);
    p3aab = rotZ(-twistAngle) * rotX(-bendAngle) * p3aab;
    d = smin(d, branchSDF(p3aab, len3, r3_base, r3_top), 0.008);
    
    // From 2ab
    var p3aba = p2ab - vec3<f32>(0.0, len2, 0.0);
    p3aba = rotZ(twistAngle) * rotX(bendAngle) * p3aba;
    d = smin(d, branchSDF(p3aba, len3, r3_base, r3_top), 0.008);
    
    var p3abb = p2ab - vec3<f32>(0.0, len2, 0.0);
    p3abb = rotZ(-twistAngle) * rotX(-bendAngle) * p3abb;
    d = smin(d, branchSDF(p3abb, len3, r3_base, r3_top), 0.008);
    
    // From 2ba
    var p3baa = p2ba - vec3<f32>(0.0, len2, 0.0);
    p3baa = rotZ(twistAngle) * rotX(bendAngle) * p3baa;
    d = smin(d, branchSDF(p3baa, len3, r3_base, r3_top), 0.008);
    
    var p3bab = p2ba - vec3<f32>(0.0, len2, 0.0);
    p3bab = rotZ(-twistAngle) * rotX(-bendAngle) * p3bab;
    d = smin(d, branchSDF(p3bab, len3, r3_base, r3_top), 0.008);
    
    // From 2bb
    var p3bba = p2bb - vec3<f32>(0.0, len2, 0.0);
    p3bba = rotZ(twistAngle) * rotX(bendAngle) * p3bba;
    d = smin(d, branchSDF(p3bba, len3, r3_base, r3_top), 0.008);
    
    var p3bbb = p2bb - vec3<f32>(0.0, len2, 0.0);
    p3bbb = rotZ(-twistAngle) * rotX(-bendAngle) * p3bbb;
    d = smin(d, branchSDF(p3bbb, len3, r3_base, r3_top), 0.008);
    
    // Level 4-7: Add finer twigs with reduced detail
    let len4 = len3 * lenScale;
    let r4 = r3_top * radScale;
    
    // Simplified higher levels - just add some noise-like twigs
    d = smin(d, branchSDF(p3aaa - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3aab - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3aba - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3abb - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3baa - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3bab - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3bba - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    d = smin(d, branchSDF(p3bbb - vec3<f32>(0.0, len3, 0.0), len4, r4, r4 * 0.5), 0.005);
    
    return d;
}

// Calculate normal
fn getNormal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.001, 0.0);
    return normalize(vec3<f32>(
        treeSDF(p + e.xyy) - treeSDF(p - e.xyy),
        treeSDF(p + e.yxy) - treeSDF(p - e.yxy),
        treeSDF(p + e.yyx) - treeSDF(p - e.yyx)
    ));
}

// Ray march
fn rayMarch(ro: vec3<f32>, rd: vec3<f32>) -> f32 {
    var t = 0.0;
    for (var i = 0; i < MAX_STEPS; i = i + 1) {
        let p = ro + rd * t;
        let d = treeSDF(p);
        if (d < SURF_DIST) {
            return t;
        }
        if (t > MAX_DIST) {
            break;
        }
        t = t + d * 0.8;
    }
    return -1.0;
}

// Sky gradient
fn getSky(rd: vec3<f32>) -> vec3<f32> {
    let zenith = vec3<f32>(0.843, 0.925, 1.0);  // #d7ecff
    let horizon = vec3<f32>(1.0, 1.0, 1.0);     // #ffffff
    let t = clamp(rd.y * 0.5 + 0.5, 0.0, 1.0);
    return mix(horizon, zenith, t);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let uv = (pos.xy - resolution * 0.5) / min(resolution.x, resolution.y);
    
    // Camera setup
    let camPos = vec3<f32>(3.0, 2.5, -6.0);
    let camTarget = vec3<f32>(0.0, 0.8, 0.0);
    let camUp = vec3<f32>(0.0, 1.0, 0.0);
    
    // Camera matrix
    let fwd = normalize(camTarget - camPos);
    let right = normalize(cross(fwd, camUp));
    let up = cross(right, fwd);
    
    // FOV 40 degrees
    let fov = tan(PI * 40.0 / 360.0);
    let rd = normalize(fwd + (uv.x * right + uv.y * up) * fov);
    
    // Ray march
    let t = rayMarch(camPos, rd);
    
    var col = getSky(rd);
    
    if (t > 0.0) {
        let p = camPos + rd * t;
        let n = getNormal(p);
        
        // Three-point lighting
        let keyPos = vec3<f32>(3.0, 5.0, -5.0);
        let fillPos = vec3<f32>(-2.0, 4.0, -6.0);
        let rimPos = vec3<f32>(0.0, 6.0, 0.0);
        
        let keyDir = normalize(keyPos - p);
        let fillDir = normalize(fillPos - p);
        let rimDir = normalize(rimPos - p);
        
        // Diffuse lighting
        let keyDiff = max(dot(n, keyDir), 0.0);
        let fillDiff = max(dot(n, fillDir), 0.0) * 0.4;
        let rimDiff = max(dot(n, rimDir), 0.0) * 0.3;
        
        // Rim lighting for silhouette emphasis
        let rimFresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0) * 0.5;
        
        // Ambient
        let ambient = 0.15;
        
        let lighting = ambient + keyDiff + fillDiff + rimDiff + rimFresnel;
        
        // Apply bark color with roughness effect
        col = BARK_COLOR * lighting;
        
        // Add subtle specular for wet bark look
        let h = normalize(keyDir - rd);
        let spec = pow(max(dot(n, h), 0.0), 8.0) * 0.1;
        col = col + vec3<f32>(spec);
        
        // Fog for depth
        let fogAmount = 1.0 - exp(-t * 0.03);
        col = mix(col, getSky(rd), fogAmount);
    }
    
    // Tone mapping and gamma
    col = col / (col + vec3<f32>(1.0));
    col = pow(col, vec3<f32>(0.4545));
    
    return vec4<f32>(col, 1.0);
}