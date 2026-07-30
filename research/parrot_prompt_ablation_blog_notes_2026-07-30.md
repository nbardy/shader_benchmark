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

## Iterative expert-prompt development: v2–v5

The next phase is sequential prompt development rather than a parallel
leaderboard. Each version gets one three-round parrot run; its actual renders
and WGSL determine the smallest change in the next version.

The IQ kernel suggests three generative-art principles:

1. **Hierarchical scene architecture.** Cheap bounds and envelopes decide where
   expensive geometry, marching, shadows, and volumes are evaluated.
2. **Structured variation.** A stable macro-form is populated with real object
   instances whose position, scale, angle, shape, material, and occupancy vary
   coherently across neighboring cells and larger density fields.
3. **Unified surface response.** Geometry and displacement produce normals;
   normals, material, lighting, atmosphere, and final color grading form one
   pipeline rather than independent effects.

[Current GPT-5.6 guidance](https://developers.openai.com/api/docs/guides/model-guidance?model=gpt-5.6#prompting-best-practices)
favors lean, outcome-oriented prompts and recommends removing repeated
scaffolding one group at a time. V2 therefore tests one hypothesis: a concise,
mechanically verifiable 3D gate will preserve true 3D better than v1's maximal
expert checklist.

### V2 — lean 3D gate

Trajectory: 307 → 316 → 331.

V2 succeeded architecturally. The round-3 WGSL uses a perspective camera,
ray-marched `mapScene`, occluding 3D ellipsoids and beak forms, geometric
normals, material IDs, roughness, Fresnel, soft shadow, AO, fog, and bounded
feather functions. It did not fall back to screen-space construction.

Visually it became a toy parrot made from repeated parts. The breast and wing
are populated by regular rows of tapered capsules/cones with similar spacing,
orientation, and glossy bead-like ends. Iteration improved crop and detail but
made the regimented pattern more obvious. The score rose monotonically while
the central artistic defect remained.

V3 changes only the feather representation: replace the parts grid with a
surface-following plumage field plus sparse, asymmetrical hero feathers whose
placement follows a curved wing frame.

### V3 — organic feather flow

Trajectory: render failure → 316 → 334.

V3 preserved genuine 3D after compiler recovery and removed the regimented
capsule grid. It overcorrected toward smooth parent volumes: the final bird has
global rib-like surface waves and a few isolated oval/blob details instead of
convincing plumage. Crop and head scale improved, but the body still reads as a
toy made of glossy primitive masses.

V4 keeps the same macro 3D gate and changes the surface layer only. It bans
global sine ribs, plastic feather materials, and oval decals, then specifies a
three-scale system: macro anatomy, a warped surface-aligned meso feather field,
and restrained fiber-scale normal/roughness variation.

### V4 — plumage material system

Trajectory: render failure → 238 → render failure.

V4 was the worst treatment. Two rounds used `select()` on a `SceneHit` struct,
which WGSL/naga rejects. The only render showed a separate mathematical failure:
periodic feather geometry escaped the bird and formed long chains through the
background. The prompt requested cheap parent bounds, but that encouraged
conditional evaluation rather than true SDF intersection. A branch can save
work; it does not guarantee the repeated field is clipped.

V5 returns to v2's stable macro scene, adds the exact containment equation
`max(dDetail, dParentRegion)`, forbids unbounded world-space folding, and replaces
the universal cell field with three designed treatments: subtle breast relief,
7–10 bounded flight feathers along a curved arc, and a few crown/shoulder
silhouette details. It also records the two repeated WGSL hazards: struct
`select()` and swizzle assignment.

### V5 — contained designed variation

Trajectory: render failure → 279 → 328.

V5 successfully contained the feather work to the bird and recovered a
recognizable, tightly cropped 3D macaw with a stronger facial patch, eye, and
hooked beak. Round 1 still violated the explicit no-swizzle-assignment rule and
failed after repair, showing that prompt text is not a reliable compiler
boundary.

The final render's macro anatomy is the strongest of v4/v5, but the intended
flight feathers collapse into thin wire/crease artifacts. Large body and wing
surfaces remain smooth and plastic. Exact containment fixed v4's catastrophic
pattern escape; it did not solve the hard meso-geometry design problem.

## V2–V5 development summary

| Version | Round 1 | Round 2 | Round 3 | Human read |
|---|---:|---:|---:|---|
| v2 lean 3D gate | 307 | 316 | 331 | Genuine 3D and explicit feathers, but a regular peg grid |
| v3 organic flow | fail | 316 | 334 | Cleaner masses and crop, but ribbed/plastic with sparse blobs |
| v4 material system | fail | 238 | fail | Periodic detail escapes the bird; mechanically fragile |
| v5 contained design | fail | 279 | 328 | Best late macro anatomy; feather detail degenerates into wires |

Run IDs:

- `parrot_domain_expert_v2_iq_20260730`
- `parrot_domain_expert_v3_iq_20260730`
- `parrot_domain_expert_v4_iq_20260730`
- `parrot_domain_expert_v5_iq_20260730`

None of the four is an IQ-level artistic parrot. The original combined
art-direction + ambitious-3D trial 3 round 3 still has the strongest overall
photographic volume and material presence to the human reviewer.

## What the iteration actually established

The three IQ-derived principles remain sound, but prose alone does not reliably
instantiate them:

1. **Bounds need equations, not adjectives.** V4 interpreted “bound detail” as
   a performance branch; v5's explicit SDF intersection fixed the escape.
2. **Structured variation needs a domain-specific representation.** Asking for
   repeated real objects produced a peg grid; asking for a field produced ribs;
   asking for both produced fragile geometry. A close-up feather coat needs a
   reusable surface-coordinate feather primitive or worked scaffold, not more
   vocabulary.
3. **Materials cannot rescue weak geometry.** Roughness, Fresnel, AO, fog, and
   grading were present, but broad primitive anatomy plus weak meso detail still
   read as plastic.

The next meaningful system experiment is not v6 prompt accretion. It is to give
the model a small, tested WGSL production scaffold: robust scene-hit selection,
ellipsoid/capsule/lens primitives, safe transforms, parent-shell clipping,
surface frames, and one bounded feather-field helper. Then let the model spend
test-time compute on composition and art direction while compile/render gates
enforce the architecture mechanically. Pair that with blinded human preference,
because the scalar judge did not track the preferred image reliably.

## Visual sketchbook hypothesis

The v2 image makes the remaining failure unusually concrete. The shader does
have real 3D, lighting, materials, and repeated feather objects, but its
placement is effectively fixed row/column indexing with small hash offsets and
its feather primitive is a tapered capsule. fBm cannot turn that representation
into layered plumage: it can only make a peg grid slightly crooked. There is no
parent-surface coordinate frame carrying tangent, bitangent, normal, curvature,
or a wing/body boundary, so instances cannot convincingly wrap around anatomy.

The next experiment therefore changes the inference workflow rather than adding
another expert paragraph. Before the final reconstruction, one persistent
render-tool session must build three visual sketchbooks. Each sketchbook is a
3×2 atlas with six materially different alternatives for a high-risk component.
The expected roles are macro silhouette/architecture, signature meso shape and
surface-following distribution, and material/palette/light response, but the
agent must choose subjects from the reference so the protocol generalizes
beyond parrots.

After inspecting an atlas, the agent records a public selection: winning A–F
cell, visible reasons, and the exact function family, coordinate frame,
parameter ranges, and aesthetic properties to carry into the final shader. The
tool server blocks final rendering until all three records exist and requires
at least two successful final revisions afterward. This tests whether rendered
component search produces better primitives and placement fields than asking a
single full-scene rollout to invent, integrate, and critique everything at
once.

### First sketchbook run

Run: `parrot_sketchbook_3x2_v1_sol_medium_20260730`

The agent used seven of ten render calls:

1. the first macro atlas failed compilation;
2. the repaired macro atlas selected variant C;
3. the feather/distribution atlas selected variant B;
4. the palette/material/light atlas selected variant E;
5. the first integrated final failed compilation;
6. final revision 1 scored 324/500;
7. final revision 2 scored 332/500 and was submitted.

The server behavior worked as designed. All three study records existed before
the first final render, study renders were excluded from judging, and the two
successful full-scene renders alone satisfied the submission minimum. The
second final corrected the portrait-facing direction and improved its score by
eight points.

The visual hypothesis only partially succeeded. The submitted bird has a much
clearer overlapping feather cascade than v2's peg rows, but the feathers are
still smooth ellipsoid petals rather than thin, curved, asymmetric feather
forms. The final WGSL uses 24 explicit wing ellipsoids in a fixed 4×6 loop plus
small hash displacement; it contains no fBm or domain-warped surface frame.
Study 1 and Study 3 mostly compare conservative parameter changes. Even Study
2 varies coverage, flow, and density more than the underlying primitive.

The judge score, 332, is effectively tied with the original v2 round 3 score of
331. Human inspection sees a real meso-structure improvement but not a more
photographic reconstruction: anatomy, facial geometry, feather edge structure,
and material variation remain toy-like.

The experiment reveals the next enforcement gap. A 3×2 atlas requirement
guarantees six cells, not six representation families. The model can satisfy
the workflow with six nearby parameterizations, then write a confident study
record that overstates their diversity. For repeated organic detail, the next
version should separate the individual component-shape study from the
parent-surface placement study and require an explicit A–F representation
inventory. Better still, a tested surface-frame and curved-feather scaffold
would move this from prose compliance to executable architecture.

### Curved-element v2: separating shape from placement

Run: `parrot_sketchbook_curved_elements_v2_sol_medium_20260730`

V2 made Study 2 an enlarged individual-feather laboratory and Study 3 a
separate wing-attachment laboratory. It also forced ordered studies and a
public A–F construction inventory. This exposed another representation failure:
the model implemented each curved feather as a smooth union of nine ellipsoidal
segments. The isolated atlas looked like six tapered caterpillars, and wrapping
them over an ellipsoid wing produced organized rows of bead stacks.

The first integrated render scored 323. Its revision smoothed the segments into
larger bent worm-like chunks and regressed to 277. The inventory gate improved
auditability but did not stop the model from over-describing six similar
segmented constructions as distinct families.

### Continuous-element v3: one variable-width implicit profile

Run: `parrot_sketchbook_continuous_elements_v3_sol_medium_20260730`

V3 explicitly prohibited segment unions for a single element and supplied an
inverse-bend field:

- a longitudinal `s` coordinate;
- curved centerline from quadratic bend plus sinusoidal sweep;
- independent root growth, shoulder, and tip taper;
- asymmetric left/right width;
- thickness, lift, and camber varying with `s`;
- a single continuous cross-section intersected with axial bounds.

This was the first study to eliminate both ovals and caterpillars. Its six
enlarged variants are continuous, tapered, visibly curved vane-like shapes;
variant F adds a restrained central groove. Study 3 preserved the selected
function on a shared curved wing, and both final renders reused that exact
continuous function.

The final scores were 301 and 304, lower than the simpler v1's 332. Human
inspection nevertheless identifies a real representation advance: feathers
now bend, widen, thin, and taper instead of reading as blobs. The new dominant
failure is integration. The instances are too pale, sparse, small, and shallow;
many appear to float on the wing rather than embedding their roots and
overlapping into a dense coat.

The final WGSL still does not implement fBm. It applies one scalar hash jitter
to row placement and bend, computes the ellipsoid front depth, then rotates the
element only in the image-plane XY basis. It does not construct the full
surface `(T,B,N)` frame promised by the study record. Thus v3 fixes the local
shape but only partially fixes body conformance.

The next change should be code architecture rather than a v4 paragraph:
provide tested WGSL helpers for ellipsoid/parent UV parameterization, analytic
or gradient normals, tangent/bitangent construction, UV-space fBm/domain warp,
root embedding, and overlap depth. The continuous feather helper from v3 can
then be transformed through that frame without being reinterpreted by the
model.
