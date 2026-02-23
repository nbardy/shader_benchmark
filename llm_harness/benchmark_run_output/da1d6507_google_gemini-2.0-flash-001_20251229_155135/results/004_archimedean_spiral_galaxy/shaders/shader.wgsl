@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    resolution: vec2<f32>,
    time: f32,
};

fn blackbody(temperature: f32) -> vec3<f32> {
    var temp: f32 = temperature / 100.0;
    var r: f32 = 0.0;
    var g: f32 = 0.0;
    var b: f32 = 0.0;

    if (temp <= 66.0) {
        r = 255.0;
    } else {
        r = temp - 60.0;
        r = 329.698727446 * pow(r, -0.1332047592);
        r = clamp(r, 0.0, 255.0);
    }

    if (temp <= 66.0) {
        g = temp;
        g = 99.4708025861 * log(g) - 161.1195681661;
        g = clamp(g, 0.0, 255.0);
    } else {
        g = temp - 60.0;
        g = 288.1221695283 * pow(g, -0.0755148492);
        g = clamp(g, 0.0, 255.0);
    }

    if (temp >= 66.0) {
        b = 255.0;
    } else {
        if (temp <= 19.0) {
            b = 0.0;
        } else {
            b = temp - 10.0;
            b = 138.5177312231 * log(b) - 305.0447927307;
            b = clamp(b, 0.0, 255.0);
        }
    }

    return vec3<f32>(r / 255.0, g / 255.0, b / 255.0);
}

fn gaussian(x: f32, sigma: f32) -> f32 {
    return exp(-(x * x) / (2.0 * sigma * sigma)) / (sigma * sqrt(2.0 * 3.14159265359));
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy / params.resolution) * 20.0 - 10.0;
    let a: f32 = 0.25;
    var color = vec3<f32>(0.0, 0.0, 0.0);

    // Spiral galaxy stars
    for (var i: u32 = 0u; i < 120000u; i++) {
        let theta = rand(vec2<f32>(f32(i) * 0.1, params.time)) * 8.0 * 3.14159265359;
        let r = a * theta;
        
        let deltaTheta = rand(vec2<f32>(f32(i) * 0.2, params.time)) * 2.0 - 1.0;
        let deltaR = rand(vec2<f32>(f32(i) * 0.3, params.time)) * 2.0 - 1.0;

        let sigmaTheta = 0.035;
        let sigmaR = 0.025 * (1.0 + 0.5 * theta);

        let thetaFinal = theta + deltaTheta * sigmaTheta;
        let rFinal = r + deltaR * sigmaR;
        let w = exp(-rFinal / 3.0);
        let u = rand(vec2<f32>(f32(i) * 0.4, params.time));

        if (u < w) {
            let starX = rFinal * cos(thetaFinal);
            let starY = rFinal * sin(thetaFinal);
            let dist = length(uv - vec2<f32>(starX, starY));

            let fwhm = 0.03 + 0.004 * rFinal;
            let brightness = exp(-0.5 * rFinal);
            let brightnessClipped = clamp(brightness, 0.0, 1.0);
            let star_color_temp = 7200.0 - 25.0 * rFinal;
            let star_color = blackbody(star_color_temp);
            let sprite = gaussian(dist, fwhm / 2.355) * 5.0 * brightnessClipped;

            color += sprite * star_color;
        }
    }

    // Disc halo stars
    for (var i: u32 = 0u; i < 10000u; i++) {
        let r = rand(vec2<f32>(f32(i) * 0.5, params.time)) * 10.0;
        let theta = rand(vec2<f32>(f32(i) * 0.6, params.time)) * 2.0 * 3.14159265359;
        let weight = r * exp(-r / 3.0); 
        
        let x = r * cos(theta);
        let y = r * sin(theta);

        let dist = length(uv - vec2<f32>(x, y));
        let sprite = gaussian(dist, 0.01);
        color += sprite * 0.1 * vec3<f32>(1.0, 1.0, 1.0);
    }

    // Supernova core glow
    let coreDist = length(uv);
    let coreGlow = gaussian(coreDist, 0.4 / 2.355) * 0.6;
    color += coreGlow * vec3<f32>(1.0, 1.0, 0.666); // #ffffaa

    return vec4<f32>(color, 1.0);
}

fn rand(co:vec2<f32>) -> f32 {
    let a = 12.9898;
    let b = 78.233;
    let c = 43758.5453;
    var dt= dot(co.xy ,vec2<f32>(a,b));
    var sn= fract(dt * c);
    return fract(sin(sn * 3.14159265359 * 2.0) * 0.5 + 0.5);
}