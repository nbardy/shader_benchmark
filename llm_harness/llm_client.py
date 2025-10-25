import os
import requests
import json
from typing import Dict, Any, Optional
from dotenv import load_dotenv
from language_specs import ShaderLanguageSpec, WGSLSpec

class LLMClient:
    def __init__(self, language_spec: Optional[ShaderLanguageSpec] = None):
        """Initialize LLM client with language specification.

        Args:
            language_spec: Language specification defining constraint prompts and examples.
                          Defaults to WGSLSpec() for backward compatibility.
        """
        self.language_spec = language_spec or WGSLSpec()

        self.api_key = os.getenv('OPENROUTER_API_KEY')
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY environment variable not set")

        self.base_url = "https://openrouter.ai/api/v1"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

    async def generate_shaders(self, model_name: str, prompt: str) -> str:
        """Generate shader code using the specified OpenRouter model.

        Uses language_spec to load appropriate constraint prompts and reference examples.

        Args:
            model_name: OpenRouter model identifier
            prompt: Problem-specific prompt (from request.txt)

        Returns:
            LLM response containing generated shader code
        """

        # Get language-specific reference examples from shader_harness
        shader_harness_example = self._get_shader_harness_example()

        # Load and format the prompt template with language-specific constraints
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
        """Load language-specific reference examples from shader_harness.

        Delegates to language_spec.get_reference_examples() to load appropriate
        examples for the target language (WGSL vs GLSL).

        Returns:
            Formatted string containing reference examples
        """
        from pathlib import Path
        script_dir = Path(__file__).parent.absolute()
        shader_harness_path = str(script_dir.parent / "shader_harness")

        # Use language_spec to load appropriate examples
        example_files = self.language_spec.get_reference_examples(shader_harness_path)

        return "\n\n".join(example_files)

    def _format_prompt_template(self, problem_prompt: str, shader_harness_example: str) -> str:
        """Format prompt template using language_spec constraints.

        Tries to load prompt_template.txt first (for backward compatibility),
        then falls back to language_spec.constraint_prompt.

        Args:
            problem_prompt: Problem-specific prompt from request.txt
            shader_harness_example: Reference examples from shader_harness

        Returns:
            Formatted complete prompt for LLM
        """
        try:
            # Try to load existing prompt_template.txt (backward compatibility)
            with open("prompt_template.txt", 'r') as f:
                template = f.read()

            # Use simple string replacement to avoid formatting issues
            template = template.replace("{problem_prompt}", problem_prompt)
            template = template.replace("{shader_harness_example}", shader_harness_example)
            return template

        except FileNotFoundError:
            # Fallback: Use language_spec constraint prompt
            constraint_prompt = self.language_spec.constraint_prompt

            # Build complete prompt from language_spec
            return f"""{constraint_prompt}

PROBLEM CONTEXT:
---------------------------------------------
{problem_prompt}

REFERENCE EXAMPLES:
---------------------------------------------
{shader_harness_example}

OUTPUT FORMAT:
---------------------------------------------
<shader file="{self.language_spec.fallback_filename}">
// Your {self.language_spec.name} shader code here
</shader>
"""
