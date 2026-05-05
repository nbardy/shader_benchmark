#!/usr/bin/env python3
"""Migrate single-judge benchmark runs to the multi-judge schema.

Idempotent: re-running on already-migrated runs is a no-op.

What it does, per `benchmark_run_output/<run_id>/`:

1. Read `config.json` to learn which judge produced this run's scores.
2. For every `checkpoints/problem_*.json` that has a legacy `stages.judge`
   entry, rename it to `stages.judge:<safe_key>` and stamp the original
   judge_model into `data.judge_model`. Skip problems that already have
   any `judge:` stage (already migrated).
3. For every `results/<idx>_<problem>/results.json` with a non-empty
   `scores` list, add `scores_by_judge: {<judge_model>: scores}` if it's
   not already present.
4. Write `judge_models: [<judge_model>]` into `config.json` if missing
   (legacy field `judge_model` is preserved untouched).

Run with `--dry-run` to print what would change without writing.
Run with `--run-dir <path>` to migrate a single run; otherwise migrates
every subdir of `benchmark_run_output/`.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from judge_panel import judge_stage_name, is_judge_stage

REPO = Path(__file__).resolve().parent.parent
BENCH_DIR = REPO / "llm_harness" / "benchmark_run_output"


def migrate_checkpoint(cp_path: Path, judge_model: str, dry_run: bool) -> str:
    """Migrate one problem checkpoint. Returns 'migrated', 'skipped', or 'no-judge'."""
    try:
        cp = json.loads(cp_path.read_text())
    except (OSError, json.JSONDecodeError) as e:
        return f"error:{e}"

    stages = cp.get('stages', {})
    if not isinstance(stages, dict):
        return 'no-judge'

    # Already migrated if any judge:<...> stage exists.
    if any(is_judge_stage(name) for name in stages):
        return 'skipped'

    legacy = stages.get('judge')
    if not isinstance(legacy, dict):
        return 'no-judge'

    new_stage = dict(legacy)
    new_data = dict(new_stage.get('data') or {})
    # Stamp the judge model so future reads don't depend on the sanitized
    # stage name suffix.
    new_data['judge_model'] = judge_model
    new_stage['data'] = new_data

    new_stages = {k: v for k, v in stages.items() if k != 'judge'}
    new_stages[judge_stage_name(judge_model)] = new_stage
    cp['stages'] = new_stages

    if not dry_run:
        tmp = cp_path.with_suffix('.tmp')
        tmp.write_text(json.dumps(cp, indent=2, default=str))
        tmp.replace(cp_path)
    return 'migrated'


def migrate_results_json(rj_path: Path, judge_model: str, dry_run: bool) -> str:
    """Migrate one results.json. Returns 'migrated', 'skipped', 'no-scores', or 'error:...'."""
    try:
        rj = json.loads(rj_path.read_text())
    except (OSError, json.JSONDecodeError) as e:
        return f"error:{e}"

    scores = rj.get('scores')
    if not (isinstance(scores, list) and len(scores) == 5):
        return 'no-scores'

    # Treat all-zero as "judge skipped"; nothing to attribute.
    if not any(isinstance(s, (int, float)) and s > 0 for s in scores):
        return 'no-scores'

    sbj = rj.get('scores_by_judge')
    if isinstance(sbj, dict) and judge_model in sbj:
        return 'skipped'

    if not isinstance(sbj, dict):
        sbj = {}
    sbj[judge_model] = [int(s) for s in scores]
    rj['scores_by_judge'] = sbj

    if not dry_run:
        tmp = rj_path.with_suffix('.tmp')
        tmp.write_text(json.dumps(rj, indent=2, default=str))
        tmp.replace(rj_path)
    return 'migrated'


def migrate_run(run_dir: Path, dry_run: bool) -> dict:
    """Migrate one benchmark run dir. Returns counts dict."""
    cfg_path = run_dir / "config.json"
    if not cfg_path.exists():
        return {'error': f'no config.json at {run_dir}'}
    cfg = json.loads(cfg_path.read_text())

    judge_model = cfg.get('judge_model')
    if not judge_model:
        return {'error': f'no judge_model in {cfg_path}'}

    counts = {
        'judge_model': judge_model,
        'checkpoints_migrated': 0,
        'checkpoints_skipped': 0,
        'checkpoints_no_judge': 0,
        'results_migrated': 0,
        'results_skipped': 0,
        'results_no_scores': 0,
        'errors': [],
    }

    cp_dir = run_dir / "checkpoints"
    if cp_dir.exists():
        for cp_path in sorted(cp_dir.glob("problem_*.json")):
            res = migrate_checkpoint(cp_path, judge_model, dry_run)
            if res == 'migrated':
                counts['checkpoints_migrated'] += 1
            elif res == 'skipped':
                counts['checkpoints_skipped'] += 1
            elif res == 'no-judge':
                counts['checkpoints_no_judge'] += 1
            else:
                counts['errors'].append(f"{cp_path}: {res}")

    results_dir = run_dir / "results"
    if results_dir.exists():
        for problem_dir in sorted(results_dir.iterdir()):
            rj = problem_dir / "results.json"
            if not rj.exists():
                continue
            res = migrate_results_json(rj, judge_model, dry_run)
            if res == 'migrated':
                counts['results_migrated'] += 1
            elif res == 'skipped':
                counts['results_skipped'] += 1
            elif res == 'no-scores':
                counts['results_no_scores'] += 1
            else:
                counts['errors'].append(f"{rj}: {res}")

    # Bump config to declare judge_models if not already present.
    if 'judge_models' not in cfg:
        cfg['judge_models'] = [judge_model]
        if not dry_run:
            cfg_path.write_text(json.dumps(cfg, indent=2, default=str))
        counts['config_updated'] = True
    else:
        counts['config_updated'] = False

    return counts


def main() -> None:
    p = argparse.ArgumentParser(description="Migrate benchmark runs to multi-judge schema.")
    p.add_argument('--run-dir', type=str, default=None,
                   help='Single run dir to migrate (default: every subdir of benchmark_run_output/)')
    p.add_argument('--dry-run', action='store_true', help='Print intended changes without writing.')
    args = p.parse_args()

    if args.run_dir:
        run_dirs = [Path(args.run_dir).resolve()]
    else:
        if not BENCH_DIR.exists():
            raise SystemExit(f"no benchmark_run_output dir at {BENCH_DIR}")
        run_dirs = sorted(d for d in BENCH_DIR.iterdir() if d.is_dir())

    total_migrated = 0
    total_skipped = 0
    for run_dir in run_dirs:
        counts = migrate_run(run_dir, args.dry_run)
        if counts.get('error'):
            print(f"⚠️  {run_dir.name}: {counts['error']}")
            continue
        total_migrated += counts['checkpoints_migrated']
        total_skipped += counts['checkpoints_skipped']
        line = (
            f"{run_dir.name}: judge={counts['judge_model']}  "
            f"cp(mig={counts['checkpoints_migrated']}, skip={counts['checkpoints_skipped']}, "
            f"none={counts['checkpoints_no_judge']})  "
            f"rj(mig={counts['results_migrated']}, skip={counts['results_skipped']}, "
            f"none={counts['results_no_scores']})"
        )
        if counts['errors']:
            line += f"  errors={len(counts['errors'])}"
        print(line)
        for err in counts['errors']:
            print(f"   ! {err}")

    suffix = " (dry-run)" if args.dry_run else ""
    print(f"\nTotal: migrated={total_migrated} checkpoints, skipped={total_skipped}{suffix}")


if __name__ == "__main__":
    main()
