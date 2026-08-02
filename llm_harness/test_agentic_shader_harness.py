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
    SKETCHBOOK_WORKFLOW,
    build_agent_prompt,
    build_codex_command,
    workflow_required_studies,
    workflow_requires_variant_inventory,
    workflow_uses_study_dag,
)


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

    def test_codex_command_is_isolated_and_tool_allowlisted(self):
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
