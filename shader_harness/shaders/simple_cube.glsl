#version 450 core

out vec4 fragColor;

void main() {
    // Convert gl_FragCoord to normalized coordinates [-1, 1]
    vec2 uv = (gl_FragCoord.xy - 512.0) / 512.0;  // For 1024x1024 canvas
    
    // Simple animated cube wireframe using GLSL features
    float time = length(uv) * 2.0;
    
    // Cube vertices - GLSL SUPPORTS VARIABLE ARRAY INDEXING!
    vec3 vertices[8] = vec3[](
        vec3(-0.5, -0.5, -0.5), vec3( 0.5, -0.5, -0.5),
        vec3( 0.5,  0.5, -0.5), vec3(-0.5,  0.5, -0.5),
        vec3(-0.5, -0.5,  0.5), vec3( 0.5, -0.5,  0.5), 
        vec3( 0.5,  0.5,  0.5), vec3(-0.5,  0.5,  0.5)
    );
    
    // Rotation matrices
    float c = cos(time * 0.5), s = sin(time * 0.5);
    mat3 rot = mat3(c, 0, s, 0, 1, 0, -s, 0, c);
    
    // Transform vertices with VARIABLE INDEXING (impossible in WGSL!)
    vec2 projected[8];
    for (int i = 0; i < 8; i++) {
        vec3 rotated = rot * vertices[i];  // ✅ WORKS IN GLSL!
        projected[i] = rotated.xy;         // ✅ WORKS IN GLSL!
    }
    
    // Edge connections
    int edges[24] = int[](
        0,1, 1,2, 2,3, 3,0,  // back face
        4,5, 5,6, 6,7, 7,4,  // front face  
        0,4, 1,5, 2,6, 3,7   // connections
    );
    
    // Find closest edge distance
    float minDist = 1000.0;
    for (int i = 0; i < 24; i += 2) {
        vec2 p0 = projected[edges[i]];     // ✅ VARIABLE INDEXING!
        vec2 p1 = projected[edges[i+1]];   // ✅ VARIABLE INDEXING!
        
        vec2 pa = uv - p0;
        vec2 ba = p1 - p0;
        float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
        float dist = length(pa - ba * h);
        minDist = min(minDist, dist);
    }
    
    // Render wireframe
    float lineWidth = 0.02;
    vec3 cubeColor = vec3(0.0, 0.6, 1.0);
    vec3 bgColor = vec3(0.1, 0.1, 0.1);
    
    float alpha = 1.0 - smoothstep(0.0, lineWidth, minDist);
    vec3 finalColor = mix(bgColor, cubeColor, alpha);
    
    fragColor = vec4(finalColor, 1.0);
}