// Al-Khwarizmi's Geometric Solution to Quadratic Equations
// Visualization of x² + 10x = 39 solved geometrically
// Historical inspiration: House of Wisdom, Baghdad, 9th century

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
}

@group(0) @binding(0) var<uniform> params: Params;

// Islamic geometric pattern - 8-fold star
fn islamicPattern(uv: vec2<f32>, scale: f32) -> f32 {
    let angle = atan2(uv.y, uv.x);
    let radius = length(uv);
    let pattern = sin(angle * 8.0) * cos(radius * scale);
    return smoothstep(-0.1, 0.1, pattern);
}

// Draw rectangle with fill
fn drawRect(uv: vec2<f32>, center: vec2<f32>, size: vec2<f32>) -> f32 {
    let p = abs(uv - center);
    let d = p - size * 0.5;
    let outside = length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0);
    return smoothstep(0.01, -0.01, outside);
}

// Draw rectangle outline only
fn drawRectOutline(uv: vec2<f32>, center: vec2<f32>, size: vec2<f32>) -> f32 {
    let p = abs(uv - center);
    let d = p - size * 0.5;
    let outside = length(max(d, vec2<f32>(0.0))) + min(max(d.x, d.y), 0.0);
    let stroke = 0.005;
    return smoothstep(stroke, -stroke, abs(outside) - stroke);
}

// Linear interpolation for animation
fn animationPhase(t: f32, phase: f32, duration: f32) -> f32 {
    let elapsed = (t - phase) % (duration + 1.0);
    return select(0.0, min(1.0, elapsed / duration), t >= phase);
}

@fragment
fn fs_main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let uv = (pos.xy - params.resolution * 0.5) / min(params.resolution.x, params.resolution.y);
    
    // Background: traditional Islamic manuscript color
    var result = vec3<f32>(0.9961, 0.9529, 0.7843); // #FEF3C7
    
    // Animation timing
    let t = params.time * 0.2;
    
    // Animation phases (5 steps over ~5 seconds)
    let phase1 = animationPhase(t, 0.0, 1.0);   // Draw x² square
    let phase2 = animationPhase(t, 1.0, 1.0);   // Add rectangles
    let phase3 = animationPhase(t, 2.0, 1.0);   // Add corner squares
    let phase4 = animationPhase(t, 3.0, 1.0);   // Show completion
    let phase5 = animationPhase(t, 4.0, 1.0);   // Show solution

    // Scale and offset for composition
    let scale = 0.4;
    let offsetY = 0.1;
    
    // Step 1: Central square (x², side = 3)
    let x_val = 3.0;
    let centralPos = vec2<f32>(0.0, offsetY);
    let centralSize = vec2<f32>(x_val * scale, x_val * scale);
    
    let centralFill = drawRect(uv, centralPos, centralSize);
    let centralOutline = drawRectOutline(uv, centralPos, centralSize);
    
    // Deep blue for central square (#1E3A8A)
    let deepBlue = vec3<f32>(0.1176, 0.2275, 0.5412);
    result = mix(result, deepBlue, centralFill * phase1);
    result = mix(result, deepBlue * 0.7, centralOutline * phase1 * 0.5);
    
    // Step 2: Four rectangles (x × 2.5 each)
    // Top rectangle
    let rectHeight = 2.5 * scale;
    let rectWidth = x_val * scale;
    let topRectPos = vec2<f32>(0.0, offsetY + x_val * scale * 0.5 + rectHeight * 0.5);
    let topRectSize = vec2<f32>(rectWidth, rectHeight);
    let topRectFill = drawRect(uv, topRectPos, topRectSize);
    
    // Bottom rectangle
    let bottomRectPos = vec2<f32>(0.0, offsetY - x_val * scale * 0.5 - rectHeight * 0.5);
    let bottomRectFill = drawRect(uv, bottomRectPos, topRectSize);
    
    // Left rectangle
    let leftRectPos = vec2<f32>(-x_val * scale * 0.5 - rectHeight * 0.5, offsetY);
    let leftRectSize = vec2<f32>(rectHeight, rectWidth);
    let leftRectFill = drawRect(uv, leftRectPos, leftRectSize);
    
    // Right rectangle
    let rightRectPos = vec2<f32>(x_val * scale * 0.5 + rectHeight * 0.5, offsetY);
    let rightRectFill = drawRect(uv, rightRectPos, leftRectSize);
    
    // Gold for rectangles (#F59E0B)
    let gold = vec3<f32>(0.9608, 0.6196, 0.0392);
    result = mix(result, gold, topRectFill * phase2);
    result = mix(result, gold, bottomRectFill * phase2);
    result = mix(result, gold, leftRectFill * phase2);
    result = mix(result, gold, rightRectFill * phase2);
    
    // Step 3: Four corner squares (2.5 × 2.5 each)
    let cornerSize = vec2<f32>(rectHeight, rectHeight);
    let cornerDist = x_val * scale * 0.5 + rectHeight * 0.5;
    
    // Top-right corner
    let tr_pos = vec2<f32>(cornerDist, offsetY + cornerDist);
    let tr_fill = drawRect(uv, tr_pos, cornerSize);
    
    // Top-left corner
    let tl_pos = vec2<f32>(-cornerDist, offsetY + cornerDist);
    let tl_fill = drawRect(uv, tl_pos, cornerSize);
    
    // Bottom-right corner
    let br_pos = vec2<f32>(cornerDist, offsetY - cornerDist);
    let br_fill = drawRect(uv, br_pos, cornerSize);
    
    // Bottom-left corner
    let bl_pos = vec2<f32>(-cornerDist, offsetY - cornerDist);
    let bl_fill = drawRect(uv, bl_pos, cornerSize);
    
    // White with blue tint for corners
    let cornerColor = vec3<f32>(1.0, 0.9961, 0.9529);
    result = mix(result, cornerColor, (tr_fill + tl_fill + br_fill + bl_fill) * phase3);
    
    // Draw outlines for corner squares
    let cornerOutlineColor = deepBlue;
    let tr_outline = drawRectOutline(uv, tr_pos, cornerSize);
    let tl_outline = drawRectOutline(uv, tl_pos, cornerSize);
    let br_outline = drawRectOutline(uv, br_pos, cornerSize);
    let bl_outline = drawRectOutline(uv, bl_pos, cornerSize);
    result = mix(result, cornerOutlineColor, (tr_outline + tl_outline + br_outline + bl_outline) * phase3 * 0.7);
    
    // Step 4: Highlight the complete square
    let completedSquareSize = vec2<f32>((x_val + 5.0) * scale, (x_val + 5.0) * scale);
    let completedOutline = drawRectOutline(uv, centralPos, completedSquareSize);
    let highlightColor = vec3<f32>(0.8, 0.4, 0.0); // Orange highlight
    result = mix(result, highlightColor, completedOutline * phase4 * 0.6);
    
    // Step 5: Display solution text region (x = 3)
    let solutionY = offsetY - (x_val + 5.0) * scale * 0.5 - 0.15;
    let textBoxSize = vec2<f32>(0.3, 0.08);
    let textBoxPos = vec2<f32>(0.0, solutionY);
    let textBoxOutline = drawRectOutline(uv, textBoxPos, textBoxSize);
    
    // Ornate frame color for solution
    let ornateGold = vec3<f32>(1.0, 0.8431, 0.0);
    result = mix(result, ornateGold, textBoxOutline * phase5 * 0.8);
    
    // Islamic pattern decoration (corners and margins)
    let patternScale = 15.0;
    let patternIntensity = 0.15;
    
    // Top-right corner pattern
    let tr_uv = uv - vec2<f32>(0.8, 0.85);
    let tr_pattern = islamicPattern(tr_uv, patternScale);
    result = mix(result, deepBlue, tr_pattern * patternIntensity);
    
    // Bottom-left corner pattern
    let bl_uv = uv - vec2<f32>(-0.8, -0.85);
    let bl_pattern = islamicPattern(bl_uv, patternScale);
    result = mix(result, deepBlue, bl_pattern * patternIntensity);
    
    // Decorative border
    let borderDist = min(
        min(abs(uv.x) - 0.95, abs(uv.y) - 0.95),
        min(1.0 - abs(uv.x), 1.0 - abs(uv.y))
    );
    let border = smoothstep(0.02, -0.02, borderDist);
    let borderColor = deepBlue * 0.5;
    result = mix(result, borderColor, border * 0.4);
    
    return vec4<f32>(result, 1.0);
}