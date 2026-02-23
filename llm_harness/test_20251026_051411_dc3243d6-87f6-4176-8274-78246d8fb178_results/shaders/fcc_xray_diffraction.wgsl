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

// Compute structure factor for FCC (h,k,0) reflection
// FCC scatterers: (0,0,0), (0,1/2,1/2), (1/2,0,1/2), (1/2,1/2,0)
fn compute_structure_factor(h: i32, k: i32) -> vec2<f32> {
    var f_real = 0.0;
    var f_imag = 0.0;
    
    let pi2 = 6.28318530718;
    
    // Scatterer 1: (0,0,0)
    f_real = f_real + 1.0;
    f_imag = f_imag + 0.0;
    
    // Scatterer 2: (0,1/2,1/2)
    let phase2 = pi2 * (f32(k) * 0.5 + 0.0 * 0.5);
    f_real = f_real + cos(phase2);
    f_imag = f_imag + sin(phase2);
    
    // Scatterer 3: (1/2,0,1/2)
    let phase3 = pi2 * (f32(h) * 0.5 + 0.0 * 0.5);
    f_real = f_real + cos(phase3);
    f_imag = f_imag + sin(phase3);
    
    // Scatterer 4: (1/2,1/2,0)
    let phase4 = pi2 * (f32(h) * 0.5 + f32(k) * 0.5);
    f_real = f_real + cos(phase4);
    f_imag = f_imag + sin(phase4);
    
    return vec2<f32>(f_real, f_imag);
}

// Compute intensity from structure factor
fn compute_intensity(h: i32, k: i32) -> f32 {
    let f_hk = compute_structure_factor(h, k);
    let intensity = f_hk.x * f_hk.x + f_hk.y * f_hk.y;
    return intensity;
}

// Distance from point to disk center
fn distance_to_disk(pixel_pos: vec2<f32>, disk_center: vec2<f32>) -> f32 {
    return length(pixel_pos - disk_center);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let pixel_pos = pos.xy;
    let canvas_size = 1800.0;
    let canvas_center = vec2<f32>(canvas_size * 0.5, canvas_size * 0.5);
    
    // Normalize to reciprocal space coordinates centered at origin
    let q_pos = pixel_pos - canvas_center;
    
    // Scale factor: (20,0) spot sits at 90% of radius from center
    // Radius = 900 px * 0.9 = 810 px for (20,0)
    // Therefore: 1 reciprocal lattice unit ≈ 40.5 px
    let scale_factor = 40.5;
    
    var final_color = vec3<f32>(0.0, 0.0, 0.0); // Black background
    var max_intensity_found = 0.0;
    
    // Iterate over all integer Miller indices (h,k,0) with ||G|| <= 20
    for (var h: i32 = -20; h <= 20; h = h + 1) {
        for (var k: i32 = -20; k <= 20; k = k + 1) {
            let g_mag_sq = f32(h * h + k * k);
            
            // Skip if outside reciprocal space cutoff
            if (g_mag_sq > 400.0) {
                continue;
            }
            
            // Skip (0,0) direct beam
            if (h == 0 && k == 0) {
                continue;
            }
            
            // FCC selection rule: h+k must be even
            let sum_hk = (h + k) % 2;
            if (sum_hk != 0) {
                continue;
            }
            
            // Compute intensity
            let intensity = compute_intensity(h, k);
            
            // Disk center in pixel coordinates
            let disk_center = canvas_center + vec2<f32>(f32(h), f32(k)) * scale_factor;
            
            // Disk radius = 4 + ||G||/6 pixels
            let g_mag = sqrt(g_mag_sq);
            let disk_radius = 4.0 + g_mag / 6.0;
            
            // Distance from current pixel to disk center
            let dist = distance_to_disk(q_pos, disk_center - canvas_center);
            
            // If inside disk, compute contribution
            if (dist <= disk_radius) {
                // Linear intensity mapping: 0 → black, max → white
                // Maximum possible intensity for FCC: |F|_max = 4 (all phases aligned)
                let max_possible_intensity = 16.0; // 4^2
                let normalized_intensity = min(intensity / max_possible_intensity, 1.0);
                
                // Update pixel color (greyscale)
                final_color = vec3<f32>(normalized_intensity, normalized_intensity, normalized_intensity);
                max_intensity_found = max(max_intensity_found, normalized_intensity);
            }
        }
    }
    
    return vec4<f32>(final_color, 1.0);
}