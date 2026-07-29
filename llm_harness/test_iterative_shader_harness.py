import tempfile
import unittest
from pathlib import Path

from PIL import Image

from iterative_shader_harness import (
    HISTORY_CRITIQUE_LOOP_STRATEGY,
    HISTORY_CODE_CRITIQUE_LOOP_STRATEGY,
    build_revision_request,
    build_revision_output_contract,
    create_feedback_context,
    create_feedback_history,
    extract_revision_critique,
)


class IterativeShaderHarnessTests(unittest.TestCase):
    def test_first_round_preserves_original_request(self):
        self.assertEqual(
            build_revision_request(
                original_request="DRAW THIS",
                round_number=1,
                total_rounds=3,
                previous_shader="",
                previous_render_available=False,
                reference_available=True,
            ),
            "DRAW THIS",
        )

    def test_revision_round_contains_visual_contract_and_full_shader(self):
        result = build_revision_request(
            original_request="DRAW THIS",
            round_number=2,
            total_rounds=4,
            previous_shader="@fragment fn fs_main() {}",
            previous_render_available=True,
            reference_available=True,
            previous_error="naga error",
        )
        for required in (
            "ROUND 2 OF 4",
            "TARGET REFERENCE",
            "CURRENT RENDER",
            "COMPLETE replacement shader",
            "<previous_shader>",
            "@fragment fn fs_main() {}",
            "<render_error>",
            "naga error",
        ):
            self.assertIn(required, result)
        self.assertIn("identify the three", result)
        self.assertIn("highest-impact discrepancies", result)

    def test_feedback_context_contains_two_labeled_panels(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            reference = root / "reference.png"
            render = root / "render.png"
            output = root / "feedback.png"
            Image.new("RGB", (320, 480), (10, 200, 20)).save(reference)
            Image.new("RGB", (512, 512), (30, 40, 220)).save(render)

            result = create_feedback_context(
                current_render=render,
                reference_image=reference,
                output_path=output,
            )

            self.assertEqual(result, output.resolve())
            with Image.open(result) as image:
                self.assertEqual(image.size, (1536, 820))
                self.assertEqual(image.mode, "RGB")

    def test_history_loop_uses_all_prior_renders_and_latest_code(self):
        request = build_revision_request(
            original_request="DRAW THIS",
            round_number=3,
            total_rounds=3,
            previous_shader="LATEST EXECUTED WGSL",
            previous_render_available=True,
            reference_available=True,
            loop_strategy=HISTORY_CRITIQUE_LOOP_STRATEGY,
            history_render_count=2,
        )
        self.assertIn("2 prior render(s)", request)
        self.assertIn("newest render is not automatically best", request)
        self.assertIn("PRESERVE", request)
        self.assertIn("REGRESSION CHECKS", request)
        self.assertIn("LATEST EXECUTED WGSL", request)

        contract = build_revision_output_contract(
            HISTORY_CRITIQUE_LOOP_STRATEGY, 3, "baseline"
        )
        self.assertIn("<revision_critique>", contract)
        self.assertIn("<best_prior_round>", contract)
        self.assertIn("<regression_checks>", contract)

    def test_history_contact_sheet_has_target_and_two_rounds(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            reference = root / "reference.png"
            render_1 = root / "render_1.png"
            render_2 = root / "render_2.png"
            output = root / "feedback.png"
            Image.new("RGB", (320, 480), (10, 200, 20)).save(reference)
            Image.new("RGB", (512, 512), (30, 40, 220)).save(render_1)
            Image.new("RGB", (512, 512), (220, 40, 30)).save(render_2)
            create_feedback_history(
                [(1, render_1), (2, render_2)],
                output,
                reference,
            )
            with Image.open(output) as image:
                self.assertEqual(image.size, (1536, 564))

    def test_extracts_public_revision_critique(self):
        response = (
            "<revision_critique>preserve silhouette</revision_critique>"
            "<shader file=\"shader.wgsl\">code</shader>"
        )
        self.assertEqual(
            extract_revision_critique(response), "preserve silhouette"
        )

    def test_v3_supplies_bounded_prior_shader_history(self):
        request = build_revision_request(
            original_request="DRAW THIS",
            round_number=3,
            total_rounds=3,
            previous_shader="LATEST",
            previous_render_available=True,
            reference_available=True,
            loop_strategy=HISTORY_CODE_CRITIQUE_LOOP_STRATEGY,
            history_render_count=2,
            shader_history=[
                (1, "ROUND ONE CODE"),
                (2, "ROUND TWO CODE"),
            ],
        )
        self.assertIn('<prior_shader round="1">', request)
        self.assertIn("ROUND ONE CODE", request)
        self.assertIn('<prior_shader round="2">', request)
        self.assertIn("ROUND TWO CODE", request)
        self.assertNotIn("<previous_shader>", request)
        self.assertIn("newest code is best", request)


if __name__ == "__main__":
    unittest.main()
