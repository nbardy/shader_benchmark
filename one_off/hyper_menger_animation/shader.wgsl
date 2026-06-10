// Animated, re-shaded "hyper Menger cube on a 3-sphere" — v5: v4's two
// interacting pole-moving sweeps + a BREATHING SLICE RADIUS.
//
// Derived from shader_original.wgsl (benchmark output, run 2cebf07b /
// 000_hyper_menger_cube_3sphere). Geometry pipeline is unchanged:
// inverse stereographic lift R^3 -> S^3, 4D rotation, 4D Menger
// tesseract distance estimator, conservative 3D step.
//
// v5 design (adds on top of v4, which stays exactly as is):
//
//   Evaluate the Menger DE at  r(t) * G(t) * q_lift  (scale AFTER the
//   rotation, before the DE), i.e. slice the tesseract with a sphere of
//   radius r(t) instead of the unit sphere:
//
//     r(t) = R_MID + R_AMP * sin(TAU * t / LOOP_SECONDS + R_PHI)
//
//   One full breath per 24 s loop (period = LOOP_SECONDS -> seamless).
//   WHY THIS IS STRUCTURAL, NOT A ZOOM: the visible object is
//   (Menger tesseract) INTERSECT (sphere of radius r). The cube [-1,1]^4
//   has inradius 1 (face centers) and circumradius 2 (corners), so as r
//   crosses those shells the intersection CHANGES TOPOLOGY — corners
//   pierce the sphere as separate caps, caps merge across edges, tunnel
//   systems connect — cavities open because the topology changed, not by
//   sweep-alignment luck. Points with r != 1 leave S^3; that's fine — the
//   DE is a true R^4 distance, so marching still works, only the
//   R^3-step conversion gains a factor r (see map_scene).
//   Radius window chosen empirically (rotation frozen at t=0, stills at
//   r in {0.6, 0.65, 0.8, 1.0, 1.2, 1.4, 1.5, 1.55, 1.6, 1.7, 2.0}):
//     r ~ 0.6-0.7  lobed slice through the CENTRAL TUNNEL system (the
//                  sphere is inside the inradius shell; only the axis
//                  tunnels cut it, carving merged lobes with windows)
//     r ~ 0.8-1.2  perforated ball (the v4 regime at r = 1)
//     r ~ 1.4-1.6  tunnel mouths PIERCE the ball and widen into large
//                  openings; nested interior shells become visible
//     r ~ 1.7      sparse thin wheel (still rich but small silhouette)
//     r = 2.0      empty — corners sit at |corner| = 2 exactly, the caps
//                  have measure zero. Dropped.
//   Window [0.64, 1.60]: R_MID = 1.12, R_AMP = 0.48. The sine lingers at
//   the two exotic regimes (tunnel-lobes / open wheel) and transits the
//   familiar perforated ball quickly; both topology-change events (lobes
//   merging into the ball, tunnel mouths piercing through) happen every
//   breath. NOTE the slice topology is rotation-INVARIANT (sphere_r and
//   G commute: sphere_r INTERSECT G*Menger = G*(sphere_r INTERSECT
//   Menger)), so no rotation phase can empty a radius that is non-empty
//   at t=0 — only the projection (which face is near the pole) varies.
//   R_PHI = 0 puts t=0 mid-breath (r rising through R_MID), not at an
//   extreme.
//
// v4 design (adds a second sweep on top of v3, which stays exactly as is):
//
//   G(t) = R_wx(PRE_WX + TAU*t/12) o R_wu(TAU*t/24) o R_yz(PRE_YZ)
//
//   The v3 fast (w,x) sweep (one turn per 12 s, reads bottom-right ->
//   top-left on screen) is composed with a 2x-slower simple rotation in the
//   (w,u)-plane, u = (y+z)/sqrt(2) — a unit SPATIAL direction chosen
//   empirically so its sweep reads bottom-left -> top-right on screen (the
//   opposite diagonal). Both planes contain w, so BOTH rotations move the
//   projection pole and morph the visible surface (see v3 notes below: a
//   plane avoiding w is just a rigid screen swirl — never animate one).
//   The two factors do NOT commute (their planes share the w axis), which
//   is fine: one composition order is fixed (slow first, fast second).
//   LOOP CLOSURE despite non-commutativity: LOOP_SECONDS = 24, so at t=24
//   the fast factor has made exactly 2 full turns and the slow factor
//   exactly 1 full turn — EACH factor is individually the identity, hence
//   G(24) = I regardless of order, and the seam closes for any color field.
//
// v3 design notes (kept; replaces v2's SU(2)xSU(2) double isoclinic action):
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
//   ANIMATION - (v3) a SINGLE simple rotation in the (w,x)-plane only (a
//              plane containing the pole — pure slice-sweep, no swirl):
//                  alpha = TAU * time / FAST_SECONDS
//              The object passes "through infinity" once per fast turn. A
//              constant aesthetic pre-rotation (PRE_WX / PRE_YZ, v2's base
//              orientation) is applied first; any fixed pre-rotation keeps
//              the net loop transform identity. (v4 composes the slow
//              (w,u) sweep with this — see the v4 notes above.)
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
// v4: loop doubled to 24 s — the fast (w,x) factor (period 12 s) makes 2
// full turns and the slow (w,u) factor (period 24 s) makes 1 full turn, so
// each factor is individually the identity at t = LOOP_SECONDS.
const LOOP_SECONDS: f32 = 24.0;
const FAST_SECONDS: f32 = 12.0; // v3's (w,x) sweep period, unchanged
// Slow sweep direction: unit spatial vector u = (y+z)/sqrt(2), lifted to
// e_u = (0, u) in R^4 (zero w component, so e_u is orthogonal to the pole
// axis e_w). Chosen empirically from candidates {y, z, (y+z)/sqrt2,
// (y-z)/sqrt2}: with this camera azimuth and pre-rotation, the slow-only
// (w,u) sweep opens its cut-in cavity at the bottom-LEFT and erodes toward
// the top-right — the opposite screen diagonal to v3's fast sweep.
const SLOW_U: vec3<f32> = vec3<f32>(0.0, 0.7071067811865476, 0.7071067811865476);
// Constant phase offset of the slow factor. Any constant still closes the
// loop (the slow factor completes a full turn, so R_wu(TAU + phi0) =
// R_wu(phi0) = the t=0 value). Kept 0.0: the two pole passages stay well
// separated over the 24 s loop (verified frame-by-frame, no blank stretch).
const SLOW_PHI0: f32 = 0.0;

// v5 breathing slice radius r(t) = R_MID + R_AMP*sin(TAU*t/LOOP + R_PHI).
// One full breath per loop -> seamless. Window picked empirically; see the
// header notes. R_PHI = 0 so t=0 sits mid-breath (r = R_MID, growing),
// never at a sine extreme.
const R_MID: f32 = 1.12;
const R_AMP: f32 = 0.48;
const R_PHI: f32 = 0.0;

fn breath_r() -> f32 {
    return R_MID + R_AMP * sin(TAU * params.time / LOOP_SECONDS + R_PHI);
}

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

// Simple rotation in the (w,u)-plane for a unit spatial direction u
// (e_u = (u, 0_w), orthonormal to e_w since its w component is zero).
// General plane-rotation formula
//   q' = q + (cos a - 1)(<q,e_w> e_w + <q,e_u> e_u)
//          + sin a (<q,e_w> e_u - <q,e_u> e_w)
// specialised to this layout; for u = e_x it reduces exactly to rot_wx
// (same sign convention). Fixes the orthogonal complement of span{e_w,e_u}
// pointwise and preserves |q|. The plane CONTAINS the pole axis, so this is
// a pole-moving sweep, like rot_wx but along a different spatial direction.
fn rot_wu(q: vec4<f32>, u: vec3<f32>, a: f32) -> vec4<f32> {
    let c = cos(a);
    let s = sin(a);
    let qu = dot(q.xyz, u);
    let xyz = q.xyz + ((c - 1.0) * qu + s * q.w) * u;
    let w = q.w * c - s * qu;
    return vec4<f32>(xyz, w);
}

// v4 action: fixed pre-rotation, then the slow (w,u) sweep (1 turn per
// loop), then v3's fast (w,x) sweep (2 turns per loop). The factors don't
// commute (both planes contain w); this order — slow inside, fast outside —
// is the one fixed choice. At t = LOOP_SECONDS each factor is individually
// the identity, so the composition is too, and the seam closes exactly for
// any color field.
fn rot4(q: vec4<f32>) -> vec4<f32> {
    let alpha_fast = TAU * params.time / FAST_SECONDS;
    let alpha_slow = TAU * params.time / LOOP_SECONDS + SLOW_PHI0;
    return rot_wx(rot_wu(rot_yz(q, PRE_YZ), SLOW_U, alpha_slow), PRE_WX + alpha_fast);
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
    // v5: scale AFTER the rotation, before the DE — slice the tesseract
    // with the breathing sphere of radius r(t). The composed map
    // p -> r * G(t) * lift(p) has local Lipschitz constant r * lambda
    // (lift conformal factor lambda, rotation isometric, scaling exactly
    // r), so the conservative R^3 step divides by r as well. CLIP_R/TMAX
    // are unaffected: marching still happens in the same projected ball.
    let r = breath_r();
    let q = r * rot4(inv_stereo(p));
    let d4 = menger4(q);
    let lambda = 2.0 / (1.0 + dot(p, p));
    let dm = (d4 / (lambda * r)) * 0.6;
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
// v5 HUE NORMALIZATION: the DE now sees q_eval = r(t) * G(t) * q_lift with
// |q_eval| = r(t), so q_eval.w spans [-r, r] and the old formula would
// clip out of the hue range at r > 1 (and compress at r < 1). The caller
// therefore passes the UNIT rotated point (q_eval / r == G(t) * q_lift),
// which makes this formula exactly (q_eval.w / r + 1)/2 * 0.83 — the
// rainbow stays in range at every radius. atan2(q.z, q.y) is
// scale-invariant, so saturation is unaffected either way.
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
    // UNIT rotated 4D point (NOT scaled by r): this is q_eval / r(t), the
    // v5 hue normalization — see surface_albedo.
    let q = rot4(inv_stereo(p));
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
