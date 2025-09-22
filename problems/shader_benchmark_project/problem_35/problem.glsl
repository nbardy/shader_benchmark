// Problem 35: Truncated Icosahedron (Soccer Ball)
// 12 pentagons and 20 hexagons with classic black/white pattern
// Leather-like material with subtle texture

uniform vec2 iResolution;
uniform float iTime;

float sdTruncatedIcosahedron(vec3 p, float r) {
    // Approximation using multiple plane intersections
    float phi = (1.0 + sqrt(5.0)) / 2.0;
    float a = 1.0 / sqrt(3.0);
    float b = a / phi;
    float c = a * phi;
    
    // Normalize to unit sphere
    p /= r;
    
    // Pentagon faces (12 faces)
    float d = length(p) - 1.0;
    
    // Major planes for truncated icosahedron
    d = max(d, abs(p.x) - c);
    d = max(d, abs(p.y) - c);
    d = max(d, abs(p.z) - c);
    
    // Diagonal planes
    d = max(d, abs(p.x + p.y * phi) - c * sqrt(1.0 + phi * phi));
    d = max(d, abs(p.x - p.y * phi) - c * sqrt(1.0 + phi * phi));
    d = max(d, abs(p.y + p.z * phi) - c * sqrt(1.0 + phi * phi));
    d = max(d, abs(p.y - p.z * phi) - c * sqrt(1.0 + phi * phi));
    d = max(d, abs(p.z + p.x * phi) - c * sqrt(1.0 + phi * phi));
    d = max(d, abs(p.z - p.x * phi) - c * sqrt(1.0 + phi * phi));
    
    return d * r;
}

float map(vec3 p) {
    // Rotate the ball
    float angle = iTime * 0.2;
    float c = cos(angle);
    float s = sin(angle);
    p.xz = mat2(c, -s, s, c) * p.xz;
    
    angle = iTime * 0.15;
    c = cos(angle);
    s = sin(angle);
    p.xy = mat2(c, -s, s, c) * p.xy;
    
    return sdTruncatedIcosahedron(p, 1.0);
}

vec3 calcNormal(vec3 p) {
    const float h = 0.001;
    const vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h) +
                     k.yyx * map(p + k.yyx * h) +
                     k.yxy * map(p + k.yxy * h) +
                     k.xxx * map(p + k.xxx * h));
}

// Simple pattern detection for soccer ball coloring
float getSoccerPattern(vec3 p, vec3 n) {
    // Project onto sphere and create pattern
    vec3 sp = normalize(p);
    
    // Create hexagonal-like pattern
    float pattern = 0.0;
    pattern += sin(sp.x * 12.0) * sin(sp.y * 12.0) * sin(sp.z * 12.0);
    pattern += sin(sp.x * 8.0 + sp.y * 8.0);
    pattern += sin(sp.y * 8.0 + sp.z * 8.0);
    pattern += sin(sp.z * 8.0 + sp.x * 8.0);
    
    return smoothstep(-0.1, 0.1, pattern);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 ro = vec3(0, 0, 4);
    vec3 lookAt = vec3(0);
    vec3 f = normalize(lookAt - ro);
    vec3 r = normalize(cross(vec3(0, 1, 0), f));
    vec3 u = cross(f, r);
    vec3 rd = normalize(f + uv.x * r + uv.y * u);
    
    vec3 col = vec3(0.5, 0.7, 0.5); // Grass background
    
    float t = 0.0;
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if(d < 0.001) {
            vec3 n = calcNormal(p);
            vec3 lightDir = normalize(vec3(0.5, 0.8, 0.3));
            
            // Soccer ball pattern
            float pattern = getSoccerPattern(p, n);
            vec3 matColor = mix(vec3(0.95), vec3(0.1), pattern);
            
            // Leather-like material
            float diff = max(dot(n, lightDir), 0.0);
            float spec = pow(max(dot(reflect(-lightDir, n), -rd), 0.0), 16.0);
            
            // Subtle ambient occlusion
            float ao = 0.5 + 0.5 * n.y;
            
            col = matColor * (0.3 + 0.6 * diff) * ao + vec3(0.2) * spec;
            
            break;
        }
        t += d;
        if(t > 20.0) break;
    }
    
    fragColor = vec4(col, 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}