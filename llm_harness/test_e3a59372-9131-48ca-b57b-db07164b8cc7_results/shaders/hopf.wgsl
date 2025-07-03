// Utilities and constants
const PI = 3.14159265359;
const TAU = 6.28318530718;

fn hsv2rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let c = v * s;
    let hp = h * 6.0;
    let x = c * (1.0 - abs(fract(hp / 2.0) - 1.0));
    let m = v - c;
    
    var rgb = select(
        select(
            select(
                select(
                    select(
                        vec3<f32>(c,0,x),
                        vec3<f32>(x,0,c),
                        hp < 5.0
                    ),
                    vec3<f32>(0,x,c),
                    hp < 4.0
                ),
                vec3<f32>(0,c,x),
                hp < 3.0
            ),
            vec3<f32>(x,c,0),
            hp < 2.0
        ),
        vec3<f32>(c,x,0),
        hp < 1.0
    );
    return rgb + vec3<f32>(m);
}

// Stereographic projection S³ → R³
fn stereo_proj(p: vec4<f32>) -> vec3<f32> {
    let scale = 1.0 / (1.0 - p.w);
    return p.xyz * scale;
}

// Hopf fibration
fn hopf_fiber(theta: f32, phi: f32, psi: f32) -> vec4<f32> {
    let cosT = cos(theta * 0.5);
    let sinT = sin(theta * 0.5);
    let cosP = cos(phi);
    let sinP = sin(phi);
    let cosS = cos(psi);
    let sinS = sin(psi);
    
    return vec4<f32>(
        cosT * cosP * cosS - sinT * sinP * sinS,
        cosT * cosP * sinS + sinT * sinP * cosS,
        cosT * sinP * cosS + sinT * cosP * sinS,
        cosT * sinP * sinS - sinT * cosP * cosS
    );
}

@vertex
fn main_vs(@builtin(vertex_index) vid: u32) -> @builtin(position) vec4<f32> {
    let xy = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -3.0),
        vec2<f32>( 3.0,  1.0),
        vec2<f32>(-1.0,  1.0),
    )[vid];
    return vec4<f32>(xy, 0.0, 1.0);
}

@fragment
fn main_fs(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - 800.0) / 800.0;
    
    // Ray setup for rendering
    let ro = vec3<f32>(0.0, 0.0, -4.0);
    var rd = normalize(vec3<f32>(uv, 2.0));
    
    var col = vec3<f32>(1.0); // White background
    
    // Parameters for the three tori
    let latitudes = array<f32, 3>(
        PI/3.0,    // +60°
        PI/2.0,    // 0°
        2.0*PI/3.0 // -60°
    );
    
    // For each torus from Hopf fibration
    for(var i = 0u; i < 3u; i++) {
        let theta = latitudes[i];
        
        // Sample points along the fiber
        for(var t = 0.0; t < TAU; t += 0.01) {
            for(var s = 0.0; s < TAU; s += 0.01) {
                let p = hopf_fiber(theta, t, s);
                let p3 = stereo_proj(p);
                
                // Distance from ray to fiber point
                let v = p3 - ro;
                let dist = length(cross(v, rd)) / length(rd);
                
                // If ray hits fiber
                if(dist < 0.1) {
                    // Color based on longitude
                    let hue = t / TAU;
                    col = hsv2rgb(hue, 1.0, 1.0);
                }
            }
        }
    }
    
    return vec4<f32>(col, 1.0);
}