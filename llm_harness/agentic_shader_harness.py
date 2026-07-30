#!/usr/bin/env python3
"""Run one persistent Codex shader agent with bounded render/edit tools."""

from __future__ import annotations

import argparse
import asyncio
import html
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from judge import EvaluationContext, Judge
from language_specs import get_language_spec
from llm_client import generation_isolation_metadata, parse_cli_spec
from prompt_profiles import (
    BASELINE_PROFILE,
    apply_prompt_profile,
    prompt_profile_choices,
)
from test_runner import TestRunner


PROTOCOL = "persistent-agent-render-tools-v5"
STANDARD_WORKFLOW = "standard"
SKETCHBOOK_WORKFLOW = "sketchbook-3x2-v1"
CURVED_ELEMENT_SKETCHBOOK_WORKFLOW = "sketchbook-curved-elements-v2"
CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW = "sketchbook-continuous-elements-v3"
PROGRESSIVE_APPLICATION_WORKFLOW = "sketchbook-progressive-application-v4"
HIERARCHICAL_WIDE_SEARCH_WORKFLOW = "sketchbook-hierarchical-wide-search-v5"
SKETCHBOOK_WORKFLOWS = (
    SKETCHBOOK_WORKFLOW,
    CURVED_ELEMENT_SKETCHBOOK_WORKFLOW,
    CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW,
    PROGRESSIVE_APPLICATION_WORKFLOW,
    HIERARCHICAL_WIDE_SEARCH_WORKFLOW,
)
MCP_TOOLS = (
    "write_shader",
    "render_shader",
    "record_study",
    "submit_final",
)


def workflow_requires_variant_inventory(workflow: str) -> bool:
    return workflow in {
        CURVED_ELEMENT_SKETCHBOOK_WORKFLOW,
        CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW,
        PROGRESSIVE_APPLICATION_WORKFLOW,
        HIERARCHICAL_WIDE_SEARCH_WORKFLOW,
    }


def workflow_required_studies(workflow: str) -> int:
    if workflow == STANDARD_WORKFLOW:
        return 0
    if workflow == PROGRESSIVE_APPLICATION_WORKFLOW:
        return 4
    if workflow == HIERARCHICAL_WIDE_SEARCH_WORKFLOW:
        return 6
    if workflow in SKETCHBOOK_WORKFLOWS:
        return 3
    raise ValueError(f"unknown agent workflow: {workflow}")


def _json_config(value: Any) -> str:
    """Encode strings/arrays as TOML-compatible CLI config literals."""
    return json.dumps(value, ensure_ascii=True)


def build_agent_prompt(
    problem_request: str,
    prompt_profile: str,
    render_budget: int,
    min_successful_revisions: int = 2,
    workflow: str = STANDARD_WORKFLOW,
) -> str:
    language_spec = get_language_spec("wgsl")
    canonical_prompt = f"""\
{language_spec.constraint_prompt.rstrip()}

PROBLEM CONTEXT
===============
{problem_request.strip()}
"""
    profiled_prompt = apply_prompt_profile(canonical_prompt, prompt_profile)
    if workflow not in {STANDARD_WORKFLOW, *SKETCHBOOK_WORKFLOWS}:
        raise ValueError(f"unknown agent workflow: {workflow}")
    required_studies = workflow_required_studies(workflow)
    sketchbook_contract = (
        f"""

MANDATORY 3×2 VISUAL SKETCHBOOK
==============================

Before building the final reconstruction, use rendered evidence to resolve
{required_studies} high-risk, subject-specific design decisions. This is a
public production study, not hidden chain-of-thought. Select the core elements from the
reference rather than hardcoding the examples below.

Study selection:
- Study 1 normally resolves macro form, silhouette, pose, projection, or scene
  architecture.
- Study 2 normally resolves the signature meso-scale element and how it is
  distributed, oriented, overlapped, or wrapped over its parent form.
- Study 3 normally resolves material response, palette relationships, lighting,
  atmospheric treatment, or another unresolved identity-carrying element.
- A workflow-specific contract below may replace these default roles and
  define a longer dependent study chain.
- Adapt these roles when a mathematical plot, landscape, typography, fluid,
  architecture, or abstract target has different dominant risks.

For EACH study:
1. Write a self-contained study shader whose entire image is a clean 3-column
   by 2-row atlas. The six cells are variants A, B, C, D, E, F in reading order.
   Give every cell equal scale, safe margins, a consistent comparison camera,
   and a visibly distinct construction. Tiny random-seed or parameter changes
   do not count as six alternatives.
2. For shape studies, vary the actual representation: silhouette/profile,
   thickness, curvature, taper, overlap, deformation, normal construction, or
   primitive/CSG/intersection method. Do not compare six copies of one peg,
   capsule, disk, or decal.
3. For placement studies, test a parent-surface coordinate frame and coherent
   distribution fields. Compare useful combinations of curvature-following
   orientation, layered overlap, low-frequency fBm/domain warp, correlated
   jitter, density drift, clusters, and sparse exceptions. Noise must modulate
   a designed structure; it must not erase the parent silhouette or become
   screen-space static.
4. Call render_shader(stage="study", study_index=N), inspect the returned atlas,
   and revise/render that study if the variants do not answer the design
   question and budget remains.
5. Call record_study only after inspecting a successful atlas. Record the
   selected A-F cell using visible comparison evidence and name the exact
   function family, coordinate frame, parameter ranges, and aesthetic
   properties that must be carried into the final shader.

After all required selections are recorded, replace the atlas with the complete
reconstruction. The final shader must materially reuse the selected
representations and handoff requirements; do not restart from generic
primitives. Render it with render_shader(stage="final", study_index=0), compare
it to the reference, and iterate the final scene. Study atlases are experiments,
not valid final submissions.
"""
        if required_studies
        else ""
    )
    curved_element_contract = (
        r"""

CURVED-ELEMENT AND SURFACE-WRAPPING GATE
========================================

The previous 3×2 workflow can fail by comparing six arrangements while keeping
one weak oval/capsule primitive. This workflow separates shape search from
placement search whenever repeated organic or bent elements carry the subject's
identity (feathers, leaves, petals, scales, hair clumps, cloth strips, fins,
tiles on a curved shell, layered clouds, or analogous motifs).

Study 2 — isolated element-shape laboratory:
- Fill 65–80% of each cell with ONE enlarged element under the same camera and
  lighting. Do not show a full arrangement.
- A–F must be six different construction families or centerline/width/cross-
  section combinations. A uniformly scaled ellipsoid, capsule, lozenge, disk,
  or pointed oval is not an acceptable organic element.
- Give the element a longitudinal coordinate s in [0,1], a curved centerline
  C(s), and independently designed width w(s), thickness h(s), lift/camber,
  root attachment, and tip. At minimum compare quadratic or cubic bend, swept
  tapered segments, asymmetric vane/profile, and a layered or notched option
  when appropriate.
- A useful generic family is:
    C(s) = p0 + T*L*s + B*(bend*s*s + sweep*sin(pi*s))
                 + N*(lift*sin(pi*s) + camber*s*(1-s))
    w(s) = mix(rootWidth, maxWidth, smoothstep(0, shoulder, s))
           * (1 - smoothstep(taperStart, 1, s))
    h(s) = thickness * (0.35 + 0.65*sin(pi*s))
  This is a design scaffold, not a requirement to make all six variants from
  one formula. Use bounded segment sweeps, inverse-bend coordinates, Bezier
  centerlines, SDF intersection/subtraction, or another robust construction.
- The study record must inventory what A, B, C, D, E, and F actually changed.

Study 3 — parent-surface attachment and distribution laboratory:
- Reuse the selected Study-2 function. Do not replace it with a cheaper oval.
- Show the same curved parent form in all six cells and vary how the elements
  fit it. Compute or approximate a surface point P(u,v), normal N, flow tangent
  T, and bitangent B. Transform each element through that local frame so its
  root is embedded, its body follows curvature, and its tip lifts or overlaps.
- Apply low-frequency fBm/domain warp to (u,v), density, bend, and flow angle,
  not merely to screen-space color or world-space row positions. Combine it
  with bounded correlated jitter and deliberate sparse exceptions.
- Compare staggered rows, geodesic/flow-following arcs, scale gradients,
  occlusion order, root-to-tip overlap, boundary clipping, and silhouette hero
  elements. Preserve the parent silhouette and prevent geometry from escaping.
- The selected handoff must name the parent parameterization/frame, warp
  amplitude and frequency range, overlap rule, containment rule, and which
  shape parameters vary coherently across instances.

For targets without a repeated bent/organic signature element, reinterpret
Study 2 as an isolated laboratory for the most important non-rigid primitive
and Study 3 as its coordinate-aware integration into the parent structure.
The mathematical requirement remains general: design a nonuniform local shape
first, then test how its frame and parameters follow the larger form.
"""
        if workflow
        in {
            CURVED_ELEMENT_SKETCHBOOK_WORKFLOW,
            CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW,
            PROGRESSIVE_APPLICATION_WORKFLOW,
        }
        else ""
    )
    continuous_element_contract = (
        r"""

CONTINUOUS IMPLICIT ELEMENT GATE
================================

Do not build one organic element by looping over and unioning spheres,
ellipsoids, capsules, or bead-like segments. Smooth-min only rounds the seams;
it still produces a caterpillar or worm. Each studied and final element must
use one continuous local implicit profile whose center, width, and thickness
vary with its longitudinal coordinate.

Use this robust inverse-bend pattern as the baseline implementation, adapting
axes and parameters to the subject:

    // q is already in the element's local (B,T,N) surface frame.
    s = clamp(q.y / length + 0.5, 0.0, 1.0)
    centerX = bend*s*s + sweep*sin(PI*s)
    centerZ = lift*sin(PI*s) + camber*s*(1.0-s)
    x = q.x - centerX
    z = q.z - centerZ
    grow = smoothstep(0.0, shoulder, s)
    taper = 1.0 - smoothstep(taperStart, 1.0, s)
    width = max(epsilon, mix(rootWidth, maxWidth, grow) * taper)
    thick = max(epsilon, baseThickness
                * mix(rootThicknessFactor, 1.0, sin(PI*s)) * taper)
    crossSection = (length(vec2(x/width, z/thick)) - 1.0)
                   * min(width, thick)
    axialBounds = max(-q.y - 0.5*length, q.y - 0.5*length)
    d = max(crossSection, axialBounds)

This is an approximate distance field under deformation, so use conservative
ray-march steps (roughly 0.5–0.7 times d) and finite-difference normals. Improve
the profile continuously with asymmetric left/right widths, a rachis, a shallow
vane groove, edge notches, or a tip cut only when those operations preserve one
coherent silhouette.

Study 2 must show the isolated continuous profiles large enough to verify:
- narrow embedded root;
- shoulder that widens at a deliberate s rather than at the midpoint by habit;
- nonuniform left/right width where appropriate;
- visible centerline curvature without bead lobes;
- thickness/camber that changes from root through tip;
- a thin, tapered or notched terminal shape rather than a round cap.

Study 3 and the final scene must call the selected continuous function directly.
No lower-fidelity ellipsoid/capsule replacement is allowed during integration.
The study record's handoff must name the function and the exact bend, sweep,
shoulder, taper-start, width, thickness, camber, and surface-frame ranges.
"""
        if workflow
        in {
            CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW,
            PROGRESSIVE_APPLICATION_WORKFLOW,
        }
        else ""
    )
    progressive_application_contract = (
        r"""

PROGRESSIVE STUDY-APPLICATION LADDER
====================================

This workflow requires TWO distinct, visually diverse successful renders of
every study before record_study can accept it. A compile failure or a
near-duplicate atlas is not a pass.

For each study:
- Pass 1 — DIVERGE: render six broad A–F alternatives that span the plausible
  design space. Exaggerate meaningful axes enough to make the differences easy
  to judge. These are prototypes, not six timid finalists.
- Inspect Pass 1. Choose the strongest two candidates and identify their
  visible strengths and weaknesses.
- Pass 2 — REFINE: render a new 3×2 atlas. A/B/C must be three purposeful
  refinements of the first candidate; D/E/F must refine the second. Change
  shape, assembly, or integration variables that answer the observed problems.
  Do not merely rerender Pass 1 or make six tiny seed changes.
- Only after inspecting Pass 2 may you call record_study. Its rationale must
  compare both passes and its handoff must name what survived refinement.
- Additional study renders are allowed when neither pass answers the question
  and the server reports enough remaining budget.
- Before every study render, pass variation_manifest to render_shader. It must
  predeclare materially different A: through F: constructions and the
  meaningful design axis each changes. This is a precommitment, not a
  description written after seeing the atlas.
- After every study render, inspect study_pass_qualified and study_diversity.
  If the pass is rejected as visually near-duplicate, exaggerate structural
  differences and rerender; compilation alone does not advance the study.

The study chain forms a scale ladder. Each later study MUST call and visibly
reuse the selected code from the previous study:

1. PRIMITIVE STUDY
   Isolate one identity-carrying unit at large scale: a feather, leaf, branch,
   cloud lobe, stone, tile, facade module, glyph/mark, curve segment, particle,
   material flake, or another task-specific primitive. Resolve its shape,
   internal structure, coordinate system, and material response.

2. ASSEMBLY / SHEET STUDY
   Build a neutral planar or gently curved swatch from the selected primitive.
   Compare packing, overlap, orientation flow, scale and density gradients,
   clustering, gaps, low-frequency warp, correlated variation, and exceptions.
   The unit must remain recognizable; this is a sheet/coat/grove/facade/field,
   not a texture painted over an unrelated surface.

3. PARENT-INTEGRATION / COAT STUDY
   Transform the selected assembly through the parent object's or scene's
   coordinate frame. Compare surface attachment, tangent/bitangent/normal or
   analogous local bases, root embedding, curvature following, overlap depth,
   containment, boundary behavior, silhouette elements, and art-directed
   domain variation. Show enough of the parent to judge whether the assembly
   belongs to it.
   For a surface, implement this relationship explicitly: evaluate P(u,v);
   compute N from its gradient or derivatives; compute T=dP/du and B=dP/dv (or
   a stable orthonormal equivalent); warp and vary (u,v), not world XY; embed
   each root at P-depth*N; and transform every primitive through (T,B,N).
   Merely computing a curved z position while leaving the primitive in the
   camera/image basis does not count as surface wrapping.

4. RELATIONSHIPS / LAYER-TRANSITION STUDY
   Place the coated parent next to the major forms it touches. Explore how the
   assembly transitions into neighboring layers, disappears under overlaps,
   changes scale or orientation across seams, contributes to the silhouette,
   and shares light/material response. For an organic coat, compare crown,
   shoulder, chest, wing-edge, and body-to-wing transitions rather than
   rendering an isolated shell. For other domains, study the corresponding
   module-to-system and system-to-context relationships.

Then integrate the selected parent treatment into the complete final scene and
iterate at least two successful final renders. For targets without repeated
organic elements, preserve the same abstraction: fundamental unit → composed
system → placement in the larger coordinate structure → finished scene.
"""
        if workflow == PROGRESSIVE_APPLICATION_WORKFLOW
        else ""
    )
    hierarchical_wide_search_contract = (
        r"""

HIERARCHICAL GEOMETRY + WIDE REPRESENTATION SEARCH
==================================================

The previous workflow found a better local detail but converged too early on
independent oval body parts and nearby parameter tweaks. This workflow forbids
hyperparameter search as a substitute for design exploration.

WIDE SEARCH — THREE QUALIFIED PASSES PER STUDY
----------------------------------------------

Each study must render THREE visually diverse successful 3×2 atlases before it
can be recorded: 18 candidate constructions total.

- Pass 1 — STRUCTURAL SURVEY A: A–F are six mutually distinct representation
  families. Changing only dimensions, offsets, counts, bend values, noise
  seeds, or colors does not create a new family.
- Pass 2 — STRUCTURAL SURVEY B: A–F are six NEW representation families, not
  refinements or parameter neighbors of any Pass-1 candidate. Deliberately try
  different topology, coordinate construction, composition rule, implicit
  operation, or mathematical model.
- Pass 3 — SYNTHESIS: create six structurally distinct hybrids. Every candidate
  must combine useful mechanisms from at least two earlier families while
  fixing a visible failure. This is the first pass where refinement is allowed,
  but A–F must still be different architectures rather than six settings.
- Only after inspecting all three passes may record_study select a result. Its
  rationale must compare evidence across all 18 candidates.

Before every render, variation_manifest must describe A: through F: using this
auditable form for each cell:

  family=<representation family>;
  construction=<equations/topology/coordinate method>;
  structural_difference=<what changes besides parameters>

Do not claim a new family when the code still calls the same primitive with
different constants. Inspect study_pass_qualified and study_diversity after
every render. Also inspect cross_render_diversity: the server compares the
whole atlas with qualified passes from this and every earlier study. Reusing a
prior atlas or topic template does not advance the study even when its six
cells differ internally.

ROOTED GEOMETRY DEPENDENCY GRAPH
--------------------------------

The final construction must be a rooted procedural scene graph, not a list of
independent world-space shapes. Only the root/camera may be positioned directly
in world space. Each attached child must derive its origin and basis from its
parent geometry:

  worldPoint =
      rootTransform
    * parentFrame(parentCoordinate)
    * attachmentTransform
    * childFrame(childCoordinate)
    * localPoint

For surfaces, parentFrame includes P, T, B, and N. For curves or skeletons it
includes a centerline point and transported local frame. Store attachment
coordinates such as shoulder-s, branch-s, facade-bay, curve-t, or another
domain coordinate—not an unrelated world-space center. When the parent bends,
rotates, changes proportion, or moves, every descendant must follow.

An attached appendage must be modeled as its own appropriate geometry: a thin
swept/cambered shell, branching extrusion, loft, ribbon, membrane, or other
task-specific form. A full ellipsoid, sphere, capsule, or disk placed beside
the parent is not an acceptable wing, branch, petal layer, roof, limb, or
analogous child merely because its color and silhouette are plausible.

SIX DEPENDENT STUDIES
---------------------

1. ROOT SCAFFOLD + DEPENDENCY STUDY
   Render clay-like whole-subject maquettes. Explore different skeletons,
   centerline graphs, attachment graphs, proportions, poses, and projection
   strategies. Identify the root, parent-child edges, attachment coordinates,
   and frame functions. Major parts must already read as one articulated
   subject rather than neighboring blobs.

2. PRIMARY VOLUME STUDY
   Replace generic base ovals with geometry derived along the selected
   scaffold: swept varying cross-sections, lofts, bent profiles, blended
   anatomical masses, shells, constructive intersections, or other suitable
   families. Cross-section width, thickness, asymmetry, and orientation should
   vary along the parent coordinate. Preserve the dependency graph.

3. ATTACHED FORM / APPENDAGE STUDY
   Build the dominant child form from a parent attachment frame. Explore thin
   shells, swept ribbons, lofted outlines, cambered membranes, branched forms,
   layered surfaces, and other task-relevant families. Include attachment
   stress tests: across the atlas, change the parent's pose/proportion and show
   that the child root, orientation, seam, and silhouette follow automatically.
   A separately positioned oval or capsule fails this study.

4. IDENTITY-CARRYING LOCAL ELEMENT STUDY
   Isolate and broadly search the important local unit. For organic elongated
   elements, use continuous centerline/width/thickness/camber profiles rather
   than bead chains or ovals. For other domains, choose the corresponding
   high-information primitive. Study internal structure and material as part
   of the representation, not as a color afterthought.

5. OVERLAPPING SHEET / FIELD STUDY
   Build a dense assembly from the selected unit on the selected child
   geometry. Search genuinely different assembly algorithms: staggered
   shingles, geodesic bands, transported flow lines, clustered/Voronoi fields,
   hierarchical branching, adaptive tiling, layered shell extrusion, or other
   domain-appropriate approaches. The cells must differ in construction, not
   just row offsets.

   A successful overlapping sheet has visible root-to-tip or upstream-to-
   downstream occlusion, covers most of its parent without erasing the parent
   silhouette, varies density and scale coherently, and contains designed
   irregularity. Adjacent decorations with open gaps are not a sheet. Preserve
   comparable coverage and instance density in the final scene.

6. HIERARCHICAL INTEGRATION + TRANSITION STUDY
   Combine the rooted scaffold, primary volume, attached form, and overlapping
   field. Explore seams, ownership, occlusion, silhouette transitions, and
   material/light continuity between parent and child. Stress the dependency
   graph again with parent pose variations. Record exact helper functions,
   frame composition, attachment domains, coverage/overlap rules, and scene-
   graph edges that the final must preserve.

FINAL HANDOFF INVARIANTS
------------------------

The final shader must call the selected scaffold, parent-frame, attached-form,
local-element, and assembly functions directly. It must preserve the recorded
parent-child graph and approximately the selected sheet coverage/overlap. Do
not collapse the studied child into an independently positioned oval, replace
the sheet with sparse decorations, or restart from unrelated primitives.

For a target without organic anatomy, reinterpret the same general structure:
root scaffold → parent geometry → attached subsystem → local unit → composed
field → contextual integration. Examples include trunk→branch→leaf, terrain→
riverbed→water detail, building frame→facade system→panels, curve→transported
marks, or network→edge bundle→nodes.
"""
        if workflow == HIERARCHICAL_WIDE_SEARCH_WORKFLOW
        else ""
    )
    return f"""\
{profiled_prompt.rstrip()}

AGENTIC RENDER-AND-REVISE EXECUTION CONTRACT
=============================================

This contract replaces the one-shot response envelope above. The reference
image is attached to this persistent session. Do not merely describe an
iteration loop and do not put WGSL in your final chat response.

You have exactly these benchmark tools:
- write_shader(shader_source, revision_critique): replace the complete working
  WGSL program; every rewrite after revision 1 requires a concise critique;
- render_shader(stage, study_index, variation_manifest): compile and render the
  current revision, returning compiler feedback, local study-diversity
  measurements, and the actual rendered image;
- record_study(study_index, subject, selected_variant, selection_rationale,
  handoff_requirements, variant_inventory): preserve public visual-study
  evidence, the A–F construction inventory, and its exact implementation
  handoff;
- submit_final(summary): freeze the current successfully rendered revision.
{sketchbook_contract}
{curved_element_contract}
{continuous_element_contract}
{progressive_application_contract}
{hierarchical_wide_search_contract}

Workflow requirements:
1. Study the reference and plan a strong procedural reconstruction.
2. Call write_shader with a complete shader, then call render_shader. Use
   stage="final" and study_index=0 unless the sketchbook contract above applies.
3. Visually compare every returned render with the reference. Diagnose the
   largest concrete mismatch in silhouette, composition, depth, color,
   lighting, material, or texture before editing.
4. Revise the complete shader and render again when a material improvement is
   plausible. You control when to stop. The hard render-call budget is
   {render_budget}, and compile failures consume budget.
5. Preserve successful features and avoid blind rewrites. You may return to an
   earlier idea because this is one persistent session and your prior tool
   calls remain in context.
6. Call submit_final only when the current exact revision has rendered
   successfully. The harness treats a chat response without submit_final as a
   failed run.

You must produce at least {min_successful_revisions} distinct successfully
rendered FINAL revisions before submitting. The {required_studies} required
studies and their required render passes do not count toward that
final-revision minimum. Re-rendering unchanged code is rejected without
consuming budget. Each rewrite should respond to visible evidence, not merely
satisfy the counter.

For each rewrite, put the target-versus-render evidence, strongest feature to
preserve, and bounded changes you are making in write_shader's
revision_critique argument. The server rejects unaudited rewrites.

The tools expose no arbitrary file paths, textures, benchmark results, judges,
or other contestants' work. Build the image analytically in WGSL. Use the
rendered evidence—not confidence or prose—to decide when the file is done.
"""


def build_codex_command(
    *,
    model_spec: str,
    workspace: Path,
    reference_image: Path | None,
    server_script: Path,
    renderer: Path,
    render_budget: int,
    render_size: int,
    min_successful_revisions: int,
    required_studies: int,
    require_variant_inventory: bool,
    min_successful_study_renders: int,
    require_study_diversity: bool,
    trace_path: Path,
    last_message_path: Path,
) -> list[str]:
    tool, model, effort = parse_cli_spec(model_spec)
    if tool != "codex":
        raise ValueError(
            "The persistent render-tool harness currently requires cli/codex."
        )

    uv_path = shutil.which("uv")
    if not uv_path:
        raise FileNotFoundError("uv is required to launch the local MCP server")

    command = [
        "codex",
        "exec",
        "--ephemeral",
        "--ignore-user-config",
        "--ignore-rules",
        "--sandbox",
        "read-only",
        "--skip-git-repo-check",
        "--cd",
        str(workspace),
        "--json",
        "--output-last-message",
        str(last_message_path),
    ]
    if model:
        command.extend(["--model", model])
    if reference_image:
        command.extend(["--image", str(reference_image)])
    if effort:
        command.extend(["--config", f"reasoning_effort={_json_config(effort)}"])

    server_args = [
        "run",
        "--quiet",
        "--with",
        "mcp>=1,<2",
        "--with",
        "Pillow>=10",
        "python",
        str(server_script),
    ]
    configs = {
        "mcp_servers.shader_tools.command": uv_path,
        "mcp_servers.shader_tools.args": server_args,
        "mcp_servers.shader_tools.cwd": str(workspace),
        "mcp_servers.shader_tools.required": True,
        "mcp_servers.shader_tools.startup_timeout_sec": 30,
        "mcp_servers.shader_tools.tool_timeout_sec": 180,
        "mcp_servers.shader_tools.enabled_tools": list(MCP_TOOLS),
        "mcp_servers.shader_tools.default_tools_approval_mode": "approve",
        "mcp_servers.shader_tools.env.SHADER_AGENT_WORKSPACE": str(workspace),
        "mcp_servers.shader_tools.env.SHADER_AGENT_RENDERER": str(renderer),
        "mcp_servers.shader_tools.env.SHADER_AGENT_RENDER_BUDGET": str(
            render_budget
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_RENDER_SIZE": str(render_size),
        "mcp_servers.shader_tools.env.SHADER_AGENT_MIN_SUCCESSFUL_REVISIONS": str(
            min_successful_revisions
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_REQUIRED_STUDIES": str(
            required_studies
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_REQUIRE_VARIANT_INVENTORY": (
            "1" if require_variant_inventory else "0"
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_MIN_SUCCESSFUL_STUDY_RENDERS": str(
            min_successful_study_renders
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_REQUIRE_STUDY_DIVERSITY": (
            "1" if require_study_diversity else "0"
        ),
    }
    for key, value in configs.items():
        command.extend(["--config", f"{key}={_json_config(value)}"])
    command.append("-")
    return command


def _base_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in (
        "CLAUDECODE",
        "CLAUDECODE_SESSION_ID",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_API_KEY",
    ):
        env.pop(key, None)
    return env


def _copy_workspace(workspace: Path, output_dir: Path) -> None:
    for child in workspace.iterdir():
        if child.name == "reference.png":
            continue
        target = output_dir / child.name
        if child.is_dir():
            shutil.copytree(child, target, dirs_exist_ok=True)
        else:
            shutil.copy2(child, target)


def _agentic_isolation_metadata() -> dict[str, Any]:
    metadata = generation_isolation_metadata("cli/codex")
    metadata.update(
        {
            "protocol": PROTOCOL,
            "persistent_model_session": True,
            "model_render_budget_enforced_server_side": True,
            "fixed_path_mcp_tools": list(MCP_TOOLS),
            "codex_sandbox": "read-only",
            "mcp_server_mutations": "one temporary shader workspace only",
            "study_records_are_public_decision_evidence": True,
        }
    )
    return metadata


async def _judge_render(
    output_dir: Path,
    problem_path: Path,
    judge_model: str,
    render_call: int,
    revision: int,
) -> dict[str, Any]:
    render = output_dir / "renders" / f"render_{render_call:02d}.png"
    shader = (
        output_dir
        / "renders"
        / f"render_{render_call:02d}_revision_{revision:02d}.wgsl"
    )
    judge_dir = output_dir / "renders" / f"judge_render_{render_call:02d}"
    judge_dir.mkdir(exist_ok=True)
    judge = Judge(judge_model=judge_model)
    scores, failure_reason, usage = await judge.evaluate_with_template(
        EvaluationContext(
            critic_path=problem_path / "critic.txt",
            request_path=problem_path / "request.txt",
            result_image_path=render,
            save_dir=judge_dir,
            code_path=shader,
            reference_image_path=problem_path / "reference.png",
        )
    )
    result = {
        "render_call": render_call,
        "revision": revision,
        "judge_model": judge_model,
        "scores": scores,
        "total": sum(scores),
        "failure_reason": failure_reason,
        "usage": usage,
    }
    (judge_dir / "judge_result.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    return result


async def _judge_render_sequence(
    output_dir: Path,
    problem_path: Path,
    judge_model: str,
    state: dict[str, Any],
) -> list[dict[str, Any]]:
    successful = [
        (int(event["render_call"]), int(event["revision"]))
        for event in state.get("events", [])
        if event.get("type") == "render_shader" and event.get("ok")
        and event.get("stage", "final") == "final"
    ]
    return list(
        await asyncio.gather(
            *(
                _judge_render(
                    output_dir,
                    problem_path,
                    judge_model,
                    render_call,
                    revision,
                )
                for render_call, revision in successful
            )
        )
    )


def _render_report(
    output_dir: Path,
    problem_path: Path,
    result: dict[str, Any],
) -> Path:
    state = result.get("state") or {}
    render_events = [
        event
        for event in state.get("events", [])
        if event.get("type") == "render_shader"
    ]
    panels = [
        (
            "Reference",
            problem_path / "reference.png",
            "Target image",
        )
    ]
    judged_by_call = {
        int(item["render_call"]): item
        for item in result.get("render_judges", [])
    }
    for event in render_events:
        if event.get("ok"):
            render_call = event["render_call"]
            stage = event.get("stage", "final")
            study_index = int(event.get("study_index", 0))
            study_pass = int(event.get("study_pass", 0))
            judged = judged_by_call.get(int(render_call))
            score_caption = (
                f" · {judged['total']} / 500" if judged else ""
            )
            diversity_caption = ""
            if stage == "study":
                within = event.get("study_diversity") or {}
                cross = event.get("cross_render_diversity") or {}
                measurements = []
                if within.get("mean_pairwise_mae_percent") is not None:
                    measurements.append(
                        "cell Δ "
                        f"{within['mean_pairwise_mae_percent']:.3f}%"
                    )
                if cross.get("same_study_min_mae_percent") is not None:
                    measurements.append(
                        "pass Δ "
                        f"{cross['same_study_min_mae_percent']:.3f}%"
                    )
                if cross.get("other_study_min_mae_percent") is not None:
                    measurements.append(
                        "topic Δ "
                        f"{cross['other_study_min_mae_percent']:.3f}%"
                    )
                if measurements:
                    diversity_caption = " · " + " · ".join(measurements)
            panels.append(
                (
                    (
                        (
                            f"Study {study_index} · pass {study_pass}"
                            f" · render {render_call}"
                        )
                        if stage == "study"
                        else f"Final render {render_call}"
                    )
                    + f" · revision {event['revision']}",
                    output_dir / "renders" / f"render_{render_call:02d}.png",
                    (
                        f"{event.get('remaining_renders', 0)} renders left"
                        f"{score_caption}"
                        f"{diversity_caption}"
                        + (
                            " · diversity gate failed"
                            if stage == "study"
                            and not event.get("study_pass_qualified", True)
                            else ""
                        )
                    ),
                )
            )
    if (output_dir / "final_render.png").exists():
        panels.append(("Submitted final", output_dir / "final_render.png", ""))

    panel_html = "\n".join(
        f"""<article><h2>{html.escape(title)}</h2>
<img src="{html.escape(os.path.relpath(path, output_dir))}" alt="{html.escape(title)}">
<p>{html.escape(caption)}</p></article>"""
        for title, path, caption in panels
        if path.exists()
    )
    judge = result.get("judge")
    judge_html = (
        f"<p><strong>Judge:</strong> {html.escape(judge['judge_model'])} · "
        f"<strong>{judge['total']} / 500</strong> · {judge['scores']}</p>"
        if judge
        else "<p>No judge score.</p>"
    )
    study_records = state.get("study_records", {})
    study_html = ""
    if study_records:
        items = "\n".join(
            "<li><strong>Study "
            + html.escape(str(record.get("study_index", index)))
            + ": "
            + html.escape(str(record.get("subject", "")))
            + "</strong> — selected "
            + html.escape(str(record.get("selected_variant", "")))
            + "<br>"
            + html.escape(str(record.get("selection_rationale", "")))
            + (
                "<br><em>Variants:</em> "
                + html.escape(str(record.get("variant_inventory", "")))
                if record.get("variant_inventory")
                else ""
            )
            + "<br><em>Handoff:</em> "
            + html.escape(str(record.get("handoff_requirements", "")))
            + "</li>"
            for index, record in sorted(
                study_records.items(), key=lambda item: int(item[0])
            )
        )
        study_html = f"<h2>Recorded study decisions</h2><ol>{items}</ol>"
    report = output_dir / "agentic_report.html"
    report.write_text(
        f"""<!doctype html><meta charset="utf-8"><title>Agentic shader run</title>
<style>
body{{font:16px system-ui;background:#0d1117;color:#d7dde8;margin:2rem}}
.meta{{background:#161b22;padding:1rem;border-radius:10px;margin-bottom:1rem}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:1rem}}
article{{background:#161b22;padding:1rem;border-radius:10px}}
img{{display:block;width:100%;aspect-ratio:1;object-fit:contain;background:#000}}
code{{color:#9ecbff}}
</style>
<h1>Persistent agent render-tool experiment</h1>
<div class="meta">
<p><strong>Model:</strong> {html.escape(result['model'])} ·
<strong>Profile:</strong> {html.escape(result['prompt_profile'])} ·
<strong>Workflow:</strong> {html.escape(result.get('workflow', STANDARD_WORKFLOW))} ·
<strong>Budget:</strong> {result['render_budget']} renders ·
<strong>Used:</strong> {state.get('render_calls', 0)}</p>
{judge_html}
<p>Protocol: <code>{PROTOCOL}</code></p>
{study_html}
</div><div class="grid">{panel_html}</div>""",
        encoding="utf-8",
    )
    return report


async def run_agentic_shader(
    *,
    model: str,
    problem: str,
    prompt_profile: str,
    render_budget: int,
    render_size: int,
    min_successful_revisions: int,
    workflow: str,
    judge_model: str | None,
    run_id: str | None,
) -> Path:
    if render_budget < 1:
        raise ValueError("render_budget must be at least 1")
    required_studies = workflow_required_studies(workflow)
    require_variant_inventory = workflow_requires_variant_inventory(workflow)
    if workflow not in {STANDARD_WORKFLOW, *SKETCHBOOK_WORKFLOWS}:
        raise ValueError(f"unknown agent workflow: {workflow}")
    if not 1 <= min_successful_revisions <= render_budget:
        raise ValueError(
            "min_successful_revisions must be between 1 and render_budget"
        )
    min_successful_study_renders = (
        3
        if workflow == HIERARCHICAL_WIDE_SEARCH_WORKFLOW
        else 2
        if workflow == PROGRESSIVE_APPLICATION_WORKFLOW
        else 1
    )
    require_study_diversity = workflow in {
        PROGRESSIVE_APPLICATION_WORKFLOW,
        HIERARCHICAL_WIDE_SEARCH_WORKFLOW,
    }
    minimum_render_budget = (
        required_studies * min_successful_study_renders
        + min_successful_revisions
    )
    if render_budget < minimum_render_budget:
        raise ValueError(
            "render_budget must allow every required successful study render "
            "plus the minimum successful final revisions"
        )
    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent
    problem_path = (repo_root / "problems" / "base_set" / problem).resolve()
    if not problem_path.is_dir():
        raise FileNotFoundError(f"problem not found: {problem_path}")

    renderer = (
        repo_root / "shader_harness" / "target" / "release" / "shader-bench"
    )
    if not renderer.exists():
        runner = TestRunner()
        await runner.prebuild_shader_binary()
        renderer = runner.shader_bench_binary
    if renderer is None or not renderer.exists():
        raise FileNotFoundError("shader-bench release binary is unavailable")

    safe_model = model.replace("/", "_").replace(":", "_")
    actual_run_id = run_id or (
        f"{uuid.uuid4().hex[:8]}_agentic_{safe_model}_"
        f"{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    )
    output_dir = script_dir / "benchmark_run_output" / actual_run_id
    output_dir.mkdir(parents=True, exist_ok=False)

    request = (problem_path / "request.txt").read_text(encoding="utf-8")
    prompt = build_agent_prompt(
        request,
        prompt_profile,
        render_budget,
        min_successful_revisions,
        workflow,
    )
    (output_dir / "agent_prompt.txt").write_text(prompt, encoding="utf-8")

    with tempfile.TemporaryDirectory(
        prefix="shader_agent_workspace_"
    ) as temporary:
        workspace = Path(temporary).resolve()
        reference_source = problem_path / "reference.png"
        staged_reference = None
        if reference_source.exists():
            staged_reference = workspace / "reference.png"
            shutil.copy2(reference_source, staged_reference)

        trace_path = output_dir / "agent_trace.jsonl"
        last_message_path = output_dir / "last_message.txt"
        command = build_codex_command(
            model_spec=model,
            workspace=workspace,
            reference_image=staged_reference,
            server_script=script_dir / "shader_agent_mcp.py",
            renderer=renderer,
            render_budget=render_budget,
            render_size=render_size,
            min_successful_revisions=min_successful_revisions,
            required_studies=required_studies,
            require_variant_inventory=require_variant_inventory,
            min_successful_study_renders=min_successful_study_renders,
            require_study_diversity=require_study_diversity,
            trace_path=trace_path,
            last_message_path=last_message_path,
        )
        (output_dir / "command.json").write_text(
            json.dumps(command, indent=2), encoding="utf-8"
        )
        completed = await asyncio.to_thread(
            subprocess.run,
            command,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=1800,
            env=_base_env(),
            cwd=workspace,
        )
        trace_path.write_text(completed.stdout or "", encoding="utf-8")
        (output_dir / "codex_stderr.txt").write_text(
            completed.stderr or "", encoding="utf-8"
        )
        _copy_workspace(workspace, output_dir)

    state_path = output_dir / "agent_state.json"
    state = (
        json.loads(state_path.read_text(encoding="utf-8"))
        if state_path.exists()
        else {}
    )
    submitted = (output_dir / "submission.json").exists()
    result: dict[str, Any] = {
        "protocol": PROTOCOL,
        "model": model,
        "problem": problem,
        "prompt_profile": prompt_profile,
        "render_budget": render_budget,
        "render_size": render_size,
        "min_successful_revisions": min_successful_revisions,
        "workflow": workflow,
        "required_studies": required_studies,
        "require_variant_inventory": require_variant_inventory,
        "min_successful_study_renders": min_successful_study_renders,
        "require_study_diversity": require_study_diversity,
        "codex_returncode": completed.returncode,
        "submitted": submitted,
        "state": state,
        "isolation": _agentic_isolation_metadata(),
    }
    if completed.returncode != 0:
        result["error"] = (
            completed.stderr or completed.stdout or "Codex failed"
        )[-8_000:]
    if submitted and judge_model:
        result["render_judges"] = await _judge_render_sequence(
            output_dir, problem_path, judge_model, state
        )
        submission = json.loads(
            (output_dir / "submission.json").read_text(encoding="utf-8")
        )
        chosen_call = submission.get("render_call")
        result["judge"] = next(
            (
                item
                for item in result["render_judges"]
                if item["render_call"] == chosen_call
            ),
            None,
        )

    report = _render_report(output_dir, problem_path, result)
    result["report"] = str(report)
    (output_dir / "result.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    if not submitted:
        raise RuntimeError(
            f"Agent did not call submit_final. Inspect {trace_path}"
        )
    return report


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Give one persistent Codex session bounded write/render/submit "
            "tools and let it decide how to iterate."
        )
    )
    parser.add_argument(
        "--model", default="cli/codex:gpt-5.6-sol:medium"
    )
    parser.add_argument("--problem", required=True)
    parser.add_argument(
        "--prompt-profile",
        choices=prompt_profile_choices(),
        default=BASELINE_PROFILE,
    )
    parser.add_argument("--render-budget", type=int, default=3)
    parser.add_argument(
        "--workflow",
        choices=(STANDARD_WORKFLOW, *SKETCHBOOK_WORKFLOWS),
        default=STANDARD_WORKFLOW,
        help=(
            "Use the ordinary render loop or require three rendered 3x2 "
            "component studies before final-scene iteration."
        ),
    )
    parser.add_argument(
        "--min-successful-revisions",
        type=int,
        default=2,
        help=(
            "Distinct revisions that must render successfully before the "
            "agent may submit."
        ),
    )
    parser.add_argument("--render-size", type=int, default=1024)
    parser.add_argument("--judge-model", default=None)
    parser.add_argument("--run-id", default=None)
    args = parser.parse_args(argv)
    report = asyncio.run(
        run_agentic_shader(
            model=args.model,
            problem=args.problem,
            prompt_profile=args.prompt_profile,
            render_budget=args.render_budget,
            render_size=args.render_size,
            min_successful_revisions=args.min_successful_revisions,
            workflow=args.workflow,
            judge_model=args.judge_model,
            run_id=args.run_id,
        )
    )
    print(f"Agentic report: {report}")


if __name__ == "__main__":
    main()
