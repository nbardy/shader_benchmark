#!/usr/bin/env python3
"""Rejudge cached prompt-matrix renders with the corrected critic parser."""

from __future__ import annotations

import argparse
import asyncio
import json
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, List, Tuple

from judge import EvaluationContext, Judge
from prompt_matrix_harness import PromptMatrixHarness, _read_json, _write_json


def discover_rendered_rounds(
    matrix_dir: Path,
) -> List[Tuple[Path, Path, Path, Path]]:
    config = _read_json(matrix_dir / "config.json")
    problem_root = Path(__file__).parent.parent / "problems" / "base_set"
    output_root = Path(__file__).parent / "benchmark_run_output"
    work: List[Tuple[Path, Path, Path, Path]] = []
    for child in config.get("child_runs", []):
        child_dir = output_root / child["run_id"]
        for problem_index, problem in enumerate(config["problems"]):
            problem_path = problem_root / problem
            result_root = (
                child_dir / "results" / f"{problem_index:03d}_{problem}"
            )
            for round_number in range(1, int(config["rounds"]) + 1):
                round_dir = result_root / f"round_{round_number:02d}"
                state = _read_json(round_dir / "round_result.json")
                image_value = state.get("image_path")
                shader_value = state.get("shader_path")
                if not image_value or not shader_value:
                    continue
                image_path = Path(image_value)
                shader_path = Path(shader_value)
                if image_path.exists() and shader_path.exists():
                    work.append(
                        (problem_path, round_dir, image_path, shader_path)
                    )
    return work


async def rejudge_one(
    judge_model: str,
    item: Tuple[Path, Path, Path, Path],
    semaphore: asyncio.Semaphore,
) -> Dict[str, Any]:
    problem_path, round_dir, image_path, shader_path = item
    output_dir = round_dir / "fixed_rubric_judge"
    result_path = output_dir / "results.json"
    cached = _read_json(result_path)
    if cached.get("status") == "complete":
        return cached

    async with semaphore:
        output_dir.mkdir(parents=True, exist_ok=True)
        judge = Judge(judge_model=judge_model)
        context = EvaluationContext(
            critic_path=problem_path / "critic.txt",
            request_path=problem_path / "request.txt",
            result_image_path=image_path,
            save_dir=output_dir,
            code_path=shader_path,
            reference_image_path=problem_path / "reference.png",
        )
        try:
            scores, failure_reason, usage = await judge.evaluate_with_template(
                context
            )
            result = {
                "status": "complete",
                "rubric_version": "reconstruction-section-aliases-v2",
                "judge_model": judge_model,
                "scores": scores,
                "total_score": sum(scores),
                "failure_reason": failure_reason,
                "usage": usage,
                "completed": datetime.now().isoformat(),
            }
        except Exception as exc:
            result = {
                "status": "failed",
                "rubric_version": "reconstruction-section-aliases-v2",
                "judge_model": judge_model,
                "error": str(exc),
                "updated": datetime.now().isoformat(),
            }
        _write_json(result_path, result)
        return result


async def run(args) -> None:
    matrix_dir = Path(args.matrix_run)
    if not matrix_dir.exists():
        matrix_dir = (
            Path(__file__).parent
            / "benchmark_run_output"
            / args.matrix_run
        )
    matrix_dir = matrix_dir.resolve()
    config = _read_json(matrix_dir / "config.json")
    if config.get("harness") != "prompt-matrix-v1":
        raise ValueError(f"Not a prompt matrix: {matrix_dir}")

    work = discover_rendered_rounds(matrix_dir)
    semaphore = asyncio.Semaphore(args.max_parallel)
    results = await asyncio.gather(
        *(
            rejudge_one(args.judge_model, item, semaphore)
            for item in work
        )
    )
    complete = sum(result.get("status") == "complete" for result in results)
    print(f"Corrected-rubric judges complete: {complete}/{len(results)}")

    harness = PromptMatrixHarness(
        model=config["model"],
        problems=config["problems"],
        profiles=config["profiles"],
        trials=int(config["trials"]),
        rounds=int(config["rounds"]),
        judge_models=config["judge_models"],
        max_parallel=int(config.get("max_parallel", 3)),
        run_id=config["run_id"],
        language=config.get("language", "wgsl"),
        runtime=config.get("runtime"),
        skip_judge=config.get("skip_judge", False),
        loop_strategy=config.get("loop_strategy", "latest-v1"),
    )
    print(harness._generate_report())


def main(argv=None) -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("matrix_run")
    parser.add_argument(
        "--judge-model", default="cli/codex:gpt-5.5:high"
    )
    parser.add_argument("--max-parallel", type=int, default=3)
    args = parser.parse_args(argv)
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
