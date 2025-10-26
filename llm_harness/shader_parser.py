import re
from typing import Dict, Tuple, List, Optional, NamedTuple
from language_specs import ShaderLanguageSpec, WGSLSpec


class WGSLRepair:
    """Simple compiler-error-driven repair."""

    def repair_from_error(self, code: str, error: str) -> str:
        """Apply fixes based on actual compiler error."""
        if "redefinition of `Params`" in error:
            return self._remove_duplicate_params(code)
        if "cannot assign to let" in error or "let binding is immutable" in error:
            return self._fix_let_mutations(code)
        return code

    def _remove_duplicate_params(self, code: str) -> str:
        """Keep only first struct Params."""
        pattern = r'struct\s+Params\s*\{[^}]*\}'
        matches = list(re.finditer(pattern, code))
        if len(matches) <= 1:
            return code

        result = code
        for match in reversed(matches[1:]):
            # Remove from start of line to end of struct
            start = code.rfind('\n', 0, match.start()) + 1
            end = match.end()
            while end < len(code) and code[end] in ' \t\n':
                end += 1
            result = result[:start] + result[end:]
            code = result
        return result

    def _fix_let_mutations(self, code: str) -> str:
        """Convert let to var<function> where needed."""
        return code.replace('let ', 'var<function> ', 1)


class ShaderParser:
    def __init__(self, language_spec: Optional[ShaderLanguageSpec] = None):
        self.language_spec = language_spec or WGSLSpec()

    def parse_response(self, llm_response: str) -> Tuple[Dict[str, str], str]:
        """Extract shader files from LLM response."""
        shaders = {}
        main_rs = ""

        shader_pattern = r'<shader\s+file="([^"]+)">(.*?)</shader>'
        for filename, content in re.findall(shader_pattern, llm_response, re.DOTALL):
            shaders[filename] = content.strip()

        if not shaders:
            shader_code_pattern = r'```(?:wgsl|glsl)\n(.*?)\n```'
            for i, content in enumerate(re.findall(shader_code_pattern, llm_response, re.DOTALL)):
                filename = f"shader_{i}{self.language_spec.file_extension}"
                shaders[filename] = content.strip()

        if not shaders:
            raise ValueError("No shader files found")

        return shaders, main_rs
