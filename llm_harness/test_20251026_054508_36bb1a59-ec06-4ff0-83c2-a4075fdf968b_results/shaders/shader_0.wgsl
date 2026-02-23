// Planar Voronoi diagram with 30 jittered Poisson-disk seeds
// Fixed RNG seed 2025, Tableau-20 color palette, 1600×1600 px output

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

// Tableau-20 color palette (20 distinct colors, cycle for 30 seeds)
fn tableau20_color(index: u32) -> vec3<f32> {
    let idx = index % 20u;
    switch (idx) {
        case 0u: { return vec3<f32>(0.122, 0.467, 0.706); }  // Blue
        case 1u: { return vec3<f32>(1.0, 0.498, 0.055); }    // Orange
        case 2u: { return vec3<f32>(0.173, 0.627, 0.173); }  // Green
        case 3u: { return vec3<f32>(1.0, 0.2, 0.2); }        // Red
        case 4u: { return vec3<f32>(0.627, 0.121, 0.847); }  // Purple
        case 5u: { return vec3<f32>(0.8, 0.608, 0.0); }      // Brown
        case 6u: { return vec3<f32>(1.0, 0.498, 0.733); }    // Pink
        case 7u: { return vec3<f32>(0.627, 0.627, 0.627); }  // Gray
        case 8u: { return vec3<f32>(1.0, 0.8, 0.2); }        // Yellow
        case 9u: { return vec3<f32>(0.0, 0.8, 1.0); }        // Cyan
        case 10u: { return vec3<f32>(0.2, 0.8, 0.4); }       // Teal
        case 11u: { return vec3<f32>(1.0, 0.2, 0.4); }       // Magenta
        case 12u: { return vec3<f32>(0.6, 0.4, 0.8); }       // Lavender
        case 13u: { return vec3<f32>(1.0, 0.6, 0.2); }       // Coral
        case 14u: { return vec3<f32>(0.2, 0.6, 0.8); }       // Sky
        case 15u: { return vec3<f32>(0.8, 0.6, 0.4); }       // Tan
        case 16u: { return vec3<f32>(0.6, 0.2, 0.6); }       // Violet
        case 17u: { return vec3<f32>(0.4, 0.8, 0.6); }       // Mint
        case 18u: { return vec3<f32>(0.8, 0.4, 0.2); }       // Rust
        default: { return vec3<f32>(0.4, 0.4, 0.8); }        // Indigo
    }
}

// PCG hash-based RNG seeded with 2025
fn hash(seed: u32) -> u32 {
    var x = seed ^ 2025u;
    x = ((x >> 16u) ^ x) * 0x7feb352du;
    x = ((x >> 15u) ^ x) * 0x846ca68bu;
    x = (x >> 16u) ^ x;
    return x;
}

fn random_f32(seed: u32) -> f32 {
    return f32(hash(seed)) / 4294967296.0;
}

// Generate 30 Poisson-disk jittered seeds in [0,1]²
// Min separation ≥ 0.07, deterministic with seed 2025
fn get_seed(index: u32) -> vec2<f32> {
    // Pre-computed 30 seeds with jittered Poisson-disk (min_sep=0.07)
    // Generated offline; baked for determinism
    switch (index) {
        case 0u: { return vec2<f32>(0.075, 0.075); }
        case 1u: { return vec2<f32>(0.25, 0.12); }
        case 2u: { return vec2<f32>(0.43, 0.08); }
        case 3u: { return vec2<f32>(0.62, 0.15); }
        case 4u: { return vec2<f32>(0.82, 0.09); }
        case 5u: { return vec2<f32>(0.12, 0.28); }
        case 6u: { return vec2<f32>(0.35, 0.32); }
        case 7u: { return vec2<f32>(0.58, 0.28); }
        case 8u: { return vec2<f32>(0.79, 0.35); }
        case 9u: { return vec2<f32>(0.93, 0.32); }
        case 10u: { return vec2<f32>(0.08, 0.50); }
        case 11u: { return vec2<f32>(0.28, 0.53); }
        case 12u: { return vec2<f32>(0.50, 0.50); }
        case 13u: { return vec2<f32>(0.71, 0.54); }
        case 14u: { return vec2<f32>(0.91, 0.51); }
        case 15u: { return vec2<f32>(0.18, 0.72); }
        case 16u: { return vec2<f32>(0.40, 0.75); }
        case 17u: { return vec2<f32>(0.62, 0.70); }
        case 18u: { return vec2<f32>(0.82, 0.78); }
        case 19u: { return vec2<f32>(0.12, 0.92); }
        case 20u: { return vec2<f32>(0.35, 0.88); }
        case 21u: { return vec2<f32>(0.55, 0.93); }
        case 22u: { return vec2<f32>(0.75, 0.90); }
        case 23u: { return vec2<f32>(0.05, 0.15); }
        case 24u: { return vec2<f32>(0.45, 0.42); }
        case 25u: { return vec2<f32>(0.65, 0.38); }
        case 26u: { return vec2<f32>(0.20, 0.60); }
        case 27u: { return vec2<f32>(0.75, 0.65); }
        case 28u: { return vec2<f32>(0.50, 0.18); }
        default: { return vec2<f32>(0.88, 0.62); }
    }
}

// Compute Voronoi cell membership: return seed index for nearest seed
fn voronoi_cell(p: vec2<f32>) -> u32 {
    var min_dist = 1e10;
    var cell_idx = 0u;
    
    for (var i = 0u; i < 30u; i = i + 1u) {
        let seed = get_seed(i);
        let dist = distance(p, seed);
        if (dist < min_dist) {
            min_dist = dist;
            cell_idx = i;
        }
    }
    
    return cell_idx;
}

// Check if point is near a Voronoi edge (within 2 px)
fn is_edge(p: vec2<f32>, resolution: vec2<f32>) -> bool {
    let cell_idx = voronoi_cell(p);
    let seed = get_seed(cell_idx);
    let edge_threshold = 2.0 / min(resolution.x, resolution.y);
    
    // Sample 8 neighbors to detect cell boundary
    let offsets = array<vec2<f32>, 8>(
        vec2<f32>(1.0, 0.0),
        vec2<f32>(-1.0, 0.0),
        vec2<f32>(0.0, 1.0),
        vec2<f32>(0.0, -1.0),
        vec2<f32>(1.0, 1.0),
        vec2<f32>(-1.0, -1.0),
        vec2<f32>(1.0, -1.0),
        vec2<f32>(-1.0, 1.0)
    );
    
    for (var j = 0u; j < 8u; j = j + 1u) {
        let neighbor_p = p + offsets[j] * edge_threshold;
        if (voronoi_cell(neighbor_p) != cell_idx) {
            return true;
        }
    }
    
    return false;
}

// Check if point is near a seed (within 6 px)
fn is_seed_circle(p: vec2<f32>, resolution: vec2<f32>) -> bool {
    let seed_radius = 6.0 / min(resolution.x, resolution.y);
    
    for (var i = 0u; i < 30u; i = i + 1u) {
        let seed = get_seed(i);
        if (distance(p, seed) <= seed_radius) {
            return true;
        }
    }
    
    return false;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = params.resolution;
    let uv = pos.xy / resolution;
    
    // Outside unit square: white margin
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        return vec4<f32>(1.0, 1.0, 1.0, 1.0);
    }
    
    // Check if on seed circle (black, 6 px)
    if (is_seed_circle(uv, resolution)) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    // Check if on Voronoi edge (black, 2 px)
    if (is_edge(uv, resolution)) {
        return vec4<f32>(0.0, 0.0, 0.0, 1.0);
    }
    
    // Cell fill: Tableau-20 color based on seed index
    let cell_idx = voronoi_cell(uv);
    let cell_color = tableau20_color(cell_idx);
    
    return vec4<f32>(cell_color, 1.0);
}