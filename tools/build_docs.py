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
DOCS = REPO / "docs"

# Three completed runs we publish. Order = column order on the hub.
RUNS = [
    {
        "key": "claude-opus-4-7",
        "label": "Claude Opus 4.7",
        "run_dir": "65ab97ac_cli_claude_claude-opus-4-7_20260427_183924",
    },
    {
        "key": "gemini-3.1-pro-preview",
        "label": "Gemini 3.1-pro-preview",
        "run_dir": "f995b01e_cli_gemini_20260427_184028",
    },
    {
        "key": "codex-gpt-5.5-high",
        "label": "Codex GPT-5.5 high",
        "run_dir": "68ca3b4b_cli_codex_gpt-5.5_high_20260428_170724",
    },
]

CATEGORY_LABELS = [
    "Mathematical Accuracy",
    "Visual Quality",
    "Color Implementation",
    "Geometric Completeness",
    "Reference Elements",
]


# ---------------------------------------------------------------------------
# Data extraction
# ---------------------------------------------------------------------------


def load_run(run_dir: Path) -> dict:
    """Return canonical run record with config + per-problem rows.

    Status for a problem is one of:
      "ok"          results.json has 5 nonzero scores AND has_image (i.e. judged)
      "render_fail" render stage failed (any permanent flag or status=failed)
      "missing"     no checkpoint / no results.json / not judged
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
            "has_image": False,
            "status": "missing",
            "index": idx,
        }

        # Render-fail detection from checkpoint
        is_render_fail = False
        if cp_path.exists():
            try:
                cp = json.loads(cp_path.read_text())
                stages = cp.get("stages", {})
                for stage, val in stages.items():
                    if val.get("status") == "failed":
                        is_render_fail = True
                    data = val.get("data") or {}
                    if isinstance(data, dict) and data.get("permanent") is True:
                        is_render_fail = True
            except Exception:
                pass

        if results_path.exists():
            try:
                r = json.loads(results_path.read_text())
                scores = r.get("scores")
                has_img = bool(r.get("has_image")) and image_path.exists()
                # Treat as ok only if we have 5 scores, all > 0, AND an image.
                if (
                    isinstance(scores, list)
                    and len(scores) == 5
                    and all(isinstance(s, (int, float)) for s in scores)
                    and any(s > 0 for s in scores)
                    and has_img
                    and r.get("status") == "completed"
                ):
                    row["scores"] = [int(s) for s in scores]
                    row["total"] = sum(int(s) for s in scores)
                    row["has_image"] = True
                    row["status"] = "ok"
                else:
                    # judged with zeros, or no image, or status not completed
                    row["status"] = "render_fail" if is_render_fail else "missing"
                    row["has_image"] = has_img
            except Exception:
                row["status"] = "render_fail" if is_render_fail else "missing"
        else:
            row["status"] = "render_fail" if is_render_fail else "missing"

        rows[name] = row

    return {
        "config": cfg,
        "rows": rows,
        "run_dir": run_dir,
    }


def aggregate(runs: dict[str, dict], problems_sorted: list[str]) -> dict:
    """Produce the all_scores.json structure."""
    scores = {}
    for name in problems_sorted:
        scores[name] = {}
        for key, run in runs.items():
            r = run["rows"].get(name) or {
                "scores": None,
                "total": None,
                "has_image": False,
                "status": "missing",
            }
            scores[name][key] = {
                "scores": r["scores"],
                "total": r["total"],
                "has_image": r["has_image"],
                "status": r["status"],
            }

    summary = {}
    for key, run in runs.items():
        rows = run["rows"]
        ok_totals = [r["total"] for r in rows.values() if r["status"] == "ok"]
        all_totals = [(r["total"] or 0) for r in rows.values()]
        ok_count = sum(1 for r in rows.values() if r["status"] == "ok")
        fail_count = sum(1 for r in rows.values() if r["status"] == "render_fail")
        # missing_count = total - ok - fail (kept implicit)

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
            "language": cfg.get("language"),
            "runtime": cfg.get("runtime"),
        })

    return {
        "generated": datetime.now(timezone.utc).isoformat(),
        "models": models_meta,
        "problems": problems_sorted,
        "scores": scores,
        "summary": summary,
    }


# ---------------------------------------------------------------------------
# Asset copying
# ---------------------------------------------------------------------------


def copy_run_report(run_meta: dict, run_dir: Path) -> None:
    out = DOCS / run_meta["key"]
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)
    for fname in ("benchmark_report.html", "benchmark_report.md"):
        src = run_dir / fname
        if src.exists():
            shutil.copy2(src, out / fname)
    src_imgs = run_dir / "images"
    if src_imgs.exists():
        shutil.copytree(src_imgs, out / "images")


def copy_drawer_images(run_meta: dict, run_dir: Path) -> None:
    """Copy per-problem rendered images into docs/images/<model>/ for the drawer."""
    src = run_dir / "images"
    dst = DOCS / "images" / run_meta["key"]
    if dst.exists():
        shutil.rmtree(dst)
    if not src.exists():
        return
    dst.mkdir(parents=True)
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


def find_image_filename(run_dir: Path, idx: int, problem: str) -> str | None:
    """Return the actual filename inside images/ for this problem, if present."""
    src = run_dir / "images"
    if not src.exists():
        return None
    expected = f"{idx:03d}_{problem}_result.png"
    if (src / expected).exists():
        return expected
    return None


def render_html(data: dict, runs: dict[str, dict], ref_map: dict[str, str]) -> str:
    """Render the hub index.html."""
    models = data["models"]
    problems = data["problems"]
    summary = data["summary"]
    scores = data["scores"]

    # Per-model image filename lookup so drawer image paths work even when
    # naming drift would otherwise break things.
    img_lookup: dict[str, dict[str, str | None]] = {}
    for m in models:
        run = runs[m["key"]]
        run_dir = run["run_dir"]
        idx_for = {p: run["rows"][p]["index"] for p in problems if p in run["rows"]}
        img_lookup[m["key"]] = {
            p: find_image_filename(run_dir, idx_for[p], p) for p in problems if p in idx_for
        }

    # --- model summary table -----
    summary_rows = []
    for m in models:
        s = summary[m["key"]]
        avg_f_raw = s["avg_total_filtered"]
        avg_z_raw = s["avg_total_with_zeros"]
        avg_f = f"{avg_f_raw:.1f}" if avg_f_raw is not None else "—"
        avg_z = f"{avg_z_raw:.1f}" if avg_z_raw is not None else "—"
        avg_f_pct = pct_from_total(avg_f_raw)
        avg_z_pct = pct_from_total(avg_z_raw)
        avg_f_html = (
            f"{avg_f} / 500 <span class='pct'>{avg_f_pct}%</span>{bar_html(avg_f_pct)}"
            if avg_f_pct is not None else "—"
        )
        avg_z_html = (
            f"{avg_z} / 500 <span class='pct'>{avg_z_pct}%</span>{bar_html(avg_z_pct)}"
            if avg_z_pct is not None else "—"
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
        summary_rows.append(
            f"<tr>"
            f"<td class='mname'><strong>{m['label']}</strong></td>"
            f"<td>{s['ok']}</td>"
            f"<td>{s['permanent_fail']}</td>"
            f"<td class='avgcell'>{avg_f_html}</td>"
            f"<td class='avgcell'>{avg_z_html}</td>"
            f"<td class='nowrap'>{best_s}</td>"
            f"<td>{worst_s}</td>"
            f"<td class='nowrap'><a href='{m['key']}/benchmark_report.html'>View detail report &rarr;</a></td>"
            f"</tr>"
        )
    summary_html = "\n".join(summary_rows)

    # --- comparison table -----
    header_cells = "".join(f"<th class='mh'>{m['label']}</th>" for m in models)

    body_rows = []
    for problem in problems:
        cells = []
        for m in models:
            cell = scores[problem][m["key"]]
            total = cell["total"]
            status = cell["status"]
            color = color_for_total(total if status == "ok" else None)
            if total is not None:
                pct = pct_from_total(total)
                disp = (
                    f"<div class='cellnum'>{total}<span class='cellpct'> · {pct}%</span></div>"
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
            f"<td class='pname'>{problem}</td>"
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
  td.avgcell {{ min-width: 140px; white-space: nowrap; }}
  td.avgcell .pct {{ color: var(--dim); font-size: 12px; margin-left: 4px; }}
  td.avgcell .barwrap {{ background: #222633; }}
  td.avgcell .bar {{ background: var(--accent); }}
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
  <h1>Shader Benchmark</h1>
  <p class="lead">Three frontier coding agents generating WGSL shaders from text prompts on 107 mathematical visualization problems. Scored 0&ndash;100 across five categories by an LLM judge against the rendered image.</p>
  <p class="sub">Generation and judging both ran on subscription CLIs (Claude Code, Gemini CLI, Codex CLI). Direct API spend: <strong>$0</strong>.</p>

  <h2>Model summary</h2>
  <table>
    <thead>
      <tr>
        <th>Model</th><th>OK</th><th>Render fails</th>
        <th>Avg total (ok)</th><th>Avg total (fails=0)</th>
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
    <span style="margin-left:8px">— click any cell to expand reference + rendered shaders + sub-scores. Score is sum of 5 categories (max 500). Bar shows final score: <code>(score &minus; 200) / 300</code>, clamped 0&ndash;100%.</span>
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
      p.appendChild(el('div', {{class:'stotal'}}, ['Total: ' + cell.total + ' / 500']));
    }} else {{
      p.appendChild(el('div', {{class:'dim'}}, ['Status: ' + cell.status]));
    }}
    return p;
  }}

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

    runs: dict[str, dict] = {}
    for r in RUNS:
        run_dir = BENCH_DIR / r["run_dir"]
        if not run_dir.exists():
            raise SystemExit(f"missing run dir: {run_dir}")
        runs[r["key"]] = load_run(run_dir)

    # Use the union of problem names across configs, sorted. They should match.
    problem_set: set[str] = set()
    for run in runs.values():
        problem_set.update(run["config"]["problems"])
    problems_sorted = sorted(problem_set)

    data = aggregate(runs, problems_sorted)
    (DOCS / "all_scores.json").write_text(json.dumps(data, indent=2))

    # Copy per-model detail reports + images they reference.
    for r in RUNS:
        copy_run_report(r, runs[r["key"]]["run_dir"])
        copy_drawer_images(r, runs[r["key"]]["run_dir"])

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
