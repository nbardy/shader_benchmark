import re
import xml.etree.ElementTree as ET
from typing import Dict, Tuple, List

class ShaderParser:
    def __init__(self):
        pass
    
    def parse_response(self, llm_response: str) -> Tuple[Dict[str, str], str]:
        """Parse LLM response to extract shader files and main.rs content"""
        shaders = {}
        main_rs = ""
        
        # Parse XML blocks for shader files
        shader_pattern = r'<shader\s+file="([^"]+)">(.*?)</shader>'
        shader_matches = re.findall(shader_pattern, llm_response, re.DOTALL)
        
        for filename, content in shader_matches:
            shaders[filename] = content.strip()
        
        # Parse main.rs content
        main_rs_pattern = r'<main_rs>(.*?)</main_rs>'
        main_rs_match = re.search(main_rs_pattern, llm_response, re.DOTALL)
        
        if main_rs_match:
            main_rs = main_rs_match.group(1).strip()
        else:
            # Fallback: try to find code blocks that might be main.rs
            rust_code_pattern = r'```rust\n(.*?)\n```'
            rust_matches = re.findall(rust_code_pattern, llm_response, re.DOTALL)
            if rust_matches:
                # Take the longest rust code block as main.rs
                main_rs = max(rust_matches, key=len).strip()
        
        if not main_rs:
            raise ValueError("No main.rs content found in LLM response")
        
        if not shaders:
            # Try to extract shader files from code blocks
            shader_code_pattern = r'```(?:wgsl|glsl)\n(.*?)\n```'
            shader_matches = re.findall(shader_code_pattern, llm_response, re.DOTALL)
            
            for i, shader_content in enumerate(shader_matches):
                filename = f"shader_{i}.wgsl"
                shaders[filename] = shader_content.strip()
        
        if not shaders:
            raise ValueError("No shader files found in LLM response")
        
        return shaders, main_rs
    
    def validate_shader_syntax(self, shader_content: str) -> bool:
        """Basic validation of shader syntax"""
        # Check for basic WGSL structure
        if '@vertex' in shader_content or '@fragment' in shader_content or '@compute' in shader_content:
            return True
        
        # Check for basic function definitions
        if 'fn ' in shader_content:
            return True
        
        return False
    
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