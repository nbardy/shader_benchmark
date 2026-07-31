"""Bounded, append-only planning state for adaptive shader studies.

The graph stores *study tasks*, not individual A-F candidates.  Candidate
rejection remains local to a study; every node admitted to this graph must
eventually be promoted and feed the single final integration node.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any, Mapping


MODES = ("diverge", "refine", "integrate")
STATUSES = ("pending", "active", "studied", "selected", "promoted")
DEFAULT_REQUIRED_PASSES = {
    "diverge": 2,
    "refine": 1,
    "integrate": 1,
}
SERIALIZATION_VERSION = 1

_NODE_ID = re.compile(r"^[A-Za-z][A-Za-z0-9_-]{0,63}$")
_NODE_KEYS = {
    "node_id",
    "title",
    "decision_question",
    "depends_on",
    "success_criteria",
    "failure_signals",
    "mode",
}


class StudyDAGError(ValueError):
    """Raised when a graph mutation or serialized state violates the contract."""


def _is_int(value: object) -> bool:
    return isinstance(value, int) and not isinstance(value, bool)


def _exact_keys(
    value: object, expected: set[str], context: str
) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise StudyDAGError(f"{context} must be an object")
    keys = set(value)
    if keys != expected:
        missing = sorted(expected - keys)
        unknown = sorted(keys - expected)
        raise StudyDAGError(
            f"{context} has invalid keys; missing={missing}, unknown={unknown}"
        )
    return value


def _strict_text(value: object, field: str) -> str:
    if not isinstance(value, str) or not value or value != value.strip():
        raise StudyDAGError(f"{field} must be a non-empty trimmed string")
    if "\x00" in value:
        raise StudyDAGError(f"{field} may not contain NUL")
    return value


def _strict_text_list(
    value: object, field: str, *, allow_empty: bool
) -> tuple[str, ...]:
    if not isinstance(value, list):
        raise StudyDAGError(f"{field} must be a JSON array")
    if not allow_empty and not value:
        raise StudyDAGError(f"{field} may not be empty")
    items = tuple(_strict_text(item, f"{field}[]") for item in value)
    if len(set(items)) != len(items):
        raise StudyDAGError(f"{field} may not contain duplicates")
    return items


@dataclass(frozen=True)
class StudyNode:
    """The strict, model-authored portion of one study task."""

    node_id: str
    title: str
    decision_question: str
    depends_on: tuple[str, ...]
    success_criteria: tuple[str, ...]
    failure_signals: tuple[str, ...]
    mode: str

    @classmethod
    def from_dict(cls, payload: object) -> "StudyNode":
        data = _exact_keys(payload, _NODE_KEYS, "study node")
        node_id = _strict_text(data["node_id"], "node_id")
        if not _NODE_ID.fullmatch(node_id):
            raise StudyDAGError(
                "node_id must start with a letter and contain only letters, "
                "digits, underscores, or hyphens (maximum 64 characters)"
            )
        mode = _strict_text(data["mode"], "mode")
        if mode not in MODES:
            raise StudyDAGError(f"mode must be one of {MODES}")
        depends_on = _strict_text_list(
            data["depends_on"], "depends_on", allow_empty=True
        )
        if node_id in depends_on:
            raise StudyDAGError("a node may not depend on itself")
        return cls(
            node_id=node_id,
            title=_strict_text(data["title"], "title"),
            decision_question=_strict_text(
                data["decision_question"], "decision_question"
            ),
            depends_on=depends_on,
            success_criteria=_strict_text_list(
                data["success_criteria"],
                "success_criteria",
                allow_empty=False,
            ),
            failure_signals=_strict_text_list(
                data["failure_signals"], "failure_signals", allow_empty=False
            ),
            mode=mode,
        )

    def to_dict(self) -> dict[str, object]:
        return {
            "node_id": self.node_id,
            "title": self.title,
            "decision_question": self.decision_question,
            "depends_on": list(self.depends_on),
            "success_criteria": list(self.success_criteria),
            "failure_signals": list(self.failure_signals),
            "mode": self.mode,
        }


@dataclass(frozen=True)
class StudyNodeSnapshot:
    """Read-only server state paired with a strict study node."""

    node: StudyNode
    study_index: int
    status: str
    successful_passes: int
    required_passes: int


@dataclass
class _Progress:
    study_index: int
    status: str = "pending"
    successful_passes: int = 0


class AdaptiveStudyDAG:
    """A bounded study DAG with transactional append and lifecycle updates."""

    def __init__(
        self,
        *,
        max_nodes: int,
        max_depth: int,
        render_budget: int,
        final_render_reserve: int,
        min_initial_nodes: int = 1,
        required_passes: Mapping[str, int] | None = None,
    ) -> None:
        for name, value in (
            ("max_nodes", max_nodes),
            ("max_depth", max_depth),
            ("render_budget", render_budget),
            ("final_render_reserve", final_render_reserve),
            ("min_initial_nodes", min_initial_nodes),
        ):
            if not _is_int(value):
                raise StudyDAGError(f"{name} must be an integer")
        if max_nodes < 1:
            raise StudyDAGError("max_nodes must be at least 1")
        if max_depth < 0:
            raise StudyDAGError("max_depth must be at least 0")
        if render_budget < 1:
            raise StudyDAGError("render_budget must be at least 1")
        if not 1 <= final_render_reserve <= render_budget:
            raise StudyDAGError(
                "final_render_reserve must be between 1 and render_budget"
            )
        if not 1 <= min_initial_nodes <= max_nodes:
            raise StudyDAGError(
                "min_initial_nodes must be between 1 and max_nodes"
            )

        passes = dict(
            DEFAULT_REQUIRED_PASSES
            if required_passes is None
            else required_passes
        )
        if set(passes) != set(MODES):
            raise StudyDAGError(
                f"required_passes must define exactly {sorted(MODES)}"
            )
        if any(not _is_int(value) or value < 1 for value in passes.values()):
            raise StudyDAGError("every required pass count must be a positive integer")

        self.max_nodes = max_nodes
        self.max_depth = max_depth
        self.render_budget = render_budget
        self.final_render_reserve = final_render_reserve
        self.min_initial_nodes = min_initial_nodes
        self.required_passes = {mode: passes[mode] for mode in MODES}
        self._nodes: dict[str, StudyNode] = {}
        self._progress: dict[str, _Progress] = {}
        self._render_calls_used = 0
        self._successful_final_renders = 0
        self._closed = False
        self._final_node_id: str | None = None

    @property
    def node_count(self) -> int:
        return len(self._nodes)

    @property
    def node_ids(self) -> tuple[str, ...]:
        return tuple(self._nodes)

    @property
    def graph_closed(self) -> bool:
        return self._closed

    @property
    def final_node_id(self) -> str | None:
        return self._final_node_id

    @property
    def render_calls_used(self) -> int:
        return self._render_calls_used

    @property
    def successful_final_renders(self) -> int:
        return self._successful_final_renders

    @property
    def remaining_final_reserve(self) -> int:
        return max(
            0, self.final_render_reserve - self._successful_final_renders
        )

    @property
    def budget_remaining(self) -> int:
        return self.render_budget - self._render_calls_used

    @property
    def minimum_remaining_work(self) -> int:
        return self._minimum_work(self._nodes, self._progress)

    @property
    def budget_slack(self) -> int:
        return (
            self.render_budget
            - self._render_calls_used
            - self.minimum_remaining_work
            - self.remaining_final_reserve
        )

    @property
    def budget_blocked(self) -> bool:
        """Whether irreversible attempts left too little budget for the plan."""
        return self.budget_slack < 0

    def node(self, node_id: str) -> StudyNode:
        try:
            return self._nodes[node_id]
        except KeyError as exc:
            raise StudyDAGError(f"unknown node_id: {node_id}") from exc

    def study_index(self, node_id: str) -> int:
        self.node(node_id)
        return self._progress[node_id].study_index

    def node_id_for_index(self, study_index: int) -> str:
        if not _is_int(study_index):
            raise StudyDAGError("study_index must be an integer")
        for node_id, progress in self._progress.items():
            if progress.study_index == study_index:
                return node_id
        raise StudyDAGError(f"unknown study_index: {study_index}")

    def snapshot(self, node_id: str) -> StudyNodeSnapshot:
        node = self.node(node_id)
        progress = self._progress[node_id]
        return StudyNodeSnapshot(
            node=node,
            study_index=progress.study_index,
            status=progress.status,
            successful_passes=progress.successful_passes,
            required_passes=self.required_passes[node.mode],
        )

    def snapshots(self) -> tuple[StudyNodeSnapshot, ...]:
        return tuple(self.snapshot(node_id) for node_id in self._nodes)

    def is_ready(self, node_id: str) -> bool:
        node = self.node(node_id)
        return self._progress[node_id].status == "pending" and all(
            self._progress[dependency].status == "promoted"
            for dependency in node.depends_on
        )

    def frontier_node_ids(self) -> tuple[str, ...]:
        return tuple(node_id for node_id in self._nodes if self.is_ready(node_id))

    def define_nodes(self, payloads: object) -> dict[str, int]:
        """Atomically define the initial graph and assign stable study indexes."""
        if self._nodes:
            raise StudyDAGError("the initial graph is already defined")
        if not isinstance(payloads, list) or len(payloads) < self.min_initial_nodes:
            raise StudyDAGError(
                "initial graph must define at least "
                f"{self.min_initial_nodes} nodes"
            )
        return self._append(payloads, operation="define")

    def expand_nodes(self, payloads: object) -> dict[str, int]:
        """Atomically append nodes without changing any existing node or index."""
        if not self._nodes:
            raise StudyDAGError("define the initial graph before expanding it")
        return self._append(payloads, operation="expand")

    def _append(self, payloads: object, *, operation: str) -> dict[str, int]:
        if self._closed:
            raise StudyDAGError("a closed graph cannot be expanded")
        if not isinstance(payloads, list) or not payloads:
            raise StudyDAGError(f"{operation} payload must be a non-empty JSON array")
        parsed = [StudyNode.from_dict(payload) for payload in payloads]
        new_ids = [node.node_id for node in parsed]
        if len(set(new_ids)) != len(new_ids):
            raise StudyDAGError("the append batch contains duplicate node_ids")
        overlap = sorted(set(new_ids) & set(self._nodes))
        if overlap:
            raise StudyDAGError(
                f"append-only graph cannot replace existing nodes: {overlap}"
            )

        prospective_nodes = dict(self._nodes)
        prospective_progress = {
            node_id: _Progress(
                state.study_index, state.status, state.successful_passes
            )
            for node_id, state in self._progress.items()
        }
        first_index = len(prospective_nodes) + 1
        assignments: dict[str, int] = {}
        for offset, node in enumerate(parsed):
            index = first_index + offset
            prospective_nodes[node.node_id] = node
            prospective_progress[node.node_id] = _Progress(index)
            assignments[node.node_id] = index

        self._validate_graph(prospective_nodes)
        self._ensure_feasible(
            prospective_nodes, prospective_progress, self._render_calls_used
        )
        self._nodes = prospective_nodes
        self._progress = prospective_progress
        return assignments

    def begin_node(self, node_id: str) -> StudyNodeSnapshot:
        progress = self._progress_for(node_id)
        if not self.is_ready(node_id):
            raise StudyDAGError(
                "node must be pending with every dependency promoted before begin"
            )
        progress.status = "active"
        return self.snapshot(node_id)

    def record_pass(
        self,
        node_id: str,
        *,
        success: bool,
        render_calls_used: int | None = None,
    ) -> StudyNodeSnapshot:
        """Record one atlas attempt using an optional authoritative call total."""
        progress = self._progress_for(node_id)
        if progress.status != "active":
            raise StudyDAGError("study passes may only be recorded for an active node")
        if not isinstance(success, bool):
            raise StudyDAGError("success must be a boolean")
        new_used = self._next_render_total(render_calls_used)
        new_passes = progress.successful_passes + (1 if success else 0)
        required = self.required_passes[self._nodes[node_id].mode]
        if new_passes > required:
            raise StudyDAGError("node already has every required successful pass")
        new_status = "studied" if new_passes == required else "active"

        prospective = self._copy_progress()
        prospective[node_id].successful_passes = new_passes
        prospective[node_id].status = new_status
        self._ensure_history_covered(prospective, new_used)
        progress.successful_passes = new_passes
        progress.status = new_status
        self._render_calls_used = new_used
        return self.snapshot(node_id)

    def sync_render_calls(self, render_calls_used: int) -> None:
        """Monotonically import failed/non-node attempts from the render server."""
        new_used = self._validated_render_total(render_calls_used)
        self._render_calls_used = new_used

    def record_final(
        self,
        *,
        success: bool,
        render_calls_used: int | None = None,
    ) -> int:
        """Record a final attempt; only successes discharge the final reserve."""
        if not self._closed:
            raise StudyDAGError("final renders require a closed study graph")
        if not isinstance(success, bool):
            raise StudyDAGError("success must be a boolean")
        new_used = self._next_render_total(render_calls_used)
        new_successes = self._successful_final_renders + (1 if success else 0)
        self._ensure_history_covered(
            self._progress,
            new_used,
            successful_final_renders=new_successes,
        )
        self._render_calls_used = new_used
        self._successful_final_renders = new_successes
        return new_successes

    def select_node(self, node_id: str) -> StudyNodeSnapshot:
        progress = self._progress_for(node_id)
        if progress.status != "studied":
            raise StudyDAGError("only a fully studied node can be selected")
        progress.status = "selected"
        return self.snapshot(node_id)

    def promote_node(
        self, node_id: str, *, render_calls_used: int | None = None
    ) -> StudyNodeSnapshot:
        """Record the full-frame promotion render and freeze the selected node."""
        progress = self._progress_for(node_id)
        if progress.status != "selected":
            raise StudyDAGError("only a selected node can be promoted")
        node = self._nodes[node_id]
        if any(
            self._progress[dependency].status != "promoted"
            for dependency in node.depends_on
        ):
            raise StudyDAGError("every dependency must remain promoted")
        new_used = self._next_render_total(render_calls_used)
        prospective = self._copy_progress()
        prospective[node_id].status = "promoted"
        self._ensure_history_covered(prospective, new_used)
        progress.status = "promoted"
        self._render_calls_used = new_used
        return self.snapshot(node_id)

    def close_graph(self) -> str:
        """Close an all-promoted DAG with one sink reached by every node."""
        if self._closed:
            assert self._final_node_id is not None
            return self._final_node_id
        final_node_id = self._closure_candidate(require_promoted=True)
        self._closed = True
        self._final_node_id = final_node_id
        return final_node_id

    def _closure_candidate(self, *, require_promoted: bool) -> str:
        if not self._nodes:
            raise StudyDAGError("cannot close an empty graph")
        dependents = {node_id: set() for node_id in self._nodes}
        for node in self._nodes.values():
            for dependency in node.depends_on:
                dependents[dependency].add(node.node_id)
        sinks = [node_id for node_id, children in dependents.items() if not children]
        if len(sinks) != 1:
            raise StudyDAGError(
                f"graph must have exactly one final sink; found {sorted(sinks)}"
            )
        sink = sinks[0]
        ancestors = {sink}
        stack = [sink]
        while stack:
            current = stack.pop()
            for dependency in self._nodes[current].depends_on:
                if dependency not in ancestors:
                    ancestors.add(dependency)
                    stack.append(dependency)
        missing = sorted(set(self._nodes) - ancestors)
        if missing:
            raise StudyDAGError(
                f"every node must reach the final sink; disconnected={missing}"
            )
        if require_promoted:
            unpromoted = sorted(
                node_id
                for node_id, progress in self._progress.items()
                if progress.status != "promoted"
            )
            if unpromoted:
                raise StudyDAGError(
                    f"every node must be promoted before close; pending={unpromoted}"
                )
        return sink

    def to_dict(self) -> dict[str, object]:
        return {
            "version": SERIALIZATION_VERSION,
            "config": {
                "max_nodes": self.max_nodes,
                "max_depth": self.max_depth,
                "render_budget": self.render_budget,
                "final_render_reserve": self.final_render_reserve,
                "min_initial_nodes": self.min_initial_nodes,
                "required_passes": dict(self.required_passes),
            },
            "render_calls_used": self._render_calls_used,
            "successful_final_renders": self._successful_final_renders,
            "graph_closed": self._closed,
            "final_node_id": self._final_node_id,
            "nodes": [
                {
                    "study_index": self._progress[node_id].study_index,
                    "status": self._progress[node_id].status,
                    "successful_passes": self._progress[node_id].successful_passes,
                    "node": node.to_dict(),
                }
                for node_id, node in self._nodes.items()
            ],
        }

    def to_json(self, *, indent: int | None = None) -> str:
        return json.dumps(self.to_dict(), indent=indent, sort_keys=True)

    @classmethod
    def from_json(cls, raw: str) -> "AdaptiveStudyDAG":
        if not isinstance(raw, str):
            raise StudyDAGError("serialized graph must be a JSON string")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise StudyDAGError(f"invalid graph JSON: {exc}") from exc
        return cls.from_dict(payload)

    @classmethod
    def from_dict(cls, payload: object) -> "AdaptiveStudyDAG":
        top = _exact_keys(
            payload,
            {
                "version",
                "config",
                "render_calls_used",
                "successful_final_renders",
                "graph_closed",
                "final_node_id",
                "nodes",
            },
            "serialized graph",
        )
        if top["version"] != SERIALIZATION_VERSION:
            raise StudyDAGError("unsupported serialized graph version")
        config = _exact_keys(
            top["config"],
            {
                "max_nodes",
                "max_depth",
                "render_budget",
                "final_render_reserve",
                "min_initial_nodes",
                "required_passes",
            },
            "serialized config",
        )
        if not isinstance(config["required_passes"], Mapping):
            raise StudyDAGError("required_passes must be an object")
        graph = cls(
            max_nodes=config["max_nodes"],
            max_depth=config["max_depth"],
            render_budget=config["render_budget"],
            final_render_reserve=config["final_render_reserve"],
            min_initial_nodes=config["min_initial_nodes"],
            required_passes=config["required_passes"],
        )
        records = top["nodes"]
        if not isinstance(records, list):
            raise StudyDAGError("serialized nodes must be a JSON array")
        record_keys = {"study_index", "status", "successful_passes", "node"}
        nodes: dict[str, StudyNode] = {}
        progress: dict[str, _Progress] = {}
        for expected_index, raw_record in enumerate(records, start=1):
            record = _exact_keys(raw_record, record_keys, "serialized node state")
            if record["study_index"] != expected_index:
                raise StudyDAGError(
                    "study indexes must be stable, unique, and contiguous from 1"
                )
            node = StudyNode.from_dict(record["node"])
            if node.node_id in nodes:
                raise StudyDAGError("serialized graph contains duplicate node_ids")
            status = record["status"]
            passes = record["successful_passes"]
            if status not in STATUSES:
                raise StudyDAGError(f"invalid node status: {status}")
            if not _is_int(passes) or passes < 0:
                raise StudyDAGError("successful_passes must be a non-negative integer")
            required = graph.required_passes[node.mode]
            if status == "pending" and passes != 0:
                raise StudyDAGError("pending nodes cannot have successful passes")
            if status == "active" and passes >= required:
                raise StudyDAGError("active node pass count must be below its target")
            if status in {"studied", "selected", "promoted"} and passes != required:
                raise StudyDAGError(
                    f"{status} node must have exactly its required pass count"
                )
            nodes[node.node_id] = node
            progress[node.node_id] = _Progress(expected_index, status, passes)

        graph._validate_graph(nodes)
        if nodes and len(nodes) < graph.min_initial_nodes:
            raise StudyDAGError(
                "serialized graph has fewer nodes than min_initial_nodes"
            )
        for node_id, node in nodes.items():
            if progress[node_id].status != "pending" and any(
                progress[dependency].status != "promoted"
                for dependency in node.depends_on
            ):
                raise StudyDAGError(
                    f"started node {node_id} has an unpromoted dependency"
                )
        used = top["render_calls_used"]
        if not _is_int(used) or used < 0:
            raise StudyDAGError("render_calls_used must be a non-negative integer")
        if used > graph.render_budget:
            raise StudyDAGError("render_calls_used exceeds render_budget")
        minimum_already_spent = sum(
            state.successful_passes + (1 if state.status == "promoted" else 0)
            for state in progress.values()
        )
        if used < minimum_already_spent:
            raise StudyDAGError(
                "render_calls_used is below the successful pass/promotion history"
            )
        final_successes = top["successful_final_renders"]
        if not _is_int(final_successes) or final_successes < 0:
            raise StudyDAGError(
                "successful_final_renders must be a non-negative integer"
            )
        if used < minimum_already_spent + final_successes:
            raise StudyDAGError(
                "render_calls_used is below the successful study/final history"
            )
        # External attempts are irreversible.  Compile/diversity failures can
        # legitimately leave a checkpoint with negative slack, which must be
        # rehydrated rather than silently rolled back.
        closed = top["graph_closed"]
        if not isinstance(closed, bool):
            raise StudyDAGError("graph_closed must be a boolean")
        final_node_id = top["final_node_id"]
        if not closed and final_node_id is not None:
            raise StudyDAGError("an open graph cannot have final_node_id")
        if not closed and final_successes:
            raise StudyDAGError("an open graph cannot have successful final renders")

        graph._nodes = nodes
        graph._progress = progress
        graph._render_calls_used = used
        graph._successful_final_renders = final_successes
        graph._closed = closed
        graph._final_node_id = final_node_id
        if closed:
            if not isinstance(final_node_id, str):
                raise StudyDAGError("a closed graph requires final_node_id")
            actual = graph._closure_candidate(require_promoted=True)
            if final_node_id != actual:
                raise StudyDAGError("final_node_id does not match the unique sink")
        return graph

    def _progress_for(self, node_id: str) -> _Progress:
        self.node(node_id)
        if self._closed:
            raise StudyDAGError("a closed graph is immutable")
        return self._progress[node_id]

    def _copy_progress(self) -> dict[str, _Progress]:
        return {
            node_id: _Progress(
                state.study_index, state.status, state.successful_passes
            )
            for node_id, state in self._progress.items()
        }

    def _next_render_total(self, supplied: int | None) -> int:
        return self._validated_render_total(
            self._render_calls_used + 1 if supplied is None else supplied
        )

    def _validated_render_total(self, value: object) -> int:
        if not _is_int(value) or value < self._render_calls_used:
            raise StudyDAGError(
                "render_calls_used must be an integer at least as large as the "
                "prior authoritative total"
            )
        if value > self.render_budget:
            raise StudyDAGError("render_calls_used exceeds render_budget")
        return value

    @staticmethod
    def _minimum_spent(progress: Mapping[str, _Progress]) -> int:
        return sum(
            state.successful_passes + (1 if state.status == "promoted" else 0)
            for state in progress.values()
        )

    def _ensure_history_covered(
        self,
        progress: Mapping[str, _Progress],
        render_calls_used: int,
        *,
        successful_final_renders: int | None = None,
    ) -> None:
        final_successes = (
            self._successful_final_renders
            if successful_final_renders is None
            else successful_final_renders
        )
        if render_calls_used < self._minimum_spent(progress) + final_successes:
            raise StudyDAGError(
                "render_calls_used does not cover the successful pass, promotion, "
                "and final-render history"
            )

    def _minimum_work(
        self,
        nodes: Mapping[str, StudyNode],
        progress: Mapping[str, _Progress],
    ) -> int:
        remaining = 0
        for node_id, node in nodes.items():
            state = progress[node_id]
            required = self.required_passes[node.mode]
            if state.status in {"pending", "active"}:
                remaining += required - state.successful_passes + 1
            elif state.status in {"studied", "selected"}:
                remaining += 1
        return remaining

    def _ensure_feasible(
        self,
        nodes: Mapping[str, StudyNode],
        progress: Mapping[str, _Progress],
        render_calls_used: int,
        *,
        successful_final_renders: int | None = None,
    ) -> None:
        final_successes = (
            self._successful_final_renders
            if successful_final_renders is None
            else successful_final_renders
        )
        required = (
            render_calls_used
            + self._minimum_work(nodes, progress)
            + max(0, self.final_render_reserve - final_successes)
        )
        if required > self.render_budget:
            raise StudyDAGError(
                "graph is not budget-feasible: minimum required "
                f"{required} > render_budget {self.render_budget}"
            )

    def _validate_graph(self, nodes: Mapping[str, StudyNode]) -> None:
        if len(nodes) > self.max_nodes:
            raise StudyDAGError(
                f"graph has {len(nodes)} nodes but max_nodes is {self.max_nodes}"
            )
        known = set(nodes)
        for node in nodes.values():
            unknown = sorted(set(node.depends_on) - known)
            if unknown:
                raise StudyDAGError(
                    f"node {node.node_id} has unknown dependencies: {unknown}"
                )

        visiting: set[str] = set()
        visited: set[str] = set()
        depths: dict[str, int] = {}

        def visit(node_id: str) -> int:
            if node_id in visiting:
                raise StudyDAGError("study graph contains a dependency cycle")
            if node_id in visited:
                return depths[node_id]
            visiting.add(node_id)
            dependencies = nodes[node_id].depends_on
            depth = 0 if not dependencies else 1 + max(visit(dep) for dep in dependencies)
            visiting.remove(node_id)
            visited.add(node_id)
            depths[node_id] = depth
            return depth

        for node_id in nodes:
            depth = visit(node_id)
            if depth > self.max_depth:
                raise StudyDAGError(
                    f"node {node_id} depth {depth} exceeds max_depth {self.max_depth}"
                )


__all__ = [
    "AdaptiveStudyDAG",
    "DEFAULT_REQUIRED_PASSES",
    "MODES",
    "SERIALIZATION_VERSION",
    "STATUSES",
    "StudyDAGError",
    "StudyNode",
    "StudyNodeSnapshot",
]
