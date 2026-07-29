import asyncio
import os
import base64
import re
import shutil
import aiohttp
import json
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import List, Tuple, Optional, Dict, Any
from pathlib import Path
from dotenv import load_dotenv
from critic_template import CriticTemplate
from llm_client import parse_cli_spec, CliExecutor
from judge_panel import judge_safe_key

_ZERO_USAGE: Dict[str, Any] = {
    'prompt_tokens': 0, 'completion_tokens': 0, 'total_tokens': 0,
    'cost': 0.0, 'cached_tokens': 0,
}


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
try:
    from PIL import Image
    import numpy as np
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("⚠️ Warning: PIL/numpy not available - image analysis disabled")


@dataclass
class EvaluationContext:
    critic_path: Path
    request_path: Path
    result_image_path: Path
    save_dir: Optional[Path] = None
    code_path: Optional[Path] = None
    reference_image_path: Optional[Path] = None

class Judge:
    """Score a generated shader image against the problem's critic rubric.

    Supports two backends:
      * `<provider>/<model>` (default `anthropic/claude-opus-4-6`) — call
        OpenRouter. Requires `OPENROUTER_API_KEY`.
      * `cli/<tool>` (`cli/claude`, `cli/codex`) — invoke the local agentic
        CLI as the judge, billed against the user's subscription. The CLI
        is run with the same anti-write hardening as the gen path so it
        can't escape into the workspace.

    The CLI judge path is best used to remove OpenRouter spend on the judge
    side of a benchmark when the user has a Max / ChatGPT plan that absorbs
    the calls.
    """

    SUPPORTED_CLI_JUDGES = ("claude", "codex", "gemini")

    def __init__(self, judge_model: str = "anthropic/claude-opus-4-6"):
        self.judge_model = judge_model
        # Suffix used on per-judge log filenames so panel members don't
        # clobber each other's response/error logs in the shared save_dir.
        self.judge_log_suffix = judge_safe_key(judge_model)
        self.is_cli_judge = judge_model.startswith("cli/")

        if self.is_cli_judge:
            tool, self.cli_judge_model_q, self.cli_judge_extra = parse_cli_spec(judge_model)
            self.cli_judge_tool = tool
            if tool not in self.SUPPORTED_CLI_JUDGES:
                raise ValueError(
                    f"Unsupported CLI judge 'cli/{tool}'. Supported: "
                    f"{['cli/' + n for n in self.SUPPORTED_CLI_JUDGES]}"
                )
            # No OpenRouter key needed for CLI path.
            self.api_key = None
            self.base_url = None
            self.headers = None
        else:
            self.api_key = os.getenv('OPENROUTER_API_KEY')
            if not self.api_key:
                raise ValueError("OPENROUTER_API_KEY environment variable not set")
            self.base_url = "https://openrouter.ai/api/v1"
            self.headers = {
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            }

        self.critic_template = CriticTemplate()

    def analyze_image_quality(self, image_path: Path) -> Tuple[bool, Optional[str]]:
        """
        Analyze image to detect obvious failures that should skip LLM judge.

        Uses multiple metrics to avoid false positives:
        - Mean pixel value alone is insufficient (starfield on black has low mean but is valid)
        - Also check max pixel value and standard deviation

        Returns:
            (should_skip, failure_reason) where:
            - should_skip: True if image is obviously failed (all black/white)
            - failure_reason: "ALL_BLACK", "ALL_WHITE", or None

        Args:
            image_path: Path to the rendered image
        """
        if not HAS_PIL:
            return (False, None)  # Can't analyze without PIL

        if not image_path or not image_path.exists():
            return (True, "NO_IMAGE")

        try:
            # Load image and convert to RGB numpy array
            img = Image.open(image_path).convert('RGB')
            pixels = np.array(img)

            # Calculate statistics
            mean_value = np.mean(pixels)
            max_value = np.max(pixels)
            std_value = np.std(pixels)

            # ALL BLACK detection:
            # - Mean must be very low (< 1.0)
            # - AND max must be low (< 10) - no bright pixels at all
            # - AND stddev must be near zero (< 2) - uniform darkness
            # This avoids false positives for starfields/galaxies on black backgrounds
            if mean_value < 1.0 and max_value < 10 and std_value < 2.0:
                return (True, "ALL_BLACK")

            # ALL WHITE detection:
            # - Mean must be very high (> 254)
            # - AND min must be high (> 245) - no dark pixels
            # - AND stddev must be near zero (< 2) - uniform brightness
            min_value = np.min(pixels)
            if mean_value > 254.0 and min_value > 245 and std_value < 2.0:
                return (True, "ALL_WHITE")

            # Image has meaningful content, proceed with LLM judge
            return (False, None)

        except Exception as e:
            print(f"Warning: Failed to analyze image quality: {e}")
            return (False, None)  # Don't skip on analysis errors

    async def evaluate_with_template(self, context: EvaluationContext) -> Tuple[List[int], Optional[str], Dict[str, Any]]:
        """
        Evaluate using structured critic template system.

        Returns:
            (scores, failure_reason, usage) where:
            - scores: List[int] of 5 scores (0-100 each)
            - failure_reason: "NO_IMAGE" if no image exists, None otherwise
            - usage: Dict with cost/token data from API
        """
        empty_usage = {'prompt_tokens': 0, 'completion_tokens': 0, 'total_tokens': 0, 'cost': 0.0, 'cached_tokens': 0}

        # Only skip if there's literally no image file to judge
        if not context.result_image_path or not context.result_image_path.exists():
            print(f"⏭️  Skipping LLM judge - NO IMAGE GENERATED (0/500)")
            if context.save_dir and context.save_dir.exists():
                skip_log = context.save_dir / f"judge_skipped.{self.judge_log_suffix}.txt"
                with open(skip_log, 'w') as f:
                    f.write("JUDGE SKIPPED - NO IMAGE GENERATED\n")
                    f.write("Reason: No result image file found\n")
                    f.write("Score: 0/500 (automatic failure)\n")
            return ([0, 0, 0, 0, 0], "NO_IMAGE", empty_usage)

        # Always send to LLM judge - let it score everything
        # (removed "smart skip" for black/white images - caused false positives)
        judge_prompt = self.critic_template.format_critic_prompt(context.critic_path, context.request_path)
        scores, usage = await self.evaluate(judge_prompt, context)
        if not any(isinstance(s, (int, float)) and s > 0 for s in scores):
            raise RuntimeError(
                f"{self.judge_model} judge response did not contain parseable nonzero scores"
            )
        return (scores, None, usage)
    
    async def evaluate(self, judge_prompt: str, context: EvaluationContext) -> Tuple[List[int], Dict[str, Any]]:
        """Score the shader image. Routes to OpenRouter or a local CLI based
        on `judge_model` (`cli/...` → CLI). Returns (scores, usage)."""
        if self.is_cli_judge:
            # to_thread is load-bearing: _evaluate_via_cli blocks on
            # subprocess.run, which would freeze the event loop and serialize
            # every judge in the panel. The 4-slot CLI judge semaphore in the
            # harness only delivers real concurrency because of this hop.
            return await asyncio.to_thread(self._evaluate_via_cli, judge_prompt, context)
        return await self._evaluate_via_openrouter(judge_prompt, context)

    async def _evaluate_via_openrouter(self, judge_prompt: str, context: EvaluationContext) -> Tuple[List[int], Dict[str, Any]]:
        """Evaluate via OpenRouter chat-completions API (default path)."""
        empty_usage = dict(_ZERO_USAGE)

        if not context.result_image_path or not context.result_image_path.exists():
            print(f"Error: Result image not found at {context.result_image_path}")
            return [1, 1, 1, 1, 1], empty_usage
        
        # Encode image to base64
        try:
            image_base64 = self._encode_image(context.result_image_path)
        except Exception as e:
            print(f"Error encoding image: {e}")
            return [1, 1, 1, 1, 1], empty_usage
        
        # The judge_prompt from template already contains instructions
        full_prompt = judge_prompt

        if context.code_path and context.code_path.exists():
            try:
                with open(context.code_path, 'r', encoding='utf-8') as f:
                    code_content = f.read()
                full_prompt += f"\n\nHere is the source code of the shader:\n```\n{code_content}\n```\nPlease evaluate if the code cheats by reading actual pixel values instead of using procedural generation."
            except Exception as e:
                print(f"Error reading code file: {e}")

        content_payload = [
            {
                "type": "text",
                "text": full_prompt
            },
            {
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/png;base64,{image_base64}"
                }
            }
        ]

        if context.reference_image_path and context.reference_image_path.exists():
            try:
                ref_base64 = self._encode_image(context.reference_image_path)
                content_payload.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:image/png;base64,{ref_base64}"
                    }
                })
                full_prompt += "\n\nA reference image has been provided. The first image is the generated result, the second image is the reference image."
                content_payload[0]["text"] = full_prompt
            except Exception as e:
                print(f"Error encoding reference image: {e}")
        
        try:
            payload = {
                "model": self.judge_model,
                "messages": [
                    {
                        "role": "user",
                        "content": content_payload
                    }
                ]
            }
            
            print(f"Calling {self.judge_model} for evaluation...")
            
            async with aiohttp.ClientSession() as session:
                async with session.post(
                    f"{self.base_url}/chat/completions",
                    headers=self.headers,
                    json=payload
                ) as response:
                    
                    if response.status != 200:
                        error_text = await response.text()
                        raise Exception(f"OpenRouter API error: {response.status} - {error_text}")
                    
                    result = await response.json()
                    response_text = result['choices'][0]['message']['content']
                    usage = extract_usage_data(result)
                    print(f"Judge response: {response_text}")
                    print(f"Judge cost: ${usage['cost']:.4f} ({usage['total_tokens']} tokens)")

                    # Save raw judge response if save directory provided
                    if context.save_dir and context.save_dir.exists():
                        judge_log_file = context.save_dir / f"judge_response.{self.judge_log_suffix}.txt"
                        with open(judge_log_file, 'w', encoding='utf-8') as f:
                            f.write("=== JUDGE EVALUATION LOG ===\n\n")
                            f.write("PROMPT:\n")
                            f.write(full_prompt)
                            f.write("\n\n" + "="*50 + "\n\n")
                            f.write("RAW RESPONSE:\n")
                            f.write(response_text)
                            f.write("\n\n" + "="*50 + "\n\n")
                            f.write(f"USAGE:\n{usage}\n\n")
                        print(f"Judge response saved to: {judge_log_file}")

                    # Parse scores from response
                    scores = self._parse_scores(response_text)

                    # Add parsed scores to log file if it exists
                    if context.save_dir and context.save_dir.exists():
                        judge_log_file = context.save_dir / f"judge_response.{self.judge_log_suffix}.txt"
                        with open(judge_log_file, 'a', encoding='utf-8') as f:
                            f.write(f"PARSED SCORES:\n{scores}\n\n")
                            if scores == [1, 1, 1, 1, 1]:
                                f.write("⚠️ WARNING: Default fallback scores - parsing may have failed!\n")

                    print(f"Parsed scores: {scores}")
                    return scores, usage
            
        except Exception as e:
            print(f"Error calling judge ({self.judge_model}): {e}")

            # Save error log; then re-raise so the harness saves judge
            # stage='failed' and the next resume re-judges this problem
            # (using the cached render image — generation is NOT redone).
            if context.save_dir and context.save_dir.exists():
                error_log_file = context.save_dir / f"judge_error.{self.judge_log_suffix}.txt"
                with open(error_log_file, 'w', encoding='utf-8') as f:
                    f.write("=== JUDGE ERROR LOG ===\n\n")
                    f.write(f"ERROR: {str(e)}\n\n")
                    f.write("PROMPT USED:\n")
                    f.write(full_prompt)
                    f.write("\n\nThis judge call failed; the harness will mark judge=failed and re-judge on the next resume.\n")
                print(f"Judge error logged to: {error_log_file}")

            raise

    # ------------------------------------------------------------------
    # CLI judge path
    # ------------------------------------------------------------------
    @staticmethod
    def _judge_cli_env() -> Dict[str, str]:
        """Same env hygiene as LLMClient.CliExecutor: drop nested-session vars
        and provider API keys so the CLI uses subscription auth, not a key."""
        env = os.environ.copy()
        for k in (
            'CLAUDECODE', 'CLAUDECODE_SESSION_ID',
            'ANTHROPIC_API_KEY', 'OPENAI_API_KEY',
            'GEMINI_API_KEY', 'GOOGLE_API_KEY',
        ):
            env.pop(k, None)
        return env

    def _evaluate_via_cli(self, judge_prompt: str, context: EvaluationContext) -> Tuple[List[int], Dict[str, Any]]:
        """Run the configured CLI tool as the judge. Returns (scores, zero-usage).

        We append the shader source (when available) to the prompt the same
        way the OpenRouter path does, so the cheating-check still works.
        Reference + result images are passed natively via the CLI flag for
        codex (`-i <FILE>`) or via Read-tool absolute-path instructions for
        claude.
        """
        empty_usage = dict(_ZERO_USAGE)

        if not context.result_image_path or not context.result_image_path.exists():
            print(f"Error: Result image not found at {context.result_image_path}")
            return [1, 1, 1, 1, 1], empty_usage

        full_prompt = judge_prompt
        if context.code_path and context.code_path.exists():
            try:
                code_content = context.code_path.read_text(encoding='utf-8')
                full_prompt += (
                    f"\n\nHere is the source code of the shader:\n```\n{code_content}\n```\n"
                    "Please evaluate if the code cheats by reading actual pixel values "
                    "instead of using procedural generation."
                )
            except Exception as e:
                print(f"Error reading code file: {e}")

        if context.reference_image_path and context.reference_image_path.exists():
            full_prompt += (
                "\n\nA reference image has been provided. The first image is the "
                "generated result, the second image is the reference image."
            )

        tool = self.cli_judge_tool
        print(f"Calling {self.judge_model} for evaluation...")

        try:
            if tool == 'codex':
                response_text = self._run_codex_judge(full_prompt, context)
            elif tool == 'claude':
                response_text = self._run_claude_judge(full_prompt, context)
            elif tool == 'gemini':
                response_text = self._run_gemini_judge(full_prompt, context)
            else:
                raise ValueError(f"unsupported CLI judge cli/{tool}")
        except Exception as e:
            # Save error context for postmortem, then re-raise. The
            # harness's judge-stage handler catches this, saves
            # status='failed' on the checkpoint, and re-running the
            # benchmark resumes by re-judging only the failed problems
            # (cached render image is reused — generation is NOT redone).
            print(f"Error calling judge ({self.judge_model}): {e}")
            if context.save_dir and context.save_dir.exists():
                error_log = context.save_dir / f"judge_error.{self.judge_log_suffix}.txt"
                with open(error_log, 'w', encoding='utf-8') as f:
                    f.write(f"=== JUDGE ERROR LOG ({self.judge_model}) ===\n\n")
                    f.write(f"ERROR: {e}\n\nPROMPT USED:\n{full_prompt}\n")
            raise

        # Persist the raw response for debugging.
        if context.save_dir and context.save_dir.exists():
            judge_log = context.save_dir / f"judge_response.{self.judge_log_suffix}.txt"
            with open(judge_log, 'w', encoding='utf-8') as f:
                f.write(f"=== JUDGE EVALUATION LOG ({self.judge_model}) ===\n\nPROMPT:\n")
                f.write(full_prompt)
                f.write("\n\n" + "=" * 50 + "\n\nRAW RESPONSE:\n")
                f.write(response_text)
                f.write("\n\n" + "=" * 50 + "\n\nUSAGE: (CLI judge — billed to subscription, not OpenRouter)\n\n")
            scores = self._parse_scores(response_text)
            with open(judge_log, 'a', encoding='utf-8') as f:
                f.write(f"PARSED SCORES:\n{scores}\n\n")
                if scores == [1, 1, 1, 1, 1]:
                    f.write("⚠️ WARNING: Default fallback scores - parsing may have failed!\n")
            print(f"Parsed scores: {scores}")
            return scores, empty_usage

        scores = self._parse_scores(response_text)
        print(f"Parsed scores: {scores}")
        return scores, empty_usage

    def _run_codex_judge(self, full_prompt: str, context: EvaluationContext) -> str:
        """codex exec with -i for each image; final assistant message via -o file."""
        with tempfile.TemporaryDirectory(
            prefix="codex_judge_workspace_"
        ) as workspace:
            workspace_path = Path(workspace)
            out_path = workspace_path / "final_response.txt"
            staged_result = workspace_path / (
                f"generated{context.result_image_path.suffix}"
            )
            shutil.copy2(context.result_image_path, staged_result)

            staged_reference: Optional[Path] = None
            if (
                context.reference_image_path
                and context.reference_image_path.exists()
            ):
                staged_reference = workspace_path / (
                    f"reference{context.reference_image_path.suffix}"
                )
                shutil.copy2(context.reference_image_path, staged_reference)

            cmd = [
                'codex', '-a', 'never', 'exec',
                '-s', 'read-only',
                '--skip-git-repo-check',
                '--ephemeral',
                '--ignore-user-config',
                '--ignore-rules',
                '--color', 'never',
                '-o', str(out_path),
            ]
            if self.cli_judge_model_q:
                cmd += ['-m', self.cli_judge_model_q]
            if self.cli_judge_extra:
                cmd += ['-c', f'reasoning_effort={self.cli_judge_extra}']
            cmd += ['-i', str(staged_result)]
            if staged_reference:
                cmd += ['-i', str(staged_reference)]
            cmd += ['-']

            try:
                result = subprocess.run(
                    cmd, input=full_prompt, capture_output=True, text=True,
                    timeout=900, env=self._judge_cli_env(), cwd=workspace,
                )
            except subprocess.TimeoutExpired:
                raise Exception("codex judge timed out after 900s")
            if result.returncode != 0:
                raise Exception(f"codex judge failed (exit {result.returncode}): {(result.stderr or '')[:500]}")
            with open(out_path, 'r', encoding='utf-8') as f:
                return f.read()

    def _run_claude_judge(self, full_prompt: str, context: EvaluationContext) -> str:
        """claude -p with Read tool authorized so it can load the images by path."""
        with tempfile.TemporaryDirectory(
            prefix="claude_judge_workspace_"
        ) as workspace:
            workspace_path = Path(workspace)
            staged_result = workspace_path / (
                f"generated{context.result_image_path.suffix}"
            )
            shutil.copy2(context.result_image_path, staged_result)
            prompt = (
                f"{full_prompt}\n\nThe images you need to evaluate are at "
                "these absolute paths — use your Read tool to view them:\n"
                f"- generated result: {staged_result}\n"
            )
            if (
                context.reference_image_path
                and context.reference_image_path.exists()
            ):
                staged_reference = workspace_path / (
                    f"reference{context.reference_image_path.suffix}"
                )
                shutil.copy2(context.reference_image_path, staged_reference)
                prompt += f"- reference: {staged_reference}\n"

            cmd = [
                'claude', '-p',
                '--dangerously-skip-permissions',
                '--output-format', 'text',
                '--no-session-persistence',
                '--bare',
                '--allowedTools', 'Read',
                '--disallowedTools', 'Write,Edit,NotebookEdit,Bash',
            ]
            if self.cli_judge_model_q:
                cmd += ['--model', self.cli_judge_model_q]
            if self.cli_judge_extra:
                cmd += ['--effort', self.cli_judge_extra]
            try:
                result = subprocess.run(
                    cmd, input=prompt, capture_output=True, text=True,
                    timeout=900, env=self._judge_cli_env(), cwd=workspace,
                )
            except subprocess.TimeoutExpired:
                raise Exception("claude judge timed out after 900s")
            if result.returncode != 0:
                raise Exception(
                    f"claude judge failed (exit {result.returncode}): "
                    f"{(result.stderr or '')[:500]}"
                )
            return result.stdout

    def _run_gemini_judge(self, full_prompt: str, context: EvaluationContext) -> str:
        """gemini -p with images staged into an isolated tempdir workspace.

        Mirrors `LLMClient._run_gemini`: gemini-cli walks `--include-directories`
        recursively on startup and OOMs the node heap if pointed at any folder
        inside this repo (cargo target + benchmark output > 200MB combined).
        Stage the images into a fresh tempdir, whitelist only that tempdir, and
        bump V8's heap to 8GB so the workspace seed phase doesn't crash.
        """
        # Heap-OOM guard: refuse to run if ~/.gemini/tmp/ has grown past the
        # threshold seen to OOM gemini-cli on startup. Reuses the same
        # preflight LLMClient runs for the gen path.
        CliExecutor._gemini_preflight()

        with tempfile.TemporaryDirectory(prefix='gemini_judge_workspace_') as workspace:
            workspace_path = Path(workspace)
            staged_result = workspace_path / context.result_image_path.name
            shutil.copy(context.result_image_path, staged_result)

            staged_ref: Optional[Path] = None
            if context.reference_image_path and context.reference_image_path.exists():
                staged_ref = workspace_path / f"reference_{context.reference_image_path.name}"
                shutil.copy(context.reference_image_path, staged_ref)

            prompt = (
                f"{full_prompt}\n\n"
                f"The images you need to evaluate are at these absolute paths — use your "
                f"read_file tool to view them:\n"
                f"- generated result: {staged_result.absolute()}\n"
            )
            if staged_ref:
                prompt += f"- reference: {staged_ref.absolute()}\n"

            cmd = [
                'gemini', '-p', '',
                '--output-format', 'text',
                '--approval-mode', 'plan',
                '--include-directories', workspace,
            ]
            if self.cli_judge_model_q:
                cmd += ['-m', self.cli_judge_model_q]

            env = self._judge_cli_env()
            # 4GB default heap can OOM during workspace seeding even with the
            # isolated tempdir; 8GB has been verified sufficient on the gen
            # path. Append rather than replace so any user override survives.
            env['NODE_OPTIONS'] = (env.get('NODE_OPTIONS', '') + ' --max-old-space-size=8192').strip()

            try:
                result = subprocess.run(
                    cmd, input=prompt, capture_output=True, text=True,
                    timeout=1200, env=env, cwd=workspace,
                )
            except subprocess.TimeoutExpired:
                raise Exception("gemini judge timed out after 1200s")
            if result.returncode != 0:
                raise Exception(f"gemini judge failed (exit {result.returncode}): {(result.stderr or '')[:1000]}")

            # gemini-cli can print transient 429/capacity errors while it is
            # still retrying, then exit 0 with a valid final answer on stdout.
            # Do not fail merely because stderr mentions RESOURCE_EXHAUSTED;
            # the caller parses stdout and treats non-parseable/all-zero
            # output as retryable. Keeping stderr non-fatal lets recovered
            # attempts with valid <scores> count.
            stderr_blob = result.stderr or ''
            for marker in ('RESOURCE_EXHAUSTED', 'MODEL_CAPACITY_EXHAUSTED',
                           'rateLimitExceeded', 'quotaExceeded'):
                if marker in stderr_blob:
                    print(f"⚠️ gemini stderr included transient {marker}; checking final stdout")
                    break
            return CliExecutor._strip_gemini_noise(result.stdout)

    def _encode_image(self, image_path: Path) -> str:
        """Encode image to base64 for OpenAI API"""
        with open(image_path, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')
    
    def _parse_scores(self, response_text: str) -> List[int]:
        """Parse scores from the judge response - supports both XML and legacy formats"""
        
        # First try new XML format: <scores><S1>85</S1><S2>72</S2>...</scores>
        scores_xml_pattern = r'<scores>(.*?)</scores>'
        xml_match = re.search(scores_xml_pattern, response_text, re.DOTALL)
        
        if xml_match:
            xml_content = xml_match.group(1)
            try:
                scores = []
                missing = []
                for i in range(1, 6):
                    score_pattern = rf'<S{i}>(\d+)</S{i}>'
                    score_match = re.search(score_pattern, xml_content)
                    if score_match:
                        score = int(score_match.group(1))
                        # Validate score is in range 1-100
                        score = max(1, min(100, score))
                        scores.append(score)
                    else:
                        missing.append(f"S{i}")
                        scores.append(0)

                if not missing:
                    print(f"Successfully parsed XML scores: {scores}")
                    return scores
                # Partial XML response: do NOT silently default missing
                # scores to 50 (was the old behavior — it polluted the panel
                # mean with fake middle scores when a judge omitted some
                # tags). Return the all-zero "failure" signal; the caller
                # raises so the harness marks the judge stage retryable.
                print(f"⚠️ Partial XML response — missing {missing}; treating as parse failure")
                return [0, 0, 0, 0, 0]

            except Exception as e:
                print(f"Error parsing XML scores: {e}")
        
        # Fallback to legacy SCORES: [X, X, X, X, X] pattern (1-10 scale)
        scores_pattern = r'SCORES:\s*\[(\d+),\s*(\d+),\s*(\d+),\s*(\d+),\s*(\d+)\]'
        match = re.search(scores_pattern, response_text)
        
        if match:
            scores = [int(match.group(i)) for i in range(1, 6)]
            # Convert 1-10 scale to 1-100 scale for backward compatibility
            scores = [max(1, min(10, score)) * 10 for score in scores]
            print(f"Parsed legacy scores (converted to 100-scale): {scores}")
            return scores
        
        # Try to find any sequence of 5 numbers that could be scores
        all_numbers = re.findall(r'\b\d+\b', response_text)
        if len(all_numbers) >= 5:
            scores = []
            for num_str in all_numbers[:5]:
                num = int(num_str)
                if 1 <= num <= 10:
                    # Assume 1-10 scale, convert to 1-100
                    scores.append(num * 10)
                elif 1 <= num <= 100:
                    # Assume 1-100 scale
                    scores.append(num)
                else:
                    # Invalid score, use default
                    scores.append(50)
            
            if len(scores) == 5:
                print(f"Parsed fallback scores: {scores}")
                return scores
        
        print("Could not parse scores from judge response, using default scores")
        return [0, 0, 0, 0, 0]  # Default scores for missing/errored evaluations (1-100 scale)
