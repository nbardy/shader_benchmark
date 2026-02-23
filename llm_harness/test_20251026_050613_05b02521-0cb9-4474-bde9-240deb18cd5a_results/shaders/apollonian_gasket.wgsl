@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> @builtin(position) vec4<f32> {
    let vertex_id = vertex_index % 3u;
    let x = f32(i32(vertex_id & 1u) << 2u) - 1.0;
    let y = f32(i32((vertex_id >> 1u) & 1u) << 2u) - 1.0;
    return vec4<f32>(x, y, 0.0, 1.0);
}

struct Params {
    resolution: vec2<f32>,
    time: f32,
    _pad: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

fn lcg_random(seed: ptr<function, u32>) -> f32 {
    let a = 1664525u;
    let c = 1013904223u;
    let m = 4294967295u;
    *seed = (a * (*seed) + c) & m;
    return f32(*seed) / f32(m);
}

fn mobius_m1(z: vec2<f32>) -> vec2<f32> {
    let num_r = 2.0 * z.x + 1.0;
    let num_i = 2.0 * z.y;
    let den_r = z.x + 1.0;
    let den_i = z.y;
    let denom_norm = den_r * den_r + den_i * den_i + 1e-6;
    return vec2<f32>(
        (num_r * den_r + num_i * den_i) / denom_norm,
        (num_i * den_r - num_r * den_i) / denom_norm
    );
}

fn mobius_m2(z: vec2<f32>) -> vec2<f32> {
    let num_r = 2.0 * z.x - 1.0;
    let num_i = 2.0 * z.y;
    let den_r = z.x - 1.0;
    let den_i = z.y;
    let denom_norm = den_r * den_r + den_i * den_i + 1e-6;
    return vec2<f32>(
        (num_r * den_r + num_i * den_i) / denom_norm,
        (num_i * den_r - num_r * den_i) / denom_norm
    );
}

fn apply_mobius(z: vec2<f32>, seed: ptr<function, u32>) -> vec2<f32> {
    let r = lcg_random(seed);
    return select(mobius_m2(z), mobius_m1(z), r < 0.5);
}

fn stereo_project(sphere_pt: vec3<f32>) -> vec2<f32> {
    let denom = 1.0 - sphere_pt.z + 1e-6;
    return sphere_pt.xy / denom;
}

fn stereo_unproject(plane_pt: vec2<f32>) -> vec3<f32> {
    let r2 = dot(plane_pt, plane_pt);
    let denom = 1.0 + r2;
    return vec3<f32>(
        2.0 * plane_pt.x / denom,
        2.0 * plane_pt.y / denom,
        (r2 - 1.0) / denom
    );
}

fn pixel_distance(frag_pos: vec2<f32>, orbit_pt: vec2<f32>, pixel_scale: f32) -> f32 {
    let delta = frag_pos - orbit_pt * pixel_scale;
    return length(delta);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let canvas_size = params.resolution;
    let center = canvas_size * 0.5;
    let max_dim = max(canvas_size.x, canvas_size.y);
    
    let padding = 120.0;
    let effective_size = max_dim - 2.0 * padding;
    let scale = effective_size / 2400.0;
    let pixel_scale = scale;
    
    var accumulated_color = vec3<f32>(0.0, 0.0, 0.0);
    var sample_count = 0u;
    
    var seed = u32(
        (u32(pos.x) ^ 0x9e3779b9u) +
        (u32(pos.y) << 6u) +
        (u32(pos.y) >> 2u)
    );
    
    let walks_per_frag = 100u;
    let points_per_walk = 300u;
    let discard_iterations = 12u;
    let plot_depth = 9u;
    
    for (var walk_idx = 0u; walk_idx < walks_per_frag; walk_idx = walk_idx + 1u) {
        var z = vec2<f32>(
            (lcg_random(&seed) - 0.5) * 0.1,
            (lcg_random(&seed) - 0.5) * 0.1
        );
        
        for (var iter = 0u; iter < points_per_walk; iter = iter + 1u) {
            z = apply_mobius(z, &seed);
            
            if (iter >= discard_iterations && iter < discard_iterations + plot_depth) {
                let sphere_pt = stereo_unproject(z);
                let projected = stereo_project(sphere_pt);
                
                let parity = (iter & 1u);
                let color_factor = select(vec3<f32>(1.0, 0.2, 0.4), vec3<f32>(0.2, 1.0, 0.4), parity == 0u);
                
                let dist_to_frag = pixel_distance(pos.xy, projected, pixel_scale);
                let disk_radius = 0.6;
                
                let contrib = max(0.0, 1.0 - dist_to_frag / disk_radius) * 0.15;
                accumulated_color = accumulated_color + color_factor * contrib;
                
                sample_count = sample_count + 1u;
            }
        }
    }
    
    let bloom_strength = 0.4;
    var final_color = accumulated_color / (f32(sample_count) + 1.0);
    final_color = pow(final_color, vec3<f32>(0.8)) * (1.0 + bloom_strength);
    
    final_color = clamp(final_color, vec3<f32>(0.0), vec3<f32>(1.0));
    
    return vec4<f32>(final_color, 1.0);
}