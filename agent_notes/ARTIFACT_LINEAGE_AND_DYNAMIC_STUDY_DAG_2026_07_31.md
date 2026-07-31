# Artifact lineage and a self-growing study DAG

Date: 2026-07-31

This note records the selection/lineage audit of the parrot experiments, the
first exact-artifact workflow, its interrupted-and-resumed run, and the design
direction for a self-growing study graph. It is intentionally detailed so a
future blog post can distinguish observed failures from proposed treatments.

## The measured failure in v5 was not merely weak generation

The hierarchical wide-search v5b run generated better intermediate geometry
than its final image preserved. Two independently inspected atlases contain the
clearest examples:

- Study 1, render 3: the attractive top-middle cell is **B**, but the generator
  recorded **F**.
- Study 2, render 6: the attractive top-middle cell is again **B**, but the
  generator recorded **C**.

In both shaders, cell B uses a subtractive ellipsoid after a warped or blended
body construction. The subtraction creates the reference-specific hooked
negative space and a harder anatomical transition. The recorded winners are
smoother, easier positive-volume constructions. This is a systematic artistic
preference error, not a mislabeled screenshot.

A fresh isolated GPT-5.5-high selector was then shown opaque, deterministically
shuffled contact sheets made from the cached v5 cells. It received the target
image and candidates but no code, pass labels, generator rationale, treatment
name, or implementation convenience. Across all 18 candidates for each topic,
it selected render-3 B for Study 1 and render-6 B for Study 2. That blinded
replay supports the user's visual judgment and localizes a real selection
failure.

The second v5 failure was executable handoff. `record_study` preserved a cell
letter and prose, but not the exact WGSL implementing the cell. Later stages
introduced newly written helpers with names such as `bodyFrame`, `wingShell`,
and `featherField`; those functions did not exist in the selected study shader.
Some equations survived approximately, but the handoff was semantic telephone.
The prose also overstated the code: a "surface-following" feather sheet was a
mostly planar grid, and a "continuous feather" was still a hard extruded slab.

The final-selection rule created a third avoidable regression. v5b's first
successful final scored 313 and its next scored 309, but the old tool could
submit only the current head. More test-time compute is useful only when the
harness can retain earlier champions.

## V8 treatment: selection and lineage become server-owned evidence

Workflow: `sketchbook-artifact-lineage-v8`

Protocol: `persistent-agent-render-tools-v8`

The treatment adds five mechanical properties while keeping the generator in
one isolated persistent session:

1. **Blinded selection.** `rank_study` sends every qualified A-F cell from both
   passes to a fresh isolated visual selector. The opaque order is deterministic
   and the call fails closed if its structured result is invalid.
2. **Executable artifacts.** Each candidate is enclosed in a literal marked
   block with a unique callable entry. The dispatcher must call all six blocks,
   preventing decorative or dead candidate code.
3. **Exact materialization.** `record_study` extracts the selected historical
   block and crop itself, stores source/image/origin files, and hashes the exact
   bytes. The generator cannot substitute a different implementation while
   recording the selection.
4. **Promotion and immutable use.** The selected block must appear byte for
   byte in a full-frame promotion render and remain called from live scene code.
   Later `write_shader` calls reject deletion, mutation, or dead-code retention.
   A server-side injection marker avoids manual retranscription.
5. **Regression-safe history.** `restore_revision` branches from exact saved
   source, and `submit_final(revision=N)` can choose any successful final rather
   than blindly freezing the last rewrite.

The workflow also checkpoints every relevant state transition. Resume rebuilds
the render history, study candidates, selector result, locked artifact source,
promotion status, final candidates, and remaining budget from the run directory.
It resumes in an isolated workspace with only its own artifacts; completed
studies are not regenerated.

Focused unit tests cover exact extraction, six-block validation, dead-code
rejection, selector enforcement, crop/source materialization, lock mutation,
injection, promotion gates, historical final submission, and checkpoint
rehydration. The combined agentic harness suite currently passes 32 tests.

## First V8 parrot run

Run directory:
`parrot_artifact_lineage_v8_sol_medium_20260731`

Configuration:

- generator: `cli/codex:gpt-5.6-sol:medium`
- selector and judge: `cli/codex:gpt-5.5:high`
- prompt profile: `domain-expert-v2`
- render budget: 18
- minimum final candidates: 2

Timeline:

| Call | Event |
| ---: | --- |
| 1 | Study-1 compile failure; budget correctly consumed |
| 2-3 | Study-1 broad/refinement atlases |
| 3 | selector chose B |
| 4 | exact Study-1 B promotion |
| 5-6 | Study-2 atlases |
| 6 | selector chose B |
| 7 | exact Study-2 B promotion |
| 8-9 | Study-3 atlases |
| 8 | selector chose E |
| 10 | exact Study-3 E promotion |
| 11 | first final, 270/500 |
| — | real network/DNS disconnect before a second final |
| 12 | resumed second final, 308/500, then submitted revision 12 |

The resumed state reported 12/18 calls used and six calls remaining. The three
locked sources remained the original selected bytes:

- `study_1_B`, origin revision 3,
  `954d9e558cfe8ba754cfa73b4414b5202142dcdeef8b05474040130f580f1f19`
- `study_2_B`, origin revision 6,
  `fe59cd4337fc25fdce4d76d6c428e6e7930f276d39f533f8644a432e3e3fac13`
- `study_3_E`, origin revision 8,
  `38d67107fcaf4ea92010c4d75e634098176e55ed1184981eba3fcf4252dbcdc5`

Final revision 11 scored `[42, 63, 31, 96, 38]` = 270. Revision 12 scored
`[56, 70, 38, 96, 48]` = 308. The submitted final SHA-256 is
`ac07b5e13ae40609ec7ecb79327df42051424e288b43ef2041c0c69cfd515005`.

## Human visual read: the mechanism worked, the candidates did not

The result is a successful process test and a weak artistic result. Revision 12
improves contrast and palette over revision 11, but remains below the v1 human
favorite and v6b judge winner. Its largest visible defects are:

- an oversized white face oval and a blocky downward beak;
- a dark crest that reads like a mohawk rather than layered plumage;
- smooth body/wing volumes with pasted-on secondary masses;
- repeated capsule/oval columns instead of swept, tapered feathers;
- texture blocks whose regularity is not corrected by surface flow or fBm;
- too little reference-specific photographic anatomy, material response, and
  feather transition detail.

The promotions explain why. Study 1's winner is a more distinctive bent bean
than a generic ellipsoid, but is still an under-resolved macro body. Study 2's
winner is a broad smooth blue appendage; it satisfies parent attachment more
than earlier detached ovals, but does not yet read as a thin shell wrapping a
body. Study 3's candidate set is dominated by capsule columns, so the selector
can only choose the least-bad capsule arrangement. Exact lineage then faithfully
preserves mediocre local winners.

The ordinal selector traces also expose useful discarded hypotheses. Study 1's
runner-up D contains the subtractive beak cavity that selected B lacks. Study 2
runner-up E and winner B have complementary wing silhouettes, but both remain
absolute-coordinate face/wing bundles. Study 3 runner-up B has more coherent
coverage while winner E is slightly less regular; neither consumes the wing
surface or frame. With no score margin and no critical-axis threshold, v8 had
no principled reason to throw all three runner-ups away.

One bookkeeping inconsistency was found during the postmortem: the global
promotion map correctly listed studies 1-3 as promoted and the locked artifacts
had `promoted_locked` status, while the embedded study records still said
`selected_pending_promotion`. This does not affect the byte locks, but it should
be fixed before graph state is layered on top; the DAG needs one authoritative
node lifecycle.

This is the important causal conclusion:

> V8 fixes selection, provenance, and regression control. It cannot create a
> high-quality candidate that the search never generated, and a fixed composite
> study can hide several distinct unresolved questions behind one winner.

The old system could discover good code and lose it. V8 can preserve code, but
its fixed three-step ladder may freeze a local maximum too early.

## Why a self-growing study DAG is the correct next generalization

The proposed method is stronger than another fixed prompt ladder because the
number and topology of hard decisions are unknown before the reference is
studied. It should be implemented as a **DAG of reusable artifacts with a local
search tree inside each study node**, not as one unconstrained tree and not as a
prompt-only plan.

The components have different jobs:

- the graph planner decides **what must be learned**, the dependency interfaces,
  and which nodes can run independently;
- local candidate search proposes alternate implementations for one question;
- the blinded selector ranks the evidence for that node;
- exact artifact locks preserve the winning executable result;
- a promotion/evaluator gate decides **accept, revise, expand, split, or reject**;
- join nodes compose several accepted parents and expose integration residuals;
- regression-safe history retains champions while children are explored.

A pure tree is insufficient because a feather-field node depends on both a
wing-surface artifact and a feather-unit artifact. A DAG permits such joins and
also lets palette/material work run parallel to geometric morphology. A single
mutable `shader.wgsl` is likewise insufficient for true parallel siblings;
each node needs a branch workspace assembled from content-addressed parent
artifacts, with only promoted outputs entering descendants.

### Proposed node contract

Each node should declare machine-readable fields before spending renders:

```json
{
  "id": "feather_distribution",
  "question": "How do selected feather units overlap and flow on the wing?",
  "kind": "study",
  "parents": ["wing_surface", "feather_unit"],
  "input_artifacts": ["wing_surface:*", "feather_unit:*"],
  "output_interface": "feather_field(p, wing_frame) -> material distance",
  "acceptance_rubric": [
    "roots lie on the parent surface",
    "axes derive from a transported T/B/N frame",
    "overlap follows reference flow",
    "boundary units shorten or turn rather than spill"
  ],
  "budget": {"passes": 2, "promotion_renders": 1},
  "status": "ready"
}
```

Node states should be explicit:

`planned → ready → exploring → selected → promoted → accepted`

with side exits to `revise`, `expanded`, `rejected`, and `blocked`. Graph edges
must remain acyclic, reference existing parents, and respect typed artifact
interfaces. A node is ready only when every parent has an accepted promoted
artifact.

### Evidence-gated graph growth

The executor must not be allowed to recursively add vague "make it better"
nodes. Expansion requires:

- visible residual evidence from a promotion or join render;
- the failed acceptance-rubric item;
- a child question that isolates one causal uncertainty;
- declared parent inputs and output interface;
- expected information gain versus render cost;
- a bounded local budget and stop condition.

The evaluator returns a structured decision such as:

```json
{
  "decision": "split",
  "visible_evidence": "The selected coat follows the silhouette but every unit is a capsule and the lower boundary spills beyond the wing.",
  "residuals": [
    {"id": "unit_shape", "severity": 0.9},
    {"id": "boundary_flow", "severity": 0.7}
  ],
  "children": ["feather_morphology", "shell_boundary_distribution"]
}
```

The system should retain a champion and, when evidence is close or strengths
are complementary, one challenger. A single global winner is too lossy: the
best silhouette candidate and the best coordinate-frame candidate can be
different and may deserve an explicit synthesis join.

### Bounded search and parallelism

Recommended initial limits for a parrot-scale experiment:

- global render budget: 24-30, with at least 2 final renders reserved;
- maximum accepted study nodes: 8;
- maximum expansion depth: 3;
- two atlas passes plus one promotion per normal node;
- at most two new children from one evaluation;
- at most two live hypotheses per node;
- stop expansion when residual severity or expected information gain falls
  below a threshold, or when the final-reserve budget would be consumed.

Parallelism should schedule independent ready nodes, not simultaneous writes to
one workspace. For the parrot, wing-surface parameterization and feather-unit
morphology can run concurrently after the macro attachment frame is accepted.
Face material/palette can also run while the wing subtree develops. The sheet
join waits for both wing and feather parents.

### The graph v8 should have grown

An initial parrot graph can be compact:

```text
reference decomposition
├── macro silhouette + negative space
│   ├── head/beak subtraction (only if the promotion remains blob-like)
│   └── torso/head transition (only if needed)
├── wing parent surface P(u,v), T/B/N
├── feather unit morphology
├── face/beak material and color
├── feather distribution [wing surface + feather unit]
├── coat/body transition [macro + distribution]
└── final composition [all accepted parents]
```

V8's Study 3 incorrectly bundled local morphology, surface parameterization,
packing, material, palette, lighting, and transitions. When its pass produced
capsule columns, the correct action was not to select the least-bad composite.
It was to split the residual into at least:

1. a swept varying-width feather-unit study;
2. a wing-shell coordinate and boundary study;
3. a sheet packing/overlap join using both artifacts;
4. a boundary and body-transition integration check.

Likewise, if a strong macro silhouette and a strong parent coordinate frame
occur in different cells, the system should keep both roles and create a
synthesis node instead of making one scalar ranking erase the other.

The exact v8 trace suggests additional automatic growth triggers:

- reject an atlas whose proposed children are nearly all occluded in the
  cumulative view, as happened in Study-2 pass 1;
- reject a dependent artifact that never calls or derives coordinates from its
  declared parent interface, as happened in Studies 2 and 3;
- grow a primitive child when every candidate fails a critical morphology
  criterion, rather than promoting a least-bad oval;
- turn unstudied final-only additions (the gray crest tubes and needle-like face
  stripes) into explicit child nodes instead of letting them bypass the graph;
- allocate remaining budget to low mathematical/fidelity/completeness axes once
  procedural compliance is already high (the final judge's fourth score was 96).

## Discriminating next experiment

The next experiment should be a bounded v9 DAG, not another longer prose
prompt. It should keep every v8 control—blinding, exact hashes, promotion,
historical finals, isolation, and checkpointing—and change only study topology.

Primary measurements:

- Does the graph create children only for visible residuals?
- Are ready independent nodes actually schedulable in isolated workspaces?
- Does every accepted child have exact parent artifact provenance?
- Do join renders preserve each parent rather than reimplementing them?
- How many renders are spent on invalid breadth versus causal uncertainty?
- Does the final reuse the strongest promoted forms, and does human review
  prefer it even when the scalar judge disagrees?

The immediate engineering MVP is graph state plus lifecycle validation and
branch artifact assembly. The first empirical run can use a conservative
planner-generated graph with a maximum of two dynamic expansions; this tests
the mechanism without turning one parrot into an unbounded credit sink.
