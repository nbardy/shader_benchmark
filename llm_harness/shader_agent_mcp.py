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
import math
import os
import re
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
from PIL import ImageChops, ImageDraw, ImageStat


MAX_SHADER_BYTES = 512_000
STUDY_DIVERSITY_MEAN_MAE_MIN = 1.0
STUDY_DIVERSITY_MAX_MAE_MIN = 1.75
STUDY_CROSS_PASS_MAE_MIN = 1.0
STUDY_CROSS_TOPIC_MAE_MIN = 0.5
ARTIFACT_MARKER_RE = re.compile(
    r"(?ms)^// @shaderbench-artifact-begin "
    r"id=(study_(\d+)_([A-F])) entry=([A-Za-z_][A-Za-z0-9_]*)[ \t]*\n"
    r"(.*?)"
    r"^// @shaderbench-artifact-end id=\1[ \t]*(?:\n|$)"
)
ARTIFACT_BEGIN_RE = re.compile(
    r"(?m)^// @shaderbench-artifact-begin[^\n]*$"
)
ARTIFACT_END_RE = re.compile(
    r"(?m)^// @shaderbench-artifact-end[^\n]*$"
)
ARTIFACT_INJECT_RE = re.compile(
    r"(?m)^// @shaderbench-inject id=(study_\d+_[A-F])[ \t]*(?:\n|$)"
)
VARIANTS = ("A", "B", "C", "D", "E", "F")


def _extract_artifact_blocks(shader_source: str) -> dict[str, dict[str, Any]]:
    """Extract exact, server-addressable study candidate blocks."""
    blocks: dict[str, dict[str, Any]] = {}
    for match in ARTIFACT_MARKER_RE.finditer(shader_source):
        artifact_id = match.group(1)
        if artifact_id in blocks:
            raise ValueError(f"duplicate artifact block: {artifact_id}")
        exact_source = match.group(0)
        blocks[artifact_id] = {
            "artifact_id": artifact_id,
            "study_index": int(match.group(2)),
            "variant": match.group(3),
            "entry_symbol": match.group(4),
            "source": exact_source,
            "sha256": hashlib.sha256(exact_source.encode("utf-8")).hexdigest(),
        }
    return blocks


def _artifact_manifest_errors(
    shader_source: str,
    study_index: int,
) -> list[str]:
    """Require one uniquely marked, callable implementation for every A-F cell."""
    errors: list[str] = []
    try:
        blocks = _extract_artifact_blocks(shader_source)
    except ValueError as error:
        return [str(error)]
    begin_count = len(ARTIFACT_BEGIN_RE.findall(shader_source))
    end_count = len(ARTIFACT_END_RE.findall(shader_source))
    if begin_count != end_count or begin_count != len(blocks):
        errors.append(
            "artifact markers are malformed, nested, duplicated, or unmatched"
        )
    expected = {f"study_{study_index}_{variant}" for variant in VARIANTS}
    present = {
        artifact_id
        for artifact_id, block in blocks.items()
        if block["study_index"] == study_index
    }
    for artifact_id in sorted(expected - present):
        errors.append(f"{artifact_id} missing")
    for artifact_id in sorted(present - expected):
        errors.append(f"unexpected current-study artifact {artifact_id}")
    entries = [
        blocks[artifact_id]["entry_symbol"]
        for artifact_id in sorted(expected & present)
    ]
    if len(entries) != len(set(entries)):
        errors.append("A-F entry symbols must be unique")
    for artifact_id in sorted(expected & present):
        block = blocks[artifact_id]
        outside = shader_source.replace(block["source"], "", 1)
        if not re.search(
            rf"\b{re.escape(block['entry_symbol'])}\s*\(",
            outside,
        ):
            errors.append(
                f"{artifact_id} entry {block['entry_symbol']} is never called"
            )
    return errors


def _crop_atlas_cell(path: Path, variant: str) -> PILImage.Image:
    """Crop an A-F cell from the canonical three-column, two-row atlas."""
    index = VARIANTS.index(variant)
    image = PILImage.open(path).convert("RGB")
    width, height = image.size
    column = index % 3
    row = index // 3
    return image.crop(
        (
            column * width // 3,
            row * height // 2,
            (column + 1) * width // 3,
            (row + 1) * height // 2,
        )
    )


def _parse_selector_output(raw: str) -> dict[str, Any]:
    """Parse the selector's strict JSON response without accepting prose fallback."""
    candidate = raw.strip()
    if candidate.startswith("```"):
        lines = candidate.splitlines()
        if len(lines) >= 3 and lines[-1].strip() == "```":
            candidate = "\n".join(lines[1:-1])
            if candidate.lstrip().startswith("json"):
                candidate = candidate.lstrip()[4:].lstrip()
    if not candidate.startswith("{"):
        start = candidate.find("{")
        end = candidate.rfind("}")
        if start >= 0 and end > start:
            candidate = candidate[start : end + 1]
    parsed = json.loads(candidate)
    if not isinstance(parsed, dict):
        raise ValueError("selector response must be a JSON object")
    return parsed


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
    require_artifact_blocks: bool = False
    require_study_selector: bool = False
    require_study_promotions: bool = False
    reference_image: Path | None = None
    selector_model: str = "gpt-5.5"
    selector_effort: str = "high"
    selector_runner: Any | None = field(default=None, repr=False)
    resume_existing: bool = False
    revision: int = 0
    render_calls: int = 0
    submitted: bool = False
    current_hash: str | None = None
    successful_render_by_revision: dict[int, Path] = field(default_factory=dict)
    successful_render_stage_by_revision: dict[int, str] = field(
        default_factory=dict
    )
    successful_render_hash_by_revision: dict[int, str] = field(
        default_factory=dict
    )
    latest_successful_study_render: dict[int, dict[str, int]] = field(
        default_factory=dict
    )
    latest_successful_promotion_render: dict[int, dict[str, int]] = field(
        default_factory=dict
    )
    successful_study_render_count: dict[int, int] = field(default_factory=dict)
    qualified_study_render_paths: dict[int, list[Path]] = field(
        default_factory=dict
    )
    qualified_study_candidates: dict[int, list[dict[str, Any]]] = field(
        default_factory=dict
    )
    study_rankings: dict[int, dict[str, Any]] = field(default_factory=dict)
    study_records: dict[int, dict[str, Any]] = field(default_factory=dict)
    promotion_records: dict[int, dict[str, Any]] = field(default_factory=dict)
    locked_artifacts: dict[str, dict[str, Any]] = field(default_factory=dict)
    attempted_revisions: set[int] = field(default_factory=set)
    events: list[dict[str, Any]] = field(default_factory=list)

    def __post_init__(self) -> None:
        self.workspace = self.workspace.resolve()
        self.renderer = self.renderer.resolve()
        if self.reference_image is not None:
            self.reference_image = self.reference_image.resolve()
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
            + (
                self.required_studies
                if self.require_study_promotions
                else 0
            )
            + self.min_successful_revisions
        )
        if self.render_budget < minimum_budget:
            raise ValueError(
                "render budget must allow every required study plus the "
                "minimum successful final revisions"
            )
        if not self.renderer.is_file():
            raise FileNotFoundError(f"renderer not found: {self.renderer}")
        if self.require_study_selector and (
            self.reference_image is None or not self.reference_image.is_file()
        ):
            raise FileNotFoundError(
                "an isolated reference image is required for study selection"
            )
        if self.require_study_promotions and not self.require_artifact_blocks:
            raise ValueError(
                "study promotions require exact artifact blocks"
            )
        self.workspace.mkdir(parents=True, exist_ok=True)
        (self.workspace / "renders").mkdir(exist_ok=True)
        (self.workspace / "artifacts").mkdir(exist_ok=True)
        (self.workspace / "selectors").mkdir(exist_ok=True)
        if self.resume_existing:
            if not self.state_path.is_file():
                raise FileNotFoundError(
                    f"resume checkpoint not found: {self.state_path}"
                )
            self._load_checkpoint()
        else:
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

    def _load_checkpoint(self) -> None:
        """Rehydrate exact state after an interrupted outer model session."""
        payload = json.loads(self.state_path.read_text(encoding="utf-8"))
        if payload.get("protocol") != "persistent-agent-render-tools-v8":
            raise ValueError("only v8 shader-agent checkpoints can resume")
        if int(payload.get("render_budget", -1)) != self.render_budget:
            raise ValueError("resume render budget does not match checkpoint")
        self.revision = int(payload.get("revision", 0))
        self.render_calls = int(payload.get("render_calls", 0))
        self.submitted = bool(payload.get("submitted", False))
        self.current_hash = payload.get("current_hash")
        self.events = list(payload.get("events", []))
        self.attempted_revisions = {
            int(event["revision"])
            for event in self.events
            if event.get("type") == "render_shader"
            and event.get("revision") is not None
        }
        for event in self.events:
            if event.get("type") != "render_shader" or not event.get("ok"):
                continue
            revision = int(event["revision"])
            image_path = event.get("image")
            if image_path:
                self.successful_render_by_revision[revision] = Path(image_path)
            self.successful_render_stage_by_revision[revision] = str(
                event.get("stage", "final")
            )
            if event.get("sha256"):
                self.successful_render_hash_by_revision[revision] = str(
                    event["sha256"]
                )
            if event.get("stage") == "promotion":
                self.latest_successful_promotion_render[
                    int(event["study_index"])
                ] = {
                    "revision": revision,
                    "render_call": int(event["render_call"]),
                }
        self.successful_study_render_count = {
            int(index): int(count)
            for index, count in payload.get(
                "successful_study_render_count", {}
            ).items()
        }
        self.qualified_study_render_paths = {
            int(index): [Path(path) for path in paths]
            for index, paths in payload.get(
                "qualified_study_render_paths", {}
            ).items()
        }
        self.qualified_study_candidates = {
            int(index): [
                {
                    **candidate,
                    "atlas_path": Path(candidate["atlas_path"]),
                    "source_path": Path(candidate["source_path"]),
                }
                for candidate in candidates
            ]
            for index, candidates in payload.get(
                "qualified_study_candidates", {}
            ).items()
        }
        for study_index, candidates in self.qualified_study_candidates.items():
            if not candidates:
                continue
            latest = max(candidates, key=lambda item: int(item["render_call"]))
            self.latest_successful_study_render[study_index] = {
                "revision": int(latest["revision"]),
                "render_call": int(latest["render_call"]),
                "study_pass": int(latest["study_pass"]),
            }
        self.study_rankings = {
            int(index): record
            for index, record in payload.get("study_rankings", {}).items()
        }
        self.study_records = {
            int(index): record
            for index, record in payload.get("study_records", {}).items()
        }
        self.promotion_records = {
            int(index): record
            for index, record in payload.get("promotion_records", {}).items()
        }
        for artifact_id, metadata in payload.get(
            "locked_artifacts", {}
        ).items():
            source_path = Path(metadata["artifact_source_path"])
            if not source_path.is_file():
                raise FileNotFoundError(
                    f"locked artifact source missing: {source_path}"
                )
            self.locked_artifacts[artifact_id] = {
                **metadata,
                "source": source_path.read_text(encoding="utf-8"),
            }

    def _persist(self) -> None:
        payload = {
            "protocol": "persistent-agent-render-tools-v8",
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
            "require_artifact_blocks": self.require_artifact_blocks,
            "require_study_selector": self.require_study_selector,
            "require_study_promotions": self.require_study_promotions,
            "selector_model": self.selector_model,
            "selector_effort": self.selector_effort,
            "successful_study_render_count": self.successful_study_render_count,
            "qualified_study_render_paths": {
                str(index): [str(path) for path in paths]
                for index, paths in self.qualified_study_render_paths.items()
            },
            "qualified_study_candidates": {
                str(index): [
                    {
                        key: str(value) if isinstance(value, Path) else value
                        for key, value in candidate.items()
                    }
                    for candidate in candidates
                ]
                for index, candidates in self.qualified_study_candidates.items()
            },
            "study_rankings": self.study_rankings,
            "completed_studies": sorted(self.study_records),
            "study_records": self.study_records,
            "completed_promotions": sorted(self.promotion_records),
            "promotion_records": self.promotion_records,
            "locked_artifacts": {
                artifact_id: {
                    key: value
                    for key, value in artifact.items()
                    if key != "source"
                }
                for artifact_id, artifact in self.locked_artifacts.items()
            },
            "revision": self.revision,
            "current_hash": self.current_hash,
            "submitted": self.submitted,
            "events": self.events,
        }
        _atomic_write(self.state_path, json.dumps(payload, indent=2))

    def _locked_artifact_errors(self, shader_source: str) -> list[str]:
        """Reject missing, edited, or dead-only promoted implementations."""
        if not self.locked_artifacts:
            return []
        try:
            blocks = _extract_artifact_blocks(shader_source)
        except ValueError as error:
            return [str(error)]
        errors: list[str] = []
        for artifact_id, locked in sorted(self.locked_artifacts.items()):
            current = blocks.get(artifact_id)
            if current is None:
                errors.append(f"locked artifact {artifact_id} is missing")
                continue
            if current["source"] != locked["source"]:
                errors.append(
                    f"locked artifact {artifact_id} changed byte-for-byte"
                )
                continue
            outside = shader_source.replace(current["source"], "", 1)
            entry_symbol = locked["entry_symbol"]
            if not re.search(
                rf"\b{re.escape(entry_symbol)}\s*\(",
                outside,
            ):
                errors.append(
                    f"locked artifact {artifact_id} entry "
                    f"{entry_symbol} is not called outside its definition"
                )
        return errors

    def _expand_locked_artifact_injections(
        self,
        shader_source: str,
    ) -> tuple[str, list[str], list[str]]:
        """Replace server-owned placeholders with exact immutable source."""
        errors: list[str] = []
        injected: list[str] = []
        matches: dict[str, int] = {}
        for match in ARTIFACT_INJECT_RE.finditer(shader_source):
            artifact_id = match.group(1)
            matches[artifact_id] = matches.get(artifact_id, 0) + 1
        for artifact_id, count in sorted(matches.items()):
            if artifact_id not in self.locked_artifacts:
                errors.append(
                    f"cannot inject unknown or unselected artifact {artifact_id}"
                )
            if count != 1:
                errors.append(
                    f"artifact injection {artifact_id} appears {count} times"
                )
        if errors:
            return shader_source, injected, errors
        expanded = shader_source
        for artifact_id, count in sorted(matches.items()):
            if count != 1:
                continue
            pattern = re.compile(
                rf"(?m)^// @shaderbench-inject "
                rf"id={re.escape(artifact_id)}[ \t]*(?:\n|$)"
            )
            expanded = pattern.sub(
                lambda _: self.locked_artifacts[artifact_id]["source"],
                expanded,
                count=1,
            )
            injected.append(artifact_id)
        return expanded, injected, errors

    @staticmethod
    def _selector_rubric(study_index: int) -> str:
        common = (
            "Judge visible fidelity to the reference, not implementation "
            "convenience. Do not reward a candidate for being easier to attach, "
            "cleaner to clip, more complex, more regular, or more complete if "
            "those traits weaken the target. Penalize generic ovals, glued-on "
            "parts, arbitrary repeated batches, and geometric regularity that "
            "erases character. Prefer distinctive curvature, meaningful "
            "negative space, coherent overlap, specific proportions, and an "
            "organic relationship between soft and hard edges."
        )
        stage = {
            1: (
                "This is the signature macro-form study. Rank silhouette, pose, "
                "major mass proportions, carved negative spaces, hooked/bent/"
                "twisted form language, and continuity of the root anatomy. "
                "Ignore readiness for later decoration and do not reward extra "
                "appendages merely because they are present."
            ),
            2: (
                "This is the parent-attached subsystem study. Preserve the "
                "strong macro form while ranking whether the new shell, branch, "
                "layer, appendage, or major secondary structure grows from the "
                "parent geometry, follows its frame and curvature, and creates "
                "the reference's overlap and boundary relationships."
            ),
            3: (
                "This is the surface treatment and art-direction study. Preserve "
                "the selected hierarchy while ranking whether local units, "
                "material, color, and lighting conform to the real parent "
                "surface; vary coherently; overlap at useful scale; and retain "
                "the reference's emotional focal hierarchy without becoming a "
                "flat grid, texture stamp, finger field, or armor sheet."
            ),
        }.get(
            study_index,
            (
                "Rank the candidates by reference fidelity and by whether the "
                "new subsystem belongs to the already selected hierarchy."
            ),
        )
        return common + " " + stage

    def _build_selector_sheet(
        self,
        study_index: int,
        candidates: list[dict[str, Any]],
    ) -> tuple[Path, dict[str, dict[str, Any]]]:
        """Build a deterministically shuffled, opaque candidate contact sheet."""
        ordered = sorted(
            candidates,
            key=lambda item: hashlib.sha256(
                (
                    f"shaderbench-v8-selector:{study_index}:"
                    f"{item['render_call']}:{item['variant']}"
                ).encode("utf-8")
            ).hexdigest(),
        )
        candidate_map: dict[str, dict[str, Any]] = {}
        cell_width = 360
        image_height = 520
        label_height = 40
        columns = 3
        rows = math.ceil(len(ordered) / columns)
        sheet = PILImage.new(
            "RGB",
            (cell_width * columns, (image_height + label_height) * rows),
            (13, 17, 23),
        )
        draw = ImageDraw.Draw(sheet)
        for index, candidate in enumerate(ordered):
            candidate_id = f"candidate_{index + 1:02d}"
            candidate_map[candidate_id] = {
                key: str(value) if isinstance(value, Path) else value
                for key, value in candidate.items()
            }
            crop = _crop_atlas_cell(
                Path(candidate["atlas_path"]),
                str(candidate["variant"]),
            )
            crop.thumbnail((cell_width - 8, image_height - 8))
            column = index % columns
            row = index // columns
            x = column * cell_width + (cell_width - crop.width) // 2
            y0 = row * (image_height + label_height)
            y = y0 + label_height + (image_height - crop.height) // 2
            sheet.paste(crop, (x, y))
            draw.text(
                (column * cell_width + 12, y0 + 10),
                candidate_id,
                fill=(235, 240, 248),
            )
        sheet_path = (
            self.workspace
            / "selectors"
            / f"study_{study_index:02d}_candidates.png"
        )
        sheet.save(sheet_path)
        return sheet_path, candidate_map

    def _run_selector_cli(
        self,
        study_index: int,
        sheet_path: Path,
        candidate_ids: list[str],
    ) -> dict[str, Any]:
        """Run a fresh, read-only visual selector with no generator context."""
        assert self.reference_image is not None
        with tempfile.TemporaryDirectory(
            prefix=f"shader_selector_{study_index:02d}_"
        ) as temporary:
            selector_workspace = Path(temporary)
            reference = selector_workspace / "reference.png"
            sheet = selector_workspace / "candidates.png"
            last_message = selector_workspace / "last_message.txt"
            shutil.copy2(self.reference_image, reference)
            shutil.copy2(sheet_path, sheet)
            prompt = f"""\
You are an isolated visual selector for a procedural reconstruction benchmark.
The first attached image is the reference. The second is a blinded contact sheet
whose labels are opaque candidate IDs. Rank every candidate exactly once.

SELECTION RUBRIC
{self._selector_rubric(study_index)}

Return ONLY this JSON schema:
{{
  "ranking": {json.dumps(candidate_ids)},
  "winner": "{candidate_ids[0]}",
  "evidence": "specific visible comparison against the reference",
  "runner_up_tradeoff": "specific reason the runner-up loses"
}}

Replace the example ordering and winner with your actual judgment. The ranking
must contain each supplied ID exactly once. Do not infer pass order, code,
future composability, or treatment names; you do not have that information.
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
                str(selector_workspace),
                "--json",
                "--output-last-message",
                str(last_message),
                "--model",
                self.selector_model,
                "--image",
                str(reference),
                "--image",
                str(sheet),
            ]
            if self.selector_effort:
                command.extend(
                    [
                        "--config",
                        "reasoning_effort="
                        + json.dumps(self.selector_effort),
                    ]
                )
            command.append("-")
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
            completed = subprocess.run(
                command,
                input=prompt,
                capture_output=True,
                text=True,
                timeout=240,
                env=environment,
                cwd=selector_workspace,
            )
            selector_log = (
                self.workspace
                / "selectors"
                / f"study_{study_index:02d}_selector.jsonl"
            )
            _atomic_write(selector_log, completed.stdout or "")
            _atomic_write(
                self.workspace
                / "selectors"
                / f"study_{study_index:02d}_selector.stderr.txt",
                completed.stderr or "",
            )
            if completed.returncode != 0 or not last_message.exists():
                raise RuntimeError(
                    "isolated selector failed: "
                    + (completed.stderr or completed.stdout or "no response")[
                        -2_000:
                    ]
                )
            return _parse_selector_output(
                last_message.read_text(encoding="utf-8")
            )

    def rank_study(
        self,
        study_index: int,
    ) -> tuple[dict[str, Any], Path | None]:
        """Blindly rank every qualified cell without generator self-selection."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }, None
        if not 1 <= study_index <= self.required_studies:
            return {
                "ok": False,
                "error": (
                    "study_index must identify one of the required studies "
                    f"(1-{self.required_studies})."
                ),
            }, None
        if study_index in self.study_records:
            return {
                "ok": False,
                "error": "This study is already recorded and immutable.",
            }, None
        if study_index in self.study_rankings:
            existing = self.study_rankings[study_index]
            return {"ok": True, **existing, "cached": True}, Path(
                existing["candidate_sheet"]
            )
        candidates = self.qualified_study_candidates.get(study_index, [])
        successful_passes = self.successful_study_render_count.get(
            study_index, 0
        )
        if (
            successful_passes < self.min_successful_study_renders
            or not candidates
        ):
            return {
                "ok": False,
                "error": (
                    "Complete every required qualified study pass before "
                    "requesting independent selection."
                ),
                "successful_study_renders": successful_passes,
                "min_successful_study_renders": (
                    self.min_successful_study_renders
                ),
            }, None
        sheet_path, candidate_map = self._build_selector_sheet(
            study_index, candidates
        )
        candidate_ids = list(candidate_map)
        try:
            raw_result = (
                self.selector_runner(
                    study_index=study_index,
                    reference_path=self.reference_image,
                    candidate_sheet_path=sheet_path,
                    candidate_ids=candidate_ids,
                    rubric=self._selector_rubric(study_index),
                )
                if self.selector_runner is not None
                else self._run_selector_cli(
                    study_index,
                    sheet_path,
                    candidate_ids,
                )
            )
            parsed = (
                _parse_selector_output(raw_result)
                if isinstance(raw_result, str)
                else raw_result
            )
            if not isinstance(parsed, dict):
                raise ValueError("selector result must be an object")
            ranking = parsed.get("ranking")
            winner = parsed.get("winner")
            if (
                not isinstance(ranking, list)
                or len(ranking) != len(candidate_ids)
                or len(set(ranking)) != len(candidate_ids)
                or set(ranking) != set(candidate_ids)
            ):
                raise ValueError(
                    "selector ranking must contain every opaque candidate "
                    "exactly once"
                )
            if winner != ranking[0] or winner not in candidate_map:
                raise ValueError(
                    "selector winner must be the first ranked candidate"
                )
            evidence = str(parsed.get("evidence", "")).strip()
            if len(evidence) < 40:
                raise ValueError(
                    "selector evidence must contain at least 40 characters"
                )
        except Exception as error:
            result = {
                "ok": False,
                "error": f"independent selector failed closed: {error}",
                "candidate_sheet": str(sheet_path),
            }
            self._event("rank_study_failed", **result)
            return result, sheet_path
        winner_origin = candidate_map[str(winner)]
        record = {
            "study_index": study_index,
            "selector_model": self.selector_model,
            "selector_effort": self.selector_effort,
            "rubric": self._selector_rubric(study_index),
            "rubric_sha256": hashlib.sha256(
                self._selector_rubric(study_index).encode("utf-8")
            ).hexdigest(),
            "candidate_sheet": str(sheet_path),
            "candidate_map": candidate_map,
            "ranking": ranking,
            "winner": winner,
            "winner_origin": winner_origin,
            "evidence": evidence,
            "runner_up_tradeoff": str(
                parsed.get("runner_up_tradeoff", "")
            ).strip()[:2_000],
        }
        self.study_rankings[study_index] = record
        result = {"ok": True, **record, "cached": False}
        self._event("rank_study", **result)
        return result, sheet_path

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
        shader_source, injected_artifacts, injection_errors = (
            self._expand_locked_artifact_injections(shader_source)
        )
        if injection_errors:
            return {
                "ok": False,
                "error": "Artifact injection placeholders are invalid.",
                "artifact_injection_errors": injection_errors,
            }
        encoded = shader_source.encode("utf-8")
        if not shader_source.strip():
            return {"ok": False, "error": "shader_source cannot be empty"}
        if len(encoded) > MAX_SHADER_BYTES:
            return {
                "ok": False,
                "error": f"shader exceeds the {MAX_SHADER_BYTES}-byte limit",
            }
        locked_errors = self._locked_artifact_errors(shader_source)
        if locked_errors:
            return {
                "ok": False,
                "error": (
                    "The rewrite would lose, alter, or stop calling a selected "
                    "executable study artifact."
                ),
                "artifact_lineage_errors": locked_errors,
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
            "injected_artifacts": injected_artifacts,
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
        if stage not in {"study", "promotion", "final"}:
            result = {
                "ok": False,
                "error": (
                    "stage must be 'study', 'promotion', or 'final'."
                ),
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
            if self.require_artifact_blocks and study_index in self.study_records:
                result = {
                    "ok": False,
                    "error": (
                        "This study already has an immutable selected artifact; "
                        "later same-study renders cannot erase or supersede it."
                    ),
                }
                self._event("render_rejected", **result)
                return result, None
            missing_prior = [
                index
                for index in range(1, study_index)
                if index
                not in (
                    self.promotion_records
                    if self.require_study_promotions
                    else self.study_records
                )
            ]
            if missing_prior:
                result = {
                    "ok": False,
                    "error": (
                        (
                            "Promote each earlier study before rendering this "
                            "one, so later studies operate on the exact selected "
                            "implementation."
                        )
                        if self.require_study_promotions
                        else (
                            "Record each earlier study before rendering this "
                            "one, so later studies can reuse the selected "
                            "construction."
                        )
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
        elif stage == "promotion":
            if not 1 <= study_index <= self.required_studies:
                result = {
                    "ok": False,
                    "error": (
                        "promotion study_index must identify one of the "
                        f"required studies (1-{self.required_studies})."
                    ),
                }
                self._event("render_rejected", **result)
                return result, None
            if study_index not in self.study_records:
                result = {
                    "ok": False,
                    "error": (
                        "Record the independently selected study artifact "
                        "before rendering its full-frame promotion."
                    ),
                }
                self._event("render_rejected", **result)
                return result, None
            if study_index in self.promotion_records:
                result = {
                    "ok": False,
                    "error": "This study promotion is already immutable.",
                }
                self._event("render_rejected", **result)
                return result, None
            missing_prior = [
                index
                for index in range(1, study_index)
                if index not in self.promotion_records
            ]
            if missing_prior:
                result = {
                    "ok": False,
                    "error": (
                        "Promote every earlier selected artifact before this "
                        "full-frame promotion."
                    ),
                    "missing_prior_promotions": missing_prior,
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
        if (
            stage == "final"
            and self.require_study_promotions
            and len(self.promotion_records) < self.required_studies
        ):
            result = {
                "ok": False,
                "error": (
                    "Promote every exact selected artifact in full-frame "
                    "context before rendering the final reconstruction."
                ),
                "completed_promotions": sorted(self.promotion_records),
                "required_studies": self.required_studies,
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
        shader_source = self.shader_path.read_text(encoding="utf-8")
        if stage == "study" and self.require_artifact_blocks:
            artifact_errors = _artifact_manifest_errors(
                shader_source,
                study_index,
            )
            if artifact_errors:
                result = {
                    "ok": False,
                    "error": (
                        "Every A-F cell must expose a unique, called, exact "
                        "artifact block before this study render."
                    ),
                    "artifact_manifest_errors": artifact_errors,
                    "render_budget_consumed": False,
                }
                self._event("render_rejected", **result)
                return result, None
        lineage_errors = self._locked_artifact_errors(shader_source)
        if lineage_errors:
            result = {
                "ok": False,
                "error": (
                    "The current shader fails executable artifact lineage "
                    "validation."
                ),
                "artifact_lineage_errors": lineage_errors,
                "render_budget_consumed": False,
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
            if self.current_hash is not None:
                self.successful_render_hash_by_revision[
                    self.revision
                ] = self.current_hash
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
                    self.qualified_study_candidates.setdefault(
                        study_index, []
                    ).extend(
                        {
                            "revision": self.revision,
                            "render_call": call_number,
                            "study_pass": study_pass,
                            "variant": variant,
                            "atlas_path": output_path,
                            "source_path": shader_snapshot,
                            "variation_manifest": (
                                variation_manifest.strip()[:4_000]
                            ),
                        }
                        for variant in VARIANTS
                    )
                    if not self.require_artifact_blocks:
                        self.study_records.pop(study_index, None)
            elif stage == "promotion":
                study_pass = 0
                study_diversity = None
                cross_render_diversity = None
                study_pass_qualified = True
                self.latest_successful_promotion_render[study_index] = {
                    "revision": self.revision,
                    "render_call": call_number,
                }
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
        selected_render_call: int = 0,
    ) -> dict[str, Any]:
        """Record and materialize one exact selected atlas implementation."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        if self.require_artifact_blocks and study_index in self.study_records:
            return {
                "ok": False,
                "error": "This study selection is already immutable.",
            }
        latest_rendered = self.latest_successful_study_render.get(study_index)
        if latest_rendered is None:
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
        ranking = self.study_rankings.get(study_index)
        if self.require_study_selector and ranking is None:
            return {
                "ok": False,
                "error": (
                    "Call rank_study and accept its blinded winner before "
                    "recording this study."
                ),
            }
        variant = selected_variant.strip().upper()
        if not variant and ranking is not None:
            variant = str(ranking["winner_origin"]["variant"])
        if variant not in set(VARIANTS):
            return {
                "ok": False,
                "error": "selected_variant must be one of A, B, C, D, E, or F.",
            }
        if ranking is not None and self.require_study_selector:
            winner_origin = ranking["winner_origin"]
            expected_variant = str(winner_origin["variant"])
            expected_call = int(winner_origin["render_call"])
            if variant != expected_variant or (
                selected_render_call not in {0, expected_call}
            ):
                return {
                    "ok": False,
                    "error": (
                        "The generator cannot override the enforced blinded "
                        "selector winner."
                    ),
                    "selector_variant": expected_variant,
                    "selector_render_call": expected_call,
                }
            selected_render_call = expected_call
        elif selected_render_call == 0:
            selected_render_call = int(latest_rendered["render_call"])
        selected_candidates = [
            candidate
            for candidate in self.qualified_study_candidates.get(
                study_index, []
            )
            if int(candidate["render_call"]) == selected_render_call
            and str(candidate["variant"]) == variant
        ]
        if not selected_candidates:
            if self.require_artifact_blocks:
                return {
                    "ok": False,
                    "error": (
                        "The selected render/cell is not a qualified immutable "
                        "study candidate."
                    ),
                }
            selected_candidate = {
                **latest_rendered,
                "variant": variant,
                "atlas_path": self.successful_render_by_revision.get(
                    int(latest_rendered["revision"]),
                    self.workspace / "renders" / "unavailable.png",
                ),
                "source_path": (
                    self.workspace
                    / "renders"
                    / f"revision_{int(latest_rendered['revision']):02d}.wgsl"
                ),
                "variation_manifest": "",
            }
        else:
            selected_candidate = selected_candidates[0]
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
        if (
            not self.require_study_selector
            and len(selection_rationale.strip()) < 80
        ):
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
        artifact_metadata: dict[str, Any] = {}
        if self.require_artifact_blocks:
            source_path = Path(selected_candidate["source_path"])
            atlas_path = Path(selected_candidate["atlas_path"])
            source = source_path.read_text(encoding="utf-8")
            artifact_id = f"study_{study_index}_{variant}"
            try:
                block = _extract_artifact_blocks(source).get(artifact_id)
            except ValueError as error:
                return {"ok": False, "error": str(error)}
            if block is None:
                return {
                    "ok": False,
                    "error": (
                        f"Selected candidate has no exact {artifact_id} block."
                    ),
                }
            artifact_dir = self.workspace / "artifacts" / artifact_id
            artifact_dir.mkdir(parents=True, exist_ok=True)
            artifact_source_path = artifact_dir / "artifact.wgsl"
            artifact_crop_path = artifact_dir / "selected.png"
            artifact_atlas_path = artifact_dir / "atlas.png"
            artifact_origin_path = artifact_dir / "atlas.wgsl"
            _atomic_write(artifact_source_path, block["source"])
            _crop_atlas_cell(atlas_path, variant).save(artifact_crop_path)
            shutil.copy2(atlas_path, artifact_atlas_path)
            shutil.copy2(source_path, artifact_origin_path)
            artifact_metadata = {
                "artifact_id": artifact_id,
                "study_index": study_index,
                "variant": variant,
                "entry_symbol": block["entry_symbol"],
                "sha256": block["sha256"],
                "origin_revision": int(selected_candidate["revision"]),
                "origin_render_call": selected_render_call,
                "artifact_source_path": str(artifact_source_path),
                "artifact_crop_path": str(artifact_crop_path),
                "artifact_atlas_path": str(artifact_atlas_path),
                "artifact_origin_shader_path": str(artifact_origin_path),
                "status": "selected_pending_promotion",
            }
            self.locked_artifacts[artifact_id] = {
                **artifact_metadata,
                "source": block["source"],
            }
            _atomic_write(
                artifact_dir / "manifest.json",
                json.dumps(artifact_metadata, indent=2),
            )
        rendered = {
            "revision": int(selected_candidate["revision"]),
            "render_call": selected_render_call,
            "study_pass": int(selected_candidate.get("study_pass", 0)),
        }
        record = {
            "study_index": study_index,
            "subject": subject.strip()[:300],
            "selected_variant": variant,
            "variant_inventory": variant_inventory.strip()[:4_000],
            "selection_rationale": (
                str(ranking["evidence"])
                if ranking is not None and self.require_study_selector
                else selection_rationale.strip()
            )[:4_000],
            "generator_self_assessment": selection_rationale.strip()[:4_000],
            "handoff_requirements": handoff_requirements.strip()[:4_000],
            "selected_by": (
                "isolated_blinded_selector"
                if ranking is not None and self.require_study_selector
                else "generator"
            ),
            "selector_winner": (
                ranking["winner"] if ranking is not None else None
            ),
            **artifact_metadata,
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

    def promote_study(
        self,
        study_index: int,
        integration_evidence: str,
    ) -> dict[str, Any]:
        """Freeze evidence that the exact selected artifact works full-frame."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        record = self.study_records.get(study_index)
        rendered = self.latest_successful_promotion_render.get(study_index)
        if record is None or rendered is None:
            return {
                "ok": False,
                "error": (
                    "Record the selected artifact, write it into a full-frame "
                    "scene, and render stage='promotion' before promotion."
                ),
            }
        if study_index in self.promotion_records:
            return {
                "ok": False,
                "error": "This study promotion is already immutable.",
            }
        if len(integration_evidence.strip()) < 80:
            return {
                "ok": False,
                "error": (
                    "integration_evidence must contain at least 80 characters "
                    "comparing the promoted full-frame result with the target "
                    "and prior champion."
                ),
            }
        artifact_id = str(record.get("artifact_id", ""))
        if not artifact_id or artifact_id not in self.locked_artifacts:
            return {
                "ok": False,
                "error": "No exact selected artifact is available to promote.",
            }
        artifact_dir = self.workspace / "artifacts" / artifact_id
        promotion_shader = artifact_dir / "promotion.wgsl"
        promotion_render = artifact_dir / "promotion.png"
        revision = int(rendered["revision"])
        render_call = int(rendered["render_call"])
        shutil.copy2(
            self.workspace / "renders" / f"revision_{revision:02d}.wgsl",
            promotion_shader,
        )
        shutil.copy2(
            self.workspace / "renders" / f"render_{render_call:02d}.png",
            promotion_render,
        )
        promoted_status = "promoted_locked"
        promotion = {
            "study_index": study_index,
            "artifact_id": artifact_id,
            "revision": revision,
            "render_call": render_call,
            "promotion_shader": str(promotion_shader),
            "promotion_render": str(promotion_render),
            "integration_evidence": integration_evidence.strip()[:4_000],
            "status": promoted_status,
        }
        self.promotion_records[study_index] = promotion
        record["status"] = promoted_status
        self.locked_artifacts[artifact_id]["status"] = promoted_status
        manifest_path = artifact_dir / "manifest.json"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        manifest.update(promotion)
        manifest["status"] = promoted_status
        _atomic_write(manifest_path, json.dumps(manifest, indent=2))
        result = {
            "ok": True,
            **promotion,
            "completed_promotions": sorted(self.promotion_records),
            "required_studies": self.required_studies,
        }
        self._event("promote_study", **result)
        return result

    def restore_revision(
        self,
        revision: int,
        reason: str,
    ) -> dict[str, Any]:
        """Create a new head from an immutable historical source revision."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        if len(reason.strip()) < 40:
            return {
                "ok": False,
                "error": "restore reason must contain at least 40 characters",
            }
        source_path = (
            self.workspace / "renders" / f"revision_{revision:02d}.wgsl"
        )
        if not source_path.is_file():
            return {"ok": False, "error": "unknown historical revision"}
        source = source_path.read_text(encoding="utf-8")
        lineage_errors = self._locked_artifact_errors(source)
        if lineage_errors:
            return {
                "ok": False,
                "error": (
                    "That historical revision predates or violates the current "
                    "immutable artifact lineage."
                ),
                "artifact_lineage_errors": lineage_errors,
            }
        self.revision += 1
        encoded = source.encode("utf-8")
        self.current_hash = hashlib.sha256(encoded).hexdigest()
        _atomic_write(self.shader_path, source)
        new_revision_path = (
            self.workspace / "renders" / f"revision_{self.revision:02d}.wgsl"
        )
        shutil.copy2(self.shader_path, new_revision_path)
        result = {
            "ok": True,
            "revision": self.revision,
            "restored_from": revision,
            "sha256": self.current_hash,
            "reason": reason.strip()[:4_000],
            "prior_render_image": (
                str(self.successful_render_by_revision[revision])
                if revision in self.successful_render_by_revision
                else None
            ),
            "remaining_renders": self.render_budget - self.render_calls,
        }
        self._event("restore_revision", **result)
        return result

    def submit_final(
        self,
        summary: str = "",
        revision: int = 0,
    ) -> dict[str, Any]:
        """Freeze any successful final revision, not necessarily the newest."""
        if self.submitted:
            return {
                "ok": False,
                "error": "The final shader has already been submitted.",
            }
        submitted_revision = revision or self.revision
        rendered_path = self.successful_render_by_revision.get(
            submitted_revision
        )
        if rendered_path is None:
            result = {
                "ok": False,
                "error": (
                    "The requested shader revision has not rendered "
                    "successfully."
                ),
                "revision": submitted_revision,
                "remaining_renders": self.render_budget - self.render_calls,
            }
            self._event("submit_rejected", **result)
            return result
        if (
            self.successful_render_stage_by_revision.get(submitted_revision)
            != "final"
        ):
            result = {
                "ok": False,
                "error": (
                    "The requested revision is not a final "
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
        successful_final_hashes = {
            self.successful_render_hash_by_revision.get(candidate_revision)
            for candidate_revision, stage
            in self.successful_render_stage_by_revision.items()
            if stage == "final"
        }
        successful_final_hashes.discard(None)
        successful_final_revisions = len(successful_final_hashes)
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
        submitted_source = (
            self.workspace
            / "renders"
            / f"revision_{submitted_revision:02d}.wgsl"
        )
        shutil.copy2(submitted_source, final_shader)
        shutil.copy2(rendered_path, final_render)
        self.submitted = True
        submitted_hash = self.successful_render_hash_by_revision.get(
            submitted_revision
        )
        result = {
            "ok": True,
            "revision": submitted_revision,
            "head_revision": self.revision,
            "sha256": submitted_hash,
            "render_call": next(
                (
                    event["render_call"]
                    for event in reversed(self.events)
                    if event.get("type") == "render_shader"
                    and event.get("revision") == submitted_revision
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
        require_artifact_blocks=(
            os.environ.get("SHADER_AGENT_REQUIRE_ARTIFACT_BLOCKS", "0") == "1"
        ),
        require_study_selector=(
            os.environ.get("SHADER_AGENT_REQUIRE_STUDY_SELECTOR", "0") == "1"
        ),
        require_study_promotions=(
            os.environ.get("SHADER_AGENT_REQUIRE_STUDY_PROMOTIONS", "0") == "1"
        ),
        reference_image=(
            Path(os.environ["SHADER_AGENT_REFERENCE_IMAGE"])
            if os.environ.get("SHADER_AGENT_REFERENCE_IMAGE")
            else None
        ),
        selector_model=os.environ.get(
            "SHADER_AGENT_SELECTOR_MODEL", "gpt-5.5"
        ),
        selector_effort=os.environ.get(
            "SHADER_AGENT_SELECTOR_EFFORT", "high"
        ),
        resume_existing=(
            os.environ.get("SHADER_AGENT_RESUME_EXISTING", "0") == "1"
        ),
    )


def create_mcp(state: ShaderAgentState) -> FastMCP:
    """Bind the fixed workspace state to the bounded MCP surface."""
    server = FastMCP(
        "shader-render-tools",
        instructions=(
            "Work only through the bounded shader tools. "
            "Every render consumes one unit of the fixed budget, including "
            "compile failures. Inspect each returned image before revising. "
            "When required, variation_manifest must predeclare materially "
            "different A-F constructions before a study render. "
            "Three-pass wide-search studies require family=, construction=, "
            "and structural_difference= for every A-F entry. "
            "When study_pass_qualified is false, the atlas was too visually "
            "similar internally or recycled a prior pass/topic, so it must be "
            "revised despite compiling. "
            "When artifact lineage is enabled, call rank_study after all "
            "qualified passes, record its enforced winner, render that exact "
            "artifact full-frame with stage='promotion', and call "
            "promote_study before the next study. Marker blocks are immutable "
            "and must remain byte-identical and called. A single top-level "
            "'// @shaderbench-inject id=study_N_X' placeholder lets "
            "write_shader inject exact locked source. "
            "submit_final may select an earlier successful final revision when "
            "the newest one regresses."
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

    @server.tool(structured_output=False)
    def rank_study(study_index: int) -> CallToolResult:
        """Blindly rank all qualified A-F cells with an isolated selector."""
        result, sheet_path = state.rank_study(study_index)
        content: list[Any] = [
            TextContent(type="text", text=json.dumps(result, indent=2))
        ]
        if sheet_path is not None:
            content.append(Image(path=sheet_path).to_image_content())
        return CallToolResult(content=content, isError=False)

    @server.tool()
    def record_study(
        study_index: int,
        subject: str,
        selected_variant: str,
        selection_rationale: str,
        handoff_requirements: str,
        variant_inventory: str = "",
        selected_render_call: int = 0,
    ) -> str:
        """Materialize the selected cell and exact executable artifact."""
        return json.dumps(
            state.record_study(
                study_index,
                subject,
                selected_variant,
                selection_rationale,
                handoff_requirements,
                variant_inventory,
                selected_render_call,
            ),
            indent=2,
        )

    @server.tool()
    def promote_study(study_index: int, integration_evidence: str) -> str:
        """Freeze a selected artifact after its full-frame promotion render."""
        return json.dumps(
            state.promote_study(study_index, integration_evidence),
            indent=2,
        )

    @server.tool()
    def restore_revision(revision: int, reason: str) -> str:
        """Branch the current head from exact historical shader source."""
        return json.dumps(
            state.restore_revision(revision, reason),
            indent=2,
        )

    @server.tool()
    def submit_final(summary: str = "", revision: int = 0) -> str:
        """Submit any exact successfully rendered final revision."""
        return json.dumps(state.submit_final(summary, revision), indent=2)

    return server


if __name__ == "__main__":
    create_mcp(_state_from_environment()).run(transport="stdio")
