// Möbius Transformation Visualization
// 3D Cubic Lattice warped through conformal Möbius map
// f(w,v) = ((aw+b)/(cw+d), v/|cw+d|²) where a=1+i, b=0.5, c=0.5i, d=1

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

// Complex number operations as vec2<f32>: (real, imag)
fn complex_mul(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn complex_div(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = dot(b, b);
    return vec2<f32>(dot(a, b), a.y * b.x - a.x * b.y) / denom;
}

// Möbius transformation: f(w,v) = ((aw+b)/(cw+d), v/|cw+d|²)
// Parameters: a=1+i, b=0.5, c=0.5i, d=1
fn mobius_transform(w: vec2<f32>, v: f32) -> vec3<f32> {
    let a = vec2<f32>(1.0, 1.0);
    let b = vec2<f32>(0.5, 0.0);
    let c = vec2<f32>(0.0, 0.5);
    let d = vec2<f32>(1.0, 0.0);
    
    let cw_plus_d = complex_mul(c, w) + d;
    let denom_sq = dot(cw_plus_d, cw_plus_d);
    
    let numerator = complex_mul(a, w) + b;
    let w_prime = complex_div(numerator, cw_plus_d);
    
    let denom_safe = select(0.001, denom_sq, denom_sq > 0.0001);
    let v_prime = v / denom_safe;
    
    return vec3<f32>(w_prime.x, w_prime.y, v_prime);
}

// Original lattice point
fn original_lattice(i: i32, j: i32, k: i32) -> vec3<f32> {
    return vec3<f32>(
        f32(i - 3) * 0.5,
        f32(j - 3) * 0.5,
        f32(k - 3) * 0.5
    );
}

// Distance from pixel to line segment (used for rendering)
fn dist_to_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
    return length(pa - ba * h);
}

// Project 3D point to 2D with perspective
fn project_to_2d(pos: vec3<f32>, camera_pos: vec3<f32>, focal_length: f32) -> vec2<f32> {
    let to_camera = pos - camera_pos;
    let z_dist = max(to_camera.z, 0.1);
    return vec2<f32>(
        to_camera.x * focal_length / z_dist,
        to_camera.y * focal_length / z_dist
    );
}

// Render edges of original lattice (faded grey)
fn render_original_edge(uv: vec2<f32>, i0: i32, j0: i32, k0: i32, i1: i32, j1: i32, k1: i32) -> f32 {
    let camera_pos = vec3<f32>(4.0, 3.0, 3.5);
    let p0 = original_lattice(i0, j0, k0);
    let p1 = original_lattice(i1, j1, k1);
    
    let proj0 = project_to_2d(p0, camera_pos, 1.5);
    let proj1 = project_to_2d(p1, camera_pos, 1.5);
    
    let dist = dist_to_line(uv, proj0, proj1);
    return smoothstep(0.015, 0.005, dist);
}

// Render edges of transformed lattice (glowing tubes)
fn render_transformed_edge(uv: vec2<f32>, i0: i32, j0: i32, k0: i32, i1: i32, j1: i32, k1: i32) -> vec3<f32> {
    let camera_pos = vec3<f32>(4.0, 3.0, 3.5);
    
    let p0_orig = original_lattice(i0, j0, k0);
    let p1_orig = original_lattice(i1, j1, k1);
    
    let p0_trans = mobius_transform(vec2<f32>(p0_orig.x, p0_orig.y), p0_orig.z);
    let p1_trans = mobius_transform(vec2<f32>(p1_orig.x, p1_orig.y), p1_orig.z);
    
    let proj0 = project_to_2d(p0_trans, camera_pos, 1.5);
    let proj1 = project_to_2d(p1_trans, camera_pos, 1.5);
    
    let dist = dist_to_line(uv, proj0, proj1);
    
    // Compute distortion magnitude for coloring
    let distort0 = length(p0_trans - p0_orig);
    let distort1 = length(p1_trans - p1_orig);
    let avg_distort = (distort0 + distort1) * 0.5;
    
    // Logarithmic scale to handle large distortions
    let log_distort = log(avg_distort + 1.0) * 0.3;
    let color_factor = clamp(log_distort, 0.0, 1.0);
    
    // Blue to red gradient
    let color = mix(
        vec3<f32>(0.2, 0.4, 1.0),
        vec3<f32>(1.0, 0.2, 0.2),
        color_factor
    );
    
    let line_alpha = smoothstep(0.020, 0.008, dist);
    let glow = smoothstep(0.08, 0.0, dist) * 0.3;
    
    return color * (line_alpha + glow);
}

// Focal sphere at singularity (approximately at origin)
fn render_focal_sphere(uv: vec2<f32>) -> vec3<f32> {
    let camera_pos = vec3<f32>(4.0, 3.0, 3.5);
    let sphere_center = vec3<f32>(0.0, 0.0, 0.0);
    
    let proj_center = project_to_2d(sphere_center, camera_pos, 1.5);
    let dist_from_center = length(uv - proj_center);
    
    let sphere_edge = smoothstep(0.25, 0.20, dist_from_center);
    let sphere_fill = smoothstep(0.20, 0.15, dist_from_center) * 0.4;
    
    return (sphere_edge + sphere_fill) * vec3<f32>(1.0, 0.8, 0.3);
}

// Grid plane at z=0
fn render_grid_plane(uv: vec2<f32>) -> f32 {
    let camera_pos = vec3<f32>(4.0, 3.0, 3.5);
    
    var grid_val = 0.0;
    for (var gx: i32 = -4; gx <= 4; gx = gx + 1) {
        for (var gy: i32 = -4; gy <= 4; gy = gy + 1) {
            let grid_pt = vec3<f32>(f32(gx) * 0.5, f32(gy) * 0.5, 0.0);
            let proj_pt = project_to_2d(grid_pt, camera_pos, 1.5);
            let dist_to_grid = length(uv - proj_pt);
            grid_val = max(grid_val, smoothstep(0.008, 0.002, dist_to_grid) * 0.2);
        }
    }
    return grid_val;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let uv = (pos.xy - resolution * 0.5) / min(resolution.x, resolution.y);
    
    // Dark background
    var final_color = vec3<f32>(0.02, 0.02, 0.05);
    
    // Render grid plane
    final_color = final_color + render_grid_plane(uv) * vec3<f32>(0.3, 0.3, 0.4);
    
    // Render original lattice edges (grey, faded)
    var original_contrib = 0.0;
    for (var i: i32 = 0; i < 7; i = i + 1) {
        for (var j: i32 = 0; j < 7; j = j + 1) {
            for (var k: i32 = 0; k < 7; k = k + 1) {
                // Edges in x direction
                if (i < 6) {
                    original_contrib = max(original_contrib, render_original_edge(uv, i, j, k, i + 1, j, k));
                }
                // Edges in y direction
                if (j < 6) {
                    original_contrib = max(original_contrib, render_original_edge(uv, i, j, k, i, j + 1, k));
                }
                // Edges in z direction
                if (k < 6) {
                    original_contrib = max(original_contrib, render_original_edge(uv, i, j, k, i, j, k + 1));
                }
            }
        }
    }
    final_color = final_color + original_contrib * vec3<f32>(0.4, 0.4, 0.45) * 0.3;
    
    // Render transformed lattice edges (glowing, colored)
    var transformed_contrib = vec3<f32>(0.0);
    for (var i: i32 = 0; i < 7; i = i + 1) {
        for (var j: i32 = 0; j < 7; j = j + 1) {
            for (var k: i32 = 0; k < 7; k = k + 1) {
                // Edges in x direction
                if (i < 6) {
                    transformed_contrib = max(transformed_contrib, render_transformed_edge(uv, i, j, k, i + 1, j, k));
                }
                // Edges in y direction
                if (j < 6) {
                    transformed_contrib = max(transformed_contrib, render_transformed_edge(uv, i, j, k, i, j + 1, k));
                }
                // Edges in z direction
                if (k < 6) {
                    transformed_contrib = max(transformed_contrib, render_transformed_edge(uv, i, j, k, i, j, k + 1));
                }
            }
        }
    }
    final_color = final_color + transformed_contrib * 0.85;
    
    // Render focal sphere
    let sphere_contrib = render_focal_sphere(uv);
    final_color = final_color + sphere_contrib;
    
    // Tone mapping and gamma correction
    final_color = clamp(final_color, vec3<f32>(0.0), vec3<f32>(1.0));
    final_color = pow(final_color, vec3<f32>(0.45));
    
    return vec4<f32>(final_color, 1.0);
}