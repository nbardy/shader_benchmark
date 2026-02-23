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

fn draw_line(
    frag_coord: vec2<f32>,
    p0: vec2<f32>,
    p1: vec2<f32>,
    stroke_width: f32
) -> f32 {
    let pa = frag_coord - p0;
    let ba = p1 - p0;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    let dist = length(pa - ba * h);
    return smoothstep(stroke_width + 0.5, stroke_width - 0.5, dist);
}

fn draw_branch(
    frag_coord: vec2<f32>,
    start: vec2<f32>,
    angle_rad: f32,
    length_px: f32,
    stroke_width: f32
) -> f32 {
    let cos_a = cos(angle_rad);
    let sin_a = sin(angle_rad);
    let end = start + vec2<f32>(cos_a * length_px, sin_a * length_px);
    return draw_line(frag_coord, start, end, stroke_width);
}

fn tree_recursive(
    frag_coord: vec2<f32>,
    start: vec2<f32>,
    angle_rad: f32,
    length_px: f32,
    depth: u32,
    max_depth: u32,
    stroke_width: f32
) -> f32 {
    var result = 0.0;
    
    // Draw current segment
    result = result + draw_branch(frag_coord, start, angle_rad, length_px, stroke_width);
    
    // Recurse if we haven't exceeded max depth
    if (depth < max_depth) {
        let cos_a = cos(angle_rad);
        let sin_a = sin(angle_rad);
        let end = start + vec2<f32>(cos_a * length_px, sin_a * length_px);
        
        let next_length = length_px * 0.7;
        let angle_offset = 0.7853981633974483; // 45 degrees in radians
        
        // Left branch
        result = result + tree_recursive(
            frag_coord,
            end,
            angle_rad + angle_offset,
            next_length,
            depth + 1u,
            max_depth,
            stroke_width
        );
        
        // Right branch
        result = result + tree_recursive(
            frag_coord,
            end,
            angle_rad - angle_offset,
            next_length,
            depth + 1u,
            max_depth,
            stroke_width
        );
    }
    
    return result;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let canvas_width = 1600.0;
    let canvas_height = 1800.0;
    
    // Flip Y coordinate to match standard graphics conventions
    let frag_coord = vec2<f32>(pos.x, canvas_height - pos.y);
    
    // Trunk starts at bottom center, extends upward
    let trunk_start = vec2<f32>(canvas_width * 0.5, canvas_height * 0.1);
    let trunk_length = 180.0;
    let stroke_width = 2.0;
    let max_depth = 7u;
    
    // Angle: 90 degrees (π/2) pointing upward in standard coords
    let trunk_angle = 1.5707963267948966; // π/2 radians
    
    // Draw the tree
    let tree_coverage = tree_recursive(
        frag_coord,
        trunk_start,
        trunk_angle,
        trunk_length,
        0u,
        max_depth,
        stroke_width
    );
    
    // Color: #006600 (dark green) for branches, white background
    let branch_color = vec3<f32>(0.0, 0.4, 0.0);
    let bg_color = vec3<f32>(1.0, 1.0, 1.0);
    
    // Blend based on coverage (anti-aliased edges)
    let final_color = mix(bg_color, branch_color, tree_coverage);
    
    return vec4<f32>(final_color, 1.0);
}