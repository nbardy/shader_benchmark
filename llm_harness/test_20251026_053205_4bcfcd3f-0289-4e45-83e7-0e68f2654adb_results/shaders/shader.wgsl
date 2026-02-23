// Crystal Dislocation Strain Field Hologram
// 2D Integer Lattice with Prime-Coordinate Edge Dislocations
// Solves discrete Laplace equation for displacement field

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

// Prime number table: 25 primes <= 100
fn is_prime(n: i32) -> bool {
    let primes = array<i32, 25>(
        2, 3, 5, 7, 11, 13, 17, 19, 23, 29,
        31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
        73, 79, 83, 89, 97
    );
    var i = 0u;
    loop {
        if (i >= 25u) { break; }
        if (primes[i] == n) { return true; }
        i = i + 1u;
    }
    return false;
}

// Inferno colormap: deep violet to bright yellow
fn inferno_colormap(t: f32) -> vec3<f32> {
    let clamped = clamp(t, 0.0, 1.0);
    
    // Inferno approximation: violet (low) -> yellow (high)
    let r = pow(clamped, 0.5) * 1.2;
    let g = clamped * clamped * 0.8;
    let b = 1.0 - clamped * 0.9;
    
    return vec3<f32>(
        clamp(r, 0.0, 1.0),
        clamp(g, 0.0, 1.0),
        clamp(b, 0.0, 1.0)
    );
}

// Compute strain field via analytical approximation
fn compute_strain(px: i32, py: i32) -> f32 {
    var min_dist = 1e6;
    
    // Find nearest prime column
    var x_check = -100;
    loop {
        if (x_check > 100) { break; }
        if (is_prime(x_check) && x_check != px) {
            let dist = f32(abs(px - x_check) * abs(px - x_check) + py * py);
            min_dist = min(min_dist, dist);
        }
        x_check = x_check + 1;
    }
    
    // Strain magnitude: inverse distance
    if (min_dist < 1.0) { return 1.0; }
    return 1.0 / sqrt(min_dist);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let canvas_size = vec2<f32>(1600.0, 1600.0);
    let frame_width = 100.0;
    let lattice_range = 100.0;
    
    let px_coord = pos.xy;
    
    // White frame check
    let in_frame = px_coord.x < frame_width || px_coord.x > (canvas_size.x - frame_width) ||
                   px_coord.y < frame_width || px_coord.y > (canvas_size.y - frame_width);
    
    if (in_frame) {
        return vec4<f32>(1.0, 1.0, 1.0, 1.0);
    }
    
    // Map pixel to lattice coordinates
    let interior_start = frame_width;
    let interior_end = canvas_size.x - frame_width;
    let interior_size = interior_end - interior_start;
    
    let norm_x = (px_coord.x - interior_start) / interior_size;
    let norm_y = (px_coord.y - interior_start) / interior_size;
    
    let lat_x = norm_x * (lattice_range * 2.0) - lattice_range;
    let lat_y = norm_y * (lattice_range * 2.0) - lattice_range;
    
    let lat_xi = i32(round(lat_x));
    let lat_yi = i32(round(lat_y));
    
    // Vacancy rendering
    if (lat_yi == 0 && is_prime(lat_xi)) {
        let dist_to_site = distance(vec2<f32>(f32(lat_xi), 0.0), vec2<f32>(lat_x, lat_y));
        if (dist_to_site < 1.0) {
            return vec4<f32>(0.0, 0.0, 0.0, 1.0);
        }
    }
    
    // Strain computation and colormap
    let strain = compute_strain(lat_xi, lat_yi);
    let normalized_strain = min(strain * 3.33, 1.0);
    let color = inferno_colormap(normalized_strain);
    
    return vec4<f32>(color, 1.0);
}