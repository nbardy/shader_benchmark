import re
import xml.etree.ElementTree as ET
from typing import Dict, Tuple, List, Optional, NamedTuple
from language_specs import ShaderLanguageSpec, WGSLSpec

class LintError(NamedTuple):
    """Represents a linting error found in shader code."""
    error_type: str
    message: str
    line_num: int
    location: str  # Brief description of where error was found


class WGSLLinter:
    """Detects common WGSL compilation issues."""

    def lint(self, shader_content: str) -> List[LintError]:
        """Detect all compilation issues in the shader code.

        Returns:
            List of LintError objects describing all detected issues.
        """
        errors = []
        lines = shader_content.split('\n')

        # Check for duplicate Params struct definitions
        errors.extend(self._check_duplicate_params(shader_content, lines))

        # Check for let binding mutations
        errors.extend(self._check_let_mutations(shader_content, lines))

        # Check for duplicate @group/@binding declarations
        errors.extend(self._check_duplicate_bindings(shader_content, lines))

        # Check for select() function signature errors
        errors.extend(self._check_select_signatures(shader_content, lines))

        # Check for numeric literal violations
        errors.extend(self._check_numeric_literals(shader_content, lines))

        return errors

    def _check_duplicate_params(self, shader_content: str, lines: List[str]) -> List[LintError]:
        """Check for duplicate Params struct definitions."""
        errors = []

        # Find all struct Params definitions
        struct_pattern = r'struct\s+Params\s*\{'
        matches = list(re.finditer(struct_pattern, shader_content))

        if len(matches) > 1:
            # Mark duplicates (all but first)
            for i, match in enumerate(matches[1:], start=1):
                line_num = shader_content[:match.start()].count('\n') + 1
                errors.append(LintError(
                    error_type="duplicate_params",
                    message=f"Duplicate Params struct definition #{i+1}",
                    line_num=line_num,
                    location=f"struct Params definition at line {line_num}"
                ))

        return errors

    def _check_let_mutations(self, shader_content: str, lines: List[str]) -> List[LintError]:
        """Check for mutations of let bindings (should be var<function>)."""
        errors = []

        # Find all let bindings
        let_pattern = r'let\s+(\w+)\s*:'
        let_matches = list(re.finditer(let_pattern, shader_content))

        for let_match in let_matches:
            var_name = let_match.group(1)
            line_num = shader_content[:let_match.start()].count('\n') + 1

            # Look for assignments to this variable after its declaration
            # Pattern: var_name followed by = or +=, -=, etc.
            mutation_pattern = rf'\b{re.escape(var_name)}\s*(?:\+=|-=|\*=|/=|=)'

            # Search only after the let declaration
            search_start = let_match.end()
            remaining_code = shader_content[search_start:]

            mutation_match = re.search(mutation_pattern, remaining_code)
            if mutation_match:
                mutation_line = line_num + remaining_code[:mutation_match.start()].count('\n')
                errors.append(LintError(
                    error_type="let_mutation",
                    message=f"Let binding '{var_name}' is mutated (should use var<function>)",
                    line_num=mutation_line,
                    location=f"let binding '{var_name}' declared at line {line_num}, mutated at line {mutation_line}"
                ))

        return errors

    def _check_duplicate_bindings(self, shader_content: str, lines: List[str]) -> List[LintError]:
        """Check for duplicate @group/@binding declarations."""
        errors = []

        # Find all @binding declarations
        binding_pattern = r'@group\((\d+)\)\s*@binding\((\d+)\)'
        matches = list(re.finditer(binding_pattern, shader_content))

        # Track seen bindings
        seen = {}
        for match in matches:
            group = match.group(1)
            binding = match.group(2)
            key = (group, binding)
            line_num = shader_content[:match.start()].count('\n') + 1

            if key in seen:
                errors.append(LintError(
                    error_type="duplicate_binding",
                    message=f"Duplicate @group({group}) @binding({binding})",
                    line_num=line_num,
                    location=f"@group({group}) @binding({binding}) at line {line_num}"
                ))
            else:
                seen[key] = line_num

        return errors

    def _check_select_signatures(self, shader_content: str, lines: List[str]) -> List[LintError]:
        """Check for select() function with wrong number of arguments."""
        errors = []

        # Find select() calls - simple pattern for common cases
        # This is a heuristic and may have false positives/negatives
        select_pattern = r'select\s*\([^)]+\)'
        matches = list(re.finditer(select_pattern, shader_content))

        for match in matches:
            call_content = match.group(0)
            # Count commas to estimate argument count
            comma_count = call_content.count(',')
            arg_count = comma_count + 1  # Arguments = commas + 1

            if arg_count != 3:
                line_num = shader_content[:match.start()].count('\n') + 1
                errors.append(LintError(
                    error_type="select_signature",
                    message=f"select() requires 3 arguments, found {arg_count}",
                    line_num=line_num,
                    location=f"select() call at line {line_num}: {call_content[:50]}"
                ))

        return errors

    def _check_numeric_literals(self, shader_content: str, lines: List[str]) -> List[LintError]:
        """Check for numeric literals outside valid f32 range."""
        errors = []

        # Find f32 scientific notation literals
        # Pattern: digits followed by . or e/E
        sci_pattern = r'(\d+\.?\d*)[eE]([+-]?\d+)'
        matches = list(re.finditer(sci_pattern, shader_content))

        for match in matches:
            mantissa_str = match.group(1)
            exponent_str = match.group(2)

            try:
                exponent = int(exponent_str)
                # f32 valid exponent range is approximately ±38
                if abs(exponent) > 38:
                    line_num = shader_content[:match.start()].count('\n') + 1
                    errors.append(LintError(
                        error_type="numeric_overflow",
                        message=f"Numeric literal exponent {exponent_str} outside f32 range (±38)",
                        line_num=line_num,
                        location=f"Literal {match.group(0)} at line {line_num}"
                    ))
            except ValueError:
                pass  # Skip if exponent can't be parsed

        return errors


class WGSLRepair:
    """Repairs common WGSL compilation issues."""

    def repair_all(self, shader_content: str, errors: List[LintError]) -> Tuple[str, Dict[str, int]]:
        """Apply repairs for all detected errors.

        Returns:
            Tuple of (repaired_code, repairs_applied) where repairs_applied
            maps error_type to count of repairs made.
        """
        repaired = shader_content
        repairs = {}

        # Group errors by type and apply repairs
        for error_type in set(e.error_type for e in errors):
            error_list = [e for e in errors if e.error_type == error_type]

            if error_type == "duplicate_params":
                repaired, count = self._repair_duplicate_params(repaired)
                repairs["duplicate_params"] = count

            elif error_type == "let_mutation":
                repaired, count = self._repair_let_mutations(repaired, error_list)
                repairs["let_mutation"] = count

            elif error_type == "duplicate_binding":
                repaired, count = self._repair_duplicate_bindings(repaired)
                repairs["duplicate_binding"] = count

            elif error_type == "numeric_overflow":
                repaired, count = self._repair_numeric_overflow(repaired, error_list)
                repairs["numeric_overflow"] = count

        return repaired, repairs

    def _repair_duplicate_params(self, shader_content: str) -> Tuple[str, int]:
        """Remove all but the first Params struct definition."""
        # Find all struct Params definitions
        struct_pattern = r'struct\s+Params\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
        struct_matches = list(re.finditer(struct_pattern, shader_content, re.DOTALL))

        if len(struct_matches) <= 1:
            return shader_content, 0

        # Remove all but the first, working backwards
        repaired = shader_content
        removed_count = 0

        for match in reversed(struct_matches[1:]):
            start = match.start()
            end = match.end()

            # Extend end to include trailing whitespace/newlines
            while end < len(repaired) and repaired[end] in ' \t\n':
                end += 1

            # Find line start
            line_start = repaired.rfind('\n', 0, start)
            if line_start == -1:
                line_start = 0
            else:
                line_start += 1

            # Only remove from line_start if there's only whitespace before struct
            if repaired[line_start:start].strip() == '':
                start = line_start

            repaired = repaired[:start] + repaired[end:]
            removed_count += 1

        return repaired, removed_count

    def _repair_let_mutations(self, shader_content: str, errors: List[LintError]) -> Tuple[str, int]:
        """Convert let bindings that are mutated to var<function>."""
        repaired = shader_content
        repair_count = 0

        # Find all let bindings that need to be converted
        let_pattern = r'let\s+(\w+)\s*:'
        let_matches = list(re.finditer(let_pattern, shader_content))

        # Work backwards to maintain positions
        for match in reversed(let_matches):
            var_name = match.group(1)

            # Check if this variable is mutated later
            search_start = match.end()
            remaining = shader_content[search_start:]

            mutation_pattern = rf'\b{re.escape(var_name)}\s*(?:\+=|-=|\*=|/=|=)'
            if re.search(mutation_pattern, remaining):
                # Replace 'let' with 'var<function>'
                repaired = repaired[:match.start()] + 'var<function>' + repaired[match.end():]
                # Adjust positions for future iterations
                shader_content = repaired
                repair_count += 1

        return repaired, repair_count

    def _repair_duplicate_bindings(self, shader_content: str) -> Tuple[str, int]:
        """Remove duplicate @group/@binding declarations and their associated variables."""
        binding_pattern = r'@group\((\d+)\)\s*@binding\((\d+)\)\s*var\s+\w+\s*:\s*[^;]+;'
        matches = list(re.finditer(binding_pattern, shader_content, re.DOTALL))

        if len(matches) <= 1:
            return shader_content, 0

        # Track first occurrence of each binding
        seen = {}
        repaired = shader_content
        removed_count = 0

        for match in reversed(matches):
            group = match.group(1)
            binding = match.group(2)
            key = (group, binding)

            if key not in seen:
                seen[key] = True
            else:
                # Remove this duplicate binding
                start = match.start()
                end = match.end()

                # Extend to include trailing newline
                while end < len(repaired) and repaired[end] in ' \t\n':
                    end += 1

                repaired = repaired[:start] + repaired[end:]
                removed_count += 1

        return repaired, removed_count

    def _repair_numeric_overflow(self, shader_content: str, errors: List[LintError]) -> Tuple[str, int]:
        """Clamp numeric literals to valid f32 range."""
        repaired = shader_content
        repair_count = 0

        # Find scientific notation literals and repair them
        sci_pattern = r'(\d+\.?\d*)[eE]([+-]?\d+)'
        matches = list(re.finditer(sci_pattern, shader_content))

        for match in reversed(matches):
            try:
                exponent = int(match.group(2))
                if abs(exponent) > 38:
                    # Replace with a clamped value
                    mantissa = match.group(1)
                    clamped_exp = 38 if exponent > 38 else -38
                    replacement = f"{mantissa}e{clamped_exp}"

                    repaired = repaired[:match.start()] + replacement + repaired[match.end():]
                    repair_count += 1
            except ValueError:
                pass

        return repaired, repair_count


class ShaderParser:
    def __init__(self, language_spec: Optional[ShaderLanguageSpec] = None):
        """Initialize parser with language specification.

        Args:
            language_spec: Language specification defining syntax rules and validation.
                          Defaults to WGSLSpec() for backward compatibility.
        """
        self.language_spec = language_spec or WGSLSpec()
    
    def parse_response(self, llm_response: str) -> Tuple[Dict[str, str], str]:
        """Parse LLM response to extract shader files (language-agnostic).

        Uses language_spec to determine file extension and valid code block formats.
        Supports both XML blocks and markdown code blocks.

        NOTE: main.rs is not used in current pipeline (harness is fixed).

        Returns:
            Tuple of (shaders_dict, main_rs_str)
        """
        shaders = {}
        main_rs = ""  # Not used in current pipeline

        # Parse XML blocks for shader files
        shader_pattern = r'<shader\s+file="([^"]+)">(.*?)</shader>'
        shader_matches = re.findall(shader_pattern, llm_response, re.DOTALL)

        for filename, content in shader_matches:
            shaders[filename] = content.strip()

        if not shaders:
            # Fallback: try to extract shader files from code blocks
            # Support both wgsl and glsl code blocks
            shader_code_pattern = r'```(?:wgsl|glsl)\n(.*?)\n```'
            shader_matches = re.findall(shader_code_pattern, llm_response, re.DOTALL)

            for i, shader_content in enumerate(shader_matches):
                # Use language_spec to determine file extension
                filename = f"shader_{i}{self.language_spec.file_extension}"
                shaders[filename] = shader_content.strip()

        if not shaders:
            raise ValueError("No shader files found in LLM response")

        return shaders, main_rs

    def validate_shader_syntax(self, shader_content: str) -> bool:
        """Validate shader syntax using language_spec validator.

        Delegates to language_spec.validate_syntax() for language-specific validation.
        This enables clean separation between parsing logic and language rules.

        Args:
            shader_content: Shader source code to validate

        Returns:
            True if syntax appears valid per language_spec rules
        """
        return self.language_spec.validate_syntax(shader_content)
    
    def validate_main_rs_syntax(self, main_rs_content: str) -> bool:
        """Basic validation of main.rs syntax"""
        required_patterns = [
            r'fn main\(',  # main function
            r'use\s+\w+',  # use statements
        ]

        for pattern in required_patterns:
            if not re.search(pattern, main_rs_content):
                return False

        return True

    def cleanup_wgsl_shader(self, shader_content: str) -> str:
        """Clean up WGSL shader code to fix common LLM-generated issues.

        Fixes:
        - Removes duplicate struct Params definitions (keeps first, removes rest)
        - Maintains struct order relative to binding declaration

        Args:
            shader_content: Raw WGSL shader code from LLM

        Returns:
            Cleaned shader code
        """
        # Find all struct Params definitions using a more robust pattern
        # This handles nested braces using a balanced brace matching approach
        struct_pattern = r'struct\s+Params\s*\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
        struct_matches = list(re.finditer(struct_pattern, shader_content, re.DOTALL))

        if len(struct_matches) <= 1:
            # No duplicates, return as-is
            return shader_content

        # Remove all but the first struct Params definition
        # Work backwards through matches to maintain character positions
        cleaned = shader_content
        for match in reversed(struct_matches[1:]):
            # Get the match bounds
            start = match.start()
            end = match.end()

            # Clean up trailing whitespace/newlines after the struct
            while end < len(cleaned) and cleaned[end] in ' \t\n':
                end += 1

            # Also clean up leading whitespace at the beginning of the line
            line_start = cleaned.rfind('\n', 0, start)
            if line_start == -1:
                line_start = 0
            else:
                line_start += 1  # Move past the newline

            # Only remove from line_start if there's only whitespace before struct
            if cleaned[line_start:start].strip() == '':
                start = line_start

            # Remove the duplicate struct definition
            cleaned = cleaned[:start] + cleaned[end:]

        return cleaned