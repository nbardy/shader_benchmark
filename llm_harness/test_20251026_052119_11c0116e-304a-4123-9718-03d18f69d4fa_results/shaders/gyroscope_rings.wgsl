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

fn mat3_mult(m: mat3x3<f32>, v: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(
        dot(m[0], v),
        dot(m[1], v),
        dot(m[2], v)
    );
}

fn rot_x(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(1.0, 0.0, 0.0),
        vec3<f32>(0.0, c, -s),
        vec3<f32>(0.0, s, c)
    );
}

fn rot_y(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, 0.0, s),
        vec3<f32>(0.0, 1.0, 0.0),
        vec3<f32>(-s, 0.0, c)
    );
}

fn rot_z(angle: f32) -> mat3x3<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat3x3<f32>(
        vec3<f32>(c, -s, 0.0),
        vec3<f32>(s, c, 0.0),
        vec3<f32>(0.0, 0.0, 1.0)
    );
}

fn line_distance(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
}

fn project(v: vec3<f32>, cam_dist: f32) -> vec2<f32> {
    let scale = cam_dist / (cam_dist + v.z);
    return v.xy * scale;
}

fn render_ring(
    uv: vec2<f32>,
    radius: f32,
    rot_mat: mat3x3<f32>,
    color: vec3<f32>,
    samples: u32
) -> vec4<f32> {
    var total_contrib = 0.0;
    
    var i = 0u;
    loop {
        if (i >= samples) { break; }
        
        let theta = f32(i) * 6.28318530718 / f32(samples);
        let next_theta = f32(i + 1u) * 6.28318530718 / f32(samples);
        
        let pt1 = vec3<f32>(radius * cos(theta), radius * sin(theta), 0.0);
        let pt2 = vec3<f32>(radius * cos(next_theta), radius * sin(next_theta), 0.0);
        
        let pt1_rot = mat3_mult(rot_mat, pt1);
        let pt2_rot = mat3_mult(rot_mat, pt2);
        
        let cam_pos = vec3<f32>(4.0, 3.0, 3.0);
        let cam_dist = length(cam_pos);
        
        let p1 = project(pt1_rot - cam_pos, cam_dist);
        let p2 = project(pt2_rot - cam_pos, cam_dist);
        
        let dist = line_distance(uv, p1, p2);
        let edge = smoothstep(0.005, 0.002, dist);
        total_contrib = total_contrib + edge;
        
        i = i + 1u;
    }
    
    let alpha = min(total_contrib, 1.0);
    return vec4<f32>(color, alpha);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    let angle_x = 0.5236;
    let angle_y = 0.5236;
    let angle_z = 0.5236;
    
    let rot_mat_1 = rot_x(angle_x);
    let rot_mat_2 = rot_y(angle_y);
    let rot_mat_3 = rot_z(angle_z);
    
    var final_color = vec3<f32>(0.0, 0.0, 0.0);
    var final_alpha = 0.0;
    
    let ring1 = render_ring(uv, 1.0, rot_mat_1, vec3<f32>(1.0, 0.4, 0.4), 64u);
    let ring2 = render_ring(uv, 1.5, rot_mat_2, vec3<f32>(0.4, 1.0, 0.4), 96u);
    let ring3 = render_ring(uv, 2.0, rot_mat_3, vec3<f32>(0.4, 0.4, 1.0), 128u);
    
    final_color = final_color + ring1.rgb * ring1.a * (1.0 - final_alpha);
    final_alpha = final_alpha + ring1.a * (1.0 - final_alpha);
    
    final_color = final_color + ring2.rgb * ring2.a * (1.0 - final_alpha);
    final_alpha = final_alpha + ring2.a * (1.0 - final_alpha);
    
    final_color = final_color + ring3.rgb * ring3.a * (1.0 - final_alpha);
    final_alpha = final_alpha + ring3.a * (1.0 - final_alpha);
    
    let bg_color = vec3<f32>(0.05, 0.05, 0.05);
    final_color = mix(bg_color, final_color, final_alpha);
    
    return vec4<f32>(final_color, 1.0);
}