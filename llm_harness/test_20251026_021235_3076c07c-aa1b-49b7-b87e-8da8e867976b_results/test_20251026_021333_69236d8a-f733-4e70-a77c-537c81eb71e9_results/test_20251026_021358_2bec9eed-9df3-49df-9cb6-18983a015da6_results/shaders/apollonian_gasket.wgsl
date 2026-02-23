// Apollonian Gasket - Rank-2 Kleinian Group Limit Set
// Möbius generators with red/green parity coloring and bloom

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
    _padding: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

// Möbius transformation: (az + b) / (cz + d)
fn mobius(z: vec2<f32>, a: vec2<f32>, b: vec2<f32>, c: vec2<f32>, d: vec2<f32>) -> vec2<f32> {
    let numerator = complex_add(complex_mult(a, z), b);
    let denominator = complex_add(complex_mult(c, z), d);
    return complex_div(numerator, denominator);
}

fn complex_mult(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

fn complex_add(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    return a + b;
}

fn complex_div(a: vec2<f32>, b: vec2<f32>) -> vec2<f32> {
    let denom = b.x * b.x + b.y * b.y;
    return vec2<f32>(
        (a.x * b.x + a.y * b.y) / denom,
        (a.y * b.x - a.x * b.y) / denom
    );
}

// M1(z) = (2z + 1)/(z + 1)
fn gen_m1(z: vec2<f32>) -> vec2<f32> {
    return mobius(z, vec2<f32>(2.0, 0.0), vec2<f32>(1.0, 0.0), 
                       vec2<f32>(1.0, 0.0), vec2<f32>(1.0, 0.0));
}

// M2(z) = (2z - 1)/(z - 1)
fn gen_m2(z: vec2<f32>) -> vec2<f32> {
    return mobius(z, vec2<f32>(2.0, 0.0), vec2<f32>(-1.0, 0.0),
                       vec2<f32>(1.0, 0.0), vec2<f32>(-1.0, 0.0));
}

// Pseudo-random generator using PCG
fn pcg_hash(seed: u32) -> u32 {
    var x = seed;
    x = x ^ (x >> 16u);
    x = x * 0x7feb352du;
    x = x ^ (x >> 15u);
    x = x * 0x846ca68bu;
    x = x ^ (x >> 16u);
    return x;
}

fn rand_float(seed: u32) -> f32 {
    return f32(pcg_hash(seed)) / 4294967296.0;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Accumulator for orbit points
    var red_accum = 0.0;
    var green_accum = 0.0;
    
    // Seed based on pixel position + time
    let base_seed = u32(pos.x) * 2654435761u ^ u32(pos.y) * 2246822519u;
    
    // 16 random walks per pixel
    for (var walk = 0u; walk < 16u; walk = walk + 1u) {
        var seed = base_seed ^ (walk * 0x9e3779b1u);
        
        // Start at z0 = 0
        var z = vec2<f32>(0.0, 0.0);
        
        // Burn-in: 12 iterations
        for (var i = 0u; i < 12u; i = i + 1u) {
            let coin = rand_float(seed);
            seed = pcg_hash(seed);
            
            if (coin < 0.5) {
                z = gen_m1(z);
            } else {
                z = gen_m2(z);
            }
        }
        
        // Collect 9 iterations with parity coloring
        for (var depth = 0u; depth < 9u; depth = depth + 1u) {
            let coin = rand_float(seed);
            seed = pcg_hash(seed);
            
            if (coin < 0.5) {
                z = gen_m1(z);
            } else {
                z = gen_m2(z);
            }
            
            // Parity: even depth → red, odd depth → green
            let is_even_depth = (depth % 2u) == 0u;
            
            // Gaussian kernel around orbit point
            let dist_sq = dot(z - uv, z - uv);
            let kernel = exp(-dist_sq * 50.0);
            
            if (is_even_depth) {
                red_accum = red_accum + kernel * 0.0625;
            } else {
                green_accum = green_accum + kernel * 0.0625;
            }
        }
    }
    
    // Boost and apply bloom
    red_accum = red_accum * 2.0;
    green_accum = green_accum * 2.0;
    
    // Clamp
    red_accum = min(red_accum, 1.0);
    green_accum = min(green_accum, 1.0);
    
    // Red (#ff3355) and Green (#33ff55) colors
    let red_color = vec3<f32>(1.0, 0.2, 0.33);
    let green_color = vec3<f32>(0.2, 1.0, 0.33);
    
    let final_color = red_accum * red_color + green_accum * green_color;
    
    // Additive glow
    let glow = (red_accum + green_accum) * 0.2;
    let color_with_glow = final_color + glow * vec3<f32>(1.0, 1.0, 1.0);
    
    return vec4<f32>(color_with_glow, 1.0);
}