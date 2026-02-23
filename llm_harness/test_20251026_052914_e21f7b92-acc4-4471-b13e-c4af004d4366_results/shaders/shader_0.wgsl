// Number Theory as 3D Musical Score Sculpture
// Mathematical properties → Musical elements in crystalline space

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

// Prime factorization helper - count factors of p in n
fn countPrimeFactor(n_val: u32, p: u32) -> u32 {
    var n = n_val;
    var count = 0u;
    var divisor = p;
    loop {
        if (n % divisor != 0u) { break; }
        count = count + 1u;
        n = n / divisor;
        if (count > 32u) { break; }
    }
    return count;
}

// Euler's totient approximation
fn totient(n_val: u32) -> u32 {
    var result = n_val;
    var n = n_val;
    var p = 2u;
    loop {
        if (p * p > n) { break; }
        if (n % p == 0u) {
            while (n % p == 0u) {
                n = n / p;
            }
            result = result - result / p;
        }
        p = p + 1u;
        if (p > 100u) { break; }
    }
    if (n > 1u) {
        result = result - result / n;
    }
    return max(result, 1u);
}

// GCD for harmonic intervals
fn gcd(a: u32, b: u32) -> u32 {
    var x = a;
    var y = b;
    loop {
        if (y == 0u) { break; }
        let temp = y;
        y = x % y;
        x = temp;
    }
    return x;
}

// Collatz sequence step
fn collatz_step(n: u32) -> u32 {
    return select(n / 2u, 3u * n + 1u, (n % 2u) == 1u);
}

// Fibonacci number detection and spiral position
fn fib_spiral_angle(n: u32) -> f32 {
    var a = 0u;
    var b = 1u;
    var fib_index = 0u;
    loop {
        if (b > n || fib_index > 50u) { break; }
        let temp = a + b;
        a = b;
        b = temp;
        fib_index = fib_index + 1u;
    }
    return f32(fib_index) * 0.4 + sin(f32(n) * 0.01) * 0.3;
}

// Perfect number check (only 6, 28, 496, 8128 in reasonable range)
fn is_perfect(n: u32) -> f32 {
    let cond = select(0.0, 1.0, n == 6u || n == 28u || n == 496u);
    return cond;
}

// Main rendering function
@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / params.resolution.y;
    
    // Initialize accumulator
    var final_color = vec3<f32>(0.02, 0.01, 0.05); // Dark concert hall ambiance
    
    // Iterate through number range as musical phrases
    var n_idx = 1u;
    loop {
        if (n_idx > 120u) { break; }
        
        let n_float = f32(n_idx);
        
        // ========== PRIME FACTORIZATION RHYTHM ==========
        // Each prime gets instrument track at height z = log(p)
        let exp2 = countPrimeFactor(n_idx, 2u);
        let exp3 = countPrimeFactor(n_idx, 3u);
        let exp5 = countPrimeFactor(n_idx, 5u);
        
        // Staff lines from prime factors (glass tubes)
        let staff_2 = 0.69;  // log(2)
        let staff_3 = 1.10;  // log(3)
        let staff_5 = 1.61;  // log(5)
        
        // Exponent determines note duration width
        let note_width_2 = f32(exp2) * 0.015 + 0.01;
        let note_width_3 = f32(exp3) * 0.015 + 0.01;
        let note_width_5 = f32(exp5) * 0.015 + 0.01;
        
        // Note positions along timeline (left to right)
        let time_pos = (n_float - 60.0) / 40.0;
        
        // ========== MODULAR ARITHMETIC MELODY ==========
        // n mod 12 = chromatic scale
        let chromatic = n_idx % 12u;
        let octave = u32(log2(f32(n_idx)) + 0.1);
        
        // Pitch height from chromatic + octave
        let pitch_height = f32(chromatic) * 0.08 + f32(octave) * 0.2 - 0.8;
        
        // ========== FIBONACCI SPIRAL ==========
        let fib_angle = fib_spiral_angle(n_idx);
        let spiral_r = f32(n_idx) * 0.008;
        let spiral_x = spiral_r * cos(fib_angle);
        let spiral_y = spiral_r * sin(fib_angle);
        
        // Golden ribbon color
        let fib_glow = smoothstep(0.15, 0.0, length(uv - vec2<f32>(spiral_x, spiral_y)));
        final_color = mix(final_color, vec3<f32>(1.0, 0.84, 0.0), fib_glow * 0.6);
        
        // ========== HARMONIC FUNCTION COLORING ==========
        // Tonic (blue): fundamental, divisors of n
        // Dominant (yellow): n % 7 == 0
        // Subdominant (green): n % 5 == 0
        
        let is_dominant = select(0.0, 1.0, n_idx % 7u == 0u);
        let is_subdominant = select(0.0, 1.0, n_idx % 5u == 0u);
        let is_tonic = select(0.0, 1.0, n_idx % 12u == 0u || is_perfect(f32(n_idx)) > 0.5);
        
        // ========== CRYSTAL POLYHEDRA NOTES ==========
        // Shape from prime factors, positioned at pitch_height, time_pos
        let note_pos = vec2<f32>(time_pos, pitch_height);
        let dist_to_note = length(uv - note_pos);
        
        // Crystalline appearance: scale by totient
        let phi = totient(n_idx);
        let crystal_size = 0.02 + f32(phi) * 0.001;
        let crystal_shine = smoothstep(crystal_size * 1.5, crystal_size * 0.5, dist_to_note);
        
        // Note color by harmonic function
        var note_color = vec3<f32>(0.2, 0.3, 1.0); // Tonic blue
        note_color = mix(note_color, vec3<f32>(1.0, 1.0, 0.2), is_dominant);  // Dominant yellow
        note_color = mix(note_color, vec3<f32>(0.2, 1.0, 0.3), is_subdominant); // Subdominant green
        
        // Glow/highlight for perfect numbers
        let perfect_boost = is_perfect(f32(n_idx)) * 0.8;
        final_color = mix(final_color, note_color, crystal_shine * (0.7 + perfect_boost));
        
        // ========== COLLATZ CHAOS PERCUSSION ==========
        let collatz_state = collatz_step(n_idx);
        let collatz_chaos = f32(collatz_state % 13u) * 0.077; // Lightning effect
        let chaos_dist = abs(uv.x - collatz_chaos * 0.5) + abs(uv.y - pitch_height) * 0.5;
        let chaos_strike = exp(-chaos_dist * chaos_dist * 30.0);
        final_color = mix(final_color, vec3<f32>(1.0, 0.7, 0.3), chaos_strike * 0.4);
        
        // ========== STAFF LINES (GLASS TUBES) ==========
        let staff_dist_2 = abs(uv.y - staff_2);
        let staff_dist_3 = abs(uv.y - staff_3);
        let staff_dist_5 = abs(uv.y - staff_5);
        
        let staff_glow = smoothstep(0.005, 0.0, staff_dist_2) * 0.15
                       + smoothstep(0.005, 0.0, staff_dist_3) * 0.12
                       + smoothstep(0.005, 0.0, staff_dist_5) * 0.10;
        final_color = mix(final_color, vec3<f32>(0.3, 0.5, 0.8), staff_glow);
        
        // ========== SOUND WAVE PARTICLES ==========
        let wave_freq = f32(exp2) + 0.5;
        let wave_phase = n_float * 0.05 - uv.x * 8.0;
        let soundwave = sin(wave_phase * wave_freq) * cos(uv.y * 5.0);
        let particle_intensity = smoothstep(-0.3, 0.3, soundwave) * 0.2;
        final_color = mix(final_color, vec3<f32>(0.5, 0.8, 1.0), particle_intensity);
        
        // ========== GCD HARMONIC INTERVALS ==========
        let prev_n = select(n_idx - 1u, 1u, n_idx > 1u);
        let interval = gcd(n_idx, prev_n);
        let harmonic_strength = f32(interval) / f32(max(n_idx, prev_n));
        let harmonic_color = vec3<f32>(harmonic_strength, 0.5, 1.0 - harmonic_strength);
        final_color = mix(final_color, harmonic_color, harmonic_strength * 0.1);
        
        n_idx = n_idx + 1u;
    }
    
    // ========== SPOTLIGHT EFFECT ==========
    // Bright center, darker edges (concert hall atmosphere)
    let vignette = 1.0 - length(uv) * 0.4;
    final_color = final_color * vignette;
    
    // ========== DEPTH OF FIELD BOKEH ==========
    let bokeh_pos = vec2<f32>(sin(uv.x * 3.0) * 0.3, cos(uv.y * 3.0) * 0.3);
    let bokeh_dist = length(uv - bokeh_pos);
    let bokeh = exp(-bokeh_dist * bokeh_dist * 2.0) * 0.1;
    final_color = final_color + bokeh;
    
    // ========== FINAL TONE MAPPING ==========
    final_color = final_color / (final_color + vec3<f32>(1.0));
    final_color = pow(final_color, vec3<f32>(0.45)); // Gamma correction for sRGB
    
    return vec4<f32>(final_color, 1.0);
}