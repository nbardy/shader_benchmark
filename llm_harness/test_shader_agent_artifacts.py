"""Focused contract tests for promoted study artifacts in the v8 workflow."""

from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from PIL import Image

from shader_agent_mcp import (
    ShaderAgentState,
    _artifact_manifest_errors,
    _extract_artifact_blocks,
)


SELECTION_RATIONALE = (
    "Variant B has the strongest reference-specific hooked silhouette, negative "
    "space, and continuous three-dimensional bend; F is a safer generic oval."
)
HANDOFF_REQUIREMENTS = (
    "Preserve the exact selected artifact function and its subtraction, then "
    "call it from the live scene path before adding dependent surface details."
)
INTEGRATION_EVIDENCE = (
    "The promoted full-frame render calls the selected artifact from the live "
    "scene SDF, preserves its negative space, and visibly carries its silhouette."
)
REVISION_CRITIQUE = (
    "Preserve the selected hooked artifact exactly while changing only its "
    "surrounding integration, dependent geometry, and final scene composition."
)


def artifact_block(study_index: int, label: str) -> str:
    """Return one exact, independently extractable WGSL artifact block."""
    lower = label.lower()
    offset = "ABCDEF".index(label) + 1
    return (
        f"// @shaderbench-artifact-begin "
        f"id=study_{study_index}_{label} "
        f"entry=artifact_s{study_index}_{lower}\n"
        f"fn artifact_s{study_index}_{lower}(p: vec3<f32>) -> f32 {{\n"
        f"    return length(p + vec3<f32>({offset}.0, 0.0, 0.0)) - 0.5;\n"
        "}\n"
        f"// @shaderbench-artifact-end id=study_{study_index}_{label}\n"
    )


def shader_with_artifacts(
    study_index: int = 1,
    labels: str = "ABCDEF",
    live_entry: str = "artifact_s1_b",
    retained_blocks: tuple[str, ...] = (),
) -> str:
    """Build a compact valid shader containing an A-F study manifest."""
    blocks = list(retained_blocks)
    blocks.extend(artifact_block(study_index, label) for label in labels)
    current_entries = [
        f"artifact_s{study_index}_{label.lower()}" for label in labels
    ]
    calls = [f"    var distance = {live_entry}(p);"]
    calls.extend(
        f"    distance = min(distance, {entry}(p));"
        for entry in current_entries
    )
    if retained_blocks and live_entry != "artifact_s1_b":
        calls.append("    distance = min(distance, artifact_s1_b(p));")
    calls.append("    return distance;")
    return (
        "\n\n".join(blocks)
        + "\n\n"
        + f"""
fn scene_sdf(p: vec3<f32>) -> f32 {{
{chr(10).join(calls)}
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
"""
    )


def integrated_shader(block: str, *, call_artifact: bool = True) -> str:
    """Build a full-frame shader that either uses or strands a locked block."""
    body = (
        "return artifact_s1_b(p);"
        if call_artifact
        else "return length(p) - 1.0;"
    )
    return (
        block
        + "\n\n"
        + f"""
fn scene_sdf(p: vec3<f32>) -> f32 {{
    {body}
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
"""
    )


def selector_result() -> dict[str, object]:
    ordered_variants = sorted(
        "ABCDEF",
        key=lambda variant: hashlib.sha256(
            f"shaderbench-v8-selector:1:1:{variant}".encode("utf-8")
        ).hexdigest(),
    )
    winner = f"candidate_{ordered_variants.index('B') + 1:02d}"
    candidate_ids = [
        f"candidate_{index:02d}" for index in range(1, 7)
    ]
    return {
        "winner": winner,
        "ranking": [winner]
        + [candidate_id for candidate_id in candidate_ids if candidate_id != winner],
        "evidence": (
            "B most closely matches the hooked reference silhouette and "
            "subtractive negative space; C is the next strongest construction."
        ),
        "runner_up_tradeoff": (
            "C has useful curvature but loses the specific hooked negative space."
        ),
    }


def fake_renderer(command: list[str], **_: object) -> object:
    """Render a deterministic 3x2 atlas with a distinct top-middle B cell."""
    output = Path(command[command.index("--output") + 1])
    atlas = Image.new("RGB", (300, 200), (0, 0, 0))
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


class ShaderArtifactWorkflowTests(unittest.TestCase):
    def make_state(
        self,
        root: Path,
        *,
        required_studies: int = 1,
        min_successful_revisions: int = 1,
    ) -> tuple[ShaderAgentState, Mock]:
        renderer = root / "renderer"
        renderer.write_text("fake", encoding="utf-8")
        reference = root / "reference.png"
        Image.new("RGB", (64, 64), (10, 20, 30)).save(reference)
        selector = Mock(return_value=selector_result())
        state = ShaderAgentState(
            root / "workspace",
            renderer,
            render_budget=12,
            render_size=64,
            min_successful_revisions=min_successful_revisions,
            required_studies=required_studies,
            require_artifact_blocks=True,
            require_study_selector=True,
            require_study_promotions=True,
            reference_image=reference,
            selector_runner=selector,
        )
        return state, selector

    def render_and_rank_first_study(
        self, state: ShaderAgentState
    ) -> tuple[dict[str, object], str]:
        source = shader_with_artifacts()
        self.assertTrue(state.write_shader(source)["ok"])
        with patch("shader_agent_mcp.subprocess.run", fake_renderer):
            rendered, _ = state.render_shader("study", 1)
        self.assertTrue(rendered["ok"])
        ranked, _ = state.rank_study(1)
        self.assertTrue(ranked["ok"])
        self.assertEqual(ranked["winner_origin"]["variant"], "B")
        return ranked, source

    def record_first_study(self, state: ShaderAgentState) -> dict[str, object]:
        self.render_and_rank_first_study(state)
        recorded = state.record_study(
            1,
            "reference-specific hooked macro form",
            "B",
            SELECTION_RATIONALE,
            HANDOFF_REQUIREMENTS,
            selected_render_call=1,
        )
        self.assertTrue(recorded["ok"])
        return recorded

    def test_extracts_exactly_six_marked_artifact_blocks(self):
        source = shader_with_artifacts()
        blocks = _extract_artifact_blocks(source)

        expected_ids = {f"study_1_{label}" for label in "ABCDEF"}
        self.assertEqual(set(blocks), expected_ids)
        for label in "ABCDEF":
            artifact_id = f"study_1_{label}"
            self.assertEqual(
                blocks[artifact_id]["entry_symbol"],
                f"artifact_s1_{label.lower()}",
            )
            self.assertEqual(
                blocks[artifact_id]["source"],
                artifact_block(1, label),
            )
        self.assertEqual(_artifact_manifest_errors(source, 1), [])

        missing_f = shader_with_artifacts(labels="ABCDE")
        errors = _artifact_manifest_errors(missing_f, 1)
        self.assertTrue(errors)
        self.assertTrue(any("study_1_F" in error for error in errors))

    def test_selector_winner_gates_record_and_materializes_exact_artifacts(self):
        with tempfile.TemporaryDirectory() as temporary:
            state, selector = self.make_state(Path(temporary))
            self.render_and_rank_first_study(state)
            selector.assert_called_once()

            rejected = state.record_study(
                1,
                "reference-specific hooked macro form",
                "F",
                SELECTION_RATIONALE,
                HANDOFF_REQUIREMENTS,
                selected_render_call=1,
            )
            self.assertFalse(rejected["ok"])
            self.assertEqual(rejected["selector_variant"], "B")

            accepted = state.record_study(
                1,
                "reference-specific hooked macro form",
                "B",
                SELECTION_RATIONALE,
                HANDOFF_REQUIREMENTS,
                selected_render_call=1,
            )
            self.assertTrue(accepted["ok"])
            source_path = Path(accepted["artifact_source_path"])
            crop_path = Path(accepted["artifact_crop_path"])
            self.assertEqual(
                source_path.read_text(encoding="utf-8"),
                artifact_block(1, "B"),
            )
            with Image.open(crop_path) as crop:
                self.assertEqual(crop.size, (100, 100))
                self.assertEqual(
                    crop.convert("RGB").getpixel((50, 50)),
                    (20, 200, 30),
                )

    def test_locked_artifact_rejects_mutation_omission_and_dead_only_use(self):
        with tempfile.TemporaryDirectory() as temporary:
            state, _ = self.make_state(Path(temporary))
            self.record_first_study(state)
            locked = artifact_block(1, "B")

            injected = state.write_shader(
                integrated_shader(
                    "// @shaderbench-inject id=study_1_B\n"
                ),
                REVISION_CRITIQUE,
            )
            self.assertTrue(injected["ok"])
            self.assertEqual(injected["injected_artifacts"], ["study_1_B"])
            self.assertIn(
                locked,
                state.shader_path.read_text(encoding="utf-8"),
            )

            mutated = integrated_shader(
                locked.replace("2.0, 0.0, 0.0", "9.0, 0.0, 0.0")
            )
            mutation = state.write_shader(mutated, REVISION_CRITIQUE)
            self.assertFalse(mutation["ok"])
            self.assertIn(
                "locked",
                " ".join(mutation["artifact_lineage_errors"]).lower(),
            )

            missing = state.write_shader(
                integrated_shader("", call_artifact=False),
                REVISION_CRITIQUE,
            )
            self.assertFalse(missing["ok"])
            self.assertIn(
                "locked",
                " ".join(missing["artifact_lineage_errors"]).lower(),
            )

            dead_only = state.write_shader(
                integrated_shader(locked, call_artifact=False),
                REVISION_CRITIQUE,
            )
            self.assertFalse(dead_only["ok"])
            self.assertIn(
                "not called",
                " ".join(dead_only["artifact_lineage_errors"]).lower(),
            )

            retained = state.write_shader(
                integrated_shader(locked),
                REVISION_CRITIQUE,
            )
            self.assertTrue(retained["ok"])

    def test_promotion_is_required_before_later_studies_and_final(self):
        with tempfile.TemporaryDirectory() as temporary:
            state, _ = self.make_state(Path(temporary), required_studies=2)
            self.record_first_study(state)
            locked = artifact_block(1, "B")
            self.assertTrue(
                state.write_shader(
                    integrated_shader(locked),
                    REVISION_CRITIQUE,
                )["ok"]
            )

            later, _ = state.render_shader("study", 2)
            self.assertFalse(later["ok"])
            self.assertIn("promote", later["error"].lower())
            self.assertEqual(state.render_calls, 1)

            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                promotion_render, _ = state.render_shader("promotion", 1)
            self.assertTrue(promotion_render["ok"])
            promoted = state.promote_study(1, INTEGRATION_EVIDENCE)
            self.assertTrue(promoted["ok"])
            self.assertEqual(promoted["status"], "promoted_locked")
            self.assertEqual(
                state.study_records[1]["status"], "promoted_locked"
            )
            persisted = json.loads(
                state.state_path.read_text(encoding="utf-8")
            )
            self.assertEqual(
                persisted["study_records"]["1"]["status"],
                "promoted_locked",
            )
            manifest = json.loads(
                (
                    state.workspace
                    / "artifacts"
                    / "study_1_B"
                    / "manifest.json"
                ).read_text(encoding="utf-8")
            )
            self.assertEqual(manifest["status"], "promoted_locked")

            second_study_source = shader_with_artifacts(
                study_index=2,
                live_entry="artifact_s2_a",
                retained_blocks=(locked,),
            )
            self.assertTrue(
                state.write_shader(
                    second_study_source,
                    REVISION_CRITIQUE,
                )["ok"]
            )
            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                later, _ = state.render_shader("study", 2)
            self.assertTrue(later["ok"])

        with tempfile.TemporaryDirectory() as temporary:
            state, _ = self.make_state(Path(temporary), required_studies=1)
            self.record_first_study(state)
            locked = artifact_block(1, "B")
            self.assertTrue(
                state.write_shader(
                    integrated_shader(locked),
                    REVISION_CRITIQUE,
                )["ok"]
            )
            final, _ = state.render_shader("final", 0)
            self.assertFalse(final["ok"])
            self.assertIn("promote", final["error"].lower())

    def test_checkpoint_resume_rehydrates_locks_history_and_budget(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state, _ = self.make_state(root)
            self.record_first_study(state)
            locked = artifact_block(1, "B")
            self.assertTrue(
                state.write_shader(
                    integrated_shader(
                        "// @shaderbench-inject id=study_1_B\n"
                    ),
                    REVISION_CRITIQUE,
                )["ok"]
            )
            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                promoted_render, _ = state.render_shader("promotion", 1)
            self.assertTrue(promoted_render["ok"])
            self.assertTrue(
                state.promote_study(1, INTEGRATION_EVIDENCE)["ok"]
            )

            resumed = ShaderAgentState(
                root / "workspace",
                root / "renderer",
                render_budget=12,
                render_size=64,
                min_successful_revisions=1,
                required_studies=1,
                require_artifact_blocks=True,
                require_study_selector=True,
                require_study_promotions=True,
                reference_image=root / "reference.png",
                selector_runner=Mock(),
                resume_existing=True,
            )
            self.assertEqual(resumed.render_calls, 2)
            self.assertEqual(resumed.revision, 2)
            self.assertIn(1, resumed.study_records)
            self.assertIn(1, resumed.promotion_records)
            self.assertEqual(
                resumed.locked_artifacts["study_1_B"]["source"], locked
            )
            rewritten = resumed.write_shader(
                integrated_shader(
                    "// @shaderbench-inject id=study_1_B\n"
                )
                + "\n// resumed bounded revision\n",
                REVISION_CRITIQUE,
            )
            self.assertTrue(rewritten["ok"])
            self.assertEqual(rewritten["revision"], 3)

    def test_submit_final_can_select_an_earlier_successful_revision(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=3,
                render_size=64,
                min_successful_revisions=2,
            )
            first = integrated_shader("", call_artifact=False) + "\n// first"
            second = integrated_shader("", call_artifact=False) + "\n// second"

            with patch("shader_agent_mcp.subprocess.run", fake_renderer):
                self.assertTrue(state.write_shader(first)["ok"])
                first_render, _ = state.render_shader("final", 0)
                self.assertTrue(first_render["ok"])
                self.assertTrue(
                    state.write_shader(second, REVISION_CRITIQUE)["ok"]
                )
                second_render, _ = state.render_shader("final", 0)
                self.assertTrue(second_render["ok"])

            submitted = state.submit_final(
                "Revision 1 preserves the stronger studied silhouette.",
                revision=1,
            )
            self.assertTrue(submitted["ok"])
            self.assertEqual(submitted["revision"], 1)
            self.assertEqual(
                (state.workspace / "final_shader.wgsl").read_text(
                    encoding="utf-8"
                ),
                first,
            )


if __name__ == "__main__":
    unittest.main()
