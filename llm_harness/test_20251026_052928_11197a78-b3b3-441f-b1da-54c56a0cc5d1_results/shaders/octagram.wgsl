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

fn octagram_sdf(p: vec2<f32>) -> f32 {
    let pi = 3.14159265359;
    let angle = atan2(p.y, p.x);
    let r = length(p);
    
    let octant_angle = (angle + pi) / (2.0 * pi) * 8.0;
    let octant_id = floor(octant_angle);
    let local_angle = octant_angle - octant_id;
    
    let r_outer = 0.9;
    let r_inner = 0.414213562373;
    
    let is_outer_region = local_angle < 0.5;
    let threshold_r = select(r_inner, r_outer, is_outer_region);
    
    return r - threshold_r;
}

fn is_in_octagram(p: vec2<f32>) -> f32 {
    let sdf = octagram_sdf(p);
    let outline_thickness = 0.015;
    let is_outline = select(0.0, 1.0, abs(sdf) < outline_thickness);
    let is_fill = select(0.0, 1.0, sdf < 0.0);
    
    return max(is_outline, is_fill);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let center = params.resolution * 0.5;
    let pixel_offset = pos.xy - center;
    let max_dim = max(params.resolution.x, params.resolution.y);
    let uv = pixel_offset / (max_dim * 0.5);
    
    let sdf = octagram_sdf(uv);
    let outline_thickness = 0.025;
    
    let is_fill = step(sdf, 0.0);
    let is_outline = step(abs(sdf) - outline_thickness, 0.0) - is_fill;
    
    let star_color = vec3<f32>(0.352, 0.0, 1.0);
    let outline_color = vec3<f32>(0.0, 0.0, 0.0);
    let bg_color = vec3<f32>(1.0, 1.0, 1.0);
    
    let shadow_offset = vec2<f32>(0.015, -0.015);
    let shadow_uv = uv - shadow_offset;
    let shadow_sdf = octagram_sdf(shadow_uv);
    let shadow_alpha = 0.25 * (1.0 - step(0.0, shadow_sdf));
    
    var final_color = bg_color;
    final_color = mix(final_color, vec3<f32>(0.0, 0.0, 0.0), shadow_alpha * (1.0 - is_fill));
    final_color = mix(final_color, star_color, is_fill);
    final_color = mix(final_color, outline_color, is_outline);
    
    return vec4<f32>(final_color, 1.0);
}