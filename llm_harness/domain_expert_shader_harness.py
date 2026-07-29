#!/usr/bin/env python3
"""Launch the benchmark with domain-expert shader prompting."""

import sys

from benchmark_harness import main as benchmark_main
from prompt_profiles import DOMAIN_EXPERT_PROFILE


def main(argv=None):
    forwarded = list(sys.argv[1:] if argv is None else argv)
    if "--prompt-profile" in forwarded:
        raise SystemExit(
            "domain_expert_shader_harness.py fixes --prompt-profile to "
            f"{DOMAIN_EXPERT_PROFILE!r}; remove the override."
        )
    benchmark_main(["--prompt-profile", DOMAIN_EXPERT_PROFILE, *forwarded])


if __name__ == "__main__":
    main()
