#!/usr/bin/env python3
"""Launch the benchmark with scratchpad + art-direction prompting."""

import sys

from benchmark_harness import main as benchmark_main
from prompt_profiles import SCRATCHPAD_ART_DIRECTION_PROFILE


def main(argv=None):
    forwarded = list(sys.argv[1:] if argv is None else argv)
    if "--prompt-profile" in forwarded:
        raise SystemExit(
            "chatgpt_shader_harness.py fixes --prompt-profile to "
            f"{SCRATCHPAD_ART_DIRECTION_PROFILE!r}; remove the override."
        )
    benchmark_main(
        ["--prompt-profile", SCRATCHPAD_ART_DIRECTION_PROFILE, *forwarded]
    )


if __name__ == "__main__":
    main()
