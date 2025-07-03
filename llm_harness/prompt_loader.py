import os
from pathlib import Path

class PromptLoader:
    def __init__(self):
        pass
    
    def load_request_prompt(self, prompt_folder: str) -> str:
        """Load the request prompt from the specified folder"""
        request_file = Path(prompt_folder) / "request.txt"
        
        if not request_file.exists():
            raise FileNotFoundError(f"Request prompt file not found: {request_file}")
        
        with open(request_file, 'r', encoding='utf-8') as f:
            return f.read().strip()
    
    def load_judge_prompt(self, prompt_folder: str) -> str:
        """Load the judge prompt from the specified folder"""
        judge_file = Path(prompt_folder) / "judge.txt"
        
        if not judge_file.exists():
            raise FileNotFoundError(f"Judge prompt file not found: {judge_file}")
        
        with open(judge_file, 'r', encoding='utf-8') as f:
            return f.read().strip()
    
    def load_critic_prompt(self, prompt_folder: str) -> str:
        """Load the critic prompt from the specified folder (optional)"""
        critic_file = Path(prompt_folder) / "critic.txt"
        
        if not critic_file.exists():
            return ""
        
        with open(critic_file, 'r', encoding='utf-8') as f:
            return f.read().strip()