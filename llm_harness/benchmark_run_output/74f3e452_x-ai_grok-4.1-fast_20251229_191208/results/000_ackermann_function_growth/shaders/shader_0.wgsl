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
    aspect: f32,
};

@group(0) @binding(0) var<uniform> params: Params;

const LOG10_2: f32 = 0.3010299956639812;
const FIRST_CENTER: f32 = 400.0;
const BAR_SPACING: f32 = 80.0;
const BAR_HALF_WIDTH: f32 = 20.0;
const ROUND_R: f32 = 10.0;
const PLOT_TOP: f32 = 50.0;
const BOTTOM_MARGIN: f32 = 200.0;
const TOWER_SPACING: f32 = 13.0;
const NUM_BARS: u32 = 11u;
const NUM_DECADES: u32 = 11u;

fn get_log_height(n: u32) -> f32 {
    switch(n) {
        case 0u => { 0.0 },
        case 1u => { 0.30103 },
        case 2u => { 0.47712 },
        case 3u => { 1.11394 },
        case 4u => { 4.81648 },
        case 5u => { 65536.0 * LOG10_2 },
        case 6u => { 3.4028235e+38 },
        case 7u => { 3.4028235e+38 },
        case 8u => { 3.4028235e+38 },
        case 9u => { 3.4028235e+38 },
        case 10u => { 3.4028235e+38 },
        default => { 0.0 },
    }
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let screen: vec2<f32> = pos.xy;
    let res: vec2<f32> = params.resolution;
    let w: f32 = res.x;
    let h: f32 = res.y;

    let plot_bottom: f32 = h - BOTTOM_MARGIN;
    let plot_height: f32 = plot_bottom - PLOT_TOP;
    let px_per_log: f32 = plot_height / 10.0;
    let plot_left: f32 = FIRST_CENTER - 30.0;
    let plot_right: f32 = FIRST_CENTER + BAR_SPACING * 10.0 + 30.0;

    var color: vec3<f32> = vec3<f32>(1.0);

    // Grid lines (horizontal decades)
    for(var k: u32 = 0u; k < NUM_DECADES; k = k + 1u) {
        let log_k: f32 = f32(k);
        let grid_y: f32 = plot_bottom - log_k * px_per_log;
        let dy: f32 = abs(screen.y - grid_y);
        let is_major: bool = ((k % 5u) == 0u);
        let line_thick: f32 = select(1.5, 0.8, is_major);
        let alpha: f32 = (1.0 - smoothstep(0.0, line_thick, dy)) * (0.2 + 0.1 * log_k / 10.0);
        color = mix(color, vec3<f32>(0.7), alpha);
    }

    // Y-axis (vertical)
    let axis_dx: f32 = abs(screen.x - plot_left);
    let axis_dy_range: f32 = min(screen.y - PLOT_TOP, plot_bottom - screen.y);
    let axis_d: f32 = sqrt(axis_dx * axis_dx + axis_dy_range * axis_dy_range);
    let axis_alpha: f32 = (1.0 - smoothstep(0.0, 2.0, axis_d)) * 0.6;
    color = mix(color, vec3<f32>(0.0), axis_alpha);

    // X-axis (horizontal)
    let xaxis_dy: f32 = abs(screen.y - plot_bottom);
    let xaxis_in_range: f32 = select(0.0, 1.0, screen.x >= plot_left && screen.x <= plot_right);
    let xaxis_alpha: f32 = (1.0 - smoothstep(0.0, 2.0, xaxis_dy)) * 0.6 * xaxis_in_range;
    color = mix(color, vec3<f32>(0.0), xaxis_alpha);

    // Bars
    let offset_x: f32 = screen.x - FIRST_CENTER;
    let bar_n_float: f32 = offset_x / BAR_SPACING;
    let bar_n: u32 = u32(floor(bar_n_float + 0.5));
    let frac: f32 = fract(bar_n_float);
    let local_x: f32 = (frac - 0.5) * BAR_SPACING;
    let in_bar_x: bool = abs(local_x) <= BAR_HALF_WIDTH;
    let valid_n: bool = bar_n <= 10u;
    if (valid_n && in_bar_x) {
        let cx: f32 = FIRST_CENTER + BAR_SPACING * f32(bar_n);
        let log_h: f32 = get_log_height(bar_n);
        let frac_h: f32 = min(log_h / 10.0, 1.0);
        let bar_h_px: f32 = frac_h * plot_height;
        let bar_center_y: f32 = plot_bottom - bar_h_px * 0.5;
        let p: vec2<f32> = screen.xy - vec2<f32>(cx, bar_center_y);
        let q: vec2<f32> = abs(p) - vec2<f32>(BAR_HALF_WIDTH, bar_h_px * 0.5) + vec2<f32>(ROUND_R);
        let dist: f32 = min(max(q.x, q.y), 0.0) + length(max(q, vec2<f32>(0.0))) - ROUND_R;
        let bar_fill: f32 = 1.0 - smoothstep(0.0, 1.5, dist);
        let t: f32 = f32(bar_n) / 10.0;
        let bar_blue: vec3<f32> = vec3<f32>(0.0, 0.2, 0.8);
        let bar_red: vec3<f32> = vec3<f32>(1.0, 0.2, 0.0);
        var bar_col: vec3<f32> = mix(bar_blue, bar_red, t);
        let clipped_dark: f32 = smoothstep(8.5, 10.0, log_h);
        bar_col *= (1.0 - 0.4 * clipped_dark);
        color = mix(color, bar_col, bar_fill);
    }

    // Exponent-tower annotations (stacked circles representing tower height n)
    for(var bn: u32 = 0u; bn < NUM_BARS; bn = bn + 1u) {
        let cx: f32 = FIRST_CENTER + BAR_SPACING * f32(bn);
        let tower_bot: f32 = plot_bottom + 20.0;
        let num_levels: u32 = bn;
        for(var lvl: u32 = 0u; lvl <= 10u; lvl = lvl + 1u) {
            if (lvl >= num_levels) {
                break;
            }
            let level_frac: f32 = f32(lvl) / f32(num_levels);
            let circ_r: f32 = mix(7.0, 2.5, level_frac);
            let circ_y: f32 = tower_bot - f32(lvl + 1u) * TOWER_SPACING;
            let tower_d: f32 = length(screen.xy - vec2<f32>(cx, circ_y)) - circ_r;
            let tower_fill: f32 = 1.0 - smoothstep(0.0, 1.0, tower_d);
            color = mix(color, vec3<f32>(0.1), tower_fill * 0.9);
        }
    }

    return vec4<f32>(color, 1.0);
}