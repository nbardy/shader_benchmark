#!/usr/bin/env python3
"""Write `category.txt` to each problem dir in problems/base_set/.

Categories come from the prose listing in problems/readme.md, plus a
hand-curated alias map for problems whose dir was renamed since the
readme was last updated, plus a `reproduce_image*` → "Image Reproduction"
rule for the photographic-baseline problems we added recently.

Idempotent. Re-run any time the readme or aliases change.
"""

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
README = REPO / "problems" / "readme.md"
BASE_SET = REPO / "problems" / "base_set"

# Disk dir name → canonical readme entry (when they differ).
# Hand-curated. If a problem was renamed and no longer matches the readme,
# add it here.
ALIASES: dict[str, str] = {
    "regular_dodecahedron": "dodecahedron",
    "regular_icosahedron": "icosahedron",
    "mobius_strip_half_twist": "mobius_strip",
    "mobius_strip_triple_twist": "mobius_strip_3_twists",
    "menger_sponge_fractal": "menger_sponge",
    "menger_cube_fractal": "menger_sponge",  # close enough — same category
    "differential_equations_water": "differential_equation_water",
    "fourier_architectural_blueprint": "fourier_architectural_blueprints",
    "helical_twisted_cube_advanced": "helical_twisted_cube",
    "octagram_star_polygon": "eight_pointed_star",
    "lorenz_attractor_poincare": "lorenz_attractor",
    "trefoil_alexander_polynomial": "alexander_polynomial_viz",
    "sierpinski_triangle_6_iterations": "sierpinski_triangle",
    "stella_octangula": "compound_polyhedra_stella_octangula",
    "fractal_tree_2d": "fractal_tree_3d",
    "hopf_fibration_base_loops": "hopf_fibration",
    "poincare_disc": "hyperbolic_geometry_poincare_disk",
    "hyper_menger_cube_3sphere": "menger_sponge",  # advanced variant
    # Disk-only additions with no readme entry — categorized by best guess:
    "chinese_remainder_theorem": "chinese_remainder_sunzi",  # same topic
    "euler_polyhedron_platonic": "euler_polyhedron_formula",  # same topic
    "fourier_epicycles_drawing": "fourier_architectural_blueprints",
    "glass_sphere_red_core": "schwarzschild_black_hole",  # rendering-heavy
    "lissajous_curve_garden": "rose_curves",  # parametric curve
    "parametric_seashell": "rose_curves",
    "sierpinski_tetrahedron": "sierpinski_triangle",
    "superformula_explorer": "rose_curves",
}

# Category for the reproduce_image_* family — a new category not in the
# readme. Generic "reproduce_image" (singular) goes here too.
IMAGE_REPRO_CATEGORY = "Image Reproduction"


def parse_readme_categories() -> dict[str, str]:
    """Walk the readme and return {problem_name: category}.

    Uses the `### Category Name (N problems)` headers as section
    delimiters and `- \`name\`` bullets within each section.
    """
    txt = README.read_text(encoding="utf-8")
    categories: dict[str, str] = {}
    current_category: str | None = None
    header_pat = re.compile(r"^### ([^(]+?)(?:\s*\(\d+\s+problems?\))?\s*$")
    bullet_pat = re.compile(r"^- `([^`]+)`")
    for raw in txt.splitlines():
        line = raw.rstrip()
        h = header_pat.match(line)
        if h:
            name = h.group(1).strip()
            # Skip non-problem-list sections at the bottom of the readme.
            # NB: substring matches like "format" in "Deformations" mis-fired
            # earlier — use exact-string list instead.
            skip_titles = {
                "critic file format",
                "common techniques required",
                "wgsl constraints",
                "single problem test",
                "category-focused evaluation",
            }
            current_category = None if name.lower() in skip_titles else name
            continue
        b = bullet_pat.match(line)
        if b and current_category:
            categories[b.group(1).strip()] = current_category
    return categories


def main() -> int:
    if not BASE_SET.is_dir():
        print(f"problem dir not found: {BASE_SET}", file=sys.stderr)
        return 1

    readme_map = parse_readme_categories()
    print(f"parsed {len(readme_map)} problem→category mappings from readme")

    matched = 0
    by_alias = 0
    by_pattern = 0
    uncategorized: list[str] = []

    for prob_dir in sorted(BASE_SET.iterdir()):
        if not prob_dir.is_dir():
            continue
        name = prob_dir.name

        category: str | None = None

        # 1. Direct match
        if name in readme_map:
            category = readme_map[name]
            matched += 1
        # 2. Alias (renamed dir)
        elif name in ALIASES and ALIASES[name] in readme_map:
            category = readme_map[ALIASES[name]]
            by_alias += 1
        # 3. Pattern: image-reproduction problems
        elif name == "reproduce_image" or name.startswith("reproduce_image_"):
            category = IMAGE_REPRO_CATEGORY
            by_pattern += 1

        target = prob_dir / "category.txt"
        if category:
            target.write_text(category + "\n", encoding="utf-8")
        else:
            uncategorized.append(name)
            # Don't write a placeholder; user can decide.

    print(f"  direct match:        {matched}")
    print(f"  matched via alias:   {by_alias}")
    print(f"  matched via pattern: {by_pattern}")
    print(f"  uncategorized:       {len(uncategorized)}")
    if uncategorized:
        print("\nuncategorized problems (no category.txt written):")
        for n in uncategorized:
            print(f"  - {n}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
