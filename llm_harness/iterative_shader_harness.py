#!/usr/bin/env python3
"""N-round shader generation, rendering, visual feedback, and revision."""

from __future__ import annotations

import argparse
import asyncio
import html
import json
import re
import sys
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from PIL import Image, ImageDraw, ImageOps

from judge import EvaluationContext, Judge
from judge_panel import mean_scores
from language_specs import get_language_spec
from llm_client import LLMClient, generation_isolation_metadata
from prompt_loader import PromptLoader
from prompt_profiles import (
    AMBITIOUS_3D_PROFILE,
    BASELINE_PROFILE,
    prompt_profile_choices,
    validate_prompt_profile,
)
from runtimes import default_runtime_for_language, get_runtime
from shader_parser import ShaderParser
from test_runner import TestRunner

LATEST_LOOP_STRATEGY = "latest-v1"
HISTORY_CRITIQUE_LOOP_STRATEGY = "history-critique-v2"
HISTORY_CODE_CRITIQUE_LOOP_STRATEGY = "history-code-critique-v3"
LOOP_STRATEGIES = (
    LATEST_LOOP_STRATEGY,
    HISTORY_CRITIQUE_LOOP_STRATEGY,
    HISTORY_CODE_CRITIQUE_LOOP_STRATEGY,
)


def validate_loop_strategy(value: str) -> str:
    if value not in LOOP_STRATEGIES:
        raise ValueError(
            f"Unknown loop strategy {value!r}; choose one of: "
            + ", ".join(LOOP_STRATEGIES)
        )
    return value


def build_revision_request(
    original_request: str,
    round_number: int,
    total_rounds: int,
    previous_shader: str,
    previous_render_available: bool,
    reference_available: bool,
    previous_error: Optional[str] = None,
    loop_strategy: str = LATEST_LOOP_STRATEGY,
    history_render_count: int = 0,
    shader_history: Optional[List[Tuple[int, str]]] = None,
) -> str:
    """Create the task-specific feedback contract for rounds after the first."""
    if round_number <= 1:
        return original_request

    loop_strategy = validate_loop_strategy(loop_strategy)
    if (
        loop_strategy
        in (
            HISTORY_CRITIQUE_LOOP_STRATEGY,
            HISTORY_CODE_CRITIQUE_LOOP_STRATEGY,
        )
        and history_render_count
        and reference_available
    ):
        image_context = (
            "The attached diagnostic history sheet shows the TARGET REFERENCE "
            f"followed by {history_render_count} prior render(s), labeled by "
            "round. Compare all of them. Choose the strongest prior render as "
            "the visual anchor; the newest render is not automatically best."
        )
    elif previous_render_available and reference_available:
        image_context = (
            "The attached diagnostic image is a labeled two-panel contact sheet: "
            "TARGET REFERENCE is on the left and the CURRENT RENDER from the "
            "previous round is on the right."
        )
    elif previous_render_available:
        image_context = (
            "The attached diagnostic image is the CURRENT RENDER from the "
            "previous round."
        )
    elif reference_available:
        image_context = (
            "The attached image is the TARGET REFERENCE. The previous shader "
            "did not produce a usable render."
        )
    else:
        image_context = "No usable render or reference image is attached."

    error_section = ""
    if previous_error:
        error_section = f"""

The previous attempt failed to render. Diagnose and fix this exact failure
before making aesthetic improvements:
<render_error>
{previous_error}
</render_error>
"""

    code_history_section = f"""
The exact shader used for the previous render follows:
<previous_shader>
{previous_shader}
</previous_shader>
"""
    if (
        loop_strategy == HISTORY_CODE_CRITIQUE_LOOP_STRATEGY
        and shader_history
    ):
        bounded_history = shader_history[-3:]
        entries = "\n".join(
            f'<prior_shader round="{prior_round}">\n{shader}\n</prior_shader>'
            for prior_round, shader in bounded_history
        )
        code_history_section = f"""
The exact executed shaders for the visible prior rounds follow. Select the
strongest prior round as the code anchor, copy that implementation faithfully,
and make only the prioritized changes. Do not assume the newest code is best.
<shader_history>
{entries}
</shader_history>
"""

    return f"""{original_request}

ITERATIVE SHADER REVISION — ROUND {round_number} OF {total_rounds}
================================================================

{image_context}

Treat the visible render as evidence, not inspiration. Compare it against the
target and request, preserve what already works, and identify the three
highest-impact discrepancies. Revise geometry, camera, composition, depth,
lighting, material, color, and procedural detail where the evidence demands
it. Prefer meaningful structural changes over indiscriminate extra noise or
minor parameter churn.

Before rewriting, distinguish:
- PRESERVE: successful features that must survive this revision;
- CHANGE: at most three prioritized discrepancies, each tied to visible
  evidence and a concrete code-level intervention;
- REGRESSION CHECKS: properties from any stronger prior render that the new
  shader must not lose.

This is a rewrite round. Return a COMPLETE replacement shader, never a patch,
diff, abbreviated excerpt, or commentary-only answer. The next render will use
only the newly returned shader.
{error_section}

{code_history_section}
"""


def build_revision_output_contract(
    loop_strategy: str,
    round_number: int,
    prompt_profile: str,
) -> str:
    """Return the auditable critique contract appended after profile rules."""
    if (
        loop_strategy
        not in (
            HISTORY_CRITIQUE_LOOP_STRATEGY,
            HISTORY_CODE_CRITIQUE_LOOP_STRATEGY,
        )
        or round_number <= 1
    ):
        return ""
    planning_note = (
        "After this critique, retain any art-direction or scratchpad elements "
        f"required by the `{prompt_profile}` profile in their specified order, "
        "then return the complete <shader> element."
    )
    return f"""
ITERATIVE SELF-CRITIQUE OUTPUT CONTRACT
=======================================

Before any profile-specific planning and before the shader, return exactly one
compact public critique:

<revision_critique>
<best_prior_round>round number and why it is the strongest visual anchor</best_prior_round>
<comparison>specific target-versus-render evidence about silhouette, crop,
pose, proportions, depth, palette, material, lighting, and signature detail</comparison>
<preserve>the successful features that must not regress</preserve>
<change>at most three prioritized changes; for each, name the visible defect,
the concrete shader function/parameter/representation change, and expected
visual effect</change>
<regression_checks>observable checks the next render must pass</regression_checks>
</revision_critique>

Do not include private chain-of-thought. This is a concise, auditable production
decision record, capped at 450 words. {planning_note}
""".strip()


def extract_revision_critique(response: str) -> Optional[str]:
    match = re.search(
        r"<revision_critique>(.*?)</revision_critique>",
        response,
        re.DOTALL,
    )
    return match.group(1).strip() if match else None


def create_feedback_context(
    current_render: Path,
    output_path: Path,
    reference_image: Optional[Path] = None,
) -> Path:
    """Create the single labeled image supplied to the next model round."""
    return create_feedback_history(
        render_history=[(1, current_render)],
        output_path=output_path,
        reference_image=reference_image,
    )


def create_feedback_history(
    render_history: List[Tuple[int, Path]],
    output_path: Path,
    reference_image: Optional[Path] = None,
    max_prior_renders: int = 4,
) -> Path:
    """Create target + prior-render history without unbounded image growth."""
    selected = render_history[-max_prior_renders:]
    panel_count = len(selected) + (
        1 if reference_image and reference_image.exists() else 0
    )
    panel_size = min(768, max(384, 1536 // max(panel_count, 1)))
    header = 52
    panels: List[Tuple[str, Path]] = []
    if reference_image and reference_image.exists():
        panels.append(("TARGET REFERENCE", reference_image))
    for index, (round_number, render_path) in enumerate(selected):
        label = (
            f"CURRENT RENDER — ROUND {round_number}"
            if index == len(selected) - 1
            else f"PRIOR RENDER — ROUND {round_number}"
        )
        panels.append((label, render_path))

    canvas = Image.new(
        "RGB", (panel_size * len(panels), panel_size + header), (18, 20, 24)
    )
    draw = ImageDraw.Draw(canvas)

    for index, (label, path) in enumerate(panels):
        with Image.open(path) as source:
            image = ImageOps.contain(
                source.convert("RGB"),
                (panel_size, panel_size),
                method=Image.Resampling.LANCZOS,
            )
        x0 = index * panel_size
        paste_x = x0 + (panel_size - image.width) // 2
        paste_y = header + (panel_size - image.height) // 2
        canvas.paste(image, (paste_x, paste_y))
        draw.rectangle((x0, 0, x0 + panel_size, header), fill=(28, 32, 39))
        draw.text((x0 + 18, 18), label, fill=(235, 239, 245))

    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path)
    return output_path.resolve()


def _write_json(path: Path, data: Dict[str, Any]) -> None:
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(json.dumps(data, indent=2, default=str))
    temp_path.replace(path)


def _read_json(path: Path) -> Dict[str, Any]:
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


class IterativeShaderHarness:
    def __init__(
        self,
        model: str,
        problems: List[str],
        rounds: int,
        judge_models: List[str],
        prompt_profile: str = AMBITIOUS_3D_PROFILE,
        run_id: Optional[str] = None,
        language: str = "wgsl",
        runtime: Optional[str] = None,
        skip_judge: bool = False,
        loop_strategy: str = LATEST_LOOP_STRATEGY,
    ):
        if rounds < 1:
            raise ValueError("rounds must be at least 1")

        self.model = model
        self.problems = list(problems)
        self.rounds = rounds
        self.judge_models = list(judge_models)
        self.prompt_profile = validate_prompt_profile(prompt_profile)
        self.loop_strategy = validate_loop_strategy(loop_strategy)
        self.language = language
        self.skip_judge = skip_judge
        self.language_spec = get_language_spec(language)
        self.runtime = (
            get_runtime(runtime)
            if runtime
            else default_runtime_for_language(self.language_spec)
        )

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe = model.replace("/", "_").replace(":", "_")
        profile_safe = self.prompt_profile.replace("-", "_")
        generated_run_id = (
            f"{str(uuid.uuid4())[:8]}_iterative_{model_safe}_"
            f"{profile_safe}_{self.loop_strategy.replace('-', '_')}_"
            f"{rounds}r_{timestamp}"
        )
        self.run_id = run_id or generated_run_id

        script_dir = Path(__file__).parent.absolute()
        self.problem_root = script_dir.parent / "problems" / "base_set"
        self.output_root = script_dir / "benchmark_run_output"
        self.run_dir = (self.output_root / self.run_id).resolve()
        self.results_dir = self.run_dir / "results"
        self.run_dir.mkdir(parents=True, exist_ok=True)
        self.results_dir.mkdir(parents=True, exist_ok=True)
        self.config_path = self.run_dir / "config.json"

        self.test_runner = TestRunner(
            language_spec=self.language_spec,
            runtime=self.runtime,
        )
        self._save_config()

    def _save_config(self) -> None:
        existing = _read_json(self.config_path)
        config = {
            "run_id": self.run_id,
            "harness": "iterative-shader-v1",
            "model": self.model,
            "judge_model": self.judge_models[0] if self.judge_models else None,
            "judge_models": self.judge_models,
            "prompt_profile": self.prompt_profile,
            "loop_strategy": self.loop_strategy,
            "generation_isolation": generation_isolation_metadata(self.model),
            "judge_isolation": {
                model: generation_isolation_metadata(model)
                for model in self.judge_models
            },
            "rounds": self.rounds,
            "problems": self.problems,
            "total_problems": len(self.problems),
            "language": self.language,
            "runtime": self.runtime.name,
            "skip_judge": self.skip_judge,
            "created": existing.get("created", datetime.now().isoformat()),
            "last_updated": datetime.now().isoformat(),
        }
        _write_json(self.config_path, config)

    def _problem_dir(self, problem_index: int, problem: str) -> Path:
        path = self.results_dir / f"{problem_index:03d}_{problem}"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @staticmethod
    def _round_dir(problem_dir: Path, round_number: int) -> Path:
        path = problem_dir / f"round_{round_number:02d}"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def _completed_round(
        self, problem_dir: Path, round_number: int
    ) -> Optional[Dict[str, Any]]:
        round_dir = self._round_dir(problem_dir, round_number)
        state = _read_json(round_dir / "round_result.json")
        if state.get("status") != "complete":
            return None
        shader_path = Path(state.get("shader_path", ""))
        if not shader_path.exists():
            return None
        if state.get("render_complete"):
            image_path = Path(state.get("image_path", ""))
            if not image_path.exists():
                return None
        return state

    @staticmethod
    def _find_shader(round_dir: Path) -> Optional[Path]:
        candidates = sorted((round_dir / "shaders").glob("*"))
        return candidates[0].resolve() if candidates else None

    async def _judge_round(
        self,
        problem_path: Path,
        round_dir: Path,
        result_image: Path,
        shader_path: Path,
    ) -> Tuple[List[int], Dict[str, List[int]], Dict[str, Any]]:
        if self.skip_judge or not self.judge_models:
            return [0, 0, 0, 0, 0], {}, {
                "cost": 0.0,
                "total_tokens": 0,
            }

        reference_image = problem_path / "reference.png"
        if not reference_image.exists():
            reference_image = None

        scores_by_judge: Dict[str, List[int]] = {}
        usages: List[Dict[str, Any]] = []
        for judge_model in self.judge_models:
            judge = Judge(judge_model=judge_model)
            context = EvaluationContext(
                critic_path=problem_path / "critic.txt",
                request_path=problem_path / "request.txt",
                result_image_path=result_image,
                save_dir=round_dir,
                code_path=shader_path,
                reference_image_path=reference_image,
            )
            scores, _, usage = await judge.evaluate_with_template(context)
            scores_by_judge[judge_model] = scores
            usages.append(usage)

        aggregate_usage = {
            "cost": sum(u.get("cost", 0.0) for u in usages),
            "total_tokens": sum(u.get("total_tokens", 0) for u in usages),
        }
        return (
            mean_scores(scores_by_judge) or [0, 0, 0, 0, 0],
            scores_by_judge,
            aggregate_usage,
        )

    async def _run_round(
        self,
        problem_path: Path,
        problem_dir: Path,
        round_number: int,
        original_request: str,
        previous_shader: Optional[str],
        previous_render: Optional[Path],
        previous_error: Optional[str],
        render_history: List[Tuple[int, Path]],
        shader_history: List[Tuple[int, str]],
    ) -> Dict[str, Any]:
        round_dir = self._round_dir(problem_dir, round_number)
        state_path = round_dir / "round_result.json"
        state = _read_json(state_path)

        reference_image = problem_path / "reference.png"
        if not reference_image.exists():
            reference_image = None

        revision_request = build_revision_request(
            original_request=original_request,
            round_number=round_number,
            total_rounds=self.rounds,
            previous_shader=previous_shader or "",
            previous_render_available=bool(
                previous_render and previous_render.exists()
            ),
            reference_available=bool(reference_image),
            previous_error=previous_error,
            loop_strategy=self.loop_strategy,
            history_render_count=len(render_history),
            shader_history=shader_history,
        )

        context_image: Optional[Path] = reference_image
        if round_number > 1 and previous_render and previous_render.exists():
            if self.loop_strategy in (
                HISTORY_CRITIQUE_LOOP_STRATEGY,
                HISTORY_CODE_CRITIQUE_LOOP_STRATEGY,
            ):
                context_image = create_feedback_history(
                    render_history=render_history,
                    reference_image=reference_image,
                    output_path=round_dir / "feedback_context.png",
                )
            else:
                context_image = create_feedback_context(
                    current_render=previous_render,
                    reference_image=reference_image,
                    output_path=round_dir / "feedback_context.png",
                )

        llm_client = LLMClient(language_spec=self.language_spec)
        post_profile_instructions = build_revision_output_contract(
            self.loop_strategy, round_number, self.prompt_profile
        )

        if not state.get("generation_complete"):
            full_prompt = llm_client.build_generation_prompt(
                revision_request,
                self.prompt_profile,
                post_profile_instructions,
            )
            (round_dir / "llm_request.txt").write_text(full_prompt)
            try:
                response, generation_usage = await llm_client.generate_shaders(
                    self.model,
                    revision_request,
                    str(context_image) if context_image else None,
                    prompt_profile=self.prompt_profile,
                    post_profile_instructions=post_profile_instructions,
                )
                (round_dir / "llm_response.txt").write_text(response)
                state.update(
                    {
                        "round": round_number,
                        "status": "generated",
                        "generation_complete": True,
                        "generation_usage": generation_usage,
                        "feedback_context_path": (
                            str(context_image) if context_image else None
                        ),
                        "revision_critique": extract_revision_critique(response),
                    }
                )
                _write_json(state_path, state)
            except Exception as exc:
                state.update(
                    {
                        "round": round_number,
                        "status": "generation_failed",
                        "generation_complete": False,
                        "error": str(exc),
                    }
                )
                _write_json(state_path, state)
                raise

        response_path = round_dir / "llm_response.txt"
        response = response_path.read_text()
        shaders, main_rs = ShaderParser(
            language_spec=self.language_spec
        ).parse_response(response)

        if not state.get("render_complete"):
            self.test_runner.setup_test_files(round_dir, shaders, main_rs)
            shader_path = self._find_shader(round_dir)
            if not shader_path:
                raise RuntimeError("Generated response contained no shader file")
            try:
                result_image = await self.test_runner.render_shader(round_dir)
                # Render-time repairs may have changed the shader; always carry
                # the actual executed file into the next revision round.
                shader_path = self._find_shader(round_dir)
                state.update(
                    {
                        "status": "rendered",
                        "render_complete": True,
                        "image_path": str(result_image),
                        "shader_path": str(shader_path),
                        "render_error": None,
                    }
                )
                _write_json(state_path, state)
            except Exception as exc:
                shader_path = self._find_shader(round_dir)
                state.update(
                    {
                        "status": "render_failed",
                        "render_complete": False,
                        "shader_path": str(shader_path) if shader_path else None,
                        "render_error": str(exc),
                    }
                )
                _write_json(state_path, state)
                return state

        result_image = Path(state["image_path"])
        shader_path = Path(state["shader_path"])

        if not state.get("judge_complete") and not self.skip_judge:
            try:
                scores, scores_by_judge, judge_usage = await self._judge_round(
                    problem_path, round_dir, result_image, shader_path
                )
                state.update(
                    {
                        "scores": scores,
                        "total_score": sum(scores),
                        "scores_by_judge": scores_by_judge,
                        "judge_usage": judge_usage,
                        "judge_complete": True,
                    }
                )
                self.test_runner.save_results(
                    round_dir,
                    scores,
                    True,
                    generation_usage=state.get("generation_usage"),
                    judge_usage=judge_usage,
                    scores_by_judge=scores_by_judge,
                )
                _write_json(state_path, state)
            except Exception as exc:
                state.update(
                    {
                        "status": "judge_failed",
                        "judge_complete": False,
                        "judge_error": str(exc),
                    }
                )
                _write_json(state_path, state)
                raise
        elif self.skip_judge:
            state.update(
                {
                    "scores": [0, 0, 0, 0, 0],
                    "total_score": 0,
                    "scores_by_judge": {},
                    "judge_complete": False,
                }
            )

        state["status"] = "complete"
        _write_json(state_path, state)
        return state

    async def run_problem(
        self, problem_index: int, problem: str
    ) -> List[Dict[str, Any]]:
        problem_path = self.problem_root / problem
        if not problem_path.exists():
            raise FileNotFoundError(f"Problem not found: {problem_path}")

        original_request = PromptLoader().load_request_prompt(str(problem_path))
        problem_dir = self._problem_dir(problem_index, problem)
        round_states: List[Dict[str, Any]] = []
        previous_shader: Optional[str] = None
        previous_render: Optional[Path] = None
        previous_error: Optional[str] = None
        render_history: List[Tuple[int, Path]] = []
        shader_history: List[Tuple[int, str]] = []

        for round_number in range(1, self.rounds + 1):
            cached = self._completed_round(problem_dir, round_number)
            if cached:
                state = cached
                print(
                    f"✅ {problem} round {round_number}/{self.rounds} cached "
                    f"({state.get('total_score', 0)}/500)"
                )
            else:
                print(
                    f"\n🔁 {problem} — round {round_number}/{self.rounds} "
                    f"({self.prompt_profile})"
                )
                state = await self._run_round(
                    problem_path=problem_path,
                    problem_dir=problem_dir,
                    round_number=round_number,
                    original_request=original_request,
                    previous_shader=previous_shader,
                    previous_render=previous_render,
                    previous_error=previous_error,
                    render_history=render_history,
                    shader_history=shader_history,
                )

            round_states.append(state)
            shader_path_str = state.get("shader_path")
            if shader_path_str and Path(shader_path_str).exists():
                previous_shader = Path(shader_path_str).read_text()
                shader_history.append((round_number, previous_shader))

            if state.get("render_complete"):
                candidate = Path(state["image_path"])
                if candidate.exists():
                    previous_render = candidate
                    render_history.append((round_number, candidate))
                previous_error = None
                print(
                    f"   Rendered: {candidate} — "
                    f"{state.get('total_score', 0)}/500"
                )
            else:
                previous_error = state.get("render_error") or state.get("error")
                print(f"   Render failed: {previous_error}")

        return round_states

    def _generate_report(self, all_results: Dict[str, List[Dict[str, Any]]]) -> Path:
        markdown_lines = [
            "# Iterative Shader Harness Report",
            "",
            f"- Model: `{self.model}`",
            f"- Prompt profile: `{self.prompt_profile}`",
            f"- Loop strategy: `{self.loop_strategy}`",
            f"- Rounds: {self.rounds}",
            f"- Judges: {', '.join(self.judge_models) if self.judge_models else 'skipped'}",
            "",
        ]

        html_sections: List[str] = []
        for problem_index, problem in enumerate(self.problems):
            states = all_results.get(problem, [])
            markdown_lines += [f"## {problem}", ""]
            cards: List[str] = []
            for state in states:
                round_number = state.get("round", 0)
                total = state.get("total_score", 0)
                scores = state.get("scores") or [0, 0, 0, 0, 0]
                status = state.get("status", "unknown")
                image_path_str = state.get("image_path")
                image_rel = ""
                if image_path_str and Path(image_path_str).exists():
                    image_rel = str(
                        Path(image_path_str).resolve().relative_to(self.run_dir)
                    )
                    markdown_lines.append(
                        f"### Round {round_number}: {total}/500"
                    )
                    markdown_lines.append("")
                    markdown_lines.append(f"![Round {round_number}]({image_rel})")
                    markdown_lines.append("")
                else:
                    markdown_lines += [
                        f"### Round {round_number}: {status}",
                        "",
                    ]
                markdown_lines.append(
                    f"Scores: `{scores}` · Status: `{status}`"
                )
                markdown_lines.append("")

                image_html = (
                    f'<img src="{html.escape(image_rel)}" '
                    f'alt="{html.escape(problem)} round {round_number}">'
                    if image_rel
                    else '<div class="missing">No render</div>'
                )
                cards.append(
                    f"""
                    <article class="card">
                      <h3>Round {round_number} <span>{total}/500</span></h3>
                      {image_html}
                      <p>Scores: {html.escape(str(scores))}</p>
                      <p>Status: {html.escape(status)}</p>
                    </article>
                    """
                )
            html_sections.append(
                f"<section><h2>{html.escape(problem)}</h2>"
                f'<div class="rounds">{"".join(cards)}</div></section>'
            )

        markdown_path = self.run_dir / "benchmark_report.md"
        markdown_path.write_text("\n".join(markdown_lines))

        html_path = self.run_dir / "benchmark_report.html"
        html_path.write_text(
            f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Iterative Shader Harness — {html.escape(self.model)}</title>
<style>
  :root {{ color-scheme: dark; font-family: Inter, ui-sans-serif, system-ui; }}
  body {{ margin: 0; background: #0d1015; color: #e8edf5; }}
  main {{ max-width: 1500px; margin: auto; padding: 32px; }}
  header, section {{ margin-bottom: 32px; }}
  .meta {{ color: #9ba8ba; }}
  .rounds {{ display: grid; grid-template-columns: repeat(auto-fit,minmax(300px,1fr)); gap: 18px; }}
  .card {{ background: #151a22; border: 1px solid #293241; border-radius: 14px; padding: 16px; }}
  .card h3 {{ display: flex; justify-content: space-between; margin-top: 0; }}
  .card h3 span {{ color: #83aaff; }}
  img {{ display: block; width: 100%; border-radius: 9px; background: #090b0f; }}
  .missing {{ aspect-ratio: 1; display: grid; place-items: center; background: #090b0f; color: #cf6b72; }}
</style>
</head>
<body><main>
<header>
  <h1>Iterative Shader Harness</h1>
  <p class="meta">Model: {html.escape(self.model)} · Profile: {html.escape(self.prompt_profile)} · Loop: {html.escape(self.loop_strategy)} · Rounds: {self.rounds}</p>
</header>
{''.join(html_sections)}
</main></body></html>"""
        )
        return html_path

    async def run(self) -> Path:
        print(f"🎨 Iterative Shader Harness: {self.model}")
        print(f"🧭 Prompt profile: {self.prompt_profile}")
        print(f"🧠 Loop strategy: {self.loop_strategy}")
        print(f"🔁 Rounds: {self.rounds}")
        print(f"🆔 Run ID: {self.run_id}")
        await self.test_runner.prepare_runtime()

        all_results: Dict[str, List[Dict[str, Any]]] = {}
        for problem_index, problem in enumerate(self.problems):
            all_results[problem] = await self.run_problem(
                problem_index, problem
            )

        report = self._generate_report(all_results)
        config = _read_json(self.config_path)
        config["completed"] = datetime.now().isoformat()
        config["report"] = str(report)
        _write_json(self.config_path, config)
        print(f"\n✅ Iterative report: {report}")
        return report


def _resolve_resume_path(value: str) -> Path:
    candidate = Path(value)
    if candidate.exists():
        return candidate.resolve()
    script_dir = Path(__file__).parent.absolute()
    candidate = script_dir / "benchmark_run_output" / value
    if candidate.exists():
        return candidate.resolve()
    raise FileNotFoundError(f"Resume run not found: {value}")


def main(argv=None) -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Generate, render, visually inspect, and fully rewrite a shader "
            "for N rounds."
        )
    )
    parser.add_argument("--model")
    parser.add_argument("--problems", nargs="+")
    parser.add_argument("--rounds", type=int)
    parser.add_argument("--judge-model", nargs="+")
    parser.add_argument(
        "--prompt-profile",
        choices=prompt_profile_choices(),
        default=None,
    )
    parser.add_argument(
        "--loop-strategy",
        choices=LOOP_STRATEGIES,
        default=None,
        help=(
            "latest-v1 uses only the immediately previous render; "
            "history-critique-v2 shows prior render history and requires an "
            "auditable preserve/change/regression critique; "
            "history-code-critique-v3 also supplies bounded prior shader code "
            "so the model can branch from the strongest earlier round."
        ),
    )
    parser.add_argument(
        "--language",
        choices=["wgsl", "glsl", "shadertoy", "hlsl_unity"],
        default=None,
    )
    parser.add_argument(
        "--runtime", choices=["wgpu", "shadertoy"], default=None
    )
    parser.add_argument("--skip-judge", action="store_true")
    parser.add_argument("--run-id")
    parser.add_argument("--resume")
    args = parser.parse_args(argv)

    if args.resume:
        run_dir = _resolve_resume_path(args.resume)
        config_path = run_dir / "config.json"
        if not config_path.exists():
            parser.error(f"Missing iterative config: {config_path}")
        config = _read_json(config_path)
        if config.get("harness") != "iterative-shader-v1":
            parser.error("The selected run is not an iterative-shader-v1 run")

        recorded_profile = config.get(
            "prompt_profile", AMBITIOUS_3D_PROFILE
        )
        if args.prompt_profile and args.prompt_profile != recorded_profile:
            parser.error(
                "Cannot change --prompt-profile while resuming; start a new run"
            )
        recorded_loop = config.get(
            "loop_strategy", LATEST_LOOP_STRATEGY
        )
        if args.loop_strategy and args.loop_strategy != recorded_loop:
            parser.error(
                "Cannot change --loop-strategy while resuming; start a new run"
            )
        rounds = args.rounds or int(config["rounds"])
        if rounds < int(config["rounds"]):
            parser.error("--rounds cannot shrink an existing iterative run")

        harness = IterativeShaderHarness(
            model=config["model"],
            problems=config["problems"],
            rounds=rounds,
            judge_models=(
                args.judge_model
                or config.get("judge_models")
                or [config.get("judge_model", "cli/codex:gpt-5.5:high")]
            ),
            prompt_profile=recorded_profile,
            run_id=run_dir.name,
            language=config.get("language", "wgsl"),
            runtime=config.get("runtime"),
            skip_judge=args.skip_judge or config.get("skip_judge", False),
            loop_strategy=recorded_loop,
        )
    else:
        if not args.model:
            parser.error("--model is required for a new run")
        if not args.problems:
            parser.error("--problems is required for a new run")
        harness = IterativeShaderHarness(
            model=args.model,
            problems=args.problems,
            rounds=args.rounds or 3,
            judge_models=args.judge_model or ["cli/codex:gpt-5.5:high"],
            prompt_profile=args.prompt_profile or AMBITIOUS_3D_PROFILE,
            run_id=args.run_id,
            language=args.language or "wgsl",
            runtime=args.runtime,
            skip_judge=args.skip_judge,
            loop_strategy=args.loop_strategy or LATEST_LOOP_STRATEGY,
        )

    try:
        report = asyncio.run(harness.run())
    except KeyboardInterrupt:
        print("\nInterrupted. Resume with:")
        print(f"  python iterative_shader_harness.py --resume {harness.run_id}")
        raise
    print(f"📋 Report: {report}")
    print(
        "🔄 Resume/extend: "
        f"python iterative_shader_harness.py --resume {harness.run_id} "
        f"--rounds {harness.rounds}"
    )


if __name__ == "__main__":
    main()
