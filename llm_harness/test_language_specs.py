#!/usr/bin/env python3
"""
Test suite for language_specs.py refactoring

Validates:
1. Language spec abstract interface
2. WGSL spec implementation
3. GLSL spec implementation
4. Backward compatibility with ShaderParser
5. Factory function (get_language_spec)

Run: python3 test_language_specs.py
"""

import sys
from pathlib import Path

# Ensure we can import from llm_harness directory
sys.path.insert(0, str(Path(__file__).parent))

from language_specs import (
    ShaderLanguageSpec,
    WGSLSpec,
    GLSLSpec,
    get_language_spec,
    SUPPORTED_LANGUAGES
)
from shader_parser import ShaderParser


def test_wgsl_spec():
    """Test WGSLSpec implementation"""
    print("\n=== Testing WGSLSpec ===")

    spec = WGSLSpec()

    # Test properties
    assert spec.name == "WGSL", f"Expected 'WGSL', got '{spec.name}'"
    assert spec.file_extension == ".wgsl", f"Expected '.wgsl', got '{spec.file_extension}'"
    assert spec.fallback_filename == "shader.wgsl", f"Expected 'shader.wgsl', got '{spec.fallback_filename}'"
    assert "WebGPU" in spec.description, f"Description should mention WebGPU"
    assert len(spec.constraint_prompt) > 100, "Constraint prompt should be substantial"

    # Test validation - valid WGSL
    valid_wgsl_1 = "@vertex fn vs_main() -> vec4<f32> {}"
    assert spec.validate_syntax(valid_wgsl_1), f"Should validate WGSL with @vertex"

    valid_wgsl_2 = "@fragment fn fs_main() -> vec4<f32> {}"
    assert spec.validate_syntax(valid_wgsl_2), f"Should validate WGSL with @fragment"

    valid_wgsl_3 = "fn helper() -> f32 { return 1.0; }"
    assert spec.validate_syntax(valid_wgsl_3), f"Should validate WGSL function"

    # Test validation - invalid WGSL (GLSL syntax)
    invalid_wgsl = "void main() { gl_FragColor = vec4(1.0); }"
    assert not spec.validate_syntax(invalid_wgsl), f"Should reject GLSL syntax"

    print("✓ WGSLSpec properties correct")
    print("✓ WGSLSpec validation working")


def test_glsl_spec():
    """Test GLSLSpec implementation"""
    print("\n=== Testing GLSLSpec ===")

    spec = GLSLSpec()

    # Test properties
    assert spec.name == "GLSL", f"Expected 'GLSL', got '{spec.name}'"
    assert spec.file_extension == ".glsl", f"Expected '.glsl', got '{spec.file_extension}'"
    assert spec.fallback_filename == "shader.glsl", f"Expected 'shader.glsl', got '{spec.fallback_filename}'"
    assert "OpenGL" in spec.description, f"Description should mention OpenGL"
    assert len(spec.constraint_prompt) > 100, "Constraint prompt should be substantial"

    # Test validation - valid GLSL
    valid_glsl_1 = "void main() { }"
    assert spec.validate_syntax(valid_glsl_1), f"Should validate GLSL main"

    valid_glsl_2 = "void mainImage(out vec4 fragColor, in vec2 fragCoord) { }"
    assert spec.validate_syntax(valid_glsl_2), f"Should validate Shadertoy mainImage"

    valid_glsl_3 = "void helper() { return; }"
    assert spec.validate_syntax(valid_glsl_3), f"Should validate GLSL function"

    # Test validation - invalid GLSL (WGSL syntax)
    invalid_glsl = "@fragment fn fs_main() -> vec4<f32> {}"
    assert not spec.validate_syntax(invalid_glsl), f"Should reject WGSL syntax"

    print("✓ GLSLSpec properties correct")
    print("✓ GLSLSpec validation working")


def test_factory_function():
    """Test get_language_spec factory function"""
    print("\n=== Testing get_language_spec() ===")

    # Test WGSL
    wgsl = get_language_spec('wgsl')
    assert isinstance(wgsl, WGSLSpec), "Should return WGSLSpec instance"

    wgsl_upper = get_language_spec('WGSL')
    assert isinstance(wgsl_upper, WGSLSpec), "Should be case-insensitive"

    # Test GLSL
    glsl = get_language_spec('glsl')
    assert isinstance(glsl, GLSLSpec), "Should return GLSLSpec instance"

    glsl_upper = get_language_spec('GLSL')
    assert isinstance(glsl_upper, GLSLSpec), "Should be case-insensitive"

    # Test invalid
    try:
        invalid = get_language_spec('invalid')
        assert False, "Should raise ValueError for unknown language"
    except ValueError as e:
        assert "Unknown language" in str(e), "Should have helpful error message"

    print("✓ Factory function working")
    print(f"✓ Supported languages: {SUPPORTED_LANGUAGES}")


def test_shader_parser_backward_compatibility():
    """Test ShaderParser backward compatibility (no language_spec)"""
    print("\n=== Testing ShaderParser Backward Compatibility ===")

    # Default parser (no language_spec) should use WGSL
    parser = ShaderParser()
    assert parser.language_spec.name == "WGSL", "Should default to WGSL"
    assert parser.language_spec.file_extension == ".wgsl", "Should use .wgsl extension"

    # Test WGSL validation
    wgsl_code = "@vertex fn vs_main() -> vec4<f32> {}"
    assert parser.validate_shader_syntax(wgsl_code), "Should validate WGSL"

    # Test parsing with XML format
    llm_response_xml = '''<shader file="test.wgsl">
@fragment
fn fs_main() -> vec4<f32> {
    return vec4<f32>(1.0, 0.0, 0.0, 1.0);
}
</shader>'''

    shaders, _ = parser.parse_response(llm_response_xml)
    assert "test.wgsl" in shaders, "Should parse XML shader block"
    assert "@fragment" in shaders["test.wgsl"], "Should preserve shader content"

    # Test parsing with code block format (fallback)
    llm_response_code = '''```wgsl
@vertex
fn vs_main() -> vec4<f32> {
    return vec4<f32>(0.0, 0.0, 0.0, 1.0);
}
```'''

    shaders, _ = parser.parse_response(llm_response_code)
    assert len(shaders) == 1, "Should parse code block"
    filename = list(shaders.keys())[0]
    assert filename.endswith(".wgsl"), "Should use .wgsl extension for fallback"

    print("✓ ShaderParser defaults to WGSL")
    print("✓ XML parsing works")
    print("✓ Code block parsing works")
    print("✓ Backward compatibility: PASSED")


def test_shader_parser_with_glsl():
    """Test ShaderParser with GLSLSpec"""
    print("\n=== Testing ShaderParser with GLSLSpec ===")

    parser = ShaderParser(language_spec=GLSLSpec())
    assert parser.language_spec.name == "GLSL", "Should use GLSL spec"

    # Test GLSL validation
    glsl_code = "void main() { gl_FragColor = vec4(1.0); }"
    assert parser.validate_shader_syntax(glsl_code), "Should validate GLSL"

    # Test parsing with code block format - should use .glsl extension
    llm_response_code = '''```glsl
void main() {
    gl_FragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
```'''

    shaders, _ = parser.parse_response(llm_response_code)
    assert len(shaders) == 1, "Should parse code block"
    filename = list(shaders.keys())[0]
    assert filename.endswith(".glsl"), "Should use .glsl extension for GLSL spec"

    print("✓ ShaderParser uses GLSL spec correctly")
    print("✓ GLSL validation works")
    print("✓ GLSL file extension applied")


def test_reference_examples():
    """Test reference example loading"""
    print("\n=== Testing Reference Examples ===")

    shader_harness_path = Path(__file__).parent.parent / "shader_harness"

    if shader_harness_path.exists():
        # Test WGSL examples
        wgsl_spec = WGSLSpec()
        wgsl_examples = wgsl_spec.get_reference_examples(str(shader_harness_path))
        print(f"✓ WGSL loaded {len(wgsl_examples)} reference examples")

        # Test GLSL examples
        glsl_spec = GLSLSpec()
        glsl_examples = glsl_spec.get_reference_examples(str(shader_harness_path))
        print(f"✓ GLSL loaded {len(glsl_examples)} reference examples")
    else:
        print("⚠ shader_harness not found, skipping reference example test")


def main():
    """Run all tests"""
    print("=" * 60)
    print("Language Specification Architecture - Test Suite")
    print("=" * 60)

    tests = [
        test_wgsl_spec,
        test_glsl_spec,
        test_factory_function,
        test_shader_parser_backward_compatibility,
        test_shader_parser_with_glsl,
        test_reference_examples,
    ]

    failed = 0
    for test in tests:
        try:
            test()
        except Exception as e:
            print(f"\n✗ {test.__name__} FAILED: {e}")
            import traceback
            traceback.print_exc()
            failed += 1

    print("\n" + "=" * 60)
    if failed == 0:
        print("✓ ALL TESTS PASSED")
        print("=" * 60)
        print("\nRefactoring Summary:")
        print("- Language specification abstraction created")
        print("- WGSL and GLSL specs implemented")
        print("- ShaderParser refactored for spec-based parsing")
        print("- Backward compatibility maintained (defaults to WGSL)")
        print("- Ready for ablation experiments")
        return 0
    else:
        print(f"✗ {failed} TEST(S) FAILED")
        print("=" * 60)
        return 1


if __name__ == "__main__":
    sys.exit(main())
