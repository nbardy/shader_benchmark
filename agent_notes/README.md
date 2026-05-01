# Agent Notes

This directory contains historical implementation notes, decision docs, and research summaries from the project's development. Active project docs are at the repo root in `Readme.md` and `CLAUDE.md`.

## Decision Records

- **GLSL_MIGRATION_DECISION.md** — Investigation that led to staying with WGSL instead of migrating to GLSL.
- **WGSL_CONSTRAINT_SPEC.md** — Locked, non-negotiable ABI contract for LLM-generated WGSL shaders.

## Research

- **RESEARCH_FINDINGS.md** — Theoretical and empirical foundation for the constraint-based prompting approach.
- **ANALYSIS_FINDINGS.md** — Findings from a 53-run shader benchmark investigation, captured for future maintenance.
- **AGENT_NOTES.md** — WGSL migration architecture notes documenting the clean separation of concerns in the system.

## Implementation Summaries

- **THREE_PIPELINES_IMPLEMENTATION.md** — Summary of the three-shader-pipeline implementation built via parallel sub-agents.
- **HLSL_IMPLEMENTATION_SUMMARY.md** — Implementation of the HLSL Unity shader pipeline for LLM testing.
- **GLSL_SOKOL_IMPLEMENTATION_SUMMARY.md** — Implementation of the GLSL ES 3.0 + Sokol pipeline as an alternative to the WGPU/WGSL harness.
- **SHADERTOY_MIGRATION_COMPLETE.md** — Production-ready Shadertoy GLSL migration aimed at improving on the 20% baseline.
- **MULTI_AGENT_ORCHESTRATION_SUMMARY.md** — Recap of a 5-agent parallel orchestration covering research, planning, and engineering.

## Setup & Quickstart Guides

- **BENCHMARK_QUICKSTART.md** — Reference for running shader benchmark evaluations on LLM models.
- **HLSL_SETUP.md** — Step-by-step setup guide for the HLSL Unity shader pipeline on macOS.
- **HLSL_QUICK_START.md** — 5-minute quick-start for the HLSL Unity pipeline.
- **GLSL_SOKOL_INSTALL.md** — Full setup guide for the GLSL ES 3.0 + Sokol pipeline.
- **GLSL_SOKOL_QUICKSTART.md** — Fast setup guide for the GLSL ES 3.0 + Sokol pipeline.

## Validation & Testing

- **VALIDATION_ROADMAP.md** — Strategic plan for validating constraint-based LLM shader generation.
- **VALIDATION_REPORT.md** — Verification report for the path-resolution fix (commit 4c1c888).
- **PIPELINE_TEST_RESULTS.md** — Final results from parallel sub-agent testing of the three alternative pipelines.
- **PHASE1_RETRY2_RESULTS.md** — Phase 1 validation rerun after adding `select()` and numeric-literal docs (40% compile rate).
- **ABLATION_EXPERIMENTS.md** — Planned systematic variations for measuring the impact of architectural choices.

## Bug Fixes & Debt

- **ERROR_FIXES.md** — Critical bug fixes for the multi-problem path-resolution issue (commit 4c1c888).
- **TECHNICAL_DEBT.md** — Tracker of fixes needed and future improvements, ordered by impact.
- **CONVERSATION_SUMMARY_20251025.md** — Session focused on improving Claude 3.5 Sonnet WGSL compilation success from the 40% baseline toward 100%.
