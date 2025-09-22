// Simple WGSL mandala for testing the harness

@vertex
fn main_vs(@builtin(vertex_index) in_vertex_index: u32) -> @builtin(position) vec4<f32> {
    let x = f32(i32(in_vertex_index & 1u) * 4 - 1);
    let y = f32(i32((in_vertex_index >> 1u) & 1u) * 4 - 1);
    return vec4<f32>(x, y, 0.0, 1.0);
}

@fragment
fn main_fs(@builtin(position) frag_coord: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = vec2<f32>(1024.0, 1024.0);
    let uv = (frag_coord.xy - resolution * 0.5) / min(resolution.x, resolution.y);
    
    let r = length(uv);
    let angle = atan2(uv.y, uv.x);
    let t = 0.5;
    
    // Simple mandala pattern
    let petals = 8.0;
    let pattern = sin(angle * petals + t) * cos(r * 10.0 - t * 2.0);
    let intensity = smoothstep(0.3, 0.7, pattern);
    
    let color = vec3<f32>(intensity * 0.5 + 0.5, intensity * 0.3 + 0.2, intensity * 0.8 + 0.2);
    return vec4<f32>(color, 1.0);
}