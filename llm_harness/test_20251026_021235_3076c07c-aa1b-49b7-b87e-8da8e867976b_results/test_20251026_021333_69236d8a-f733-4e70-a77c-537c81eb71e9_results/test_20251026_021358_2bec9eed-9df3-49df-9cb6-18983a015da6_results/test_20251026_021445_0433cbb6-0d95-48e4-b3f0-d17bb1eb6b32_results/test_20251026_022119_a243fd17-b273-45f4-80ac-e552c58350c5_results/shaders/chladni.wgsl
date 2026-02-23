// Chladni Pattern Visualization - (4,3) Mode
// Physical simulation of standing waves on a vibrating square plate
// Sand accumulates at nodal lines (zero displacement regions)

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

// Constants for Chladni pattern
const PI: f32 = 3.14159265359;
const L: f32 = 2.0;
const N_MODE: i32 = 4;
const M_MODE: i32 = 3;
const BEIGE_NODAL: vec3<f32> = vec3<f32>(0.8314, 0.6549, 0.4549);
const BLUE_DARK: vec3<f32> = vec3<f32>(0.0, 0.4, 0.8);
const BLUE_LIGHT: vec3<f32> = vec3<f32>(0.0, 0.8, 1.0);
const RED_DARK: vec3<f32> = vec3<f32>(0.8, 0.0, 0.0);
const RED_LIGHT: vec3<f32> = vec3<f32>(1.0, 0.4, 0.4);
const SAND_COLOR: vec3<f32> = vec3<f32>(0.5451, 0.4353, 0.2784);
const BEIGE_BG: vec3<f32> = vec3<f32>(0.9608, 0.9608, 0.8627);
const BLACK_FRAME: vec3<f32> = vec3<f32>(0.0, 0.0, 0.0);
const NODAL_THRESHOLD: f32 = 0.01;

fn chladni_amplitude(x: f32, y: f32) -> f32 {
    let n_f = f32(N_MODE);
    let m_f = f32(M_MODE);
    let sin_nx = sin(n_f * PI * (x + 1.0) / L);
    let sin_my = sin(m_f * PI * (y + 1.0) / L);
    return sin_nx * sin_my;
}

fn hash_vec2(v: vec2<f32>) -> f32 {
    let h = dot(v, vec2<f32>(12.9898, 78.233));
    return fract(sin(h) * 43758.5453);
}

fn particle_position(particle_id: f32) -> vec2<f32> {
    let seed = particle_id * 73.156;
    let u1 = hash_vec2(vec2<f32>(seed, seed + 1.0));
    let u2 = hash_vec2(vec2<f32>(seed + 2.0, seed + 3.0));
    
    var pos = vec2<f32>(u1 * 2.0 - 1.0, u2 * 2.0 - 1.0);
    
    for (var i: i32 = 0; i < 6; i = i + 1) {
        let amp = chladni_amplitude(pos.x, pos.y);
        let eps = 0.002;
        let damp_dx = (chladni_amplitude(pos.x + eps, pos.y) - amp) / eps;
        let damp_dy = (chladni_amplitude(pos.x, pos.y + eps) - amp) / eps;
        
        let grad_len = sqrt(damp_dx * damp_dx + damp_dy * damp_dy) + 1e-6;
        pos = pos - vec2<f32>(damp_dx, damp_dy) / (grad_len * 40.0);
        pos = clamp(pos, vec2<f32>(-1.0, -1.0), vec2<f32>(1.0, 1.0));
    }
    
    return pos;
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = pos.xy / params.resolution;
    let x = uv.x * 2.0 - 1.0;
    let y = uv.y * 2.0 - 1.0;
    
    let frame_width = 5.0 / params.resolution.x;
    let is_frame = (x < -1.0 + frame_width) || (x > 1.0 - frame_width) ||
                   (y < -1.0 + frame_width) || (y > 1.0 - frame_width);
    
    var final_color = BEIGE_BG;
    
    if is_frame {
        final_color = BLACK_FRAME;
    } else {
        let amplitude = chladni_amplitude(x, y);
        let abs_amp = abs(amplitude);
        
        if abs_amp < NODAL_THRESHOLD {
            final_color = BEIGE_NODAL;
            
            for (var p: i32 = 0; p < 10; p = p + 1) {
                let particle_pos = particle_position(f32(p) + abs_amp * 100.0);
                let dist_to_particle = length(vec2<f32>(x, y) - particle_pos);
                let particle_influence = exp(-dist_to_particle * 80.0);
                
                let sand_contrib = SAND_COLOR * particle_influence * 0.25;
                final_color = mix(final_color, sand_contrib, particle_influence * 0.35);
            }
        } else if amplitude > 0.0 {
            let intensity = clamp(amplitude * 4.5, 0.0, 1.0);
            final_color = mix(BLUE_DARK, BLUE_LIGHT, smoothstep(0.0, 1.0, intensity));
        } else {
            let intensity = clamp(-amplitude * 4.5, 0.0, 1.0);
            final_color = mix(RED_DARK, RED_LIGHT, smoothstep(0.0, 1.0, intensity));
        }
        
        let height_factor = abs_amp * 0.25;
        let shadow_intensity = 0.06 * height_factor;
        final_color = final_color * (1.0 - shadow_intensity);
    }
    
    return vec4<f32>(final_color, 1.0);
}