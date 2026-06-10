# Hyper Menger Cube on a 3-Sphere — Animated Loop

`shader_original.wgsl` is an untouched benchmark output (run `2cebf07b_cli_claude_claude-fable-5_high`, problem `000_hyper_menger_cube_3sphere`): a 4D Menger tesseract DE evaluated on the unit 3-sphere via inverse stereographic projection, raymarched in R^3. `shader.wgsl` (v3) keeps that geometry pipeline unchanged but reworks the shading, animation math, and color, and loops seamlessly every 12 seconds. `menger_3sphere.mp4` is the current v3 render; `menger_3sphere_v2.mp4` is the previous version.

## Shading (unchanged since v2)

The washed-out 0.8-alpha translucent two-layer blend was replaced with an opaque surface lit by a strong warm key light with raymarched soft shadows, 5-tap ambient occlusion (the Menger holes read dark), a cool rim light to separate the silhouette, ACES tonemapping, a darker gradient background with a faint halo behind the object, and a radial vignette.

## Animation v3: one pole-moving rotation (and why v2 failed)

**Pole-moving vs pole-fixing.** Every visible point lifts to `q ∈ S³ ⊂ R⁴` via inverse stereographic projection with the pole on the **w axis** (`inv_stereo` stores xyzw with the quaternion scalar in `.w`; `p → ∞` maps to `+e_w`). The SO(4) rotations split into two kinds relative to that pole:

- Rotations that **fix the w axis** (e.g. any rotation in the (x,y), (y,z), (x,z) planes) commute with stereographic projection, so they appear in R³ as **rigid 3D rotations** of the projected set — the ball just swirls.
- Rotations that **move the pole** (any plane containing w) re-slice the fractal relative to the projection point — the projected surface **morphs**: cavities open, shells dissolve, the object sweeps "through infinity".

v2 used two commuting isoclinic actions `q → L q R` about the axis i. That pair decomposes into a pole-moving (w,x) component advancing −1 quarter-turn/loop and a pole-fixing (y,z) component advancing +3 quarter-turns/loop — so the motion was dominated by rigid swirl with minimal surface morphing. Worse, v2's hue was `ξ1 = atan2(q.x, q.w)`, the angle of the very circle action doing the rotating: the motion slid points along their own hue bands, making the color field static by construction.

**v3** keeps only the part that matters: a **single rotation in the (w,x)-plane** (a plane containing the pole — pure slice-sweep, zero swirl):

```
α = TAU · t / LOOP_SECONDS                  (LOOP_SECONDS = 12)
(w,x) ← (w cosα − x sinα, w sinα + x cosα)   y, z unchanged
```

One **full turn** per loop, so the net loop transform is the **identity** — the seam closes exactly for *any* color field (verified: mean pixel diff between t=0 and t=12 renders is 0.0005/255, pure float jitter). A constant aesthetic pre-rotation (`PRE_WX = 0.23`, `PRE_YZ = 0.87` — the net fixed offsets of v2's base orientation) is applied first; being time-independent it cannot affect loop closure.

A quarter-turn in a coordinate plane is a signed coordinate permutation — an exact symmetry of the Menger tesseract DE — so the **geometry** actually cycles every LOOP/4 = 3 s: perforated sphere → panels dissolve into fine perforation → a scalloped cavity opens revealing a nested inner shell → terraced shells close back up. The **color** (below) has the full 12 s period, so each of the four geometric cycles wears a different stretch of the rainbow. The pole passage is glancing enough at this orientation that no frame goes blank or degenerate (checked at 0.375 s granularity).

**Camera: static.** The v2 orbit and height bob are gone — one fixed viewpoint (v2's phase-0 view, azimuth 0.7). The key light stays tied to the camera azimuth. The 4D sweep provides all the visual change, which makes the morphing unambiguous: nothing in the frame moves rigidly.

## Color v3: the hidden dimension, literally

Albedo hue is the rotated 4D point's **raw w coordinate** — depth into the 4th dimension:

```
hue = (q.w + 1) / 2 · 0.83      (0.83 stops red wrapping back onto red)
```

Because the net loop transform is the identity, no periodicity constraint applies (v2 needed π/2-periodic hue to close its loop, which is exactly what locked its colors to the motion). Now the rainbow genuinely warps: as the (w,x) sweep advances, every material cell's w changes, so hue bands migrate across the surface independent of the (repeating) geometry. Saturation keeps v2's subtle modulation by the (y,z)-plane angle `atan2(q.z, q.y)` (0.62→0.80) as a faint second visible 4D direction, and the albedo is still gamma-deepened (`pow 1.7`) so the hue survives the additive light terms and ACES highlight rolloff.

## Rendering

Re-render with `./render_video.sh` (needs `shader_harness` built release with the `--time` flag, plus ffmpeg). Defaults: 360 frames, 30 fps, 12 s, 1024 px; frame i is rendered at `t = LOOP · i / FRAMES` so the last frame ≠ the first and the video tiles seamlessly. Env overrides: `FRAMES=90 SIZE=512 OUT=preview.mp4 ./render_video.sh` for a quick preview.
