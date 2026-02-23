// Rotating pattern - Demonstrates rotation matrices and polar coordinates
// Demonstrates: 2D rotation, polar coordinates, repetition, time animation

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Aspect-corrected centered coordinates
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // 2D rotation matrix
    float angle = iTime * 0.5;
    float c = cos(angle);
    float s = sin(angle);
    mat2 rot = mat2(c, -s, s, c);

    // Apply rotation
    uv = rot * uv;

    // Convert to polar coordinates
    float r = length(uv);
    float a = atan(uv.y, uv.x);

    // Create repeating pattern using polar coordinates
    float pattern = sin(a * 8.0) * cos(r * 10.0 - iTime * 2.0);

    // Normalize to [0, 1]
    pattern = pattern * 0.5 + 0.5;

    // Color based on pattern
    vec3 col1 = vec3(0.2, 0.4, 0.8);
    vec3 col2 = vec3(0.9, 0.3, 0.5);
    vec3 col = mix(col1, col2, pattern);

    // Add radial gradient for depth
    col *= 1.0 - smoothstep(0.3, 0.8, r);

    fragColor = vec4(col, 1.0);
}
