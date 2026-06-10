#!/usr/bin/env python3
"""Audit the raw frontier equation seed bank."""

from __future__ import annotations

import re
import sys
from pathlib import Path


EXPECTED = {
    "high_dimensional_topology_equations.md": "EQ-HDT",
    "nonarchimedean_arithmetic_equations.md": "EQ-NAA",
    "algebraic_moduli_equations.md": "EQ-ALG",
    "hyperbolic_teichmuller_group_equations.md": "EQ-HTG",
    "qft_gauge_instanton_equations.md": "EQ-QGI",
    "quantum_codes_fractons_equations.md": "EQ-QCF",
    "pde_singularity_dynamics_equations.md": "EQ-PSD",
    "matroid_polytope_combinatorics_equations.md": "EQ-MPC",
    "logic_automata_proof_equations.md": "EQ-LAP",
    "exceptional_lattice_calibration_equations.md": "EQ-ELC",
}


def audit_file(root: Path, filename: str, prefix: str) -> tuple[int, bool]:
    path = root / filename
    if not path.exists():
        print(f"{filename}: MISSING")
        return 0, False

    text = path.read_text(encoding="utf-8")
    ids: list[str] = []
    no_code_marker: list[int] = []
    pattern = re.compile(rf"^({re.escape(prefix)}-\d{{3}}):\s*(.*)$")

    for line_no, line in enumerate(text.splitlines(), 1):
        match = pattern.match(line)
        if not match:
            continue
        ids.append(match.group(1))
        if "`" not in match.group(2):
            no_code_marker.append(line_no)

    expected_ids = [f"{prefix}-{index:03d}" for index in range(1, 251)]
    ascii_ok = all(ord(char) < 128 for char in text)
    ok = ids == expected_ids and ascii_ok and not no_code_marker

    print(
        f"{filename}: "
        f"count={len(ids)} "
        f"first={ids[0] if ids else '-'} "
        f"last={ids[-1] if ids else '-'} "
        f"ascii={ascii_ok} "
        f"code_markers={not no_code_marker} "
        f"ok={ok}"
    )
    if no_code_marker:
        print(f"  entries without code markers on lines: {no_code_marker[:10]}")
    return len(ids), ok


def main() -> int:
    root = Path("problems/frontier_explore/equations")
    total = 0
    all_ok = True

    for filename, prefix in EXPECTED.items():
        count, ok = audit_file(root, filename, prefix)
        total += count
        all_ok = all_ok and ok

    print(f"total_equations={total}")
    if total != 2500:
        all_ok = False

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
