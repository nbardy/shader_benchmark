#version 300 es
precision highp float;

uniform float time;
uniform vec2 resolution;
out vec4 fragColor;

// Animated rotating pattern - GLSL ES 3.0 reference example
void main() {
    // Normalize and center coordinates (-1 to 1)
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 centered = (uv - 0.5) * 2.0;

    // Account for aspect ratio
    float aspect = resolution.x / resolution.y;
    centered.x *= aspect;

    // Calculate distance from center
    float dist = length(centered);

    // Calculate angle from center
    float angle = atan(centered.y, centered.x);

    // Rotating spiral pattern
    float pattern = sin(dist * 8.0 - angle * 3.0 + time * 2.0);

    // Time-varying colors
    float r = 0.5 + 0.5 * sin(time + dist * 2.0);
    float g = 0.5 + 0.5 * cos(time * 1.3 + angle);
    float b = 0.5 + 0.5 * sin(time * 0.7 + pattern * 2.0);

    // Mix pattern with colors
    vec3 color = vec3(r, g, b) * (0.5 + 0.5 * pattern);

    fragColor = vec4(color, 1.0);
}
