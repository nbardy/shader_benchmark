#!/usr/bin/env python3
"""
Benchmark Harness - Tier 2
Runs multiple problems for a single LLM model and generates comprehensive report
"""

import argparse
import asyncio
import sys
from pathlib import Path
from datetime import datetime
from typing import List, Dict
import subprocess
import json

class BenchmarkHarness:
    def __init__(self, model: str, problems: List[str]):
        self.model = model
        self.problems = problems
        self.results = []
        self.start_time = None
        self.end_time = None
        
    async def run_single_problem(self, problem: str) -> Dict:
        """Run main.py for a single problem and return results"""
        print(f"🧪 Testing {problem}...")
        
        problem_path = f"../problems/base_set/{problem}"
        if not Path(problem_path).exists():
            print(f"❌ Problem not found: {problem}")
            return {
                'problem': problem,
                'success': False,
                'error': 'Problem directory not found',
                'scores': [0, 0, 0, 0, 0],
                'image_path': None,
                'execution_time': 0
            }
        
        start_time = datetime.now()
        
        # Run main.py for this problem (skip individual reports)
        cmd = [
            sys.executable, "main.py",
            "--model", self.model,
            "--prompt-folder", problem_path,
            "--no-report"
        ]
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            end_time = datetime.now()
            execution_time = (end_time - start_time).total_seconds()
            
            if result.returncode == 0:
                # Find the most recent test result directory
                test_dirs = list(Path(".").glob("test_*_results"))
                if test_dirs:
                    latest_dir = max(test_dirs, key=lambda p: p.stat().st_mtime)
                    
                    # Load results
                    results_json = latest_dir / "results.json"
                    image_path = latest_dir / "result.png"
                    
                    scores = [0, 0, 0, 0, 0]
                    if results_json.exists():
                        with open(results_json, 'r') as f:
                            data = json.load(f)
                            scores = data.get('scores', [0, 0, 0, 0, 0])
                    
                    print(f"✅ {problem} - SUCCESS (Total: {sum(scores)}/500)")
                    return {
                        'problem': problem,
                        'success': True,
                        'scores': scores,
                        'image_path': image_path if image_path.exists() else None,
                        'test_dir': latest_dir,
                        'execution_time': execution_time
                    }
                else:
                    print(f"❌ {problem} - No test results found")
                    return {
                        'problem': problem,
                        'success': False,
                        'error': 'No test results directory found',
                        'scores': [0, 0, 0, 0, 0],
                        'image_path': None,
                        'execution_time': execution_time
                    }
            else:
                print(f"❌ {problem} - FAILED")
                return {
                    'problem': problem,
                    'success': False,
                    'error': result.stderr[:500] if result.stderr else 'Unknown error',
                    'scores': [0, 0, 0, 0, 0],
                    'image_path': None,
                    'execution_time': execution_time
                }
                
        except subprocess.TimeoutExpired:
            print(f"⏰ {problem} - TIMEOUT (5 minutes)")
            return {
                'problem': problem,
                'success': False,
                'error': 'Execution timeout (5 minutes)',
                'scores': [0, 0, 0, 0, 0],
                'image_path': None,
                'execution_time': 300
            }
        except Exception as e:
            print(f"💥 {problem} - EXCEPTION: {e}")
            return {
                'problem': problem,
                'success': False,
                'error': str(e),
                'scores': [0, 0, 0, 0, 0],
                'image_path': None,
                'execution_time': 0
            }
    
    def generate_report(self) -> str:
        """Generate report using unified generate_report.py system"""
        # Get test directories from THIS harness run only
        test_dirs_from_this_run = []
        for result in self.results:
            if result.get('test_dir'):
                test_dirs_from_this_run.append(str(result['test_dir']))
        
        if not test_dirs_from_this_run:
            print("❌ No test directories found from this harness run")
            return None
            
        # Create isolated harness report directory
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        model_safe = self.model.replace('/', '_').replace(':', '_')
        harness_dir = f"harness_{model_safe}_{timestamp}"
        Path(harness_dir).mkdir(exist_ok=True)
        
        output_file = f"harness_report_{model_safe}_{timestamp}.md"
        
        # Use custom generate_report that only scans our specific test directories
        from generate_report import ReportGenerator
        generator = ReportGenerator(self.model)
        
        # Add only test directories from THIS harness run
        for test_dir in test_dirs_from_this_run:
            generator.add_test_result(test_dir)
            
        # Generate report in harness directory
        report_path = generator.generate_report(output_file, harness_dir)
        return report_path
    
    async def run_benchmark(self) -> str:
        """Run all problems and generate report"""
        print(f"🎯 Benchmark Harness - Testing {self.model}")
        print(f"📝 Problems: {self.problems}")
        print(f"📊 Total tests: {len(self.problems)}")
        print("=" * 60)
        
        self.start_time = datetime.now()
        
        # Run all problems
        for problem in self.problems:
            result = await self.run_single_problem(problem)
            self.results.append(result)
            
            # Brief pause between tests
            await asyncio.sleep(1)
        
        self.end_time = datetime.now()
        
        # Generate report
        report_path = self.generate_report()
        
        # Print summary
        successful = sum(1 for r in self.results if r['success'])
        total_time = (self.end_time - self.start_time).total_seconds()
        
        print("\n" + "=" * 60)
        print(f"🏁 Benchmark complete for {self.model}")
        print(f"✅ Success rate: {successful}/{len(self.problems)} ({successful/len(self.problems)*100:.1f}%)")
        print(f"⏱️  Total time: {total_time:.1f} seconds")
        print(f"📊 Report: {report_path}")
        
        return report_path

def main():
    parser = argparse.ArgumentParser(description='Shader Benchmark Harness - Tier 2')
    parser.add_argument('--model', required=True, help='LLM model to test')
    parser.add_argument('--problems', nargs='+', required=True, 
                       help='List of problems to test (from problems/base_set/)')
    
    args = parser.parse_args()
    
    harness = BenchmarkHarness(args.model, args.problems)
    report_path = asyncio.run(harness.run_benchmark())
    
    print(f"\n📋 Benchmark report: {report_path}")

if __name__ == "__main__":
    main()