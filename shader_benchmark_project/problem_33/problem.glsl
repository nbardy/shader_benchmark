// Problem 33: Capsule Shape
// Create a capsule (cylinder with hemispherical caps)
// Material: Semi-glossy porcelain white
// Height: 2.0 units, radius: 0.5 units

uniform vec2 iResolution;
uniform float iTime;

float sdCapsule(vec3 p, vec3 a, vec3 b, float r) {
    vec3 pa = p - a, ba = b - a;
    float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h) - r;
}

float map(vec3 p) {
    // Rotate the capsule
    float angle = iTime * 0.5;
    float c = cos(angle);
    float s = sin(angle);
    p.xz = mat2(c, -s, s, c) * p.xz;
    
    return sdCapsule(p, vec3(0, -1, 0), vec3(0, 1, 0), 0.5);
}

vec3 calcNormal(vec3 p) {
    const float h = 0.001;
    const vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h) +
                     k.yyx * map(p + k.yyx * h) +
                     k.yxy * map(p + k.yxy * h) +
                     k.xxx * map(p + k.xxx * h));
}

float calcAO(vec3 p, vec3 n) {
    float ao = 0.0;
    float scale = 1.0;
    for(int i = 0; i < 5; i++) {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = map(p + h * n);
        ao += (h - d) * scale;
        scale *= 0.95;
    }
    return clamp(1.0 - 3.0 * ao, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 ro = vec3(0, 1.5, 4);
    vec3 lookAt = vec3(0, 0, 0);
    vec3 f = normalize(lookAt - ro);
    vec3 r = normalize(cross(vec3(0, 1, 0), f));
    vec3 u = cross(f, r);
    vec3 rd = normalize(f + uv.x * r + uv.y * u);
    
    vec3 col = vec3(0.15);
    
    float t = 0.0;
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if(d < 0.001) {
            vec3 n = calcNormal(p);
            vec3 lightDir = normalize(vec3(0.5, 0.7, 0.6));
            
            // Semi-glossy porcelain material
            vec3 matColor = vec3(0.95, 0.95, 0.92);
            float diff = max(dot(n, lightDir), 0.0);
            
            // Specular
            vec3 viewDir = normalize(-rd);
            vec3 halfDir = normalize(lightDir + viewDir);
            float spec = pow(max(dot(n, halfDir), 0.0), 32.0);
            
            float ao = calcAO(p, n);
            
            col = matColor * (0.3 + 0.6 * diff) * ao + vec3(0.4) * spec;
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