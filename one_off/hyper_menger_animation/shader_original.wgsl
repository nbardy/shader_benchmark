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
    aspect: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

const CLIP_R: f32 = 3.2;     // bounding ball for the projected set (keeps camera outside)
const TMAX: f32 = 13.0;
const MENGER_ITERS: i32 = 4; // >= 3 complete iterations required

// Inverse stereographic projection from R^3 onto the unit 3-sphere in R^4.
// Forward map is pi(x,y,z,w) = (x,y,z)/(1-w) from the pole (0,0,0,1);
// inverse: p -> (2p, |p|^2 - 1) / (1 + |p|^2).  Always satisfies x^2+y^2+z^2+w^2 = 1.
fn inv_stereo(p: vec3<f32>) -> vec4<f32> {
    let r2 = dot(p, p);
    let inv = 1.0 / (1.0 + r2);
    return vec4<f32>(2.0 * p.x * inv, 2.0 * p.y * inv, 2.0 * p.z * inv, (r2 - 1.0) * inv);
}

// Gentle double rotation in 4D (x-w plane and y-z plane) to reveal multiple aspects.
fn rot4(q: vec4<f32>) -> vec4<f32> {
    let a1 = 0.55 + 0.12 * params.time;
    let c1 = cos(a1);
    let s1 = sin(a1);
    var p = vec4<f32>(c1 * q.x - s1 * q.w, q.y, q.z, s1 * q.x + c1 * q.w);
    let a2 = 0.32 + 0.09 * params.time;
    let c2 = cos(a2);
    let s2 = sin(a2);
    p = vec4<f32>(p.x, c2 * p.y - s2 * p.z, s2 * p.y + c2 * p.z, p.w);
    return p;
}

// Distance estimator for the 4D Menger tesseract in [-1,1]^4.
// Folding identical to the classic 3D Menger DE, extended to 4 coordinates.
// r_i > 1  <=>  coordinate i lies in a middle third at the current scale.
// A point is REMOVED when >= 3 of 4 coordinates are middle (kept iff at most 2),
// i.e. when the second-smallest component of r exceeds 1 — computed as the
// max over the four triple-mins.
fn menger4(p: vec4<f32>) -> f32 {
    let b = abs(p) - vec4<f32>(1.0);
    var d = length(max(b, vec4<f32>(0.0))) + min(max(max(b.x, b.y), max(b.z, b.w)), 0.0);
    var s = 1.0;
    for (var m: i32 = 0; m < MENGER_ITERS; m = m + 1) {
        let ps = p * s;
        let a = ps - 2.0 * floor(ps * 0.5) - 1.0;   // mod(p*s, 2) - 1, valid for negatives
        s = s * 3.0;
        let r = abs(vec4<f32>(1.0) - 3.0 * abs(a));
        let m1 = min(r.y, min(r.z, r.w));
        let m2 = min(r.x, min(r.z, r.w));
        let m3 = min(r.x, min(r.y, r.w));
        let m4 = min(r.x, min(r.y, r.z));
        let c = (max(max(m1, m2), max(m3, m4)) - 1.0) / s;
        d = max(d, c);
    }
    return d;
}

// Scene field: point p in R^3 lifts to the 3-sphere; solid where the lifted,
// rotated 4D point is inside the Menger tesseract.  A 3D step of length L
// moves ~ lambda*L on the sphere with lambda = 2/(1+|p|^2), so divide the 4D
// distance by lambda (with a safety factor) to get a conservative 3D step.
fn map_scene(p: vec3<f32>) -> f32 {
    let q = rot4(inv_stereo(p));
    let d4 = menger4(q);
    let lambda = 2.0 / (1.0 + dot(p, p));
    let dm = (d4 / lambda) * 0.6;
    let dclip = length(p) - CLIP_R;
    return max(dm, dclip);
}

fn calc_normal(p: vec3<f32>) -> vec3<f32> {
    let h = 0.0011;
    let dx = map_scene(p + vec3<f32>(h, 0.0, 0.0)) - map_scene(p - vec3<f32>(h, 0.0, 0.0));
    let dy = map_scene(p + vec3<f32>(0.0, h, 0.0)) - map_scene(p - vec3<f32>(0.0, h, 0.0));
    let dz = map_scene(p + vec3<f32>(0.0, 0.0, h)) - map_scene(p - vec3<f32>(0.0, 0.0, h));
    return normalize(vec3<f32>(dx, dy, dz));
}

// Color by the pre-projection w coordinate (linearized sRGB targets):
// w=+1 bright yellow #ffeb3b, w=0 deep orange #ff5722, w=-1 dark purple #4a148c.
fn w_color(w: f32) -> vec3<f32> {
    let purple = vec3<f32>(0.084, 0.006, 0.30);
    let orange = vec3<f32>(1.0, 0.116, 0.018);
    let yellow = vec3<f32>(1.0, 0.846, 0.053);
    let t1 = smoothstep(-1.0, 0.0, w);
    let t2 = smoothstep(0.0, 1.0, w);
    let c1 = purple + (orange - purple) * t1;
    return c1 + (yellow - c1) * t2;
}

// Deep-space background: dark blue (#0d47a1, linearized) fading to black.
fn bg_color(rd: vec3<f32>) -> vec3<f32> {
    let blue = vec3<f32>(0.0026, 0.077, 0.40);
    let t = clamp(0.5 + 0.6 * rd.y, 0.0, 1.0);
    let g = 0.1 + 0.9 * t * t;
    return blue * g;
}

fn shade(p: vec3<f32>, rd: vec3<f32>) -> vec3<f32> {
    let n = calc_normal(p);
    let w = inv_stereo(p).w;                  // w-coordinate before projection
    let base = w_color(w);
    let l1 = normalize(vec3<f32>(0.65, 0.75, 0.45));   // primary: upper-right
    let l2 = normalize(vec3<f32>(-0.6, -0.45, -0.4));  // secondary: lower-left
    let dif1 = clamp(dot(n, l1), 0.0, 1.0);
    let dif2 = clamp(dot(n, l2), 0.0, 1.0);
    let ao = clamp(map_scene(p + n * 0.08) / 0.08, 0.0, 1.0) * 0.6 + 0.4;
    let h1 = normalize(l1 - rd);
    let spec = pow(clamp(dot(n, h1), 0.0, 1.0), 48.0);
    let rim = pow(clamp(1.0 + dot(n, rd), 0.0, 1.0), 2.5);  // fake subsurface glow
    var col = base * (0.24 * ao);                           // ambient (prevents deep shadows)
    col = col + base * dif1 * vec3<f32>(1.0, 0.96, 0.88) * 1.05;
    col = col + base * dif2 * vec3<f32>(0.55, 0.6, 0.9) * 0.5;
    col = col + vec3<f32>(1.0, 1.0, 1.0) * spec * (0.65 * (0.3 + 0.7 * dif1));
    col = col + base * rim * 0.45;
    return col;
}

fn march(ro: vec3<f32>, rd: vec3<f32>, t0: f32, maxsteps: i32) -> f32 {
    var t = t0;
    for (var i: i32 = 0; i < maxsteps; i = i + 1) {
        let d = map_scene(ro + rd * t);
        if (d < 0.0008 + 0.0006 * t) {
            return t;
        }
        t = t + d;
        if (t > TMAX) {
            break;
        }
    }
    return -1.0;
}

// Two-layer march: front surface at alpha = 0.8, then skip through the solid
// and march to a second surface so internal structure shows through.
fn render(ro: vec3<f32>, rd: vec3<f32>) -> vec3<f32> {
    let bg = bg_color(rd);
    var col = bg;
    let t1 = march(ro, rd, 0.0, 180);
    if (t1 > 0.0) {
        let p1 = ro + rd * t1;
        let c1 = shade(p1, rd);
        var t = t1 + 0.015;
        var exited = false;
        for (var i: i32 = 0; i < 48; i = i + 1) {
            let d = map_scene(ro + rd * t);
            if (d > 0.012) {
                exited = true;
                break;
            }
            t = t + max(abs(d) * 0.9, 0.015);
            if (t > TMAX) {
                break;
            }
        }
        var rest = bg;
        if (exited) {
            let t2 = march(ro, rd, t, 120);
            if (t2 > 0.0) {
                let c2 = shade(ro + rd * t2, rd);
                rest = c2 * 0.8 + bg * 0.2;
            }
        }
        col = c1 * 0.8 + rest * 0.2;   // alpha = 0.8 front-to-back blend
    }
    // mild tonemap; output stays linear (sRGB render target encodes it)
    return col / (col + vec3<f32>(0.8)) * 1.4;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let ang = 0.7 + 0.12 * params.time;
    let ro = vec3<f32>(7.2 * cos(ang), 3.6, 7.2 * sin(ang));
    let fwd = normalize(-ro);
    let right = normalize(cross(fwd, vec3<f32>(0.0, 1.0, 0.0)));
    let up = cross(right, fwd);
    var col = vec3<f32>(0.0);
    // 2x2 supersampling for anti-aliasing
    for (var sy: i32 = 0; sy < 2; sy = sy + 1) {
        for (var sx: i32 = 0; sx < 2; sx = sx + 1) {
            let off = vec2<f32>(f32(sx), f32(sy)) * 0.5 - 0.25;
            let frag = pos.xy + off;
            let ndc = (2.0 * frag - res) / res.y;
            let suv = vec2<f32>(ndc.x, -ndc.y);
            let rd = normalize(right * suv.x + up * suv.y + fwd * 2.0);
            col = col + render(ro, rd);
        }
    }
    col = col * 0.25;
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}