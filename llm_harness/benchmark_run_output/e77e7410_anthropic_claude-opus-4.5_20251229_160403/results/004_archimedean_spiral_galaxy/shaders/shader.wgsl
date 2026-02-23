// Two-arm Archimedean spiral galaxy shader
// r = a*theta, a = 0.25, theta in [0, 8*pi]

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

// Hash functions for pseudo-random number generation
fn hash1(n: f32) -> f32 {
    return fract(sin(n) * 43758.5453123);
}

fn hash2(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453123);
}

fn hash3(p: vec3<f32>) -> f32 {
    return fract(sin(dot(p, vec3<f32>(127.1, 311.7, 74.7))) * 43758.5453123);
}

// Box-Muller transform for Gaussian random numbers
fn gaussian(seed1: f32, seed2: f32) -> f32 {
    let u1 = max(hash1(seed1), 0.0001);
    let u2 = hash1(seed2);
    return sqrt(-2.0 * log(u1)) * cos(6.283185307 * u2);
}

// Black-body to sRGB approximation
fn blackBodyToRGB(temp: f32) -> vec3<f32> {
    let t = temp / 100.0;
    var r: f32;
    var g: f32;
    var b: f32;
    
    if (t <= 66.0) {
        r = 255.0;
        g = 99.4708025861 * log(t) - 161.1195681661;
        if (t <= 19.0) {
            b = 0.0;
        } else {
            b = 138.5177312231 * log(t - 10.0) - 305.0447927307;
        }
    } else {
        r = 329.698727446 * pow(t - 60.0, -0.1332047592);
        g = 288.1221695283 * pow(t - 60.0, -0.0755148492);
        b = 255.0;
    }
    
    return clamp(vec3<f32>(r, g, b) / 255.0, vec3<f32>(0.0), vec3<f32>(1.0));
}

// Gaussian star sprite
fn starSprite(dist: f32, fwhm: f32) -> f32 {
    let sigma = fwhm / 2.355;
    return exp(-0.5 * (dist * dist) / (sigma * sigma));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let minRes = min(res.x, res.y);
    
    // Map pixel to galaxy coordinates [-10, 10]
    let uv = (pos.xy - res * 0.5) / (minRes * 0.05);
    
    var color = vec3<f32>(0.0);
    
    // Spiral parameters
    let a = 0.25;
    let thetaMax = 25.132741228; // 8 * pi
    
    // Render spiral arm stars (120,000 stars total, but sample nearby ones)
    let numStars = 2000u; // Reduced for per-pixel computation
    
    for (var i = 0u; i < numStars; i = i + 1u) {
        let fi = f32(i);
        
        // Generate star position for arm 0
        let theta0 = hash1(fi * 1.1) * thetaMax;
        let rBase0 = a * theta0;
        
        // Gaussian offsets
        let dTheta0 = gaussian(fi * 2.3, fi * 3.7) * 0.035;
        let sigmaR0 = 0.025 * (1.0 + 0.5 * theta0);
        let dR0 = gaussian(fi * 4.1, fi * 5.3) * sigmaR0;
        
        let theta0Final = theta0 + dTheta0;
        let r0 = rBase0 + dR0;
        
        // Rejection sampling for radial density falloff
        let weight0 = exp(-r0 / 3.0);
        let u0 = hash1(fi * 6.7);
        
        if (u0 < weight0 && r0 > 0.0) {
            let starPos0 = vec2<f32>(r0 * cos(theta0Final), r0 * sin(theta0Final));
            let dist0 = length(uv - starPos0);
            
            // Star properties
            let temp0 = 7200.0 - 250.0 * r0;
            let brightness0 = exp(-0.5 * r0);
            let fwhm0 = 0.03 + 0.004 * r0;
            
            let starColor0 = blackBodyToRGB(temp0);
            let intensity0 = starSprite(dist0, fwhm0) * brightness0;
            
            color = color + starColor0 * intensity0 * 0.8;
        }
        
        // Generate star position for arm 1 (offset by pi)
        let theta1 = hash1(fi * 1.1 + 1000.0) * thetaMax;
        let rBase1 = a * theta1;
        
        let dTheta1 = gaussian(fi * 2.3 + 1000.0, fi * 3.7 + 1000.0) * 0.035;
        let sigmaR1 = 0.025 * (1.0 + 0.5 * theta1);
        let dR1 = gaussian(fi * 4.1 + 1000.0, fi * 5.3 + 1000.0) * sigmaR1;
        
        let theta1Final = theta1 + dTheta1 + 3.141592653;
        let r1 = rBase1 + dR1;
        
        let weight1 = exp(-r1 / 3.0);
        let u1 = hash1(fi * 6.7 + 1000.0);
        
        if (u1 < weight1 && r1 > 0.0) {
            let starPos1 = vec2<f32>(r1 * cos(theta1Final), r1 * sin(theta1Final));
            let dist1 = length(uv - starPos1);
            
            let temp1 = 7200.0 - 250.0 * r1;
            let brightness1 = exp(-0.5 * r1);
            let fwhm1 = 0.03 + 0.004 * r1;
            
            let starColor1 = blackBodyToRGB(temp1);
            let intensity1 = starSprite(dist1, fwhm1) * brightness1;
            
            color = color + starColor1 * intensity1 * 0.8;
        }
    }
    
    // Background halo/disc stars (10,000 stars)
    let numHaloStars = 500u;
    
    for (var j = 0u; j < numHaloStars; j = j + 1u) {
        let fj = f32(j);
        
        // Sample radius with p(r) ~ r * exp(-r/3)
        let u_r = hash1(fj * 11.3 + 5000.0);
        // Inverse CDF approximation for r*exp(-r/3)
        let rHalo = -3.0 * log(1.0 - u_r * (1.0 - exp(-10.0/3.0))) * (1.0 + 0.3 * u_r);
        let angleHalo = hash1(fj * 13.7 + 5000.0) * 6.283185307;
        
        let haloPos = vec2<f32>(rHalo * cos(angleHalo), rHalo * sin(angleHalo));
        let distHalo = length(uv - haloPos);
        
        // Small white dots
        let haloIntensity = starSprite(distHalo, 0.02) * 0.3;
        color = color + vec3<f32>(1.0, 1.0, 1.0) * haloIntensity;
    }
    
    // Core glow - supernova-like bloom
    let coreRadius = 0.4;
    let coreDist = length(uv);
    let coreGlow = exp(-coreDist * coreDist / (coreRadius * coreRadius * 0.5));
    let coreColor = vec3<f32>(1.0, 1.0, 0.667) * coreGlow * 0.6;
    
    color = color + coreColor;
    
    // Add central bright core
    let centralCore = exp(-coreDist * coreDist / 0.01) * 2.0;
    color = color + vec3<f32>(1.0, 0.95, 0.8) * centralCore;
    
    // Tone mapping and gamma correction
    color = color / (color + vec3<f32>(1.0));
    color = pow(color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(color, 1.0);
}