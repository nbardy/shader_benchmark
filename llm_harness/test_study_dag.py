"""Contract tests for the bounded adaptive study DAG."""

from __future__ import annotations

import copy
import unittest

from study_dag import AdaptiveStudyDAG, StudyDAGError, StudyNode


def node(
    node_id: str,
    *,
    depends_on: list[str] | None = None,
    mode: str = "refine",
) -> dict[str, object]:
    return {
        "node_id": node_id,
        "title": f"Study {node_id}",
        "decision_question": f"Which construction resolves {node_id}?",
        "depends_on": depends_on or [],
        "success_criteria": [f"{node_id} visibly matches the reference"],
        "failure_signals": [f"{node_id} remains generic or disconnected"],
        "mode": mode,
    }


def graph(**overrides: object) -> AdaptiveStudyDAG:
    options: dict[str, object] = {
        "max_nodes": 8,
        "max_depth": 4,
        "render_budget": 30,
        "final_render_reserve": 2,
    }
    options.update(overrides)
    return AdaptiveStudyDAG(**options)  # type: ignore[arg-type]


def finish_node(dag: AdaptiveStudyDAG, node_id: str) -> None:
    dag.begin_node(node_id)
    required = dag.snapshot(node_id).required_passes
    for _ in range(required):
        dag.record_pass(node_id, success=True)
    dag.select_node(node_id)
    dag.promote_node(node_id)


class StudyNodeSchemaTests(unittest.TestCase):
    def test_schema_is_strict_and_round_trips(self) -> None:
        original = node("wing_surface", mode="diverge")
        parsed = StudyNode.from_dict(original)
        self.assertEqual(parsed.to_dict(), original)
        for mutation in (
            {**original, "extra": True},
            {key: value for key, value in original.items() if key != "title"},
            {**original, "mode": "search"},
            {**original, "success_criteria": []},
            {**original, "depends_on": ("other",)},
            {**original, "node_id": "bad id"},
        ):
            with self.subTest(mutation=mutation), self.assertRaises(StudyDAGError):
                StudyNode.from_dict(mutation)

    def test_constructor_rejects_incomplete_pass_policy(self) -> None:
        for policy in ({"diverge": 2, "refine": 1}, {}):
            with self.subTest(policy=policy), self.assertRaisesRegex(
                StudyDAGError, "exactly"
            ):
                graph(required_passes=policy)


class StudyDAGStructureTests(unittest.TestCase):
    def test_minimum_initial_graph_size_is_enforced_and_serialized(self) -> None:
        dag = graph(min_initial_nodes=2)
        before = dag.to_dict()
        with self.assertRaisesRegex(StudyDAGError, "at least 2"):
            dag.define_nodes([node("only")])
        self.assertEqual(dag.to_dict(), before)
        dag.define_nodes([node("one"), node("two")])
        restored = AdaptiveStudyDAG.from_dict(dag.to_dict())
        self.assertEqual(restored.min_initial_nodes, 2)
        tampered = dag.to_dict()
        tampered["nodes"] = tampered["nodes"][:1]
        with self.assertRaisesRegex(StudyDAGError, "min_initial_nodes"):
            AdaptiveStudyDAG.from_dict(tampered)

    def test_stable_indexes_and_append_only_expansion(self) -> None:
        dag = graph()
        assigned = dag.define_nodes([node("shape"), node("color")])
        self.assertEqual(assigned, {"shape": 1, "color": 2})
        expanded = dag.expand_nodes(
            [node("join", depends_on=["shape", "color"], mode="integrate")]
        )
        self.assertEqual(expanded, {"join": 3})
        self.assertEqual(dag.study_index("shape"), 1)
        self.assertEqual(dag.node_id_for_index(3), "join")
        before = dag.to_dict()
        with self.assertRaisesRegex(StudyDAGError, "replace"):
            dag.expand_nodes([node("shape")])
        self.assertEqual(dag.to_dict(), before)

    def test_cycle_rejection_is_atomic_and_does_not_consume_indexes(self) -> None:
        dag = graph()
        dag.define_nodes([node("root")])
        before = dag.to_dict()
        with self.assertRaisesRegex(StudyDAGError, "cycle"):
            dag.expand_nodes(
                [
                    node("a", depends_on=["b"]),
                    node("b", depends_on=["a"]),
                ]
            )
        self.assertEqual(dag.to_dict(), before)
        self.assertEqual(dag.expand_nodes([node("valid", depends_on=["root"])]), {"valid": 2})

    def test_unknown_dependency_depth_and_node_count_are_atomic(self) -> None:
        dag = graph(max_nodes=3, max_depth=1)
        dag.define_nodes([node("root")])
        for additions, message in (
            ([node("unknown", depends_on=["missing"])], "unknown"),
            (
                [
                    node("middle", depends_on=["root"]),
                    node("deep", depends_on=["middle"]),
                ],
                "depth",
            ),
            ([node("a"), node("b"), node("c")], "max_nodes"),
        ):
            before = dag.to_dict()
            with self.subTest(message=message), self.assertRaisesRegex(StudyDAGError, message):
                dag.expand_nodes(additions)
            self.assertEqual(dag.to_dict(), before)


class StudyDAGExecutionTests(unittest.TestCase):
    def test_frontier_dependencies_and_per_mode_passes(self) -> None:
        dag = graph()
        dag.define_nodes(
            [
                node("silhouette", mode="diverge"),
                node("palette", mode="refine"),
                node(
                    "composition",
                    depends_on=["silhouette", "palette"],
                    mode="integrate",
                ),
            ]
        )
        self.assertEqual(dag.frontier_node_ids(), ("silhouette", "palette"))
        dag.begin_node("silhouette")
        self.assertEqual(dag.snapshot("silhouette").required_passes, 2)
        self.assertEqual(
            dag.record_pass("silhouette", success=True).status, "active"
        )
        self.assertEqual(
            dag.record_pass("silhouette", success=True).status, "studied"
        )
        dag.select_node("silhouette")
        dag.promote_node("silhouette")
        self.assertNotIn("composition", dag.frontier_node_ids())
        finish_node(dag, "palette")
        self.assertEqual(dag.frontier_node_ids(), ("composition",))

    def test_invalid_transition_rejection_is_atomic(self) -> None:
        dag = graph()
        dag.define_nodes([node("root")])
        before = dag.to_dict()
        with self.assertRaises(StudyDAGError):
            dag.select_node("root")
        self.assertEqual(dag.to_dict(), before)
        dag.begin_node("root")
        before = dag.to_dict()
        with self.assertRaises(StudyDAGError):
            dag.promote_node("root")
        self.assertEqual(dag.to_dict(), before)

    def test_absolute_render_totals_and_failed_attempts(self) -> None:
        dag = graph(render_budget=10, final_render_reserve=2)
        dag.define_nodes([node("root", mode="refine")])
        dag.begin_node("root")
        dag.record_pass("root", success=False, render_calls_used=2)
        self.assertEqual(dag.render_calls_used, 2)
        self.assertEqual(dag.snapshot("root").successful_passes, 0)
        dag.record_pass("root", success=True, render_calls_used=3)
        dag.select_node("root")
        dag.promote_node("root", render_calls_used=4)
        self.assertEqual(dag.render_calls_used, 4)
        dag.sync_render_calls(4)
        self.assertEqual(dag.render_calls_used, 4)

    def test_budget_reserve_rejects_infeasible_define(self) -> None:
        dag = graph(render_budget=5, final_render_reserve=2)
        before = dag.to_dict()
        with self.assertRaisesRegex(StudyDAGError, "budget-feasible"):
            dag.define_nodes([node("wide", mode="diverge"), node("other")])
        self.assertEqual(dag.to_dict(), before)

        dag.define_nodes([node("wide", mode="diverge")])
        self.assertEqual(dag.budget_slack, 0)
        dag.begin_node("wide")
        dag.record_pass("wide", success=False)
        self.assertEqual(dag.render_calls_used, 1)
        self.assertEqual(dag.budget_slack, -1)
        self.assertTrue(dag.budget_blocked)
        before = dag.to_dict()
        with self.assertRaisesRegex(StudyDAGError, "budget-feasible"):
            dag.expand_nodes([node("late", depends_on=["wide"])])
        self.assertEqual(dag.to_dict(), before)

    def test_already_spent_render_can_advance_successful_transitions(self) -> None:
        dag = graph(render_budget=6, final_render_reserve=2)
        dag.define_nodes([node("root", mode="refine")])
        dag.begin_node("root")
        dag.sync_render_calls(1)
        dag.record_pass("root", success=True, render_calls_used=1)
        dag.select_node("root")
        dag.sync_render_calls(2)
        dag.promote_node("root", render_calls_used=2)
        self.assertEqual(dag.snapshot("root").status, "promoted")
        self.assertEqual(dag.render_calls_used, 2)

    def test_expansion_budget_failure_preserves_existing_graph(self) -> None:
        dag = graph(render_budget=7, final_render_reserve=2)
        dag.define_nodes([node("root")])
        before = dag.to_dict()
        with self.assertRaisesRegex(StudyDAGError, "budget-feasible"):
            dag.expand_nodes(
                [node("a", depends_on=["root"]), node("b", depends_on=["root"])]
            )
        self.assertEqual(dag.to_dict(), before)


class StudyDAGClosureAndSerializationTests(unittest.TestCase):
    def test_exact_budget_final_successes_discharge_reserve(self) -> None:
        dag = graph(render_budget=4, final_render_reserve=2)
        dag.define_nodes([node("final", mode="refine")])
        finish_node(dag, "final")
        dag.close_graph()
        self.assertEqual(dag.budget_slack, 0)
        self.assertEqual(dag.record_final(success=True), 1)
        self.assertEqual(dag.remaining_final_reserve, 1)
        self.assertEqual(dag.record_final(success=True), 2)
        self.assertEqual(dag.remaining_final_reserve, 0)
        self.assertEqual(dag.render_calls_used, 4)

    def test_failed_final_consumes_budget_without_discarding_reserve(self) -> None:
        dag = graph(render_budget=5, final_render_reserve=2)
        dag.define_nodes([node("final", mode="refine")])
        finish_node(dag, "final")
        dag.close_graph()
        self.assertEqual(dag.budget_slack, 1)
        self.assertEqual(dag.record_final(success=False), 0)
        self.assertEqual(dag.render_calls_used, 3)
        self.assertEqual(dag.remaining_final_reserve, 2)
        dag.record_final(success=True)
        dag.record_final(success=True)
        self.assertEqual(dag.render_calls_used, 5)

    def test_failed_final_at_zero_slack_persists_blocked_checkpoint(self) -> None:
        dag = graph(render_budget=4, final_render_reserve=2)
        dag.define_nodes([node("final", mode="refine")])
        finish_node(dag, "final")
        dag.close_graph()
        self.assertEqual(dag.budget_slack, 0)
        dag.record_final(success=False)
        self.assertEqual(dag.render_calls_used, 3)
        self.assertEqual(dag.remaining_final_reserve, 2)
        self.assertTrue(dag.budget_blocked)
        restored = AdaptiveStudyDAG.from_json(dag.to_json())
        self.assertTrue(restored.budget_blocked)
        self.assertEqual(restored.render_calls_used, 3)

    def test_close_requires_unique_promoted_sink(self) -> None:
        dag = graph()
        dag.define_nodes([node("a"), node("b")])
        finish_node(dag, "a")
        finish_node(dag, "b")
        with self.assertRaisesRegex(StudyDAGError, "exactly one"):
            dag.close_graph()

        joined = graph()
        joined.define_nodes(
            [node("a"), node("final", depends_on=["a"], mode="integrate")]
        )
        finish_node(joined, "a")
        with self.assertRaisesRegex(StudyDAGError, "promoted"):
            joined.close_graph()
        finish_node(joined, "final")
        self.assertEqual(joined.close_graph(), "final")
        self.assertTrue(joined.graph_closed)
        with self.assertRaisesRegex(StudyDAGError, "closed"):
            joined.expand_nodes([node("late", depends_on=["final"])])

    def test_json_round_trip_rehydrates_frontier_and_indexes(self) -> None:
        dag = graph()
        dag.define_nodes(
            [node("root"), node("child", depends_on=["root"], mode="integrate")]
        )
        finish_node(dag, "root")
        restored = AdaptiveStudyDAG.from_json(dag.to_json(indent=2))
        self.assertEqual(restored.to_dict(), dag.to_dict())
        self.assertEqual(restored.frontier_node_ids(), ("child",))
        self.assertEqual(restored.study_index("child"), 2)

    def test_closed_graph_round_trip(self) -> None:
        dag = graph()
        dag.define_nodes([node("final", mode="integrate")])
        finish_node(dag, "final")
        dag.close_graph()
        restored = AdaptiveStudyDAG.from_dict(dag.to_dict())
        self.assertTrue(restored.graph_closed)
        self.assertEqual(restored.final_node_id, "final")

    def test_tampered_serialization_is_rejected(self) -> None:
        dag = graph()
        dag.define_nodes([node("root")])
        payload = dag.to_dict()
        mutations = []
        unknown = copy.deepcopy(payload)
        unknown["surprise"] = True
        mutations.append(unknown)
        bad_index = copy.deepcopy(payload)
        bad_index["nodes"][0]["study_index"] = 2  # type: ignore[index]
        mutations.append(bad_index)
        impossible_status = copy.deepcopy(payload)
        impossible_status["nodes"][0]["status"] = "promoted"  # type: ignore[index]
        mutations.append(impossible_status)
        over_budget = copy.deepcopy(payload)
        over_budget["render_calls_used"] = 99
        mutations.append(over_budget)
        for mutation in mutations:
            with self.subTest(mutation=mutation), self.assertRaises(StudyDAGError):
                AdaptiveStudyDAG.from_dict(mutation)


if __name__ == "__main__":
    unittest.main()
