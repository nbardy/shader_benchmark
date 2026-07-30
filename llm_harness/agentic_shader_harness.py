#!/usr/bin/env python3
"""Run one persistent Codex shader agent with bounded render/edit tools."""

from __future__ import annotations

import argparse
import asyncio
import html
import json
import os
import shutil
import subprocess
import sys
import tempfile
import uuid
from datetime import datetime
from pathlib import Path
from typing import Any

from judge import EvaluationContext, Judge
from language_specs import get_language_spec
from llm_client import generation_isolation_metadata, parse_cli_spec
from prompt_profiles import (
    BASELINE_PROFILE,
    apply_prompt_profile,
    prompt_profile_choices,
)
from test_runner import TestRunner


PROTOCOL = "persistent-agent-render-tools-v2"
STANDARD_WORKFLOW = "standard"
SKETCHBOOK_WORKFLOW = "sketchbook-3x2-v1"
MCP_TOOLS = (
    "write_shader",
    "render_shader",
    "record_study",
    "submit_final",
)


def _json_config(value: Any) -> str:
    """Encode strings/arrays as TOML-compatible CLI config literals."""
    return json.dumps(value, ensure_ascii=True)


def build_agent_prompt(
    problem_request: str,
    prompt_profile: str,
    render_budget: int,
    min_successful_revisions: int = 2,
    workflow: str = STANDARD_WORKFLOW,
) -> str:
    language_spec = get_language_spec("wgsl")
    canonical_prompt = f"""\
{language_spec.constraint_prompt.rstrip()}

PROBLEM CONTEXT
===============
{problem_request.strip()}
"""
    profiled_prompt = apply_prompt_profile(canonical_prompt, prompt_profile)
    if workflow not in {STANDARD_WORKFLOW, SKETCHBOOK_WORKFLOW}:
        raise ValueError(f"unknown agent workflow: {workflow}")
    required_studies = 3 if workflow == SKETCHBOOK_WORKFLOW else 0
    sketchbook_contract = (
        r"""

MANDATORY 3×2 VISUAL SKETCHBOOK
==============================

Before building the final reconstruction, use rendered evidence to resolve
three high-risk, subject-specific design decisions. This is a public production
study, not hidden chain-of-thought. Select the three core elements from the
reference rather than hardcoding the examples below.

Study selection:
- Study 1 normally resolves macro form, silhouette, pose, projection, or scene
  architecture.
- Study 2 normally resolves the signature meso-scale element and how it is
  distributed, oriented, overlapped, or wrapped over its parent form.
- Study 3 normally resolves material response, palette relationships, lighting,
  atmospheric treatment, or another unresolved identity-carrying element.
- Adapt these roles when a mathematical plot, landscape, typography, fluid,
  architecture, or abstract target has different dominant risks.

For EACH study:
1. Write a self-contained study shader whose entire image is a clean 3-column
   by 2-row atlas. The six cells are variants A, B, C, D, E, F in reading order.
   Give every cell equal scale, safe margins, a consistent comparison camera,
   and a visibly distinct construction. Tiny random-seed or parameter changes
   do not count as six alternatives.
2. For shape studies, vary the actual representation: silhouette/profile,
   thickness, curvature, taper, overlap, deformation, normal construction, or
   primitive/CSG/intersection method. Do not compare six copies of one peg,
   capsule, disk, or decal.
3. For placement studies, test a parent-surface coordinate frame and coherent
   distribution fields. Compare useful combinations of curvature-following
   orientation, layered overlap, low-frequency fBm/domain warp, correlated
   jitter, density drift, clusters, and sparse exceptions. Noise must modulate
   a designed structure; it must not erase the parent silhouette or become
   screen-space static.
4. Call render_shader(stage="study", study_index=N), inspect the returned atlas,
   and revise/render that study if the variants do not answer the design
   question and budget remains.
5. Call record_study only after inspecting a successful atlas. Record the
   selected A-F cell using visible comparison evidence and name the exact
   function family, coordinate frame, parameter ranges, and aesthetic
   properties that must be carried into the final shader.

After all three selections are recorded, replace the atlas with the complete
reconstruction. The final shader must materially reuse the selected
representations and handoff requirements; do not restart from generic
primitives. Render it with render_shader(stage="final", study_index=0), compare
it to the reference, and iterate the final scene. Study atlases are experiments,
not valid final submissions.
"""
        if required_studies
        else ""
    )
    return f"""\
{profiled_prompt.rstrip()}

AGENTIC RENDER-AND-REVISE EXECUTION CONTRACT
=============================================

This contract replaces the one-shot response envelope above. The reference
image is attached to this persistent session. Do not merely describe an
iteration loop and do not put WGSL in your final chat response.

You have exactly these benchmark tools:
- write_shader(shader_source, revision_critique): replace the complete working
  WGSL program; every rewrite after revision 1 requires a concise critique;
- render_shader(stage, study_index): compile and render the current revision,
  returning both compiler feedback and the actual rendered image;
- record_study(study_index, subject, selected_variant, selection_rationale,
  handoff_requirements): preserve public visual-study evidence and its exact
  implementation handoff;
- submit_final(summary): freeze the current successfully rendered revision.
{sketchbook_contract}

Workflow requirements:
1. Study the reference and plan a strong procedural reconstruction.
2. Call write_shader with a complete shader, then call render_shader. Use
   stage="final" and study_index=0 unless the sketchbook contract above applies.
3. Visually compare every returned render with the reference. Diagnose the
   largest concrete mismatch in silhouette, composition, depth, color,
   lighting, material, or texture before editing.
4. Revise the complete shader and render again when a material improvement is
   plausible. You control when to stop. The hard render-call budget is
   {render_budget}, and compile failures consume budget.
5. Preserve successful features and avoid blind rewrites. You may return to an
   earlier idea because this is one persistent session and your prior tool
   calls remain in context.
6. Call submit_final only when the current exact revision has rendered
   successfully. The harness treats a chat response without submit_final as a
   failed run.

You must produce at least {min_successful_revisions} distinct successfully
rendered FINAL revisions before submitting. The {required_studies} required
study renders do not count toward that final-revision minimum. Re-rendering
unchanged code is rejected without consuming budget. Each rewrite should
respond to visible evidence, not merely satisfy the counter.

For each rewrite, put the target-versus-render evidence, strongest feature to
preserve, and bounded changes you are making in write_shader's
revision_critique argument. The server rejects unaudited rewrites.

The tools expose no arbitrary file paths, textures, benchmark results, judges,
or other contestants' work. Build the image analytically in WGSL. Use the
rendered evidence—not confidence or prose—to decide when the file is done.
"""


def build_codex_command(
    *,
    model_spec: str,
    workspace: Path,
    reference_image: Path | None,
    server_script: Path,
    renderer: Path,
    render_budget: int,
    render_size: int,
    min_successful_revisions: int,
    required_studies: int,
    trace_path: Path,
    last_message_path: Path,
) -> list[str]:
    tool, model, effort = parse_cli_spec(model_spec)
    if tool != "codex":
        raise ValueError(
            "The persistent render-tool harness currently requires cli/codex."
        )

    uv_path = shutil.which("uv")
    if not uv_path:
        raise FileNotFoundError("uv is required to launch the local MCP server")

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
        str(last_message_path),
    ]
    if model:
        command.extend(["--model", model])
    if reference_image:
        command.extend(["--image", str(reference_image)])
    if effort:
        command.extend(["--config", f"reasoning_effort={_json_config(effort)}"])

    server_args = [
        "run",
        "--quiet",
        "--with",
        "mcp>=1,<2",
        "python",
        str(server_script),
    ]
    configs = {
        "mcp_servers.shader_tools.command": uv_path,
        "mcp_servers.shader_tools.args": server_args,
        "mcp_servers.shader_tools.cwd": str(workspace),
        "mcp_servers.shader_tools.required": True,
        "mcp_servers.shader_tools.startup_timeout_sec": 30,
        "mcp_servers.shader_tools.tool_timeout_sec": 180,
        "mcp_servers.shader_tools.enabled_tools": list(MCP_TOOLS),
        "mcp_servers.shader_tools.default_tools_approval_mode": "approve",
        "mcp_servers.shader_tools.env.SHADER_AGENT_WORKSPACE": str(workspace),
        "mcp_servers.shader_tools.env.SHADER_AGENT_RENDERER": str(renderer),
        "mcp_servers.shader_tools.env.SHADER_AGENT_RENDER_BUDGET": str(
            render_budget
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_RENDER_SIZE": str(render_size),
        "mcp_servers.shader_tools.env.SHADER_AGENT_MIN_SUCCESSFUL_REVISIONS": str(
            min_successful_revisions
        ),
        "mcp_servers.shader_tools.env.SHADER_AGENT_REQUIRED_STUDIES": str(
            required_studies
        ),
    }
    for key, value in configs.items():
        command.extend(["--config", f"{key}={_json_config(value)}"])
    command.append("-")
    return command


def _base_env() -> dict[str, str]:
    env = os.environ.copy()
    for key in (
        "CLAUDECODE",
        "CLAUDECODE_SESSION_ID",
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
        "GEMINI_API_KEY",
        "GOOGLE_API_KEY",
    ):
        env.pop(key, None)
    return env


def _copy_workspace(workspace: Path, output_dir: Path) -> None:
    for child in workspace.iterdir():
        if child.name == "reference.png":
            continue
        target = output_dir / child.name
        if child.is_dir():
            shutil.copytree(child, target, dirs_exist_ok=True)
        else:
            shutil.copy2(child, target)


def _agentic_isolation_metadata() -> dict[str, Any]:
    metadata = generation_isolation_metadata("cli/codex")
    metadata.update(
        {
            "protocol": PROTOCOL,
            "persistent_model_session": True,
            "model_render_budget_enforced_server_side": True,
            "fixed_path_mcp_tools": list(MCP_TOOLS),
            "codex_sandbox": "read-only",
            "mcp_server_mutations": "one temporary shader workspace only",
            "study_records_are_public_decision_evidence": True,
        }
    )
    return metadata


async def _judge_render(
    output_dir: Path,
    problem_path: Path,
    judge_model: str,
    render_call: int,
    revision: int,
) -> dict[str, Any]:
    render = output_dir / "renders" / f"render_{render_call:02d}.png"
    shader = (
        output_dir
        / "renders"
        / f"render_{render_call:02d}_revision_{revision:02d}.wgsl"
    )
    judge_dir = output_dir / "renders" / f"judge_render_{render_call:02d}"
    judge_dir.mkdir(exist_ok=True)
    judge = Judge(judge_model=judge_model)
    scores, failure_reason, usage = await judge.evaluate_with_template(
        EvaluationContext(
            critic_path=problem_path / "critic.txt",
            request_path=problem_path / "request.txt",
            result_image_path=render,
            save_dir=judge_dir,
            code_path=shader,
            reference_image_path=problem_path / "reference.png",
        )
    )
    result = {
        "render_call": render_call,
        "revision": revision,
        "judge_model": judge_model,
        "scores": scores,
        "total": sum(scores),
        "failure_reason": failure_reason,
        "usage": usage,
    }
    (judge_dir / "judge_result.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    return result


async def _judge_render_sequence(
    output_dir: Path,
    problem_path: Path,
    judge_model: str,
    state: dict[str, Any],
) -> list[dict[str, Any]]:
    successful = [
        (int(event["render_call"]), int(event["revision"]))
        for event in state.get("events", [])
        if event.get("type") == "render_shader" and event.get("ok")
        and event.get("stage", "final") == "final"
    ]
    return list(
        await asyncio.gather(
            *(
                _judge_render(
                    output_dir,
                    problem_path,
                    judge_model,
                    render_call,
                    revision,
                )
                for render_call, revision in successful
            )
        )
    )


def _render_report(
    output_dir: Path,
    problem_path: Path,
    result: dict[str, Any],
) -> Path:
    state = result.get("state") or {}
    render_events = [
        event
        for event in state.get("events", [])
        if event.get("type") == "render_shader"
    ]
    panels = [
        (
            "Reference",
            problem_path / "reference.png",
            "Target image",
        )
    ]
    judged_by_call = {
        int(item["render_call"]): item
        for item in result.get("render_judges", [])
    }
    for event in render_events:
        if event.get("ok"):
            render_call = event["render_call"]
            stage = event.get("stage", "final")
            study_index = int(event.get("study_index", 0))
            judged = judged_by_call.get(int(render_call))
            score_caption = (
                f" · {judged['total']} / 500" if judged else ""
            )
            panels.append(
                (
                    (
                        f"Study {study_index} · render {render_call}"
                        if stage == "study"
                        else f"Final render {render_call}"
                    )
                    + f" · revision {event['revision']}",
                    output_dir / "renders" / f"render_{render_call:02d}.png",
                    (
                        f"{event.get('remaining_renders', 0)} renders left"
                        f"{score_caption}"
                    ),
                )
            )
    if (output_dir / "final_render.png").exists():
        panels.append(("Submitted final", output_dir / "final_render.png", ""))

    panel_html = "\n".join(
        f"""<article><h2>{html.escape(title)}</h2>
<img src="{html.escape(os.path.relpath(path, output_dir))}" alt="{html.escape(title)}">
<p>{html.escape(caption)}</p></article>"""
        for title, path, caption in panels
        if path.exists()
    )
    judge = result.get("judge")
    judge_html = (
        f"<p><strong>Judge:</strong> {html.escape(judge['judge_model'])} · "
        f"<strong>{judge['total']} / 500</strong> · {judge['scores']}</p>"
        if judge
        else "<p>No judge score.</p>"
    )
    study_records = state.get("study_records", {})
    study_html = ""
    if study_records:
        items = "\n".join(
            "<li><strong>Study "
            + html.escape(str(record.get("study_index", index)))
            + ": "
            + html.escape(str(record.get("subject", "")))
            + "</strong> — selected "
            + html.escape(str(record.get("selected_variant", "")))
            + "<br>"
            + html.escape(str(record.get("selection_rationale", "")))
            + "<br><em>Handoff:</em> "
            + html.escape(str(record.get("handoff_requirements", "")))
            + "</li>"
            for index, record in sorted(
                study_records.items(), key=lambda item: int(item[0])
            )
        )
        study_html = f"<h2>Recorded study decisions</h2><ol>{items}</ol>"
    report = output_dir / "agentic_report.html"
    report.write_text(
        f"""<!doctype html><meta charset="utf-8"><title>Agentic shader run</title>
<style>
body{{font:16px system-ui;background:#0d1117;color:#d7dde8;margin:2rem}}
.meta{{background:#161b22;padding:1rem;border-radius:10px;margin-bottom:1rem}}
.grid{{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:1rem}}
article{{background:#161b22;padding:1rem;border-radius:10px}}
img{{display:block;width:100%;aspect-ratio:1;object-fit:contain;background:#000}}
code{{color:#9ecbff}}
</style>
<h1>Persistent agent render-tool experiment</h1>
<div class="meta">
<p><strong>Model:</strong> {html.escape(result['model'])} ·
<strong>Profile:</strong> {html.escape(result['prompt_profile'])} ·
<strong>Workflow:</strong> {html.escape(result.get('workflow', STANDARD_WORKFLOW))} ·
<strong>Budget:</strong> {result['render_budget']} renders ·
<strong>Used:</strong> {state.get('render_calls', 0)}</p>
{judge_html}
<p>Protocol: <code>{PROTOCOL}</code></p>
{study_html}
</div><div class="grid">{panel_html}</div>""",
        encoding="utf-8",
    )
    return report


async def run_agentic_shader(
    *,
    model: str,
    problem: str,
    prompt_profile: str,
    render_budget: int,
    render_size: int,
    min_successful_revisions: int,
    workflow: str,
    judge_model: str | None,
    run_id: str | None,
) -> Path:
    if render_budget < 1:
        raise ValueError("render_budget must be at least 1")
    required_studies = 3 if workflow == SKETCHBOOK_WORKFLOW else 0
    if workflow not in {STANDARD_WORKFLOW, SKETCHBOOK_WORKFLOW}:
        raise ValueError(f"unknown agent workflow: {workflow}")
    if not 1 <= min_successful_revisions <= render_budget:
        raise ValueError(
            "min_successful_revisions must be between 1 and render_budget"
        )
    if render_budget < required_studies + min_successful_revisions:
        raise ValueError(
            "render_budget must allow all required studies plus the minimum "
            "successful final revisions"
        )
    script_dir = Path(__file__).parent.resolve()
    repo_root = script_dir.parent
    problem_path = (repo_root / "problems" / "base_set" / problem).resolve()
    if not problem_path.is_dir():
        raise FileNotFoundError(f"problem not found: {problem_path}")

    renderer = (
        repo_root / "shader_harness" / "target" / "release" / "shader-bench"
    )
    if not renderer.exists():
        runner = TestRunner()
        await runner.prebuild_shader_binary()
        renderer = runner.shader_bench_binary
    if renderer is None or not renderer.exists():
        raise FileNotFoundError("shader-bench release binary is unavailable")

    safe_model = model.replace("/", "_").replace(":", "_")
    actual_run_id = run_id or (
        f"{uuid.uuid4().hex[:8]}_agentic_{safe_model}_"
        f"{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    )
    output_dir = script_dir / "benchmark_run_output" / actual_run_id
    output_dir.mkdir(parents=True, exist_ok=False)

    request = (problem_path / "request.txt").read_text(encoding="utf-8")
    prompt = build_agent_prompt(
        request,
        prompt_profile,
        render_budget,
        min_successful_revisions,
        workflow,
    )
    (output_dir / "agent_prompt.txt").write_text(prompt, encoding="utf-8")

    with tempfile.TemporaryDirectory(
        prefix="shader_agent_workspace_"
    ) as temporary:
        workspace = Path(temporary).resolve()
        reference_source = problem_path / "reference.png"
        staged_reference = None
        if reference_source.exists():
            staged_reference = workspace / "reference.png"
            shutil.copy2(reference_source, staged_reference)

        trace_path = output_dir / "agent_trace.jsonl"
        last_message_path = output_dir / "last_message.txt"
        command = build_codex_command(
            model_spec=model,
            workspace=workspace,
            reference_image=staged_reference,
            server_script=script_dir / "shader_agent_mcp.py",
            renderer=renderer,
            render_budget=render_budget,
            render_size=render_size,
            min_successful_revisions=min_successful_revisions,
            required_studies=required_studies,
            trace_path=trace_path,
            last_message_path=last_message_path,
        )
        (output_dir / "command.json").write_text(
            json.dumps(command, indent=2), encoding="utf-8"
        )
        completed = await asyncio.to_thread(
            subprocess.run,
            command,
            input=prompt,
            capture_output=True,
            text=True,
            timeout=1800,
            env=_base_env(),
            cwd=workspace,
        )
        trace_path.write_text(completed.stdout or "", encoding="utf-8")
        (output_dir / "codex_stderr.txt").write_text(
            completed.stderr or "", encoding="utf-8"
        )
        _copy_workspace(workspace, output_dir)

    state_path = output_dir / "agent_state.json"
    state = (
        json.loads(state_path.read_text(encoding="utf-8"))
        if state_path.exists()
        else {}
    )
    submitted = (output_dir / "submission.json").exists()
    result: dict[str, Any] = {
        "protocol": PROTOCOL,
        "model": model,
        "problem": problem,
        "prompt_profile": prompt_profile,
        "render_budget": render_budget,
        "render_size": render_size,
        "min_successful_revisions": min_successful_revisions,
        "workflow": workflow,
        "required_studies": required_studies,
        "codex_returncode": completed.returncode,
        "submitted": submitted,
        "state": state,
        "isolation": _agentic_isolation_metadata(),
    }
    if completed.returncode != 0:
        result["error"] = (
            completed.stderr or completed.stdout or "Codex failed"
        )[-8_000:]
    if submitted and judge_model:
        result["render_judges"] = await _judge_render_sequence(
            output_dir, problem_path, judge_model, state
        )
        submission = json.loads(
            (output_dir / "submission.json").read_text(encoding="utf-8")
        )
        chosen_call = submission.get("render_call")
        result["judge"] = next(
            (
                item
                for item in result["render_judges"]
                if item["render_call"] == chosen_call
            ),
            None,
        )

    report = _render_report(output_dir, problem_path, result)
    result["report"] = str(report)
    (output_dir / "result.json").write_text(
        json.dumps(result, indent=2), encoding="utf-8"
    )
    if not submitted:
        raise RuntimeError(
            f"Agent did not call submit_final. Inspect {trace_path}"
        )
    return report


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(
        description=(
            "Give one persistent Codex session bounded write/render/submit "
            "tools and let it decide how to iterate."
        )
    )
    parser.add_argument(
        "--model", default="cli/codex:gpt-5.6-sol:medium"
    )
    parser.add_argument("--problem", required=True)
    parser.add_argument(
        "--prompt-profile",
        choices=prompt_profile_choices(),
        default=BASELINE_PROFILE,
    )
    parser.add_argument("--render-budget", type=int, default=3)
    parser.add_argument(
        "--workflow",
        choices=(STANDARD_WORKFLOW, SKETCHBOOK_WORKFLOW),
        default=STANDARD_WORKFLOW,
        help=(
            "Use the ordinary render loop or require three rendered 3x2 "
            "component studies before final-scene iteration."
        ),
    )
    parser.add_argument(
        "--min-successful-revisions",
        type=int,
        default=2,
        help=(
            "Distinct revisions that must render successfully before the "
            "agent may submit."
        ),
    )
    parser.add_argument("--render-size", type=int, default=1024)
    parser.add_argument("--judge-model", default=None)
    parser.add_argument("--run-id", default=None)
    args = parser.parse_args(argv)
    report = asyncio.run(
        run_agentic_shader(
            model=args.model,
            problem=args.problem,
            prompt_profile=args.prompt_profile,
            render_budget=args.render_budget,
            render_size=args.render_size,
            min_successful_revisions=args.min_successful_revisions,
            workflow=args.workflow,
            judge_model=args.judge_model,
            run_id=args.run_id,
        )
    )
    print(f"Agentic report: {report}")


if __name__ == "__main__":
    main()
