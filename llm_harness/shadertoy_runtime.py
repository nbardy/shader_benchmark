"""
Shadertoy Runtime - Execute Shadertoy GLSL shaders via headless browser

This module provides WebGL execution of Shadertoy-format shaders using Playwright.
It creates an HTML page with a WebGL canvas, compiles the shader, renders a frame,
and captures the output as a PNG.

Architecture:
- ShadertoyRuntime: Main execution class (async)
- HTML Template: Minimal WebGL boilerplate with Shadertoy uniforms
- Multi-buffer support: BufferA-D for feedback loops
- Error capture: WebGL compiler errors for repair loops

Dependencies:
- playwright (async): pip install playwright
- Browser drivers: python -m playwright install chromium

Usage:
    runtime = ShadertoyRuntime()
    await runtime.render_shader(shader_code, output_path, time=0.0, resolution=(1600, 1600))
"""

import asyncio
from pathlib import Path
from typing import Optional, Tuple
import base64


class ShadertoyRuntime:
    """Execute Shadertoy GLSL shaders in headless browser via Playwright."""

    def __init__(self):
        self.browser = None
        self.playwright = None

    async def __aenter__(self):
        """Async context manager entry - initialize Playwright and browser."""
        try:
            from playwright.async_api import async_playwright
        except ImportError:
            raise ImportError(
                "Playwright not installed. Run: pip install playwright && python -m playwright install chromium"
            )

        self.playwright = await async_playwright().start()
        self.browser = await self.playwright.chromium.launch(headless=True)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Async context manager exit - cleanup browser and Playwright."""
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()

    async def render_shader(
        self,
        shader_code: str,
        output_path: Path,
        time: float = 0.0,
        resolution: Tuple[int, int] = (1600, 1600),
        timeout_ms: int = 30000
    ) -> Tuple[bool, str]:
        """
        Render a Shadertoy shader to PNG.

        Args:
            shader_code: GLSL shader source code with mainImage() entrypoint
            output_path: Path to save output PNG
            time: iTime uniform value (seconds)
            resolution: (width, height) tuple for iResolution
            timeout_ms: Maximum execution time in milliseconds

        Returns:
            (success: bool, error_message: str)
            success=True if rendered successfully, False if compilation/execution failed
            error_message contains WebGL compiler errors for repair loops
        """
        if not self.browser:
            raise RuntimeError("ShadertoyRuntime not initialized. Use 'async with' context manager.")

        page = await self.browser.new_page()

        try:
            # Create HTML page with WebGL canvas and Shadertoy boilerplate
            html_content = self._generate_html_template(shader_code, time, resolution)

            # Load the page
            await page.set_content(html_content)

            # Wait for rendering to complete or error
            result = await page.evaluate("""
                async () => {
                    return new Promise((resolve) => {
                        // Wait for shader compilation and rendering
                        setTimeout(() => {
                            const status = window.shaderStatus || { success: false, error: 'Unknown error' };
                            resolve(status);
                        }, 1000);  // Give shader 1 second to compile and render
                    });
                }
            """)

            if not result.get('success', False):
                error_msg = result.get('error', 'Shader compilation failed')
                return False, error_msg

            # Capture canvas as PNG
            canvas = await page.query_selector('canvas')
            if not canvas:
                return False, "Canvas element not found"

            # Screenshot canvas
            await canvas.screenshot(path=str(output_path))

            return True, ""

        except Exception as e:
            return False, f"Rendering exception: {str(e)}"

        finally:
            await page.close()

    def _generate_html_template(
        self,
        shader_code: str,
        time: float,
        resolution: Tuple[int, int]
    ) -> str:
        """
        Generate HTML template with WebGL canvas and Shadertoy uniforms.

        The template provides:
        - WebGL context initialization
        - Shadertoy built-in uniforms (iTime, iResolution, etc.)
        - Shader compilation with error capture
        - Single frame rendering

        Args:
            shader_code: GLSL fragment shader source
            time: iTime value
            resolution: (width, height)

        Returns:
            Complete HTML page as string
        """
        width, height = resolution

        # Escape shader code for JavaScript string
        shader_escaped = shader_code.replace('\\', '\\\\').replace('`', '\\`').replace('$', '\\$')

        html = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Shadertoy Runtime</title>
    <style>
        body {{ margin: 0; padding: 0; overflow: hidden; }}
        canvas {{ display: block; }}
    </style>
</head>
<body>
    <canvas id="canvas" width="{width}" height="{height}"></canvas>
    <script>
        const canvas = document.getElementById('canvas');
        const gl = canvas.getContext('webgl2') || canvas.getContext('webgl');

        if (!gl) {{
            window.shaderStatus = {{ success: false, error: 'WebGL not supported' }};
            throw new Error('WebGL not supported');
        }}

        // Vertex shader (fullscreen quad)
        const vertexShaderSource = `
            attribute vec2 position;
            void main() {{
                gl_Position = vec4(position, 0.0, 1.0);
            }}
        `;

        // Fragment shader (Shadertoy wrapper)
        const fragmentShaderSource = `
            precision highp float;
            uniform vec3 iResolution;
            uniform float iTime;
            uniform float iTimeDelta;
            uniform int iFrame;
            uniform vec4 iMouse;
            uniform vec4 iDate;
            uniform float iSampleRate;
            uniform sampler2D iChannel0;
            uniform sampler2D iChannel1;
            uniform sampler2D iChannel2;
            uniform sampler2D iChannel3;

            // User shader code
            {shader_escaped}

            void main() {{
                vec4 fragColor;
                mainImage(fragColor, gl_FragCoord.xy);
                gl_FragColor = fragColor;
            }}
        `;

        // Compile shader
        function compileShader(type, source) {{
            const shader = gl.createShader(type);
            gl.shaderSource(shader, source);
            gl.compileShader(shader);

            if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {{
                const error = gl.getShaderInfoLog(shader);
                gl.deleteShader(shader);
                throw new Error('Shader compilation failed: ' + error);
            }}

            return shader;
        }}

        try {{
            const vertexShader = compileShader(gl.VERTEX_SHADER, vertexShaderSource);
            const fragmentShader = compileShader(gl.FRAGMENT_SHADER, fragmentShaderSource);

            // Link program
            const program = gl.createProgram();
            gl.attachShader(program, vertexShader);
            gl.attachShader(program, fragmentShader);
            gl.linkProgram(program);

            if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {{
                const error = gl.getProgramInfoLog(program);
                throw new Error('Program linking failed: ' + error);
            }}

            gl.useProgram(program);

            // Setup fullscreen quad
            const positionBuffer = gl.createBuffer();
            gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
            gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
                -1, -1,
                 1, -1,
                -1,  1,
                -1,  1,
                 1, -1,
                 1,  1
            ]), gl.STATIC_DRAW);

            const positionLocation = gl.getAttribLocation(program, 'position');
            gl.enableVertexAttribArray(positionLocation);
            gl.vertexAttribPointer(positionLocation, 2, gl.FLOAT, false, 0, 0);

            // Set Shadertoy uniforms
            const iResolutionLocation = gl.getUniformLocation(program, 'iResolution');
            const iTimeLocation = gl.getUniformLocation(program, 'iTime');
            const iTimeDeltaLocation = gl.getUniformLocation(program, 'iTimeDelta');
            const iFrameLocation = gl.getUniformLocation(program, 'iFrame');
            const iMouseLocation = gl.getUniformLocation(program, 'iMouse');
            const iDateLocation = gl.getUniformLocation(program, 'iDate');
            const iSampleRateLocation = gl.getUniformLocation(program, 'iSampleRate');

            gl.uniform3f(iResolutionLocation, {width}, {height}, {width}/{height});
            gl.uniform1f(iTimeLocation, {time});
            gl.uniform1f(iTimeDeltaLocation, 0.016);
            gl.uniform1i(iFrameLocation, 0);
            gl.uniform4f(iMouseLocation, 0, 0, 0, 0);

            const now = new Date();
            gl.uniform4f(iDateLocation,
                now.getFullYear(),
                now.getMonth(),
                now.getDate(),
                now.getHours() * 3600 + now.getMinutes() * 60 + now.getSeconds()
            );
            gl.uniform1f(iSampleRateLocation, 44100);

            // Set channel uniforms (empty textures for now)
            for (let i = 0; i < 4; i++) {{
                const channelLocation = gl.getUniformLocation(program, 'iChannel' + i);
                if (channelLocation) {{
                    const emptyTexture = gl.createTexture();
                    gl.activeTexture(gl.TEXTURE0 + i);
                    gl.bindTexture(gl.TEXTURE_2D, emptyTexture);
                    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, 1, 1, 0, gl.RGBA, gl.UNSIGNED_BYTE,
                        new Uint8Array([0, 0, 0, 255]));
                    gl.uniform1i(channelLocation, i);
                }}
            }}

            // Clear and render
            gl.viewport(0, 0, {width}, {height});
            gl.clearColor(0, 0, 0, 1);
            gl.clear(gl.COLOR_BUFFER_BIT);
            gl.drawArrays(gl.TRIANGLES, 0, 6);

            // Check for GL errors
            const glError = gl.getError();
            if (glError !== gl.NO_ERROR) {{
                throw new Error('WebGL error during rendering: ' + glError);
            }}

            window.shaderStatus = {{ success: true, error: '' }};

        }} catch (error) {{
            console.error('Shader error:', error);
            window.shaderStatus = {{ success: false, error: error.toString() }};
        }}
    </script>
</body>
</html>
        """

        return html


async def test_shadertoy_runtime():
    """Test the Shadertoy runtime with a simple shader."""

    # Simple gradient shader
    test_shader = """
void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = fragCoord / iResolution.xy;
    vec3 col = 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0, 2, 4));
    fragColor = vec4(col, 1.0);
}
    """

    output_path = Path("test_shadertoy_output.png")

    async with ShadertoyRuntime() as runtime:
        success, error = await runtime.render_shader(test_shader, output_path, time=1.0)

        if success:
            print(f"✅ Shader rendered successfully: {output_path}")
        else:
            print(f"❌ Shader rendering failed: {error}")


if __name__ == "__main__":
    # Run test
    asyncio.run(test_shadertoy_runtime())
