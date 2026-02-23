// Distance field circle - Demonstrates signed distance functions (SDF)
// Demonstrates: Aspect-corrected coordinates, distance fields, smoothstep anti-aliasing

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Center coordinates to [-1, 1] with aspect ratio correction
    // Dividing by iResolution.y ensures circles stay circular
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;

    // Animated circle radius
    float radius = 0.3 + 0.1 * sin(iTime * 2.0);

    // Signed distance to circle (negative inside, positive outside)
    float dist = length(uv) - radius;

    // Anti-aliased edge using smoothstep
    // 0.01 controls edge sharpness (smaller = sharper)
    float circle = smoothstep(0.01, 0.0, dist);

    // Color based on distance field
    vec3 col = vec3(circle);

    // Add color gradient
    col = mix(vec3(0.1, 0.2, 0.3), vec3(0.8, 0.5, 0.2), circle);

    fragColor = vec4(col, 1.0);
}
