#version 320 es
precision highp float;

out vec4 fragColor;

// 3D transformations and cube rendering with GLSL features
mat3 rotateX(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        1.0, 0.0, 0.0,
        0.0, c, -s,
        0.0, s, c
    );
}

mat3 rotateY(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        c, 0.0, s,
        0.0, 1.0, 0.0,
        -s, 0.0, c
    );
}

float distanceToLine(vec2 p, vec2 a, vec2 b) {
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

void main() {
    // Convert screen coordinates to normalized coordinates
    vec2 uv = (gl_FragCoord.xy - 512.0) / 512.0;
    
    // Animation time
    float time = length(uv) * 2.0;
    
    // Rotate cube
    mat3 rot = rotateY(time * 0.5) * rotateX(time * 0.3);
    
    // Cube vertices - THIS WORKS IN GLSL (variable array indexing)
    vec3 vertices[8] = vec3[](
        vec3(-1.0, -1.0, -1.0), // 0
        vec3( 1.0, -1.0, -1.0), // 1
        vec3( 1.0,  1.0, -1.0), // 2
        vec3(-1.0,  1.0, -1.0), // 3
        vec3(-1.0, -1.0,  1.0), // 4
        vec3( 1.0, -1.0,  1.0), // 5
        vec3( 1.0,  1.0,  1.0), // 6
        vec3(-1.0,  1.0,  1.0)  // 7
    );
    
    // Transform vertices - VARIABLE ARRAY INDEXING WORKS!
    vec2 projected[8];
    for (int i = 0; i < 8; i++) {
        vec3 rotated = rot * vertices[i];
        projected[i] = rotated.xy * 0.4; // Scale for viewing
    }
    
    // Define edges (pairs of vertex indices)
    int edges[24] = int[](
        0, 1, 1, 2, 2, 3, 3, 0, // Back face
        4, 5, 5, 6, 6, 7, 7, 4, // Front face
        0, 4, 1, 5, 2, 6, 3, 7  // Connecting edges
    );
    
    float lineWidth = 0.01;
    vec3 cubeColor = vec3(0.0, 0.5, 1.0); // Blue
    vec3 backgroundColor = vec3(0.1, 0.1, 0.1); // Dark gray
    
    float minDistance = 1000.0;
    
    // Check distance to each edge - VARIABLE INDEXING WORKS!
    for (int i = 0; i < 24; i += 2) {
        int v0 = edges[i];
        int v1 = edges[i + 1];
        vec2 p0 = projected[v0];
        vec2 p1 = projected[v1];
        
        float dist = distanceToLine(uv, p0, p1);
        minDistance = min(minDistance, dist);
    }
    
    // Anti-aliased edge rendering
    float alpha = 1.0 - smoothstep(0.0, lineWidth, minDistance);
    vec3 finalColor = mix(backgroundColor, cubeColor, alpha);
    
    fragColor = vec4(finalColor, 1.0);
}