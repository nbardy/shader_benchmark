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

fn rayMarch(ro: vec3<f32>, rd: vec3<f32>) -> vec4<f32> {
    var t = 0.0;
    var material = 0u;
    
    for (var i = 0u; i < 128u; i = i + 1u) {
        let p = ro + rd * t;
        
        // Regular tetrahedron vertices (normalized to unit circumsphere)
        let sqrt3inv = 0.57735026919;
        let v0 = vec3<f32>(1.0, 1.0, 1.0) * sqrt3inv;
        let v1 = vec3<f32>(-1.0, -1.0, 1.0) * sqrt3inv;
        let v2 = vec3<f32>(-1.0, 1.0, -1.0) * sqrt3inv;
        let v3 = vec3<f32>(1.0, -1.0, -1.0) * sqrt3inv;
        
        // Distance to tetrahedron surface (approximate via edge distance)
        let d0 = distance(p, v0);
        let d1 = distance(p, v1);
        let d2 = distance(p, v2);
        let d3 = distance(p, v3);
        let dtet = min(min(d0, d1), min(d2, d3)) - 0.05;
        
        // Distance to ground plane at y = -1.2
        let dground = p.y + 1.2;
        
        let d = min(dtet, dground);
        
        if (d < 0.001) {
            if (dground < dtet) {
                material = 1u;
            } else {
                material = 2u;
            }
            break;
        }
        
        if (t > 50.0) {
            material = 0u;
            break;
        }
        
        t = t + max(d, 0.01);
    }
    
    return vec4<f32>(f32(material), t, 0.0, 1.0);
}

fn shadeTetrahedron(p: vec3<f32>, n: vec3<f32>) -> vec3<f32> {
    let baseColor = vec3<f32>(1.0, 0.8, 0.333);
    let lightPos = vec3<f32>(-4.0, 4.0, 6.0);
    let toLight = normalize(lightPos - p);
    let diff = max(dot(n, toLight), 0.0) * 0.8;
    let viewDir = normalize(vec3<f32>(3.0, -4.0, 2.5) - p);
    let h = normalize(toLight + viewDir);
    let spec = pow(max(dot(n, h), 0.0), 32.0) * 0.6;
    return baseColor * (0.3 + diff) + vec3<f32>(1.0) * spec;
}

fn shadeGround(p: vec3<f32>, n: vec3<f32>) -> vec3<f32> {
    let groundColor = vec3<f32>(0.3, 0.2, 0.15);
    let lightPos = vec3<f32>(-4.0, 4.0, 6.0);
    let toLight = normalize(lightPos - p);
    let diff = max(dot(n, toLight), 0.0) * 0.6;
    let teaColor = vec3<f32>(1.0, 0.8, 0.333);
    let reflection = teaColor * 0.3;
    return groundColor * (0.2 + diff) + reflection;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let fov = 35.0 * 3.14159 / 180.0;
    let tanFov = tan(fov * 0.5);
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    let rd = normalize(vec3<f32>(uv.x * tanFov * aspect, uv.y * tanFov, 1.0));
    
    let ro = vec3<f32>(3.0, -4.0, 2.5);
    let forward = normalize(vec3<f32>(-3.0, 4.0, -2.5));
    let right = normalize(cross(forward, vec3<f32>(0.0, 0.0, 1.0)));
    let up = cross(right, forward);
    
    let rdRotated = normalize(
        rd.x * right +
        rd.y * up +
        rd.z * forward
    );
    
    let result = rayMarch(ro, rdRotated);
    let material = u32(result.x);
    let dist = result.y;
    let p = ro + rdRotated * dist;
    let h = 0.0001;
    let n = normalize(vec3<f32>(
        rayMarch(ro + vec3<f32>(h, 0.0, 0.0), rdRotated).y - dist,
        rayMarch(ro + vec3<f32>(0.0, h, 0.0), rdRotated).y - dist,
        rayMarch(ro + vec3<f32>(0.0, 0.0, h), rdRotated).y - dist
    ));
    
    var color = vec3<f32>(0.1, 0.1, 0.12);
    
    if (material == 2u) {
        color = shadeTetrahedron(p, n);
    } else if (material == 1u) {
        color = shadeGround(p, n);
    }
    
    color = color / (vec3<f32>(1.0) + color);
    color = pow(color, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(color, 1.0);
}