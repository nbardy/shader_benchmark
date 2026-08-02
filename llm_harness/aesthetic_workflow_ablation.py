#!/usr/bin/env python3
"""Run and compare the five controlled beauty-first shader workflows."""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import html
import json
import math
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw

from aesthetic_workflows import aesthetic_workflow_specs
from agentic_shader_harness import resume_agentic_shader, run_agentic_shader
from llm_client import parse_cli_spec
from shader_agent_mcp import _parse_selector_output


CONTROL_RUNS = (
    (
        "v1 control",
        "parrot_sketchbook_3x2_v1_sol_medium_20260730",
    ),
    (
        "v6b control",
        "parrot_composition_first_hierarchy_v6b_sol_medium_20260731",
    ),
)

AESTHETIC_AXES = (
    "emotional_specificity",
    "silhouette_negative_space",
    "focal_hierarchy",
    "organic_rhythm",
    "palette_value",
    "material_depth",
    "whole_image_coherence",
)


def _base_env() -> dict[str, str]:
    environment = os.environ.copy()
    for key in (
        "CLAUDECODE",
        "CLAUDECODE_SESSION_ID",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_API_KEY",
    ):
        environment.pop(key, None)
    return environment


def _result(output_root: Path, run_id: str) -> dict[str, Any] | None:
    path = output_root / run_id / "result.json"
    if not path.is_file():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def _successful_final_count(result: dict[str, Any]) -> int:
    return sum(
        event.get("type") == "render_shader"
        and event.get("ok")
        and event.get("stage", "final") == "final"
        for event in (result.get("state") or {}).get("events", [])
    )


def _judging_complete(result: dict[str, Any], judge_model: str) -> bool:
    judged = result.get("render_judges") or []
    return (
        bool(result.get("submitted"))
        and len(judged) == _successful_final_count(result)
        and all(item.get("judge_model") == judge_model for item in judged)
    )


async def _generate_one(
    *,
    semaphore: asyncio.Semaphore,
    run_id: str,
    output_root: Path,
    model: str,
    problem: str,
    prompt_profile: str,
    render_budget: int,
    render_size: int,
    min_successful_revisions: int,
    workflow: str,
    selector_model: str,
    max_resume_attempts: int,
) -> dict[str, Any]:
    async with semaphore:
        existing = _result(output_root, run_id)
        if existing and existing.get("submitted"):
            return {"run_id": run_id, "submitted": True, "cached": True}

        attempts = 0
        error = ""
        if existing is None:
            try:
                await run_agentic_shader(
                    model=model,
                    problem=problem,
                    prompt_profile=prompt_profile,
                    render_budget=render_budget,
                    render_size=render_size,
                    min_successful_revisions=min_successful_revisions,
                    workflow=workflow,
                    judge_model=None,
                    run_id=run_id,
                    study_selector_model=selector_model,
                )
            except Exception as caught:  # checkpoint remains resumable
                error = str(caught)

        while attempts < max_resume_attempts:
            existing = _result(output_root, run_id)
            if existing and existing.get("submitted"):
                break
            if existing is None:
                break
            attempts += 1
            try:
                await resume_agentic_shader(
                    run_id=run_id,
                    judge_model=None,
                    study_selector_model=selector_model,
                )
            except Exception as caught:  # retain evidence for the next retry
                error = str(caught)

        existing = _result(output_root, run_id) or {}
        return {
            "run_id": run_id,
            "submitted": bool(existing.get("submitted")),
            "cached": False,
            "resume_attempts": attempts,
            "error": error,
        }


def _candidate_sheet(
    candidates: list[dict[str, Any]],
    path: Path,
    *,
    image_size: int,
) -> dict[str, dict[str, Any]]:
    ordered = sorted(
        candidates,
        key=lambda item: hashlib.sha256(
            f"shaderbench-beauty-v10:{item['key']}".encode("utf-8")
        ).hexdigest(),
    )
    columns = 3
    rows = math.ceil(len(ordered) / columns)
    label_height = 34
    cell_width = image_size + 16
    cell_height = image_size + label_height + 12
    sheet = Image.new(
        "RGB",
        (columns * cell_width, rows * cell_height),
        (13, 17, 23),
    )
    draw = ImageDraw.Draw(sheet)
    candidate_map: dict[str, dict[str, Any]] = {}
    for index, candidate in enumerate(ordered):
        candidate_id = f"candidate_{index + 1:02d}"
        candidate_map[candidate_id] = candidate
        image = Image.open(candidate["image_path"]).convert("RGB")
        image.thumbnail((image_size, image_size))
        column = index % columns
        row = index // columns
        left = column * cell_width + (cell_width - image.width) // 2
        top = row * cell_height + label_height
        sheet.paste(image, (left, top))
        draw.text(
            (column * cell_width + 9, row * cell_height + 9),
            candidate_id,
            fill=(238, 242, 250),
        )
    sheet.save(path)
    return candidate_map


def _validate_aesthetic_result(
    parsed: dict[str, Any],
    candidate_ids: set[str],
) -> None:
    ranking = parsed.get("ranking")
    if not isinstance(ranking, list) or set(ranking) != candidate_ids:
        raise ValueError("aesthetic ranking must contain every opaque candidate")
    if len(ranking) != len(candidate_ids):
        raise ValueError("aesthetic ranking contains duplicates")
    if parsed.get("winner") != ranking[0]:
        raise ValueError("aesthetic winner must be first in ranking")
    records = parsed.get("candidates")
    if not isinstance(records, dict) or set(records) != candidate_ids:
        raise ValueError("aesthetic candidate records are incomplete")
    for candidate_id, record in records.items():
        if not isinstance(record, dict):
            raise ValueError(f"{candidate_id} record must be an object")
        for axis in AESTHETIC_AXES:
            score = record.get(axis)
            if isinstance(score, bool) or not isinstance(score, (int, float)):
                raise ValueError(f"{candidate_id}.{axis} must be numeric")
            if not 0 <= float(score) <= 100:
                raise ValueError(f"{candidate_id}.{axis} is outside 0-100")
        if len(str(record.get("evidence", "")).strip()) < 40:
            raise ValueError(f"{candidate_id} needs coordinate-specific evidence")
        if len(str(record.get("critical_failure", "")).strip()) < 20:
            raise ValueError(f"{candidate_id} needs a critical failure")


async def _run_aesthetic_selector(
    *,
    comparison_dir: Path,
    reference_image: Path,
    candidates: list[dict[str, Any]],
    selector_spec: str,
) -> dict[str, Any]:
    thumbnail_sheet = comparison_dir / "aesthetic_candidates_128px.png"
    full_sheet = comparison_dir / "aesthetic_candidates_full.png"
    candidate_map = _candidate_sheet(candidates, thumbnail_sheet, image_size=128)
    full_map = _candidate_sheet(candidates, full_sheet, image_size=480)
    if candidate_map.keys() != full_map.keys():
        raise RuntimeError("thumbnail and full-size candidate maps disagree")
    candidate_ids = list(candidate_map)
    tool, model, effort = parse_cli_spec(selector_spec)
    if tool != "codex" or not model:
        raise ValueError("aesthetic selector must be a cli/codex model")

    with tempfile.TemporaryDirectory(prefix="shader_beauty_selector_") as temp:
        workspace = Path(temp)
        reference = workspace / "reference.png"
        thumbnail = workspace / "thumbnail.png"
        full = workspace / "full.png"
        last_message = workspace / "last_message.txt"
        shutil.copy2(reference_image, reference)
        shutil.copy2(thumbnail_sheet, thumbnail)
        shutil.copy2(full_sheet, full)
        schema_records = {
            candidate_id: {
                **{axis: 0 for axis in AESTHETIC_AXES},
                "evidence": "coordinate-specific visible evidence",
                "critical_failure": "largest visible aesthetic failure",
            }
            for candidate_id in candidate_ids
        }
        prompt = f"""\
You are a fresh, isolated art director judging procedural reconstructions. The
first image is the reference. The second is a 128-pixel thumbnail contact sheet
for the three-second read. The third is the same blinded candidates at larger
size for sustained inspection. Labels are opaque and reveal no method.

Rank beauty and reference-specific visual coherence, not code complexity,
object count, mathematical sophistication, or generic completeness. Judge:
- emotional specificity rather than generic toy/cartoon read;
- silhouette, gesture, and designed negative space;
- focal path and quiet-versus-detailed hierarchy;
- organic rhythm, overlap, controlled irregularity, and part relationships;
- palette/value relationships and subject-background separation;
- material differentiation, lighting, depth, and edge quality;
- whole-image coherence and whether details serve the same art direction.

Use both scales. Penalize ovals glued together, finger/capsule arrays, exposed
grids, armor sheets, shiny balls with fake texture, arbitrary bokeh, and detail
that weakens the thumbnail. Score each axis 0-100. Evidence must cite visible
image regions or relationships.

Return ONLY this JSON shape, replacing every value with your judgment:
{json.dumps({
    'ranking': candidate_ids,
    'winner': candidate_ids[0],
    'candidates': schema_records,
    'overall_evidence': 'why the ranking separates the strongest images',
}, indent=2)}
"""
        command = [
            "codex",
            "exec",
            "--ephemeral",
            "--ignore-user-config",
            "--ignore-rules",
            "--sandbox",
            "read-only",
            "--skip-git-repo-check",
            "--cd",
            str(workspace),
            "--json",
            "--output-last-message",
            str(last_message),
            "--model",
            model,
            "--image",
            str(reference),
            "--image",
            str(thumbnail),
            "--image",
            str(full),
        ]
        if effort:
            command.extend(
                ["--config", "reasoning_effort=" + json.dumps(effort)]
            )
        command.append("-")
        completed = await asyncio.to_thread(
            subprocess.run,
            command,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=600,
            env=_base_env(),
            cwd=workspace,
        )
        (comparison_dir / "aesthetic_selector.jsonl").write_text(
            completed.stdout or "", encoding="utf-8"
        )
        (comparison_dir / "aesthetic_selector.stderr.txt").write_text(
            completed.stderr or "", encoding="utf-8"
        )
        if completed.returncode != 0 or not last_message.is_file():
            raise RuntimeError(
                "aesthetic selector failed: "
                + (completed.stderr or completed.stdout or "no response")[-2_000:]
            )
        raw = last_message.read_text(encoding="utf-8")

    parsed = _parse_selector_output(raw)
    _validate_aesthetic_result(parsed, set(candidate_ids))
    parsed["candidate_map"] = candidate_map
    parsed["selector_model"] = selector_spec
    parsed["axes"] = list(AESTHETIC_AXES)
    (comparison_dir / "aesthetic_ranking.json").write_text(
        json.dumps(parsed, indent=2), encoding="utf-8"
    )
    return parsed


def _candidate_for_run(
    output_root: Path,
    *,
    key: str,
    label: str,
    run_id: str,
    hypothesis: str,
    control: bool,
) -> dict[str, Any] | None:
    run_dir = output_root / run_id
    result = _result(output_root, run_id)
    image = run_dir / "final_render.png"
    if not result or not result.get("submitted") or not image.is_file():
        return None
    diagnostic = _selection_diagnostic(run_dir, result)
    submitted = diagnostic["submitted"]
    return {
        "key": key,
        "label": label,
        "run_id": run_id,
        "hypothesis": hypothesis,
        "control": control,
        "image_path": str(image),
        "report_path": str(run_dir / "agentic_report.html"),
        "benchmark_total": submitted.get("total"),
        "benchmark_scores": submitted.get("scores"),
        "render_calls": (result.get("state") or {}).get("render_calls"),
        **diagnostic,
    }


def _selection_diagnostic(
    run_dir: Path,
    result: dict[str, Any],
) -> dict[str, Any]:
    """Compare the submitted final with the best scored full-frame final.

    Study atlases are deliberately excluded even if a malformed or historical
    result happens to contain a judge record for one. The oracle is diagnostic:
    it never replaces ``image_path``, which remains the submitted image used by
    the blinded aesthetic selector.
    """

    submission_path = run_dir / "submission.json"
    submission = (
        json.loads(submission_path.read_text(encoding="utf-8"))
        if submission_path.is_file()
        else {}
    )
    submitted_judge = result.get("judge") or {}
    submitted_call = submission.get(
        "render_call", submitted_judge.get("render_call")
    )
    submitted_revision = submission.get(
        "revision", submitted_judge.get("revision")
    )
    submitted = {
        "image_path": str(run_dir / "final_render.png"),
        "render_call": submitted_call,
        "revision": submitted_revision,
        "total": submitted_judge.get("total"),
        "scores": submitted_judge.get("scores"),
    }

    successful_finals = {
        (int(event["render_call"]), int(event["revision"]))
        for event in (result.get("state") or {}).get("events", [])
        if event.get("type") == "render_shader"
        and event.get("ok")
        and event.get("stage", "final") == "final"
        and isinstance(event.get("render_call"), int)
        and not isinstance(event.get("render_call"), bool)
        and isinstance(event.get("revision"), int)
        and not isinstance(event.get("revision"), bool)
    }
    judged_finals: list[dict[str, Any]] = []
    for judged in result.get("render_judges") or []:
        render_call = judged.get("render_call")
        revision = judged.get("revision")
        total = judged.get("total")
        if (
            isinstance(render_call, int)
            and not isinstance(render_call, bool)
            and isinstance(revision, int)
            and not isinstance(revision, bool)
            and isinstance(total, (int, float))
            and not isinstance(total, bool)
            and (render_call, revision) in successful_finals
        ):
            render_path = run_dir / "renders" / f"render_{render_call:02d}.png"
            if render_path.is_file():
                judged_finals.append(
                    {
                        "image_path": str(render_path),
                        "render_call": render_call,
                        "revision": revision,
                        "total": total,
                        "scores": judged.get("scores"),
                    }
                )
    oracle_best = (
        max(
            judged_finals,
            key=lambda item: (float(item["total"]), int(item["render_call"])),
        )
        if judged_finals
        else None
    )
    submitted_total = submitted.get("total")
    selection_gap = (
        float(oracle_best["total"]) - float(submitted_total)
        if oracle_best is not None
        and isinstance(submitted_total, (int, float))
        and not isinstance(submitted_total, bool)
        else None
    )
    return {
        "submitted": submitted,
        "oracle_best": oracle_best,
        "selection_gap": selection_gap,
    }


def _workflow_diagnostics(
    candidates: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    return {
        str(candidate["key"]): {
            "run_id": candidate["run_id"],
            "label": candidate["label"],
            "submitted": candidate.get("submitted"),
            "oracle_best": candidate.get("oracle_best"),
            "selection_gap": candidate.get("selection_gap"),
        }
        for candidate in candidates
        if not candidate["control"]
    }


def _load_reusable_aesthetic_ranking(
    ranking_path: Path,
    candidates: list[dict[str, Any]],
) -> dict[str, Any]:
    """Load a saved blind ranking only when its candidate identities still match."""

    aesthetic = json.loads(ranking_path.read_text(encoding="utf-8"))
    candidate_map = aesthetic.get("candidate_map") or {}
    _validate_aesthetic_result(aesthetic, set(candidate_map))
    current_keys = {str(candidate["key"]) for candidate in candidates}
    ranked_keys = {
        str(candidate.get("key"))
        for candidate in candidate_map.values()
        if isinstance(candidate, dict)
    }
    if ranked_keys != current_keys:
        raise ValueError("saved aesthetic ranking does not match current candidates")
    return aesthetic


def _build_report(
    comparison_dir: Path,
    candidates: list[dict[str, Any]],
    aesthetic: dict[str, Any] | None,
) -> Path:
    by_opaque = (aesthetic or {}).get("candidate_map") or {}
    aesthetic_records = (aesthetic or {}).get("candidates") or {}
    rank_by_key: dict[str, int] = {}
    scores_by_key: dict[str, dict[str, Any]] = {}
    for rank, opaque in enumerate((aesthetic or {}).get("ranking") or [], 1):
        mapped = by_opaque.get(opaque) or {}
        key = str(mapped.get("key", ""))
        if key:
            rank_by_key[key] = rank
            scores_by_key[key] = aesthetic_records.get(opaque) or {}

    rows = []
    cards = []
    for candidate in sorted(
        candidates,
        key=lambda item: rank_by_key.get(str(item["key"]), 999),
    ):
        key = str(candidate["key"])
        scores = scores_by_key.get(key, {})
        mean_aesthetic = (
            sum(float(scores[axis]) for axis in AESTHETIC_AXES)
            / len(AESTHETIC_AXES)
            if all(axis in scores for axis in AESTHETIC_AXES)
            else None
        )
        submitted = candidate.get("submitted") or {
            "image_path": candidate["image_path"],
            "total": candidate.get("benchmark_total"),
            "scores": candidate.get("benchmark_scores"),
            "revision": None,
            "render_call": None,
        }
        oracle_best = candidate.get("oracle_best")
        submitted_total = submitted.get("total")
        oracle_total = (
            oracle_best.get("total") if isinstance(oracle_best, dict) else None
        )
        selection_gap = candidate.get("selection_gap")
        relative_image = os.path.relpath(submitted["image_path"], comparison_dir)
        relative_report = os.path.relpath(candidate["report_path"], comparison_dir)
        rows.append(
            "<tr>"
            f"<td>{rank_by_key.get(key, '—')}</td>"
            f"<td>{html.escape(str(candidate['label']))}</td>"
            f"<td>{'control' if candidate['control'] else 'v10 workflow'}</td>"
            f"<td>{html.escape(str(submitted_total if submitted_total is not None else '—'))}</td>"
            f"<td>{html.escape(str(oracle_total if oracle_total is not None else '—'))}</td>"
            f"<td>{f'+{selection_gap:g}' if isinstance(selection_gap, (int, float)) and not isinstance(selection_gap, bool) else '—'}</td>"
            f"<td>{f'{mean_aesthetic:.1f}' if mean_aesthetic is not None else '—'}</td>"
            f"<td>{html.escape(str(candidate.get('render_calls') or '—'))}</td>"
            "</tr>"
        )
        axis_lines = "".join(
            f"<li>{html.escape(axis.replace('_', ' ').title())}: "
            f"{html.escape(str(scores.get(axis, '—')))}</li>"
            for axis in AESTHETIC_AXES
        )
        submitted_caption = (
            f"Submitted · revision {submitted.get('revision', '—')} · "
            f"{submitted_total if submitted_total is not None else '—'} / 500"
        )
        if isinstance(oracle_best, dict):
            relative_oracle = os.path.relpath(
                oracle_best["image_path"], comparison_dir
            )
            oracle_figure = (
                "<figure>"
                f"<img src='{html.escape(relative_oracle)}' "
                f"alt='Standard-judge oracle best for {html.escape(str(candidate['label']))}'>"
                f"<figcaption>Oracle-best final · revision "
                f"{html.escape(str(oracle_best.get('revision', '—')))} · "
                f"{html.escape(str(oracle_total))} / 500</figcaption>"
                "</figure>"
            )
        else:
            oracle_figure = (
                "<figure class='unavailable'><div>Oracle unavailable</div>"
                "<figcaption>No complete per-final standard judging.</figcaption>"
                "</figure>"
            )
        cards.append(
            "<article>"
            f"<h2>#{rank_by_key.get(key, '—')} · {html.escape(str(candidate['label']))}</h2>"
            "<div class='comparison-pair'>"
            "<figure>"
            f"<a href='{html.escape(relative_report)}'><img src='{html.escape(relative_image)}' "
            f"alt='Submitted final for {html.escape(str(candidate['label']))}'></a>"
            f"<figcaption>{html.escape(submitted_caption)}</figcaption>"
            "</figure>"
            f"{oracle_figure}"
            "</div>"
            f"<p><strong>Hypothesis:</strong> {html.escape(str(candidate['hypothesis']))}</p>"
            f"<p><strong>Submitted benchmark:</strong> {html.escape(str(submitted_total if submitted_total is not None else '—'))} / 500 "
            f"{html.escape(str(submitted.get('scores') or ''))}</p>"
            f"<p><strong>Selection gap:</strong> {f'+{selection_gap:g}' if isinstance(selection_gap, (int, float)) and not isinstance(selection_gap, bool) else '—'} points available from the best standard-judged final.</p>"
            f"<ul>{axis_lines}</ul>"
            f"<p><strong>Blinded evidence for submitted image:</strong> {html.escape(str(scores.get('evidence', '—')))}</p>"
            f"<p><strong>Submitted-image critical failure:</strong> {html.escape(str(scores.get('critical_failure', '—')))}</p>"
            f"<p><a href='{html.escape(relative_report)}'>Open complete trace</a></p>"
            "</article>"
        )
    report = comparison_dir / "aesthetic_comparison.html"
    report.write_text(
        f"""<!doctype html>
<html><head><meta charset="utf-8"><title>ShaderBench beauty workflows</title>
<style>
:root{{color-scheme:dark}}body{{margin:0;padding:28px;background:#0d1117;color:#e6edf3;font:16px/1.5 system-ui;max-width:1800px}}
h1{{font-size:34px}}table{{border-collapse:collapse;width:100%;margin:24px 0}}th,td{{padding:10px;border-bottom:1px solid #30363d;text-align:left}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(520px,1fr));gap:20px}}article{{background:#161b22;border:1px solid #30363d;border-radius:14px;padding:16px}}img{{display:block;width:100%;border-radius:10px;background:#080b10}}a{{color:#79c0ff}}.lead{{color:#aeb8c4;max-width:1100px}}.comparison-pair{{display:grid;grid-template-columns:1fr 1fr;gap:12px}}figure{{margin:0}}figcaption{{color:#aeb8c4;padding-top:7px}}.unavailable{{display:grid;min-height:260px;place-items:center;background:#0d1117;border-radius:10px;color:#8b949e}}.unavailable figcaption{{align-self:end;padding:10px}}
</style></head><body>
<h1>Beauty-first ShaderBench workflow ablation</h1>
<p class="lead">Five GPT-5.6 Sol medium workflows share the same parrot, prompt profile, 18-render ceiling, six-final minimum, renderer, and benchmark judge. Two historical controls are included only in the blinded aesthetic ranking. <strong>The blinded aesthetic judge ranked submitted outputs only</strong>, with opaque labels at 128px and full size. Oracle-best images are shown afterward solely to diagnose whether a workflow generated a stronger full-frame final but selected the wrong one; they were never selector candidates.</p>
<p><strong>Blinded selector:</strong> {html.escape(str((aesthetic or {}).get('selector_model', 'unavailable')))}</p>
<p>{html.escape(str((aesthetic or {}).get('overall_evidence', 'Aesthetic selector unavailable.')))}</p>
<table><thead><tr><th>Submitted aesthetic rank</th><th>Method</th><th>Group</th><th>Submitted /500</th><th>Oracle-best /500</th><th>Selection gap</th><th>Submitted aesthetic mean /100</th><th>Renders</th></tr></thead><tbody>{''.join(rows)}</tbody></table>
<p><a href="aesthetic_candidates_128px.png">128px blinded sheet</a> · <a href="aesthetic_candidates_full.png">full-size blinded sheet</a></p>
<div class="grid">{''.join(cards)}</div>
</body></html>""",
        encoding="utf-8",
    )
    return report


async def run_ablation(args: argparse.Namespace) -> Path:
    script_dir = Path(__file__).parent.resolve()
    output_root = script_dir / "benchmark_run_output"
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,90}", args.run_prefix):
        raise ValueError("run prefix contains invalid path characters")
    run_ids = {
        spec.name: f"{args.run_prefix}__{spec.name}"
        for spec in aesthetic_workflow_specs()
    }
    semaphore = asyncio.Semaphore(args.max_parallel)
    generation_results = await asyncio.gather(
        *(
            _generate_one(
                semaphore=semaphore,
                run_id=run_ids[spec.name],
                output_root=output_root,
                model=args.model,
                problem=args.problem,
                prompt_profile=args.prompt_profile,
                render_budget=args.render_budget,
                render_size=args.render_size,
                min_successful_revisions=args.min_successful_revisions,
                workflow=spec.name,
                selector_model=args.selector_model,
                max_resume_attempts=args.max_resume_attempts,
            )
            for spec in aesthetic_workflow_specs()
        )
    )

    for spec in aesthetic_workflow_specs():
        run_id = run_ids[spec.name]
        result = _result(output_root, run_id)
        if not result or not result.get("submitted"):
            continue
        if not _judging_complete(result, args.judge_model):
            await resume_agentic_shader(
                run_id=run_id,
                judge_model=args.judge_model,
                study_selector_model=args.selector_model,
            )

    comparison_dir = output_root / f"{args.run_prefix}__comparison"
    comparison_dir.mkdir(parents=True, exist_ok=True)
    candidates: list[dict[str, Any]] = []
    for spec in aesthetic_workflow_specs():
        candidate = _candidate_for_run(
            output_root,
            key=spec.name,
            label=spec.label,
            run_id=run_ids[spec.name],
            hypothesis=spec.hypothesis,
            control=False,
        )
        if candidate is not None:
            candidates.append(candidate)
    for label, run_id in CONTROL_RUNS:
        candidate = _candidate_for_run(
            output_root,
            key=run_id,
            label=label,
            run_id=run_id,
            hypothesis="Historical visual control; no new generation cost.",
            control=True,
        )
        if candidate is not None:
            candidates.append(candidate)

    aesthetic: dict[str, Any] | None = None
    if len(candidates) >= 2:
        ranking_path = comparison_dir / "aesthetic_ranking.json"
        if args.reuse_aesthetic_ranking:
            if not ranking_path.is_file():
                raise FileNotFoundError(
                    "--reuse-aesthetic-ranking requested but no saved ranking exists"
                )
            aesthetic = _load_reusable_aesthetic_ranking(
                ranking_path,
                candidates,
            )
        else:
            problem_path = (
                script_dir.parent / "problems" / "base_set" / args.problem
            )
            aesthetic = await _run_aesthetic_selector(
                comparison_dir=comparison_dir,
                reference_image=problem_path / "reference.png",
                candidates=candidates,
                selector_spec=args.selector_model,
            )
    report = _build_report(comparison_dir, candidates, aesthetic)
    summary = {
        "config": vars(args),
        "run_ids": run_ids,
        "generation_results": generation_results,
        "submitted_workflows": sum(
            bool((_result(output_root, run_id) or {}).get("submitted"))
            for run_id in run_ids.values()
        ),
        "workflow_diagnostics": _workflow_diagnostics(candidates),
        "report": str(report),
    }
    (comparison_dir / "ablation_result.json").write_text(
        json.dumps(summary, indent=2), encoding="utf-8"
    )
    return report


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description="Run five controlled beauty-first shader workflows."
    )
    parser.add_argument("--model", default="cli/codex:gpt-5.6-sol:medium")
    parser.add_argument("--judge-model", default="cli/codex:gpt-5.5:high")
    parser.add_argument("--selector-model", default="cli/codex:gpt-5.5:high")
    parser.add_argument("--problem", default="reproduce_image_andrew_pons")
    parser.add_argument("--prompt-profile", default="domain-expert-v2")
    parser.add_argument("--render-budget", type=int, default=18)
    parser.add_argument("--render-size", type=int, default=1024)
    parser.add_argument("--min-successful-revisions", type=int, default=6)
    parser.add_argument("--max-parallel", type=int, default=2)
    parser.add_argument("--max-resume-attempts", type=int, default=2)
    parser.add_argument("--run-prefix", default="parrot_beauty5_20260803")
    parser.add_argument(
        "--reuse-aesthetic-ranking",
        action="store_true",
        help=(
            "reuse the saved blinded ranking when rebuilding diagnostics and "
            "HTML; fails closed if the candidate set changed"
        ),
    )
    args = parser.parse_args(argv)
    if not 1 <= args.max_parallel <= 3:
        raise ValueError("max_parallel must be between 1 and 3")
    if args.render_budget < args.min_successful_revisions:
        raise ValueError("render budget must cover required finals")
    report = asyncio.run(run_ablation(args))
    print(f"Aesthetic comparison: {report}")


if __name__ == "__main__":
    main()
