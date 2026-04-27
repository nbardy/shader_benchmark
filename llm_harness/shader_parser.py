import re
from typing import Dict, Tuple, List, Optional, NamedTuple
from language_specs import ShaderLanguageSpec, WGSLSpec


class WGSLRepair:
    """Simple compiler-error-driven repair.

    See HAIKU_ERROR_PATTERNS.md for comprehensive error documentation.

    Repair Methods:
    - _fix_params_naming: Params variable/type conflict (40% → 80% improvement)
    - _fix_mod_function: mod(x,y) → x % y conversion
    - _fix_reserved_keywords: Renames reserved words
    - _fix_numeric_overflow: Clamps f32 to max 3.4e38
    - _fix_let_mutations: let → var<function>
    - _fix_underscore_identifier: _ → _unused
    """

    # WGSL reserved keywords (from WGSL spec 2024)
    RESERVED_KEYWORDS = {'target', 'handle', 'using', 'namespace', 'typedef', 'ref', 'ptr'}

    def repair_from_error(self, code: str, error: str) -> str:
        """Apply fixes based on actual compiler error."""
        # Fix naming conflict: var<uniform> Params: Params -> var<uniform> params: Params
        if ("redefinition of" in error or "previous definition of" in error) and "Params" in error:
            # First try to fix naming conflict (uppercase variable name)
            fixed = self._fix_params_naming(code)
            if fixed != code:
                return fixed
            # If that didn't work, try removing duplicate struct definitions
            return self._remove_duplicate_params(code)

        # Fix mod() function (GLSL → WGSL)
        if "no definition" in error and "mod" in error:
            return self._fix_mod_function(code)

        # Fix reserved keywords
        if "reserved keyword" in error:
            return self._fix_reserved_keywords(code)

        # Fix numeric overflow
        if "numeric literal not representable" in error:
            return self._fix_numeric_overflow(code)

        # Fix underscore identifier
        if "Identifier can't be '_'" in error or "identifier cannot be '_'" in error:
            return self._fix_underscore_identifier(code)

        # Fix let mutations
        if "cannot assign to let" in error or "let binding is immutable" in error or "invalid left-hand side of assignment" in error:
            return self._fix_let_mutations(code)

        # Fix var<function> syntax error (should just be var inside functions)
        if "expected identifier" in error and "var<function>" in code:
            return self._fix_var_function_syntax(code)

        return code

    def _remove_duplicate_params(self, code: str) -> str:
        """Keep only first struct Params, removing subsequent definitions."""
        # Find all struct Params definitions with proper brace matching
        lines = code.split('\n')
        struct_starts = []

        for i, line in enumerate(lines):
            if 'struct' in line and 'Params' in line and '{' in line:
                struct_starts.append(i)

        # If only one or fewer structs, return as-is
        if len(struct_starts) <= 1:
            return code

        # Keep only first struct Params, remove rest
        # Find end of first struct by brace matching
        first_start = struct_starts[0]
        brace_count = 0
        first_end = first_start

        for i in range(first_start, len(lines)):
            brace_count += lines[i].count('{')
            brace_count -= lines[i].count('}')
            if brace_count == 0 and i >= first_start:
                first_end = i
                break

        # Keep everything up to end of first struct, then skip remaining structs
        result_lines = lines[:first_end + 1]

        # Skip any remaining Params definitions
        i = first_end + 1
        while i < len(lines):
            line = lines[i]
            if 'struct' in line and 'Params' in line and '{' in line:
                # Skip this struct definition
                brace_count = 0
                while i < len(lines):
                    brace_count += lines[i].count('{')
                    brace_count -= lines[i].count('}')
                    i += 1
                    if brace_count == 0:
                        break
            else:
                result_lines.append(line)
                i += 1

        return '\n'.join(result_lines)

    def _fix_params_naming(self, code: str) -> str:
        """Fix naming conflict: var<uniform> Params: Params -> var<uniform> params: Params"""
        import re
        # Match the uniform declaration with uppercase Params variable name
        pattern = r'@group\(0\)\s*@binding\(0\)\s*var<uniform>\s+Params\s*:\s*Params'
        replacement = r'@group(0) @binding(0) var<uniform> params: Params'
        fixed = re.sub(pattern, replacement, code)

        # Also need to update all references from Params.field to params.field
        if fixed != code:
            # Replace uppercase Params references with lowercase params
            fixed = re.sub(r'\bParams\.', 'params.', fixed)
        return fixed

    def _fix_let_mutations(self, code: str) -> str:
        """Convert let to var where needed (inside functions, var is sufficient)."""
        return code.replace('let ', 'var ', 1)

    def _fix_var_function_syntax(self, code: str) -> str:
        """Fix var<function> to just var (address space is implicit inside functions)."""
        import re
        return re.sub(r'\bvar<function>\s*', 'var ', code)

    def _fix_mod_function(self, code: str) -> str:
        """Convert GLSL mod(x, y) to WGSL x % y operator.

        See HAIKU_ERROR_PATTERNS.md section 2: mod() Function
        """
        import re
        # Match mod(expr1, expr2) and replace with (expr1 % expr2)
        # Use parentheses to preserve operator precedence
        pattern = r'\bmod\s*\(\s*([^,]+)\s*,\s*([^)]+)\s*\)'
        return re.sub(pattern, r'(\1 % \2)', code)

    def _fix_reserved_keywords(self, code: str) -> str:
        """Rename WGSL reserved keywords by appending _var.

        See HAIKU_ERROR_PATTERNS.md section 3: Reserved Keywords
        """
        import re
        for keyword in self.RESERVED_KEYWORDS:
            # Match keyword as complete word (variable name)
            # Use word boundaries to avoid matching substrings
            pattern = r'\b' + keyword + r'\b'
            replacement = keyword + '_var'
            code = re.sub(pattern, replacement, code)
        return code

    def _fix_numeric_overflow(self, code: str) -> str:
        """Replace numeric literals > 1e38 with f32 max (3.4e38).

        See HAIKU_ERROR_PATTERNS.md section 1: Numeric Overflow
        """
        import re
        # Match scientific notation with large exponents
        # Pattern: number.numbereEXP where EXP > 38
        def replace_large(match):
            full_match = match.group(0)
            exp_str = match.group(1)
            exp = int(exp_str) if exp_str else 0
            if exp > 38:
                return "3.4e38"  # f32 max value
            return full_match

        # Match patterns like: 1.28e19729 or 5.49755813888e308
        pattern = r'\b\d+\.?\d*e\+?(\d+)\b'
        return re.sub(pattern, replace_large, code)

    def _fix_underscore_identifier(self, code: str) -> str:
        """Replace standalone _ identifier with _unused.

        See HAIKU_ERROR_PATTERNS.md section 5: Underscore Identifier
        """
        import re
        # Match "let _ =" or "var _ =" patterns
        # Use word boundaries to avoid matching valid identifiers like _foo
        pattern = r'\b(let|var(?:<[^>]+>)?)\s+_\s*='
        replacement = r'\1 _unused ='
        return re.sub(pattern, replacement, code)



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
            # Try markdown code blocks with language hints
            shader_code_pattern = r'```(?:wgsl|glsl|shadertoy|hlsl)\n(.*?)\n```'
            for i, content in enumerate(re.findall(shader_code_pattern, llm_response, re.DOTALL)):
                filename = f"shader_{i}{self.language_spec.file_extension}"
                shaders[filename] = content.strip()

        if not shaders:
            # Fallback: Try generic code blocks
            generic_code_pattern = r'```\n(.*?)\n```'
            for i, content in enumerate(re.findall(generic_code_pattern, llm_response, re.DOTALL)):
                # Only accept if it looks like shader code
                shader_keywords = ['mainImage', 'fs_main', 'vs_main', 'CGPROGRAM', 'SV_Target', 'Shader "']
                if any(keyword in content for keyword in shader_keywords):
                    filename = f"shader_{i}{self.language_spec.file_extension}"
                    shaders[filename] = content.strip()

        if not shaders:
            # Final fallback: bare shader source with no wrapper / no fence.
            # Some CLI agents (notably codex exec) strip ceremonial markdown
            # and just emit the shader code directly. If the response contains
            # the language's distinctive entrypoint markers, treat the whole
            # text as a single shader file.
            stripped = llm_response.strip()
            wgsl_markers = ('@vertex', '@fragment', 'fn fs_main', 'fn vs_main')
            if any(m in stripped for m in wgsl_markers):
                shaders[f"shader{self.language_spec.file_extension}"] = stripped

        if not shaders:
            raise ValueError("No shader files found")

        return shaders, main_rs
