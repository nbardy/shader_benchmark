import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from aesthetic_workflows import (
    AESTHETIC_COLOR_MATERIAL_WORKFLOW,
    AESTHETIC_PERCEPTUAL_CRITIC_WORKFLOW,
    AESTHETIC_RELATIONAL_INTEGRATION_WORKFLOW,
    AESTHETIC_SILHOUETTE_RHYTHM_WORKFLOW,
    AESTHETIC_WHOLE_SCENE_TOURNAMENT_WORKFLOW,
    aesthetic_workflow_specs,
)
from agentic_shader_harness import (
    ADAPTIVE_STUDY_DAG_WORKFLOW,
    ARTIFACT_LINEAGE_WORKFLOW,
    BASE_MCP_TOOLS,
    COMPOSITION_FIRST_HIERARCHY_WORKFLOW,
    COMPOSITION_FIRST_SHAPED_DETAIL_WORKFLOW,
    CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW,
    CURVED_ELEMENT_SKETCHBOOK_WORKFLOW,
    HIERARCHICAL_WIDE_SEARCH_WORKFLOW,
    GRAPH_MCP_TOOLS,
    PROTOCOL_V8,
    PROTOCOL_V9,
    PROGRESSIVE_APPLICATION_WORKFLOW,
    RECURSIVE_COMPONENT_LINEAGE_WORKFLOW,
    SKETCHBOOK_WORKFLOW,
    _agentic_isolation_metadata,
    _append_seed_followup_prompt,
    _prepare_seed_followup,
    _render_report,
    _resume_context_images,
    build_agent_prompt,
    build_codex_command,
    workflow_required_studies,
    workflow_requires_variant_inventory,
    workflow_uses_study_dag,
)


def make_submitted_seed_run(
    script_dir: Path,
    *,
    run_id: str = "submitted_seed",
    problem: str = "reproduce_image_andrew_pons",
) -> tuple[Path, Path]:
    source = script_dir / "benchmark_run_output" / run_id
    renders = source / "renders"
    renders.mkdir(parents=True)
    shader = "fn seeded_scene() -> f32 { return 1.0; }\n"
    shader_hash = hashlib.sha256(shader.encode("utf-8")).hexdigest()
    historical_shader = "fn historical_scene() -> f32 { return 0.8; }\n"
    historical_hash = hashlib.sha256(
        historical_shader.encode("utf-8")
    ).hexdigest()
    final_shader = source / "final_shader.wgsl"
    revision_shader = renders / "revision_03.wgsl"
    final_shader.write_text(shader, encoding="utf-8")
    revision_shader.write_text(shader, encoding="utf-8")
    (renders / "revision_02.wgsl").write_text(
        historical_shader, encoding="utf-8"
    )
    render_bytes = b"stable-seed-render"
    historical_render_bytes = b"historical-seed-render"
    final_render = source / "final_render.png"
    event_render = renders / "render_02.png"
    historical_render = renders / "render_01.png"
    final_render.write_bytes(render_bytes)
    event_render.write_bytes(render_bytes)
    historical_render.write_bytes(historical_render_bytes)
    submission = {
        "revision": 3,
        "render_call": 2,
        "sha256": shader_hash,
        "summary": "The submitted image preserved the strongest public form.",
    }
    state = {
        "submitted": True,
        "render_calls": 2,
        "events": [
            {
                "type": "render_shader",
                "ok": True,
                "stage": "final",
                "revision": 2,
                "render_call": 1,
                "sha256": historical_hash,
                "image": str(historical_render.absolute()),
            },
            {
                "type": "write_shader",
                "revision": 3,
                "revision_critique": (
                    "The body is too generic; preserve the focal eye while "
                    "improving the silhouette."
                ),
            },
            {
                "type": "render_shader",
                "ok": True,
                "stage": "final",
                "revision": 3,
                "render_call": 2,
                "sha256": shader_hash,
                "image": str(event_render.absolute()),
            },
        ],
        "study_records": {
            "1": {
                "study_index": 1,
                "node_id": "macro",
                "subject": "Macro silhouette",
                "selected_variant": "B",
                "variant_inventory": "A: oval; B: curved body",
                "selection_rationale": "B has the clearest visible gesture.",
                "handoff_requirements": "Preserve the curved silhouette.",
            }
        },
        "study_dag": {
            "graph_closed": True,
            "final_node_id": "macro",
            "nodes": [],
        },
        "node_evaluations": {},
    }
    result = {
        "submitted": True,
        "model": "cli/codex:gpt-5.6-sol:medium",
        "problem": problem,
        "prompt_profile": "domain-expert-v2",
        "workflow": "sketchbook-adaptive-study-dag-v9",
        "protocol": "persistent-agent-render-tools-v9",
        "render_budget": 24,
        "judge": {"total": 499, "secret_judge_sentinel": True},
        "render_judges": [{"secret_response": "never expose this"}],
    }
    (source / "submission.json").write_text(
        json.dumps(submission), encoding="utf-8"
    )
    (source / "agent_state.json").write_text(
        json.dumps(state), encoding="utf-8"
    )
    (source / "result.json").write_text(json.dumps(result), encoding="utf-8")
    brief = script_dir / "followup.txt"
    brief.write_text(
        "Replace the generic oval macro anatomy with a dynamic swept form.",
        encoding="utf-8",
    )
    return source, brief


class AgenticShaderHarnessTests(unittest.TestCase):
    def test_prompt_makes_submission_and_budget_explicit(self):
        prompt = build_agent_prompt("Draw the target.", "baseline", 3)
        self.assertIn("one persistent session", prompt)
        self.assertIn("hard render-call budget is\n   3", prompt)
        self.assertIn("submit_final", prompt)

    def test_sketchbook_prompt_requires_three_rendered_atlases_and_handoff(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            8,
            min_successful_revisions=2,
            workflow=SKETCHBOOK_WORKFLOW,
        )
        self.assertIn("MANDATORY 3×2 VISUAL SKETCHBOOK", prompt)
        self.assertIn("3 high-risk, subject-specific", prompt)
        self.assertIn('stage="study"', prompt)
        self.assertIn("variants A, B, C, D, E, F", prompt)
        self.assertIn("parent-surface coordinate frame", prompt)
        self.assertIn("fBm/domain warp", prompt)
        self.assertIn("record_study", prompt)
        self.assertIn("materially reuse", prompt)

    def test_curved_element_workflow_separates_shape_from_surface_placement(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            8,
            min_successful_revisions=2,
            workflow=CURVED_ELEMENT_SKETCHBOOK_WORKFLOW,
        )
        self.assertIn("CURVED-ELEMENT AND SURFACE-WRAPPING GATE", prompt)
        self.assertIn("Study 2 — isolated element-shape laboratory", prompt)
        self.assertIn("Study 3 — parent-surface attachment", prompt)
        self.assertIn("curved centerline", prompt)
        self.assertIn("width w(s)", prompt)
        self.assertIn("surface point P(u,v)", prompt)
        self.assertIn("fBm/domain warp to (u,v)", prompt)
        self.assertIn("variant_inventory", prompt)

    def test_continuous_element_workflow_bans_segment_union_blobs(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            8,
            min_successful_revisions=2,
            workflow=CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW,
        )
        self.assertIn("CONTINUOUS IMPLICIT ELEMENT GATE", prompt)
        self.assertIn("Do not build one organic element by looping", prompt)
        self.assertIn("centerX = bend*s*s", prompt)
        self.assertIn("width = max(epsilon", prompt)
        self.assertIn("crossSection", prompt)
        self.assertIn("conservative\nray-march steps", prompt)
        self.assertIn("No lower-fidelity ellipsoid/capsule replacement", prompt)
        self.assertTrue(
            workflow_requires_variant_inventory(
                CONTINUOUS_ELEMENT_SKETCHBOOK_WORKFLOW
            )
        )

    def test_progressive_workflow_requires_refinement_and_application_ladder(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            10,
            min_successful_revisions=2,
            workflow=PROGRESSIVE_APPLICATION_WORKFLOW,
        )
        self.assertIn("PROGRESSIVE STUDY-APPLICATION LADDER", prompt)
        self.assertIn("TWO distinct, visually diverse successful renders", prompt)
        self.assertIn("Pass 1 — DIVERGE", prompt)
        self.assertIn("Pass 2 — REFINE", prompt)
        self.assertIn("variation_manifest", prompt)
        self.assertIn("study_pass_qualified", prompt)
        self.assertIn("PRIMITIVE STUDY", prompt)
        self.assertIn("ASSEMBLY / SHEET STUDY", prompt)
        self.assertIn("PARENT-INTEGRATION / COAT STUDY", prompt)
        self.assertIn("fundamental unit → composed", prompt)
        self.assertEqual(
            workflow_required_studies(PROGRESSIVE_APPLICATION_WORKFLOW), 4
        )

    def test_hierarchical_workflow_forces_wide_search_and_relative_geometry(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            20,
            min_successful_revisions=2,
            workflow=HIERARCHICAL_WIDE_SEARCH_WORKFLOW,
        )
        self.assertIn("HIERARCHICAL GEOMETRY + WIDE REPRESENTATION SEARCH", prompt)
        self.assertIn("18 candidate constructions total", prompt)
        self.assertIn("STRUCTURAL SURVEY A", prompt)
        self.assertIn("STRUCTURAL SURVEY B", prompt)
        self.assertIn("SYNTHESIS", prompt)
        self.assertIn("not a list of\nindependent world-space shapes", prompt)
        self.assertIn("parentFrame(parentCoordinate)", prompt)
        self.assertIn("ATTACHED FORM / APPENDAGE STUDY", prompt)
        self.assertIn("OVERLAPPING SHEET / FIELD STUDY", prompt)
        self.assertIn("Adjacent decorations with open gaps are not a sheet", prompt)
        self.assertIn("approximately the selected sheet coverage/overlap", prompt)
        self.assertEqual(
            workflow_required_studies(HIERARCHICAL_WIDE_SEARCH_WORKFLOW), 6
        )
        self.assertTrue(
            workflow_requires_variant_inventory(
                HIERARCHICAL_WIDE_SEARCH_WORKFLOW
            )
        )

    def test_composition_first_workflow_preserves_quality_in_final_context(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            10,
            min_successful_revisions=2,
            workflow=COMPOSITION_FIRST_HIERARCHY_WORKFLOW,
        )
        self.assertIn("COMPOSITION-FIRST, QUALITY-PRESERVING HIERARCHY", prompt)
        self.assertIn("THREE FINAL-CONTEXT STUDIES", prompt)
        self.assertIn("strongest visible feature that must survive", prompt)
        self.assertIn("COMPOSITION + ROOTED MACRO FORM", prompt)
        self.assertIn("ATTACHED DETAIL COAT", prompt)
        self.assertIn("ART DIRECTION + MATERIAL IN CONTEXT", prompt)
        self.assertIn("many modest elements", prompt)
        self.assertIn("root = parentPoint(s, u, v)", prompt)
        self.assertIn("Complexity\nis not a tiebreaker", prompt)
        self.assertEqual(
            workflow_required_studies(COMPOSITION_FIRST_HIERARCHY_WORKFLOW),
            3,
        )
        self.assertFalse(
            workflow_requires_variant_inventory(
                COMPOSITION_FIRST_HIERARCHY_WORKFLOW
            )
        )

    def test_shaped_detail_workflow_rejects_finger_primitives(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            10,
            min_successful_revisions=2,
            workflow=COMPOSITION_FIRST_SHAPED_DETAIL_WORKFLOW,
        )
        self.assertIn("COMPOSITION-FIRST, QUALITY-PRESERVING HIERARCHY", prompt)
        self.assertIn("VISIBLE ELEMENT-MORPHOLOGY GATE", prompt)
        self.assertIn("capsule, finger, peg, pill, wire, comb tooth", prompt)
        self.assertIn("continuous longitudinal coordinate s", prompt)
        self.assertIn("off-center shoulder", prompt)
        self.assertIn("25–45% of length", prompt)
        self.assertIn("cannot be the complete visible unit", prompt)
        self.assertIn("avoid straight vertical rails", prompt)
        self.assertIn("tapered varying-width silhouettes", prompt)
        self.assertEqual(
            workflow_required_studies(
                COMPOSITION_FIRST_SHAPED_DETAIL_WORKFLOW
            ),
            3,
        )

    def test_artifact_lineage_workflow_selects_promotes_and_locks_code(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            14,
            min_successful_revisions=2,
            workflow=ARTIFACT_LINEAGE_WORKFLOW,
        )
        self.assertIn(
            "BLINDED SELECTION + EXECUTABLE ARTIFACT LINEAGE V8",
            prompt,
        )
        self.assertIn("SIGNATURE MACRO FORM", prompt)
        self.assertIn("PARENT-ATTACHED SECONDARY SYSTEM", prompt)
        self.assertIn("SURFACE TREATMENT + ART DIRECTION", prompt)
        self.assertIn("render TWO qualified 3×2 passes", prompt)
        self.assertIn("@shaderbench-artifact-begin", prompt)
        self.assertIn("rank_study(study_index=N)", prompt)
        self.assertIn('stage="promotion"', prompt)
        self.assertIn("byte-for-byte", prompt)
        self.assertIn("@shaderbench-inject", prompt)
        self.assertIn("submit_final(summary, revision=N)", prompt)
        self.assertEqual(
            workflow_required_studies(ARTIFACT_LINEAGE_WORKFLOW),
            3,
        )
        self.assertTrue(
            workflow_requires_variant_inventory(ARTIFACT_LINEAGE_WORKFLOW)
        )

    def test_adaptive_dag_workflow_exposes_bounded_public_graph_contract(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            24,
            min_successful_revisions=2,
            workflow=ADAPTIVE_STUDY_DAG_WORKFLOW,
        )
        self.assertIn("SELF-GROWING STUDY DAG + EXACT ARTIFACTS V9", prompt)
        self.assertIn("define_study_graph(graph_json, rationale)", prompt)
        self.assertIn("begin_study_node(node_id)", prompt)
        self.assertIn("evaluate_study_node", prompt)
        self.assertIn("expand_study_graph", prompt)
        self.assertIn("close_study_graph", prompt)
        self.assertIn("parallel-ready", prompt)
        self.assertIn("cumulative/augmenting", prompt)
        self.assertEqual(workflow_required_studies(ADAPTIVE_STUDY_DAG_WORKFLOW), 0)
        self.assertTrue(workflow_uses_study_dag(ADAPTIVE_STUDY_DAG_WORKFLOW))

    def test_recursive_component_workflow_is_subject_neutral_and_extent_aware(self):
        prompt = build_agent_prompt(
            "Draw the target.",
            "baseline",
            18,
            min_successful_revisions=2,
            workflow=RECURSIVE_COMPONENT_LINEAGE_WORKFLOW,
        )
        self.assertIn("RECURSIVE COMPONENT LINEAGE V11", prompt)
        self.assertIn("fixed linear ablation, not the adaptive study DAG", prompt)
        self.assertIn("ROOT SYSTEM + AUTHORITATIVE PARENT MAP", prompt)
        self.assertIn("CHILD UNIT + ITS INTERNAL SUBCOMPONENTS", prompt)
        self.assertIn("EXTENT-AWARE PARENT TRANSPORT", prompt)
        self.assertIn("gamma(s) = { u(s), v(s), h(s) }", prompt)
        self.assertIn("parallel-transport the frame", prompt)
        self.assertIn("extent_map=", prompt)
        self.assertIn("parent_stress=", prompt)
        self.assertIn("coordinate_map=", prompt)
        self.assertIn("exact selected shader\nartifact", prompt)
        self.assertEqual(
            workflow_required_studies(RECURSIVE_COMPONENT_LINEAGE_WORKFLOW),
            4,
        )
        self.assertTrue(
            workflow_requires_variant_inventory(
                RECURSIVE_COMPONENT_LINEAGE_WORKFLOW
            )
        )
        self.assertFalse(
            workflow_uses_study_dag(RECURSIVE_COMPONENT_LINEAGE_WORKFLOW)
        )
        workflow_only = prompt[prompt.index("RECURSIVE COMPONENT LINEAGE V11") :]
        for parrot_term in ("macaw", "torso", "bill", "cheek"):
            self.assertNotIn(parrot_term, workflow_only.lower())

    def test_five_aesthetic_workflows_are_distinct_public_decision_processes(self):
        expected = {
            AESTHETIC_PERCEPTUAL_CRITIC_WORKFLOW: (
                5,
                "INDEPENDENT CRITIC + CHAMPION LOOP",
            ),
            AESTHETIC_WHOLE_SCENE_TOURNAMENT_WORKFLOW: (
                1,
                "WHOLE-SCENE AESTHETIC TOURNAMENT",
            ),
            AESTHETIC_SILHOUETTE_RHYTHM_WORKFLOW: (
                2,
                "SILHOUETTE, NEGATIVE SPACE, AND RHYTHM",
            ),
            AESTHETIC_COLOR_MATERIAL_WORKFLOW: (
                2,
                "COLOR SCRIPT, MATERIAL, AND CINEMATOGRAPHY",
            ),
            AESTHETIC_RELATIONAL_INTEGRATION_WORKFLOW: (
                3,
                "RELATIONAL INTEGRATION TOURNAMENT",
            ),
        }
        self.assertEqual(len(aesthetic_workflow_specs()), 5)
        for workflow, (study_count, signature) in expected.items():
            with self.subTest(workflow=workflow):
                prompt = build_agent_prompt(
                    "Draw the target.",
                    "baseline",
                    18,
                    min_successful_revisions=6,
                    workflow=workflow,
                )
                self.assertIn("BEAUTY IS A FIRST-CLASS ACCEPTANCE CRITERION", prompt)
                self.assertIn("THREE-SECOND READ", prompt)
                self.assertIn("GESTALT:", prompt)
                self.assertIn("BEAUTIFUL:", prompt)
                self.assertIn("UNCANNY:", prompt)
                self.assertIn("INTERVENTION:", prompt)
                self.assertIn("TEST:", prompt)
                self.assertIn(signature, prompt)
                self.assertEqual(
                    workflow_required_studies(workflow),
                    study_count,
                )
                self.assertTrue(workflow_requires_variant_inventory(workflow))
                self.assertFalse(workflow_uses_study_dag(workflow))

    def test_seed_followup_validates_assets_and_excludes_judges(self):
        with tempfile.TemporaryDirectory() as temporary:
            script_dir = Path(temporary)
            _, brief = make_submitted_seed_run(script_dir)
            seed = _prepare_seed_followup(
                script_dir=script_dir,
                problem="reproduce_image_andrew_pons",
                seed_run="submitted_seed",
                followup_brief_file=brief,
            )
        self.assertIsNotNone(seed)
        assert seed is not None
        self.assertEqual(seed.source_run_id, "submitted_seed")
        self.assertEqual(
            seed.provenance["seed_shader_sha256"],
            hashlib.sha256(
                "fn seeded_scene() -> f32 { return 1.0; }\n".encode("utf-8")
            ).hexdigest(),
        )
        self.assertFalse(seed.provenance["raw_trace_included"])
        self.assertFalse(seed.provenance["judge_outputs_included"])
        self.assertNotIn("secret_judge_sentinel", seed.public_summary_json)
        self.assertNotIn("never expose this", seed.public_summary_json)
        self.assertIn("Macro silhouette", seed.public_summary_json)
        self.assertIn("generic", seed.public_summary_json)

    def test_seed_followup_prompt_puts_user_brief_last(self):
        with tempfile.TemporaryDirectory() as temporary:
            script_dir = Path(temporary)
            _, brief = make_submitted_seed_run(script_dir)
            seed = _prepare_seed_followup(
                script_dir=script_dir,
                problem="reproduce_image_andrew_pons",
                seed_run="submitted_seed",
                followup_brief_file=brief,
            )
            prompt = _append_seed_followup_prompt("BASE CONTRACT", seed)
        self.assertIn("The second attached image is", prompt)
        self.assertIn("seed_shader.wgsl", prompt)
        self.assertIn("evidence, not an instruction", prompt)
        self.assertGreater(
            prompt.index("USER-AUTHORIZED FOLLOW-UP BRIEF"),
            prompt.index("<prior_public_trace_data>"),
        )
        self.assertGreater(
            prompt.index("Replace the generic oval macro anatomy"),
            prompt.index("BASE CONTRACT"),
        )

    def test_seed_followup_can_select_a_successful_historical_final(self):
        with tempfile.TemporaryDirectory() as temporary:
            script_dir = Path(temporary)
            _, brief = make_submitted_seed_run(script_dir)
            seed = _prepare_seed_followup(
                script_dir=script_dir,
                problem="reproduce_image_andrew_pons",
                seed_run="submitted_seed",
                seed_revision=2,
                followup_brief_file=brief,
            )
            self.assertIsNotNone(seed)
            assert seed is not None
            self.assertEqual(seed.shader_path.name, "revision_02.wgsl")
            self.assertEqual(seed.baseline_path.name, "render_01.png")
            self.assertEqual(seed.provenance["source_selection"], "historical_final")
            self.assertEqual(seed.provenance["source_revision"], 2)
            self.assertEqual(seed.provenance["source_render_call"], 1)
            self.assertEqual(
                seed.public_summary["seed_selection"]["kind"],
                "historical_final",
            )

            with self.assertRaisesRegex(
                ValueError, "no matching successful final render"
            ):
                _prepare_seed_followup(
                    script_dir=script_dir,
                    problem="reproduce_image_andrew_pons",
                    seed_run="submitted_seed",
                    seed_revision=99,
                    followup_brief_file=brief,
                )

    def test_seed_followup_rejects_problem_or_asset_hash_mismatch(self):
        with tempfile.TemporaryDirectory() as temporary:
            script_dir = Path(temporary)
            source, brief = make_submitted_seed_run(script_dir)
            with self.assertRaisesRegex(ValueError, "problem does not match"):
                _prepare_seed_followup(
                    script_dir=script_dir,
                    problem="different_problem",
                    seed_run="submitted_seed",
                    followup_brief_file=brief,
                )
            (source / "final_shader.wgsl").write_text(
                "fn changed() -> f32 { return 0.0; }\n", encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "shader hash disagrees"):
                _prepare_seed_followup(
                    script_dir=script_dir,
                    problem="reproduce_image_andrew_pons",
                    seed_run="submitted_seed",
                    followup_brief_file=brief,
                )
            shader = "fn seeded_scene() -> f32 { return 1.0; }\n"
            (source / "final_shader.wgsl").write_text(shader, encoding="utf-8")
            (source / "final_render.png").write_bytes(b"changed-render")
            with self.assertRaisesRegex(ValueError, "render hash disagrees"):
                _prepare_seed_followup(
                    script_dir=script_dir,
                    problem="reproduce_image_andrew_pons",
                    seed_run="submitted_seed",
                    followup_brief_file=brief,
                )

    def test_seed_baseline_is_visible_in_report(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            output = root / "output"
            problem = root / "problem"
            output.mkdir()
            problem.mkdir()
            (problem / "reference.png").write_bytes(b"reference")
            (output / "seed_baseline.png").write_bytes(b"baseline")
            report = _render_report(
                output,
                problem,
                {
                    "model": "cli/codex:gpt-5.6-sol:medium",
                    "prompt_profile": "domain-expert-v2",
                    "workflow": "standard",
                    "render_budget": 10,
                    "protocol": PROTOCOL_V8,
                    "state": {"render_calls": 0, "events": []},
                    "seed_followup": {
                        "source_run_id": "submitted_seed",
                        "seed_baseline_file": "seed_baseline.png",
                        "seed_shader_sha256": "a" * 64,
                        "seed_baseline_sha256": "b" * 64,
                    },
                },
            )
            html_text = report.read_text(encoding="utf-8")
        self.assertIn("Seed baseline", html_text)
        self.assertIn("submitted_seed", html_text)
        self.assertIn("seed_baseline.png", html_text)

    def test_resume_command_preserves_seed_and_checkpoint_image_identity(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renders = root / "renders"
            renders.mkdir()
            reference = root / "reference.png"
            seed_baseline = root / "seed_baseline.png"
            checkpoint = renders / "render_07.png"
            for path in (reference, seed_baseline, checkpoint):
                path.write_bytes(path.name.encode("utf-8"))
            latest = {"render_call": 7}
            seeded_context = _resume_context_images(
                root,
                {
                    "seed_followup": {
                        "seed_baseline_file": "seed_baseline.png"
                    }
                },
                latest,
            )
            self.assertEqual(seeded_context, (seed_baseline, checkpoint))
            self.assertEqual(
                _resume_context_images(root, {}, latest),
                (checkpoint,),
            )
            command = build_codex_command(
                model_spec="cli/codex:gpt-5.6-sol:medium",
                workspace=root,
                reference_image=reference,
                server_script=root / "server.py",
                renderer=root / "renderer",
                render_budget=8,
                render_size=512,
                min_successful_revisions=2,
                required_studies=3,
                require_variant_inventory=True,
                min_successful_study_renders=2,
                require_study_diversity=True,
                require_artifact_blocks=True,
                require_study_selector=True,
                require_study_promotions=True,
                require_recursive_component_contract=False,
                selector_model="gpt-5.5",
                selector_effort="high",
                protocol=PROTOCOL_V8,
                graph_enabled=False,
                min_graph_nodes=3,
                max_graph_nodes=8,
                max_graph_depth=3,
                final_render_reserve=2,
                resume_existing=True,
                context_images=seeded_context,
                trace_path=root / "trace.jsonl",
                last_message_path=root / "last.txt",
            )
        attached = [
            command[index + 1]
            for index, value in enumerate(command)
            if value == "--image"
        ]
        self.assertEqual(
            attached,
            [str(reference), str(seed_baseline), str(checkpoint)],
        )

    def test_agentic_isolation_metadata_states_practical_read_boundary(self):
        metadata = _agentic_isolation_metadata(PROTOCOL_V8, False)
        self.assertEqual(
            metadata["isolation_scope"],
            "best-effort practical process isolation",
        )
        self.assertTrue(metadata["mcp_tool_allowlist_enforced"])
        self.assertFalse(metadata["mcp_tools_accept_arbitrary_paths"])
        self.assertFalse(metadata["filesystem_read_allowlist_enforced"])
        self.assertTrue(metadata["absolute_path_reads_may_be_possible"])
        self.assertFalse(
            metadata["repository_or_other_runs_guaranteed_unreadable"]
        )
        self.assertIn(
            "not a filesystem read allowlist",
            metadata["codex_sandbox"],
        )
        self.assertNotIn("provided_inputs_only", metadata)
        self.assertNotIn("repository_context_loaded", metadata)

    def test_codex_command_uses_practical_isolation_and_tool_allowlist(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command = build_codex_command(
                model_spec="cli/codex:gpt-5.6-sol:medium",
                workspace=root,
                reference_image=root / "reference.png",
                server_script=root / "server.py",
                renderer=root / "renderer",
                render_budget=3,
                render_size=512,
                min_successful_revisions=2,
                required_studies=3,
                require_variant_inventory=True,
                min_successful_study_renders=2,
                require_study_diversity=True,
                require_artifact_blocks=True,
                require_study_selector=True,
                require_study_promotions=True,
                require_recursive_component_contract=True,
                selector_model="gpt-5.5",
                selector_effort="high",
                protocol=PROTOCOL_V8,
                graph_enabled=False,
                min_graph_nodes=3,
                max_graph_nodes=8,
                max_graph_depth=3,
                final_render_reserve=2,
                resume_existing=False,
                context_images=(),
                trace_path=root / "trace.jsonl",
                last_message_path=root / "last.txt",
            )
        self.assertIn("--ignore-user-config", command)
        self.assertIn("--ignore-rules", command)
        self.assertIn("read-only", command)
        joined = "\n".join(command)
        self.assertIn("mcp_servers.shader_tools.enabled_tools", joined)
        for tool_name in BASE_MCP_TOOLS:
            self.assertIn(tool_name, joined)
        for tool_name in GRAPH_MCP_TOOLS:
            self.assertNotIn(f'"{tool_name}"', joined)
        self.assertIn("SHADER_AGENT_RENDER_BUDGET", joined)
        self.assertIn("SHADER_AGENT_REQUIRED_STUDIES", joined)
        self.assertIn("SHADER_AGENT_REQUIRE_VARIANT_INVENTORY", joined)
        self.assertIn("SHADER_AGENT_MIN_SUCCESSFUL_STUDY_RENDERS", joined)
        self.assertIn("SHADER_AGENT_REQUIRE_STUDY_DIVERSITY", joined)
        self.assertIn("SHADER_AGENT_REQUIRE_ARTIFACT_BLOCKS", joined)
        self.assertIn("SHADER_AGENT_REQUIRE_STUDY_SELECTOR", joined)
        self.assertIn("SHADER_AGENT_REQUIRE_STUDY_PROMOTIONS", joined)
        self.assertIn(
            "SHADER_AGENT_REQUIRE_RECURSIVE_COMPONENT_CONTRACT", joined
        )
        self.assertIn("SHADER_AGENT_REFERENCE_IMAGE", joined)

    def test_codex_command_enables_graph_tools_and_v9_environment(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            command = build_codex_command(
                model_spec="cli/codex:gpt-5.6-sol:medium",
                workspace=root,
                reference_image=root / "reference.png",
                server_script=root / "server.py",
                renderer=root / "renderer",
                render_budget=24,
                render_size=512,
                min_successful_revisions=2,
                required_studies=0,
                require_variant_inventory=True,
                min_successful_study_renders=1,
                require_study_diversity=True,
                require_artifact_blocks=True,
                require_study_selector=True,
                require_study_promotions=True,
                require_recursive_component_contract=False,
                selector_model="gpt-5.5",
                selector_effort="high",
                protocol=PROTOCOL_V9,
                graph_enabled=True,
                min_graph_nodes=3,
                max_graph_nodes=8,
                max_graph_depth=3,
                final_render_reserve=2,
                resume_existing=False,
                context_images=(),
                trace_path=root / "trace.jsonl",
                last_message_path=root / "last.txt",
            )
        joined = "\n".join(command)
        for tool_name in (*BASE_MCP_TOOLS, *GRAPH_MCP_TOOLS):
            self.assertIn(tool_name, joined)
        self.assertIn(PROTOCOL_V9, joined)
        self.assertIn("SHADER_AGENT_GRAPH_ENABLED", joined)
        self.assertIn("SHADER_AGENT_MIN_GRAPH_NODES", joined)
        self.assertIn("SHADER_AGENT_MAX_GRAPH_NODES", joined)
        self.assertIn("SHADER_AGENT_MAX_GRAPH_DEPTH", joined)
        self.assertIn("SHADER_AGENT_FINAL_RENDER_RESERVE", joined)


if __name__ == "__main__":
    unittest.main()
