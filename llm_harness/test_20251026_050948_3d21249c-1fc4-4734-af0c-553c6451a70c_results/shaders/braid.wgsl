// Three-strand braided rope with helical geometry
// Strands at phase offsets 0°, 120°, 240° on cylinder radius 0.6
// Pitch 1.8, tube radius 0.15
// Colors: #c96, #6c9, #96c

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

const PI = 3.14159265359;
const TWO_PI = 6.28318530718;
const CYLINDER_RADIUS = 0.6;
const PITCH = 1.8;
const TUBE_RADIUS = 0.15;
const NUM_STRANDS = 3u;
const CAMERA_POS = vec3<f32>(3.0, 2.0, 2.0);
const CAMERA_TARGET = vec3<f32>(0.0, 0.0, 0.0);

fn render_scene(uv: vec2<f32>) -> vec3<f32> {
    let aspect = params.resolution.x / params.resolution.y;
    let screen_pos = vec3<f32>(uv.x * aspect, uv.y, -3.5);
    
    let camera_forward = normalize(CAMERA_TARGET - CAMERA_POS);
    let camera_right = normalize(cross(camera_forward, vec3<f32>(0.0, 1.0, 0.0)));
    let camera_up = cross(camera_right, camera_forward);
    
    let ray_dir = normalize(
        camera_forward * 1.5 +
        camera_right * screen_pos.x +
        camera_up * screen_pos.y
    );
    let ray_origin = CAMERA_POS;
    
    var final_color = vec3<f32>(0.1, 0.1, 0.12);
    var min_depth = 1e6;
    var closest_strand = 0u;
    
    var strand = 0u;
    loop {
        if (strand >= NUM_STRANDS) { break; }
        
        let phase = f32(strand) * TWO_PI / 3.0;
        var t = -5.0;
        let t_step = 0.05;
        
        loop {
            if (t > 5.0) { break; }
            
            let angle = t * TWO_PI / PITCH + phase;
            let cos_a = cos(angle);
            let sin_a = sin(angle);
            
            let helix_center = vec3<f32>(
                CYLINDER_RADIUS * cos_a,
                t,
                CYLINDER_RADIUS * sin_a
            );
            
            let to_ray = ray_origin - helix_center;
            let proj_len = dot(to_ray, ray_dir);
            
            if (proj_len > 0.0) {
                let closest = ray_origin - ray_dir * proj_len;
                let dist = length(closest - helix_center);
                
                if (dist < TUBE_RADIUS) {
                    let depth = length(ray_origin - helix_center);
                    if (depth < min_depth) {
                        min_depth = depth;
                        closest_strand = strand;
                    }
                }
            }
            
            t = t + t_step;
        }
        
        strand = strand + 1u;
    }
    
    if (min_depth < 1e5) {
        let strand_colors = array<vec3<f32>, 3>(
            vec3<f32>(0.8, 0.6, 0.4),
            vec3<f32>(0.4, 0.8, 0.6),
            vec3<f32>(0.6, 0.4, 0.8)
        );
        
        let color = strand_colors[closest_strand];
        let lighting = 0.4 + 0.6 * max(0.0, dot(normalize(vec3<f32>(1.0, 1.0, 1.0)), ray_dir));
        final_color = color * lighting;
    }
    
    return final_color;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    let color = render_scene(uv);
    return vec4<f32>(color, 1.0);
}