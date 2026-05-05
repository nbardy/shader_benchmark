# Benchmark Wrap-Up Status - 2026-05-05

## Published Coverage

`tools/build_docs.py` now publishes the merged 130-problem set to `docs/`:

- 107 original/base problems
- 3 reconstruction additions:
  - `reproduce_image_javier_penas`
  - `reproduce_image_mark_basarab`
  - `reproduce_image_tim_stief`
- 20 frontier additions:
  - `topological_quantum_code_defect_braiding`
  - `mean_curvature_flow_surgery`
  - `minimal_surface_knot_boundaries`
  - `qec_threshold_phase_diagram`
  - `optimal_transport_mass_flow_tubes`
  - `spinodal_decomposition_3d`
  - `coxeter_reflection_kaleidoscope`
  - `braid_word_reduction_ribbons`
  - `ocean_eddy_lcs`
  - `earthquake_fault_slip_wavefronts`
  - `protein_folding_energy_landscape`
  - `navier_stokes_vortex_reconnection`
  - `error_correcting_code_decoding_landscape`
  - `differentiable_rendering_ambiguity_landscape`
  - `fractal_drum_eigenfunctions`
  - `riemann_surface_covering_sheets`
  - `reaction_diffusion_nonorientable_surfaces`
  - `polyrhythm_phase_torus`
  - `crystal_dislocation_network`
  - `cellular_potts_tissue_folding`

Current regenerated docs summary from `docs/all_scores.json`:

| Model | OK | Render Fails | Total | Avg OK | Avg Fails=0 |
|---|---:|---:|---:|---:|---:|
| Claude Opus 4.7 | 117 | 13 | 130 | 258.39 | 232.55 |
| Gemini 3.1 Pro Preview | 111 | 19 | 130 | 260.84 | 222.72 |
| Codex GPT-5.5 High | 122 | 8 | 130 | 265.30 | 248.97 |

## Run IDs

Published model rows are merged from these local run directories:

- Claude:
  - `65ab97ac_cli_claude_claude-opus-4-7_20260427_183924`
  - `c27a9b7a_cli_claude_claude-opus-4-7_20260501_231430`
  - `b03ce16c_cli_claude_claude-opus-4-7_20260502_132102`
  - `a8deff3a_cli_claude_claude-opus-4-7_20260502_172716`
- Gemini:
  - `f995b01e_cli_gemini_20260427_184028`
  - `eac60057_cli_gemini_20260501_231430`
  - `3b212275_cli_gemini_20260502_132102`
- Codex:
  - `68ca3b4b_cli_codex_gpt-5.5_high_20260428_170724`
  - `53b06f90_cli_codex_gpt-5.5_high_20260501_231430`
  - `768e6e20_cli_codex_gpt-5.5_high_20260502_132102`

## Retry Pass

The retryable reconstruction generation failures were retried and are now settled:

- Claude `reproduce_image_mark_basarab`: fixed, rendered, Codex-judged at `234/500`.
- Gemini `reproduce_image_javier_penas`: fixed, rendered, Codex-judged at `175/500`.
- Gemini `reproduce_image_mark_basarab`: fixed, rendered, Codex-judged at `243/500`.

Remaining reconstruction render failures are permanent model-output failures:

- Claude `reproduce_image_javier_penas`
- Claude `reproduce_image_tim_stief`

## Frontier Status

The 20 frontier problems have been attempted for all three models.

- Claude: 19 scored after the retry run; `navier_stokes_vortex_reconnection` is a permanent render failure.
- Gemini: 17 scored; permanent render failures are `qec_threshold_phase_diagram`, `braid_word_reduction_ribbons`, and `riemann_surface_covering_sheets`.
- Codex: 19 scored; `fractal_drum_eigenfunctions` is a permanent render failure.

Claude's three initial frontier generation failures were repaired by the retry run:

- `coxeter_reflection_kaleidoscope`
- `braid_word_reduction_ribbons`
- `ocean_eddy_lcs`

## Judge Panel Status

The original 107-problem runs were configured with a three-judge panel:

- `cli/codex:gpt-5.5:high`
- `cli/claude:claude-opus-4-7`
- `cli/gemini:gemini-3.1-pro-preview`

Codex and Claude judges scored every rendered image in those original runs. Gemini judge produced usable scores for most rendered images, but returned empty/parse-failed responses for 43 original rendered cells:

- 13 cells in the Claude-output run
- 14 cells in the Gemini-output run
- 16 cells in the Codex-output run

The newer reconstruction/frontier runs currently have Codex judge scores only. A dry-run backfill for the full three-judge panel reports:

```bash
cd llm_harness
python3 rejudge.py \
  --panel cli/codex:gpt-5.5:high cli/claude:claude-opus-4-7 cli/gemini:gemini-3.1-pro-preview \
  --runs \
    65ab97ac_cli_claude_claude-opus-4-7_20260427_183924 \
    f995b01e_cli_gemini_20260427_184028 \
    68ca3b4b_cli_codex_gpt-5.5_high_20260428_170724 \
    c27a9b7a_cli_claude_claude-opus-4-7_20260501_231430 \
    eac60057_cli_gemini_20260501_231430 \
    53b06f90_cli_codex_gpt-5.5_high_20260501_231430 \
    b03ce16c_cli_claude_claude-opus-4-7_20260502_132102 \
    3b212275_cli_gemini_20260502_132102 \
    768e6e20_cli_codex_gpt-5.5_high_20260502_132102 \
    a8deff3a_cli_claude_claude-opus-4-7_20260502_172716 \
  --dry-run
```

Current dry-run result: `167` judge calls still needed for a fully balanced three-judge panel.

## Judge Backfill Launch

Launched a serialized panel backfill on 2026-05-05:

- Active screen session: `shader_rejudge_loop_20260505_1845`
- Main log: `llm_harness/logs/rejudge_panel_loop_20260505_1845.log`
- Exit marker: `llm_harness/logs/rejudge_panel_loop_20260505_1845.exit`
- Dry-run snapshots: `llm_harness/logs/rejudge_panel_loop_20260505_1845_pass*_dry.log`

The loop runs the full judge panel with `--max-parallel 1`, so only one CLI judge call is active at a time. It dry-runs first, runs missing judges from cached render checkpoints, then repeats up to five passes until the missing count reaches zero or a pass makes no progress.

Initial dry-run before launch reported `167` missing calls. After clearing stale Gemini temp dirs and a couple early manual attempts, the active loop started pass 1 with `165` missing calls. `~/.gemini/tmp` was cleared before the loop to avoid Gemini CLI startup aborts from hundreds of stale temp session dirs.

Observed retryable judge-side errors:

- Gemini CLI startup abort: `AbortError: The user aborted a request.` This happened before clearing `~/.gemini/tmp`.
- Gemini partial XML/no-score response. The patched judge now marks this as failed/retryable instead of recording an all-zero score.

Two orphaned Python/Gemini child trees from earlier detached-screen attempts were killed after discovery; the active loop was then verified as the only remaining `rejudge.py` process.

## GitHub Publishing Policy

GitHub Pages publishes from committed `docs/**`.

For sharing the benchmark publicly, commit:

- `docs/index.html`
- `docs/all_scores.json`
- `docs/images/**`
- `docs/refs/**`
- the problem specs under `problems/base_set/**`

Raw `llm_harness/benchmark_run_output/**` directories are still ignored by `.gitignore`. Do not add them by default unless we explicitly want a heavy raw-run archive in git.

## Verification

Completed locally:

```bash
python3 -m py_compile llm_harness/benchmark_harness.py llm_harness/judge.py llm_harness/judge_panel.py llm_harness/rejudge.py llm_harness/migrate_judge_schema.py tools/build_docs.py
python3 tools/build_docs.py
cd llm_harness && python3 rejudge.py --panel ... --runs ... --dry-run
```

`pytest` was not run because neither the system Python nor `llm_harness/.venv` currently has `pytest` installed.
