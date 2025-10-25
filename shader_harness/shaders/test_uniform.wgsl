// Test shader to verify uniform buffer support
// Tests WGSL_CONSTRAINT_SPEC.md section 2.3 contract

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
    // Normalize coordinates using uniform buffer resolution
    let uv = pos.xy / params.resolution;

    // Create a gradient based on UV coordinates
    let color = vec3<f32>(uv.x, uv.y, 0.5);

    // Add a circle in the center to verify aspect ratio is correct
    let center = vec2<f32>(0.5, 0.5);
    let dist = length(uv - center);
    let circle = smoothstep(0.3, 0.29, dist);

    // Mix circle with gradient
    let finalColor = mix(color, vec3<f32>(1.0, 1.0, 1.0), circle);

    return vec4<f32>(finalColor, 1.0);
}
