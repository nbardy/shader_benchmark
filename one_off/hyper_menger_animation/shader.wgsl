// Animated, re-shaded "hyper Menger cube on a 3-sphere" — v3: one clean action.
//
// Derived from shader_original.wgsl (benchmark output, run 2cebf07b /
// 000_hyper_menger_cube_3sphere). Geometry pipeline is unchanged:
// inverse stereographic lift R^3 -> S^3, 4D rotation, 4D Menger
// tesseract distance estimator, conservative 3D step.
//
// v3 design (replaces v2's SU(2)xSU(2) double isoclinic action):
//
//   WHY: only 4D rotations that MOVE the projection pole morph the visible
//   surface. The lift puts the pole on the w axis (inv_stereo: w is the
//   (|p|^2 - 1)-like coordinate, the quaternion scalar; p -> infinity maps
//   to +e_w). A rotation that fixes the w axis commutes with stereographic
//   projection and appears in R^3 as a rigid 3D rotation — a boring swirl.
//   v2's left/right isoclinic pair decomposed into a pole-moving (w,x)
//   component (-1 quarter-turn/loop) plus a pole-fixing (y,z) component
//   (+3 quarter-turns/loop), so the motion was dominated by rigid swirl.
//   And v2's hue was the angle of the very circle action doing the
//   rotating, so points slid along their own hue bands — the color field
//   was static by construction.
//
//   ANIMATION - a SINGLE simple rotation in the (w,x)-plane only (a plane
//              containing the pole — pure slice-sweep, no swirl):
//                  alpha = TAU * time / LOOP_SECONDS
//              One FULL turn per loop, so the net loop transform is the
//              IDENTITY and the loop closes for ANY color field. The object
//              passes "through infinity" once per loop. A constant
//              aesthetic pre-rotation (PRE_WX / PRE_YZ, v2's base
//              orientation) is applied first; any fixed pre-rotation keeps
//              the net loop transform identity.
//   CAMERA   - STATIC: orbit and bob removed, one fixed viewpoint (v2's
//              phase-0 view). Key light stays tied to the (fixed) camera
//              azimuth. The 4D sweep provides all the visual change.
//   COLOR    - the hidden dimension, literally: hue from the rotated 4D
//              point's raw w coordinate, hue = (q.w + 1)/2 * 0.83 (the
//              0.83 stops red wrapping back onto red). No periodicity
//              constraint applies because the net loop transform is the
//              identity. Each material cell's w changes through the sweep,
//              so the rainbow genuinely warps: hue reads as "depth into
//              the 4th dimension".
//   SHADING  - unchanged from v2: raymarched soft shadows from a strong
//              warm key light, 5-tap ambient occlusion (Menger holes read
//              dark), cool rim light, cool fill, ACES tonemap, darker
//              gradient background with halo + screen vignette.

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

const TAU: f32 = 6.283185307179586;
const PI: f32 = 3.141592653589793;
const LOOP_SECONDS: f32 = 12.0;

// Fixed camera azimuth — v2's phase-0 viewpoint (orbit/bob removed).
const CAM_ANG: f32 = 0.7;

// Constant aesthetic pre-rotation: the net fixed offsets of v2's base
// orientation (left 0.55 / right -0.32 about i  =>  (w,x) +0.23, (y,z)
// +0.87). Time-independent, so the animated full turn still nets identity.
const PRE_WX: f32 = 0.23;
const PRE_YZ: f32 = 0.87;

const CLIP_R: f32 = 3.2;     // bounding ball for the projected set (keeps camera outside)
const TMAX: f32 = 13.0;
const MENGER_ITERS: i32 = 4; // >= 3 complete iterations required

// Inverse stereographic projection from R^3 onto the unit 3-sphere in R^4.
// Stored xyzw with the pole/scalar coordinate in .w.
fn inv_stereo(p: vec3<f32>) -> vec4<f32> {
    let r2 = dot(p, p);
    let inv = 1.0 / (1.0 + r2);
    return vec4<f32>(2.0 * p.x * inv, 2.0 * p.y * inv, 2.0 * p.z * inv, (r2 - 1.0) * inv);
}

// Plane rotation in the (w,x)-plane: (w,x) <- (w cos a - x sin a,
// w sin a + x cos a); y,z unchanged. This plane CONTAINS the projection
// pole (w axis), so the rotation sweeps the fractal through the pole —
// the projected surface morphs instead of rigidly rotating.
fn rot_wx(q: vec4<f32>, a: f32) -> vec4<f32> {
    let c = cos(a);
    let s = sin(a);
    return vec4<f32>(q.w * s + q.x * c, q.y, q.z, q.w * c - q.x * s);
}

// Plane rotation in the (y,z)-plane (pole-fixing; used only as part of the
// CONSTANT pre-rotation, never animated — animating it would just spin the
// projected ball rigidly).
fn rot_yz(q: vec4<f32>, a: f32) -> vec4<f32> {
    let c = cos(a);
    let s = sin(a);
    return vec4<f32>(q.x, q.y * c - q.z * s, q.y * s + q.z * c, q.w);
}

// The one clean action: fixed pre-rotation, then a single (w,x) rotation
// advancing one full turn per loop. alpha(LOOP_SECONDS) = TAU => net
// transform identity => seam closes exactly, for any color field.
fn rot4(q: vec4<f32>) -> vec4<f32> {
    let alpha = TAU * params.time / LOOP_SECONDS;
    return rot_wx(rot_yz(q, PRE_YZ), PRE_WX + alpha);
}

// Distance estimator for the 4D Menger tesseract in [-1,1]^4 (unchanged).
fn menger4(p: vec4<f32>) -> f32 {
    let b = abs(p) - vec4<f32>(1.0);
    var d = length(max(b, vec4<f32>(0.0))) + min(max(max(b.x, b.y), max(b.z, b.w)), 0.0);
    var s = 1.0;
    for (var m: i32 = 0; m < MENGER_ITERS; m = m + 1) {
        let ps = p * s;
        let a = ps - 2.0 * floor(ps * 0.5) - 1.0;
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

fn hsv2rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let k = vec3<f32>(1.0, 2.0 / 3.0, 1.0 / 3.0);
    let p = abs(fract(vec3<f32>(h) + k) * 6.0 - vec3<f32>(3.0));
    return v * mix(vec3<f32>(1.0), clamp(p - vec3<f32>(1.0), vec3<f32>(0.0), vec3<f32>(1.0)), s);
}

// Rainbow albedo from the hidden 4th dimension, literally: hue is the
// ROTATED point's raw w coordinate — depth into the 4th dimension. As the
// (w,x) sweep advances, every material cell's w changes, so the rainbow
// genuinely warps across the surface (v2 colored by the angle of the very
// circle doing the rotating, which slid points along their own hue bands —
// a static color field by construction). No periodicity constraint: the
// net loop transform is the identity. The 0.83 scale spans the full
// rainbow without hue 1.0 (red) wrapping back onto hue 0.0 (red).
// Saturation is subtly modulated by the (y,z)-plane angle as a faint
// second visible 4D direction. Gamma-down deepens the hue so it survives
// the additive light terms + ACES highlight rolloff.
fn surface_albedo(q: vec4<f32>) -> vec3<f32> {
    let hue = (q.w + 1.0) * 0.5 * 0.83;
    let xi2 = atan2(q.z, q.y);
    let sat = 0.62 + 0.18 * (0.5 + 0.5 * cos(4.0 * xi2));
    return pow(hsv2rgb(hue, sat, 0.95), vec3<f32>(1.7));
}

// Darker deep-space gradient + faint warm halo behind the object so the
// silhouette separates from the background.
fn bg_color(rd: vec3<f32>, fwd: vec3<f32>) -> vec3<f32> {
    let deep = vec3<f32>(0.004, 0.010, 0.040);
    let blue = vec3<f32>(0.012, 0.060, 0.235);
    let t = clamp(0.5 + 0.6 * rd.y, 0.0, 1.0);
    var c = mix(deep, blue, t * t);
    let halo = pow(clamp(dot(rd, fwd), 0.0, 1.0), 20.0);
    c = c + vec3<f32>(0.085, 0.060, 0.025) * halo;
    return c;
}

// 5-tap ambient occlusion along the normal: fractal recesses go dark.
fn calc_ao(p: vec3<f32>, n: vec3<f32>) -> f32 {
    var occ = 0.0;
    var sca = 1.0;
    for (var i: i32 = 0; i < 5; i = i + 1) {
        let h = 0.012 + 0.14 * f32(i) / 4.0;
        let d = map_scene(p + n * h);
        occ = occ + (h - d) * sca;
        sca = sca * 0.72;
    }
    return clamp(1.0 - 2.2 * occ, 0.0, 1.0);
}

// Raymarched soft shadow toward the key light.
fn soft_shadow(ro: vec3<f32>, rd: vec3<f32>, tmin: f32, tmax: f32, k: f32) -> f32 {
    var res = 1.0;
    var t = tmin;
    for (var i: i32 = 0; i < 48; i = i + 1) {
        let d = map_scene(ro + rd * t);
        res = min(res, k * d / t);
        t = t + clamp(d, 0.012, 0.35);
        if (res < 0.005 || t > tmax) {
            break;
        }
    }
    return clamp(res, 0.0, 1.0);
}

fn shade(p: vec3<f32>, rd: vec3<f32>) -> vec3<f32> {
    let n = calc_normal(p);
    let q = rot4(inv_stereo(p)); // rotated 4D surface point on S^3
    let base = surface_albedo(q);

    // Key light tied to the (fixed) camera azimuth (offset ~63 degrees,
    // moderately elevated) — raking light so relief and cast shadows stay
    // visible while the lit side faces the viewer.
    let l1 = normalize(vec3<f32>(cos(CAM_ANG + 1.1), 0.55, sin(CAM_ANG + 1.1)));
    // Weak cool fill from the opposite low side.
    let l2 = normalize(vec3<f32>(-cos(CAM_ANG + 1.1), -0.25, -sin(CAM_ANG + 1.1)));

    let ao = calc_ao(p, n);
    let sh = soft_shadow(p + n * 0.02, l1, 0.035, 6.0, 9.0);

    let dif1 = clamp(dot(n, l1), 0.0, 1.0) * sh;
    let dif2 = clamp(dot(n, l2), 0.0, 1.0);

    let h1 = normalize(l1 - rd);
    let spec = pow(clamp(dot(n, h1), 0.0, 1.0), 64.0) * sh;
    let fres = pow(clamp(1.0 + dot(n, rd), 0.0, 1.0), 3.0);
    let rim = fres * clamp(0.5 + 0.5 * dot(n, l1), 0.0, 1.0);

    var col = base * vec3<f32>(0.35, 0.42, 0.65) * (0.30 * ao);          // dim cool ambient
    col = col + base * dif1 * vec3<f32>(1.0, 0.95, 0.82) * 1.4;          // strong warm key
    col = col + base * dif2 * vec3<f32>(0.30, 0.40, 0.75) * 0.35 * ao;   // cool fill
    col = col + vec3<f32>(1.0, 0.97, 0.90) * spec * 0.9;
    col = col + vec3<f32>(0.75, 0.85, 1.0) * rim * 0.32 * ao;            // cool rim
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

// ACES filmic tonemap (input and output linear; the sRGB target encodes).
fn aces(x: vec3<f32>) -> vec3<f32> {
    let a = 2.51;
    let b = 0.03;
    let c = 2.43;
    let d = 0.59;
    let e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), vec3<f32>(0.0), vec3<f32>(1.0));
}

fn render(ro: vec3<f32>, rd: vec3<f32>) -> vec3<f32> {
    let fwd = normalize(-ro);
    var col = bg_color(rd, fwd);
    let t1 = march(ro, rd, 0.0, 200);
    if (t1 > 0.0) {
        col = shade(ro + rd * t1, rd);
        // mild distance fade for depth separation of the far interior
        let fog = 1.0 - exp(-0.010 * t1 * t1);
        col = mix(col, vec3<f32>(0.006, 0.016, 0.06), fog * 0.55);
    }
    return aces(col * 1.12);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    // Static camera: v2's phase-0 viewpoint, no orbit, no bob.
    let ro = vec3<f32>(7.2 * cos(CAM_ANG), 3.3, 7.2 * sin(CAM_ANG));
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
    // subtle radial vignette
    let q = pos.xy / res - vec2<f32>(0.5);
    let vig = 1.0 - 0.45 * smoothstep(0.45, 1.05, length(q) * 2.0);
    col = col * vig;
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}
