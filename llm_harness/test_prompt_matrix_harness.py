import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from prompt_matrix_harness import PromptMatrixHarness, build_trial_specs


class PromptMatrixHarnessTests(unittest.TestCase):
    def test_trial_plan_is_full_cross_product_with_unique_ids(self):
        specs = build_trial_specs(
            "matrix-one", ["baseline", "scratchpad-v1"], trials=3
        )
        self.assertEqual(len(specs), 6)
        self.assertEqual(
            [(spec.profile, spec.trial) for spec in specs],
            [
                ("baseline", 1),
                ("baseline", 2),
                ("baseline", 3),
                ("scratchpad-v1", 1),
                ("scratchpad-v1", 2),
                ("scratchpad-v1", 3),
            ],
        )
        self.assertEqual(len({spec.run_id for spec in specs}), 6)

    def test_trial_count_must_be_positive(self):
        with self.assertRaises(ValueError):
            build_trial_specs("matrix-one", ["baseline"], trials=0)

    def test_visual_report_groups_methods_by_trial_and_round(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            harness = object.__new__(PromptMatrixHarness)
            harness.run_id = "matrix-one"
            harness.output_root = root / "output"
            harness.run_dir = harness.output_root / harness.run_id
            harness.run_dir.mkdir(parents=True)
            harness.profiles = ["baseline", "scratchpad-v1"]
            harness.problems = ["reproduce_image_andrew_pons"]
            harness.trials = 1
            harness.rounds = 2

            observations = []
            for profile_index, profile in enumerate(harness.profiles):
                trajectory = [300 + profile_index, 320 + profile_index]
                observations.append(
                    {
                        "trial": 1,
                        "problem": harness.problems[0],
                        "profile": profile,
                        "trajectory": trajectory,
                    }
                )
                for round_number in (1, 2):
                    round_dir = harness._round_dir(
                        profile, 1, harness.problems[0], round_number
                    )
                    image_path = round_dir / "artifacts" / "result.png"
                    image_path.parent.mkdir(parents=True)
                    Image.new("RGB", (8, 8), "blue").save(image_path)
                    (round_dir / "round_result.json").write_text(
                        json.dumps({"image_path": str(image_path)})
                    )

            report_html = harness._build_trial_grids_html(observations)
            self.assertIn('data-trial-grid="1"', report_html)
            self.assertEqual(report_html.count("data-method-row"), 2)
            self.assertEqual(report_html.count('data-round="1"'), 2)
            self.assertEqual(report_html.count('data-round="2"'), 2)
            self.assertIn("Round 1", report_html)
            self.assertIn("320 / 500", report_html)


if __name__ == "__main__":
    unittest.main()
