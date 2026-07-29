#!/usr/bin/env python3
"""Backfill missing panel judges across one or more existing benchmark runs.

The harness itself is panel-aware — adding a judge to a previously-completed
run and re-running it will only execute the new judge against the cached
render images. This script is a thin orchestrator over that: for each
target run it invokes the harness in resume mode with the requested panel.

Usage:
  # Backfill claude+gemini against the three published runs (codex already done):
  python rejudge.py --panel cli/codex:gpt-5.5:high cli/claude:claude-opus-4-7 google/gemini-2.5-pro \\
                    --runs 65ab97ac_cli_claude_claude-opus-4-7_20260427_183924 \\
                           f995b01e_cli_gemini_20260427_184028 \\
                           68ca3b4b_cli_codex_gpt-5.5_high_20260428_170724

  # Or backfill EVERY run under benchmark_run_output/ (use --all):
  python rejudge.py --panel cli/codex:gpt-5.5:high cli/claude:claude-opus-4-7 google/gemini-2.5-pro --all

  # Dry-run — show what would be invoked without touching judges or spending tokens:
  python rejudge.py --panel ... --runs ... --dry-run

The script stops on the first failed run (so a quota wall on judge N+1 doesn't
silently destroy the rest of the panel for run N) — you can resume any run
individually with the harness CLI directly.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
from pathlib import Path
from typing import List

from benchmark_harness import BenchmarkHarness
from judge_panel import judge_stage_name, missing_judges, scores_by_judge_from_stages

REPO = Path(__file__).resolve().parent.parent
BENCH_DIR = REPO / "llm_harness" / "benchmark_run_output"


def summarize_run(run_dir: Path, panel: List[str]) -> dict:
    """Walk the checkpoints; return per-judge counts of (need / have / no-image)."""
    cfg_path = run_dir / "config.json"
    if not cfg_path.exists():
        return {'error': f'no config.json at {run_dir}'}
    cfg = json.loads(cfg_path.read_text())
    problems = cfg.get('problems', [])

    counts = {jm: {'have': 0, 'need': 0, 'no_render': 0} for jm in panel}
    cp_dir = run_dir / "checkpoints"
    if not cp_dir.exists():
        return {'error': f'no checkpoints/ at {run_dir}'}

    for idx in range(len(problems)):
        cp_path = cp_dir / f"problem_{idx:03d}.json"
        if not cp_path.exists():
            for jm in panel:
                counts[jm]['need'] += 1
            continue
        try:
            cp = json.loads(cp_path.read_text())
        except (OSError, json.JSONDecodeError):
            continue
        stages = cp.get('stages', {})
        render_ok = stages.get('render', {}).get('status') == 'complete'
        sbj = scores_by_judge_from_stages(stages)
        for jm in panel:
            if jm in sbj:
                counts[jm]['have'] += 1
            elif not render_ok:
                # No image to judge; harness will skip this problem entirely.
                counts[jm]['no_render'] += 1
            else:
                counts[jm]['need'] += 1
    return {'config': cfg, 'counts': counts, 'total_problems': len(problems)}


async def rejudge_run(run_dir: Path, panel: List[str], max_parallel: int) -> str:
    """Spawn the harness in resume mode against `run_dir` with the requested panel."""
    cfg = json.loads((run_dir / "config.json").read_text())
    harness = BenchmarkHarness(
        model=cfg['model'],
        problems=cfg['problems'],
        max_parallel=max_parallel,
        judge_model=panel,
        run_id=run_dir.name,
        language=cfg.get('language', 'wgsl'),
        runtime=cfg.get('runtime'),
        skip_judge=False,
        prompt_profile=cfg.get('prompt_profile', 'baseline'),
    )
    return await harness.run_benchmark()


def main() -> None:
    p = argparse.ArgumentParser(description="Backfill missing panel judges across benchmark runs.")
    p.add_argument('--panel', nargs='+', required=True,
                   help='Judge models that must score every problem.')
    p.add_argument('--runs', nargs='+', default=None,
                   help='Run dir names under benchmark_run_output/ to backfill.')
    p.add_argument('--all', action='store_true',
                   help='Backfill every run under benchmark_run_output/.')
    p.add_argument('--max-parallel', type=int, default=4,
                   help='Max parallel problems per run (default: 4).')
    p.add_argument('--dry-run', action='store_true',
                   help='Print what would be backfilled without invoking judges.')
    args = p.parse_args()

    if not args.runs and not args.all:
        p.error("pass --runs <names...> or --all")

    if args.runs:
        run_dirs = [BENCH_DIR / name for name in args.runs]
    else:
        run_dirs = sorted(d for d in BENCH_DIR.iterdir() if d.is_dir())

    missing_dirs = [d for d in run_dirs if not d.exists()]
    if missing_dirs:
        for d in missing_dirs:
            print(f"⚠️  not found: {d}")
        sys.exit(1)

    # Summary first — even non-dry-run shows it so you see the scope before spend.
    print(f"Panel: {args.panel}")
    print(f"Targets: {len(run_dirs)} run(s)")
    total_need = 0
    for run_dir in run_dirs:
        summary = summarize_run(run_dir, args.panel)
        if summary.get('error'):
            print(f"  {run_dir.name}: {summary['error']}")
            continue
        line = f"  {run_dir.name} ({summary['total_problems']} problems):"
        for jm, c in summary['counts'].items():
            line += f"\n    {jm:50s} have={c['have']:3d}  need={c['need']:3d}  no_render={c['no_render']:3d}"
            total_need += c['need']
        print(line)
    print(f"\nTotal judge calls to make: {total_need}")

    if args.dry_run:
        print("(dry-run; not invoking)")
        return
    if total_need == 0:
        print("Nothing to do.")
        return

    for run_dir in run_dirs:
        print(f"\n=== Rejudging {run_dir.name} ===")
        try:
            asyncio.run(rejudge_run(run_dir, args.panel, args.max_parallel))
        except Exception as e:
            print(f"❌ {run_dir.name} failed: {e}")
            print("   Stopping here — fix the failure and re-invoke to continue.")
            sys.exit(1)

    print("\n✅ Backfill complete. Run `python ../tools/build_docs.py` to regenerate the leaderboard.")


if __name__ == "__main__":
    # Suppress the unused-import warning while keeping the symbol available
    # to anyone importing this module for the helpers above.
    _ = judge_stage_name, missing_judges
    main()
