#!/usr/bin/env python3
"""Launch the benchmark with ambitious true-3D prompting."""

import sys

from benchmark_harness import main as benchmark_main
from prompt_profiles import AMBITIOUS_3D_PROFILE


def main(argv=None):
    forwarded = list(sys.argv[1:] if argv is None else argv)
    if "--prompt-profile" in forwarded:
        raise SystemExit(
            "ambitious_3d_shader_harness.py fixes --prompt-profile to "
            f"{AMBITIOUS_3D_PROFILE!r}; remove the override."
        )
    benchmark_main(["--prompt-profile", AMBITIOUS_3D_PROFILE, *forwarded])


if __name__ == "__main__":
    main()
