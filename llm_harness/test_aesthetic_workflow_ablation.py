"""Tests for the controlled five-workflow beauty ablation runner."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from aesthetic_workflow_ablation import (
    AESTHETIC_AXES,
    _build_report,
    _candidate_sheet,
    _judging_complete,
    _load_reusable_aesthetic_ranking,
    _selection_diagnostic,
    _validate_aesthetic_result,
    _workflow_diagnostics,
)


class AestheticWorkflowAblationTests(unittest.TestCase):
    def test_candidate_sheet_is_blinded_deterministic_and_complete(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            candidates = []
            for index in range(5):
                image = root / f"image_{index}.png"
                Image.new("RGB", (64, 64), (index * 20, 30, 40)).save(image)
                candidates.append(
                    {
                        "key": f"method_{index}",
                        "label": f"Method {index}",
                        "image_path": str(image),
                    }
                )
            first = _candidate_sheet(
                candidates,
                root / "first.png",
                image_size=64,
            )
            second = _candidate_sheet(
                list(reversed(candidates)),
                root / "second.png",
                image_size=64,
            )
            self.assertEqual(first, second)
            self.assertEqual(set(first), {f"candidate_{i:02d}" for i in range(1, 6)})
            self.assertEqual(
                (root / "first.png").read_bytes(),
                (root / "second.png").read_bytes(),
            )

    def test_candidate_sheet_uses_submitted_not_oracle_image(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            submitted = root / "submitted.png"
            oracle = root / "oracle.png"
            Image.new("RGB", (64, 64), (200, 10, 20)).save(submitted)
            Image.new("RGB", (64, 64), (10, 20, 200)).save(oracle)
            sheet_path = root / "sheet.png"

            _candidate_sheet(
                [
                    {
                        "key": "method",
                        "label": "Method",
                        "image_path": str(submitted),
                        "oracle_best": {"image_path": str(oracle)},
                    }
                ],
                sheet_path,
                image_size=64,
            )

            sheet = Image.open(sheet_path).convert("RGB")
            self.assertEqual(sheet.getpixel((9, 35)), (200, 10, 20))

    def test_aesthetic_result_requires_every_axis_and_candidate(self):
        candidate_ids = {"candidate_01", "candidate_02"}
        records = {
            candidate_id: {
                **{axis: 70 for axis in AESTHETIC_AXES},
                "evidence": "The upper-right focal edge and central silhouette remain specific.",
                "critical_failure": "The lower coat is still too mechanically regular.",
            }
            for candidate_id in candidate_ids
        }
        valid = {
            "ranking": ["candidate_02", "candidate_01"],
            "winner": "candidate_02",
            "candidates": records,
        }
        _validate_aesthetic_result(valid, candidate_ids)
        invalid = {**valid, "winner": "candidate_01"}
        with self.assertRaisesRegex(ValueError, "winner"):
            _validate_aesthetic_result(invalid, candidate_ids)

    def test_reusable_ranking_fails_closed_when_candidates_change(self):
        with tempfile.TemporaryDirectory() as temporary:
            ranking_path = Path(temporary) / "ranking.json"
            record = {
                **{axis: 70 for axis in AESTHETIC_AXES},
                "evidence": (
                    "The upper focal edge and central silhouette remain specific."
                ),
                "critical_failure": "The lower coat remains too mechanically regular.",
            }
            ranking_path.write_text(
                json.dumps(
                    {
                        "ranking": ["candidate_01"],
                        "winner": "candidate_01",
                        "candidates": {"candidate_01": record},
                        "candidate_map": {
                            "candidate_01": {"key": "original"}
                        },
                    }
                ),
                encoding="utf-8",
            )
            loaded = _load_reusable_aesthetic_ranking(
                ranking_path,
                [{"key": "original"}],
            )
            self.assertEqual(loaded["winner"], "candidate_01")
            with self.assertRaisesRegex(ValueError, "does not match"):
                _load_reusable_aesthetic_ranking(
                    ranking_path,
                    [{"key": "replacement"}],
                )

    def test_judging_complete_covers_every_successful_final(self):
        result = {
            "submitted": True,
            "state": {
                "events": [
                    {
                        "type": "render_shader",
                        "ok": True,
                        "stage": "final",
                    },
                    {
                        "type": "render_shader",
                        "ok": True,
                        "stage": "study",
                    },
                ]
            },
            "render_judges": [{"judge_model": "cli/codex:gpt-5.5:high"}],
        }
        self.assertTrue(
            _judging_complete(result, "cli/codex:gpt-5.5:high")
        )
        result["render_judges"] = []
        self.assertFalse(
            _judging_complete(result, "cli/codex:gpt-5.5:high")
        )

    def test_selection_diagnostic_uses_only_scored_successful_finals(self):
        with tempfile.TemporaryDirectory() as temporary:
            run_dir = Path(temporary)
            renders = run_dir / "renders"
            renders.mkdir()
            for render_call in (1, 2, 3, 4):
                Image.new("RGB", (32, 32), (render_call * 20, 0, 0)).save(
                    renders / f"render_{render_call:02d}.png"
                )
            Image.new("RGB", (32, 32), (40, 0, 0)).save(
                run_dir / "final_render.png"
            )
            (run_dir / "submission.json").write_text(
                '{"render_call": 2, "revision": 12}', encoding="utf-8"
            )
            result = {
                "judge": {
                    "render_call": 2,
                    "revision": 12,
                    "total": 320,
                    "scores": [60, 70, 60, 70, 60],
                },
                "state": {
                    "events": [
                        {
                            "type": "render_shader",
                            "ok": True,
                            "stage": "study",
                            "render_call": 1,
                            "revision": 11,
                        },
                        {
                            "type": "render_shader",
                            "ok": True,
                            "stage": "final",
                            "render_call": 2,
                            "revision": 12,
                        },
                        {
                            "type": "render_shader",
                            "ok": True,
                            "stage": "final",
                            "render_call": 3,
                            "revision": 13,
                        },
                        {
                            "type": "render_shader",
                            "ok": False,
                            "stage": "final",
                            "render_call": 4,
                            "revision": 14,
                        },
                        {
                            "type": "render_shader",
                            "ok": True,
                            "stage": "final",
                            "render_call": 5,
                            "revision": 15,
                        },
                    ]
                },
                "render_judges": [
                    {"render_call": 1, "revision": 11, "total": 500},
                    {
                        "render_call": 2,
                        "revision": 12,
                        "total": 320,
                        "scores": [60, 70, 60, 70, 60],
                    },
                    {
                        "render_call": 3,
                        "revision": 13,
                        "total": 345,
                        "scores": [65, 75, 65, 75, 65],
                    },
                    {"render_call": 4, "revision": 14, "total": 499},
                    {"render_call": 5, "revision": 15, "total": 490},
                ],
            }

            diagnostic = _selection_diagnostic(run_dir, result)

            self.assertEqual(diagnostic["submitted"]["revision"], 12)
            self.assertEqual(diagnostic["submitted"]["total"], 320)
            self.assertEqual(diagnostic["oracle_best"]["revision"], 13)
            self.assertEqual(diagnostic["oracle_best"]["render_call"], 3)
            self.assertEqual(diagnostic["oracle_best"]["total"], 345)
            self.assertEqual(diagnostic["selection_gap"], 25.0)

    def test_workflow_diagnostics_excludes_historical_controls(self):
        workflow = {
            "key": "workflow",
            "run_id": "run",
            "label": "Workflow",
            "control": False,
            "submitted": {"revision": 2, "total": 300},
            "oracle_best": {"revision": 3, "total": 330},
            "selection_gap": 30.0,
        }
        control = {
            "key": "control",
            "run_id": "old-run",
            "label": "Control",
            "control": True,
        }

        diagnostics = _workflow_diagnostics([workflow, control])

        self.assertEqual(set(diagnostics), {"workflow"})
        self.assertEqual(diagnostics["workflow"]["submitted"]["revision"], 2)
        self.assertEqual(
            diagnostics["workflow"]["oracle_best"]["revision"], 3
        )

    def test_report_combines_benchmark_and_blinded_aesthetic_evidence(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            image = root / "final.png"
            oracle_image = root / "oracle.png"
            report = root / "trace.html"
            Image.new("RGB", (64, 64), (20, 30, 40)).save(image)
            Image.new("RGB", (64, 64), (50, 60, 70)).save(oracle_image)
            report.write_text("trace", encoding="utf-8")
            candidate = {
                "key": "method",
                "label": "Method",
                "run_id": "run",
                "hypothesis": "Beauty reflection improves coherence.",
                "control": False,
                "image_path": str(image),
                "report_path": str(report),
                "benchmark_total": 321,
                "benchmark_scores": [60, 70, 61, 75, 55],
                "render_calls": 14,
                "submitted": {
                    "image_path": str(image),
                    "render_call": 2,
                    "revision": 2,
                    "total": 321,
                    "scores": [60, 70, 61, 75, 55],
                },
                "oracle_best": {
                    "image_path": str(oracle_image),
                    "render_call": 3,
                    "revision": 3,
                    "total": 336,
                    "scores": [64, 74, 65, 77, 56],
                },
                "selection_gap": 15.0,
            }
            aesthetic_record = {
                **{axis: 80 for axis in AESTHETIC_AXES},
                "evidence": "The centered gesture and upper focal shape read clearly.",
                "critical_failure": "The lower edge remains slightly generic.",
            }
            aesthetic = {
                "ranking": ["candidate_01"],
                "candidate_map": {"candidate_01": candidate},
                "candidates": {"candidate_01": aesthetic_record},
                "selector_model": "judge",
                "overall_evidence": "The method has the strongest whole-image read.",
            }
            output = _build_report(root, [candidate], aesthetic)
            rendered = output.read_text(encoding="utf-8")
            self.assertIn("321 / 500", rendered)
            self.assertIn("336 / 500", rendered)
            self.assertIn("Oracle-best final · revision 3", rendered)
            self.assertIn("ranked submitted outputs only", rendered)
            self.assertIn("+15 points", rendered)
            self.assertIn("80.0", rendered)
            self.assertIn("strongest whole-image read", rendered)


if __name__ == "__main__":
    unittest.main()
