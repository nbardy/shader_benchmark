#version 300 es
precision highp float;

uniform vec2 resolution;
out vec4 fragColor;

// Circle grid pattern - demonstrates math functions and loops
void main() {
    // Normalize coordinates
    vec2 uv = gl_FragCoord.xy / resolution;

    // Create grid coordinates
    vec2 grid_uv = uv * 10.0; // 10x10 grid
    vec2 cell = fract(grid_uv);
    vec2 cell_id = floor(grid_uv);

    // Center of current cell
    vec2 cell_center = vec2(0.5);

    // Distance from cell center
    float dist = length(cell - cell_center);

    // Circle radius
    float radius = 0.3;

    // Smooth circle edge
    float circle = smoothstep(radius, radius - 0.02, dist);

    // Checkerboard pattern for alternating colors
    float checker = mod(cell_id.x + cell_id.y, 2.0);

    // Color based on position
    vec3 color1 = vec3(0.2, 0.4, 0.8); // Blue
    vec3 color2 = vec3(0.8, 0.4, 0.2); // Orange

    vec3 bg_color = mix(color1, color2, checker);
    vec3 circle_color = vec3(1.0);

    // Final color
    vec3 color = mix(bg_color, circle_color, circle);

    fragColor = vec4(color, 1.0);
}
