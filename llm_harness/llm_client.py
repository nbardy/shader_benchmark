import os
import requests
import json
import time
import shutil
import subprocess
import tempfile
import base64
from pathlib import Path
from typing import Dict, Any, Optional, Tuple, List
from abc import ABC, abstractmethod
from dotenv import load_dotenv
from language_specs import ShaderLanguageSpec, WGSLSpec

def extract_usage_data(api_response: dict) -> Dict[str, Any]:
    """Extract usage/cost data from OpenRouter API response."""
    usage = api_response.get('usage', {})
    return {
        'prompt_tokens': usage.get('prompt_tokens', 0),
        'completion_tokens': usage.get('completion_tokens', 0),
        'total_tokens': usage.get('total_tokens', 0),
        'cost': usage.get('cost', 0.0),
        'cached_tokens': usage.get('prompt_tokens_details', {}).get('cached_tokens', 0),
    }

MAX_RETRIES = 3
RETRY_DELAY_BASE = 2  # seconds, doubles each retry

class LLMExecutor(ABC):
    @abstractmethod
    async def execute(self, model_name: str, payload_content: List[Dict[str, Any]], full_prompt: str, reference_image_path: Optional[str] = None) -> Tuple[str, Dict[str, Any]]:
        pass

_ZERO_USAGE: Dict[str, Any] = {
    'prompt_tokens': 0,
    'completion_tokens': 0,
    'total_tokens': 0,
    'cost': 0.0,
    'cached_tokens': 0,
}


class CliExecutor(LLMExecutor):
    """Run a local CLI tool (claude / codex / gemini) as the LLM backend.

    Each CLI has very different ergonomics for non-interactive use, so the
    backends are deliberately separate methods rather than a parameterised
    template — they don't actually share enough to abstract cleanly:

      * `claude -p`    : prompt on stdin, response on stdout, image attached
                         by including the absolute path in the prompt and
                         relying on Claude's Read tool.
      * `codex exec`   : prompt on stdin, response written to a `-o` file
                         (stdout is TUI-decorated and unsafe to parse), image
                         attached via the explicit `-i <path>` flag (codex
                         has no Read-tool path for files).
      * `gemini -p ""` : prompt appended on stdin, response on stdout (with a
                         "Loaded cached credentials." prefix line that we
                         strip), image attached by including the absolute
                         path in the prompt PLUS whitelisting the containing
                         directory via `--include-directories` (gemini's
                         read_file tool is sandboxed to cwd + whitelisted
                         dirs and we run from /tmp to avoid scanning the
                         repo).

    Authentication: in every backend we strip the provider-specific API-key
    env var so the CLI falls through to its subscription auth (Anthropic Max,
    ChatGPT plan, Google AI Pro). Set the env var explicitly only if you
    actually want token-based billing.
    """

    async def execute(self, model_name: str, payload_content: List[Dict[str, Any]], full_prompt: str, reference_image_path: Optional[str] = None) -> Tuple[str, Dict[str, Any]]:
        cli_command = model_name[4:]  # 'claude', 'codex', 'gemini', ...
        print(f"🚀 Using local CLI runner: {cli_command}")

        if cli_command == 'claude':
            return self._run_claude(full_prompt, reference_image_path)
        if cli_command == 'codex':
            return self._run_codex(full_prompt, reference_image_path)
        if cli_command == 'gemini':
            return self._run_gemini(full_prompt, reference_image_path)
        raise Exception(f"Unsupported CLI runner: cli/{cli_command}")

    def _base_env(self) -> Dict[str, str]:
        """Strip nested-session vars + provider API keys so each CLI uses
        its subscription auth instead of API-key billing."""
        env = os.environ.copy()
        for k in (
            'CLAUDECODE', 'CLAUDECODE_SESSION_ID',
            'ANTHROPIC_API_KEY',
            'OPENAI_API_KEY',
            'GEMINI_API_KEY', 'GOOGLE_API_KEY',
        ):
            env.pop(k, None)
        return env

    def _append_image_instruction(self, prompt: str, ref_abs: str, tool_name: str) -> str:
        return (
            f"{prompt}\n\nA REFERENCE IMAGE is provided at this absolute path:\n{ref_abs}\n"
            f"Use your {tool_name} tool to view this image, then design the shader "
            "to reproduce it as closely as possible procedurally.\n"
        )

    def _run_claude(self, full_prompt: str, reference_image_path: Optional[str]) -> Tuple[str, Dict[str, Any]]:
        prompt = full_prompt
        if reference_image_path:
            prompt = self._append_image_instruction(prompt, str(Path(reference_image_path).absolute()), 'Read')
        # --allowedTools Read keeps the agent from acting on the prompt's
        # `<shader file="shader.wgsl">` output marker as a Write instruction.
        cmd = [
            'claude', '-p',
            '--dangerously-skip-permissions',
            '--output-format', 'text',
            '--no-session-persistence',
            '--allowedTools', 'Read',
        ]
        try:
            result = subprocess.run(
                cmd, input=prompt, capture_output=True, text=True,
                timeout=900, env=self._base_env(),
            )
        except subprocess.TimeoutExpired:
            raise Exception("claude CLI timed out after 900s")
        if result.returncode != 0:
            raise Exception(f"claude CLI failed (exit {result.returncode}): {(result.stderr or '')[:1000]}")
        return result.stdout, dict(_ZERO_USAGE)

    def _run_codex(self, full_prompt: str, reference_image_path: Optional[str]) -> Tuple[str, Dict[str, Any]]:
        # codex stdout is TUI-decorated even with `--color never` (Unicode
        # borders, banners, "tokens used" footer). The supported way to get
        # ONLY the final assistant message is `-o <file>`, which we then read.
        # Image input has no Read-tool equivalent — must be attached via -i.
        with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as out_f:
            out_path = out_f.name
        try:
            # NOTE on flag ordering for codex 0.125+: `-a/--ask-for-approval`
            # is a TOP-LEVEL codex flag and must come BEFORE the `exec`
            # subcommand. `-s`, `--ephemeral`, etc. live on `exec`.
            # Putting `-a never` after `exec` raises "unexpected argument '-a'".
            cmd = [
                'codex',
                '-a', 'never',                  # never request approval (top-level)
                'exec',
                '-s', 'read-only',              # sandbox: deny all file writes
                '--skip-git-repo-check',        # cwd may not be a git repo
                '--ephemeral',                  # no resumable session
                '--color', 'never',             # disable ANSI in stdout (banner remains)
                '-o', out_path,                 # write final assistant msg here
            ]
            if reference_image_path:
                cmd += ['-i', str(Path(reference_image_path).absolute())]
            cmd += ['-']  # read prompt from stdin

            try:
                result = subprocess.run(
                    cmd, input=full_prompt, capture_output=True, text=True,
                    timeout=1800, env=self._base_env(),
                )
            except subprocess.TimeoutExpired:
                raise Exception("codex CLI timed out after 1800s")
            if result.returncode != 0:
                raise Exception(f"codex CLI failed (exit {result.returncode}): {(result.stderr or '')[:1000]}")
            with open(out_path, 'r') as f:
                content = f.read()
            return content, dict(_ZERO_USAGE)
        finally:
            try:
                os.unlink(out_path)
            except OSError:
                pass

    @staticmethod
    def _gemini_preflight() -> None:
        """Warn (don't fail) if ~/.gemini/tmp/ has grown big enough to OOM
        gemini-cli on startup. Each project the user has chatted with leaves
        a session dir; after several hundred projects, gemini's startup
        readdir callback exceeds JS heap and aborts.

        Threshold: ~80k files (well under the 200k-file OOM seen in practice
        on 0.35.0-nightly). User can clean with `rm -rf ~/.gemini/tmp/*`.
        """
        tmp = Path.home() / '.gemini' / 'tmp'
        if not tmp.exists():
            return
        try:
            entries = sum(1 for _ in tmp.iterdir())
        except OSError:
            return
        if entries > 400:
            print(
                f"⚠️  ~/.gemini/tmp/ has {entries} session dirs — gemini-cli "
                "may OOM on startup. If gemini calls fail, run: "
                "rm -rf ~/.gemini/tmp/*"
            )

    def _run_gemini(self, full_prompt: str, reference_image_path: Optional[str]) -> Tuple[str, Dict[str, Any]]:
        self._gemini_preflight()
        # gemini-cli walks the workspace recursively on startup. Two specific
        # things will OOM the node heap (verified on 0.35.0-nightly):
        #   1. `~/.gemini/tmp/` accumulates one dir per project the user has
        #      chatted in. With ~500 projects of chat history, the readdir
        #      callback array exceeds 8-16GB of JS heap. Mitigation: prune
        #      that dir periodically (`rm -rf ~/.gemini/tmp/*`).
        #   2. Passing a `--include-directories` path that lives inside a
        #      large project tree causes gemini to walk up and seed workspace
        #      context from the surrounding repo. Our problem dirs sit inside
        #      shader_benchmark/ which has 160MB of cargo target + 60MB of
        #      benchmark output → instant OOM.
        #
        # Fix for (2): stage the reference image into an isolated per-call
        # tempdir and whitelist that tempdir instead. gemini's workspace walk
        # then sees only one PNG with no surrounding tree.
        with tempfile.TemporaryDirectory(prefix='gemini_workspace_') as workspace:
            staged_ref: Optional[str] = None
            if reference_image_path:
                src = Path(reference_image_path).absolute()
                dst = Path(workspace) / src.name
                shutil.copy(src, dst)
                staged_ref = str(dst)

            prompt = full_prompt
            if staged_ref:
                prompt = self._append_image_instruction(prompt, staged_ref, 'read_file')

            # `-p ""` + stdin: gemini appends stdin to the -p value, which
            # avoids ARG_MAX / V8 string-arg OOM at 18KB+ prompts.
            # `--approval-mode plan`: read-only; refuses write_file/run_shell
            # so the agent can't drop a stray shader.wgsl from the output
            # marker.
            cmd = [
                'gemini', '-p', '',
                '--output-format', 'text',
                '--approval-mode', 'plan',
                '--include-directories', workspace,
            ]
            env = self._base_env()
            # 4GB default heap can still OOM during workspace seeding even
            # with the isolated workspace; 8GB has been verified sufficient.
            env['NODE_OPTIONS'] = (env.get('NODE_OPTIONS', '') + ' --max-old-space-size=8192').strip()
            try:
                result = subprocess.run(
                    cmd, input=prompt, capture_output=True, text=True,
                    timeout=1200, env=env,
                    cwd=workspace,
                )
            except subprocess.TimeoutExpired:
                raise Exception("gemini CLI timed out after 1200s")
            if result.returncode != 0:
                raise Exception(f"gemini CLI failed (exit {result.returncode}): {(result.stderr or '')[:1000]}")
            # gemini-cli exits 0 even when the upstream API returned 429
            # ("MODEL_CAPACITY_EXHAUSTED"). After the retry/backoff, the
            # fallback path emits a degenerate token stream (e.g. "0_1_0_1…")
            # that would silently pass through to the shader parser.
            # Surface the capacity error explicitly so the harness logs
            # something useful instead of "no shader files found".
            stderr_blob = result.stderr or ''
            for marker in ('RESOURCE_EXHAUSTED', 'MODEL_CAPACITY_EXHAUSTED',
                           'rateLimitExceeded', 'quotaExceeded'):
                if marker in stderr_blob:
                    raise Exception(
                        f"gemini upstream API over quota ({marker}) — try again later "
                        f"or switch to OpenRouter (google/gemini-2.5-pro)."
                    )
            return self._strip_gemini_noise(result.stdout), dict(_ZERO_USAGE)

    @staticmethod
    def _strip_gemini_noise(stdout: str) -> str:
        # gemini always prints "Loaded cached credentials." (and a trailing
        # ".") on stdout before the model output. Strip leading non-content
        # lines so the shader parser sees a clean response.
        lines = stdout.split('\n')
        while lines and (
            'cached credentials' in lines[0].lower()
            or lines[0].strip() in ('', '.')
        ):
            lines.pop(0)
        return '\n'.join(lines)

class OpenRouterExecutor(LLMExecutor):
    def __init__(self):
        self.api_key = os.getenv('OPENROUTER_API_KEY')
        if not self.api_key:
            raise ValueError("OPENROUTER_API_KEY environment variable not set")

        self.base_url = "https://openrouter.ai/api/v1"
        self.headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
    async def execute(self, model_name: str, payload_content: List[Dict[str, Any]], full_prompt: str, reference_image_path: Optional[str] = None) -> Tuple[str, Dict[str, Any]]:
        payload = {
            "model": model_name,
            "max_tokens": 16384,  # Bumped from 8192
            "messages": [
                {
                    "role": "user",
                    "content": payload_content
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
                    timeout=300
                )

                if response.status_code == 200:
                    result = response.json()
                    content = result['choices'][0]['message']['content']
                    usage = extract_usage_data(result)

                    finish_reason = result['choices'][0].get('finish_reason', 'unknown')
                    if finish_reason == 'length':
                        print(f"  📝 Truncated (finish_reason=length): {len(content)} chars")
                        raise Exception("Response ended prematurely (hit token limit)")

                    truncation_signals = self._detect_truncation(content)
                    if truncation_signals:
                        print(f"  ⚠️ Possible truncation detected: {truncation_signals}")
                        print(f"  📝 Response size: {len(content)} bytes, finish_reason: {finish_reason}")
                        raise Exception(f"Response appears truncated: {truncation_signals}")

                    return content, usage

                if response.status_code in [401, 402, 403]:
                    raise Exception(f"OpenRouter API error: {response.status_code} - {response.text}")

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
                    raise

            if attempt < MAX_RETRIES - 1:
                delay = RETRY_DELAY_BASE * (2 ** attempt)
                print(f"  ⚠️ Retry {attempt + 1}/{MAX_RETRIES} after {delay}s: {last_error}")
                time.sleep(delay)

        raise Exception(f"Failed after {MAX_RETRIES} retries: {last_error}")

    def _detect_truncation(self, content: str) -> str:
        MIN_SHADER_SIZE = 800

        if len(content) < MIN_SHADER_SIZE:
            return f"response too short ({len(content)} bytes, min {MIN_SHADER_SIZE})"

        fence_count = content.count('```')
        if fence_count % 2 != 0:
            return "unclosed code fence (odd number of ```)"

        stripped = content.rstrip()
        if stripped and not stripped.endswith(('```', '}', ';', '*/')):
            last_line = stripped.split('\n')[-1] if '\n' in stripped else stripped
            if len(last_line) > 10 and not last_line.strip().startswith('//'):
                return f"ends mid-statement: '{last_line[-50:]}'"

        if '```wgsl' in content.lower() or '```' in content:
            has_vertex = 'fn vs_main' in content or '@vertex' in content
            has_fragment = 'fn fs_main' in content or '@fragment' in content
            if not has_vertex:
                return "missing vertex shader (fn vs_main)"
            if not has_fragment:
                return "missing fragment shader (fn fs_main)"

        return ""

class LLMClient:
    def __init__(self, language_spec: Optional[ShaderLanguageSpec] = None):
        """Initialize LLM client with language specification."""
        self.language_spec = language_spec or WGSLSpec()

    async def generate_shaders(self, model_name: str, prompt: str, reference_image_path: Optional[str] = None) -> Tuple[str, Dict[str, Any]]:
        """Generate shader code using the specified model."""
        shader_harness_example = self._get_shader_harness_example()
        full_prompt = self._format_prompt_template(prompt, shader_harness_example)

        content_payload = [{"type": "text", "text": full_prompt}]
        
        if reference_image_path and Path(reference_image_path).exists():
            with open(reference_image_path, "rb") as image_file:
                image_base64 = base64.b64encode(image_file.read()).decode('utf-8')
            content_payload.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/png;base64,{image_base64}"
                }
            })

        # Factory logic for selecting the right executor strategy
        if model_name.startswith("cli/"):
            executor = CliExecutor()
        else:
            executor = OpenRouterExecutor()
            
        return await executor.execute(model_name, content_payload, full_prompt, reference_image_path)

    def _get_shader_harness_example(self) -> str:
        """Load language-specific reference examples from shader_harness."""
        script_dir = Path(__file__).parent.absolute()
        shader_harness_path = str(script_dir.parent / "shader_harness")
        example_files = self.language_spec.get_reference_examples(shader_harness_path)
        return "\n\n".join(example_files)

    def _format_prompt_template(self, problem_prompt: str, shader_harness_example: str) -> str:
        """Format prompt template using language_spec constraints."""
        try:
            with open("prompt_template.txt", 'r') as f:
                template = f.read()

            template = template.replace("{problem_prompt}", problem_prompt)
            template = template.replace("{shader_harness_example}", shader_harness_example)
            return template

        except FileNotFoundError:
            constraint_prompt = self.language_spec.constraint_prompt
            return f"{constraint_prompt}\n\nPROBLEM CONTEXT:\n---------------------------------------------\n{problem_prompt}\n\nREFERENCE EXAMPLES:\n---------------------------------------------\n{shader_harness_example}\n\nOUTPUT FORMAT:\n---------------------------------------------\n<shader file=\"{self.language_spec.fallback_filename}\">\n// Your {self.language_spec.name} shader code here\n</shader>\n"
