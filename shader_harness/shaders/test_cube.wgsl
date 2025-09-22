// Convert the GLSL cube to WGSL for testing
// Note: This demonstrates WGSL array indexing limitations

@vertex
fn main_vs(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
    let x = f32(i32(in_vertex_index & 1u) * 4 - 1);
    let y = f32(i32((in_vertex_index >> 1u) & 1u) * 4 - 1);
    return vec4<f32>(x, y, 0.0, 1.0);
}

@fragment
fn main_fs(@builtin(position) frag_coord: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = vec2<f32>(1024.0, 1024.0);
    let uv = (frag_coord.xy - resolution * 0.5) / resolution;
    
    // Simple cube using WGSL constraints (no variable array indexing)
    let time = length(uv) * 2.0;
    
    // Hardcoded cube vertices (can't use array with variable indexing)
    let v0 = vec3<f32>(-0.5, -0.5, -0.5);
    let v1 = vec3<f32>( 0.5, -0.5, -0.5);
    let v2 = vec3<f32>( 0.5,  0.5, -0.5);
    let v3 = vec3<f32>(-0.5,  0.5, -0.5);
    let v4 = vec3<f32>(-0.5, -0.5,  0.5);
    let v5 = vec3<f32>( 0.5, -0.5,  0.5);
    let v6 = vec3<f32>( 0.5,  0.5,  0.5);
    let v7 = vec3<f32>(-0.5,  0.5,  0.5);
    
    // Rotation
    let c = cos(time * 0.5);
    let s = sin(time * 0.5);
    let rot = mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
    
    // Project vertices (manually, no loops with variable indexing)
    let p0 = (rot * v0).xy;
    let p1 = (rot * v1).xy;
    let p2 = (rot * v2).xy;
    let p3 = (rot * v3).xy;
    let p4 = (rot * v4).xy;
    let p5 = (rot * v5).xy;
    let p6 = (rot * v6).xy;
    let p7 = (rot * v7).xy;
    
    // Manually calculate edge distances (no dynamic loops)
    var minDist = 1000.0;
    
    // Back face edges
    minDist = min(minDist, line_distance(uv, p0, p1));
    minDist = min(minDist, line_distance(uv, p1, p2));
    minDist = min(minDist, line_distance(uv, p2, p3));
    minDist = min(minDist, line_distance(uv, p3, p0));
    
    // Front face edges
    minDist = min(minDist, line_distance(uv, p4, p5));
    minDist = min(minDist, line_distance(uv, p5, p6));
    minDist = min(minDist, line_distance(uv, p6, p7));
    minDist = min(minDist, line_distance(uv, p7, p4));
    
    // Connecting edges
    minDist = min(minDist, line_distance(uv, p0, p4));
    minDist = min(minDist, line_distance(uv, p1, p5));
    minDist = min(minDist, line_distance(uv, p2, p6));
    minDist = min(minDist, line_distance(uv, p3, p7));
    
    // Render wireframe
    let lineWidth = 0.02;
    let cubeColor = vec3<f32>(0.0, 0.6, 1.0);
    let bgColor = vec3<f32>(0.1, 0.1, 0.1);
    
    let alpha = 1.0 - smoothstep(0.0, lineWidth, minDist);
    let finalColor = mix(bgColor, cubeColor, alpha);
    
    return vec4<f32>(finalColor, 1.0);
}

fn line_distance(point: vec2<f32>, p0: vec2<f32>, p1: vec2<f32>) -> f32 {
    let pa = point - p0;
    let ba = p1 - p0;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}