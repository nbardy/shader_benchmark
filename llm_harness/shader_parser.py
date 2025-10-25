import re
import xml.etree.ElementTree as ET
from typing import Dict, Tuple, List, Optional
from language_specs import ShaderLanguageSpec, WGSLSpec

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
        # Find all struct Params definitions
        struct_pattern = r'struct\s+Params\s*\{[^}]*\}'
        struct_matches = list(re.finditer(struct_pattern, shader_content))

        if len(struct_matches) <= 1:
            # No duplicates, return as-is
            return shader_content

        # Remove all but the first struct Params definition
        # Work backwards to maintain character positions
        cleaned = shader_content
        for match in reversed(struct_matches[1:]):
            # Remove the duplicate definition and surrounding whitespace
            start = match.start()
            end = match.end()

            # Check for trailing newline/semicolon and remove if present
            if end < len(cleaned) and cleaned[end] in '\n;':
                end += 1

            # Also clean up leading whitespace on the line
            line_start = cleaned.rfind('\n', 0, start) + 1
            if cleaned[line_start:start].strip() == '':
                start = line_start

            cleaned = cleaned[:start] + cleaned[end:]

        return cleaned