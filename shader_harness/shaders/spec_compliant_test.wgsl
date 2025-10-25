// Shader following exact WGSL_CONSTRAINT_SPEC.md format
// Tests uniform buffer integration with spec-compliant naming

@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
}

@group(0) @binding(0) var<uniform> params: Params;

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Use exact pattern from spec section 7.1
    let uv = pos.xy / params.resolution;

    // Create test pattern to verify correct resolution access
    let grid_x = step(0.5, fract(uv.x * 10.0));
    let grid_y = step(0.5, fract(uv.y * 10.0));
    let grid = grid_x * grid_y;

    let color = vec3<f32>(grid, uv.x, uv.y);
    return vec4<f32>(color, 1.0);
}
