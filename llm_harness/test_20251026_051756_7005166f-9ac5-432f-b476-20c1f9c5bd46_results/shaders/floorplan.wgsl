// Architectural floorplan from frequency-domain image
// 64×64 iFFT of amplitude spectrum A(u,v) = 1/(u²+v²+1)
// Extruded to 40mm pillar heights, rendered orthographic top-down

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

// Approximated iFFT spatial map from amplitude spectrum A(u,v) = 1/(u²+v²+1)
fn spatial_value(x: u32, y: u32) -> f32 {
    let dx = f32(i32(x) - 32) * 0.125;
    let dy = f32(i32(y) - 32) * 0.125;
    let r_sq = dx * dx + dy * dy;
    
    // Gaussian-weighted approximation of iFFT
    let base = exp(-r_sq * 0.3);
    let fine = 0.2 * sin(f32(x) * 0.4) * sin(f32(y) * 0.4);
    let detail = 0.15 * cos(f32(x) * 0.25) * cos(f32(y) * 0.25);
    
    return max(0.0, base + fine * 0.1 + detail * 0.05);
}

// Extrude height: h = 40 * (s - s_min) / (s_max - s_min) mm
fn pillar_height(x: u32, y: u32) -> f32 {
    let s = spatial_value(x, y);
    let s_min = 0.05;
    let s_max = 1.1;
    let normalized = (s - s_min) / (s_max - s_min);
    let clamped = clamp(normalized, 0.0, 1.0);
    return 40.0 * clamped;
}

// Check adjacency: heights differ ≤ 1mm
fn should_connect(h1: f32, h2: f32) -> bool {
    return abs(h1 - h2) <= 1.0;
}

// World (mm) to screen (px) coordinates
fn world_to_screen(world_x: f32, world_y: f32) -> vec2<f32> {
    let content_px = 1840.0;
    let border_px = 80.0;
    let uv_x = world_x / 64.0;
    let uv_y = world_y / 64.0;
    return vec2<f32>(border_px + uv_x * content_px, border_px + uv_y * content_px);
}

// Distance to nearest wall edge
fn distance_to_wall_edge(screen_pos: vec2<f32>) -> f32 {
    var min_dist = 1000.0;
    
    for (var grid_y: u32 = 0u; grid_y < 64u; grid_y = grid_y + 1u) {
        for (var grid_x: u32 = 0u; grid_x < 64u; grid_x = grid_x + 1u) {
            let h = pillar_height(grid_x, grid_y);
            
            if (h > 2.0) {
                var is_edge = false;
                
                if (grid_x == 0u || grid_y == 0u || grid_x == 63u || grid_y == 63u) {
                    is_edge = true;
                } else {
                    let h_left = select(pillar_height(grid_x - 1u, grid_y), h, grid_x == 0u);
                    let h_right = select(pillar_height(grid_x + 1u, grid_y), h, grid_x == 63u);
                    let h_down = select(pillar_height(grid_x, grid_y - 1u), h, grid_y == 0u);
                    let h_up = select(pillar_height(grid_x, grid_y + 1u), h, grid_y == 63u);
                    
                    is_edge = !should_connect(h, h_left) ||
                              !should_connect(h, h_right) ||
                              !should_connect(h, h_down) ||
                              !should_connect(h, h_up);
                }
                
                if (is_edge) {
                    let cell_min = world_to_screen(f32(grid_x), f32(grid_y));
                    let cell_max = world_to_screen(f32(grid_x) + 1.0, f32(grid_y) + 1.0);
                    let clamped_x = clamp(screen_pos.x, cell_min.x, cell_max.x);
                    let clamped_y = clamp(screen_pos.y, cell_min.y, cell_max.y);
                    let closest = vec2<f32>(clamped_x, clamped_y);
                    let dist = distance(screen_pos, closest);
                    min_dist = min(min_dist, dist);
                }
            }
        }
    }
    
    return min_dist;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let screen_pos = pos.xy;
    
    let canvas_min = vec2<f32>(0.0, 0.0);
    let canvas_max = vec2<f32>(2000.0, 2000.0);
    
    if (screen_pos.x < canvas_min.x || screen_pos.x > canvas_max.x ||
        screen_pos.y < canvas_min.y || screen_pos.y > canvas_max.y) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    let border = 80.0;
    let content_min = vec2<f32>(border, border);
    let content_max = vec2<f32>(2000.0 - border, 2000.0 - border);
    
    if (screen_pos.x < content_min.x || screen_pos.x > content_max.x ||
        screen_pos.y < content_min.y || screen_pos.y > content_max.y) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    let content_px = 1840.0;
    let uv_x = (screen_pos.x - border) / content_px;
    let uv_y = (screen_pos.y - border) / content_px;
    let world_x = uv_x * 64.0;
    let world_y = uv_y * 64.0;
    
    let grid_x = u32(world_x);
    let grid_y = u32(world_y);
    let safe_x = min(grid_x, 63u);
    let safe_y = min(grid_y, 63u);
    
    let h = pillar_height(safe_x, safe_y);
    var color = vec3<f32>(1.0, 1.0, 1.0);
    
    if (h > 2.0) {
        color = vec3<f32>(0.0, 0.4, 0.8);
    }
    
    let within_cell_x = fract(world_x);
    let within_cell_y = fract(world_y);
    let grid_threshold = 0.05;
    let near_grid_x = within_cell_x < grid_threshold || within_cell_x > (1.0 - grid_threshold);
    let near_grid_y = within_cell_y < grid_threshold || within_cell_y > (1.0 - grid_threshold);
    
    if (near_grid_x || near_grid_y) {
        let grid_color = vec3<f32>(0.9, 0.9, 0.9);
        color = mix(color, grid_color, 0.1);
    }
    
    let wall_dist = distance_to_wall_edge(screen_pos);
    if (wall_dist < 2.0 && h > 2.0) {
        let edge_intensity = 1.0 - (wall_dist / 2.0);
        color = color * (1.0 - edge_intensity * 0.2);
    }
    
    return vec4<f32>(color, 1.0);
}