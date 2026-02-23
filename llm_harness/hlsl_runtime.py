"""
HLSL Runtime - Compile and execute Unity HLSL shaders on macOS using Metal backend

COMPILATION PIPELINE:
  1. Extract HLSL fragment shader from Unity shader structure
  2. HLSL -> DXC (DirectX Shader Compiler) -> SPIR-V
  3. SPIR-V -> spirv-cross -> Metal Shading Language (.metal)
  4. Execute Metal shader via Swift/Metal harness
  5. Save 1600x1600 PNG output

ARCHITECTURE:
  - Unity HLSL uses CGPROGRAM blocks with custom built-ins (UnityCG.cginc)
  - We extract the fragment shader and provide stub implementations for Unity built-ins
  - DXC compiles to SPIR-V intermediate representation
  - spirv-cross translates SPIR-V to Metal Shading Language
  - Metal framework executes the shader natively on macOS

DEPENDENCIES:
  - DXC (DirectX Shader Compiler): brew install directx-shader-compiler
  - spirv-cross: brew install spirv-cross
  - Metal framework (built into macOS)
  - Swift compiler (built into macOS Xcode Command Line Tools)

LIMITATIONS:
  - Multi-pass rendering: Not yet implemented (Unity RenderTexture equivalents)
  - Unity built-ins: Stub implementations provided (UnityObjectToClipPos, TRANSFORM_TEX, etc.)
  - Properties: Converted to uniform buffers
"""

import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import Tuple, Optional


class HLSLRuntime:
    """Runtime for compiling and executing Unity HLSL shaders via DXC -> SPIR-V -> Metal."""

    def __init__(self):
        # Verify toolchain availability
        self.dxc_path = self._find_dxc()
        self.spirv_cross_path = self._find_spirv_cross()

    def _find_dxc(self) -> str:
        """Locate DXC compiler (DirectX Shader Compiler)."""
        # Try brew installation path first
        brew_dxc = "/opt/homebrew/bin/dxc"
        if os.path.exists(brew_dxc):
            return brew_dxc

        # Try which dxc
        result = subprocess.run(["which", "dxc"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()

        raise FileNotFoundError(
            "DXC (DirectX Shader Compiler) not found. Install with: brew install directx-shader-compiler"
        )

    def _find_spirv_cross(self) -> str:
        """Locate spirv-cross compiler."""
        # Try brew installation path first
        brew_spirv = "/opt/homebrew/bin/spirv-cross"
        if os.path.exists(brew_spirv):
            return brew_spirv

        # Try which spirv-cross
        result = subprocess.run(["which", "spirv-cross"], capture_output=True, text=True)
        if result.returncode == 0:
            return result.stdout.strip()

        raise FileNotFoundError(
            "spirv-cross not found. Install with: brew install spirv-cross"
        )

    def extract_hlsl_fragment(self, unity_shader: str) -> Tuple[str, dict]:
        """Extract fragment shader HLSL code from Unity shader structure.

        Args:
            unity_shader: Full Unity shader code with Shader/Properties/SubShader/Pass structure

        Returns:
            Tuple of (fragment_hlsl_code, properties_dict)
        """
        # Extract Properties block
        properties = self._extract_properties(unity_shader)

        # Extract CGPROGRAM block content
        cgprogram_pattern = r'CGPROGRAM\s*(.*?)\s*ENDCG'
        match = re.search(cgprogram_pattern, unity_shader, re.DOTALL)

        if not match:
            raise ValueError("No CGPROGRAM block found in Unity shader")

        hlsl_code = match.group(1)

        # Extract fragment shader function
        # Look for function with SV_Target semantic
        frag_pattern = r'(float4|half4)\s+(\w+)\s*\([^)]*\)\s*:\s*SV_Target\s*\{[^}]*\}'
        frag_match = re.search(frag_pattern, hlsl_code, re.DOTALL)

        if not frag_match:
            raise ValueError("No fragment shader function with SV_Target found")

        return hlsl_code, properties

    def _extract_properties(self, unity_shader: str) -> dict:
        """Extract Properties block from Unity shader.

        Args:
            unity_shader: Full Unity shader code

        Returns:
            Dictionary of property names to default values
        """
        properties = {}
        props_pattern = r'Properties\s*\{(.*?)\}'
        match = re.search(props_pattern, unity_shader, re.DOTALL)

        if not match:
            return properties

        props_content = match.group(1)

        # Parse property declarations
        # Format: _Name ("Display Name", Type) = default_value
        prop_pattern = r'(\w+)\s*\([^)]*,\s*(\w+)\)\s*=\s*([^;\n]+)'
        for prop_match in re.finditer(prop_pattern, props_content):
            prop_name = prop_match.group(1)
            prop_type = prop_match.group(2)
            prop_default = prop_match.group(3).strip()
            properties[prop_name] = {'type': prop_type, 'default': prop_default}

        return properties

    def create_standalone_hlsl(self, hlsl_code: str, properties: dict) -> str:
        """Create standalone HLSL fragment shader from Unity shader code.

        Adds Unity built-in stubs and converts to DXC-compatible format.

        Args:
            hlsl_code: Extracted HLSL code from CGPROGRAM block
            properties: Properties dictionary

        Returns:
            Standalone HLSL fragment shader code
        """
        # Remove Unity-specific includes
        hlsl_code = re.sub(r'#include\s+"UnityCG\.cginc"', '', hlsl_code)
        hlsl_code = re.sub(r'#include\s+".*?"', '', hlsl_code)

        # Create Unity built-in stubs
        unity_stubs = """
// Unity Built-in Stubs for DXC compilation

// Unity built-in variables
cbuffer UnityPerFrame : register(b0) {
    float4 _Time;              // (t/20, t, t*2, t*3)
    float4 _SinTime;           // (t/8, t/4, t/2, t)
    float4 _CosTime;           // (t/8, t/4, t/2, t)
    float4 _ScreenParams;      // (width, height, 1+1/width, 1+1/height)
    float3 _WorldSpaceCameraPos;
    float4 unity_OrthoParams;
};

// Unity built-in functions
float4 UnityObjectToClipPos(float4 vertex) {
    // Simple orthographic projection for 2D shaders
    return float4(vertex.xy * 2.0 - 1.0, 0.5, 1.0);
}

float4 UnityObjectToWorldPos(float4 vertex) {
    return vertex;
}

float4 UnityWorldToClipPos(float4 vertex) {
    return UnityObjectToClipPos(vertex);
}

float2 TRANSFORM_TEX(float2 uv, sampler2D tex) {
    // Simplified - no texture transform for now
    return uv;
}

float4 tex2D(sampler2D samp, float2 uv) {
    // DXC uses texture/sampler separately, so we stub this
    return float4(0, 0, 0, 1);
}
"""

        # Combine stubs + extracted code
        standalone = unity_stubs + "\n\n" + hlsl_code

        return standalone

    def compile_hlsl_to_spirv(self, hlsl_code: str, output_spirv: Path) -> Tuple[bool, str]:
        """Compile HLSL to SPIR-V using DXC.

        Args:
            hlsl_code: HLSL fragment shader code
            output_spirv: Path to output SPIR-V file

        Returns:
            Tuple of (success: bool, error_message: str)
        """
        with tempfile.NamedTemporaryFile(mode='w', suffix='.hlsl', delete=False) as tmp_hlsl:
            tmp_hlsl.write(hlsl_code)
            tmp_hlsl_path = tmp_hlsl.name

        try:
            # DXC compilation command
            # -T ps_6_0: Pixel shader model 6.0
            # -E frag: Entry point function name
            # -spirv: Output SPIR-V format
            # -fspv-target-env=vulkan1.1: Target Vulkan 1.1 SPIR-V
            cmd = [
                self.dxc_path,
                "-T", "ps_6_0",
                "-E", "frag",
                "-spirv",
                "-fspv-target-env=vulkan1.1",
                "-Fo", str(output_spirv),
                tmp_hlsl_path
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

            if result.returncode != 0:
                error_msg = f"DXC compilation failed:\n{result.stderr}"
                return False, error_msg

            return True, ""

        finally:
            # Clean up temporary HLSL file
            if os.path.exists(tmp_hlsl_path):
                os.unlink(tmp_hlsl_path)

    def compile_spirv_to_metal(self, spirv_path: Path, output_metal: Path) -> Tuple[bool, str]:
        """Compile SPIR-V to Metal Shading Language using spirv-cross.

        Args:
            spirv_path: Path to input SPIR-V file
            output_metal: Path to output .metal file

        Returns:
            Tuple of (success: bool, error_message: str)
        """
        cmd = [
            self.spirv_cross_path,
            str(spirv_path),
            "--output", str(output_metal),
            "--msl"  # Metal Shading Language backend
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        if result.returncode != 0:
            error_msg = f"spirv-cross compilation failed:\n{result.stderr}"
            return False, error_msg

        return True, ""

    def create_metal_harness(self, metal_shader_path: Path, output_png: Path, width: int = 1600, height: int = 1600) -> str:
        """Create Swift/Metal harness to execute Metal shader and save PNG.

        Args:
            metal_shader_path: Path to .metal shader file
            output_png: Path to output PNG file
            width: Output width in pixels
            height: Output height in pixels

        Returns:
            Swift source code for Metal harness
        """
        swift_code = f"""
import Foundation
import Metal
import MetalKit
import CoreGraphics

// Load Metal device
guard let device = MTLCreateSystemDefaultDevice() else {{
    print("Metal is not supported on this device")
    exit(1)
}}

// Load shader library from .metal file
let shaderPath = "{metal_shader_path}"
let shaderSource = try String(contentsOfFile: shaderPath, encoding: .utf8)

let library: MTLLibrary
do {{
    library = try device.makeLibrary(source: shaderSource, options: nil)
}} catch {{
    print("Failed to compile Metal shader: \\(error)")
    exit(1)
}}

// Get fragment function (assuming entry point is "frag" or "main0")
guard let fragmentFunction = library.makeFunction(name: "frag") ?? library.makeFunction(name: "main0") else {{
    print("Fragment function not found in Metal library")
    exit(1)
}}

// Create render pipeline
let pipelineDescriptor = MTLRenderPipelineDescriptor()
pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba8Unorm
pipelineDescriptor.fragmentFunction = fragmentFunction

// Create simple vertex function (fullscreen quad)
let vertexFunctionSource = \"""
#include <metal_stdlib>
using namespace metal;

struct VertexOut {{
    float4 position [[position]];
    float2 uv;
}};

vertex VertexOut vertex_main(uint vid [[vertex_id]]) {{
    VertexOut out;
    float2 positions[6] = {{
        float2(-1, -1), float2(1, -1), float2(-1, 1),
        float2(-1, 1), float2(1, -1), float2(1, 1)
    }};
    float2 uvs[6] = {{
        float2(0, 1), float2(1, 1), float2(0, 0),
        float2(0, 0), float2(1, 1), float2(1, 0)
    }};
    out.position = float4(positions[vid], 0, 1);
    out.uv = uvs[vid];
    return out;
}}
\"""

let vertexLibrary = try device.makeLibrary(source: vertexFunctionSource, options: nil)
let vertexFunction = vertexLibrary.makeFunction(name: "vertex_main")!
pipelineDescriptor.vertexFunction = vertexFunction

let pipelineState: MTLRenderPipelineState
do {{
    pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
}} catch {{
    print("Failed to create pipeline state: \\(error)")
    exit(1)
}}

// Create texture to render into
let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
    pixelFormat: .rgba8Unorm,
    width: {width},
    height: {height},
    mipmapped: false
)
textureDescriptor.usage = [.renderTarget, .shaderRead]
guard let texture = device.makeTexture(descriptor: textureDescriptor) else {{
    print("Failed to create texture")
    exit(1)
}}

// Create command queue and buffer
guard let commandQueue = device.makeCommandQueue(),
      let commandBuffer = commandQueue.makeCommandBuffer() else {{
    print("Failed to create command queue/buffer")
    exit(1)
}}

// Create render pass descriptor
let renderPassDescriptor = MTLRenderPassDescriptor()
renderPassDescriptor.colorAttachments[0].texture = texture
renderPassDescriptor.colorAttachments[0].loadAction = .clear
renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
renderPassDescriptor.colorAttachments[0].storeAction = .store

// Encode render commands
guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {{
    print("Failed to create render encoder")
    exit(1)
}}

renderEncoder.setRenderPipelineState(pipelineState)
renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
renderEncoder.endEncoding()

// Commit and wait
commandBuffer.commit()
commandBuffer.waitUntilCompleted()

// Read back texture data
let bytesPerPixel = 4
let bytesPerRow = {width} * bytesPerPixel
let imageByteCount = {height} * bytesPerRow
var imageBytes = [UInt8](repeating: 0, count: imageByteCount)

texture.getBytes(&imageBytes, bytesPerRow: bytesPerRow, from: MTLRegionMake2D(0, 0, {width}, {height}), mipmapLevel: 0)

// Create CGImage and save as PNG
let colorSpace = CGColorSpaceCreateDeviceRGB()
let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

guard let context = CGContext(
    data: &imageBytes,
    width: {width},
    height: {height},
    bitsPerComponent: 8,
    bytesPerRow: bytesPerRow,
    space: colorSpace,
    bitmapInfo: bitmapInfo.rawValue
) else {{
    print("Failed to create CGContext")
    exit(1)
}}

guard let cgImage = context.makeImage() else {{
    print("Failed to create CGImage")
    exit(1)
}}

// Save PNG
let outputURL = URL(fileURLWithPath: "{output_png}")
guard let destination = CGImageDestinationCreateWithURL(outputURL as CFURL, kUTTypePNG, 1, nil) else {{
    print("Failed to create image destination")
    exit(1)
}}

CGImageDestinationAddImage(destination, cgImage, nil)
if CGImageDestinationFinalize(destination) {{
    print("Successfully saved PNG to {output_png}")
}} else {{
    print("Failed to save PNG")
    exit(1)
}}
"""
        return swift_code

    def execute_metal_shader(self, metal_shader_path: Path, output_png: Path, width: int = 1600, height: int = 1600) -> Tuple[bool, str]:
        """Execute Metal shader and save PNG output.

        Args:
            metal_shader_path: Path to .metal shader file
            output_png: Path to output PNG file
            width: Output width
            height: Output height

        Returns:
            Tuple of (success: bool, error_message: str)
        """
        # Create Swift harness
        swift_code = self.create_metal_harness(metal_shader_path, output_png, width, height)

        with tempfile.NamedTemporaryFile(mode='w', suffix='.swift', delete=False) as tmp_swift:
            tmp_swift.write(swift_code)
            tmp_swift_path = tmp_swift.name

        try:
            # Compile and execute Swift program
            # swiftc compiles to executable
            executable_path = tmp_swift_path.replace('.swift', '')

            compile_cmd = [
                'swiftc',
                '-o', executable_path,
                '-framework', 'Metal',
                '-framework', 'MetalKit',
                '-framework', 'CoreGraphics',
                '-framework', 'Foundation',
                tmp_swift_path
            ]

            compile_result = subprocess.run(compile_cmd, capture_output=True, text=True, timeout=60)

            if compile_result.returncode != 0:
                error_msg = f"Swift compilation failed:\n{compile_result.stderr}"
                return False, error_msg

            # Execute compiled program
            run_result = subprocess.run([executable_path], capture_output=True, text=True, timeout=30)

            if run_result.returncode != 0:
                error_msg = f"Metal shader execution failed:\n{run_result.stderr}"
                return False, error_msg

            if not output_png.exists():
                return False, f"PNG output not generated at {output_png}"

            return True, ""

        finally:
            # Clean up temporary files
            if os.path.exists(tmp_swift_path):
                os.unlink(tmp_swift_path)
            executable = tmp_swift_path.replace('.swift', '')
            if os.path.exists(executable):
                os.unlink(executable)

    def compile_and_execute(self, unity_shader: str, output_png: Path, width: int = 1600, height: int = 1600) -> Tuple[bool, str]:
        """Full pipeline: Unity HLSL -> SPIR-V -> Metal -> PNG.

        Args:
            unity_shader: Full Unity shader code
            output_png: Path to output PNG file
            width: Output width
            height: Output height

        Returns:
            Tuple of (success: bool, error_message: str)
        """
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)

            # Step 1: Extract HLSL fragment shader
            try:
                hlsl_code, properties = self.extract_hlsl_fragment(unity_shader)
            except Exception as e:
                return False, f"HLSL extraction failed: {e}"

            # Step 2: Create standalone HLSL
            standalone_hlsl = self.create_standalone_hlsl(hlsl_code, properties)

            # Step 3: Compile HLSL to SPIR-V
            spirv_path = tmpdir_path / "shader.spv"
            success, error = self.compile_hlsl_to_spirv(standalone_hlsl, spirv_path)
            if not success:
                return False, error

            # Step 4: Compile SPIR-V to Metal
            metal_path = tmpdir_path / "shader.metal"
            success, error = self.compile_spirv_to_metal(spirv_path, metal_path)
            if not success:
                return False, error

            # Step 5: Execute Metal shader
            success, error = self.execute_metal_shader(metal_path, output_png, width, height)
            if not success:
                return False, error

            return True, ""


def check_hlsl_toolchain() -> Tuple[bool, str]:
    """Check if HLSL toolchain (DXC, spirv-cross, Swift) is available.

    Returns:
        Tuple of (available: bool, error_message: str)
    """
    errors = []

    # Check DXC
    try:
        runtime = HLSLRuntime()
        runtime._find_dxc()
    except FileNotFoundError as e:
        errors.append(str(e))

    # Check spirv-cross
    try:
        runtime = HLSLRuntime()
        runtime._find_spirv_cross()
    except FileNotFoundError as e:
        errors.append(str(e))

    # Check Swift
    result = subprocess.run(["which", "swiftc"], capture_output=True)
    if result.returncode != 0:
        errors.append("swiftc not found. Install Xcode Command Line Tools: xcode-select --install")

    if errors:
        return False, "\n".join(errors)

    return True, "HLSL toolchain ready"


if __name__ == "__main__":
    # Test toolchain availability
    available, message = check_hlsl_toolchain()
    print(message)
    if not available:
        exit(1)
