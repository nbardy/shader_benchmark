// Problem 34: Compound Polyhedra - Stella Octangula
// Two interpenetrating tetrahedra forming an 8-pointed star
// Material: Transparent crystal with refraction

uniform vec2 iResolution;
uniform float iTime;

float sdTetrahedron(vec3 p, float h) {
    float m = h * 0.57735027; // h/sqrt(3)
    vec3 q;
    q.x = abs(p.x);
    q.z = abs(p.z);
    q.y = p.y + h;
    
    if(q.x + q.z > m * 2.0) {
        vec3 tmp = q.xz;
        q.xz = (tmp.x + tmp.y) * 0.5 * vec2(1, -1) + vec2(0, m);
    }
    
    float d1 = q.y;
    float d2 = q.z - m;
    float d3 = q.x * 0.866025 + q.y * 0.5 - m;
    
    return max(max(d1, d2), d3);
}

float map(vec3 p) {
    // Rotate the entire structure
    float angle = iTime * 0.3;
    float c = cos(angle);
    float s = sin(angle);
    p.xz = mat2(c, -s, s, c) * p.xz;
    p.xy = mat2(c, -s, s, c) * p.xy;
    
    // First tetrahedron
    float d1 = sdTetrahedron(p, 1.0);
    
    // Second tetrahedron (inverted)
    float d2 = sdTetrahedron(-p, 1.0);
    
    // Union of both tetrahedra
    return min(d1, d2);
}

vec3 calcNormal(vec3 p) {
    const float h = 0.001;
    const vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h) +
                     k.yyx * map(p + k.yyx * h) +
                     k.yxy * map(p + k.yxy * h) +
                     k.xxx * map(p + k.xxx * h));
}

vec3 render(vec3 ro, vec3 rd) {
    vec3 col = vec3(0.05, 0.05, 0.1);
    
    float t = 0.0;
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if(d < 0.001) {
            vec3 n = calcNormal(p);
            
            // Crystal material
            vec3 crystalColor = vec3(0.7, 0.85, 1.0);
            
            // Fresnel effect
            float fresnel = pow(1.0 - abs(dot(n, -rd)), 2.0);
            
            // Refraction
            vec3 refractDir = refract(rd, n, 0.9);
            float refractAmount = 0.0;
            if(length(refractDir) > 0.0) {
                refractAmount = 0.7;
            }
            
            // Simple lighting
            vec3 lightDir = normalize(vec3(0.5, 0.7, 0.3));
            float diff = max(dot(n, lightDir), 0.0);
            
            // Combine effects
            col = crystalColor * (0.2 + 0.5 * diff);
            col = mix(col, vec3(1.0), fresnel * 0.5);
            col *= (1.0 - refractAmount * 0.3);
            
            break;
        }
        t += d;
        if(t > 20.0) break;
    }
    
    return col;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 ro = vec3(0, 0, 5);
    vec3 lookAt = vec3(0);
    vec3 f = normalize(lookAt - ro);
    vec3 r = normalize(cross(vec3(0, 1, 0), f));
    vec3 u = cross(f, r);
    vec3 rd = normalize(f + uv.x * r + uv.y * u);
    
    vec3 col = render(ro, rd);
    
    fragColor = vec4(col, 1.0);
}

void main() {
    mainImage(gl_FragColor, gl_FragCoord.xy);
}