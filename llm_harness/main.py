#!/usr/bin/env python3
import argparse
import asyncio
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

from llm_client import LLMClient
from prompt_loader import PromptLoader
from shader_parser import ShaderParser
from test_runner import TestRunner
from judge import Judge
from language_specs import get_language_spec, SUPPORTED_LANGUAGES

async def main():
    parser = argparse.ArgumentParser(description='LLM Shader Harness - Language-Agnostic Pipeline')
    parser.add_argument('--model', required=True, help='OpenRouter model name')
    parser.add_argument('--prompt-folder', required=True, help='Path to prompt folder')
    parser.add_argument('--language-spec', default='wgsl',
                       choices=SUPPORTED_LANGUAGES,
                       help=f'Shader language specification (default: wgsl). Options: {", ".join(SUPPORTED_LANGUAGES)}')
    parser.add_argument('--judge-model', default='anthropic/claude-3.5-haiku',
                       help='Judge model for evaluation (default: anthropic/claude-3.5-haiku)')
    parser.add_argument('--no-report', action='store_true', help='Skip individual test report generation')
    parser.add_argument('--no-judge', action='store_true', help='Skip judge evaluation (for debugging)')

    args = parser.parse_args()

    # Get language specification
    language_spec = get_language_spec(args.language_spec)

    print(f"Running LLM Shader Harness with model: {args.model}")
    print(f"Using prompt folder: {args.prompt_folder}")
    print(f"Language specification: {language_spec.name} ({language_spec.description})")

    # Load prompts
    prompt_loader = PromptLoader()
    request_prompt = prompt_loader.load_request_prompt(args.prompt_folder)

    # Initialize LLM client with language specification
    llm_client = LLMClient(language_spec=language_spec)

    # Generate shaders
    print(f"Generating {language_spec.name} shaders with LLM...")
    llm_response = await llm_client.generate_shaders(args.model, request_prompt)

    # Parse shader files with language specification
    shader_parser = ShaderParser(language_spec=language_spec)
    shaders, main_rs = shader_parser.parse_response(llm_response)
    
    # Create test folder and run
    test_runner = TestRunner()
    test_folder = test_runner.create_test_folder()
    test_runner.setup_test_files(test_folder, shaders, main_rs)
    
    result_image = None
    scores = None
    
    try:
        result_image = await test_runner.run_test(test_folder)
        print(f"Shader execution successful! Image saved: {result_image}")
        
        # Judge the result if we have an image (unless disabled)
        if not args.no_judge and result_image and result_image.exists():
            print(f"Starting judge evaluation with {args.judge_model}...")
            judge = Judge(judge_model=args.judge_model)
            critic_path = Path(args.prompt_folder) / 'critic.txt'
            request_path = Path(args.prompt_folder) / 'request.txt'
            scores = await judge.evaluate_with_template(critic_path, request_path, result_image, test_folder)
            print(f"Judge evaluation completed. Scores: {scores}")
        else:
            if args.no_judge:
                print("Skipping judge evaluation (--no-judge flag set)")
            else:
                print("No result image to judge")
            scores = [0, 0, 0, 0, 0]  # Failed execution scores
            
    except Exception as e:
        print(f"Error during shader execution: {e}")
        scores = [0, 0, 0, 0, 0]  # Failed execution scores
    
    # Always save results (even if failed)
    test_runner.save_results(test_folder, scores, result_image is not None)
    
    # Generate isolated report for this test run (unless disabled)
    if not args.no_report:
        print("Generating report for this test run...")
        import subprocess
        try:
            cmd = [
                sys.executable, "generate_report.py",
                "--model", args.model,
                "--test-dir", str(test_folder)
            ]
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                print(f"Report generated in: {test_folder}/current_results_report.md")
            else:
                print(f"Report generation failed: {result.stderr}")
        except Exception as e:
            print(f"Error generating report: {e}")
    else:
        print("Skipping individual test report (--no-report flag set)")
    
    print("Test completed!")
    print(f"Results saved in: {test_folder}")
    print(f"Execution success: {result_image is not None}")
    print(f"Final scores: {scores}")

if __name__ == "__main__":
    asyncio.run(main())