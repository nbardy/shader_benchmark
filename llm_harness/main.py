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

async def main():
    parser = argparse.ArgumentParser(description='LLM Shader Harness')
    parser.add_argument('--model', required=True, help='OpenRouter model name')
    parser.add_argument('--prompt-folder', required=True, help='Path to prompt folder')
    
    args = parser.parse_args()
    
    print(f"Running LLM Shader Harness with model: {args.model}")
    print(f"Using prompt folder: {args.prompt_folder}")
    
    # Load prompts
    prompt_loader = PromptLoader()
    request_prompt = prompt_loader.load_request_prompt(args.prompt_folder)
    judge_prompt = prompt_loader.load_judge_prompt(args.prompt_folder)
    
    # Initialize LLM client
    llm_client = LLMClient()
    
    # Generate shaders
    print("Generating shaders with LLM...")
    llm_response = await llm_client.generate_shaders(args.model, request_prompt)
    
    # Parse shader files
    parser = ShaderParser()
    shaders, main_rs = parser.parse_response(llm_response)
    
    # Create test folder and run
    test_runner = TestRunner()
    test_folder = test_runner.create_test_folder()
    test_runner.setup_test_files(test_folder, shaders, main_rs)
    
    result_image = None
    scores = None
    
    try:
        result_image = await test_runner.run_test(test_folder)
        print(f"Shader execution successful! Image saved: {result_image}")
        
        # Judge the result if we have an image
        if result_image and result_image.exists():
            print("Starting judge evaluation...")
            judge = Judge()
            scores = await judge.evaluate(judge_prompt, result_image)
            print(f"Judge evaluation completed. Scores: {scores}")
        else:
            print("No result image to judge")
            scores = [0, 0, 0, 0, 0]  # Failed execution scores
            
    except Exception as e:
        print(f"Error during shader execution: {e}")
        scores = [0, 0, 0, 0, 0]  # Failed execution scores
    
    # Always save results (even if failed)
    test_runner.save_results(test_folder, scores, result_image is not None)
    
    print("Test completed!")
    print(f"Results saved in: {test_folder}")
    print(f"Execution success: {result_image is not None}")
    print(f"Final scores: {scores}")

if __name__ == "__main__":
    asyncio.run(main())