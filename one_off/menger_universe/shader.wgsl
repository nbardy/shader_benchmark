// MENGER UNIVERSE — the inside of a closed spherical universe.
//
// The camera lives ON the unit 3-sphere S^3 in R^4 and raymarches along
// great-circle geodesics through a 4D Menger-sponge lattice (the sponge's
// intersection with S^3 fills the universe with fractal walls). This is
// intrinsic non-Euclidean (spherical) rendering: there is no "outside" —
// rays wrap around the universe, so you see multiple images of the same
// structure, light from the far side, and (at arc pi) the antipodal
// refocusing of the point light.
//
// GEODESIC MODEL
//   camera   c in S^3 (unit 4-vector), orthonormal tangent frame {f1,f2,f3}
//            (all perpendicular to c and to each other).
//   pixel    tangent dir d = normalize(uv.x*f1 + uv.y*f2 + focal*f3); d _|_ c.
//   ray      gamma(s) = cos(s)*c + sin(s)*d,  s = arc length in [0, 2*pi].
//            gamma stays exactly on S^3; s = 2*pi returns to the camera.
//
// WHY SPHERE TRACING IS SOUND HERE: menger4 bounds the R^4 (chord) distance
// to the sponge surface. For two points of S^3 at arc distance sigma the
// chord is 2*sin(sigma/2) <= sigma, so the chord bound is also an arc-length
// bound: stepping s += DE never overshoots on-sphere material. We still use
// DE*0.8 for float safety.
//
// SCENE CALIBRATION (found numerically, see README): the sponge is enlarged
// by 1/0.82 relative to S^3 (de(p) = menger4(0.82*p)/0.82). At this scale
// the w-x great circle { (sin a, 0, 0, cos a) } threads the sponge with
// min DE = +0.025 along its whole length — a naturally open closed geodesic
// the camera can circumnavigate without ever entering material. At scale
// 1.0 (and almost every other scale) every great circle clips thin walls.
//
// LIGHTING (intrinsic S^3): one fixed point light L on the sphere.
//   arc distance  delta = acos(dot(p, L))
//   flux focusing 1/sin^2(delta)  — geodesics from a point on S^3 refocus
//   at the antipode, so the light re-brightens BOTH near delta=0 and near
//   delta=pi (a glow from "the far side of the universe"); we clamp gently
//   and let it happen. Tangent light direction at p: normalize(L-dot(L,p)p).
//   A dim headlight at the camera keeps near walls readable, and a cheap
//   inscatter term along the march makes the light (and its antipodal
//   ghost) visible as a glow in the fog.
//
// COLOR: hue from the hit point's raw w coordinate, hue = (p.w+1)/2 * 0.83
// through hsv2rgb — consistent with the sibling hyper_menger_animation.
//
// ANIMATION: the camera rides the open geodesic, c(t) = cos(a)c0 + sin(a)u0
// with a = TAU*t/LOOP_SECONDS, c0 = +e_w, u0 = +e_x. Velocity
// f3 = -sin(a)c0 + cos(a)u0 is the forward seed; e_y, e_z are constant
// right/up seeds (always tangent, never parallel to f3 — Gram-Schmidt can
// never degenerate, so the frame cannot flip). View is tilted slightly off
// the motion axis for parallax. LOOP_SECONDS = 24 is one exact
// circumnavigation of the universe: c(24) = c(0), seamless loop.

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

const LOOP_SECONDS: f32 = 24.0;   // one full circumnavigation per loop
// 5 iterations: the antipodal lens (s -> pi) magnifies a tiny wall patch to
// fill the corridor end — without fine fractal detail it reads as a flat
// slab; the 5th iteration gives it structure at the magnified scale.
const MENGER_ITERS: i32 = 5;

// Sponge scale: structure enlarged by 1/SCALE relative to S^3. 0.82 is the
// calibrated value that opens the w-x great circle (min DE +0.025 along the
// camera's whole orbit). Do not change casually — most scales close it.
const SCALE: f32 = 0.82;

// March parameters. The open channel has DE ~0.02-0.05, so traversing the
// full 2*pi wrap takes hundreds of small steps — 900 is sized so corridor
// rays reach the far structure instead of crawling out into a fog slab.
const S_MAX: f32 = TAU;          // one full wrap of the universe
const MAX_STEPS: i32 = 900;
const STEP_SAFETY: f32 = 0.8;

// Fog: extinction over a few radians of arc, so wrapped second images read
// as distant but still visible. Transmission: 0.39 at s=pi, 0.15 at s=2pi.
const FOG_K: f32 = 0.24;
const FOG_COLOR: vec3<f32> = vec3<f32>(0.012, 0.020, 0.052);

// Fixed point light on S^3. Has components in the camera-orbit plane (w,x)
// so the camera-light arc distance breathes over the loop (bright passes
// and far/dim passes), and off-plane components so the camera never sits
// exactly on the light.
const LIGHT_POS: vec4<f32> = vec4<f32>(0.55, 0.55, 0.45, 0.43); // normalized below

// View tilt off the motion axis (radians-ish, mixed into the forward seed)
// so the corridor sits off-center and nearby walls rake across the frame.
const TILT_X: f32 = 0.18;
const TILT_Y: f32 = 0.12;
const FOCAL: f32 = 1.15;

// ---------------------------------------------------------------------------
// 4D Menger tesseract distance estimator (from hyper_menger_animation).
// ---------------------------------------------------------------------------
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

// Scene DE: the sponge enlarged by 1/SCALE. Dividing by SCALE keeps it a
// valid R^4 distance bound (and hence an arc-length bound, see header).
fn scene_de(p: vec4<f32>) -> f32 {
    return menger4(p * SCALE) / SCALE;
}

// R^4 gradient of the DE (central differences), projected into the tangent
// space of S^3 at p: n = normalize(g - dot(g,p)*p). The radial component is
// meaningless on the sphere — only the tangential normal lights correctly.
fn surface_normal(p: vec4<f32>) -> vec4<f32> {
    let h = 0.0011;
    let gx = scene_de(p + vec4<f32>(h, 0.0, 0.0, 0.0)) - scene_de(p - vec4<f32>(h, 0.0, 0.0, 0.0));
    let gy = scene_de(p + vec4<f32>(0.0, h, 0.0, 0.0)) - scene_de(p - vec4<f32>(0.0, h, 0.0, 0.0));
    let gz = scene_de(p + vec4<f32>(0.0, 0.0, h, 0.0)) - scene_de(p - vec4<f32>(0.0, 0.0, h, 0.0));
    let gw = scene_de(p + vec4<f32>(0.0, 0.0, 0.0, h)) - scene_de(p - vec4<f32>(0.0, 0.0, 0.0, h));
    let g = vec4<f32>(gx, gy, gz, gw);
    return normalize(g - dot(g, p) * p);
}

fn hsv2rgb(h: f32, s: f32, v: f32) -> vec3<f32> {
    let k = vec3<f32>(1.0, 2.0 / 3.0, 1.0 / 3.0);
    let p = abs(fract(vec3<f32>(h) + k) * 6.0 - vec3<f32>(3.0));
    return v * mix(vec3<f32>(1.0), clamp(p - vec3<f32>(1.0), vec3<f32>(0.0), vec3<f32>(1.0)), s);
}

// ACES filmic tonemap.
fn aces(x: vec3<f32>) -> vec3<f32> {
    let a = 2.51;
    let b = 0.03;
    let c = 2.43;
    let d = 0.59;
    let e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), vec3<f32>(0.0), vec3<f32>(1.0));
}

// Hue from depth into the 4th dimension — the hit point's raw w coordinate.
fn surface_albedo(p: vec4<f32>) -> vec3<f32> {
    let hue = (p.w + 1.0) * 0.5 * 0.83;
    let xi2 = atan2(p.z, p.y);
    let sat = 0.72 + 0.16 * (0.5 + 0.5 * cos(4.0 * xi2));
    return pow(hsv2rgb(hue, sat, 0.88), vec3<f32>(1.8));
}

// S^3 point-light flux: geodesic spreading on the 3-sphere goes as
// 1/sin^2(delta) — flux refocuses at the antipode. sin^2 = 1 - cos^2, the
// +0.04 clamps both singularities gently (max gain ~25x).
fn s3_light_atten(cos_delta: f32) -> f32 {
    return 1.0 / (1.0 - cos_delta * cos_delta + 0.04);
}

// Ambient occlusion: 5 DE taps marching along the (tangent) normal,
// re-normalized onto S^3 so the samples stay in the universe.
fn calc_ao(p: vec4<f32>, n: vec4<f32>) -> f32 {
    var occ = 0.0;
    var sca = 1.0;
    for (var i: i32 = 0; i < 5; i = i + 1) {
        let h = 0.012 + 0.12 * f32(i) / 4.0;
        let q = normalize(p + n * h);
        occ = occ + (h - scene_de(q)) * sca;
        sca = sca * 0.72;
    }
    return clamp(1.0 - 2.6 * occ, 0.0, 1.0);
}

// Soft shadow along the geodesic from p toward the light: walk the great
// circle q(sig) = cos(sig)p + sin(sig)lt up to just short of the light's
// arc distance. Same arc-length bound argument as the primary march.
fn soft_shadow(p: vec4<f32>, lt: vec4<f32>, arc_to_light: f32) -> f32 {
    var res = 1.0;
    var sig = 0.03;
    let sig_max = arc_to_light - 0.05;
    for (var i: i32 = 0; i < 80; i = i + 1) {
        let q = cos(sig) * p + sin(sig) * lt;
        let de = scene_de(q);
        res = min(res, 10.0 * de / sig);
        sig = sig + clamp(de, 0.008, 0.20);
        if (res < 0.005 || sig > sig_max) {
            break;
        }
    }
    return clamp(res, 0.0, 1.0);
}

struct MarchResult {
    s: f32,        // arc length at exit
    de: f32,       // DE at exit (hit test: de < eps)
    glow: f32,     // accumulated inscatter from the point light
    halo: f32,     // inscatter from the HEADLIGHT's antipodal refocus: fog
                   // near the camera's antipode glows with the camera's own
                   // returned light — the luminous disk at the corridor end
};

// Sphere-trace along the geodesic gamma(s) = cos(s)c + sin(s)d.
fn march(c: vec4<f32>, d: vec4<f32>, lpos: vec4<f32>) -> MarchResult {
    var s = 0.012;
    var de = 1.0;
    var glow = 0.0;
    var halo = 0.0;
    for (var i: i32 = 0; i < MAX_STEPS; i = i + 1) {
        let p = cos(s) * c + sin(s) * d;
        de = scene_de(p);
        let eps = 0.0012 + 0.0009 * s;
        if (de < eps || s > S_MAX) {
            break;
        }
        let step = de * STEP_SAFETY;
        // inscatter: fog near the light glows; the 1/sin^2 focusing makes
        // both the light and its antipodal ghost visible as halos. The
        // light's own arc through the fog extinguishes it too.
        let cl = clamp(dot(p, lpos), -1.0, 1.0);
        glow = glow + step * exp(-FOG_K * (s + acos(cl))) * s3_light_atten(cl);
        // headlight inscatter: only its antipodal refocus matters visually
        // (near the camera it is just uniform veiling glare), so gate to the
        // hemisphere around the antipode.
        let cc = clamp(dot(p, c), -1.0, 1.0);
        halo = halo + step * exp(-FOG_K * (s + acos(cc))) * s3_light_atten(cc)
            * smoothstep(0.0, 0.6, -cc);
        s = s + step;
    }
    return MarchResult(s, de, glow, halo);
}

fn shade(p: vec4<f32>, view_t: vec4<f32>, cam: vec4<f32>, lpos: vec4<f32>) -> vec3<f32> {
    let n = surface_normal(p);
    let base = surface_albedo(p);
    let ao = calc_ao(p, n);

    // Key light: intrinsic point light at lpos, with geodesic soft shadows.
    // Near the light's ANTIPODE the tangent direction normalize(L - cos*p)
    // degenerates — physically the refocused light arrives from all
    // directions there, so we blend the diffuse term toward isotropic (and
    // disable the now-meaningless shadow ray). Light is also extinguished by
    // the same fog the camera sees, exp(-FOG_K * arc), which keeps the
    // antipodal ghost a gentle glow instead of a 25x blowout.
    let cos_dl = clamp(dot(p, lpos), -1.0, 1.0);
    let arc_dl = acos(cos_dl);
    let antip_l = smoothstep(0.92, 0.995, -cos_dl);
    let lt = normalize(lpos - cos_dl * p + vec4<f32>(1e-5));
    let sh = mix(soft_shadow(normalize(p + n * 0.012), lt, arc_dl), 1.0, antip_l);
    let dif_l = mix(clamp(dot(n, lt), 0.0, 1.0), 0.55, antip_l);
    let key = dif_l * s3_light_atten(cos_dl) * exp(-FOG_K * arc_dl) * sh;

    // Headlight: dim light at the camera position (same S^3 physics) so the
    // nearest walls always read; its antipodal refocus paints a soft glowing
    // disk on the far side of the universe — light from your own position,
    // sent all the way around. Same antipode handling as the key.
    let cos_dc = clamp(dot(p, cam), -1.0, 1.0);
    let arc_dc = acos(cos_dc);
    let antip_h = smoothstep(0.92, 0.995, -cos_dc);
    let ht = normalize(cam - cos_dc * p + vec4<f32>(1e-5));
    let dif_h = mix(clamp(dot(n, ht), 0.0, 1.0), 0.55, antip_h);
    let head = dif_h * s3_light_atten(cos_dc) * exp(-FOG_K * arc_dc);

    // Specular + fresnel rim against the incoming geodesic direction.
    let hvec = normalize(lt - view_t);
    let spec = pow(clamp(dot(n, hvec), 0.0, 1.0), 48.0)
        * s3_light_atten(cos_dl) * exp(-FOG_K * arc_dl) * sh * (1.0 - antip_l);
    let fres = pow(clamp(1.0 + dot(n, view_t), 0.0, 1.0), 3.0);

    var col = base * vec3<f32>(0.30, 0.36, 0.58) * (0.10 * ao);          // cool ambient
    col = col + base * key * vec3<f32>(1.0, 0.93, 0.80) * 1.60;          // warm key
    col = col + base * head * vec3<f32>(0.45, 0.55, 0.85) * 0.16 * ao;   // cool headlight
    col = col + vec3<f32>(1.0, 0.96, 0.88) * spec * 0.30;
    col = col + vec3<f32>(0.70, 0.80, 1.0) * fres * 0.06 * ao;           // rim
    return col;
}

fn render(c: vec4<f32>, d: vec4<f32>, lpos: vec4<f32>) -> vec3<f32> {
    let m = march(c, d, lpos);
    let hit_eps = 0.0012 + 0.0009 * m.s;
    let transmit = exp(-FOG_K * m.s);

    var col = FOG_COLOR; // miss: ray wrapped (or crawled out) into fog
    if (m.de < hit_eps * 4.0) {
        let p = normalize(cos(m.s) * c + sin(m.s) * d);
        let view_t = -sin(m.s) * c + cos(m.s) * d;   // geodesic dir at hit
        col = shade(p, view_t, c, lpos);
    }
    col = mix(FOG_COLOR, col, transmit);
    col = col + vec3<f32>(1.0, 0.88, 0.62) * m.glow * 0.018; // light + ghost
    col = col + vec3<f32>(0.55, 0.70, 1.0) * m.halo * 0.013; // antipodal disk
    return aces(col * 1.15);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let res = params.resolution;
    let lpos = normalize(LIGHT_POS);

    // Camera on its closed geodesic: one circumnavigation per LOOP_SECONDS.
    let alpha = TAU * params.time / LOOP_SECONDS;
    let c0 = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    let u0 = vec4<f32>(1.0, 0.0, 0.0, 0.0);
    let cam = cos(alpha) * c0 + sin(alpha) * u0;     // position on S^3
    let vel = -sin(alpha) * c0 + cos(alpha) * u0;    // unit tangent: forward

    // Constant tangent seeds (always orthogonal to both cam and vel by
    // construction, so Gram-Schmidt below never degenerates or flips).
    let e1 = vec4<f32>(0.0, 1.0, 0.0, 0.0);
    let e2 = vec4<f32>(0.0, 0.0, 1.0, 0.0);

    // Slightly off-axis forward for parallax, then Gram-Schmidt the frame.
    var fwd = vel + TILT_X * e1 + TILT_Y * e2;
    fwd = normalize(fwd - dot(fwd, cam) * cam);
    var right = e1 - dot(e1, cam) * cam - dot(e1, fwd) * fwd;
    right = normalize(right);
    var up = e2 - dot(e2, cam) * cam - dot(e2, fwd) * fwd - dot(e2, right) * right;
    up = normalize(up);

    var col = vec3<f32>(0.0);
    // 2x2 supersampling
    for (var sy: i32 = 0; sy < 2; sy = sy + 1) {
        for (var sx: i32 = 0; sx < 2; sx = sx + 1) {
            let off = vec2<f32>(f32(sx), f32(sy)) * 0.5 - 0.25;
            let frag = pos.xy + off;
            let ndc = (2.0 * frag - res) / res.y;
            let uv = vec2<f32>(ndc.x, -ndc.y);
            // tangent ray dir: d _|_ cam by construction, |d| = 1
            let d = normalize(uv.x * right + uv.y * up + FOCAL * fwd);
            col = col + render(cam, d, lpos);
        }
    }
    col = col * 0.25;
    // subtle vignette
    let q = pos.xy / res - vec2<f32>(0.5);
    let vig = 1.0 - 0.40 * smoothstep(0.45, 1.05, length(q) * 2.0);
    col = col * vig;
    return vec4<f32>(clamp(col, vec3<f32>(0.0), vec3<f32>(1.0)), 1.0);
}
