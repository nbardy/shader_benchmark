#!/usr/bin/env python3
"""A deliberately narrow MCP tool server for agentic shader iteration.

The server owns exactly one shader workspace. It can write the complete shader,
render the current revision with the benchmark binary, record bounded visual
studies, and freeze a rendered revision as the final submission. Paths and
budgets come from the parent harness through environment variables;
model-supplied paths are never accepted.
"""

from __future__ import annotations

import hashlib
import itertools
import json
import os
import shutil
import subprocess
import tempfile
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from mcp.server.fastmcp import FastMCP, Image
from mcp.types import CallToolResult, TextContent
from PIL import Image as PILImage
from PIL import ImageChops, ImageStat


MAX_SHADER_BYTES = 512_000
STUDY_DIVERSITY_MEAN_MAE_MIN = 1.0
STUDY_DIVERSITY_MAX_MAE_MIN = 1.75
STUDY_CROSS_PASS_MAE_MIN = 1.0
STUDY_CROSS_TOPIC_MAE_MIN = 0.5


def _structural_manifest_errors(manifest: str) -> list[str]:
    """Validate auditable A-F representation-family declarations."""
    upper = manifest.upper()
    labels = ("A:", "B:", "C:", "D:", "E:", "F:")
    errors: list[str] = []
    for index, label in enumerate(labels):
        start = upper.find(label)
        if start < 0:
            errors.append(f"{label} missing")
            continue
        end = (
            upper.find(labels[index + 1], start + len(label))
            if index + 1 < len(labels)
            else len(upper)
        )
        section = upper[start:end]
        for field_name in (
            "FAMILY=",
            "CONSTRUCTION=",
            "STRUCTURAL_DIFFERENCE=",
        ):
            if field_name not in section:
                errors.append(f"{label} missing {field_name.lower()}")
    if len(manifest.strip()) < 480:
        errors.append("manifest shorter than 480 characters")
    return errors


def _atlas_diversity_metrics(path: Path) -> dict[str, Any]:
    """Measure visible A-F cell separation in a fixed 3x2 study atlas."""
    image = PILImage.open(path).convert("RGB")
    width, height = image.size
    cells: list[PILImage.Image] = []
    for row in range(2):
        for column in range(3):
            left = column * width // 3
            right = (column + 1) * width // 3
            top = row * height // 2
            bottom = (row + 1) * height // 2
            inset_x = max(1, (right - left) // 50)
            inset_y = max(1, (bottom - top) // 50)
            cell = image.crop(
                (
                    left + inset_x,
                    top + inset_y,
                    right - inset_x,
                    bottom - inset_y,
                )
            )
            cells.append(cell.resize((96, 96)))

    pairwise_mae: list[float] = []
    for first, second in itertools.combinations(cells, 2):
        difference = ImageChops.difference(first, second)
        channel_means = ImageStat.Stat(difference).mean
        pairwise_mae.append(
            sum(channel_means) / (len(channel_means) * 255.0) * 100.0
        )
    mean_mae = sum(pairwise_mae) / len(pairwise_mae)
    max_mae = max(pairwise_mae)
    qualifies = (
        mean_mae >= STUDY_DIVERSITY_MEAN_MAE_MIN
        and max_mae >= STUDY_DIVERSITY_MAX_MAE_MIN
    )
    return {
        "method": "3x2-cell-pairwise-rgb-mae-v1",
        "pair_count": len(pairwise_mae),
        "min_pairwise_mae_percent": round(min(pairwise_mae), 3),
        "mean_pairwise_mae_percent": round(mean_mae, 3),
        "max_pairwise_mae_percent": round(max_mae, 3),
        "mean_threshold_percent": STUDY_DIVERSITY_MEAN_MAE_MIN,
        "max_threshold_percent": STUDY_DIVERSITY_MAX_MAE_MIN,
        "qualifies": qualifies,
    }


def _image_mae_percent(first_path: Path, second_path: Path) -> float:
    """Measure whole-image RGB separation between two study atlases."""
    first = PILImage.open(first_path).convert("RGB").resize((192, 192))
    second = PILImage.open(second_path).convert("RGB").resize((192, 192))
    difference = ImageChops.difference(first, second)
    channel_means = ImageStat.Stat(difference).mean
    return sum(channel_means) / (len(channel_means) * 255.0) * 100.0


def _cross_render_diversity_metrics(
    current_path: Path,
    study_index: int,
    prior_paths: dict[int, list[Path]],
) -> dict[str, Any]:
    """Reject recycled atlases within a study or across study topics."""
    same_study = [
        _image_mae_percent(current_path, prior_path)
        for prior_path in prior_paths.get(study_index, [])
    ]
    other_studies = [
        _image_mae_percent(current_path, prior_path)
        for prior_study, paths in prior_paths.items()
        if prior_study != study_index
        for prior_path in paths
    ]
    same_study_min = min(same_study) if same_study else None
    other_study_min = min(other_studies) if other_studies else None
    qualifies = (
        (same_study_min is None or same_study_min >= STUDY_CROSS_PASS_MAE_MIN)
        and (
            other_study_min is None
            or other_study_min >= STUDY_CROSS_TOPIC_MAE_MIN
        )
    )
    return {
        "method": "whole-atlas-rgb-mae-v1",
        "same_study_comparisons": len(same_study),
        "other_study_comparisons": len(other_studies),
        "same_study_min_mae_percent": (
            round(same_study_min, 3) if same_study_min is not None else None
        ),
        "other_study_min_mae_percent": (
            round(other_study_min, 3) if other_study_min is not None else None
        ),
        "same_study_threshold_percent": STUDY_CROSS_PASS_MAE_MIN,
        "other_study_threshold_percent": STUDY_CROSS_TOPIC_MAE_MIN,
        "qualifies": qualifies,
    }


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        dir=path.parent,
        prefix=f".{path.name}.",
        delete=False,
    ) as handle:
        handle.write(content)
        temporary_path = Path(handle.name)
    temporary_path.replace(path)


@dataclass
class ShaderAgentState:
    workspace: Path
    renderer: Path
    render_budget: int
    render_size: int = 1024
    min_successful_revisions: int = 1
    required_studies: int = 0
    require_variant_inventory: bool = False
    min_successful_study_renders: int = 1
    require_study_diversity: bool = False
    revision: int = 0
    render_calls: int = 0
    submitted: bool = False
    current_hash: str | None = None
    successful_render_by_revision: dict[int, Path] = field(default_factory=dict)
    successful_render_stage_by_revision: dict[int, str] = field(
        default_factory=dict
    )
    latest_successful_study_render: dict[int, dict[str, int]] = field(
        default_factory=dict
    )
    successful_study_render_count: dict[int, int] = field(default_factory=dict)
    qualified_study_render_paths: dict[int, list[Path]] = field(
        default_factory=dict
    )
    study_records: dict[int, dict[str, Any]] = field(default_factory=dict)
    attempted_revisions: set[int] = field(default_factory=set)
    events: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.workspace = self.workspace.resolve()
        self.renderer = self.renderer.resolve()
        if self.render_budget < 1:
            raise ValueError("render budget must be at least 1")
        if not 1 <= self.min_successful_revisions <= self.render_budget:
            raise ValueError(
                "min_successful_revisions must be between 1 and render_budget"
            )
        if not 0 <= self.required_studies <= 8:
            raise ValueError("required_studies must be between 0 and 8")
        if self.min_successful_study_renders < 1:
            raise ValueError("min_successful_study_renders must be at least 1")
        minimum_budget = (
            self.required_studies * self.min_successful_study_renders
            + self.min_successful_revisions
        )
        if self.render_budget < minimum_budget:
            raise ValueError(
                "render budget must allow every required study plus the "
                "minimum successful final revisions"
            )
        if not self.renderer.is_file():
            raise FileNotFoundError(f"renderer not found: {self.renderer}")
        self.workspace.mkdir(parents=True, exist_ok=True)
        (self.workspace / "renders").mkdir(exist_ok=True)
        self._persist()

    @property
    def shader_path(self) -> Path:
        return self.workspace / "shader.wgsl"

    @property
    def state_path(self) -> Path:
        return self.workspace / "agent_state.json"

    def _event(self, event_type: str, **details: Any) -> None:
        self.events.append(
            {"timestamp": _utc_now(), "type": event_type, **details}
        )
        self._persist()

    def _persist(self) -> None:
        payload = {
            "protocol": "persistent-agent-render-tools-v5",
            "render_budget": self.render_budget,
            "render_calls": self.render_calls,
            "remaining_renders": max(0, self.render_budget - self.render_calls),
            "min_successful_revisions": self.min_successful_revisions,
            "successful_revisions": len(self.successful_render_by_revision),
            "successful_final_revisions": sum(
                stage == "final"
                for stage in self.successful_render_stage_by_revision.values()
            ),
            "required_studies": self.required_studies,
            "require_variant_inventory": self.require_variant_inventory,
            "min_successful_study_renders": self.min_successful_study_renders,
            "require_study_diversity": self.require_study_diversity,
            "successful_study_render_count": self.successful_study_render_count,
            "qualified_study_render_paths": {
                str(index): [str(path) for path in paths]
                for index, paths in self.qualified_study_render_paths.items()
            },
            "completed_studies": sorted(self.study_records),
            "study_records": self.study_records,
            "revision": self.revision,
            "current_hash": self.current_hash,
            "submitted": self.submitted,
            "events": self.events,
        }
        _atomic_write(self.state_path, json.dumps(payload, indent=2))

    def write_shader(
        self,
        shader_source: str,
        revision_critique: str = "",
    ) -> dict[str, Any]:
        """Replace the one permitted shader file with a complete WGSL program."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        encoded = shader_source.encode("utf-8")
        if not shader_source.strip():
            return {"ok": False, "error": "shader_source cannot be empty"}
        if len(encoded) > MAX_SHADER_BYTES:
            return {
                "ok": False,
                "error": f"shader exceeds the {MAX_SHADER_BYTES}-byte limit",
            }
        if self.revision >= 1 and len(revision_critique.strip()) < 40:
            return {
                "ok": False,
                "error": (
                    "A rewrite after revision 1 requires a concrete "
                    "revision_critique of at least 40 characters comparing "
                    "the rendered image with the target."
                ),
            }

        self.revision += 1
        self.current_hash = hashlib.sha256(encoded).hexdigest()
        _atomic_write(self.shader_path, shader_source)
        revision_path = (
            self.workspace / "renders" / f"revision_{self.revision:02d}.wgsl"
        )
        shutil.copy2(self.shader_path, revision_path)
        result = {
            "ok": True,
            "revision": self.revision,
            "sha256": self.current_hash,
            "bytes": len(encoded),
            "remaining_renders": self.render_budget - self.render_calls,
            "revision_critique": revision_critique.strip()[:4_000],
        }
        self._event("write_shader", **result)
        return result

    def render_shader(
        self,
        stage: str = "final",
        study_index: int = 0,
        variation_manifest: str = "",
    ) -> tuple[dict[str, Any], Path | None]:
        """Render the current revision and return metadata plus its image path."""
        if stage not in {"study", "final"}:
            result = {
                "ok": False,
                "error": "stage must be either 'study' or 'final'.",
            }
            self._event("render_rejected", **result)
            return result, None
        if stage == "study":
            if not 1 <= study_index <= self.required_studies:
                result = {
                    "ok": False,
                    "error": (
                        "study_index must identify one of the required "
                        f"studies (1-{self.required_studies})."
                    ),
                }
                self._event("render_rejected", **result)
                return result, None
            missing_prior = [
                index
                for index in range(1, study_index)
                if index not in self.study_records
            ]
            if missing_prior:
                result = {
                    "ok": False,
                    "error": (
                        "Record each earlier study before rendering this one, "
                        "so later studies can reuse the selected construction."
                    ),
                    "missing_prior_studies": missing_prior,
                }
                self._event("render_rejected", **result)
                return result, None
            if self.require_study_diversity:
                manifest = variation_manifest.strip()
                missing_variants = [
                    label
                    for label in ("A:", "B:", "C:", "D:", "E:", "F:")
                    if label not in manifest.upper()
                ]
                if len(manifest) < 180 or missing_variants:
                    result = {
                        "ok": False,
                        "error": (
                            "variation_manifest must predeclare materially "
                            "different A: through F: constructions in at least "
                            "180 characters before this study render."
                        ),
                        "missing_variant_labels": missing_variants,
                        "render_budget_consumed": False,
                    }
                    self._event("render_rejected", **result)
                    return result, None
                if self.min_successful_study_renders >= 3:
                    structural_errors = _structural_manifest_errors(manifest)
                    if structural_errors:
                        result = {
                            "ok": False,
                            "error": (
                                "This wide-search study requires an auditable "
                                "A-F structural manifest. Every variant needs "
                                "family=, construction=, and "
                                "structural_difference= fields."
                            ),
                            "structural_manifest_errors": structural_errors,
                            "render_budget_consumed": False,
                        }
                        self._event("render_rejected", **result)
                        return result, None
        elif study_index != 0:
            result = {
                "ok": False,
                "error": "study_index must be 0 for a final render.",
            }
            self._event("render_rejected", **result)
            return result, None
        if stage == "final" and len(self.study_records) < self.required_studies:
            result = {
                "ok": False,
                "error": (
                    "Complete and record every required visual study before "
                    "rendering the final reconstruction."
                ),
                "completed_studies": sorted(self.study_records),
                "required_studies": self.required_studies,
            }
            self._event("render_rejected", **result)
            return result, None
        if self.submitted:
            result = {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
            self._event("render_rejected", **result)
            return result, None
        if self.render_calls >= self.render_budget:
            result = {
                "ok": False,
                "error": "Render budget exhausted.",
                "render_budget": self.render_budget,
                "render_calls": self.render_calls,
            }
            self._event("render_rejected", **result)
            return result, None
        if not self.shader_path.exists():
            result = {
                "ok": False,
                "error": "No shader exists. Call write_shader first.",
            }
            self._event("render_rejected", **result)
            return result, None
        if self.revision in self.attempted_revisions:
            result = {
                "ok": False,
                "error": (
                    "This exact revision has already been rendered or attempted. "
                    "Inspect the existing feedback, call write_shader with a "
                    "revised complete program, then render the new revision."
                ),
                "revision": self.revision,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("render_rejected", **result)
            return result, None

        self.render_calls += 1
        self.attempted_revisions.add(self.revision)
        call_number = self.render_calls
        output_path = (
            self.workspace / "renders" / f"render_{call_number:02d}.png"
        )
        log_path = (
            self.workspace / "renders" / f"render_{call_number:02d}.log"
        )
        shader_snapshot = (
            self.workspace
            / "renders"
            / f"render_{call_number:02d}_revision_{self.revision:02d}.wgsl"
        )
        shutil.copy2(self.shader_path, shader_snapshot)

        command = [
            str(self.renderer),
            "--shader",
            str(self.shader_path),
            "--output",
            str(output_path),
            "--size",
            str(self.render_size),
        ]
        try:
            completed = subprocess.run(
                command,
                cwd=self.workspace,
                capture_output=True,
                text=True,
                timeout=120,
            )
            stdout = completed.stdout or ""
            stderr = completed.stderr or ""
            returncode = completed.returncode
        except subprocess.TimeoutExpired as exc:
            stdout = exc.stdout or ""
            stderr = (exc.stderr or "") + "\nRenderer timed out after 120s."
            returncode = 124

        log_path.write_text(
            "COMMAND\n"
            + " ".join(command)
            + "\n\nSTDOUT\n"
            + stdout
            + "\n\nSTDERR\n"
            + stderr,
            encoding="utf-8",
        )
        success = returncode == 0 and output_path.is_file()
        if success:
            self.successful_render_by_revision[self.revision] = output_path
            self.successful_render_stage_by_revision[self.revision] = stage
            if stage == "study":
                study_pass = (
                    self.successful_study_render_count.get(study_index, 0) + 1
                )
                study_diversity = _atlas_diversity_metrics(output_path)
                cross_render_diversity = _cross_render_diversity_metrics(
                    output_path,
                    study_index,
                    self.qualified_study_render_paths,
                )
                study_pass_qualified = (
                    not self.require_study_diversity
                    or (
                        bool(study_diversity["qualifies"])
                        and bool(cross_render_diversity["qualifies"])
                    )
                )
                if study_pass_qualified:
                    self.successful_study_render_count[study_index] = study_pass
                    self.qualified_study_render_paths.setdefault(
                        study_index, []
                    ).append(output_path)
                    self.latest_successful_study_render[study_index] = {
                        "revision": self.revision,
                        "render_call": call_number,
                        "study_pass": study_pass,
                    }
                    self.study_records.pop(study_index, None)
            else:
                study_pass = 0
                study_diversity = None
                cross_render_diversity = None
                study_pass_qualified = True
        else:
            study_pass = 0
            study_diversity = None
            cross_render_diversity = None
            study_pass_qualified = False

        result = {
            "ok": success,
            "render_call": call_number,
            "render_budget": self.render_budget,
            "remaining_renders": self.render_budget - call_number,
            "revision": self.revision,
            "stage": stage,
            "study_index": study_index,
            "study_pass": study_pass,
            "study_pass_qualified": study_pass_qualified,
            "study_diversity": study_diversity,
            "cross_render_diversity": cross_render_diversity,
            "variation_manifest": variation_manifest.strip()[:4_000],
            "sha256": self.current_hash,
            "image": str(output_path) if success else None,
            "log": str(log_path),
            "returncode": returncode,
            "compiler_feedback": (stderr + "\n" + stdout).strip()[-12_000:],
        }
        self._event("render_shader", **result)
        return result, output_path if success else None

    def record_study(
        self,
        study_index: int,
        subject: str,
        selected_variant: str,
        selection_rationale: str,
        handoff_requirements: str,
        variant_inventory: str = "",
    ) -> dict[str, Any]:
        """Record public evidence from a successfully rendered study atlas."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        rendered = self.latest_successful_study_render.get(study_index)
        if rendered is None:
            return {
                "ok": False,
                "error": (
                    "Render this study successfully before recording its "
                    "selection."
                ),
            }
        successful_passes = self.successful_study_render_count.get(
            study_index, 0
        )
        if successful_passes < self.min_successful_study_renders:
            return {
                "ok": False,
                "error": (
                    "This study needs more distinct successful render passes "
                    "before selection can be recorded."
                ),
                "successful_study_renders": successful_passes,
                "min_successful_study_renders": (
                    self.min_successful_study_renders
                ),
            }
        variant = selected_variant.strip().upper()
        if variant not in {"A", "B", "C", "D", "E", "F"}:
            return {
                "ok": False,
                "error": "selected_variant must be one of A, B, C, D, E, or F.",
            }
        if len(subject.strip()) < 4:
            return {"ok": False, "error": "subject is too short."}
        if self.require_variant_inventory:
            inventory = variant_inventory.strip()
            missing_variants = [
                label
                for label in ("A:", "B:", "C:", "D:", "E:", "F:")
                if label not in inventory.upper()
            ]
            if len(inventory) < 180 or missing_variants:
                return {
                    "ok": False,
                    "error": (
                        "variant_inventory must describe materially distinct "
                        "A: through F: constructions in at least 180 characters."
                    ),
                    "missing_variant_labels": missing_variants,
                }
        if len(selection_rationale.strip()) < 80:
            return {
                "ok": False,
                "error": (
                    "selection_rationale must contain at least 80 characters "
                    "of visible comparison evidence."
                ),
            }
        if len(handoff_requirements.strip()) < 80:
            return {
                "ok": False,
                "error": (
                    "handoff_requirements must contain at least 80 characters "
                    "naming the reusable code, coordinates, and parameters."
                ),
            }
        record = {
            "study_index": study_index,
            "subject": subject.strip()[:300],
            "selected_variant": variant,
            "variant_inventory": variant_inventory.strip()[:4_000],
            "selection_rationale": selection_rationale.strip()[:4_000],
            "handoff_requirements": handoff_requirements.strip()[:4_000],
            **rendered,
        }
        self.study_records[study_index] = record
        result = {
            "ok": True,
            **record,
            "completed_studies": sorted(self.study_records),
            "required_studies": self.required_studies,
        }
        self._event("record_study", **result)
        return result

    def submit_final(self, summary: str = "") -> dict[str, Any]:
        """Freeze the current revision, which must have rendered successfully."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        rendered_path = self.successful_render_by_revision.get(self.revision)
        if rendered_path is None:
            result = {
                "ok": False,
                "error": (
                    "The current shader revision has not rendered successfully. "
                    "Render this exact revision before submitting."
                ),
                "revision": self.revision,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("submit_rejected", **result)
            return result
        if self.successful_render_stage_by_revision.get(self.revision) != "final":
            result = {
                "ok": False,
                "error": (
                    "The current revision is a study atlas, not a final "
                    "reconstruction. Integrate the selected studies and render "
                    "the final stage before submitting."
                ),
            }
            self._event("submit_rejected", **result)
            return result
        if len(self.study_records) < self.required_studies:
            result = {
                "ok": False,
                "error": "Every required study must be recorded before submission.",
                "completed_studies": sorted(self.study_records),
                "required_studies": self.required_studies,
            }
            self._event("submit_rejected", **result)
            return result
        successful_final_revisions = sum(
            stage == "final"
            for stage in self.successful_render_stage_by_revision.values()
        )
        if successful_final_revisions < self.min_successful_revisions:
            result = {
                "ok": False,
                "error": (
                    "More distinct successfully rendered revisions are required "
                    "before submission."
                ),
                "successful_revisions": successful_final_revisions,
                "min_successful_revisions": self.min_successful_revisions,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("submit_rejected", **result)
            return result

        final_shader = self.workspace / "final_shader.wgsl"
        final_render = self.workspace / "final_render.png"
        shutil.copy2(self.shader_path, final_shader)
        shutil.copy2(rendered_path, final_render)
        self.submitted = True
        result = {
            "ok": True,
            "revision": self.revision,
            "sha256": self.current_hash,
            "render_call": next(
                (
                    event["render_call"]
                    for event in reversed(self.events)
                    if event.get("type") == "render_shader"
                    and event.get("revision") == self.revision
                    and event.get("ok")
                ),
                None,
            ),
            "render_calls_used": self.render_calls,
            "render_budget": self.render_budget,
            "final_shader": str(final_shader),
            "final_render": str(final_render),
            "summary": summary[:4_000],
        }
        self._event("submit_final", **result)
        (self.workspace / "submission.json").write_text(
            json.dumps(result, indent=2), encoding="utf-8"
        )
        return result


def _state_from_environment() -> ShaderAgentState:
    required = (
        "SHADER_AGENT_WORKSPACE",
        "SHADER_AGENT_RENDERER",
        "SHADER_AGENT_RENDER_BUDGET",
    )
    missing = [name for name in required if not os.environ.get(name)]
    if missing:
        raise RuntimeError(
            "Missing shader-agent environment variables: " + ", ".join(missing)
        )
    return ShaderAgentState(
        workspace=Path(os.environ["SHADER_AGENT_WORKSPACE"]),
        renderer=Path(os.environ["SHADER_AGENT_RENDERER"]),
        render_budget=int(os.environ["SHADER_AGENT_RENDER_BUDGET"]),
        render_size=int(os.environ.get("SHADER_AGENT_RENDER_SIZE", "1024")),
        min_successful_revisions=int(
            os.environ.get("SHADER_AGENT_MIN_SUCCESSFUL_REVISIONS", "1")
        ),
        required_studies=int(
            os.environ.get("SHADER_AGENT_REQUIRED_STUDIES", "0")
        ),
        require_variant_inventory=(
            os.environ.get("SHADER_AGENT_REQUIRE_VARIANT_INVENTORY", "0") == "1"
        ),
        min_successful_study_renders=int(
            os.environ.get(
                "SHADER_AGENT_MIN_SUCCESSFUL_STUDY_RENDERS", "1"
            )
        ),
        require_study_diversity=(
            os.environ.get("SHADER_AGENT_REQUIRE_STUDY_DIVERSITY", "0") == "1"
        ),
    )


def create_mcp(state: ShaderAgentState) -> FastMCP:
    """Bind the fixed workspace state to the bounded MCP surface."""
    server = FastMCP(
        "shader-render-tools",
        instructions=(
            "Work only through write_shader, render_shader, record_study, and "
            "submit_final. "
            "Every render consumes one unit of the fixed budget, including "
            "compile failures. Inspect each returned image before revising. "
            "When required, variation_manifest must predeclare materially "
            "different A-F constructions before a study render. "
            "Three-pass wide-search studies require family=, construction=, "
            "and structural_difference= for every A-F entry. "
            "When study_pass_qualified is false, the atlas was too visually "
            "similar internally or recycled a prior pass/topic, so it must be "
            "revised despite compiling. "
            "submit_final accepts only the current revision after a successful "
            "render."
        ),
    )

    @server.tool()
    def write_shader(
        shader_source: str,
        revision_critique: str = "",
    ) -> str:
        """Write complete WGSL; rewrites require a target/render critique."""
        return json.dumps(
            state.write_shader(shader_source, revision_critique), indent=2
        )

    @server.tool(structured_output=False)
    def render_shader(
        stage: str = "final",
        study_index: int = 0,
        variation_manifest: str = "",
    ) -> CallToolResult:
        """Render the current shader. Return compiler feedback and the image."""
        result, image_path = state.render_shader(
            stage, study_index, variation_manifest
        )
        content: list[Any] = [
            TextContent(type="text", text=json.dumps(result, indent=2))
        ]
        if image_path is not None:
            content.append(Image(path=image_path).to_image_content())
        return CallToolResult(content=content, isError=False)

    @server.tool()
    def record_study(
        study_index: int,
        subject: str,
        selected_variant: str,
        selection_rationale: str,
        handoff_requirements: str,
        variant_inventory: str = "",
    ) -> str:
        """Record the chosen A-F cell and exact final-scene handoff."""
        return json.dumps(
            state.record_study(
                study_index,
                subject,
                selected_variant,
                selection_rationale,
                handoff_requirements,
                variant_inventory,
            ),
            indent=2,
        )

    @server.tool()
    def submit_final(summary: str = "") -> str:
        """Submit the current successfully rendered revision as final."""
        return json.dumps(state.submit_final(summary), indent=2)

    return server


if __name__ == "__main__":
    create_mcp(_state_from_environment()).run(transport="stdio")
