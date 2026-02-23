@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
};

@group(0) @binding(0) var<uniform> params: Params;

fn kleinBottle(u: f32, v: f32) -> vec3<f32> {
    let R = 2.0;
    let cos_u = cos(u);
    let sin_u = sin(u);
    let cos_u_half = cos(u * 0.5);
    let sin_u_half = sin(u * 0.5);
    let sin_v = sin(v);
    let sin_2v = sin(2.0 * v);
    let cos_2v = cos(2.0 * v);
    
    let r = R + cos_u_half * sin_v - sin_u_half * sin_2v;
    
    let x = r * cos_u;
    let y = r * sin_u;
    let z = sin_u_half * sin_v + cos_u_half * sin_2v;
    
    return vec3<f32>(x, y, z);
}

fn kleinBottleNormal(u: f32, v: f32, delta: f32) -> vec3<f32> {
    let p0 = kleinBottle(u, v);
    let p_u = kleinBottle(u + delta, v);
    let p_v = kleinBottle(u, v + delta);
    
    let du = p_u - p0;
    let dv = p_v - p0;
    
    return normalize(cross(du, dv));
}

fn gaussianCurvature(u: f32, v: f32, delta: f32) -> f32 {
    let eps = delta * 0.5;
    
    let n0 = kleinBottleNormal(u, v, delta);
    let n_u_pos = kleinBottleNormal(u + eps, v, delta);
    let n_u_neg = kleinBottleNormal(u - eps, v, delta);
    let n_v_pos = kleinBottleNormal(u, v + eps, delta);
    let n_v_neg = kleinBottleNormal(u, v - eps, delta);
    
    let dn_du = (n_u_pos - n_u_neg) / (2.0 * eps);
    let dn_dv = (n_v_pos - n_v_neg) / (2.0 * eps);
    
    let curvature = dot(dn_du, n0) * dot(dn_dv, n0) - dot(dn_du, dn_dv);
    
    return curvature;
}

fn phongLighting(normal: vec3<f32>, position: vec3<f32>, lightPos: vec3<f32>, viewPos: vec3<f32>) -> vec3<f32> {
    let lightColor = vec3<f32>(1.0, 1.0, 1.0);
    let ambientStrength = 0.2;
    let diffuseStrength = 0.7;
    let specularStrength = 0.4;
    let shininess = 32.0;
    
    let ambient = ambientStrength * lightColor;
    
    let lightDir = normalize(lightPos - position);
    let diffuse = diffuseStrength * max(dot(normal, lightDir), 0.0) * lightColor;
    
    let viewDir = normalize(viewPos - position);
    let reflectDir = reflect(-lightDir, normal);
    let spec = pow(max(dot(viewDir, reflectDir), 0.0), shininess);
    let specular = specularStrength * spec * lightColor;
    
    return ambient + diffuse + specular;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    
    let screenUv = pos.xy / resolution;
    
    let u = screenUv.x * 6.283185307179586;
    let v = screenUv.y * 6.283185307179586;
    
    let delta = 0.001;
    let surfacePoint = kleinBottle(u, v);
    let surfaceNormal = kleinBottleNormal(u, v, delta);
    
    let lightPos = vec3<f32>(4.0, 5.0, 8.0);
    let viewPos = vec3<f32>(6.0, 3.0, 1.0);
    
    let lighting = phongLighting(surfaceNormal, surfacePoint, lightPos, viewPos);
    
    let curvature = gaussianCurvature(u, v, delta);
    let curvatureNormalized = clamp(curvature * 0.5 + 0.5, 0.0, 1.0);
    
    let baseColor = mix(
        vec3<f32>(0.0, 0.3, 1.0),
        vec3<f32>(1.0, 0.2, 0.0),
        curvatureNormalized
    );
    
    let finalColor = baseColor * lighting;
    
    let bgColor = vec3<f32>(0.933, 0.949, 1.0);
    let outColor = mix(bgColor, finalColor, 0.85);
    
    return vec4<f32>(outColor, 1.0);
}