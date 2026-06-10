#!/usr/bin/env python3
"""One-off: re-render cached shaders after the June 2026 uniform fix.

Context: shader_harness used to zero-fill the last 8 bytes of the Params
uniform while the prompt spec invited models to declare `time`/`aspect`
fields there. Shaders that did so read 0.0 — multiplying a coordinate
axis by aspect collapsed the image into stripes. The harness now writes
time=0.0, aspect=1.0 (see shader_harness/src/main.rs), so re-rendering
the SAME cached shader code can heal those failures.

This script, per run dir:
  1. re-renders every problem's cached shader with the fixed binary
  2. pixel-compares against the stored artifacts/result.png
  3. with --apply, for changed problems only:
       - backs up the old image as result_pre_uniform_fix.png
       - replaces artifacts/result.png with the new render
       - deletes all judge:* stages from the problem's checkpoint, so
         `benchmark_harness.py --resume <run_dir>` re-judges just those
         problems from the cached (now corrected) image

Without --apply it only reports. It never touches generate/compile/render
checkpoint stages and never re-runs generation.

Usage:
  python tools/rerender_uniform_fix.py <run_dir>... [--apply]
  # run_dir: path under llm_harness/benchmark_run_output/ (or absolute)
"""

import argparse
import json
import subprocess
import sys
import tempfile
from io import BytesIO
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parent.parent
BENCH_DIR = REPO / "llm_harness" / "benchmark_run_output"
BINARY = REPO / "shader_harness" / "target" / "release" / "shader-bench"

# test_runner.py invokes the binary without --size, so the default (1024)
# is what produced the stored images. Match it exactly.
RENDER_TIMEOUT_S = 120


def pixels(png_path: Path) -> bytes:
    return Image.open(png_path).convert("RGBA").tobytes()


def render(shader: Path, out: Path) -> None:
    result = subprocess.run(
        [str(BINARY), "--shader", str(shader), "--output", str(out)],
        capture_output=True, text=True, timeout=RENDER_TIMEOUT_S,
    )
    if result.returncode != 0:
        raise RuntimeError(f"render failed (exit {result.returncode}): {(result.stderr or '')[:300]}")


def process_run(run_dir: Path, apply: bool) -> dict:
    counts = {"unchanged": 0, "changed": 0, "skipped": 0}
    changed_names = []
    for problem_dir in sorted((run_dir / "results").iterdir()):
        if not problem_dir.is_dir():
            continue
        name = problem_dir.name
        shader = problem_dir / "shaders" / "shader.wgsl"
        old_png = problem_dir / "artifacts" / "result.png"
        if not shader.exists():
            wgsl = sorted((problem_dir / "shaders").glob("*.wgsl")) if (problem_dir / "shaders").exists() else []
            if not wgsl:
                print(f"  SKIP {name}: no cached shader")
                counts["skipped"] += 1
                continue
            shader = wgsl[0]
        if not old_png.exists():
            print(f"  SKIP {name}: no stored render (original render failed)")
            counts["skipped"] += 1
            continue

        with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp:
            tmp_png = Path(tmp.name)
        try:
            try:
                render(shader, tmp_png)
            except (RuntimeError, subprocess.TimeoutExpired) as e:
                print(f"  SKIP {name}: re-render error: {e}")
                counts["skipped"] += 1
                continue

            if pixels(tmp_png) == pixels(old_png):
                counts["unchanged"] += 1
                continue

            counts["changed"] += 1
            changed_names.append(name)
            print(f"  CHANGED {name}")
            if apply:
                backup = old_png.with_name("result_pre_uniform_fix.png")
                if not backup.exists():
                    old_png.rename(backup)
                tmp_png.replace(old_png)
                # Index prefix of the result dir (e.g. 002_foo) maps to
                # checkpoints/problem_002.json.
                idx = name.split("_", 1)[0]
                cp = run_dir / "checkpoints" / f"problem_{idx}.json"
                if not cp.exists():
                    raise FileNotFoundError(f"{name}: expected checkpoint {cp} not found — cannot mark for re-judge")
                data = json.loads(cp.read_text())
                stages = data["stages"]
                dropped = [k for k in stages if k == "judge" or k.startswith("judge:")]
                for k in dropped:
                    del stages[k]
                cp.write_text(json.dumps(data, indent=2))
                print(f"    applied: image replaced, reset {len(dropped)} judge stage(s)")
        finally:
            tmp_png.unlink(missing_ok=True)
    return {**counts, "changed_names": changed_names}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("run_dirs", nargs="+")
    parser.add_argument("--apply", action="store_true",
                        help="replace changed images and reset their judge checkpoints")
    args = parser.parse_args()

    if not BINARY.exists():
        sys.exit(f"shader-bench binary not found at {BINARY} — build it first (cargo build --release)")

    grand = {}
    for rd in args.run_dirs:
        run_dir = Path(rd) if Path(rd).is_absolute() else BENCH_DIR / rd
        if not (run_dir / "results").exists():
            sys.exit(f"not a run dir (no results/): {run_dir}")
        print(f"\n=== {run_dir.name} ===")
        grand[run_dir.name] = process_run(run_dir, args.apply)

    print("\n===== SUMMARY =====")
    for run, c in grand.items():
        print(f"{run}: {c['changed']} changed, {c['unchanged']} unchanged, {c['skipped']} skipped")
        for n in c["changed_names"]:
            print(f"    {n}")
    if args.apply:
        print("\nNext: re-judge changed problems with\n"
              "  cd llm_harness && .venv/bin/python benchmark_harness.py --resume benchmark_run_output/<run_dir>")


if __name__ == "__main__":
    main()
