// RGB Interference Pattern: Two Coherent Plane Waves at 20° Angle
// Physical model:
//   Wave 1: k₁ = (0, 0, 2π/λ)
//   Wave 2: k₂ = (sin(10°), 0, cos(10°)) × 2π/λ
//   λ_R = 650nm, λ_G = 510nm, λ_B = 460nm
//   Domain: x,y ∈ [-5λ_G, +5λ_G]
//   Intensity: I_c = |E_c|² where E_c = exp(i·k₁·r) + exp(i·k₂·r)

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

// Compute intensity for a single color channel
// Returns |exp(i·k₁·r) + exp(i·k₂·r)|²
fn compute_intensity(pos: vec2<f32>, k1_z: f32, k2_x: f32, k2_z: f32) -> f32 {
    // Wave 1: exp(i·k₁·r) = exp(i·k₁_z·0) = 1 (z=0 at screen)
    let e1_real = 1.0;
    let e1_imag = 0.0;

    // Wave 2: exp(i·k₂·r) = exp(i·(k₂_x·x + k₂_z·0)) = cos(k₂_x·x) + i·sin(k₂_x·x)
    let phase2 = k2_x * pos.x;
    let e2_real = cos(phase2);
    let e2_imag = sin(phase2);

    // Sum: E = E₁ + E₂
    let e_real = e1_real + e2_real;
    let e_imag = e1_imag + e2_imag;

    // Intensity: I = |E|² = E_real² + E_imag²
    let intensity = e_real * e_real + e_imag * e_imag;
    return intensity;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    // Wavelengths in nm
    let lambda_r = 650.0;
    let lambda_g = 510.0;
    let lambda_b = 460.0;

    // Normalization factor: domain half-width in wavelengths
    let domain_half_width = 5.0 * lambda_g;

    // Convert screen coordinates to physical coordinates
    // Screen spans [-1, 1] in each dimension; map to [-5λ_G, +5λ_G]
    let uv = (pos.xy / params.resolution) * 2.0 - 1.0;
    let phys_pos = uv * domain_half_width;

    // Wave vector magnitudes: |k| = 2π/λ
    let k_mag_r = 6.283185307179586 / lambda_r;  // 2π/650
    let k_mag_g = 6.283185307179586 / lambda_g;  // 2π/510
    let k_mag_b = 6.283185307179586 / lambda_b;  // 2π/460

    // Angle = 20°, so each wave deviates by 10° from z-axis
    let angle_rad = 0.1745329251994329;  // 10° in radians
    let sin_angle = sin(angle_rad);      // sin(10°) ≈ 0.1736
    let cos_angle = cos(angle_rad);      // cos(10°) ≈ 0.9848

    // Wave 1: k₁ = (0, 0, 2π/λ)
    // Wave 2: k₂ = (sin(10°), 0, cos(10°)) × 2π/λ
    // At z=0 screen: k₁·r = 0, k₂·r = sin(10°) × 2π/λ × x

    // Compute intensities for each channel
    let k2_x_r = sin_angle * k_mag_r;
    let k2_z_r = cos_angle * k_mag_r;
    let intensity_r = compute_intensity(phys_pos, k_mag_r, k2_x_r, k2_z_r);

    let k2_x_g = sin_angle * k_mag_g;
    let k2_z_g = cos_angle * k_mag_g;
    let intensity_g = compute_intensity(phys_pos, k_mag_g, k2_x_g, k2_z_g);

    let k2_x_b = sin_angle * k_mag_b;
    let k2_z_b = cos_angle * k_mag_b;
    let intensity_b = compute_intensity(phys_pos, k_mag_b, k2_x_b, k2_z_b);

    // Find maximum intensities for normalization
    let max_intensity_r = 4.0;  // Maximum: |1 + 1|² = 4
    let max_intensity_g = 4.0;
    let max_intensity_b = 4.0;

    // Normalize to [0, 1]
    let norm_r = intensity_r / max_intensity_r;
    let norm_g = intensity_g / max_intensity_g;
    let norm_b = intensity_b / max_intensity_b;

    // Clamp to valid range
    let clamped_r = clamp(norm_r, 0.0, 1.0);
    let clamped_g = clamp(norm_g, 0.0, 1.0);
    let clamped_b = clamp(norm_b, 0.0, 1.0);

    // Apply sRGB gamma correction: linear → sRGB
    let gamma = 1.0 / 2.2;
    let srgb_r = pow(clamped_r, gamma);
    let srgb_g = pow(clamped_g, gamma);
    let srgb_b = pow(clamped_b, gamma);

    // Return color
    return vec4<f32>(srgb_r, srgb_g, srgb_b, 1.0);
}