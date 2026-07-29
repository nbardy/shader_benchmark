"""Named generation-prompt variants for controlled benchmark experiments."""

from typing import Dict


BASELINE_PROFILE = "baseline"
CHATGPT_SHADER_HARNESS_PROFILE = "chatgpt-shader-harness-v1"
SCRATCHPAD_PROFILE = "scratchpad-v1"
SCRATCHPAD_ART_DIRECTION_PROFILE = "scratchpad-art-direction-v1"
AMBITIOUS_3D_PROFILE = "ambitious-3d-v1"
SCRATCHPAD_ART_DIRECTION_AMBITIOUS_3D_PROFILE = (
    "scratchpad-art-direction-ambitious-3d-v1"
)
DOMAIN_EXPERT_PROFILE = "domain-expert-v1"


_SCRATCHPAD_BRIEF = r"""
Before coding, produce a compact public production plan. Compare at least three
materially different representations, then select the strongest one for this
specific problem: 2D construction, layered 2.5D, analytic ray intersections,
ray-marched 3D SDFs, or a justified hybrid. Do not default to flat masks when
volume, perspective, occlusion, lighting, or material response are important.

The <scratchpad> MUST state:
- the scene structure, camera/view, dominant silhouette, proportions, depth,
  overlap order, palette, and focal hierarchy;
- the alternatives considered, their likely failure modes, and why the chosen
  representation wins;
- primitives, coordinate systems, transforms, SDF/CSG or intersection
  operations, repetition/deformation, and composition plan;
- key equations for camera rays, geometry, normals, lighting, falloffs,
  procedural detail, and any central mathematical construction;
- surface, material, shadow, ambient-occlusion, specular, Fresnel, atmospheric,
  antialiasing, and tone-mapping decisions as appropriate;
- a final ABI, bounded-loop, static-frame, completeness, and readability audit.

Use short derivations, invariants, bounds, or sanity checks only when they help
prevent a real mathematical or visual error. Keep the scratchpad under 800
words so the complete WGSL retains most of the output budget.
""".strip()


_ART_DIRECTION_GUIDE = r"""
Before the scratchpad, produce a compact art-direction guide that identifies
what would make the result emotionally legible, specific, elegant, and
non-generic. Do not merely list objects or colors.

The <artistic_subtleties_and_elegance> block MUST identify:
- the intended feeling, gesture, rhythm, visual hierarchy, negative space,
  asymmetry, focal transitions, and three to five signature subtleties that
  carry the subject's identity;
- where a mathematically perfect pattern would become boring, synthetic, tiled,
  logo-like, or uncanny: equal spacing, identical scale/orientation, uniform
  edge hardness, constant frequency, perfect symmetry, unbroken contours, or
  evenly distributed noise;
- which regularities must remain to preserve structure, and exactly which
  parameters should vary—position, scale, angle, phase, curvature, spacing,
  hue, value, roughness, edge softness, density, or overlap;
- how to create controlled imperfection rather than indiscriminate noise:
  correlated randomness, low-frequency drift, hierarchical scale variation,
  clusters and sparse exceptions, domain warping, curvature-following
  repetition, broken symmetry, and material-specific wear or texture;
- how multiple mathematical fields will combine: a clean structural field,
  low-frequency compositional modulation, mid-frequency form variation, and
  restrained high-frequency detail, all clipped or weighted by meaningful
  masks;
- which details should be simplified or omitted so the focal forms remain
  elegant and readable.

Every proposed irregularity must serve a named artistic or material purpose.
Randomness alone is not realism, and complexity alone is not elegance.
""".strip()


_DOMAIN_EXPERT_GUIDE = r"""
DOMAIN-EXPERT DIRECTIVE
-----------------------
Work like a production shader artist who can allocate a strict real-time budget
across composition, geometry, spatial variation, material response, lighting,
and color. The goal is not merely to include these topics in the plan: the WGSL
must contain concrete functions and fields that implement the chosen subset.

1. Object-level spatial composition, not wallpaper
   - Separate a cell's integer identity from its local coordinates using
     floor/fract (or the WGSL equivalent). Use the cell identity to hash stable,
     correlated instance attributes such as presence, position, scale, angle,
     bend, species/form variant, material, and color—not only a texture value.
   - When the scene benefits from repeated elements, repeat actual 3D or
     analytic objects: feather groups, foliage, scales, stones, fibers, clouds,
     architectural pieces, or other subject-specific forms. Search neighboring
     cells where necessary so shifted instances do not create seams.
   - Break grid regularity deliberately with occupancy masks, clusters and
     clearings, low-frequency density drift, hierarchical cells, sparse hero
     exceptions, domain warping, and bounded per-instance variation. Preserve
     the large-scale silhouette and focal hierarchy.
   - Repetition is an acceleration and composition technique, not a license to
     stamp one motif everywhere. Bound the repeated-object region and skip or
     simplify work outside its envelope.

2. Multi-scale procedural form
   - Assign distinct jobs to frequency bands: analytic/SDF macro shape;
     low-frequency gesture and asymmetry; mid-frequency object variation;
     restrained high-frequency surface detail.
   - Prefer rotated octave bases, derivative-aware noise when useful, and
     object/material-space fields over screen-space noise. If derivatives are
     too expensive, use stable finite differences or a cheaper justified
     approximation.
   - Distort geometry only where it improves the named material or silhouette.
     Do not let noise destroy distance-field stepping safety, normals, or the
     recognizable macro form.

3. Palette architecture and color pipeline
   - In the public plan, define a palette ladder before coding: dominant,
     shadow, light, accent, atmospheric/background, and neutral colors. Describe
     their hue, value, saturation/chroma, temperature, contrast, and area
     relationships.
   - In WGSL, place concise color-theory comments next to named palette
     constants and reusable helpers. Prefer meaningful operations such as
     value-preserving hue bias, warm/cool light separation, saturation control,
     luminance-aware mixing, atmospheric extinction, and a restrained final
     grade over unrelated literal colors.
   - Keep color variation correlated with geometry, material, lighting, or
     composition. Do not spray independent RGB noise over the image.

4. Material and reflectance design
   - Define the material signal explicitly: at minimum albedo plus roughness or
     specular response, and add transmission, subsurface-like wrap, metallic,
     emission, or anisotropy only when the subject needs it.
   - Generate bump/normal variation in object or material coordinates and keep
     it subordinate to the geometric normal. A flat shiny primitive with a
     screen-space pattern is not an acceptable substitute for material.
   - Couple lighting to the material using a coherent diffuse/specular model,
     view-dependent Fresnel, roughness-dependent highlight width, soft shadow or
     ambient occlusion, and plausible rim/transmission where appropriate.
   - Let different surfaces respond differently. State how each major material
     changes the normal field, albedo, roughness, specular color, and light
     transport.

5. Scene architecture and budget
   - Use a real 3D camera and genuine geometry for volumetric subjects. Choose
     analytic intersections, bounded ray-marched SDFs, height fields, volume
     integration, or a hybrid according to the form. Use bounding planes,
     spheres, envelopes, or intervals before expensive marching.
   - Spend computation hierarchically: silhouette and pose first, then major
     overlaps, materials and light, characteristic repeated forms, and finally
     microdetail. A simpler complete scene beats an unfinished technical demo.
   - State hard budgets for primary steps, shadow/volume steps, neighborhood
     searches, primitive evaluations, antialiasing, and the static t=0 frame.

The attached reference is evidence about the target, not a texture to import.
The final shader must be self-contained and procedural with no external files,
textures, extra bindings, or runtime changes.
""".strip()


_PROFILE_SUFFIXES: Dict[str, str] = {
    BASELINE_PROFILE: "",
    CHATGPT_SHADER_HARNESS_PROFILE: r"""

EXPERIMENTAL PROFILE: CHATGPT + SHADER HARNESS V1
=================================================

This section intentionally extends the baseline response contract. The phrase
"ONLY valid WGSL code" above means that the <shader> element must contain only
valid WGSL. For this experimental profile, you MUST place exactly one concise
design brief before that element:

<scratchpad>
...compact, decision-relevant shader design brief...
</scratchpad>
<shader file="shader.wgsl">
...complete WGSL...
</shader>

Do not output a <think> section, hidden chain-of-thought, or prose outside those
two elements. The scratchpad is a public production plan, not a transcript of
private reasoning. Keep it under 900 words so the complete shader retains most
of the output budget.

Before coding, stop and break the scene down with the clarity of an expert
shader-art tutorial. The scratchpad MUST cover:

1. Scene read and art direction
   - Identify the dominant silhouette, focal hierarchy, camera/view, depth
     cues, palette, contrast, material character, atmosphere, and the subtle
     features that make this particular subject recognizable.
   - Optimize for perceptual fidelity, elegance, and deliberate art direction,
     not merely a checklist of approximate pixels.

2. Competing representations
   - Propose at least three materially different approaches and briefly compare
     their fidelity, complexity, robustness, and likely failure modes.
   - Explicitly choose among 2D construction, layered 2.5D, analytic ray
     intersections, ray-marched 3D SDFs, or a justified hybrid.
   - Do not default to flat 2D masks when volume, perspective, occlusion,
     lighting, or material response are important. For volumetric subjects,
     strongly prefer a real perspective camera plus 3D geometry or a 2.5D/3D
     hybrid.

3. Geometry and composition plan
   - List the major primitives and coordinate systems. State where to use SDF
     union, smooth union, intersection, subtraction, deformation, repetition,
     analytic intersections, layered masks, or another technique.
   - Describe proportions, overlap order, negative space, crop, and how the
     composition matches the reference or requested visualization.

4. Equations and checks
   - Record the key equations needed by the implementation: camera rays,
     transforms, SDFs/intersections, smooth-min or CSG operations, normals,
     palette functions, falloffs, and any mathematical construction central to
     the problem.
   - Include short derivations, invariants, bounds, or sanity checks where they
     genuinely prevent a visual or mathematical error. Do not pad the brief
     with ceremonial proofs.

5. Surface, light, and detail strategy
   - Plan normals, key/fill/rim lighting, shadows, ambient occlusion, specular
     response, Fresnel, fog, glow, and tone mapping as appropriate.
   - Use hash noise, value/gradient noise, fBm, ridged noise, domain warping,
     cellular structure, or procedural pattern math only where each supports a
     named visual feature. Avoid obvious uniform grids unless the subject
     actually has them.
   - Allocate detail across macro silhouette, medium forms, and fine texture;
     preserve readability at the final static render.

6. Final implementation audit
   - State the chosen approach and why it beats the alternatives.
   - Check that every requested element is represented, the static t=0 frame is
     intentional, loops are bounded, antialiasing is considered, and all WGSL
     obeys the supplied ABI.

Then implement the strongest chosen design completely. The shader must be
self-contained and procedural: no external textures, files, extra bindings, or
runtime changes. Prefer a coherent, polished image over many weak effects.
""".strip(),
    SCRATCHPAD_PROFILE: f"""

EXPERIMENTAL PROFILE: SHADER SCRATCHPAD V1
==========================================

This section extends the baseline response contract. The <shader> element must
contain only valid WGSL. Before it, return exactly one public design brief:

<scratchpad>
...compact, decision-relevant shader production plan...
</scratchpad>
<shader file="shader.wgsl">
...complete WGSL...
</shader>

Do not output a <think> section, hidden chain-of-thought, or prose outside those
two elements.

{_SCRATCHPAD_BRIEF}

Then implement the selected design completely. The shader must be self-contained
and procedural: no external textures, files, extra bindings, or runtime changes.
""".strip(),
    SCRATCHPAD_ART_DIRECTION_PROFILE: f"""

EXPERIMENTAL PROFILE: SHADER SCRATCHPAD + ART DIRECTION V1
==========================================================

This section extends the baseline response contract. The <shader> element must
contain only valid WGSL. Return exactly these three elements in this order:

<artistic_subtleties_and_elegance>
...compact art-direction and controlled-irregularity guide...
</artistic_subtleties_and_elegance>
<scratchpad>
...compact, decision-relevant shader production plan...
</scratchpad>
<shader file="shader.wgsl">
...complete WGSL...
</shader>

Do not output a <think> section, hidden chain-of-thought, or prose outside those
three elements. Keep both planning blocks together under 1,100 words so the
complete WGSL retains most of the output budget.

{_ART_DIRECTION_GUIDE}

{_SCRATCHPAD_BRIEF}

The scratchpad must explicitly apply the art-direction guide: name which
regularities remain, which are broken, and how the chosen equations implement
that controlled variation. Then implement the selected design completely. The
shader must be self-contained and procedural: no external textures, files,
extra bindings, or runtime changes.
""".strip(),
    AMBITIOUS_3D_PROFILE: f"""

EXPERIMENTAL PROFILE: AMBITIOUS 3D SHADER V1
============================================

This section extends the baseline response contract. The <shader> element must
contain only valid WGSL. Before it, return exactly one compact public production
plan:

<scratchpad>
...ambitious 3D scene and implementation plan...
</scratchpad>
<shader file="shader.wgsl">
...complete WGSL...
</shader>

Do not output a <think> section, hidden chain-of-thought, or prose outside those
two elements. Keep the scratchpad under 850 words so the complete shader retains
most of the output budget.

AMBITION DIRECTIVE
------------------
Approach this as an expert shader artist building a memorable scene, not as a
minimal coding exercise. When the subject has physical volume, perspective,
occlusion, or material response, true 3D is the default—not an optional idea to
reject because it is harder. A compact scene of well-chosen 3D primitives is
preferable to an elaborate stack of flat masks.

For a volumetric subject, the final shader MUST include:
- a perspective or deliberately justified orthographic camera ray in 3D;
- genuine 3D geometry through ray-marched SDFs, analytic ray intersections, or
  a hybrid of both;
- macro forms built from a small, expressive vocabulary such as ellipsoids,
  spheres, capsules, cones, rounded boxes, tori, planes, curves, and
  deformation or smooth CSG;
- normals derived from the 3D field or analytic surface, not painted screen
  gradients standing in for geometry;
- depth-aware key/fill/rim lighting, material response, and at least one of
  cast/soft shadows, ambient occlusion, Fresnel, reflection, subsurface-like
  wrap, fog, or depth-of-field;
- a clear foreground/midground/background depth plan and real occlusion between
  major forms.

Do not model thousands of tiny objects. Spend geometry on the silhouette,
pose, major overlaps, and characteristic forms; put fine detail into
object-space procedural fields, triplanar or local coordinates, bump/normal
perturbation, sparse secondary primitives, and material variation. If the full
subject is too expensive, simplify the subject while keeping the macro scene
genuinely 3D. Do not collapse back to 2.5D.

Screen-space 2D is allowed for background bokeh, annotations, compositing,
antialiasing, and restrained post-processing, but it must not construct the
primary volumetric subject. Purely planar or diagrammatic prompts may remain 2D
when 3D would be semantically wrong; state that exception explicitly.

The plan must identify the ambitious visual payoff: what depth, silhouette,
camera, lighting, material, atmosphere, or emotional quality the 3D construction
achieves that layered 2D cannot. It must also state a bounded performance budget
for ray steps, shadow steps, primitive count, and antialiasing.

{_SCRATCHPAD_BRIEF}

Then implement the strongest complete version, not a placeholder. Preserve the
problem's mathematical requirements and reference composition while using 3D
ambition to improve form, elegance, and art direction. The shader must remain
self-contained and procedural: no external textures, files, extra bindings, or
runtime changes.
""".strip(),
    SCRATCHPAD_ART_DIRECTION_AMBITIOUS_3D_PROFILE: f"""

EXPERIMENTAL PROFILE: SCRATCHPAD + ART DIRECTION + AMBITIOUS 3D V1
=================================================================

This section extends the baseline response contract. The <shader> element must
contain only valid WGSL. Return exactly these three elements in this order:

<artistic_subtleties_and_elegance>
...compact art-direction and controlled-irregularity guide...
</artistic_subtleties_and_elegance>
<scratchpad>
...ambitious 3D scene and implementation plan...
</scratchpad>
<shader file="shader.wgsl">
...complete WGSL...
</shader>

Do not output a <think> section, hidden chain-of-thought, or prose outside those
three elements. Keep both planning blocks together under 1,150 words so the
complete WGSL retains most of the output budget.

{_ART_DIRECTION_GUIDE}

AMBITION DIRECTIVE
------------------
Approach this as an expert shader artist building a memorable scene, not as a
minimal coding exercise. When the subject has physical volume, perspective,
occlusion, or material response, true 3D is the default—not an optional idea to
reject because it is harder. A compact scene of well-chosen 3D primitives is
preferable to an elaborate stack of flat masks.

For a volumetric subject, the final shader MUST include:
- a perspective or deliberately justified orthographic camera ray in 3D;
- genuine 3D geometry through ray-marched SDFs, analytic ray intersections, or
  a hybrid of both;
- macro forms built from an expressive vocabulary such as ellipsoids, spheres,
  capsules, cones, rounded boxes, tori, curves, deformation, and smooth CSG;
- normals derived from the 3D field or analytic surface, not painted screen
  gradients standing in for geometry;
- depth-aware key/fill/rim lighting, material response, and at least one of
  cast/soft shadows, ambient occlusion, Fresnel, reflection, subsurface-like
  wrap, fog, or depth-of-field;
- a clear foreground/midground/background plan and real occlusion between
  major forms.

Do not model thousands of tiny objects. Spend geometry on silhouette, pose,
major overlaps, and characteristic forms. Put fine detail into object-space
procedural fields, local coordinates, bump/normal perturbation, sparse
secondary primitives, and material variation. Screen-space 2D is allowed for
background and restrained post-processing, but it must not construct the
primary volumetric subject. Do not collapse back to 2.5D.

The art-direction guide must name the emotional and visual payoff that true 3D
provides. The scratchpad must explicitly translate that guide into camera,
geometry, lighting, material, controlled irregularity, and a bounded budget for
ray steps, shadow steps, primitive count, and antialiasing.

{_SCRATCHPAD_BRIEF}

Then implement the strongest complete version. Preserve the problem's
mathematical requirements and reference composition. The shader must remain
self-contained and procedural: no external textures, files, extra bindings, or
runtime changes.
""".strip(),
    DOMAIN_EXPERT_PROFILE: f"""

EXPERIMENTAL PROFILE: DOMAIN EXPERT SHADER V1
=============================================

This section extends the baseline response contract. The <shader> element must
contain only valid WGSL. Return exactly these three elements in this order:

<artistic_subtleties_and_elegance>
...compact art direction, palette architecture, and controlled variation...
</artistic_subtleties_and_elegance>
<scratchpad>
...compact scene architecture, math, material, and performance specification...
</scratchpad>
<shader file="shader.wgsl">
...complete WGSL...
</shader>

Do not output a <think> section, hidden chain-of-thought, or prose outside those
three elements. These are concise public design artifacts, not a transcript of
private reasoning. Keep both planning blocks together under 1,250 words so the
complete shader retains most of the output budget.

{_ART_DIRECTION_GUIDE}

{_DOMAIN_EXPERT_GUIDE}

{_SCRATCHPAD_BRIEF}

The art-direction block must define the palette ladder and identify which
regularities preserve the subject versus which are deliberately broken. The
scratchpad must translate that direction into concrete coordinate systems,
object-level repetition, geometry, materials, reflectance, lighting, bounding
acceleration, and a bounded implementation budget. Then implement the strongest
complete version. Do not merely restate this directive in comments.
""".strip(),
}


def prompt_profile_choices():
    """Return stable CLI choices in display order."""
    return tuple(_PROFILE_SUFFIXES)


def validate_prompt_profile(profile: str) -> str:
    if profile not in _PROFILE_SUFFIXES:
        choices = ", ".join(prompt_profile_choices())
        raise ValueError(f"Unknown prompt profile {profile!r}; choose one of: {choices}")
    return profile


def apply_prompt_profile(full_prompt: str, profile: str) -> str:
    """Apply a named suffix without altering the preserved baseline prompt."""
    validate_prompt_profile(profile)
    suffix = _PROFILE_SUFFIXES[profile]
    if not suffix:
        return full_prompt
    return f"{full_prompt.rstrip()}\n\n{suffix}\n"
