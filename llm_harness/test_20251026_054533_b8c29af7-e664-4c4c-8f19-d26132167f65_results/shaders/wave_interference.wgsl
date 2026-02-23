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

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Normalize coordinates
    let uv = pos.xy / params.resolution;
    let coord = uv * 2.0 - 1.0;  // [-1, 1]
    
    // Wave source positions (scaled to viewport)
    let src1 = vec2<f32>(-1.5, 0.0);
    let src2 = vec2<f32>(1.5, 0.0);
    let src3 = vec2<f32>(0.0, 1.5);
    
    // Wave parameters
    let k = 6.283185307;  // 2π (scaled for visibility)
    let phase1 = 0.0;
    let phase2 = 1.047197551;  // π/3
    let phase3 = 2.094395102;  // 2π/3
    
    // Amplitude factors
    let amp1 = 0.4;
    let amp2 = 0.3;
    let amp3 = 0.5;
    
    // Calculate distances from each source
    let d1 = length(coord - src1);
    let d2 = length(coord - src2);
    let d3 = length(coord - src3);
    
    // Add small epsilon to avoid division by zero
    let eps = 0.01;
    let denom1 = 1.0 + d1;
    let denom2 = 1.0 + d2;
    let denom3 = 1.0 + d3;
    
    // Wave height contributions (static, ω=0)
    let h1 = amp1 * sin(k * d1 + phase1) / denom1;
    let h2 = amp2 * sin(k * d2 + phase2) / denom2;
    let h3 = amp3 * sin(k * d3 + phase3) / denom3;
    
    // Total deformation
    let height = h1 + h2 + h3;
    
    // Clamp height for visualization
    let h_clamped = clamp(height, -1.0, 1.0);
    
    // Normal approximation via finite differences (simplified)
    let delta = 0.01;
    let h_dx_pos = amp1 * sin(k * (d1 + delta) + phase1) / (1.0 + d1 + delta) +
                   amp2 * sin(k * (d2 + delta) + phase2) / (1.0 + d2 + delta) +
                   amp3 * sin(k * (d3 + delta) + phase3) / (1.0 + d3 + delta);
    let h_dx_neg = amp1 * sin(k * (d1 - delta) + phase1) / (1.0 + d1 - delta) +
                   amp2 * sin(k * (d2 - delta) + phase2) / (1.0 + d2 - delta) +
                   amp3 * sin(k * (d3 - delta) + phase3) / (1.0 + d3 - delta);
    
    let slope = (h_dx_pos - h_dx_neg) / (2.0 * delta);
    
    // View direction (camera at origin looking outward)
    let view_dir = normalize(vec3<f32>(coord, -2.5));
    
    // Simplified normal based on height gradient
    let normal = normalize(vec3<f32>(-slope, -slope, 1.0 + abs(slope) * 0.5));
    
    // Iridescent effect based on view angle
    let fresnel = 1.0 - abs(dot(view_dir, normal));
    let iridescence = pow(fresnel, 2.0);
    
    // Height-based color mapping: deep blue (troughs) → cyan → green → yellow → white (peaks)
    let normalized_height = (h_clamped + 1.0) * 0.5;  // [0, 1]
    
    var color = vec3<f32>(0.0, 0.0, 0.0);
    
    if (normalized_height < 0.25) {
        // Deep blue to cyan
        let t = normalized_height * 4.0;
        color = mix(vec3<f32>(0.0, 0.1, 0.4), vec3<f32>(0.0, 0.6, 1.0), t);
    } else if (normalized_height < 0.5) {
        // Cyan to green
        let t = (normalized_height - 0.25) * 4.0;
        color = mix(vec3<f32>(0.0, 0.6, 1.0), vec3<f32>(0.0, 1.0, 0.3), t);
    } else if (normalized_height < 0.75) {
        // Green to yellow
        let t = (normalized_height - 0.5) * 4.0;
        color = mix(vec3<f32>(0.0, 1.0, 0.3), vec3<f32>(1.0, 1.0, 0.0), t);
    } else {
        // Yellow to white
        let t = (normalized_height - 0.75) * 4.0;
        color = mix(vec3<f32>(1.0, 1.0, 0.0), vec3<f32>(1.0, 1.0, 1.0), t);
    }
    
    // Rim lighting: emphasize wave crests
    let rim = pow(1.0 - dot(normal, -view_dir), 3.0) * 0.5;
    color = color + rim * vec3<f32>(1.0, 1.0, 1.0);
    
    // Iridescent shimmer
    color = color * (1.0 + iridescence * 0.3);
    
    // Microdetail (subtle displacement texture simulation)
    let texture_scale = 5.0;
    let micro = sin(coord.x * texture_scale) * cos(coord.y * texture_scale) * 0.1;
    color = color + micro * vec3<f32>(0.1, 0.1, 0.2);
    
    // Fog effect based on distance from center
    let dist_from_center = length(coord) / 2.828;  // diagonal distance
    let fog_factor = exp(-dist_from_center * dist_from_center * 0.5);
    let fog_color = vec3<f32>(0.02, 0.04, 0.1);
    color = mix(fog_color, color, fog_factor);
    
    // Background gradient (dark blue-black)
    let bg_gradient = mix(vec3<f32>(0.0, 0.01, 0.05), vec3<f32>(0.05, 0.02, 0.15), uv.y);
    color = mix(bg_gradient, color, fog_factor * 0.8);
    
    // Final tone mapping and gamma correction
    color = pow(color, vec3<f32>(0.454545));  // 1/2.2 gamma
    
    return vec4<f32>(color, 1.0);
}