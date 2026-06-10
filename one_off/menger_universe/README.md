# Menger Universe — inside a closed spherical cosmos

A self-contained WGSL shader that renders the **inside of a closed spherical
universe**: the camera lives ON the unit 3-sphere S³ ⊂ R⁴ and raymarches along
great-circle geodesics through a 4D Menger-sponge lattice. There is no
"outside" and no Euclidean embedding trick at render time — the marching is
fully intrinsic. Rays wrap around the universe: look down an open corridor and
the far end shows you light from *behind yourself*, refocused by the geometry
of the cosmos.

The 4D Menger distance estimator, `hsv2rgb`, ACES tonemap and the
hue-from-`w` color scheme are taken from the sibling project
`../hyper_menger_animation/` (which renders the same sponge *extrinsically*
via stereographic projection). This project replaces the projection with
intrinsic spherical geometry.

## The geodesic math

**Camera.** The camera position is a unit 4-vector `c ∈ S³` with an
orthonormal tangent frame `{f1, f2, f3}` — all perpendicular to `c` and to
each other (`f3` is "forward").

**Rays.** For a pixel at screen coords `uv`, the ray's initial tangent
direction is

```
d = normalize(uv.x·f1 + uv.y·f2 + focal·f3)      (d ⊥ c by construction)
```

and the ray itself is the great circle

```
γ(s) = cos(s)·c + sin(s)·d,    s = arc length ∈ [0, 2π]
```

`γ` stays exactly on S³; at `s = π` it reaches the camera's antipode and at
`s = 2π` it returns to the camera. We march the full `2π`.

**Sphere tracing on S³.** `menger4` bounds the R⁴ *chord* distance to the
sponge. Two points of S³ at arc distance σ are chord distance
`2·sin(σ/2) ≤ σ` apart, so a chord bound is automatically an arc-length
bound: stepping `s += DE` can never skip on-sphere material. We step
`DE·0.8` for float safety. The open corridor is narrow (DE ≈ 0.02–0.05), so
`MAX_STEPS = 900` lets corridor rays complete the full wrap.

**Normals.** The R⁴ gradient `g` of the DE is meaningless radially (off the
sphere), so it is projected into the tangent space at the hit point:
`n = normalize(g − ⟨g,p⟩·p)`.

**Fog.** Exponential extinction in arc length, `T = exp(−0.24·s)`, so the
wrapped second images read as distant (transmission ≈ 0.47 at s=π, 0.22 at
s=2π). Both lights suffer the same extinction over their own arc to the
surface.

## Antipodal light focusing

One point light sits at a fixed `L ∈ S³`. On a 3-sphere a point source's
flux does **not** fall off as 1/r² forever: geodesics from `L` spread out,
reach maximum dispersion at arc δ = π/2, then *reconverge at the antipode
−L*. The flux through a geodesic sphere of arc radius δ goes as

```
1 / sin²(δ)
```

which blows up at **both** δ→0 (the light itself) and δ→π (its antipodal
ghost — the whole universe acts as a lens and refocuses the light at the
opposite pole). The shader clamps gently (`1/(sin²δ + 0.04)`) and lets the
ghost happen; fog extinction `exp(−k·δ)` keeps it a soft glow rather than a
second sun at full strength.

Near an antipode the tangent direction toward the light,
`normalize(L − ⟨L,p⟩·p)`, degenerates — physically the refocused light
arrives from *all* directions there — so the diffuse term blends toward an
isotropic constant and the (now meaningless) shadow ray is disabled.

The same physics is applied to a dim **headlight at the camera**: its
antipodal refocus paints the soft luminous disk you see at the end of the
corridor — that glow is light from your own position, sent all the way
around the universe. An inscatter term accumulated during the march makes
both the key light and this antipodal disk visible in the fog itself.

Surfaces near `s = π` are the **antipodal lens**: all geodesics through the
camera reconverge at `−c`, so a tiny patch of wall near the antipode is
magnified to fill the corridor end (magnification → ∞ at exactly π). That is
why the 5th Menger iteration exists — without fine detail the magnified
patch reads as a flat slab.

## Scene calibration

The sponge is enlarged by `1/0.82` relative to S³ (`de(p) =
menger4(0.82·p)/0.82`). This value was found numerically: the sponge fills
~53 % of the 3-sphere, and at scale 1.0 (and almost every other scale)
**every** great circle clips a wall somewhere — a uniform sample of 300
random great circles all penetrated material (min DE ≈ −0.01). At scale
0.82 the `(w,x)` coordinate great circle `{(sin α, 0, 0, cos α)}` threads
the sponge with min DE = **+0.025** along its entire length: a naturally
open closed geodesic the camera can circumnavigate.

## Camera animation (exact 24 s loop)

```
c(t)  =  cos(α)·c₀ + sin(α)·u₀,   α = 2π·t / 24,   c₀ = e_w,  u₀ = e_x
f3(t) =  −sin(α)·c₀ + cos(α)·u₀   (velocity — forward seed)
f1, f2 = e_y, e_z                  (constant right/up seeds)
```

One loop = one full circumnavigation of the universe; `c(24) = c(0)`
exactly, so the video tiles seamlessly (verified: max pixel diff 6/255
between t=0 and t=24 renders). The seeds `e_y, e_z` are orthogonal to both
`c(t)` and `f3(t)` for every t, so the Gram-Schmidt frame can never
degenerate or flip. The view is tilted slightly off the motion axis
(`TILT_X/Y`) so near walls rake across the frame for parallax. Hue comes
from the hit point's `w` coordinate (`(p.w+1)/2·0.83`), so the universe
sweeps violet → green → yellow → red → violet as you travel through the
w-dimension and back.

## Files

- `shader.wgsl` — self-contained shader (vertex + fragment, standard
  `Params` uniform contract)
- `render_video.sh` — renders 720 frames @ 30 fps / 1024px and encodes
  `menger_universe.mp4` (env overrides: `FRAMES`, `SIZE`, `FPS`, `OUT`)
- `menger_universe.mp4` — the 24 s seamless loop

```bash
./render_video.sh                      # full quality
FRAMES=180 SIZE=512 ./render_video.sh  # quick preview
```

## Simplifications / honest notes

- The DE is the R⁴ distance to the *full 4D sponge*, not to its intersection
  with S³; off-sphere material can shrink steps that the geodesic would never
  hit. This only slows marching (still a valid bound), never causes misses.
- Shadow rays and AO taps use the same chord-bound argument as primary rays;
  AO samples are re-normalized onto the sphere.
- Volumetric inscatter is a single-scatter approximation accumulated at march
  sample points (not a separate integrator), and the antipodal isotropic
  blend is a smoothstep approximation of the true caustic at the pole.
- Rays that exhaust `MAX_STEPS` while crawling a grazing surface are shaded
  as hits if the final DE is within 4× the hit epsilon; otherwise they fade
  into fog — at `s ≈ 2π` transmission is ~0.2 so the error is invisible.
