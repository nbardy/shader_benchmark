import os
import requests
import json
from typing import Dict, Any
from dotenv import load_dotenv

class LLMClient:
    def __init__(self):
        self.api_key = os.getenv('OPENROUTER_API_KEY')
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY environment variable not set")
        
        self.base_url = "https://openrouter.ai/api/v1"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
    
    async def generate_shaders(self, model_name: str, prompt: str) -> str:
        """Generate shader code using the specified OpenRouter model"""
        
        # Read shader_harness example to include as context
        shader_harness_example = self._get_shader_harness_example()
        
        # Load and format the prompt template
        full_prompt = self._format_prompt_template(prompt, shader_harness_example)
        
        payload = {
            "model": model_name,
            "messages": [
                {
                    "role": "user", 
                    "content": full_prompt
                }
            ]
        }
        
        response = requests.post(
            f"{self.base_url}/chat/completions",
            headers=self.headers,
            json=payload,
            timeout=300  # 5 minute timeout for complex requests
        )
        
        if response.status_code != 200:
            raise Exception(f"OpenRouter API error: {response.status_code} - {response.text}")
        
        result = response.json()
        return result['choices'][0]['message']['content']
    
    def _get_shader_harness_example(self) -> str:
        """Read the shader_harness example files to provide as context"""
        example_files = []
        shader_harness_path = "../shader_harness"
        
        # Read main.rs
        try:
            with open(f"{shader_harness_path}/src/main.rs", 'r') as f:
                main_content = f.read()
                example_files.append(f"main.rs:\n```rust\n{main_content}\n```")
        except FileNotFoundError:
            pass
        
        # Read shader files
        shaders_path = f"{shader_harness_path}/shaders"
        if os.path.exists(shaders_path):
            for shader_file in os.listdir(shaders_path):
                if shader_file.endswith('.wgsl'):
                    try:
                        with open(f"{shaders_path}/{shader_file}", 'r') as f:
                            shader_content = f.read()
                            example_files.append(f"{shader_file}:\n```wgsl\n{shader_content}\n```")
                    except FileNotFoundError:
                        pass
        
        # Read Cargo.toml
        try:
            with open(f"{shader_harness_path}/Cargo.toml", 'r') as f:
                cargo_content = f.read()
                example_files.append(f"Cargo.toml:\n```toml\n{cargo_content}\n```")
        except FileNotFoundError:
            pass
        
        return "\n\n".join(example_files)
    
    def _format_prompt_template(self, problem_prompt: str, shader_harness_example: str) -> str:
        """Load and format the prompt template with the problem and example"""
        try:
            with open("prompt_template.txt", 'r') as f:
                template = f.read()
            
            # Use simple string replacement to avoid formatting issues
            template = template.replace("{problem_prompt}", problem_prompt)
            template = template.replace("{shader_harness_example}", shader_harness_example)
            return template
            
        except FileNotFoundError:
            # Fallback to basic template if file not found
            return f"""
{problem_prompt}

Here is an example of a working shader project structure that you should follow:

{shader_harness_example}

Please output your response with XML blocks for each shader file and the main.rs file:
<shader file="filename.wgsl">
...shader code...
</shader>

<main_rs>
...main.rs code...
</main_rs>
"""