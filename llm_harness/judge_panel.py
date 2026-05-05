"""Multi-judge panel utilities.

A "judge panel" is a list of judge model strings (same shape as
`Judge(judge_model=...)` accepts: `<provider>/<model>` or `cli/<tool>...`).
Each (run, problem) gets scored independently by every member of the panel
and the published score is the mean across whichever judges have completed.

Storage:
  * Per-problem checkpoint: each judge writes its own stage named
    `judge:<safe_key>` so the existing `_is_stage_complete` machinery treats
    each judge as an independent unit of work. The original judge_model
    string is preserved inside `data.judge_model` to avoid sanitization
    round-trip ambiguity.
  * Per-problem results.json: gains `scores_by_judge: {judge_model: [s1..s5]}`;
    top-level `scores` is the mean across judges (kept so `build_docs.py`
    and any existing readers continue to work).

The `judge:` stage prefix is the contract — anything starting with `judge:`
is treated as a judge stage. Don't reuse that prefix for non-judge stages.
"""

from __future__ import annotations

from typing import Dict, Iterable, List, Optional

JUDGE_STAGE_PREFIX = "judge:"


def judge_safe_key(judge_model: str) -> str:
    """Filesystem/JSON-key safe form of a judge model string.

    Mirrors the `model.replace('/', '_').replace(':', '_')` pattern used for
    `run_id` so the encoding is consistent across the codebase. Keeps the
    encoding lossy-but-unique-per-string (the original judge_model is also
    persisted alongside the stage data).
    """
    return judge_model.replace('/', '_').replace(':', '_')


def judge_stage_name(judge_model: str) -> str:
    """Stage name used in `stages.<name>` for a given judge."""
    return f"{JUDGE_STAGE_PREFIX}{judge_safe_key(judge_model)}"


def is_judge_stage(stage_name: str) -> bool:
    return stage_name.startswith(JUDGE_STAGE_PREFIX)


def collect_judge_stages(stages: Dict[str, dict]) -> Dict[str, dict]:
    """Return the subset of `stages` that are judge stages, keyed by stage name."""
    return {k: v for k, v in stages.items() if is_judge_stage(k)}


def scores_by_judge_from_stages(stages: Dict[str, dict]) -> Dict[str, List[int]]:
    """Extract `{judge_model: [s1..s5]}` from completed judge stages.

    A judge stage contributes only when its status is "complete", it has 5
    scores, and at least one of them is > 0 (zero-everywhere is the legacy
    encoding for "judge skipped/failed" — counting it as 0 across the board
    would unfairly drag a panel mean down).
    """
    out: Dict[str, List[int]] = {}
    for stage_name, sdata in stages.items():
        if not is_judge_stage(stage_name):
            continue
        if sdata.get('status') != 'complete':
            continue
        data = sdata.get('data') or {}
        scores = data.get('scores')
        if not (isinstance(scores, list) and len(scores) == 5):
            continue
        if not any(isinstance(s, (int, float)) and s > 0 for s in scores):
            continue
        # Prefer the persisted judge_model string; fall back to the stage
        # name suffix for legacy stages that didn't record it.
        judge_model = data.get('judge_model') or stage_name[len(JUDGE_STAGE_PREFIX):]
        out[judge_model] = [int(s) for s in scores]
    return out


def mean_scores(scores_by_judge: Dict[str, List[int]]) -> Optional[List[int]]:
    """Element-wise mean of the per-judge score vectors. None when empty."""
    if not scores_by_judge:
        return None
    n = len(scores_by_judge)
    sums = [0, 0, 0, 0, 0]
    for vec in scores_by_judge.values():
        for i in range(5):
            sums[i] += vec[i]
    return [round(s / n) for s in sums]


def missing_judges(panel: Iterable[str], scores_by_judge: Dict[str, List[int]]) -> List[str]:
    """Members of `panel` that haven't scored yet."""
    have = set(scores_by_judge.keys())
    return [j for j in panel if j not in have]
