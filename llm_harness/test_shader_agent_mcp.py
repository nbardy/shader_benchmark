import asyncio
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from shader_agent_mcp import (
    ShaderAgentState,
    _atlas_diversity_metrics,
    create_mcp,
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
    return vec4<f32>(1.0);
}
"""


class ShaderAgentStateTests(unittest.TestCase):
    def make_state(self, root: Path, budget: int = 2) -> ShaderAgentState:
        renderer = root / "renderer"
        renderer.write_text("fake", encoding="utf-8")
        return ShaderAgentState(root / "workspace", renderer, budget, 64)

    def test_submission_requires_current_revision_to_render(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary))
            self.assertTrue(state.write_shader(VALID_SHADER)["ok"])
            rejected = state.submit_final()
            self.assertFalse(rejected["ok"])

    def test_successful_render_can_be_submitted(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary))
            state.write_shader(VALID_SHADER)

            def fake_run(command, **kwargs):
                output_index = command.index("--output") + 1
                Image.new("RGB", (8, 8), "blue").save(command[output_index])
                return type(
                    "Completed",
                    (),
                    {"returncode": 0, "stdout": "ok", "stderr": ""},
                )()

            with patch("shader_agent_mcp.subprocess.run", fake_run):
                rendered, image_path = state.render_shader()
            self.assertTrue(rendered["ok"])
            self.assertTrue(image_path.exists())
            submitted = state.submit_final("done")
            self.assertTrue(submitted["ok"])
            self.assertTrue((state.workspace / "final_shader.wgsl").exists())
            self.assertTrue((state.workspace / "final_render.png").exists())

    def test_render_budget_counts_failures(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary), budget=1)
            state.write_shader(VALID_SHADER)
            failure = type(
                "Completed",
                (),
                {"returncode": 1, "stdout": "", "stderr": "compile failed"},
            )()
            with patch(
                "shader_agent_mcp.subprocess.run", return_value=failure
            ):
                first, _ = state.render_shader()
                second, _ = state.render_shader()
            self.assertFalse(first["ok"])
            self.assertIn("compile failed", first["compiler_feedback"])
            self.assertFalse(second["ok"])
            self.assertEqual(second["error"], "Render budget exhausted.")
            self.assertEqual(state.render_calls, 1)

    def test_unchanged_rerender_is_rejected_without_spending_budget(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary), budget=2)
            state.write_shader(VALID_SHADER)
            failure = type(
                "Completed",
                (),
                {"returncode": 1, "stdout": "", "stderr": "compile failed"},
            )()
            with patch(
                "shader_agent_mcp.subprocess.run", return_value=failure
            ):
                state.render_shader()
                rejected, _ = state.render_shader()
            self.assertIn(
                "already been rendered or attempted", rejected["error"]
            )
            self.assertEqual(state.render_calls, 1)

    def test_submission_can_require_two_successful_revisions(self):
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

            def fake_run(command, **kwargs):
                output_index = command.index("--output") + 1
                Image.new("RGB", (8, 8), "blue").save(command[output_index])
                return type(
                    "Completed",
                    (),
                    {"returncode": 0, "stdout": "ok", "stderr": ""},
                )()

            with patch("shader_agent_mcp.subprocess.run", fake_run):
                state.write_shader(VALID_SHADER)
                state.render_shader()
                self.assertFalse(state.submit_final()["ok"])
                state.write_shader(
                    VALID_SHADER + "\n// revision two\n",
                    (
                        "The target is warmer and more asymmetric; preserve "
                        "the silhouette while tightening the eye and beak."
                    ),
                )
                state.render_shader()
            self.assertTrue(state.submit_final()["ok"])

    def test_rewrite_requires_an_auditable_revision_critique(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary), budget=2)
            self.assertTrue(state.write_shader(VALID_SHADER)["ok"])
            rejected = state.write_shader(VALID_SHADER + "\n// change\n")
            self.assertFalse(rejected["ok"])
            self.assertIn("revision_critique", rejected["error"])

    def test_mcp_render_result_contains_a_real_image_content_block(self):
        with tempfile.TemporaryDirectory() as temporary:
            state = self.make_state(Path(temporary))
            state.write_shader(VALID_SHADER)

            def fake_run(command, **kwargs):
                output_index = command.index("--output") + 1
                Image.new("RGB", (8, 8), "blue").save(command[output_index])
                return type(
                    "Completed",
                    (),
                    {"returncode": 0, "stdout": "ok", "stderr": ""},
                )()

            server = create_mcp(state)
            with patch("shader_agent_mcp.subprocess.run", fake_run):
                result = asyncio.run(server.call_tool("render_shader", {}))
            self.assertEqual(result.content[0].type, "text")
            self.assertEqual(result.content[1].type, "image")
            self.assertEqual(result.content[1].mimeType, "image/png")

    def test_sketchbook_blocks_final_until_three_studies_are_recorded(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=5,
                render_size=64,
                min_successful_revisions=2,
                required_studies=3,
            )

            def fake_run(command, **kwargs):
                output_index = command.index("--output") + 1
                Image.new("RGB", (8, 8), "blue").save(command[output_index])
                return type(
                    "Completed",
                    (),
                    {"returncode": 0, "stdout": "ok", "stderr": ""},
                )()

            state.write_shader(VALID_SHADER)
            blocked, _ = state.render_shader("final", 0)
            self.assertFalse(blocked["ok"])
            self.assertEqual(state.render_calls, 0)

            with patch("shader_agent_mcp.subprocess.run", fake_run):
                for study_index in range(1, 4):
                    if study_index > 1:
                        state.write_shader(
                            VALID_SHADER + f"\n// study {study_index}\n",
                            (
                                "The prior atlas established the broad form; "
                                "this next atlas isolates another visible "
                                "subject-specific construction decision."
                            ),
                        )
                    rendered, _ = state.render_shader("study", study_index)
                    self.assertTrue(rendered["ok"])
                    recorded = state.record_study(
                        study_index,
                        f"core element {study_index}",
                        "C",
                        (
                            "Variant C has the clearest curved silhouette and "
                            "most convincing overlap while A and B remain too "
                            "flat and D through F lose the reference gesture."
                        ),
                        (
                            "Reuse the selected profile function, its local "
                            "surface frame, curvature range, taper parameters, "
                            "and overlap ordering in the integrated final scene."
                        ),
                    )
                    self.assertTrue(recorded["ok"])

                state.write_shader(
                    VALID_SHADER + "\n// final one\n",
                    (
                        "All three studies are now selected; integrate their "
                        "exact profiles, coordinate frames, material response, "
                        "and controlled variation into the reference composition."
                    ),
                )
                first_final, _ = state.render_shader("final", 0)
                self.assertTrue(first_final["ok"])
                self.assertFalse(state.submit_final()["ok"])
                state.write_shader(
                    VALID_SHADER + "\n// final two\n",
                    (
                        "The first final render preserves the studied forms but "
                        "needs tighter composition and stronger focal contrast "
                        "without changing the selected component constructions."
                    ),
                )
                second_final, _ = state.render_shader("final", 0)
                self.assertTrue(second_final["ok"])
            self.assertTrue(state.submit_final()["ok"])

    def test_study_record_requires_a_valid_variant_and_visible_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=2,
                render_size=64,
                min_successful_revisions=1,
                required_studies=1,
            )
            state.latest_successful_study_render[1] = {
                "revision": 1,
                "render_call": 1,
            }
            state.successful_study_render_count[1] = 1
            rejected = state.record_study(1, "shape", "G", "x" * 100, "y" * 100)
            self.assertFalse(rejected["ok"])

    def test_curved_workflow_requires_a_thorough_a_to_f_inventory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=2,
                render_size=64,
                min_successful_revisions=1,
                required_studies=1,
                require_variant_inventory=True,
            )
            state.latest_successful_study_render[1] = {
                "revision": 1,
                "render_call": 1,
            }
            state.successful_study_render_count[1] = 1
            rejected = state.record_study(
                1,
                "curved element",
                "C",
                "x" * 100,
                "y" * 100,
                "A: oval B: oval C: oval",
            )
            self.assertFalse(rejected["ok"])
            accepted = state.record_study(
                1,
                "curved element",
                "C",
                (
                    "Variant C visibly has the strongest curved centerline, "
                    "controlled root, asymmetric width, and tapered lifted tip."
                ),
                (
                    "Reuse its cubic centerline, surface-local frame, shoulder "
                    "width, taper start, camber, and root attachment parameters."
                ),
                (
                    "A: quadratic swept lens with a broad shoulder. "
                    "B: cubic Bezier vane with asymmetric edges. "
                    "C: segmented tapered sweep with camber and a lifted tip. "
                    "D: inverse-bent notched profile. "
                    "E: layered rachis and paired vanes. "
                    "F: intersected shell with a narrow curved root."
                ),
            )
            self.assertTrue(accepted["ok"])

    def test_later_study_requires_the_previous_selection(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=4,
                render_size=64,
                min_successful_revisions=1,
                required_studies=3,
            )
            state.write_shader(VALID_SHADER)
            rejected, _ = state.render_shader("study", 2)
            self.assertFalse(rejected["ok"])
            self.assertEqual(rejected["missing_prior_studies"], [1])
            self.assertEqual(state.render_calls, 0)

    def test_progressive_study_requires_two_successful_render_passes(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=3,
                render_size=64,
                min_successful_revisions=1,
                required_studies=1,
                min_successful_study_renders=2,
            )

            def fake_run(command, **kwargs):
                output_index = command.index("--output") + 1
                Image.new("RGB", (8, 8), "blue").save(command[output_index])
                return type(
                    "Completed",
                    (),
                    {"returncode": 0, "stdout": "ok", "stderr": ""},
                )()

            with patch("shader_agent_mcp.subprocess.run", fake_run):
                state.write_shader(VALID_SHADER)
                first, _ = state.render_shader("study", 1)
                self.assertEqual(first["study_pass"], 1)
                rejected = state.record_study(
                    1,
                    "primitive shape",
                    "A",
                    (
                        "Variant A has the clearest readable silhouette while "
                        "the alternatives reveal useful curvature tradeoffs."
                    ),
                    (
                        "Reuse the selected primitive function, its local frame, "
                        "width profile, taper, material, and bounded parameters."
                    ),
                )
                self.assertFalse(rejected["ok"])
                state.write_shader(
                    VALID_SHADER + "\n// refinement pass\n",
                    (
                        "The first atlas found two viable silhouettes; this "
                        "second atlas refines their curvature, taper, internal "
                        "structure, and material response at larger contrast."
                    ),
                )
                second, _ = state.render_shader("study", 1)
                self.assertEqual(second["study_pass"], 2)
            accepted = state.record_study(
                1,
                "primitive shape",
                "F",
                (
                    "Across both passes, F preserves the strongest first-pass "
                    "gesture while the refinement fixes its root and tip."
                ),
                (
                    "Reuse the refined F function, local frame, shoulder and "
                    "taper ranges, material response, and internal structure."
                ),
            )
            self.assertTrue(accepted["ok"])
            self.assertEqual(accepted["study_pass"], 2)

    def test_visual_diversity_gate_rejects_duplicate_atlas_cells(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=3,
                render_size=64,
                min_successful_revisions=1,
                required_studies=1,
                require_study_diversity=True,
            )
            render_number = 0

            def fake_run(command, **kwargs):
                nonlocal render_number
                render_number += 1
                output_index = command.index("--output") + 1
                output = Path(command[output_index])
                if render_number == 1:
                    Image.new("RGB", (300, 200), "blue").save(output)
                else:
                    atlas = Image.new("RGB", (300, 200), "black")
                    colors = ("red", "green", "blue", "yellow", "cyan", "magenta")
                    for index, color in enumerate(colors):
                        left = (index % 3) * 100
                        top = (index // 3) * 100
                        atlas.paste(color, (left, top, left + 100, top + 100))
                    atlas.save(output)
                return type(
                    "Completed",
                    (),
                    {"returncode": 0, "stdout": "ok", "stderr": ""},
                )()

            with patch("shader_agent_mcp.subprocess.run", fake_run):
                state.write_shader(VALID_SHADER)
                duplicate, duplicate_path = state.render_shader(
                    "study",
                    1,
                    (
                        "A: broad symmetric leaf with a blunt tip. "
                        "B: narrow swept leaf with a hooked tip. "
                        "C: asymmetric vane with a deep center groove. "
                        "D: layered feather with a split terminal notch. "
                        "E: strongly cambered blade with a narrow embedded root. "
                        "F: scalloped silhouette with an offset rachis and lifted tip."
                    ),
                )
                self.assertTrue(duplicate["ok"])
                self.assertFalse(duplicate["study_pass_qualified"])
                self.assertEqual(
                    state.successful_study_render_count.get(1, 0), 0
                )
                self.assertFalse(
                    _atlas_diversity_metrics(duplicate_path)["qualifies"]
                )
                state.write_shader(
                    VALID_SHADER + "\n// visibly different atlas\n",
                    (
                        "The first atlas was locally measured as near-duplicate; "
                        "this revision exaggerates six independent alternatives."
                    ),
                )
                varied, _ = state.render_shader(
                    "study",
                    1,
                    (
                        "A: broad symmetric leaf refined for shoulder width. "
                        "B: narrow swept leaf refined for stronger hook. "
                        "C: asymmetric vane refined with a visible center groove. "
                        "D: layered feather refined with a deeper terminal notch. "
                        "E: cambered blade refined with a thinner embedded root. "
                        "F: scalloped vane refined with offset rachis and tip lift."
                    ),
                )
            self.assertTrue(varied["study_pass_qualified"])
            self.assertEqual(state.successful_study_render_count[1], 1)

    def test_diversity_workflow_requires_a_predeclared_a_to_f_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            renderer = root / "renderer"
            renderer.write_text("fake", encoding="utf-8")
            state = ShaderAgentState(
                root / "workspace",
                renderer,
                render_budget=3,
                render_size=64,
                min_successful_revisions=1,
                required_studies=1,
                require_study_diversity=True,
            )
            state.write_shader(VALID_SHADER)
            rejected, image_path = state.render_shader(
                "study", 1, "A: one shape. B: another shape."
            )
            self.assertFalse(rejected["ok"])
            self.assertFalse(rejected["render_budget_consumed"])
            self.assertEqual(rejected["missing_variant_labels"], ["C:", "D:", "E:", "F:"])
            self.assertEqual(state.render_calls, 0)
            self.assertIsNone(image_path)


if __name__ == "__main__":
    unittest.main()
