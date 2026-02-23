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

fn pointInTriangle(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>) -> bool {
    let d0 = b - a;
    let d1 = c - b;
    let d2 = a - c;
    
    let c0 = p - a;
    let c1 = p - b;
    let c2 = p - c;
    
    let cross0 = d0.x * c0.y - d0.y * c0.x;
    let cross1 = d1.x * c1.y - d1.y * c1.x;
    let cross2 = d2.x * c2.y - d2.y * c2.x;
    
    return (cross0 >= -0.001 && cross1 >= -0.001 && cross2 >= -0.001) ||
           (cross0 <= 0.001 && cross1 <= 0.001 && cross2 <= 0.001);
}

fn distanceToLineSegment(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let ba = b - a;
    let pa = p - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn sierpinski(p: vec2<f32>, level: i32) -> f32 {
    let v0 = vec2<f32>(0.0, 0.866025403784);
    let v1 = vec2<f32>(-0.5, -0.433012701892);
    let v2 = vec2<f32>(0.5, -0.433012701892);
    
    var currentP = p;
    var currentV0 = v0;
    var currentV1 = v1;
    var currentV2 = v2;
    var minDist = 1000.0;
    
    var l = 0i32;
    loop {
        if l >= level {
            break;
        }
        
        let mid01 = (currentV0 + currentV1) * 0.5;
        let mid12 = (currentV1 + currentV2) * 0.5;
        let mid20 = (currentV2 + currentV0) * 0.5;
        
        minDist = min(minDist, distanceToLineSegment(currentP, mid01, mid12));
        minDist = min(minDist, distanceToLineSegment(currentP, mid12, mid20));
        minDist = min(minDist, distanceToLineSegment(currentP, mid20, mid01));
        
        let inTri0 = pointInTriangle(currentP, currentV0, mid01, mid20);
        let inTri1 = pointInTriangle(currentP, currentV1, mid12, mid01);
        let inTri2 = pointInTriangle(currentP, currentV2, mid20, mid12);
        
        if inTri0 {
            currentV1 = mid01;
            currentV2 = mid20;
        } else if inTri1 {
            currentV0 = mid01;
            currentV2 = mid12;
        } else if inTri2 {
            currentV0 = mid20;
            currentV1 = mid12;
        } else {
            break;
        }
        
        l = l + 1i32;
    }
    
    minDist = min(minDist, distanceToLineSegment(currentP, currentV0, currentV1));
    minDist = min(minDist, distanceToLineSegment(currentP, currentV1, currentV2));
    minDist = min(minDist, distanceToLineSegment(currentP, currentV2, currentV0));
    
    return minDist;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let uv = (pos.xy / params.resolution - vec2<f32>(0.5, 0.5)) * 2.0;
    let adjustedUv = vec2<f32>(uv.x * aspect, uv.y);
    
    let dist = sierpinski(adjustedUv, 6i32);
    let lineWidth = 0.004;
    let edgeAlpha = 1.0 - smoothstep(0.0, lineWidth, dist);
    
    let fillColor = vec3<f32>(1.0, 1.0, 1.0);
    let strokeColor = vec3<f32>(0.0, 0.0, 0.0);
    
    let finalColor = select(fillColor, strokeColor, edgeAlpha > 0.5);
    
    return vec4<f32>(finalColor, 1.0);
}