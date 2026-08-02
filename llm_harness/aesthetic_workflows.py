"""Ablation contracts for beauty-first procedural reconstruction workflows.

Each workflow changes the decision process, not merely adjectives in the base
prompt.  The shared harness keeps model, problem, render ceiling, renderer, and
judges fixed so the five hypotheses can be compared as one controlled batch.
"""

from __future__ import annotations

from dataclasses import dataclass


AESTHETIC_PERCEPTUAL_CRITIC_WORKFLOW = "aesthetic-perceptual-critic-v10a"
AESTHETIC_WHOLE_SCENE_TOURNAMENT_WORKFLOW = (
    "aesthetic-whole-scene-tournament-v10b"
)
AESTHETIC_SILHOUETTE_RHYTHM_WORKFLOW = "aesthetic-silhouette-rhythm-v10c"
AESTHETIC_COLOR_MATERIAL_WORKFLOW = "aesthetic-color-material-v10d"
AESTHETIC_RELATIONAL_INTEGRATION_WORKFLOW = (
    "aesthetic-relational-integration-v10e"
)


@dataclass(frozen=True)
class AestheticWorkflowSpec:
    name: str
    label: str
    hypothesis: str
    required_studies: int
    min_successful_study_renders: int
    require_study_diversity: bool
    require_study_selector: bool
    require_variant_inventory: bool
    contract: str


COMMON_BEAUTY_CONTRACT = r"""
BEAUTY IS A FIRST-CLASS ACCEPTANCE CRITERION
============================================

Mathematical sophistication is a means, never the selection criterion. A more
complex SDF, more noise octaves, more objects, or more physically complete
scene loses when it weakens the visible image. Judge the render twice:

1. THREE-SECOND READ: squint or mentally thumbnail the image. Record the focal
   subject, gesture, silhouette, dominant negative spaces, value grouping, and
   emotional character that read immediately. If the answer is "generic toy",
   "stack of primitives", "flat sticker", or "busy texture", do not polish it.
2. SUSTAINED READ: inspect proportion, shape rhythm, overlap, edge hierarchy,
   depth cues, material variation, color relationships, controlled asymmetry,
   and the transitions between major parts. Distinguish designed irregularity
   from both sterile repetition and unstructured noise.

Every rewrite critique must contain these compact public fields:

  GESTALT: what the current image communicates before details;
  BEAUTIFUL: the strongest specific visual relationship to preserve;
  UNCANNY: the most generic, stiff, plastic, regular, or disconnected feature;
  INTERVENTION: one coherent perceptual hypothesis for the next render;
  TEST: the visible change that would confirm or reject that hypothesis.

Do not list equations in those fields unless an equation explains a visible
choice. Preserve successful features. Prefer a small number of high-leverage
changes to global gesture, relational anatomy, overlap, value structure,
palette, material, or lighting over a long parameter sweep. A revision that is
only technically cleaner is not an aesthetic improvement.

For every rank_study call, pass a rubric_focus of at least 40 characters that
states the exact visible aesthetic question for that study. Never mention cell
labels, pass order, code complexity, or which candidate you personally prefer;
the server shuffles candidates before the fresh selector sees them.
"""


PERCEPTUAL_CRITIC_CONTRACT = COMMON_BEAUTY_CONTRACT + r"""

WORKFLOW V10A — INDEPENDENT CRITIC + CHAMPION LOOP
==================================================

Hypothesis: repeated selection by a fresh visual critic prevents the generator
from rationalizing an attractive-sounding but visibly mediocre local minimum.

Run FIVE sequential whole-scene studies. Every study is a 3×2 atlas at the final
camera, never an isolated component sheet:

- Include the current champion unchanged in one cell and five challengers that
  address one dominant visible beauty defect. The first study uses six broad
  complete-image champions because no incumbent exists yet.
- The five decision rounds are: (1) gesture/silhouette/negative space,
  (2) relational anatomy and overlaps, (3) repeated-form rhythm and controlled
  irregularity, (4) palette/material/lighting, and (5) restraint, focal hierarchy,
  and finished-image coherence. Preserve earlier wins in later rounds.
- Predeclare A–F in variation_manifest. Each challenger must embody a real visual
  hypothesis, not a seed, count, or nearby-constant change.
- After each atlas, call rank_study. The isolated selector—not you—chooses the
  next champion from opaque candidates. Call record_study with the winner's
  visible strengths, losses, and exact implementation handoff.
- If the incumbent wins, keep it. Do not rewrite merely to demonstrate activity.
  If a challenger wins, the next atlas must visibly inherit that candidate.

After five critic decisions, rebuild the champion full-frame and produce several
final challengers. Use historical restore when a revision loses the strongest
earlier gesture. Submission must be the most beautiful successful revision, not
automatically the newest or most elaborate.
"""


WHOLE_SCENE_TOURNAMENT_CONTRACT = COMMON_BEAUTY_CONTRACT + r"""

WORKFLOW V10B — WHOLE-SCENE AESTHETIC TOURNAMENT
================================================

Hypothesis: a wide search over complete visual concepts before implementation
detail will find a better basin than iterating one initial composition.

Study 1 is a WHOLE-SCENE tournament, not a component laboratory. Render TWO
qualified 3×2 passes before ranking:

- Pass 1 presents six complete compositions with genuinely different shape
  languages, gesture, crop, focal hierarchy, negative-space design, and mood.
  Keep enough subject identity to compare them, but make the alternatives bold.
- Pass 2 carries forward the two most beautiful concepts from Pass 1. A/B/C are
  three structural developments of one concept; D/E/F develop the other. Fix
  visible weaknesses without collapsing the concepts into one average design.
- Every atlas cell must be understandable as a thumbnail. Do not hide weak
  composition under feather counts, texture, or technical annotations.
- Call rank_study after both passes. The isolated selector sees the reference
  and all 12 opaque candidates. Record its winner and the exact silhouette,
  composition, shape-language, palette, and edge relationships to preserve.

Then rebuild that winning cell full-frame and iterate complete finals. The
winner is a visual constitution: later detail may enrich it but may not replace
its gesture, negative spaces, focal hierarchy, or characteristic edge rhythm.
"""


SILHOUETTE_RHYTHM_CONTRACT = COMMON_BEAUTY_CONTRACT + r"""

WORKFLOW V10C — SILHOUETTE, NEGATIVE SPACE, AND RHYTHM
======================================================

Hypothesis: solving the image's two-dimensional perceptual skeleton before
surface detail prevents attractive local geometry from composing into a weak
toy-like whole.

Study 1 — MONOCHROME SILHOUETTE CHOREOGRAPHY:
- Six complete-subject variants in flat light/dark only: no texture, feather
  lines, specular highlights, bokeh, or color used as camouflage.
- Vary gesture, crop, head/body proportion, hooked and carved contours, major
  overlaps, asymmetric protrusions, and the negative spaces around the subject.
- Rank by recognizability, character, tension, and economy at thumbnail scale.

Study 2 — VALUE MASSES + EDGE RHYTHM:
- Preserve the selected silhouette in every cell. Add only three to five value
  families and compare the rhythm of broad versus narrow shapes, soft versus
  hard edges, resting areas versus detail, and foreground/background separation.
- Major color zones must wrap the form and reinforce anatomy. Repeated elements
  should create directional flow and overlap cadence, not a uniform grid.
- Rank with the isolated selector and record explicit value percentages, edge
  hierarchy, focal region, and protected negative spaces.

Only then introduce full color, material, and fine structure. Every final must
still work when mentally reduced to the selected silhouette and value pattern.
Restore an earlier revision if color or detail damages that read.
"""


COLOR_MATERIAL_CONTRACT = COMMON_BEAUTY_CONTRACT + r"""

WORKFLOW V10D — COLOR SCRIPT, MATERIAL, AND CINEMATOGRAPHY
==========================================================

Hypothesis: the recurring plastic toy appearance is primarily an art-direction
failure—uniform local color and generic highlights—not only a geometry failure.

Study 1 — COLOR-SCRIPT TOURNAMENT:
- Hold one competent complete silhouette and camera approximately constant.
  Compare six designed palette/value scripts, not six hue rotations.
- For each script define dominant, supporting, accent, shadow, bounce, and
  background families as relationships. Test warm/cool separation, saturation
  hierarchy, focal contrast, atmospheric depth, and color transition scale.
- Keep large quiet color masses; do not simulate richness with high-frequency
  rainbow noise. Rank by emotional clarity and reference-specific harmony.

Study 2 — MATERIAL + EDGE-LIGHTING TOURNAMENT:
- Preserve the selected color script. Compare six coupled material/light models
  that visibly distinguish soft plumage or analogous layered matter, keratin or
  hard focal material, matte/scattering regions, and the background atmosphere.
- Geometry or procedural fields should perturb normals, roughness, occlusion,
  and reflectance coherently. A shiny ball with color stripes is a failure.
- Vary broad light direction/size, rim restraint, contact shadows, subsurface or
  velvet response where appropriate, and edge softness. Rank beauty and depth,
  not maximum gloss or contrast.

Final revisions may improve geometry, but each must preserve the chosen color
relationships and material hierarchy. Use lighting to reveal form, not to hide
weak attachment or silhouette.
"""


RELATIONAL_INTEGRATION_CONTRACT = COMMON_BEAUTY_CONTRACT + r"""

WORKFLOW V10E — RELATIONAL INTEGRATION TOURNAMENT
=================================================

Hypothesis: the largest remaining bottleneck is synthesis. Whole-image,
relationship-level tournaments should preserve beautiful discoveries better
than isolated component studies followed by one final merge.

All three studies show the COMPLETE SUBJECT at the final camera and approximate
lighting. Never replace the scene with an isolated part.

Study 1 — RELATIONAL ANATOMY:
- Six different rooted arrangements of the major masses. Explore how head grows
  from body, face cuts into head, beak locks around the cheek, wing wraps the
  torso, and major overlaps create depth. Rank gesture, attachment, negative
  space, characteristic hard/soft transitions, and subject identity.

Study 2 — COAT / LAYER INTEGRATION:
- Preserve the Study-1 winner in every cell. Compare six systems for how repeated
  or layered structures emerge from the surface, change scale and direction,
  overlap, disappear under neighbors, cross seams, and affect the silhouette.
- Prefer coherent fields with selected irregularity and sparse hero exceptions.
  Reject pasted batches, exposed grids, armor plates, fingers, or decorations
  hovering beside the parent.

Study 3 — FINISHED-IMAGE SYNTHESIS:
- Preserve the best anatomy and layer system. Present six genuinely different
  finished compositions combining palette, material, lighting, atmosphere,
  detail restraint, and focal hierarchy. Each cell must be plausible as the
  submitted image, not a parameter swatch.
- Rank all candidates with the isolated selector. Record both the winner and
  which earlier strength each synthesis preserved or lost.

After selection, render multiple full-frame finals. Treat the latest selected
study as the champion; accept a final revision only if it improves the whole
image without regressing anatomy, coat attachment, silhouette, or mood. Use
restore_revision and submit the strongest historical final when necessary.
"""


_SPECS = {
    AESTHETIC_PERCEPTUAL_CRITIC_WORKFLOW: AestheticWorkflowSpec(
        name=AESTHETIC_PERCEPTUAL_CRITIC_WORKFLOW,
        label="Perceptual critic loop",
        hypothesis=(
            "Fresh blinded champion selection redirects iterations from self-"
            "approved equation polish toward visible aesthetic gains."
        ),
        required_studies=5,
        min_successful_study_renders=1,
        require_study_diversity=True,
        require_study_selector=True,
        require_variant_inventory=True,
        contract=PERCEPTUAL_CRITIC_CONTRACT,
    ),
    AESTHETIC_WHOLE_SCENE_TOURNAMENT_WORKFLOW: AestheticWorkflowSpec(
        name=AESTHETIC_WHOLE_SCENE_TOURNAMENT_WORKFLOW,
        label="Whole-scene tournament",
        hypothesis=(
            "Wide complete-image search finds a better aesthetic basin before "
            "detail work commits the run to its first composition."
        ),
        required_studies=1,
        min_successful_study_renders=2,
        require_study_diversity=True,
        require_study_selector=True,
        require_variant_inventory=True,
        contract=WHOLE_SCENE_TOURNAMENT_CONTRACT,
    ),
    AESTHETIC_SILHOUETTE_RHYTHM_WORKFLOW: AestheticWorkflowSpec(
        name=AESTHETIC_SILHOUETTE_RHYTHM_WORKFLOW,
        label="Silhouette and rhythm",
        hypothesis=(
            "Locking silhouette, negative space, value masses, and edge rhythm "
            "before detail improves the final perceptual skeleton."
        ),
        required_studies=2,
        min_successful_study_renders=1,
        require_study_diversity=True,
        require_study_selector=True,
        require_variant_inventory=True,
        contract=SILHOUETTE_RHYTHM_CONTRACT,
    ),
    AESTHETIC_COLOR_MATERIAL_WORKFLOW: AestheticWorkflowSpec(
        name=AESTHETIC_COLOR_MATERIAL_WORKFLOW,
        label="Color and material direction",
        hypothesis=(
            "A designed color script and coupled material-light response reduce "
            "the recurring plastic-toy appearance."
        ),
        required_studies=2,
        min_successful_study_renders=1,
        require_study_diversity=True,
        require_study_selector=True,
        require_variant_inventory=True,
        contract=COLOR_MATERIAL_CONTRACT,
    ),
    AESTHETIC_RELATIONAL_INTEGRATION_WORKFLOW: AestheticWorkflowSpec(
        name=AESTHETIC_RELATIONAL_INTEGRATION_WORKFLOW,
        label="Relational integration tournament",
        hypothesis=(
            "Repeated whole-image selection at anatomy, layering, and synthesis "
            "stages prevents strong local studies from collapsing at integration."
        ),
        required_studies=3,
        min_successful_study_renders=1,
        require_study_diversity=True,
        require_study_selector=True,
        require_variant_inventory=True,
        contract=RELATIONAL_INTEGRATION_CONTRACT,
    ),
}

AESTHETIC_WORKFLOWS = tuple(_SPECS)


def get_aesthetic_workflow(name: str) -> AestheticWorkflowSpec | None:
    """Return the immutable workflow definition, if ``name`` is a v10 ablation."""
    return _SPECS.get(name)


def aesthetic_workflow_specs() -> tuple[AestheticWorkflowSpec, ...]:
    """Return all five specs in stable experiment order."""
    return tuple(_SPECS[name] for name in AESTHETIC_WORKFLOWS)
