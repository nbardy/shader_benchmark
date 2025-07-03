#!/usr/bin/env python3
"""
Retroactively judge existing test results that have images but no scores.
"""

import asyncio
import glob
import json
from pathlib import Path
from judge import Judge
from prompt_loader import PromptLoader

async def judge_existing_results():
    """Judge all existing test results that have images but no scores."""
    
    # Load judge prompt (using problem_1 as default)
    prompt_loader = PromptLoader()
    judge_prompt = prompt_loader.load_judge_prompt("../tests/problem_1")
    
    # Find all test result directories
    test_dirs = glob.glob("test_*_results")
    judge = Judge()
    
    judged_count = 0
    
    for test_dir in test_dirs:
        test_path = Path(test_dir)
        result_image = test_path / "result.png"
        results_file = test_path / "results.json"
        
        # Skip if no image or already has results
        if not result_image.exists():
            print(f"Skipping {test_dir}: No result.png")
            continue
            
        if results_file.exists():
            try:
                with open(results_file, 'r') as f:
                    data = json.load(f)
                    if data.get('scores') and not all(score == 0 for score in data['scores']):
                        print(f"Skipping {test_dir}: Already has scores")
                        continue
            except:
                pass
        
        print(f"Judging {test_dir}...")
        
        try:
            # Judge the result
            scores = await judge.evaluate(judge_prompt, result_image)
            
            # Save results
            results = {
                "scores": scores,
                "test_folder": str(test_path),
                "status": "completed",
                "execution_success": True,
                "has_image": True
            }
            
            with open(results_file, 'w') as f:
                json.dump(results, f, indent=2)
                
            print(f"✅ Judged {test_dir}: {scores}")
            judged_count += 1
            
        except Exception as e:
            print(f"❌ Error judging {test_dir}: {e}")
    
    print(f"\nCompleted! Judged {judged_count} test results.")

if __name__ == "__main__":
    asyncio.run(judge_existing_results())