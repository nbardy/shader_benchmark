# Parrot prompt-ablation blog notes — 2026-07-30

Working notes for a future ShaderBench post. Preserve observations separately
from conclusions: this is one reconstruction problem, three trials per method,
and one model judge, so it is an experiment diary rather than a general model
ranking.

## Experiment

- Target: `reproduce_image_andrew_pons` (blue-and-yellow macaw photograph).
- Generator: `cli/codex:gpt-5.6-sol:medium`.
- Judge: `cli/codex:gpt-5.5:high`, corrected reconstruction rubric.
- Six prompt profiles, three independent trials each, three dependent visual
  revision rounds per trial.
- Each trial starts from a fresh isolated generation session. Later rounds see
  the prior executed shader and a target/current-render comparison.

## Quantitative result so far

| Profile | Round 1 mean | Round 3 mean | Round 3 SD | Render failures |
|---|---:|---:|---:|---:|
| baseline | 338.3 | 347.7 | 22.9 | 0 |
| scratchpad | 312.7 | 332.7 | 45.1 | 0 |
| scratchpad + art direction | 317.3 | 343.3 | 29.9 | 0 |
| ambitious 3D | 325.0 conditional / 108.3 all-in | 353.0 | 11.3 | 2 at R1 |
| scratchpad + art direction + ambitious 3D | 327.3 | 342.3 | 28.1 | 1 at R2 |
| domain expert | 306.0 conditional / 204.0 all-in | 337.3 | 12.6 | 1 at R1 |

Revision compute helped, but less than expected and not monotonically. The
baseline gained roughly nine points from round 1 to round 3. Ambitious 3D
recovered from two initial render failures and finished with the highest mean,
while scratchpad-only had the largest variance. Best-of-round selection was
often better than blindly taking round 3.

## Human visual observation

The benchmark owner prefers the round-3
`scratchpad-art-direction-ambitious-3d-v1` render visually, even though the
judge does not rank that profile first. This is important evidence of a grader
gap. Likely underweighted qualities include coherent 3D form, artistic
specificity, material richness, controlled irregularity, and overall scene
read. Future reporting should retain the full trial-by-round image grid and add
blinded human pairwise preferences rather than treating the scalar judge as
ground truth.

## What the IQ reference kernel teaches

The supplied reference is useful as an architectural example, not code to paste
into the WGSL benchmark. Its transferable ideas include:

1. Bound expensive work. Terrain, cloud layers, and tree envelopes are tested
   before detailed marching.
2. Repeat objects, not merely colors. Tree instances use integer cell identity,
   local fractional coordinates, neighboring cells, stable hashes, and
   per-instance size/material variation.
3. Split scale bands. Macro terrain, low-frequency distribution, object shapes,
   displacement, and surface detail have separate jobs.
4. Carry derivatives or stable normal estimates when procedural fields affect
   geometry.
5. Couple materials to lighting. Normal variation, occlusion, diffuse response,
   Fresnel/specular response, fog, and color grading are designed together.
6. Finish the image. Camera, atmosphere, palette, contrast, gamma, and final
   grading are first-class parts of the shader rather than cleanup.

## Domain-expert hypothesis

The sixth profile, `domain-expert-v1`, tests whether explicit production-shader
architecture beats generic requests for “more detail” or “more 3D.” Its three
new interventions are:

- object-level spatial folding and clustered instance variation;
- palette ladders plus reusable, commented color relationships;
- material-specific normal and reflectance design that avoids the
  “shiny ball with a fake texture” failure mode.

The prompt keeps the public art-direction guide and implementation scratchpad,
but asks for observable design evidence rather than hidden reasoning. The
acceptance bar is not that the plan mentions the right terms; the shader must
contain concrete geometry, palette, material, lighting, and budget choices.

## Domain-expert result

The new arm did not win. Its successful round-1 mean was 306, with one render
failure; it recovered to 343.7 at round 2 and fell to 337.3 at round 3. Trial 2
was the strongest new trajectory (347 → 359 → 349). The small final standard
deviation is encouraging for consistency, but its mean is below baseline,
ambitious 3D, art direction, and the combined profile.

The generated WGSL shows partial instruction uptake:

- all three round-3 shaders define explicit feather fields or feather SDFs;
- trials 1 and 2 build feather groups from stable indexed instances, and trial
  2 uses `floor`/`fract` cells for material-specific fibers;
- the shaders include named palette-architecture comments, correlated color
  variation, and at least lightweight roughness/Fresnel ideas;
- nevertheless, every round-3 shader constructs the parrot primarily in screen
  space. The profile's real-3D requirement did not survive the combined
  instruction load.

Visually, trial 2 is the strongest domain-expert result: coherent silhouette,
clean background separation, and more convincing repeated feather forms. It
still reads as a polished flat procedural illustration. Trial 1 has ambitious
individual feather objects but awkward anatomy and large flat color regions.
Trial 3 simplifies back toward masks and loses much of the intended material
depth.

The benchmark owner's preferred image remains the combined art-direction +
ambitious-3D trial 3 round 3. It has stronger volume, beak material, lighting,
and photographic presence than any domain-expert result, although its scalar
judge score is not the overall winner. This reinforces the grader-gap concern.

## Interpretation for the post

“More domain knowledge in the prompt” is not equivalent to more effective test
time compute. The new contract successfully changed vocabulary and local
techniques, especially feather repetition and palette organization, but it also
created too many simultaneous obligations. The model satisfied the easiest
locally verifiable parts while abandoning the expensive architectural demand:
genuine 3D.

The honest conclusion is negative but useful:

1. visual iteration gives modest, non-monotonic gains;
2. explicit shader vocabulary can steer local construction;
3. a long expert checklist can crowd out the central representation choice;
4. one scalar vision judge misses qualities the human reviewer cares about;
5. future tests should isolate object tiling, palette design, and material
   reflectance as separate arms, and add blinded human pairwise preferences.

Do not claim success from one attractive output. The evidence here supports
smaller, falsifiable expert interventions rather than one maximal prompt.
