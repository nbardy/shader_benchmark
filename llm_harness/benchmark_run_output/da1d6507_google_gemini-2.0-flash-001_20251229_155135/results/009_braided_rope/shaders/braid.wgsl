@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

@group(0) @binding(0) var<uniform> params: Params;

struct Params {
    time: f32,
    resolution: vec2<f32>,
};

fn helix(u: f32, phase: f32) -> vec3<f32> {
    let radius = 0.6;
    let pitch = 1.8;
    let angle = 2.0 * 3.14159265359 * u + phase;
    let x = radius * cos(angle);
    let y = radius * sin(angle);
    let z = pitch * u;
    return vec3<f32>(x, y, z);
}

fn get_normal(u: f32, phase: f32) -> vec3<f32> {
    let angle = 2.0 * 3.14159265359 * u + phase;
    let x = -sin(angle);
    let y = cos(angle);
    return normalize(vec3<f32>(x, y, 0.0));
}

fn tube(pos: vec3<f32>, normal: vec3<f32>, v: f32) -> vec3<f32> {
    let tube_radius = 0.15;
    let angle = 2.0 * 3.14159265359 * v;
    let circle_point = tube_radius * (normal * cos(angle) + cross(vec3<f32>(0.0, 0.0, 1.0), normal) * sin(angle));
    return pos + circle_point;
}

fn camera(pos: vec3<f32>) -> vec3<f32> {
    let camera_pos = vec3<f32>(3.0, 2.0, 2.0);
    let look_at = vec3<f32>(0.0, 0.0, 0.9);
    let view_dir = normalize(look_at - camera_pos);
    let up = vec3<f32>(0.0, 1.0, 0.0);
    let right = cross(view_dir, up);
    let new_up = cross(right, view_dir);

    let dir = normalize(pos - camera_pos);

    let x = dot(dir, right);
    let y = dot(dir, new_up);
    let z = dot(dir, -view_dir); // Invert z direction
    return vec3<f32>(x, y, z);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let aspect = params.resolution.x / params.resolution.y;
    let centered_uv = vec2<f32>((uv.x - 0.5) * aspect, uv.y - 0.5);

    let u = centered_uv.x * 2.0 + params.time * 0.1;
    let v = centered_uv.y * 2.0;

    let strand_u = fract(u / 4.0);
    let strand_v = v;

    let phase1 = 0.0;
    let phase2 = 2.0 * 3.14159265359 / 3.0;
    let phase3 = 4.0 * 3.14159265359 / 3.0;

    let pos1 = tube(helix(strand_u, phase1), get_normal(strand_u, phase1), strand_v);
    let pos2 = tube(helix(strand_u, phase2), get_normal(strand_u, phase2), strand_v);
    let pos3 = tube(helix(strand_u, phase3), get_normal(strand_u, phase3), strand_v);

    let cam_pos1 = camera(pos1);
    let cam_pos2 = camera(pos2);
    let cam_pos3 = camera(pos3);

    let dist1 = length(cam_pos1.xy);
    let dist2 = length(cam_pos2.xy);
    let dist3 = length(cam_pos3.xy);

    let color1 = vec3<f32>(0.8, 0.6, 0.4);
    let color2 = vec3<f32>(0.4, 0.8, 0.6);
    let color3 = vec3<f32>(0.6, 0.4, 0.8);

    let opacity1 = smoothstep(0.01, 0.0, dist1 - 0.3);
    let opacity2 = smoothstep(0.01, 0.0, dist2 - 0.3);
    let opacity3 = smoothstep(0.01, 0.0, dist3 - 0.3);
    
    let final_color = color1 * opacity1 + color2 * opacity2 + color3 * opacity3;

    return vec4<f32>(final_color, 1.0);
}