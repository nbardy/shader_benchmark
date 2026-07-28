#!/usr/bin/env python3
"""Build the static site under docs/ from completed benchmark runs.

Idempotent: re-running regenerates docs/ from
llm_harness/benchmark_run_output/ + problems/base_set/ on disk.

Inputs (read-only):
  llm_harness/benchmark_run_output/<run_id>/{config.json, checkpoints/, results/, images/, benchmark_report.html, benchmark_report.md}
  problems/base_set/<problem>/reference.png  (only for reproduce_image_*)

Outputs:
  docs/index.html              hub page
  docs/all_scores.json         aggregated scores
  docs/<model-key>/...         per-model detail report copies
  docs/images/<model>/000_*.png  thumbnails for the per-problem drawer
  docs/refs/<problem>.png      reference images for image-reproduction problems
  docs/README.md               note that this is auto-generated
"""

from __future__ import annotations

import json
import os
import shutil
from datetime import datetime, timezone
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
BENCH_DIR = REPO / "llm_harness" / "benchmark_run_output"
PROBLEMS_DIR = REPO / "problems" / "base_set"
CORE_SET_PATH = REPO / "problems" / "benchmark_sets" / "core30.json"
DOCS = REPO / "docs"

# Three completed runs we publish. Order = column order on the hub.
# `run_dirs` is a list because we sometimes split a model's coverage
# across multiple harness runs (primary big run + small "delta" runs
# for problems added after the fact). Per-problem rows are merged
# across all listed run_dirs; later run_dirs override earlier ones for
# the same problem name. The first run_dir is the "primary" — its
# benchmark_report.{html,md} is what the "View detail report" link on
# the hub points to.
RUNS = [
    {
        "key": "claude-opus-5-medium",
        "label": "Claude Opus 5 medium",
        "run_dirs": [
            "e9f738e9_cli_claude_claude-opus-5_medium_20260727_044910",
        ],
    },
    {
        "key": "codex-gpt-5.6-sol-medium",
        "label": "Codex GPT-5.6 Sol medium",
        "run_dirs": [
            "29f6a349_cli_codex_gpt-5.6-sol_medium_20260726_185836",
        ],
    },
    {
        "key": "claude-fable-5",
        "label": "Claude Fable 5 high (30/130)",
        "run_dirs": [
            "ee3dcad2_cli_claude_claude-fable-5_20260610_030343",  # first 5 problems (effort: high, CLI default)
            "2cebf07b_cli_claude_claude-fable-5_high_20260610_033742",  # 4 frontier/4D problems (effort recorded in spec)
            "c1fe229b_cli_claude_claude-fable-5_high_20260610_155046",  # 10 reconstruction problems
            "core30_fable5_high_expansion_20260729",  # frozen Core-30 expansion
        ],
    },
    {
        "key": "claude-opus-4-7",
        "label": "Claude Opus 4.7",
        "run_dirs": [
            "65ab97ac_cli_claude_claude-opus-4-7_20260427_183924",
            "c27a9b7a_cli_claude_claude-opus-4-7_20260501_231430",  # 3 new image-reproduction problems
            "b03ce16c_cli_claude_claude-opus-4-7_20260502_132102",  # 20 frontier problems
            "a8deff3a_cli_claude_claude-opus-4-7_20260502_172716",  # retry for 3 frontier gen failures
        ],
    },
    {
        "key": "gemini-3.1-pro-preview",
        "label": "Gemini 3.1-pro-preview",
        "run_dirs": [
            "f995b01e_cli_gemini_20260427_184028",
            "eac60057_cli_gemini_20260501_231430",  # 3 new image-reproduction problems
            "3b212275_cli_gemini_20260502_132102",  # 20 frontier problems
        ],
    },
    {
        "key": "codex-gpt-5.5-high",
        "label": "Codex GPT-5.5 high",
        "run_dirs": [
            "68ca3b4b_cli_codex_gpt-5.5_high_20260428_170724",
            "53b06f90_cli_codex_gpt-5.5_high_20260501_231430",  # 3 new image-reproduction problems
            "768e6e20_cli_codex_gpt-5.5_high_20260502_132102",  # 20 frontier problems
        ],
    },
]

CATEGORY_LABELS = [
    "Mathematical Accuracy",
    "Visual Quality",
    "Color Implementation",
    "Geometric Completeness",
    "Reference Elements",
]

TOP_LEVEL_GROUPS = ["Frontier", "Reconstruction", "Rest"]


# ---------------------------------------------------------------------------
# Data extraction
# ---------------------------------------------------------------------------


def load_runs(run_dirs: list[Path]) -> dict:
    """Merge multiple harness run dirs for the same model into one record.

    Per-problem rows from each run_dir are unioned, keyed by problem name.
    If two runs cover the same problem, later run_dirs win (so a small
    "delta" run can correct or extend the primary). The merged record's
    `config` is the first run_dir's config; `run_dir` is also the first;
    `extra_run_dirs` is the rest, used for image-asset copying.
    """
    primary_cfg = json.loads((run_dirs[0] / "config.json").read_text())

    rows: dict[str, dict] = {}
    for run_dir in run_dirs:
        new_rows = _load_one_run_rows(run_dir)
        for name, row in new_rows.items():
            existing = rows.get(name)
            tagged = row | {"_source_run_dir": run_dir}
            if existing is None:
                rows[name] = tagged
                continue
            # Don't let a still-running delta clobber a real result from
            # the primary. Override only if the new row has data the old
            # one didn't (status "ok" wins; "render_fail" wins over
            # "missing"; "missing" never overrides).
            priority = {"ok": 2, "render_fail": 1, "missing": 0}
            if priority[row["status"]] >= priority[existing["status"]]:
                rows[name] = tagged

    return {
        "config": primary_cfg,
        "rows": rows,
        "run_dir": run_dirs[0],
        "all_run_dirs": run_dirs,
    }


def _mean_of_judges(per_judge: dict) -> list[int] | None:
    """Element-wise mean of per-judge score vectors. None when empty."""
    if not per_judge:
        return None
    n = len(per_judge)
    sums = [0, 0, 0, 0, 0]
    for vec in per_judge.values():
        for i in range(5):
            sums[i] += vec[i]
    return [round(s / n) for s in sums]


def judge_display_name(judge_model: str) -> str:
    """Short display label for a judge model identifier."""
    low = judge_model.lower()
    if "codex" in low or "gpt-5.5" in low:
        return "Codex judge"
    if "claude" in low:
        return "Claude judge"
    if "gemini" in low:
        return "Gemini judge"
    return judge_model


def load_problem_categories(problems: list[str]) -> dict[str, str]:
    """Read per-problem category.txt tags, falling back to Uncategorized."""
    categories = {}
    for name in problems:
        path = PROBLEMS_DIR / name / "category.txt"
        if path.exists():
            categories[name] = path.read_text(encoding="utf-8").strip() or "Uncategorized"
        else:
            categories[name] = "Uncategorized"
    return categories


def problem_group(problem: str, category: str) -> str:
    """Collapse detailed categories into the homepage's top-level groups."""
    if category == "Frontier":
        return "Frontier"
    if category in {"Image Reproduction", "Reconstruction"}:
        return "Reconstruction"
    if problem == "reproduce_image" or problem.startswith("reproduce_image_"):
        return "Reconstruction"
    return "Rest"


def grouped_problem_order(problems: set[str], categories: dict[str, str]) -> list[str]:
    """Sort problems by top-level group, then alphabetically within group."""
    order = {group: i for i, group in enumerate(TOP_LEVEL_GROUPS)}
    return sorted(
        problems,
        key=lambda p: (order[problem_group(p, categories.get(p, "Uncategorized"))], p),
    )


def _load_one_run_rows(run_dir: Path) -> dict[str, dict]:
    """Read a single run's per-problem rows.

    Each row carries `scores_by_judge` (per-judge breakdown) plus `scores`
    which is the panel mean recomputed from `scores_by_judge`. Recomputing
    here (instead of trusting the top-level `scores` field in results.json)
    means a stale single-judge `scores` left over from before a rejudge
    can't outvote the new evidence in `scores_by_judge`.
    """
    cfg = json.loads((run_dir / "config.json").read_text())
    problems = cfg["problems"]
    rows = {}
    for idx, name in enumerate(problems):
        cp_path = run_dir / "checkpoints" / f"problem_{idx:03d}.json"
        results_dir = run_dir / "results" / f"{idx:03d}_{name}"
        results_path = results_dir / "results.json"
        image_path = results_dir / "artifacts" / "result.png"

        # Default
        row = {
            "scores": None,
            "total": None,
            "scores_by_judge": None,
            "has_image": False,
            "status": "missing",
            "index": idx,
        }

        # Render-fail detection: only the render stage's own failed/permanent
        # marker counts. A judge stage failing transiently (codex quota etc.)
        # does NOT poison the problem — the rest of the panel can still score.
        is_render_fail = False
        if cp_path.exists():
            try:
                cp = json.loads(cp_path.read_text())
                render = cp.get("stages", {}).get("render", {})
                if render.get("status") == "failed":
                    is_render_fail = True
                rdata = render.get("data") or {}
                if isinstance(rdata, dict) and rdata.get("permanent") is True:
                    is_render_fail = True
            except Exception:
                pass

        if results_path.exists():
            try:
                r = json.loads(results_path.read_text())
                has_img = bool(r.get("has_image")) and image_path.exists()
                sbj_raw = r.get("scores_by_judge") or {}
                # Keep only judges that produced 5 nonzero ints.
                sbj: dict[str, list[int]] = {}
                for jm, vec in sbj_raw.items():
                    if (isinstance(vec, list) and len(vec) == 5
                            and all(isinstance(s, (int, float)) for s in vec)
                            and any(s > 0 for s in vec)):
                        sbj[jm] = [int(s) for s in vec]
                # Defensive fallback: pre-migration row with only the legacy
                # top-level `scores` field. migrate_judge_schema.py should
                # have backfilled scores_by_judge already, so this branch is
                # rarely hit.
                if not sbj:
                    legacy = r.get("scores")
                    if (isinstance(legacy, list) and len(legacy) == 5
                            and any(isinstance(s, (int, float)) and s > 0 for s in legacy)):
                        sbj = {cfg.get("judge_model", "unknown"): [int(s) for s in legacy]}

                mean = _mean_of_judges(sbj)
                if mean is not None and has_img and r.get("status") == "completed":
                    row["scores"] = mean
                    row["total"] = sum(mean)
                    row["scores_by_judge"] = sbj
                    row["has_image"] = True
                    row["status"] = "ok"
                else:
                    row["status"] = "render_fail" if is_render_fail else "missing"
                    row["has_image"] = has_img
            except Exception:
                row["status"] = "render_fail" if is_render_fail else "missing"
        else:
            row["status"] = "render_fail" if is_render_fail else "missing"

        rows[name] = row

    return rows


def aggregate(runs: dict[str, dict], problems_sorted: list[str], problem_categories: dict[str, str]) -> dict:
    """Produce the all_scores.json structure."""
    scores = {}
    for name in problems_sorted:
        scores[name] = {}
        for key, run in runs.items():
            r = run["rows"].get(name) or {
                "scores": None,
                "total": None,
                "scores_by_judge": None,
                "has_image": False,
                "status": "missing",
            }
            scores[name][key] = {
                "scores": r["scores"],
                "total": r["total"],
                "scores_by_judge": r.get("scores_by_judge"),
                "has_image": r["has_image"],
                "status": r["status"],
            }

    problem_groups = {group: [] for group in TOP_LEVEL_GROUPS}
    for name in problems_sorted:
        group = problem_group(name, problem_categories.get(name, "Uncategorized"))
        problem_groups.setdefault(group, []).append(name)

    summary = {}
    for key, run in runs.items():
        rows = run["rows"]
        ok_totals = [r["total"] for r in rows.values() if r["status"] == "ok"]
        all_totals = [(r["total"] or 0) for r in rows.values()]
        ok_count = sum(1 for r in rows.values() if r["status"] == "ok")
        fail_count = sum(1 for r in rows.values() if r["status"] == "render_fail")
        # missing_count = total - ok - fail (kept implicit)

        judge_totals: dict[str, list[int]] = {}
        for r in rows.values():
            if r["status"] != "ok":
                continue
            for judge_model, vec in (r.get("scores_by_judge") or {}).items():
                judge_totals.setdefault(judge_model, []).append(sum(vec))

        best = None
        worst = None
        for name, r in rows.items():
            if r["status"] != "ok":
                continue
            t = r["total"]
            if best is None or t > best[1]:
                best = (name, t)
            if worst is None or t < worst[1]:
                worst = (name, t)

        summary[key] = {
            "ok": ok_count,
            "permanent_fail": fail_count,
            "total": len(rows),
            "avg_total_filtered": (sum(ok_totals) / len(ok_totals)) if ok_totals else None,
            "avg_total_with_zeros": (sum(all_totals) / len(all_totals)) if all_totals else None,
            "avg_total_by_judge_filtered": {
                jm: (sum(vals) / len(vals)) for jm, vals in judge_totals.items()
            },
            "judge_score_counts": {jm: len(vals) for jm, vals in judge_totals.items()},
            "best_problem": {"name": best[0], "total": best[1]} if best else None,
            "worst_problem": {"name": worst[0], "total": worst[1]} if worst else None,
        }

    models_meta = []
    for r in RUNS:
        cfg = runs[r["key"]]["config"]
        models_meta.append({
            "key": r["key"],
            "label": r["label"],
            "run_id": cfg["run_id"],
            "model": cfg.get("model"),
            "judge_model": cfg.get("judge_model"),
            "judge_models": cfg.get("judge_models") or (
                [cfg.get("judge_model")] if cfg.get("judge_model") else []
            ),
            "language": cfg.get("language"),
            "runtime": cfg.get("runtime"),
        })

    return {
        "generated": datetime.now(timezone.utc).isoformat(),
        "models": models_meta,
        "problems": problems_sorted,
        "problem_categories": problem_categories,
        "problem_groups": problem_groups,
        "scores": scores,
        "summary": summary,
    }


def aggregate_core_set(runs: dict[str, dict], core_spec: dict) -> dict:
    """Score a frozen comparison set with one identical judge.

    Unlike the full-run summary, this never uses each run's panel mean. Every
    usable row is read from the exact judge named in the Core-set manifest.
    Missing or failed renders contribute zero, and a model is rank-eligible
    only after all Core problems are settled.
    """
    judge_model = core_spec["scoring"]["judge"]
    groups: dict[str, list[str]] = core_spec["groups"]
    total_problems = sum(len(problems) for problems in groups.values())
    full_suite_size = max(len(run["rows"]) for run in runs.values())
    models = {}

    for meta in RUNS:
        key = meta["key"]
        run_rows = runs[key]["rows"]
        is_full_suite = len(run_rows) == full_suite_size
        group_scores = {}
        scored = 0
        render_fails = 0
        missing = 0

        for group, problems in groups.items():
            totals = []
            group_scored = 0
            group_fails = 0
            group_missing = 0
            for problem in problems:
                row = run_rows.get(problem)
                judge_scores = (row or {}).get("scores_by_judge") or {}
                vec = judge_scores.get(judge_model)
                if row and row.get("status") == "ok" and vec:
                    totals.append(sum(vec))
                    group_scored += 1
                    scored += 1
                else:
                    totals.append(0)
                    if row and row.get("status") == "render_fail":
                        group_fails += 1
                        render_fails += 1
                    else:
                        group_missing += 1
                        missing += 1
            group_scores[group] = {
                "score": sum(totals) / len(problems),
                "scored": group_scored,
                "render_fails": group_fails,
                "missing": group_missing,
                "pending": 0 if is_full_suite else group_missing,
                "zeroed_missing": group_missing if is_full_suite else 0,
                "total": len(problems),
            }

        group_means = [entry["score"] for entry in group_scores.values()]
        pending = 0 if is_full_suite else missing
        settled = total_problems - pending
        models[key] = {
            "label": meta["label"],
            "score": sum(group_means) / len(group_means),
            "groups": group_scores,
            "scored": scored,
            "render_fails": render_fails,
            "missing": missing,
            "pending": pending,
            "settled": settled,
            "total": total_problems,
            "eligible": pending == 0,
        }

    return {
        "name": core_spec["name"],
        "version": core_spec["version"],
        "purpose": core_spec["purpose"],
        "judge": judge_model,
        "groups": groups,
        "models": models,
    }


# ---------------------------------------------------------------------------
# Asset copying
# ---------------------------------------------------------------------------


def copy_run_report(run_meta: dict, primary_run_dir: Path) -> None:
    """Copy the PRIMARY run's detail report. Delta runs are not surfaced
    as detail reports — their problems are merged into the hub's
    per-problem table instead."""
    out = DOCS / run_meta["key"]
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for fname in ("benchmark_report.html", "benchmark_report.md"):
        src = primary_run_dir / fname
        if src.exists():
            target = out / fname
            if fname.endswith(".md"):
                text = src.read_text()
                target.write_text("\n".join(line.rstrip() for line in text.splitlines()) + "\n")
            else:
                shutil.copy2(src, target)
    src_imgs = primary_run_dir / "images"
    if src_imgs.exists():
        shutil.copytree(src_imgs, out / "images")


def copy_drawer_images(run_meta: dict, run_dirs: list[Path]) -> None:
    """Copy per-problem rendered images from EACH run_dir into
    docs/images/<model>/. Later run_dirs override earlier ones for the
    same filename."""
    dst = DOCS / "images" / run_meta["key"]
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    for run_dir in run_dirs:
        src = run_dir / "images"
        if not src.exists():
            continue
        for f in src.iterdir():
            if f.suffix.lower() == ".png":
                shutil.copy2(f, dst / f.name)


def copy_reference_images(problems: list[str]) -> dict[str, str]:
    """Copy reference.png files into docs/refs/. Return {problem: filename}."""
    dst = DOCS / "refs"
    if dst.exists():
        shutil.rmtree(dst)
    dst.mkdir(parents=True)
    out = {}
    for name in problems:
        ref = PROBLEMS_DIR / name / "reference.png"
        if ref.exists():
            target = dst / f"{name}.png"
            shutil.copy2(ref, target)
            out[name] = f"refs/{name}.png"
    return out


# ---------------------------------------------------------------------------
# HTML
# ---------------------------------------------------------------------------


def color_for_total(total: int | None) -> str:
    """Return an HSL color string for a total score 0..500. None => gray."""
    if total is None:
        return "#2a2a2a"
    # 0 -> red(0), 250 -> yellow(60), 500 -> green(120)
    t = max(0, min(500, total)) / 500.0
    hue = int(t * 120)
    return f"hsl({hue}, 60%, 35%)"


def pct_from_total(total: float | int | None) -> int | None:
    """Final-score percentage: (total - 200) / 300, clamped to 0..100.

    Below 200 collapses to 0% — judge floors are around 200 even for pure
    failures, so the interesting range is 200..500. None passes through.
    """
    if total is None:
        return None
    return max(0, min(100, round((total - 200) * 100 / 300)))


def bar_html(pct: int | None) -> str:
    """Inline bar markup. Empty string if no score."""
    if pct is None:
        return ""
    return f"<div class='barwrap'><div class='bar' style='width:{pct}%'></div></div>"


BASELINE_NOTE = (
    "Percentage = (score &minus; 200) / 300. The judges floor around 200 even "
    "for unrecognizable images, so the interesting range is 200&ndash;500."
)


def _hover_card(visible_html: str, title: str, body_html: str) -> str:
    """Wrap a cell in a hover card. Pure CSS, mirrors `.hoverimg`."""
    return (
        f"<span class='hoverdetail'>{visible_html}"
        f"<span class='card'>"
        f"<span class='ctitle'>{title}</span>"
        f"<span class='cbody'>{body_html}</span>"
        f"</span></span>"
    )


def _judge_breakdown_html(
    avg_total: float | None,
    judge_avgs: dict[str, float],
    judge_counts: dict[str, int],
    impute_label: str | None,
) -> str:
    """Per-judge X/500 list for a hover card. `impute_label` is the
    one-line note explaining how render fails entered the average
    (or None if they didn't)."""
    head = (
        f"<div class='ctotal'>{avg_total:.1f} / 500</div>"
        if avg_total is not None
        else "<div class='ctotal'>—</div>"
    )
    rows = []
    for jm, avg in judge_avgs.items():
        count = judge_counts.get(jm, 0)
        rows.append(
            f"<div class='crow'>"
            f"<span class='cname'>{judge_display_name(jm)}</span>"
            f"<span class='cval'>{avg:.1f} / 500</span>"
            f"<span class='ccount'>· {count} scored</span>"
            f"</div>"
        )
    impute = f"<div class='cnote'>{impute_label}</div>" if impute_label else ""
    legend = f"<div class='cnote'>{BASELINE_NOTE}</div>"
    return head + "".join(rows) + impute + legend


def avg_total_html(total: float | int | None) -> str:
    """Normalized-score percentage + bar. No raw X/500 — keeps the
    summary table scannable; raw scores live in per-model detail pages
    and in the hover card."""
    if total is None:
        return "—"
    pct = pct_from_total(total)
    return f"<span class='pctnum'>{pct}%</span>{bar_html(pct)}"


def fail_rate_html(fails: int, total: int) -> str:
    """Render-fail rate as a percentage with an inverted bar (fuller = worse).
    Treated as a score-shaped cell so eyes can compare it alongside the
    score columns."""
    if total <= 0:
        return "—"
    pct = round(fails * 100 / total)
    return (
        f"<span class='pctnum'>{pct}%</span>"
        f"<div class='barwrap'><div class='bar failbar' style='width:{pct}%'></div></div>"
    )


def find_image_filename(source_run_dir: Path, idx: int, problem: str) -> str | None:
    """Return the actual filename inside images/ for this problem, if present.

    `source_run_dir` is the specific run that produced this row (tracked
    on the row as `_source_run_dir`). Image filenames are
    `<NNN>_<problem>_result.png` where NNN is the *that-run's* problem
    index, not the merged-hub index.
    """
    src = source_run_dir / "images"
    if not src.exists():
        return None
    expected = f"{idx:03d}_{problem}_result.png"
    if (src / expected).exists():
        return expected
    # Fallback: scan for any file matching the problem name (in case the
    # source run's index for this problem differs from our enumeration).
    for f in src.iterdir():
        if f.suffix.lower() == ".png" and f.stem.endswith(f"_{problem}_result"):
            return f.name
    return None


def render_html(data: dict, runs: dict[str, dict], ref_map: dict[str, str]) -> str:
    """Render the hub index.html."""
    models = data["models"]
    problems = data["problems"]
    problem_categories = data["problem_categories"]
    problem_groups = data["problem_groups"]
    summary = data["summary"]
    scores = data["scores"]
    group_counts = {group: len(problem_groups.get(group, [])) for group in TOP_LEVEL_GROUPS}
    group_note = (
        f"{group_counts['Frontier']} frontier, "
        f"{group_counts['Reconstruction']} reconstruction, "
        f"{group_counts['Rest']} rest"
    )

    # Per-model image filename lookup so drawer image paths work even when
    # naming drift would otherwise break things.
    img_lookup: dict[str, dict[str, str | None]] = {}
    for m in models:
        run = runs[m["key"]]
        # Each row was tagged with its own source_run_dir during merge,
        # so the image path resolves correctly even when this problem
        # came from a delta run rather than the primary.
        img_lookup[m["key"]] = {}
        for p in problems:
            row = run["rows"].get(p)
            if not row:
                continue
            src = row.get("_source_run_dir")
            if src is None:
                continue
            img_lookup[m["key"]][p] = find_image_filename(src, row["index"], p)

    # --- frozen Core-set table -----
    core = data["core30"]
    core_models = list(core["models"].values())
    core_models.sort(key=lambda item: (item["eligible"], item["score"]), reverse=True)
    core_rows = []
    for item in core_models:
        score = item["score"]
        score_pct = pct_from_total(score)
        status = "ranked" if item["eligible"] else f"{item['pending']} pending"
        group_cells = []
        for group in ("Regular", "Frontier", "Reconstruction"):
            gs = item["groups"][group]
            group_cells.append(
                f"<td data-sortval='{gs['score']:.4f}'>"
                f"<strong>{gs['score']:.1f}</strong> / 500"
                f"<div class='dim'>{gs['scored']}/{gs['total']} scored"
                f"{f', {gs['render_fails']} fail' if gs['render_fails'] else ''}"
                f"{f', {gs['zeroed_missing']} missing→0' if gs['zeroed_missing'] else ''}"
                f"{f', {gs['pending']} pending' if gs['pending'] else ''}</div></td>"
            )
        core_rows.append(
            f"<tr>"
            f"<td class='mname'><strong>{item['label']}</strong></td>"
            f"<td class='avgcell' data-sortval='{score:.4f}'>"
            f"<span class='pctnum'>{score_pct}%</span> &middot; {score:.1f} / 500"
            f"{bar_html(score_pct)}</td>"
            f"{''.join(group_cells)}"
            f"<td>{item['settled']}/{item['total']}<div class='dim'>{status}</div></td>"
            f"</tr>"
        )
    core_html = "\n".join(core_rows)

    # --- model summary table -----
    # Three score-shaped columns, in order: avg-with-fails (most honest —
    # render fails count as 0), avg-of-judges (rendered-only), and
    # render-fail rate. Per-judge X/500 numbers and the 200-baseline
    # explanation live in per-cell hover cards.
    summary_rows = []
    for m in models:
        s = summary[m["key"]]
        # Partial/specialized runs belong in the frozen Core comparison, not
        # beside genuine full-suite runs.
        if s["total"] != len(problems):
            continue
        judge_avgs = s.get("avg_total_by_judge_filtered", {})
        judge_counts = s.get("judge_score_counts", {})
        avg_f_pct = avg_total_html(s["avg_total_filtered"])
        avg_z_pct = avg_total_html(s["avg_total_with_zeros"])
        fail_pct = fail_rate_html(s["permanent_fail"], s["total"])
        avg_f_html = _hover_card(
            avg_f_pct,
            "Score excluding failures (rendered only)",
            _judge_breakdown_html(s["avg_total_filtered"], judge_avgs, judge_counts, None),
        )
        avg_z_html = _hover_card(
            avg_z_pct,
            "Score (each render fail counts as 0)",
            _judge_breakdown_html(
                s["avg_total_with_zeros"],
                judge_avgs,
                judge_counts,
                f"Per-judge rows above are rendered-only. Top number averages over all {s['total']} problems with 0 imputed for the {s['permanent_fail']} render fails.",
            ),
        )
        fail_html = _hover_card(
            fail_pct,
            "Render fails",
            (
                f"<div class='ctotal'>{s['permanent_fail']} of {s['total']} problems</div>"
                "<div class='cnote'>A render fail = the WGSL shader the model produced did not compile or "
                "the shader_harness exited non-zero. These count as 0 in the &ldquo;Score&rdquo; column and "
                "are excluded from &ldquo;Score excluding failures&rdquo;.</div>"
            ),
        )
        best = s["best_problem"]
        worst = s["worst_problem"]
        worst_s = f"{worst['name']} ({worst['total']})" if worst else "—"
        # Best gets a hover-preview tooltip showing that problem's rendered
        # image. Image filename is whatever build_image_lookup found for
        # this (model, problem) tuple.
        if best:
            best_img = img_lookup.get(m["key"], {}).get(best["name"])
            label = f"{best['name']} ({best['total']})"
            if best_img:
                best_s = (
                    f"<span class='hoverimg'>{label}"
                    f"<img src='images/{m['key']}/{best_img}' alt='{best['name']}' loading='lazy'>"
                    f"</span>"
                )
            else:
                best_s = label
        else:
            best_s = "—"
        # Numeric sort keys; missing values sink to the bottom on
        # descending sort (and float to top on ascending) by using -inf.
        sort_score = s["avg_total_with_zeros"] if s["avg_total_with_zeros"] is not None else float("-inf")
        sort_filtered = s["avg_total_filtered"] if s["avg_total_filtered"] is not None else float("-inf")
        sort_fail = (s["permanent_fail"] / s["total"]) if s["total"] else 0.0
        summary_rows.append(
            f"<tr>"
            f"<td class='mname'><strong>{m['label']}</strong></td>"
            f"<td class='avgcell' data-sortval='{sort_score}'>{avg_z_html}</td>"
            f"<td class='avgcell' data-sortval='{sort_filtered}'>{avg_f_html}</td>"
            f"<td class='avgcell' data-sortval='{sort_fail}'>{fail_html}</td>"
            f"<td class='nowrap'>{best_s}</td>"
            f"<td>{worst_s}</td>"
            f"<td class='nowrap'><a href='{m['key']}/benchmark_report.html'>View detail report &rarr;</a></td>"
            f"</tr>"
        )
    summary_html = "\n".join(summary_rows)

    # --- comparison table -----
    header_cells = "".join(f"<th class='mh'>{m['label']}</th>" for m in models)

    body_rows = []
    for group in TOP_LEVEL_GROUPS:
        group_problems = problem_groups.get(group, [])
        if not group_problems:
            continue
        body_rows.append(
            f"<tr class='group-row'><td colspan='{1 + len(models)}'>"
            f"{group}<span>{len(group_problems)} problems</span>"
            f"</td></tr>"
        )
        for problem in group_problems:
            category = problem_categories.get(problem, "Uncategorized")
            tag = group if group != "Rest" else category
            cells = []
            for m in models:
                cell = scores[problem][m["key"]]
                total = cell["total"]
                status = cell["status"]
                color = color_for_total(total if status == "ok" else None)
                if total is not None:
                    pct = pct_from_total(total)
                    # Multi-judge tag: tiny "(N)" badge so users can tell at a
                    # glance which cells are panel-mean vs single-judge.
                    njudges = len(cell.get("scores_by_judge") or {})
                    judge_tag = f"<span class='cellpct'> · {njudges}j</span>" if njudges > 1 else ""
                    disp = (
                        f"<div class='cellnum'>{total}<span class='cellpct'> · {pct}%</span>{judge_tag}</div>"
                        f"{bar_html(pct)}"
                    )
                else:
                    disp = "render fail" if status == "render_fail" else "—"
                cells.append(
                    f"<td class='cell' style='background:{color}' "
                    f"data-problem='{problem}' data-model='{m['key']}'>{disp}</td>"
                )
            ref_attr = f" data-ref='{ref_map[problem]}'" if problem in ref_map else ""
            body_rows.append(
                f"<tr class='prow' data-problem='{problem}'{ref_attr}>"
                f"<td class='pname'><span class='ptext'>{problem}</span><span class='tag'>{tag}</span></td>"
                f"{''.join(cells)}"
                f"</tr>"
            )
    body_html = "\n".join(body_rows)

    # JSON payloads embedded for the drawer JS (avoids a fetch — works on file://)
    image_payload = json.dumps(img_lookup)
    scores_payload = json.dumps({
        p: {
            m["key"]: scores[p][m["key"]]
            for m in models
        }
        for p in problems
    })
    refs_payload = json.dumps(ref_map)
    models_payload = json.dumps([{"key": m["key"], "label": m["label"]} for m in models])
    categories_payload = json.dumps(CATEGORY_LABELS)

    generated = data["generated"]

    html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Shader Benchmark Results</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  :root {{
    --bg: #0f1115;
    --panel: #161922;
    --line: #262a36;
    --text: #d8dde7;
    --dim: #8a93a4;
    --accent: #7aa6ff;
  }}
  html, body {{ margin: 0; padding: 0; background: var(--bg); color: var(--text); }}
  body {{ font: 14px/1.5 ui-sans-serif, -apple-system, system-ui, "Segoe UI", Helvetica, Arial, sans-serif; }}
  .wrap {{ max-width: 1180px; margin: 0 auto; padding: 32px 24px 80px; }}
  h1 {{ font-size: 26px; margin: 0 0 6px; letter-spacing: -0.01em; }}
  /* hero header: fixed 860x320, centered. Source is 1672x941 (~1.78:1)
     so object-fit:fill stretches it ~50% horizontally to fit the box. */
  img.hero {{ display: block; width: 860px; height: 320px; max-width: 100%; object-fit: fill; margin: 0 auto 14px; border-radius: 6px; }}
  h2 {{ font-size: 18px; margin: 36px 0 12px; letter-spacing: -0.01em; }}
  .lead {{ color: var(--dim); margin: 0 0 4px; }}
  .sub  {{ color: var(--dim); font-size: 12px; margin: 0; }}
  a {{ color: var(--accent); text-decoration: none; }}
  a:hover {{ text-decoration: underline; }}
  /* NOTE: do NOT use overflow:hidden here. The hover-preview <img> in the
     model summary is absolute-positioned and would get clipped to the
     table boundary. The border-radius still applies to the table outline;
     row backgrounds may bleed slightly past the rounded corners but it's
     visually fine. */
  table {{ width: 100%; border-collapse: collapse; background: var(--panel); border: 1px solid var(--line); border-radius: 8px; }}
  th, td {{ padding: 8px 10px; border-bottom: 1px solid var(--line); text-align: left; vertical-align: top; }}
  th {{ background: #1c2030; font-weight: 600; color: #c8cfdb; font-size: 12px; text-transform: uppercase; letter-spacing: 0.04em; }}
  td.dim, .dim {{ color: var(--dim); font-size: 12px; }}
  /* model summary: keep the model name on a single row */
  td.mname {{ white-space: nowrap; min-width: 220px; }}
  /* hover-preview tooltip: shows a thumbnail of the referenced shader
     when hovering the best-cell text. Pure CSS, no JS. */
  .hoverimg {{ position: relative; cursor: help; border-bottom: 1px dotted var(--dim); }}
  .hoverimg > img {{
    display: none;
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 10;
    margin-top: 6px;
    width: 280px;
    height: auto;
    border: 1px solid var(--line);
    border-radius: 4px;
    background: #000;
    box-shadow: 0 6px 20px rgba(0,0,0,.6);
  }}
  .hoverimg:hover > img {{ display: block; }}
  /* hover-detail card on the avg cells: shows per-judge X/500 + the
     200-baseline explanation. Pure CSS, mirrors `.hoverimg`. */
  .hoverdetail {{ position: relative; cursor: help; display: inline-block; }}
  .hoverdetail > .card {{
    display: none;
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 10;
    margin-top: 6px;
    width: 280px;
    padding: 10px 12px;
    border: 1px solid var(--line);
    border-radius: 6px;
    background: #11151f;
    box-shadow: 0 6px 20px rgba(0,0,0,.6);
    color: #e6ebf5;
    font-weight: 400;
    font-size: 12px;
    line-height: 1.45;
    text-transform: none;
    letter-spacing: 0;
    white-space: normal;
  }}
  .hoverdetail:hover > .card {{ display: block; }}
  .card .ctitle {{ display: block; font-weight: 600; color: #c8cfdb; font-size: 11px; text-transform: uppercase; letter-spacing: .04em; margin-bottom: 6px; }}
  .card .ctotal {{ font-weight: 600; font-size: 14px; color: #fff; margin-bottom: 6px; }}
  .card .crow {{ display: flex; gap: 6px; align-items: baseline; margin-top: 2px; }}
  .card .cname {{ flex: 1; color: #c8cfdb; }}
  .card .cval {{ font-variant-numeric: tabular-nums; }}
  .card .ccount {{ color: var(--dim); font-size: 11px; }}
  .card .cnote {{ color: var(--dim); font-size: 11px; margin-top: 8px; }}
  /* comparison table */
  table.cmp td.cell {{ text-align: center; cursor: pointer; font-weight: 600; min-width: 110px; color: #fff; text-shadow: 0 1px 2px rgba(0,0,0,.4); padding-bottom: 12px; }}
  table.cmp td.cell:hover {{ outline: 2px solid var(--accent); outline-offset: -2px; }}
  table.cmp td.pname {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; color: #c0c8d6; max-width: 280px; word-break: break-word; }}
  table.cmp th.mh {{ text-align: center; }}
  /* "% of way from 200 to 500" bars. Live in score cells (per-problem)
     and in the model-summary avg cells. */
  .cellnum {{ line-height: 1.1; }}
  .cellpct {{ font-weight: 400; opacity: .85; font-size: 11px; }}
  .barwrap {{ margin-top: 4px; height: 4px; background: rgba(0,0,0,.4); border-radius: 2px; overflow: hidden; }}
  .bar {{ height: 100%; background: rgba(255,255,255,.78); border-radius: 2px; }}
  td.nowrap {{ white-space: nowrap; }}
  /* avg cells: wide so the score bars are scannable at a glance. */
  td.avgcell {{ min-width: 240px; white-space: nowrap; }}
  td.avgcell .pctnum {{ font-weight: 500; font-size: 13px; }}
  td.avgcell .barwrap {{ background: #222633; margin-top: 6px; height: 6px; width: 220px; max-width: 100%; }}
  td.avgcell .bar {{ background: var(--accent); }}
  /* fail-rate bar: same shape as score bars but red, since fuller = worse. */
  td.avgcell .bar.failbar {{ background: #c64a4a; }}
  /* sortable headers in the model summary */
  th.sortable {{ cursor: pointer; user-select: none; }}
  th.sortable:hover {{ color: #fff; }}
  th.sortable .arrow {{ display: inline-block; margin-left: 4px; opacity: .35; font-size: 10px; }}
  th.sortable.sort-asc .arrow,
  th.sortable.sort-desc .arrow {{ opacity: 1; color: var(--accent); }}
  .group-row td {{
    background: #141927;
    color: #f3f6fb;
    font-weight: 700;
    letter-spacing: .03em;
    text-transform: uppercase;
    border-top: 2px solid var(--line);
  }}
  .group-row span {{ color: var(--dim); font-weight: 500; margin-left: 10px; text-transform: none; letter-spacing: 0; }}
  .ptext {{ display: block; }}
  .tag {{
    display: inline-block;
    margin-top: 4px;
    padding: 2px 6px;
    border: 1px solid var(--line);
    border-radius: 999px;
    color: var(--dim);
    font-family: Inter, system-ui, sans-serif;
    font-size: 10px;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: .04em;
    word-break: normal;
  }}
  /* drawer */
  tr.drawer-row td {{ padding: 0; background: #0c0e14; }}
  .drawer {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 16px; padding: 18px; border-top: 1px solid var(--line); }}
  .drawer .panel {{ background: var(--panel); border: 1px solid var(--line); border-radius: 6px; padding: 12px; }}
  .drawer h3 {{ margin: 0 0 8px; font-size: 13px; color: #c8cfdb; }}
  .drawer img {{ width: 100%; height: auto; image-rendering: auto; border-radius: 4px; background: #000; }}
  .drawer .ph {{ width: 100%; aspect-ratio: 1/1; display: flex; align-items: center; justify-content: center; border: 1px dashed var(--line); border-radius: 4px; color: var(--dim); font-size: 12px; }}
  .drawer ul {{ margin: 6px 0 0; padding: 0 0 0 16px; font-size: 12px; }}
  .drawer li {{ margin: 2px 0; }}
  .drawer .stotal {{ font-weight: 600; margin-top: 6px; color: #fff; }}
  /* legend */
  .legend {{ display: flex; gap: 10px; align-items: center; font-size: 12px; color: var(--dim); margin: 6px 0 12px; }}
  .legend .swatch {{ display: inline-block; width: 18px; height: 12px; border-radius: 2px; }}
  footer {{ margin-top: 48px; color: var(--dim); font-size: 12px; }}
</style>
</head>
<body>
<div class="wrap">
  <img class="hero" src="header.png" alt="Shader bench">
  <p class="lead">Frontier coding agents generating WGSL shaders from text prompts on {len(problems)} mathematical visualization problems ({group_note}). Scored 0&ndash;100 across five categories against the rendered image.</p>

  <h2>{core["name"]} same-problem comparison</h2>
  <p class="lead">A <a href="core30.json">frozen, capability-balanced set</a> of 10 regular, 10 frontier, and 10 reconstruction problems. Every score below uses the same <strong>Codex GPT-5.5 high</strong> judge; failures count as zero. Models with pending problems are shown for transparency but are not ranked.</p>
  <table id="coresum">
    <thead>
      <tr>
        <th>Model</th><th>Equal-weight score</th>
        <th>Regular</th><th>Frontier</th><th>Reconstruction</th><th>Coverage</th>
      </tr>
    </thead>
    <tbody>{core_html}</tbody>
  </table>

  <h2>Full 130-problem leaderboard</h2>
  <p class="lead">Only models whose published run defines all {len(problems)} problems appear here. Partial runs such as Fable remain visible in the Core comparison and per-problem table, but cannot lead the full-suite ranking.</p>
  <table id="modelsum">
    <thead>
      <tr>
        <th>Model</th>
        <th class="sortable" data-sort="num" data-default-dir="desc">Score<span class="arrow">▼</span></th>
        <th class="sortable" data-sort="num">Score excluding failures<span class="arrow">▼</span></th>
        <th class="sortable" data-sort="num">Render fails<span class="arrow">▼</span></th>
        <th>Best</th><th>Worst</th><th>Detail</th>
      </tr>
    </thead>
    <tbody>{summary_html}</tbody>
  </table>

  <h2>Per-problem comparison</h2>
  <div class="legend">
    <span class="swatch" style="background:hsl(0,60%,35%)"></span> low
    <span class="swatch" style="background:hsl(60,60%,35%)"></span> mid
    <span class="swatch" style="background:hsl(120,60%,35%)"></span> high
    <span style="margin-left:8px">— click any cell to expand reference + rendered shaders + sub-scores. Problems are split into Frontier, Reconstruction, and Rest. Score is sum of 5 categories (max 500). Bar shows final score: <code>(score &minus; 200) / 300</code>, clamped 0&ndash;100%.</span>
  </div>
  <table class="cmp">
    <thead>
      <tr><th>Problem</th>{header_cells}</tr>
    </thead>
    <tbody>{body_html}</tbody>
  </table>

  <footer>
    Generated {generated}.
    Source: <a href="https://github.com/nbardy/shader_benchmark">shader_benchmark</a>.
    Aggregated data: <a href="all_scores.json">all_scores.json</a>.
  </footer>
</div>
<script>
(function(){{
  const IMAGES   = {image_payload};
  const SCORES   = {scores_payload};
  const REFS     = {refs_payload};
  const MODELS   = {models_payload};
  const CATS     = {categories_payload};

  function el(tag, attrs, children){{
    const e = document.createElement(tag);
    if (attrs) for (const [k,v] of Object.entries(attrs)) {{
      if (k === 'class') e.className = v;
      else if (k === 'style') e.setAttribute('style', v);
      else e.setAttribute(k, v);
    }}
    (children||[]).forEach(c => e.appendChild(typeof c === 'string' ? document.createTextNode(c) : c));
    return e;
  }}

  function buildPanel(modelKey, modelLabel, problem){{
    const p = el('div', {{class:'panel'}});
    p.appendChild(el('h3', {{}}, [modelLabel]));
    const fname = IMAGES[modelKey] && IMAGES[modelKey][problem];
    if (fname) {{
      p.appendChild(el('img', {{src: 'images/' + modelKey + '/' + fname, alt: modelLabel + ' — ' + problem, loading:'lazy'}}));
    }} else {{
      p.appendChild(el('div', {{class:'ph'}}, ['no image (render fail)']));
    }}
    const cell = SCORES[problem][modelKey];
    if (cell.scores) {{
      const ul = el('ul');
      cell.scores.forEach((s,i) => ul.appendChild(el('li', {{}}, [CATS[i] + ': ' + s])));
      p.appendChild(ul);
      const sbj = cell.scores_by_judge || {{}};
      const judgeNames = Object.keys(sbj);
      if (judgeNames.length > 1) {{
        // Show per-judge totals when more than one judge scored — the
        // displayed `total` is the panel mean and users may want to see
        // which judge was harshest/most generous.
        const jul = el('ul', {{class:'judges'}});
        judgeNames.forEach(jm => {{
          const t = sbj[jm].reduce((a,b) => a+b, 0);
          jul.appendChild(el('li', {{}}, [jm + ': ' + t + ' / 500']));
        }});
        p.appendChild(el('div', {{class:'dim'}}, ['Per-judge totals (mean shown above):']));
        p.appendChild(jul);
      }}
      const meanLabel = judgeNames.length > 1
        ? 'Mean total: ' + cell.total + ' / 500 (' + judgeNames.length + ' judges)'
        : 'Total: ' + cell.total + ' / 500';
      p.appendChild(el('div', {{class:'stotal'}}, [meanLabel]));
    }} else {{
      p.appendChild(el('div', {{class:'dim'}}, ['Status: ' + cell.status]));
    }}
    return p;
  }}

  // --- model-summary sortable headers ---
  // Three columns are sortable: Score (default desc), Score-excluding-
  // failures, and Render-fails. Click toggles direction; clicking a
  // different column starts in its preferred default direction (desc
  // for scores, asc for fails — fewer fails is better).
  (function setupSummarySort(){{
    const tbl = document.getElementById('modelsum');
    if (!tbl) return;
    const tbody = tbl.tBodies[0];
    const heads = Array.from(tbl.tHead.rows[0].cells);
    const sortables = heads.map((th, i) => th.classList.contains('sortable') ? i : -1).filter(i => i >= 0);

    function sortBy(colIdx, dir){{
      const rows = Array.from(tbody.rows);
      rows.sort((a, b) => {{
        const av = parseFloat(a.cells[colIdx].dataset.sortval);
        const bv = parseFloat(b.cells[colIdx].dataset.sortval);
        const aOk = isFinite(av), bOk = isFinite(bv);
        if (!aOk && !bOk) return 0;
        if (!aOk) return 1;     // missing always sinks
        if (!bOk) return -1;
        return dir === 'asc' ? (av - bv) : (bv - av);
      }});
      rows.forEach(r => tbody.appendChild(r));
      heads.forEach(h => h.classList.remove('sort-asc', 'sort-desc'));
      const th = heads[colIdx];
      th.classList.add(dir === 'asc' ? 'sort-asc' : 'sort-desc');
      const arrow = th.querySelector('.arrow');
      if (arrow) arrow.textContent = dir === 'asc' ? '▲' : '▼';
    }}

    sortables.forEach(i => {{
      const th = heads[i];
      th.addEventListener('click', () => {{
        const cur = th.classList.contains('sort-desc') ? 'desc'
                  : th.classList.contains('sort-asc')  ? 'asc'
                  : (th.dataset.defaultDir || 'desc');
        // First click on a fresh column → its default direction.
        // Subsequent clicks on the active column → toggle.
        const nextDir = th.classList.contains('sort-desc') ? 'asc'
                      : th.classList.contains('sort-asc')  ? 'desc'
                      : cur;
        sortBy(i, nextDir);
      }});
    }});

    // Default: Score column (first sortable) descending.
    if (sortables.length) sortBy(sortables[0], 'desc');
  }})();

  document.querySelectorAll('tr.prow .cell').forEach(td => {{
    td.addEventListener('click', function(ev){{
      const tr = td.closest('tr.prow');
      const problem = tr.dataset.problem;
      const next = tr.nextElementSibling;
      if (next && next.classList.contains('drawer-row') && next.dataset.problem === problem) {{
        next.remove();
        return;
      }}
      // Close any other open drawer.
      document.querySelectorAll('tr.drawer-row').forEach(d => d.remove());

      const drawer = el('div', {{class:'drawer'}});
      // Reference panel if present.
      const ref = REFS[problem];
      if (ref) {{
        const p = el('div', {{class:'panel'}});
        p.appendChild(el('h3', {{}}, ['Reference image']));
        p.appendChild(el('img', {{src: ref, alt: 'reference', loading:'lazy'}}));
        drawer.appendChild(p);
      }}
      MODELS.forEach(m => drawer.appendChild(buildPanel(m.key, m.label, problem)));

      const colspan = 1 + MODELS.length;
      const dtr = el('tr', {{class:'drawer-row', 'data-problem': problem}});
      const dtd = el('td', {{colspan: String(colspan)}});
      dtd.appendChild(drawer);
      dtr.appendChild(dtd);
      tr.parentNode.insertBefore(dtr, tr.nextSibling);
    }});
  }});
}})();
</script>
</body>
</html>
"""
    return html


# ---------------------------------------------------------------------------
# Driver
# ---------------------------------------------------------------------------


def main() -> None:
    DOCS.mkdir(exist_ok=True)
    core_spec = json.loads(CORE_SET_PATH.read_text())

    runs: dict[str, dict] = {}
    for r in RUNS:
        run_dirs: list[Path] = []
        for d in r["run_dirs"]:
            p = BENCH_DIR / d
            if not p.exists():
                # Skip deltas that haven't run yet rather than hard-fail —
                # lets the build proceed before the new delta runs finish.
                print(f"  ⚠ skipping missing run dir: {d}")
                continue
            run_dirs.append(p)
        if not run_dirs:
            raise SystemExit(f"no run dirs found for model {r['key']}")
        runs[r["key"]] = load_runs(run_dirs)

    # Use the union of problem names across all rows (which may include
    # problems only present in delta runs), sorted by top-level group.
    problem_set: set[str] = set()
    for run in runs.values():
        problem_set.update(run["rows"].keys())
    problem_categories = load_problem_categories(sorted(problem_set))
    problems_sorted = grouped_problem_order(problem_set, problem_categories)

    data = aggregate(runs, problems_sorted, problem_categories)
    data["core30"] = aggregate_core_set(runs, core_spec)
    (DOCS / "all_scores.json").write_text(json.dumps(data, indent=2))
    (DOCS / "core30.json").write_text(json.dumps(core_spec, indent=2) + "\n")

    # Copy per-model detail reports (primary run only) + drawer images
    # (merged across all run_dirs).
    for r in RUNS:
        copy_run_report(r, runs[r["key"]]["run_dir"])
        copy_drawer_images(r, runs[r["key"]]["all_run_dirs"])

    # Copy reference images for image-reproduction problems.
    ref_map = copy_reference_images(problems_sorted)

    # Render the hub.
    html = render_html(data, runs, ref_map)
    (DOCS / "index.html").write_text(html)

    # README
    (DOCS / "README.md").write_text(
        "# docs/\n\n"
        "Self-contained static site for the shader benchmark.\n\n"
        "Open `index.html` to browse. Auto-generated from "
        "`llm_harness/benchmark_run_output/` by `tools/build_docs.py`. Don't edit by hand.\n"
    )

    # Print a quick summary.
    for r in RUNS:
        s = data["summary"][r["key"]]
        print(f"{r['key']:30s} ok={s['ok']:3d}  fails={s['permanent_fail']:3d}  avg_ok={s['avg_total_filtered']}")
    print(f"wrote {DOCS}/index.html")


if __name__ == "__main__":
    main()
