import os
import requests
import json
import time
from typing import Dict, Any, Optional, Tuple
from dotenv import load_dotenv
from language_specs import ShaderLanguageSpec, WGSLSpec


def extract_usage_data(api_response: dict) -> Dict[str, Any]:
    """Extract usage/cost data from OpenRouter API response.

    Returns dict with standardized fields:
        - prompt_tokens: int
        - completion_tokens: int
        - total_tokens: int
        - cost: float (in credits)
        - cached_tokens: int (if available)
    """
    usage = api_response.get('usage', {})
    return {
        'prompt_tokens': usage.get('prompt_tokens', 0),
        'completion_tokens': usage.get('completion_tokens', 0),
        'total_tokens': usage.get('total_tokens', 0),
        'cost': usage.get('cost', 0.0),
        'cached_tokens': usage.get('prompt_tokens_details', {}).get('cached_tokens', 0),
    }

# Retry configuration
MAX_RETRIES = 3
RETRY_DELAY_BASE = 2  # seconds, doubles each retry

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

    async def generate_shaders(self, model_name: str, prompt: str) -> Tuple[str, Dict[str, Any]]:
        """Generate shader code using the specified OpenRouter model.

        Uses language_spec to load appropriate constraint prompts and reference examples.

        Args:
            model_name: OpenRouter model identifier
            prompt: Problem-specific prompt (from request.txt)

        Returns:
            Tuple of (content: str, usage: dict) where usage contains:
                - prompt_tokens, completion_tokens, total_tokens
                - cost (in credits)
                - cached_tokens
        """

        # Get language-specific reference examples from shader_harness
        shader_harness_example = self._get_shader_harness_example()

        # Load and format the prompt template with language-specific constraints
        full_prompt = self._format_prompt_template(prompt, shader_harness_example)

        payload = {
            "model": model_name,
            "max_tokens": 16384,  # Bumped from 8192 - some models are verbose
            "messages": [
                {
                    "role": "user",
                    "content": full_prompt
                }
            ]
        }

        last_error = None
        for attempt in range(MAX_RETRIES):
            try:
                response = requests.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json=payload,
                    timeout=300  # 5 minute timeout for complex requests
                )

                if response.status_code == 200:
                    result = response.json()
                    content = result['choices'][0]['message']['content']
                    usage = extract_usage_data(result)

                    # Check for truncated response (finish_reason != 'stop')
                    finish_reason = result['choices'][0].get('finish_reason', 'unknown')
                    if finish_reason == 'length':
                        print(f"  📝 Truncated (finish_reason=length): {len(content)} chars")
                        raise Exception("Response ended prematurely (hit token limit)")

                    # Content-based truncation detection
                    truncation_signals = self._detect_truncation(content)
                    if truncation_signals:
                        print(f"  ⚠️ Possible truncation detected: {truncation_signals}")
                        print(f"  📝 Response size: {len(content)} bytes, finish_reason: {finish_reason}")
                        raise Exception(f"Response appears truncated: {truncation_signals}")

                    return content, usage

                # Non-retryable errors (4xx client errors except rate limits)
                if response.status_code == 402:  # Payment required
                    raise Exception(f"OpenRouter API error: {response.status_code} - {response.text}")
                if response.status_code == 403:  # Forbidden (credit limit)
                    raise Exception(f"OpenRouter API error: {response.status_code} - {response.text}")
                if response.status_code == 401:  # Unauthorized
                    raise Exception(f"OpenRouter API error: {response.status_code} - {response.text}")

                # Retryable errors (429 rate limit, 5xx server errors)
                last_error = f"OpenRouter API error: {response.status_code} - {response.text}"

            except requests.exceptions.Timeout:
                last_error = "Request timed out"
            except requests.exceptions.ConnectionError:
                last_error = "Connection error"
            except Exception as e:
                error_msg = str(e).lower()
                if "prematurely" in error_msg or "truncated" in error_msg:
                    last_error = str(e)
                else:
                    raise  # Re-raise non-retryable exceptions

            # Exponential backoff before retry
            if attempt < MAX_RETRIES - 1:
                delay = RETRY_DELAY_BASE * (2 ** attempt)
                print(f"  ⚠️ Retry {attempt + 1}/{MAX_RETRIES} after {delay}s: {last_error}")
                time.sleep(delay)

        raise Exception(f"Failed after {MAX_RETRIES} retries: {last_error}")

    def _detect_truncation(self, content: str) -> str:
        """Detect if response appears truncated based on content analysis.

        Returns empty string if OK, or description of truncation signal if detected.
        """
        # Minimum viable shader is ~500 bytes (basic passthrough)
        # Real shaders are typically 2000-8000+ bytes
        MIN_SHADER_SIZE = 800

        if len(content) < MIN_SHADER_SIZE:
            return f"response too short ({len(content)} bytes, min {MIN_SHADER_SIZE})"

        # Check for unclosed code fence
        fence_count = content.count('```')
        if fence_count % 2 != 0:
            return "unclosed code fence (odd number of ```)"

        # Check if response ends mid-line (no newline at end after content)
        stripped = content.rstrip()
        if stripped and not stripped.endswith(('```', '}', ';', '*/')):
            # Likely cut off mid-statement
            last_line = stripped.split('\n')[-1] if '\n' in stripped else stripped
            if len(last_line) > 10 and not last_line.strip().startswith('//'):
                return f"ends mid-statement: '{last_line[-50:]}'"

        # Check for required shader components (WGSL)
        if '```wgsl' in content.lower() or '```' in content:
            # Should have both vertex and fragment shaders
            has_vertex = 'fn vs_main' in content or '@vertex' in content
            has_fragment = 'fn fs_main' in content or '@fragment' in content
            if not has_vertex:
                return "missing vertex shader (fn vs_main)"
            if not has_fragment:
                return "missing fragment shader (fn fs_main)"

        return ""  # No truncation detected

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
