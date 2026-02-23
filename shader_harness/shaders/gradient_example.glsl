#version 300 es
precision highp float;

uniform vec2 resolution;
out vec4 fragColor;

// Simple gradient shader - GLSL ES 3.0 reference example
void main() {
    // Normalize pixel coordinates to 0.0-1.0
    vec2 uv = gl_FragCoord.xy / resolution;

    // Create smooth gradient from bottom-left (black) to top-right (cyan/magenta)
    vec3 color = vec3(uv.x, uv.y, 0.5);

    // Output final color with full opacity
    fragColor = vec4(color, 1.0);
}
