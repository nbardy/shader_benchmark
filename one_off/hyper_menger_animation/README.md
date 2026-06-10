# Hyper Menger Cube on a 3-Sphere — Animated Loop

`shader_original.wgsl` is an untouched benchmark output (run `2cebf07b_cli_claude_claude-fable-5_high`, problem `000_hyper_menger_cube_3sphere`): a 4D Menger tesseract DE evaluated on the unit 3-sphere via inverse stereographic projection, raymarched in R^3. `shader.wgsl` (v5) keeps that geometry pipeline unchanged but reworks the shading, animation math, and color, and loops seamlessly every 24 seconds. `menger_3sphere.mp4` is the current v5 render; `menger_3sphere_v4.mp4`, `menger_3sphere_v3.mp4`, and `menger_3sphere_v2.mp4` are the previous versions.

## Animation v5: breathing slice radius (topology, not zoom)

v5 keeps v4's two sweeps, camera, and lighting untouched and adds one new degree of freedom: the slice radius. The DE is evaluated at `r(t) · G(t) · q_lift` — scale **after** the rotation, before the DE — so the visible object becomes (Menger tesseract) ∩ (sphere of radius r(t)) instead of the unit-sphere slice:

```
r(t) = R_MID + R_AMP · sin(TAU·t / LOOP_SECONDS + R_PHI)
R_MID = 1.12,  R_AMP = 0.48,  R_PHI = 0      →  r ∈ [0.64, 1.60]
```

- **Why this is structural, not a zoom.** The tesseract `[-1,1]⁴` has inradius 1 (face centers) and circumradius 2 (corners). As r crosses those shells the intersection **changes topology**: cavities open because the slice sphere pierces a different stratum of the fractal, not because a sweep happened to align. The breath has one full period per 24 s loop (period = LOOP_SECONDS → the seam still closes; one breath against two fast / one slow sweep turns reads clearly in stills, so the 12 s double-breath alternative was not needed).
- **The radius window, found empirically** (rotation frozen at t=0, 512px stills at r ∈ {0.6, 0.65, 0.8, 1.0, 1.2, 1.4, 1.5, 1.55, 1.6, 1.7, 2.0}):
  - r ≈ 0.6–0.7 — the sphere sits inside the inradius shell and only the **central tunnel system** cuts it: merged bulging lobes with windows.
  - r ≈ 0.8–1.2 — the familiar perforated ball (v4 lives at r = 1).
  - r ≈ 1.4–1.6 — tunnel mouths **pierce through** the ball and widen into large openings; nested interior shells become visible.
  - r ≈ 1.7 — sparse thin wheel (rich but small); r = 2.0 — empty (corners sit at |corner| = 2 exactly, the caps have measure zero). Both dropped.
  
  The window [0.64, 1.60] covers both exotic regimes. Since sin lingers at its extremes, each breath holds the tunnel-lobe and open-wheel phases and transits the perforated ball quickly — two topology-change events per loop (lobes merging up into the ball, tunnel mouths punching through), verified in stills at t = 0, 3, …, 21.
- **Rotation can't break it.** The slice topology at a given r is rotation-invariant: the sphere commutes with G, so `sphere_r ∩ G·Menger = G·(sphere_r ∩ Menger)`. A radius that is non-empty at t=0 is non-empty at every t; only the stereographic projection (which part faces the pole) varies. Points with r ≠ 1 leave S³, which is fine — the Menger DE is a true R⁴ distance, so marching still works.
- **Marching correction.** The composed map `p → r·G·lift(p)` has local Lipschitz constant r·λ (lift conformal factor λ = 2/(1+|p|²), rotation isometric, scaling exactly r), so the conservative R³ step is now `d4 / (λ·r) · 0.6`. `CLIP_R`/`TMAX` are unchanged — marching still happens in the same projected ball, which the silhouette never leaves at r ≤ 1.6.
- **Hue normalization (required fix).** The evaluated point has `|q_eval| = r(t)`, so the v3/v4 formula `(q.w+1)/2·0.83` would clip out of hue range whenever r > 1. v5 colors by the **unit** rotated point — exactly `(q_eval.w / r(t) + 1)/2 · 0.83` — so the rainbow stays in range at every radius (saturation uses `atan2(q.z, q.y)`, which is scale-invariant).
- **Seam:** mean abs pixel diff between t=0 and t=24 renders is 0.0005/255 — pure float jitter, identical magnitude to v3/v4.

## Animation v4: two interacting pole-moving sweeps

v4 keeps the v3 sweep exactly as is and **composes** a second, 2x-slower sweep along the opposite screen diagonal:

```
G(t) = R_wx(PRE_WX + TAU·t/12) ∘ R_wu(TAU·t/24) ∘ R_yz(PRE_YZ)

u = (y+z)/√2,   e_u = (0, u) ⊥ e_w,   LOOP_SECONDS = 24
```

- **Both planes contain w.** Only rotations whose plane contains the projection-pole axis (w) morph the visible surface; a plane avoiding w (e.g. (y,z)) commutes with stereographic projection and is just a rigid screen swirl (the v2 failure — never animate one). The fast (w,x) factor is v3's sweep, reading bottom-right → top-left on screen; the slow (w,u) factor is a second pole-moving sweep along a different spatial direction.
- **Why u = (y+z)/√2.** The on-screen direction of a (w,u) sweep depends on the camera azimuth (0.7) and the fixed pre-rotation, so u was chosen empirically: rendering the slow rotation *alone* at t = 0/3/6 for each candidate u ∈ {y, z, (y+z)/√2, (y−z)/√2} showed y cutting in along v3's own diagonal, z and (y−z)/√2 cutting in at the top-left/top, while **(y+z)/√2** opens its scalloped cavity at the **bottom-left** and erodes toward the **top-right** — the opposite diagonal to v3.
- **Why 2:1 closes at 24 s despite non-commutativity.** The two factors do *not* commute (their planes share the w axis), so one composition order is fixed (slow inside, fast outside). But at t = 24 the fast factor has made exactly **2 full turns** and the slow factor exactly **1 full turn** — each factor is *individually* the identity, so G(24) = I regardless of order and the seam closes for any color field (measured: mean abs pixel diff between t=0 and t=24 renders is 0.0006/255, pure float jitter; t=0 is pixel-identical to v3's t=0).
- A constant phase offset `SLOW_PHI0` on the slow factor is available for separating the two pole passages without breaking closure (a full turn plus any constant lands back on the constant); at this orientation the passages are already well separated, so it stays 0. Verified over t = 0,2,…,22: the cut-in axis visibly precesses around the ball (bottom-right → left → right → top-right → top-left) with no blank or degenerate stretch.

Camera, pre-rotation, lighting, and the hue = raw `q.w` color field are all untouched from v3; the hue now warps under both motions. The geometry no longer has v3's strict 3 s sub-period (the slow factor breaks the quarter-turn symmetry), so all 24 s are distinct.

## Shading (unchanged since v2)

The washed-out 0.8-alpha translucent two-layer blend was replaced with an opaque surface lit by a strong warm key light with raymarched soft shadows, 5-tap ambient occlusion (the Menger holes read dark), a cool rim light to separate the silhouette, ACES tonemapping, a darker gradient background with a faint halo behind the object, and a radial vignette.

## Animation v3: one pole-moving rotation (and why v2 failed) — kept as the fast factor in v4

**Pole-moving vs pole-fixing.** Every visible point lifts to `q ∈ S³ ⊂ R⁴` via inverse stereographic projection with the pole on the **w axis** (`inv_stereo` stores xyzw with the quaternion scalar in `.w`; `p → ∞` maps to `+e_w`). The SO(4) rotations split into two kinds relative to that pole:

- Rotations that **fix the w axis** (e.g. any rotation in the (x,y), (y,z), (x,z) planes) commute with stereographic projection, so they appear in R³ as **rigid 3D rotations** of the projected set — the ball just swirls.
- Rotations that **move the pole** (any plane containing w) re-slice the fractal relative to the projection point — the projected surface **morphs**: cavities open, shells dissolve, the object sweeps "through infinity".

v2 used two commuting isoclinic actions `q → L q R` about the axis i. That pair decomposes into a pole-moving (w,x) component advancing −1 quarter-turn/loop and a pole-fixing (y,z) component advancing +3 quarter-turns/loop — so the motion was dominated by rigid swirl with minimal surface morphing. Worse, v2's hue was `ξ1 = atan2(q.x, q.w)`, the angle of the very circle action doing the rotating: the motion slid points along their own hue bands, making the color field static by construction.

**v3** keeps only the part that matters: a **single rotation in the (w,x)-plane** (a plane containing the pole — pure slice-sweep, zero swirl):

```
α = TAU · t / 12                             (in v4 this period is FAST_SECONDS = 12)
(w,x) ← (w cosα − x sinα, w sinα + x cosα)   y, z unchanged
```

One **full turn** per loop, so the net loop transform is the **identity** — the seam closes exactly for *any* color field (verified: mean pixel diff between t=0 and t=12 renders is 0.0005/255, pure float jitter). A constant aesthetic pre-rotation (`PRE_WX = 0.23`, `PRE_YZ = 0.87` — the net fixed offsets of v2's base orientation) is applied first; being time-independent it cannot affect loop closure.

A quarter-turn in a coordinate plane is a signed coordinate permutation — an exact symmetry of the Menger tesseract DE — so in v3 the **geometry** actually cycled every 3 s: perforated sphere → panels dissolve into fine perforation → a scalloped cavity opens revealing a nested inner shell → terraced shells close back up. The **color** had the full 12 s period, so each of the four geometric cycles wore a different stretch of the rainbow. The pole passage is glancing enough at this orientation that no frame goes blank or degenerate. (In v4 the slow factor breaks this quarter-turn sub-periodicity, so all 24 s are geometrically distinct.)

**Camera: static.** The v2 orbit and height bob are gone — one fixed viewpoint (v2's phase-0 view, azimuth 0.7). The key light stays tied to the camera azimuth. The 4D sweep provides all the visual change, which makes the morphing unambiguous: nothing in the frame moves rigidly.

## Color v3: the hidden dimension, literally

Albedo hue is the rotated 4D point's **raw w coordinate** — depth into the 4th dimension:

```
hue = (q.w + 1) / 2 · 0.83      (0.83 stops red wrapping back onto red)
```

Because the net loop transform is the identity, no periodicity constraint applies (v2 needed π/2-periodic hue to close its loop, which is exactly what locked its colors to the motion). Now the rainbow genuinely warps: as the (w,x) sweep advances, every material cell's w changes, so hue bands migrate across the surface independent of the (repeating) geometry. Saturation keeps v2's subtle modulation by the (y,z)-plane angle `atan2(q.z, q.y)` (0.62→0.80) as a faint second visible 4D direction, and the albedo is still gamma-deepened (`pow 1.7`) so the hue survives the additive light terms and ACES highlight rolloff.

## Rendering

Re-render with `./render_video.sh` (needs `shader_harness` built release with the `--time` flag, plus ffmpeg). Defaults: 720 frames, 30 fps, 24 s, 1024 px; frame i is rendered at `t = LOOP · i / FRAMES` so the last frame ≠ the first and the video tiles seamlessly. Env overrides: `FRAMES=180 SIZE=512 OUT=preview.mp4 ./render_video.sh` for a quick preview.
