# Problem Authoring Format

How to fill in `request.txt` + `critic.txt` for each frontier problem under
`problems/base_set/<slug>/`. The harness expects specific structure — straying
from it makes the judge fall back to generic defaults and degrades scoring.

The 20 frontier slugs are listed in `problems/frontier_list.md`. Each dir
already has `category.txt = "Frontier"` set, plus empty `request.txt` and
`critic.txt`. Your job is to fill those two files for each problem.

## Files per problem

```
problems/base_set/<slug>/
  category.txt   ← already set to "Frontier", do not change
  request.txt    ← FILL IN — generation prompt for the model
  critic.txt     ← FILL IN — judge rubric (specific structure required)
  reference.png  ← only needed for image-reproduction problems (not these 20)
```

## `request.txt` — generation prompt

This is what the shader-coding model sees. It must be self-contained — the
model gets *only* this prompt plus the WGSL constraints already injected by
the harness; it does not have access to external links or data. Free-form
markdown is fine.

Strong prompts for this benchmark have these sections (use whichever apply):

1. **Objective** — 1–2 sentences. What is being visualized.
2. **Mathematical specification** — the equations, parameters, domains.
   Be precise about value ranges, indexing conventions, what's static
   vs. animated. The model has to translate this into WGSL.
3. **Geometry to render** — what concrete primitives appear in the image
   (tubes / surfaces / point clouds / SDFs / fields). Include sizes and
   counts (e.g. "200 fibres at 500 samples each", "50³ voxel grid").
4. **Rendering style** — colors, transparency, lighting, anti-aliasing,
   background. Be explicit (e.g. "HSV hue from longitude φ ∈ [0,2π], white
   background, soft Phong shading, no outlines").
5. **Composition / overlays** — auxiliary elements (legend spheres,
   coordinate axes, scale bars, labels). Specify position and styling.
6. **Technical specs** — resolution (≥ 1600×1600), output format.
7. **Deliverable** — single line, e.g. "A single PNG image satisfying the
   above."

The model produces a static frame (no animation), so for time-evolving
problems pick a representative time `t` (e.g. "render at t = 0.7 of the
flow's first reconnection event"). State this in the request.

For frontier problems specifically, **lean on the math, not on freeform
'make it look cool' language**. The judge scores against measurable
geometric/topological properties — your spec needs to give the judge
something to check against.

### request.txt example (excerpt from `hopf_fibration_base_loops/request.txt`)

```
**Objective**
Produce a single high-resolution image that visualises the pre-images
(fibres) of three prescribed closed curves on the 2-sphere under the
classical Hopf fibration p: S³ → S².

**Mathematical specification**
1. Spaces and map: S³ ⊂ ℂ², S² ⊂ ℂ × ℝ. Hopf map
     p(z₀,z₁) = (2 z₀ z̄₁, |z₀|² − |z₁|²).
2. Three base loops on S²: (θ,φ) latitudes +60°, 0°, −60°.
3. Render each torus T_k = p⁻¹(Γ_k) ⊂ S³.
4. Stereographic projection from north pole (0,0,0,1) into ℝ³.

**Rendering style**
* Smooth tubes, radius ≈ 1 % of circumscribed-sphere diameter, ≥ 500
  points per fibre.
* HSV hue from φ ∈ [0,2π].
* Translucent grey reference S² in lower-right with the three loops
  plotted on it; thin axial rods (±x,±y,±z) for orientation.
* White background, soft Phong, antialiased, ≥ 1600×1600 px.

**Deliverable** A single PNG image.
```

## `critic.txt` — judge rubric (REQUIRED structure)

The harness's `CriticTemplate` parser (`llm_harness/critic_template.py`)
parses three named sections via regex. **Section names must be exact, in
this order, and each must be present.** Missing sections fall back to
generic defaults and tank scoring fidelity.

```
__MATHEMATICAL_ACCURACY__
{problem-specific math/correctness criteria — bullets ok, sub-headers ok}

__VISUAL_IMPLEMENTATION__
{problem-specific rendering/visual criteria}

__COMPLETENESS_AND_SPECIFICATIONS__
{problem-specific composition/required-element criteria}
```

These three sections plus two generic ones (Problem Accuracy, Visual Quality
— supplied by the harness) become the **5 score categories S1..S5**, each
scored 1–100 by the judge LLM. The judge sees the full critic content
inside the section block; write enough that a careful reader could mark the
image against specific bullets.

**Good content per section:**

- Multiple sub-headed groups of bullets (3–5 groups; 3–8 bullets each).
- Falsifiable, image-checkable criteria (e.g. "exactly three linked tori
  visible", "hue cycles once around 360° matching φ", "≥ 500 sample points
  per fibre — judged by smoothness").
- For frontier problems, lean on **measurable invariants** (Euler char,
  linking number, symmetry group order, monotonicity, error bounds).

**Bad content (avoid):**

- Single sentence per section ("the math should be right").
- "Use your judgment" / no concrete checks.
- Pure aesthetic language with nothing measurable.
- Mixing the three sections — keep each one focused on its theme.

### critic.txt example (`hopf_fibration_base_loops/critic.txt`)

```
__MATHEMATICAL_ACCURACY__
Topological Structure Analysis:
- Are exactly three separate, mutually linked tori visible (one per base loop)?
- Does each fiber link every other exactly once (Hopf linking property)?
- Is the S³ → S² mapping geometrically consistent?

Stereographic Projection Verification:
- Are circular fibres correctly projected from north pole (0,0,0,1)?
- Do projected fibres maintain proper relative geometry?
- Are nested arrangements consistent with stereographic distortion?

Hopf Fibration Properties:
- p(z₀,z₁) = (2 z₀ z̄₁, |z₀|² − |z₁|²) implemented correctly?
- Three base loops at θ = π/3, π/2, 2π/3 — visible and distinguishable?
- S¹ bundle structure preserved (closed circular fibres, no breaks)?

__VISUAL_IMPLEMENTATION__
Fiber Construction:
- Smooth tubes of constant radius ≈ 1 % of circumscribed diameter?
- ≥ 500 points per fibre — surface looks continuous, no faceting?
- No clipping, gaps, or aliasing artifacts?

Color Implementation:
- HSV hue = φ/(2π) implemented correctly?
- Each fibre keeps consistent color from its base point along its length?
- Smooth interpolation, no banding?

Lighting:
- Soft Phong shading applied as specified?
- Materials appropriate for clarity of topology?
- Lighting reveals 3D structure without flattening?

__COMPLETENESS_AND_SPECIFICATIONS__
Reference Sphere & Legend:
- Translucent grey S² present in lower-right?
- Three coloured base loops plotted on it?
- Orientation rods (±x,±y,±z) labeled?

Technical Specs:
- Resolution ≥ 1600 × 1600 px?
- Pure white background, no gradients/textures?
- Anti-aliasing applied, no jagged edges?

Composition:
- All three tori clearly visible and distinguishable?
- Camera angle reveals linking topology?
- Overall presentation publication-quality?
```

## When you've filled all 20

Run the categorizer to confirm everything still parses cleanly:

```
uv run python tools/categorize_problems.py   # idempotent; shouldn't change anything
```

Then a small smoke run on one frontier problem to verify the rubric parses:

```
cd llm_harness
uv run python benchmark_harness.py --model cli/codex:gpt-5.5:high \
  --judge-model cli/codex:gpt-5.5:high \
  --problems <one_slug> --new --max-parallel 1
```

If the harness logs `Warning: Missing __QUESTION_X__ in <slug>/critic.txt,
using default`, your section headers are wrong — fix them and rerun.

## Tips for writing rubrics that discriminate

- **Different difficulties per criterion.** Some bullets should be easy
  (right output count), some should be hard (correct curvature, not just
  smoothness). A rubric that's all-or-nothing won't separate models.
- **Measurable invariants over impressions.** "Linking number = 1" beats
  "tori look linked".
- **Explicit failure modes**, e.g. "if fibres are ellipses instead of
  circles, score 0 in this section". Helps the judge be consistent.
- **Avoid asking the judge to compute things it can't.** It's an image
  judge, not a numerical solver. Frame everything as visual checks.
