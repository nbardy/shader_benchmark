// Simple animated gradient - Basic Shadertoy example
// Demonstrates: iTime, iResolution, coordinate normalization, cosine palette

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    // Normalize coordinates to [0, 1]
    vec2 uv = fragCoord / iResolution.xy;

    // Animated color using cosine palette technique
    // This creates smooth color gradients over time and space
    vec3 col = 0.5 + 0.5 * cos(iTime + uv.xyx + vec3(0, 2, 4));

    // Output final color
    fragColor = vec4(col, 1.0);
}
