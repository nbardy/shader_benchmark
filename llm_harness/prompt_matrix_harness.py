#!/usr/bin/env python3
"""Repeated prompt-profile ablations with independent trials and N revisions."""

from __future__ import annotations

import argparse
import asyncio
import html
import json
import os
import statistics
import uuid
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Optional, Sequence

from PIL import Image, ImageDraw, ImageFont

from iterative_shader_harness import (
    HISTORY_CRITIQUE_LOOP_STRATEGY,
    LATEST_LOOP_STRATEGY,
    LOOP_STRATEGIES,
    IterativeShaderHarness,
    validate_loop_strategy,
)
from llm_client import generation_isolation_metadata
from prompt_profiles import (
    AMBITIOUS_3D_PROFILE,
    BASELINE_PROFILE,
    SCRATCHPAD_ART_DIRECTION_AMBITIOUS_3D_PROFILE,
    SCRATCHPAD_ART_DIRECTION_PROFILE,
    SCRATCHPAD_PROFILE,
    prompt_profile_choices,
)


DEFAULT_ABLATION_PROFILES = (
    BASELINE_PROFILE,
    SCRATCHPAD_PROFILE,
    SCRATCHPAD_ART_DIRECTION_PROFILE,
    AMBITIOUS_3D_PROFILE,
    SCRATCHPAD_ART_DIRECTION_AMBITIOUS_3D_PROFILE,
)


def _read_json(path: Path) -> Dict[str, Any]:
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def _write_json(path: Path, value: Dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True))


def _safe(value: str) -> str:
    return value.replace("/", "_").replace(":", "_").replace("-", "_")


@dataclass(frozen=True)
class TrialSpec:
    profile: str
    trial: int
    run_id: str


def build_trial_specs(
    matrix_run_id: str, profiles: Sequence[str], trials: int
) -> List[TrialSpec]:
    if trials < 1:
        raise ValueError("trials must be at least 1")
    return [
        TrialSpec(
            profile=profile,
            trial=trial,
            run_id=f"{matrix_run_id}__{_safe(profile)}__trial_{trial:02d}",
        )
        for profile in profiles
        for trial in range(1, trials + 1)
    ]


class PromptMatrixHarness:
    """Run profile × independent-trial cells, each with an N-round chain."""

    def __init__(
        self,
        model: str,
        problems: Sequence[str],
        profiles: Sequence[str],
        trials: int,
        rounds: int,
        judge_models: Sequence[str],
        max_parallel: int = 3,
        run_id: Optional[str] = None,
        language: str = "wgsl",
        runtime: Optional[str] = None,
        skip_judge: bool = False,
        loop_strategy: str = LATEST_LOOP_STRATEGY,
    ):
        if trials < 1:
            raise ValueError("trials must be at least 1")
        if rounds < 1:
            raise ValueError("rounds must be at least 1")
        if max_parallel < 1:
            raise ValueError("max_parallel must be at least 1")

        self.model = model
        self.problems = list(problems)
        self.profiles = list(profiles)
        self.trials = trials
        self.rounds = rounds
        self.judge_models = list(judge_models)
        self.max_parallel = max_parallel
        self.language = language
        self.runtime = runtime
        self.skip_judge = skip_judge
        self.loop_strategy = validate_loop_strategy(loop_strategy)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        self.run_id = run_id or (
            f"{str(uuid.uuid4())[:8]}_prompt_matrix_{_safe(model)}_"
            f"{len(self.profiles)}p_{trials}t_{rounds}r_{timestamp}"
        )
        self.output_root = Path(__file__).parent / "benchmark_run_output"
        self.run_dir = (self.output_root / self.run_id).resolve()
        self.run_dir.mkdir(parents=True, exist_ok=True)
        self.config_path = self.run_dir / "config.json"
        self.state_path = self.run_dir / "matrix_state.json"
        self.specs = build_trial_specs(self.run_id, self.profiles, self.trials)
        self._save_config()

    def _save_config(self) -> None:
        existing = _read_json(self.config_path)
        config = {
            "run_id": self.run_id,
            "harness": "prompt-matrix-v1",
            "model": self.model,
            "problems": self.problems,
            "profiles": self.profiles,
            "trials": self.trials,
            "rounds": self.rounds,
            "judge_model": (
                self.judge_models[0] if self.judge_models else None
            ),
            "judge_models": self.judge_models,
            "max_parallel": self.max_parallel,
            "language": self.language,
            "runtime": self.runtime,
            "skip_judge": self.skip_judge,
            "loop_strategy": self.loop_strategy,
            "generation_isolation": generation_isolation_metadata(self.model),
            "judge_isolation": {
                model: generation_isolation_metadata(model)
                for model in self.judge_models
            },
            "independence_contract": {
                "trial": "fresh model session and fresh round-1 shader",
                "round": "dependent rewrite with prior shader and render",
            },
            "child_runs": [
                {
                    "profile": spec.profile,
                    "trial": spec.trial,
                    "run_id": spec.run_id,
                }
                for spec in self.specs
            ],
            "created": existing.get("created", datetime.now().isoformat()),
            "last_updated": datetime.now().isoformat(),
        }
        _write_json(self.config_path, config)

    async def _run_trial(
        self, spec: TrialSpec, semaphore: asyncio.Semaphore
    ) -> Dict[str, Any]:
        async with semaphore:
            print(
                f"\n🧪 {spec.profile} · independent trial "
                f"{spec.trial}/{self.trials}"
            )
            harness = IterativeShaderHarness(
                model=self.model,
                problems=self.problems,
                rounds=self.rounds,
                judge_models=self.judge_models,
                prompt_profile=spec.profile,
                run_id=spec.run_id,
                language=self.language,
                runtime=self.runtime,
                skip_judge=self.skip_judge,
                loop_strategy=self.loop_strategy,
            )
            try:
                report = await harness.run()
                return {
                    "profile": spec.profile,
                    "trial": spec.trial,
                    "run_id": spec.run_id,
                    "status": "complete",
                    "report": str(report),
                }
            except Exception as exc:
                return {
                    "profile": spec.profile,
                    "trial": spec.trial,
                    "run_id": spec.run_id,
                    "status": "failed",
                    "error": str(exc),
                }

    def _trial_observations(
        self, spec: TrialSpec
    ) -> Iterable[Dict[str, Any]]:
        child_dir = self.output_root / spec.run_id
        results_dir = child_dir / "results"
        if not results_dir.exists():
            return
        for problem_dir in sorted(results_dir.iterdir()):
            if not problem_dir.is_dir():
                continue
            problem = problem_dir.name.split("_", 1)[-1]
            round_dirs = [
                problem_dir / f"round_{number:02d}"
                for number in range(1, self.rounds + 1)
            ]
            rounds = [
                _read_json(round_dir / "round_result.json")
                for round_dir in round_dirs
            ]
            totals: List[Optional[int]] = [
                self._preferred_total(state, round_dir)
                for state, round_dir in zip(rounds, round_dirs)
            ]
            valid_totals = [score for score in totals if score is not None]
            yield {
                "profile": spec.profile,
                "trial": spec.trial,
                "run_id": spec.run_id,
                "problem": problem,
                "trajectory": totals,
                "final": totals[-1],
                "best": max(valid_totals) if valid_totals else None,
                "completed_rounds": sum(
                    state.get("status") == "complete" for state in rounds
                ),
            }

    @staticmethod
    def _preferred_total(
        state: Dict[str, Any], round_dir: Path
    ) -> Optional[int]:
        corrected = _read_json(
            round_dir / "fixed_rubric_judge" / "results.json"
        )
        scores = corrected.get("scores")
        if (
            isinstance(scores, list)
            and len(scores) == 5
            and all(isinstance(score, (int, float)) for score in scores)
        ):
            return int(sum(scores))
        if state.get("judge_complete"):
            return int(state.get("total_score", 0))
        return None

    @staticmethod
    def _mean(values: Sequence[int]) -> Optional[float]:
        return statistics.mean(values) if values else None

    @staticmethod
    def _stdev(values: Sequence[int]) -> Optional[float]:
        return statistics.stdev(values) if len(values) > 1 else 0.0

    def _round_dir(
        self,
        profile: str,
        trial: int,
        problem: str,
        round_number: int,
    ) -> Path:
        child_run = (
            f"{self.run_id}__{_safe(profile)}__trial_{trial:02d}"
        )
        return (
            self.output_root
            / child_run
            / "results"
            / f"000_{problem}"
            / f"round_{round_number:02d}"
        )

    def _relative_asset(self, path: Path) -> str:
        return os.path.relpath(path.resolve(), self.run_dir)

    def _build_trial_grids_html(
        self, observations: Sequence[Dict[str, Any]]
    ) -> str:
        observation_lookup = {
            (row["trial"], row["problem"], row["profile"]): row
            for row in observations
        }
        sections: List[str] = []
        for trial in range(1, self.trials + 1):
            problem_grids: List[str] = []
            for problem in self.problems:
                reference = (
                    Path(__file__).parent.parent
                    / "problems"
                    / "base_set"
                    / problem
                    / "reference.png"
                )
                reference_html = (
                    f'<img src="{html.escape(self._relative_asset(reference))}" '
                    f'alt="{html.escape(problem)} target reference">'
                    if reference.exists()
                    else '<div class="missing-render">No reference</div>'
                )
                method_rows: List[str] = []
                for profile in self.profiles:
                    observation = observation_lookup.get(
                        (trial, problem, profile), {}
                    )
                    trajectory = observation.get("trajectory", [])
                    child_report = (
                        Path("..")
                        / (
                            f"{self.run_id}__{_safe(profile)}__"
                            f"trial_{trial:02d}"
                        )
                        / "benchmark_report.html"
                    )
                    round_cells: List[str] = []
                    for round_index in range(self.rounds):
                        round_number = round_index + 1
                        round_dir = self._round_dir(
                            profile, trial, problem, round_number
                        )
                        state = _read_json(round_dir / "round_result.json")
                        image_value = state.get("image_path")
                        image_path = Path(image_value) if image_value else None
                        if not image_path or not image_path.exists():
                            fallback = round_dir / "artifacts" / "result.png"
                            image_path = fallback if fallback.exists() else None
                        score = (
                            trajectory[round_index]
                            if round_index < len(trajectory)
                            else None
                        )
                        if image_path:
                            relative_image = html.escape(
                                self._relative_asset(image_path)
                            )
                            image_html = (
                                f'<a href="{relative_image}">'
                                f'<img src="{relative_image}" '
                                f'alt="{html.escape(profile)} trial {trial} '
                                f'round {round_number} render"></a>'
                            )
                            status_class = ""
                            status_text = (
                                f"{score} / 500"
                                if score is not None
                                else "unscored"
                            )
                        else:
                            image_html = (
                                '<div class="missing-render">RENDER FAIL</div>'
                            )
                            status_class = " failure"
                            status_text = "render fail"
                        round_cells.append(
                            f'<div class="round-cell{status_class}" '
                            f'data-round="{round_number}">'
                            f"{image_html}"
                            f'<div class="cell-meta"><span>Round '
                            f'{round_number}</span><strong>{status_text}</strong>'
                            "</div></div>"
                        )
                    method_rows.append(
                        '<div class="method-row" data-method-row>'
                        '<div class="method-label">'
                        f'<code>{html.escape(profile)}</code>'
                        f'<a href="{html.escape(str(child_report))}">'
                        "open run</a></div>"
                        + "".join(round_cells)
                        + "</div>"
                    )

                round_headers = "".join(
                    f"<div>Round {round_number}</div>"
                    for round_number in range(1, self.rounds + 1)
                )
                problem_grids.append(
                    '<section class="problem-grid">'
                    '<div class="problem-heading">'
                    f'<div><p class="eyebrow">Problem</p><h3>'
                    f"{html.escape(problem)}</h3></div>"
                    f'<figure class="target-card">{reference_html}'
                    "<figcaption>Target reference</figcaption></figure></div>"
                    f'<div class="round-headers"><div>Method</div>'
                    f"{round_headers}</div>"
                    f'<div class="method-rows">{"".join(method_rows)}</div>'
                    "</section>"
                )
            sections.append(
                f'<section class="trial-grid" data-trial-grid="{trial}">'
                f'<div class="trial-heading"><span>Independent trial</span>'
                f"<h2>Trial {trial}</h2></div>"
                + "".join(problem_grids)
                + "</section>"
            )
        return "".join(sections)

    def _generate_report(self) -> Path:
        observations = [
            observation
            for spec in self.specs
            for observation in self._trial_observations(spec)
        ]
        summary_rows: List[str] = []
        markdown = [
            "# Prompt Ablation Matrix",
            "",
            f"- Model: `{self.model}`",
            f"- Problems: {', '.join(self.problems)}",
            f"- Independent trials per profile: {self.trials}",
            f"- Revision rounds per trial: {self.rounds}",
            f"- Loop strategy: `{self.loop_strategy}`",
            (
                "- Score source: corrected reconstruction rubric when "
                "available; original judge score otherwise"
            ),
            (
                "- Isolation: "
                f"`{generation_isolation_metadata(self.model)['protocol']}`"
            ),
            "",
            "| Profile | "
            + " | ".join(
                f"N={round_number} conditional / all-in (fails)"
                for round_number in range(1, self.rounds + 1)
            )
            + " | Final mean ± SD | Best mean ± SD |",
            "|---|"
            + "|".join("---:" for _ in range(self.rounds + 2))
            + "|",
        ]
        for profile in self.profiles:
            rows = [row for row in observations if row["profile"] == profile]
            finals = [row["final"] for row in rows if row["final"] is not None]
            bests = [row["best"] for row in rows if row["best"] is not None]
            final_text = (
                f"{self._mean(finals):.1f} ± {self._stdev(finals):.1f}"
                if finals
                else "—"
            )
            best_text = (
                f"{self._mean(bests):.1f} ± {self._stdev(bests):.1f}"
                if bests
                else "—"
            )
            round_cells: List[str] = []
            for round_index in range(self.rounds):
                values = [
                    row["trajectory"][round_index]
                    for row in rows
                    if row["trajectory"][round_index] is not None
                ]
                failures = len(rows) - len(values)
                valid_text = (
                    f"{self._mean(values):.1f}" if values else "—"
                )
                all_in = [
                    row["trajectory"][round_index] or 0 for row in rows
                ]
                round_cells.append(
                    f"{valid_text} / {self._mean(all_in):.1f} "
                    f"({failures}F)"
                )
            markdown.append(
                f"| `{profile}` | "
                + " | ".join(round_cells)
                + f" | {final_text} | {best_text} |"
            )
            summary_rows.append(
                "<tr>"
                f"<td><code>{html.escape(profile)}</code></td>"
                + "".join(f"<td>{cell}</td>" for cell in round_cells)
                + f"<td>{final_text}</td>"
                f"<td>{best_text}</td></tr>"
            )

        observation_lookup = {
            (row["trial"], row["problem"], row["profile"]): row
            for row in observations
        }
        for trial in range(1, self.trials + 1):
            markdown += ["", f"## Trial {trial}"]
            for problem in self.problems:
                if len(self.problems) > 1:
                    markdown += ["", f"### {problem}"]
                markdown += [
                    "",
                    "| Method | "
                    + " | ".join(
                        f"Round {round_number}"
                        for round_number in range(1, self.rounds + 1)
                    )
                    + " | Final | Best |",
                    "|---|"
                    + "|".join("---:" for _ in range(self.rounds + 2))
                    + "|",
                ]
                for profile in self.profiles:
                    row = observation_lookup.get(
                        (trial, problem, profile), {}
                    )
                    trajectory = row.get(
                        "trajectory", [None] * self.rounds
                    )
                    round_cells = [
                        str(score) if score is not None else "RENDER FAIL"
                        for score in trajectory
                    ]
                    markdown.append(
                        f"| `{profile}` | "
                        + " | ".join(round_cells)
                        + f" | {row.get('final') or '—'} | "
                        f"{row.get('best') or '—'} |"
                    )

        markdown_path = self.run_dir / "benchmark_report.md"
        markdown_path.write_text("\n".join(markdown))
        trial_grids_html = self._build_trial_grids_html(observations)
        html_path = self.run_dir / "benchmark_report.html"
        html_path.write_text(
            f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Shader prompt ablation matrix</title>
<style>
:root {{ color-scheme: dark; font-family: Inter,ui-sans-serif,system-ui; }}
body {{ margin:0; background:#0d1015; color:#e8edf5; }}
main {{ max-width:1760px; margin:auto; padding:32px; }}
table {{ width:100%; border-collapse:collapse; margin:20px 0 40px; }}
th,td {{ padding:12px; border-bottom:1px solid #293241; text-align:left; }}
th {{ color:#9fb7e9; }} code {{ color:#b5c9ff; }}
a {{ color:#83aaff; }} .meta {{ color:#9ba8ba; }}
.trial-grid {{ margin:48px 0 72px; }}
.trial-heading {{ border-left:4px solid #7ea6ff; padding-left:16px; margin-bottom:18px; }}
.trial-heading span,.eyebrow {{ color:#8d9bb0; font-size:12px; font-weight:700;
  letter-spacing:.12em; margin:0; text-transform:uppercase; }}
.trial-heading h2 {{ font-size:32px; margin:2px 0 0; }}
.problem-grid {{ background:#131821; border:1px solid #283142; border-radius:16px;
  overflow-x:auto; padding:18px; }}
.problem-heading {{ align-items:flex-start; display:flex; justify-content:space-between;
  gap:20px; margin-bottom:18px; min-width:1000px; }}
.problem-heading h3 {{ font-size:18px; margin:4px 0 0; }}
.target-card {{ align-items:center; display:flex; gap:10px; margin:0; }}
.target-card img,.target-card .missing-render {{ border-radius:8px; height:88px;
  object-fit:cover; width:88px; }}
.target-card figcaption {{ color:#9ba8ba; font-size:13px; }}
.round-headers,.method-row {{ display:grid; gap:12px;
  grid-template-columns:minmax(210px,.72fr) repeat({self.rounds},minmax(250px,1fr));
  min-width:1000px; }}
.round-headers {{ color:#9fb7e9; font-size:13px; font-weight:700;
  letter-spacing:.06em; padding:0 0 10px; text-transform:uppercase; }}
.round-headers>div:not(:first-child) {{ text-align:center; }}
.method-row {{ border-top:1px solid #283142; padding:14px 0; }}
.method-label {{ align-items:flex-start; display:flex; flex-direction:column;
  gap:10px; justify-content:center; padding:10px; }}
.method-label code {{ font-size:14px; overflow-wrap:anywhere; }}
.method-label a {{ font-size:12px; }}
.round-cell {{ background:#0d1118; border:1px solid #252f40; border-radius:10px;
  overflow:hidden; }}
.round-cell>a {{ display:block; }}
.round-cell img {{ aspect-ratio:1; display:block; object-fit:contain; width:100%; }}
.cell-meta {{ align-items:center; display:flex; font-size:12px;
  justify-content:space-between; padding:9px 11px; }}
.cell-meta span {{ color:#8d9bb0; }} .cell-meta strong {{ color:#dfe8f8; }}
.round-cell.failure {{ border-color:#653b43; }}
.round-cell.failure .cell-meta strong {{ color:#ff9ea8; }}
.missing-render {{ align-items:center; aspect-ratio:1; background:#21161a;
  color:#ff9ea8; display:flex; font-size:14px; font-weight:750;
  justify-content:center; letter-spacing:.08em; }}
@media(max-width:760px) {{ main {{ padding:18px; }} }}
</style></head><body><main>
<h1>Shader Prompt Ablation Matrix</h1>
<p class="meta">Model: {html.escape(self.model)} ·
{self.trials} independent trials/profile · {self.rounds} rounds/trial ·
loop: {html.escape(self.loop_strategy)} ·
isolation: {html.escape(generation_isolation_metadata(self.model)['protocol'])}</p>
<h2>Profile summary</h2>
<table><thead><tr><th>Profile</th>
{''.join(f'<th>N={round_number} conditional / all-in (fails)</th>' for round_number in range(1, self.rounds + 1))}
<th>Final mean ± SD</th>
<th>Best mean ± SD</th></tr></thead><tbody>{''.join(summary_rows)}</tbody></table>
<h2>Visual progression by trial</h2>
<p class="meta">Each grid is one independent trial. Methods run top-to-bottom;
revision rounds progress left-to-right.</p>
{trial_grids_html}
</main></body></html>"""
        )
        return html_path

    @staticmethod
    def _font(size: int) -> ImageFont.ImageFont:
        try:
            return ImageFont.truetype(
                "/System/Library/Fonts/Helvetica.ttc", size
            )
        except OSError:
            return ImageFont.load_default()

    @staticmethod
    def _fit_image(path: Optional[Path], size: int) -> Image.Image:
        cell = Image.new("RGB", (size, size), (20, 23, 29))
        if not path or not path.exists():
            draw = ImageDraw.Draw(cell)
            draw.text(
                (size // 2, size // 2),
                "RENDER FAIL",
                fill=(220, 105, 110),
                anchor="mm",
                font=PromptMatrixHarness._font(20),
            )
            return cell
        with Image.open(path) as source:
            image = source.convert("RGB")
            image.thumbnail((size, size), Image.Resampling.LANCZOS)
            cell.paste(
                image,
                ((size - image.width) // 2, (size - image.height) // 2),
            )
        return cell

    def _generate_visual_atlases(self) -> List[Path]:
        """Create one score-blind profile × trial atlas per revision round."""
        tile = 300
        row_label_width = 340
        header_height = 42
        gap = 10
        width = row_label_width + (self.trials + 1) * (tile + gap) + gap
        height = header_height + len(self.profiles) * (tile + gap) + gap
        reference_path = (
            Path(__file__).parent.parent
            / "problems"
            / "base_set"
            / self.problems[0]
            / "reference.png"
        )
        paths: List[Path] = []
        for round_number in range(1, self.rounds + 1):
            sheet = Image.new("RGB", (width, height), (12, 15, 20))
            draw = ImageDraw.Draw(sheet)
            draw.text(
                (row_label_width + 8, 10),
                "TARGET",
                fill=(225, 230, 240),
                font=self._font(18),
            )
            for trial in range(1, self.trials + 1):
                x = row_label_width + (trial) * (tile + gap) + 8
                draw.text(
                    (x, 10),
                    f"TRIAL {trial}",
                    fill=(225, 230, 240),
                    font=self._font(18),
                )

            for profile_index, profile in enumerate(self.profiles):
                y = header_height + profile_index * (tile + gap)
                draw.text(
                    (14, y + 12),
                    profile,
                    fill=(180, 202, 245),
                    font=self._font(17),
                )
                draw.text(
                    (14, y + 42),
                    f"round {round_number}",
                    fill=(145, 154, 170),
                    font=self._font(15),
                )
                sheet.paste(
                    self._fit_image(reference_path, tile),
                    (row_label_width, y),
                )
                for trial in range(1, self.trials + 1):
                    child = self.output_root / (
                        f"{self.run_id}__{_safe(profile)}__trial_{trial:02d}"
                    )
                    state_path = (
                        child
                        / "results"
                        / f"000_{self.problems[0]}"
                        / f"round_{round_number:02d}"
                        / "round_result.json"
                    )
                    state = _read_json(state_path)
                    image_value = state.get("image_path")
                    image_path = Path(image_value) if image_value else None
                    x = row_label_width + trial * (tile + gap)
                    sheet.paste(self._fit_image(image_path, tile), (x, y))
            path = self.run_dir / f"visual_round_{round_number}_blind.png"
            sheet.save(path)
            paths.append(path)
        return paths

    async def run(self) -> Path:
        print(f"🧫 Prompt matrix: {self.model}")
        print(
            f"   {len(self.profiles)} profiles × {self.trials} trials × "
            f"{self.rounds} rounds = "
            f"{len(self.profiles) * self.trials * self.rounds} generations"
        )
        print(
            "   Trial = independent start; round = dependent visual rewrite"
        )
        semaphore = asyncio.Semaphore(self.max_parallel)
        results = await asyncio.gather(
            *(self._run_trial(spec, semaphore) for spec in self.specs)
        )
        _write_json(
            self.state_path,
            {
                "run_id": self.run_id,
                "updated": datetime.now().isoformat(),
                "children": results,
            },
        )
        report = self._generate_report()
        config = _read_json(self.config_path)
        config["completed"] = datetime.now().isoformat()
        config["report"] = str(report)
        _write_json(self.config_path, config)
        print(f"\n✅ Matrix report: {report}")
        return report


def _resolve_resume(value: str) -> Path:
    candidate = Path(value)
    if candidate.exists():
        return candidate.resolve()
    candidate = Path(__file__).parent / "benchmark_run_output" / value
    if candidate.exists():
        return candidate.resolve()
    raise FileNotFoundError(f"Matrix run not found: {value}")


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Run prompt-profile ablations with independent trials and "
            "dependent visual revision rounds."
        )
    )
    parser.add_argument("--model")
    parser.add_argument("--problems", nargs="+")
    parser.add_argument(
        "--profiles", nargs="+", choices=prompt_profile_choices()
    )
    parser.add_argument("--trials", type=int, default=3)
    parser.add_argument("--rounds", type=int, default=3)
    parser.add_argument("--judge-model", nargs="+")
    parser.add_argument("--max-parallel", type=int, default=3)
    parser.add_argument(
        "--loop-strategy",
        choices=LOOP_STRATEGIES,
        default=None,
    )
    parser.add_argument(
        "--language",
        choices=["wgsl", "glsl", "shadertoy", "hlsl_unity"],
        default="wgsl",
    )
    parser.add_argument("--runtime", choices=["wgpu", "shadertoy"])
    parser.add_argument("--skip-judge", action="store_true")
    parser.add_argument("--run-id")
    parser.add_argument("--resume")
    args = parser.parse_args(argv)

    if args.resume:
        run_dir = _resolve_resume(args.resume)
        config = _read_json(run_dir / "config.json")
        if config.get("harness") != "prompt-matrix-v1":
            parser.error("Selected run is not a prompt-matrix-v1 run")
        harness = PromptMatrixHarness(
            model=config["model"],
            problems=config["problems"],
            profiles=config["profiles"],
            trials=int(config["trials"]),
            rounds=int(config["rounds"]),
            judge_models=(
                args.judge_model
                or config.get("judge_models")
                or [config["judge_model"]]
            ),
            max_parallel=args.max_parallel or config.get("max_parallel", 3),
            run_id=run_dir.name,
            language=config.get("language", "wgsl"),
            runtime=config.get("runtime"),
            skip_judge=args.skip_judge or config.get("skip_judge", False),
            loop_strategy=config.get(
                "loop_strategy", LATEST_LOOP_STRATEGY
            ),
        )
    else:
        if not args.model:
            parser.error("--model is required")
        if not args.problems:
            parser.error("--problems is required")
        harness = PromptMatrixHarness(
            model=args.model,
            problems=args.problems,
            profiles=args.profiles or DEFAULT_ABLATION_PROFILES,
            trials=args.trials,
            rounds=args.rounds,
            judge_models=args.judge_model
            or ["cli/codex:gpt-5.5:high"],
            max_parallel=args.max_parallel,
            run_id=args.run_id,
            language=args.language,
            runtime=args.runtime,
            skip_judge=args.skip_judge,
            loop_strategy=(
                args.loop_strategy or LATEST_LOOP_STRATEGY
            ),
        )

    report = asyncio.run(harness.run())
    print(f"📋 Report: {report}")
    print(
        f"🔄 Resume: python prompt_matrix_harness.py --resume {harness.run_id}"
    )


if __name__ == "__main__":
    main()
