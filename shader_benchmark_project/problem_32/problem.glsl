// Problem 32: Rounded Box
// Create a 3D box with rounded edges and corners (radius 0.3)
// Material: Matte plastic, pastel mint (#88e0b0)
// Implement soft shadows and proper edge smoothing

uniform vec2 iResolution;
uniform float iTime;

float sdRoundBox(vec3 p, vec3 b, float r) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0) - r;
}

float map(vec3 p) {
    return sdRoundBox(p, vec3(1.0, 0.75, 0.5), 0.3);
}

vec3 calcNormal(vec3 p) {
    const float h = 0.001;
    const vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h) +
                     k.yyx * map(p + k.yyx * h) +
                     k.yxy * map(p + k.yxy * h) +
                     k.xxx * map(p + k.xxx * h));
}

float calcShadow(vec3 ro, vec3 rd, float mint, float maxt) {
    float res = 1.0;
    float t = mint;
    for(int i = 0; i < 64; i++) {
        float h = map(ro + rd * t);
        res = min(res, 8.0 * h / t);
        t += clamp(h, 0.02, 0.2);
        if(h < 0.001 || t > maxt) break;
    }
    return clamp(res, 0.0, 1.0);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord) {
    vec2 uv = (fragCoord - 0.5 * iResolution.xy) / iResolution.y;
    
    vec3 ro = vec3(3.0 * cos(iTime * 0.4), 2.0, 3.0 * sin(iTime * 0.4));
    vec3 lookAt = vec3(0.0);
    vec3 f = normalize(lookAt - ro);
    vec3 r = normalize(cross(vec3(0, 1, 0), f));
    vec3 u = cross(f, r);
    vec3 rd = normalize(f + uv.x * r + uv.y * u);
    
    vec3 col = vec3(0.1);
    
    float t = 0.0;
    for(int i = 0; i < 100; i++) {
        vec3 p = ro + rd * t;
        float d = map(p);
        if(d < 0.001) {
            vec3 n = calcNormal(p);
            vec3 lightPos = vec3(4, 5, -3);
            vec3 lightDir = normalize(lightPos - p);
            
            // Matte plastic material
            vec3 matColor = vec3(0.533, 0.878, 0.690); // #88e0b0
            float diff = max(dot(n, lightDir), 0.0);
            float shadow = calcShadow(p + n * 0.001, lightDir, 0.001, 10.0);
            
            col = matColor * (0.3 + 0.7 * diff * shadow);
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