#!/usr/bin/env python3
"""
Test script to validate smart judge skipping on existing render images.
"""

import sys
from pathlib import Path
from judge import Judge

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_smart_skip.py <path_to_image.png>")
        sys.exit(1)

    image_path = Path(sys.argv[1])

    if not image_path.exists():
        print(f"Error: Image not found: {image_path}")
        sys.exit(1)

    print(f"Testing smart judge skipping on: {image_path}")
    print("="*70)

    judge = Judge()
    should_skip, failure_reason = judge.analyze_image_quality(image_path)

    if should_skip:
        print(f"✅ WOULD SKIP LLM JUDGE")
        print(f"   Reason: {failure_reason}")

        if failure_reason == "NO_IMAGE":
            print(f"   Score assigned: 0/500")
        elif failure_reason in ["ALL_BLACK", "ALL_WHITE"]:
            print(f"   Score assigned: 1/500")

        print(f"   💰 COST SAVED: ~$0.001-0.01 (1 LLM judge API call)")
    else:
        print(f"✅ IMAGE HAS CONTENT - Would proceed with LLM judge")
        print(f"   Reason: Image contains meaningful pixels")

    print("="*70)

if __name__ == "__main__":
    main()
