"""Focused integration tests for the adaptive v9 study-DAG state."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from shader_agent_mcp import ShaderAgentState
from study_dag import AdaptiveStudyDAG, StudyDAGError


PROTOCOL_V9 = "persistent-agent-render-tools-v9"
GRAPH_RATIONALE = (
    "The reconstruction has independent macro-form and material risks that can "
    "be studied in parallel, while their final integration must wait for both "
    "parents. The graph makes those boundaries, joins, and visible failure "
    "conditions explicit before any shader implementation begins."
)
VISIBLE_EVIDENCE = (
    "The promoted full-frame result preserves the declared parent construction "
    "and makes the tested silhouette visible at reference scale; the remaining "
    "mismatch is localized enough to justify the recorded decision rather than "
    "being inferred from shader code alone."
)
SELECTION_RATIONALE = (
    "Variant B has the strongest reference-specific hooked silhouette, coherent "
    "negative space, and continuous three-dimensional bend; the other variants "
    "either flatten the gesture or replace it with a generic oval construction."
)
HANDOFF_REQUIREMENTS = (
    "Preserve the exact selected artifact function, its local coordinate frame, "
    "subtractive bend, and taper parameters, then call it from the live scene "
    "before attaching any dependent surface or material construction."
)
INTEGRATION_EVIDENCE = (
    "The full-frame promotion calls the exact selected artifact from the live "
    "scene path, visibly preserves its hooked silhouette and negative space, "
    "and leaves the declared child attachment boundary available for later work."
)
REVISION_CRITIQUE = (
    "Preserve all exact selected geometry while changing the surrounding scene "
    "only where the latest rendered image visibly differs from the reference."
)
CLOSURE_EVIDENCE = (
    "Every promoted node now has an explicit accept decision grounded in its "
    "full-frame render. The unique integration sink includes both independent "
    "parents, preserves their visible achievements, and leaves no disconnected "
    "or unresolved study branch before final reconstruction renders begin."
)


def node(
    node_id: str,
    *,
    mode: str = "refine",
    depends_on: tuple[str, ...] = (),
    title: str | None = None,
) -> dict[str, object]:
    """Build one strict model-authored study-node payload."""
    return {
        "node_id": node_id,
        "title": title or node_id.replace("_", " ").title(),
        "decision_question": (
            f"Which construction best resolves the visible {node_id} decision?"
        ),
        "depends_on": list(depends_on),
        "success_criteria": [
            f"{node_id} preserves the target silhouette and parent relationship",
            f"{node_id} remains visibly specific rather than generically regular",
        ],
        "failure_signals": [
            f"{node_id} collapses into a glued-on oval or disconnected texture",
        ],
        "mode": mode,
    }


def standard_graph() -> list[dict[str, object]]:
    """Return two parallel roots feeding a unique integration sink."""
    return [
        node("macro_form", mode="diverge", title="Signature macro form"),
        node("material_language", title="Material language"),
        node(
            "scene_join",
            mode="integrate",
            depends_on=("macro_form", "material_language"),
            title="Integrated scene join",
        ),
    ]


def artifact_block(study_index: int, label: str) -> str:
    lower = label.lower()
    offset = "ABCDEF".index(label) + 1
    return (
        f"// @shaderbench-artifact-begin id=study_{study_index}_{label} "
        f"entry=artifact_s{study_index}_{lower}\n"
        f"fn artifact_s{study_index}_{lower}(p: vec3<f32>) -> f32 {{\n"
        f"    return length(p + vec3<f32>({offset}.0, 0.0, 0.0)) - 0.5;\n"
        "}\n"
        f"// @shaderbench-artifact-end id=study_{study_index}_{label}\n"
    )


def study_shader(study_index: int, *, suffix: str = "") -> str:
    blocks = [artifact_block(study_index, label) for label in "ABCDEF"]
    calls = [
        f"    distance = min(distance, artifact_s{study_index}_{label.lower()}(p));"
        for label in "ABCDEF"
    ]
    return (
        "\n\n".join(blocks)
        + "\n\n"
        + f"""
fn scene_sdf(p: vec3<f32>) -> f32 {{
    var distance = 1000.0;
{chr(10).join(calls)}
    return distance;
}}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32)
    -> @builtin(position) vec4<f32> {{
    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>)
    -> @location(0) vec4<f32> {{
    let distance = scene_sdf(vec3<f32>(pos.xy, 0.0));
    return vec4<f32>(distance, distance, distance, 1.0);
}}
// {suffix}
"""
    )


def promoted_shader(selected_block: str) -> str:
    """Build a full-frame shader whose live path calls the exact locked block."""
    return (
        selected_block
        + "\n\n"
        + """
fn scene_sdf(p: vec3<f32>) -> f32 {
    return artifact_s1_b(p);
}

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32)
    -> @builtin(position) vec4<f32> {
    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>)
    -> @location(0) vec4<f32> {
    let distance = scene_sdf(vec3<f32>(pos.xy, 0.0));
    return vec4<f32>(distance, distance, distance, 1.0);
}
"""
    )


VALID_SHADER = """
@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32)
    -> @builtin(position) vec4<f32> {
    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>)
    -> @location(0) vec4<f32> {
    return vec4<f32>(0.2, 0.4, 0.8, 1.0);
}
"""


def fake_renderer(command: list[str], **_: object) -> object:
    """Write a deterministic six-cell image for both study and final renders."""
    output = Path(command[command.index("--output") + 1])
    atlas = Image.new("RGB", (300, 200), (12, 18, 24))
    colors = (
        (200, 20, 20),
        (20, 200, 30),
        (20, 30, 200),
        (210, 180, 20),
        (20, 180, 190),
        (180, 20, 190),
    )
    for index, color in enumerate(colors):
        left = index % 3 * 100
        top = index // 3 * 100
        atlas.paste(color, (left, top, left + 100, top + 100))
    atlas.save(output)
    return type(
        "Completed",
        (),
        {"returncode": 0, "stdout": "ok", "stderr": ""},
    )()


class ShaderAgentDAGIntegrationTests(unittest.TestCase):
    def make_state(
        self,
        root: Path,
        *,
        workspace_name: str = "workspace",
        resume_existing: bool = False,
        require_artifacts: bool = False,
    ) -> ShaderAgentState:
        renderer = root / "renderer"
        renderer.write_text("fake", encoding="utf-8")
        return ShaderAgentState(
            root / workspace_name,
            renderer,
            render_budget=18,
            protocol=PROTOCOL_V9,
            graph_enabled=True,
            min_graph_nodes=3,
            max_graph_nodes=8,
            max_graph_depth=3,
            final_render_reserve=2,
            render_size=64,
            min_successful_revisions=1,
            required_studies=0,
            require_artifact_blocks=require_artifacts,
            require_study_promotions=require_artifacts,
            resume_existing=resume_existing,
        )

    def define_standard_graph(self, state: ShaderAgentState) -> dict[str, object]:
        result = state.define_study_graph(
            json.dumps(standard_graph()), GRAPH_RATIONALE
        )
        self.assertTrue(result["ok"], result)
        return result

    @staticmethod
    def advance_without_renderer(state: ShaderAgentState, node_id: str) -> None:
        """Advance core lifecycle while keeping both authoritative ledgers equal."""
        begun = state.begin_study_node(node_id)
        if not begun["ok"]:
            raise AssertionError(begun)
        graph = state.study_dag
        assert graph is not None
        snapshot = graph.snapshot(node_id)
        for _ in range(snapshot.required_passes):
            state.render_calls += 1
            graph.record_pass(
                node_id,
                success=True,
                render_calls_used=state.render_calls,
            )
            state.events.append(
                {
                    "type": "render_shader",
                    "ok": False,
                    "revision": 0,
                    "render_call": state.render_calls,
                    "stage": "study",
                }
            )
        state.successful_study_render_count[snapshot.study_index] = (
            snapshot.required_passes
        )
        graph.select_node(node_id)
        state.study_records[snapshot.study_index] = {
            "study_index": snapshot.study_index,
            "node_id": node_id,
        }
        state.render_calls += 1
        graph.promote_node(node_id, render_calls_used=state.render_calls)
        state.events.append(
            {
                "type": "render_shader",
                "ok": False,
                "revision": 0,
                "render_call": state.render_calls,
                "stage": "promotion",
            }
        )
        state.promotion_records[snapshot.study_index] = {
            "study_index": snapshot.study_index,
            "node_id": node_id,
        }
        state._persist()

    def accept_node(self, state: ShaderAgentState, node_id: str) -> None:
        accepted = state.evaluate_study_node(
            node_id,
            "accept",
            VISIBLE_EVIDENCE,
            "[]",
            "[]",
            0.0,
        )
        self.assertTrue(accepted["ok"], accepted)

    def test_definition_parallel_siblings_child_block_and_node_rubric(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary))
            defined = self.define_standard_graph(state)

            self.assertEqual(
                defined["assignments"],
                {"macro_form": 1, "material_language": 2, "scene_join": 3},
            )
            self.assertEqual(
                set(defined["ready_frontier"]),
                {"macro_form", "material_language"},
            )

            first = state.begin_study_node("macro_form")
            sibling = state.begin_study_node("material_language")
            blocked_child = state.begin_study_node("scene_join")
            self.assertTrue(first["ok"], first)
            self.assertTrue(sibling["ok"], sibling)
            self.assertFalse(blocked_child["ok"])
            self.assertIn("dependency", blocked_child["error"])

            macro_rubric = state._selector_rubric(1)
            material_rubric = state._selector_rubric(2)
            self.assertIn("Signature macro form", macro_rubric)
            self.assertIn(
                "Which construction best resolves the visible macro_form decision?",
                macro_rubric,
            )
            self.assertIn(
                "macro_form collapses into a glued-on oval", macro_rubric
            )
            self.assertIn("Material language", material_rubric)
            self.assertNotEqual(macro_rubric, material_rubric)

    def test_graph_must_precede_shader_and_accept_allows_only_minor_residuals(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            late = self.make_state(root, workspace_name="late")
            self.assertTrue(late.write_shader(VALID_SHADER)["ok"])
            rejected = late.define_study_graph(
                json.dumps(standard_graph()), GRAPH_RATIONALE
            )
            self.assertFalse(rejected["ok"])
            self.assertIn("before writing", rejected["error"])

            state = self.make_state(root, workspace_name="acceptance")
            self.define_standard_graph(state)
            self.advance_without_renderer(state, "macro_form")
            minor = state.evaluate_study_node(
                "macro_form",
                "accept",
                VISIBLE_EVIDENCE,
                "[]",
                json.dumps(
                    [{"residual": "Minor highlight mismatch", "severity": 0.2}]
                ),
                0.05,
            )
            self.assertTrue(minor["ok"], minor)
            severe = state.evaluate_study_node(
                "macro_form",
                "accept",
                VISIBLE_EVIDENCE,
                "[]",
                json.dumps(
                    [{"residual": "Large silhouette mismatch", "severity": 0.5}]
                ),
                0.05,
            )
            self.assertFalse(severe["ok"])
            self.assertIn("severity <= 0.25", severe["error"])

    def test_record_select_and_exact_full_frame_promotion_lifecycle(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(
                Path(temporary), require_artifacts=True
            )
            self.define_standard_graph(state)
            begun = state.begin_study_node("macro_form")
            self.assertTrue(begun["ok"], begun)

            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                self.assertTrue(state.write_shader(study_shader(1))["ok"])
                first, _ = state.render_shader("study", 1)
                self.assertTrue(first["ok"], first)

                rewritten = state.write_shader(
                    study_shader(1, suffix="materially distinct pass two"),
                    REVISION_CRITIQUE,
                )
                self.assertTrue(rewritten["ok"], rewritten)
                second, _ = state.render_shader("study", 1)
                self.assertTrue(second["ok"], second)

            graph = state.study_dag
            assert graph is not None
            self.assertEqual(graph.snapshot("macro_form").status, "studied")
            recorded = state.record_study(
                1,
                "reference-specific signature macro form",
                "B",
                SELECTION_RATIONALE,
                HANDOFF_REQUIREMENTS,
                selected_render_call=2,
            )
            self.assertTrue(recorded["ok"], recorded)
            self.assertEqual(graph.snapshot("macro_form").status, "selected")
            artifact_id = str(recorded["artifact_id"])
            exact_block = str(state.locked_artifacts[artifact_id]["source"])

            promoted_write = state.write_shader(
                promoted_shader(exact_block), REVISION_CRITIQUE
            )
            self.assertTrue(promoted_write["ok"], promoted_write)
            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                promotion_render, _ = state.render_shader("promotion", 1)
            self.assertTrue(promotion_render["ok"], promotion_render)
            promoted = state.promote_study(1, INTEGRATION_EVIDENCE)
            self.assertTrue(promoted["ok"], promoted)
            self.assertEqual(graph.snapshot("macro_form").status, "promoted")
            self.assertEqual(
                state.study_records[1]["status"], "promoted_locked"
            )
            self.assertEqual(
                state.locked_artifacts[artifact_id]["source"], exact_block
            )
            resumed = self.make_state(
                Path(temporary),
                resume_existing=True,
                require_artifacts=True,
            )
            self.assertEqual(
                resumed.study_dag.snapshot("macro_form").status,  # type: ignore[union-attr]
                "promoted",
            )

    def test_expansion_is_evidence_gated_and_roundtrips_exactly(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = self.make_state(root)
            initial = [node("shape"), node("surface"), node("lighting")]
            defined = state.define_study_graph(
                json.dumps(initial), GRAPH_RATIONALE
            )
            self.assertTrue(defined["ok"], defined)
            self.advance_without_renderer(state, "shape")

            criterion = str(initial[0]["success_criteria"][0])
            expanded_decision = state.evaluate_study_node(
                "shape",
                "expand",
                VISIBLE_EVIDENCE,
                json.dumps([criterion]),
                json.dumps(
                    [
                        {
                            "residual": "The outer contour still lacks the target hook",
                            "severity": 0.7,
                        }
                    ]
                ),
                0.65,
            )
            self.assertTrue(expanded_decision["ok"], expanded_decision)

            child = node(
                "shape_hook_refinement",
                depends_on=("shape",),
                title="Hook refinement",
            )
            mismatched = state.expand_study_graph(
                "shape",
                json.dumps([child]),
                VISIBLE_EVIDENCE,
                json.dumps(["a criterion that was never evaluated"]),
                0.65,
            )
            self.assertFalse(mismatched["ok"])
            self.assertIn("match the latest evaluation", mismatched["error"])

            unrelated = state.expand_study_graph(
                "shape",
                json.dumps([node("unrelated_branch")]),
                VISIBLE_EVIDENCE,
                json.dumps([criterion]),
                0.65,
            )
            self.assertFalse(unrelated["ok"])
            self.assertIn("direct child", unrelated["error"])

            grown = state.expand_study_graph(
                "shape",
                json.dumps([child]),
                VISIBLE_EVIDENCE,
                json.dumps([criterion]),
                0.65,
            )
            self.assertTrue(grown["ok"], grown)
            self.assertEqual(grown["assignments"], {"shape_hook_refinement": 4})

            before = state.inspect_study_graph()
            resumed = self.make_state(root, resume_existing=True)
            after = resumed.inspect_study_graph()
            self.assertTrue(after["ok"], after)
            self.assertEqual(after["nodes"], before["nodes"])
            self.assertEqual(after["ready_frontier"], before["ready_frontier"])
            self.assertEqual(after["render_calls_used"], state.render_calls)
            self.assertEqual(
                resumed.node_evaluations, state.node_evaluations
            )
            self.assertEqual(
                resumed.graph_growth_events, state.graph_growth_events
            )

            original_payload = json.loads(
                state.state_path.read_text(encoding="utf-8")
            )
            mismatched_passes = json.loads(json.dumps(original_payload))
            mismatched_passes["successful_study_render_count"]["1"] = 0
            state.state_path.write_text(
                json.dumps(mismatched_passes), encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "pass ledger disagrees"):
                self.make_state(root, resume_existing=True)

            mismatched_budget = json.loads(json.dumps(original_payload))
            mismatched_budget["study_dag"]["config"]["render_budget"] = 17
            state.state_path.write_text(
                json.dumps(mismatched_budget), encoding="utf-8"
            )
            with self.assertRaisesRegex(ValueError, "graph configuration"):
                self.make_state(root, resume_existing=True)

            over_budget = json.loads(json.dumps(original_payload))
            over_budget["render_calls"] = 19
            state.state_path.write_text(json.dumps(over_budget), encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "within render_budget"):
                self.make_state(root, resume_existing=True)

    def test_final_render_is_blocked_until_acceptance_and_graph_closure(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary))
            self.define_standard_graph(state)
            written = state.write_shader(VALID_SHADER)
            self.assertTrue(written["ok"], written)

            blocked, _ = state.render_shader("final", 0)
            self.assertFalse(blocked["ok"])
            self.assertIn("close", blocked["error"])
            self.assertEqual(state.render_calls, 0)

            self.advance_without_renderer(state, "macro_form")
            self.accept_node(state, "macro_form")
            premature_close = state.close_study_graph(CLOSURE_EVIDENCE)
            self.assertFalse(premature_close["ok"])
            self.assertIn("accept evaluation", premature_close["error"])

            self.advance_without_renderer(state, "material_language")
            self.accept_node(state, "material_language")
            self.advance_without_renderer(state, "scene_join")
            self.accept_node(state, "scene_join")
            closed = state.close_study_graph(CLOSURE_EVIDENCE)
            self.assertTrue(closed["ok"], closed)
            self.assertEqual(closed["final_node_id"], "scene_join")

            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                rendered, image_path = state.render_shader("final", 0)
            self.assertTrue(rendered["ok"], rendered)
            self.assertIsNotNone(image_path)
            self.assertEqual(
                state.study_dag.successful_final_renders, 1  # type: ignore[union-attr]
            )

            duplicate_write = state.write_shader(VALID_SHADER, REVISION_CRITIQUE)
            self.assertTrue(duplicate_write["ok"], duplicate_write)
            calls_before_duplicate = state.render_calls
            duplicate, _ = state.render_shader("final", 0)
            self.assertFalse(duplicate["ok"])
            self.assertFalse(duplicate["render_budget_consumed"])
            self.assertEqual(state.render_calls, calls_before_duplicate)
            self.assertEqual(
                state.study_dag.successful_final_renders, 1  # type: ignore[union-attr]
            )

            distinct_write = state.write_shader(
                VALID_SHADER + "\n// distinct final revision\n",
                REVISION_CRITIQUE,
            )
            self.assertTrue(distinct_write["ok"], distinct_write)
            with (
                patch("shader_agent_mcp.subprocess.run", fake_renderer),
                patch.object(
                    AdaptiveStudyDAG,
                    "record_final",
                    side_effect=StudyDAGError("forced accounting fault"),
                ),
            ):
                accounting_failure, image_path = state.render_shader("final", 0)
            self.assertFalse(accounting_failure["ok"])
            self.assertIsNone(image_path)
            self.assertIn("forced accounting fault", accounting_failure["graph_accounting_error"])
            self.assertEqual(
                state.study_dag.render_calls_used,  # type: ignore[union-attr]
                state.render_calls,
            )
            self.assertNotIn(
                distinct_write["revision"], state.successful_render_by_revision
            )


if __name__ == "__main__":
    unittest.main()
