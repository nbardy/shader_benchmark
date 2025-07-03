# Agent1 Shader Programming Challenges
## LLM Code Generation Benchmark - Fragment & Vertex Shaders

**Created by**: Agent1 (Shader Programming Challenge Designer)  
**Focus**: Fragment & Vertex Shader Challenges for LLM Testing  
**Target Difficulty**: Beginner to Advanced  
**Total Challenges**: 100+  

---

## Beginner Fragment Shader Challenges (25 Problems)

### **Problem 001: Solid Color Output**

**Objective**: Create a fragment shader that outputs a solid red color across the entire screen.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Basic color representation in RGB color space

**Inputs**:
- `vec2 fragCoord` - fragment coordinates

**Expected Outputs**:
- Uniform red color (1.0, 0.0, 0.0, 1.0) across all fragments

**Success Criteria**:
- All fragments output exactly red color
- No variation across screen
- Proper alpha channel handling

**Reference Equations** (Context Only):
```
RGB Color: (R, G, B, A) where each component ∈ [0,1]
```

**Tags**: basic, color, beginner

---

### **Problem 002: Gradient Background**

**Objective**: Generate a linear gradient from black at the bottom to white at the top of the screen.

**Shader Type**: Fragment Shader

**Diversity Level**: Beginner

**Mathematical Context**: Linear interpolation and normalized coordinates

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Smooth gradient from black (bottom) to white (top)
- Normalized coordinate usage

**Success Criteria**:
- Gradient is perfectly linear
- Uses normalized screen coordinates
- Smooth transition without banding

**Reference Equations** (Context Only):
```
Linear interpolation: lerp(a,b,t) = a + t(b-a)
Normalized coordinates: uv = fragCoord / resolution
```

**Tags**: gradient, interpolation, coordinates, beginner

---

### **Problem 003: Circle Shape**

**Objective**: Draw a white circle centered on screen with a radius of 0.3 on a black background.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Distance functions and circle equation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Sharp-edged white circle on black background
- Circle centered at (0.5, 0.5) in normalized coordinates
- Radius of 0.3 in normalized space

**Success Criteria**:
- Circle has correct position and size
- Sharp boundary between circle and background
- Proper aspect ratio handling

**Reference Equations** (Context Only):
```
Circle equation: (x-h)² + (y-k)² = r²
Distance from center: d = sqrt((x-cx)² + (y-cy)²)
```

**Tags**: shapes, distance, circle, beginner

---

### **Problem 004: Animated Color Cycle**

**Objective**: Create a fragment shader that cycles through RGB colors over time using sine waves.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Trigonometric functions and time-based animation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - elapsed time in seconds

**Expected Outputs**:
- Smooth color cycling across red, green, blue spectrum
- Animation period of approximately 6 seconds
- Full screen color effect

**Success Criteria**:
- Smooth color transitions without jumps
- Colors cycle through full RGB spectrum
- Consistent animation timing

**Reference Equations** (Context Only):
```
Sine wave: sin(ωt + φ)
Color cycling: R = sin(t), G = sin(t + 2π/3), B = sin(t + 4π/3)
```

**Tags**: animation, trigonometry, color, time, beginner

---

### **Problem 005: Checkerboard Pattern**

**Objective**: Generate a classic 8x8 checkerboard pattern alternating between black and white squares.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Modular arithmetic and pattern generation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- 8x8 grid of alternating black and white squares
- Pattern starts with black square in bottom-left corner
- Perfect square aspect ratio for each checker

**Success Criteria**:
- Exactly 8x8 grid layout
- Sharp transitions between squares
- Correct alternating pattern

**Reference Equations** (Context Only):
```
Grid coordinates: gridPos = floor(uv * 8.0)
Alternating pattern: (int(x) + int(y)) % 2
```

**Tags**: patterns, grid, modular, beginner

---

### **Problem 006: Radial Gradient**

**Objective**: Create a radial gradient emanating from the screen center, transitioning from white at center to black at edges.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Radial distance calculation and gradient mapping

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Circular gradient centered on screen
- White at center, black at maximum distance
- Smooth radial transition

**Success Criteria**:
- Perfect circular symmetry
- Smooth gradient without banding
- Proper normalization to screen bounds

**Reference Equations** (Context Only):
```
Radial distance: r = length(uv - center)
Normalized distance: r_norm = r / max_radius
```

**Tags**: gradient, radial, distance, beginner

---

### **Problem 007: RGB Color Bars**

**Objective**: Display three horizontal bars showing pure red, green, and blue colors from top to bottom.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Conditional color assignment based on screen regions

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Top third: pure red (1,0,0)
- Middle third: pure green (0,1,0)
- Bottom third: pure blue (0,0,1)

**Success Criteria**:
- Equal height for each color bar
- Sharp boundaries between colors
- Correct RGB values

**Reference Equations** (Context Only):
```
Vertical division: y_norm = fragCoord.y / resolution.y
Conditional assignment: if (y < 1/3) red, else if (y < 2/3) green, else blue
```

**Tags**: color, conditional, regions, beginner

---

### **Problem 008: Moving Circle**

**Objective**: Animate a white circle moving horizontally across the screen from left to right, wrapping around.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Time-based position animation and modular wrapping

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- White circle on black background
- Horizontal movement from left to right
- Seamless wrapping at screen edges

**Success Criteria**:
- Smooth horizontal motion
- Consistent circle size and shape
- Proper edge wrapping behavior

**Reference Equations** (Context Only):
```
Position animation: x(t) = x₀ + vt
Modular wrapping: x_wrapped = mod(x, screen_width)
```

**Tags**: animation, movement, time, circle, beginner

---

### **Problem 009: Striped Pattern**

**Objective**: Create vertical stripes alternating between red and white, with 10 stripes total across the screen.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Pattern repetition and color alternation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- 10 vertical stripes across screen width
- Alternating red and white colors
- Equal stripe widths

**Success Criteria**:
- Exactly 10 stripes
- Perfect vertical alignment
- Sharp color transitions

**Reference Equations** (Context Only):
```
Stripe index: stripe = floor(x * stripe_count)
Color alternation: color = (stripe % 2 == 0) ? color1 : color2
```

**Tags**: patterns, stripes, alternation, beginner

---

### **Problem 010: Pulsing Circle**

**Objective**: Create a circle that pulses in size rhythmically, scaling between radius 0.1 and 0.4.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Sinusoidal animation and radius scaling

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- White circle on black background
- Rhythmic size pulsing every 2 seconds
- Centered on screen

**Success Criteria**:
- Smooth size transitions
- Consistent pulsing rhythm
- Proper radius range adherence

**Reference Equations** (Context Only):
```
Pulsing radius: r(t) = r_min + (r_max - r_min) * (sin(ωt) + 1) / 2
Angular frequency: ω = 2π / period
```

**Tags**: animation, pulsing, sinusoidal, circle, beginner

---

### **Problem 011: Color Mixing Zones**

**Objective**: Divide screen into four quadrants, each displaying a different primary or secondary color.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Screen space partitioning and conditional color assignment

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Top-left: Red (1,0,0)
- Top-right: Green (0,1,0)
- Bottom-left: Blue (0,0,1) 
- Bottom-right: Yellow (1,1,0)

**Success Criteria**:
- Perfect quadrant division
- Sharp boundaries at center lines
- Correct color assignments

**Reference Equations** (Context Only):
```
Quadrant detection: 
left/right = (x < 0.5), top/bottom = (y < 0.5)
```

**Tags**: quadrants, colors, conditional, partitioning, beginner

---

### **Problem 012: Triangle Shape**

**Objective**: Draw a white equilateral triangle centered on screen against a black background.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Triangle geometry and signed distance functions

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- White equilateral triangle on black background
- Triangle centered on screen
- Side length approximately 0.6 in normalized space

**Success Criteria**:
- Perfect equilateral geometry
- Sharp edges
- Centered positioning

**Reference Equations** (Context Only):
```
Equilateral triangle vertices: (0, h), (-w/2, -h/2), (w/2, -h/2)
Point-in-triangle test using barycentric coordinates or half-plane tests
```

**Tags**: shapes, triangle, geometry, beginner

---

### **Problem 013: Diagonal Gradient**

**Objective**: Create a diagonal gradient from bottom-left (black) to top-right (white).

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Linear gradient along diagonal direction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Smooth diagonal gradient
- Black at (0,0), white at (1,1) in normalized coordinates
- Linear transition along diagonal

**Success Criteria**:
- Perfect diagonal orientation
- Smooth gradient without banding
- Correct endpoint colors

**Reference Equations** (Context Only):
```
Diagonal coordinate: d = (x + y) / 2
Normalized diagonal: d_norm = d / max_diagonal_length
```

**Tags**: gradient, diagonal, linear, beginner

---

### **Problem 014: Concentric Circles**

**Objective**: Draw three concentric white circles on black background with radii 0.1, 0.2, and 0.3.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Multiple distance comparisons and circle rings

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Three white circle outlines on black background
- Radii: 0.1, 0.2, 0.3 in normalized coordinates
- All circles centered on screen

**Success Criteria**:
- Three distinct circle outlines
- Correct radii measurements
- Sharp, thin circle boundaries

**Reference Equations** (Context Only):
```
Distance from center: d = length(uv - center)
Circle outline: abs(d - radius) < line_width
```

**Tags**: circles, concentric, multiple, outlines, beginner

---

### **Problem 015: Color Wheel Sectors**

**Objective**: Create a simple color wheel divided into 6 sectors showing primary and secondary colors.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Polar coordinates and angular divisions

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Six 60-degree sectors in circular arrangement
- Colors: Red, Yellow, Green, Cyan, Blue, Magenta
- Sector boundaries at 0°, 60°, 120°, 180°, 240°, 300°

**Success Criteria**:
- Perfect 60-degree divisions
- Correct color sequence
- Sharp sector boundaries

**Reference Equations** (Context Only):
```
Polar angle: θ = atan2(y, x)
Sector index: sector = floor((θ + π) / (π/3))
```

**Tags**: polar, angles, color-wheel, sectors, beginner

---

### **Problem 016: Blinking Effect**

**Objective**: Create a full-screen color that blinks between white and black every second.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Discrete time intervals and binary switching

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - elapsed time

**Expected Outputs**:
- Alternating white and black full-screen colors
- 1-second intervals for each color
- Sharp transitions (no fading)

**Success Criteria**:
- Precise 1-second timing
- Sharp color switches
- Consistent alternation pattern

**Reference Equations** (Context Only):
```
Discrete switching: color = (floor(time) % 2 == 0) ? white : black
Time quantization: t_discrete = floor(time)
```

**Tags**: blinking, timing, discrete, alternation, beginner

---

### **Problem 017: Square Grid**

**Objective**: Draw a 5x5 grid of white square outlines on a black background.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Grid generation and line drawing

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- 5x5 grid of square outlines
- White lines on black background
- Equal square sizes filling the screen

**Success Criteria**:
- Exactly 5x5 grid layout
- Uniform line thickness
- Perfect square shapes

**Reference Equations** (Context Only):
```
Grid lines: x % (1/grid_size) < line_width OR y % (1/grid_size) < line_width
Grid cell boundaries at multiples of 1/5
```

**Tags**: grid, squares, lines, outlines, beginner

---

### **Problem 018: Rotating Colors**

**Objective**: Display three colored segments that rotate around the screen center like a color wheel.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Rotating coordinate systems and angular animation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Three 120-degree sectors (red, green, blue)
- Rotation around screen center
- Complete rotation every 4 seconds

**Success Criteria**:
- Smooth rotation motion
- Consistent sector sizes
- Proper color assignments

**Reference Equations** (Context Only):
```
Rotation matrix: [cos(θ) -sin(θ); sin(θ) cos(θ)]
Rotating angle: θ(t) = ωt where ω = 2π/period
```

**Tags**: rotation, colors, sectors, animation, beginner

---

### **Problem 019: Heart Shape**

**Objective**: Draw a pink heart shape centered on screen using the parametric heart equation.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Parametric curves and implicit surface representation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Pink heart shape on black background
- Centered on screen
- Smooth curved boundaries

**Success Criteria**:
- Recognizable heart shape
- Smooth curves without artifacts
- Proper scaling and positioning

**Reference Equations** (Context Only):
```
Heart equation: x = 16sin³(t), y = 13cos(t) - 5cos(2t) - 2cos(3t) - cos(4t)
Implicit form: (x² + y² - 1)³ - x²y³ = 0 (simplified version)
```

**Tags**: heart, parametric, curves, shape, beginner

---

### **Problem 020: Mandelbrot Preview**

**Objective**: Create a simple black-and-white visualization of the Mandelbrot set within a 2x2 viewing window.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Complex number iteration and fractal geometry

**Inputs**:
- `vec2 fragCoord` - fragment coordinates  
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Black and white Mandelbrot set visualization
- Complex plane range: [-2, 2] x [-2, 2]
- Maximum 50 iterations for convergence test

**Success Criteria**:
- Recognizable Mandelbrot set shape
- Sharp boundary between set and non-set points
- Proper complex plane mapping

**Reference Equations** (Context Only):
```
Mandelbrot iteration: z_{n+1} = z_n² + c
Convergence test: |z_n| > 2 for divergence
Complex plane mapping: c = (x,y) where x,y ∈ [-2,2]
```

**Tags**: fractal, mandelbrot, complex, iteration, beginner

---

### **Problem 021: Cross Pattern**

**Objective**: Draw a white cross shape centered on screen, with arms extending to screen edges.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Geometric intersection and conditional rendering

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- White cross on black background
- Horizontal and vertical arms of equal width
- Arms extend to screen boundaries

**Success Criteria**:
- Perfect centering
- Equal arm widths (approximately 0.1 in normalized space)
- Sharp edges

**Reference Equations** (Context Only):
```
Cross condition: |x - 0.5| < width/2 OR |y - 0.5| < width/2
Centered coordinates: (x,y) relative to (0.5, 0.5)
```

**Tags**: cross, shapes, intersection, beginner

---

### **Problem 022: Breathing Effect**

**Objective**: Create a full-screen color that smoothly transitions in brightness from dark to bright and back, like breathing.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Sinusoidal brightness modulation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - elapsed time

**Expected Outputs**:
- Smooth brightness variation across entire screen
- "Breathing" cycle every 3 seconds
- Base color: blue (0, 0, 1)

**Success Criteria**:
- Smooth brightness transitions
- Consistent 3-second period
- No sudden jumps or discontinuities

**Reference Equations** (Context Only):
```
Brightness modulation: brightness = 0.3 + 0.7 * (sin(2πt/T) + 1) / 2
Breathing period: T = 3 seconds
```

**Tags**: breathing, brightness, modulation, smooth, beginner

---

### **Problem 023: Diamond Shape**

**Objective**: Draw a white diamond (rotated square) centered on screen with a diagonal length of 0.6.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Rotated coordinate systems and diamond geometry

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- White diamond on black background
- Diamond oriented with points at cardinal directions
- Diagonal length of 0.6 in normalized coordinates

**Success Criteria**:
- Perfect diamond symmetry
- Correct size and orientation
- Sharp edges

**Reference Equations** (Context Only):
```
Diamond equation: |x| + |y| = r (Manhattan distance)
Rotated square: 45-degree rotation of unit square
```

**Tags**: diamond, rotation, manhattan-distance, shapes, beginner

---

### **Problem 024: Color Temperature**

**Objective**: Create a horizontal gradient representing color temperature from cool blue (left) to warm orange (right).

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Color temperature mapping and smooth interpolation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Horizontal gradient from blue to orange
- Left edge: cool blue (0.2, 0.4, 1.0)
- Right edge: warm orange (1.0, 0.6, 0.2)

**Success Criteria**:
- Smooth color interpolation
- Correct endpoint colors
- Linear progression across screen width

**Reference Equations** (Context Only):
```
Color interpolation: color(t) = color_a * (1-t) + color_b * t
Horizontal parameter: t = x / screen_width
```

**Tags**: color-temperature, gradient, interpolation, horizontal, beginner

---

### **Problem 025: Star Shape**

**Objective**: Draw a white 5-pointed star centered on screen using geometric construction.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Star polygon geometry and polar coordinates

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- White 5-pointed star on black background
- Star centered on screen
- Outer radius of 0.3 in normalized coordinates

**Success Criteria**:
- Perfect 5-fold symmetry
- Sharp star points
- Correct proportions

**Reference Equations** (Context Only):
```
Star points: θ_k = 2πk/5 for k = 0,1,2,3,4
Alternating radii: r_outer for points, r_inner for indentations
Polar coordinates: x = r*cos(θ), y = r*sin(θ)
```

**Tags**: star, polygon, polar, symmetry, beginner

---

## Intermediate Fragment Shader Challenges (30 Problems)

### **Problem 026: Phong Lighting Sphere**

**Objective**: Render a sphere with Phong lighting model including ambient, diffuse, and specular components.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: 3D sphere ray tracing and Phong illumination model

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 lightPos` - light position (2.0, 2.0, 2.0)
- `uniform vec3 viewPos` - camera position (0.0, 0.0, 3.0)

**Expected Outputs**:
- 3D sphere with realistic lighting
- Visible ambient, diffuse, and specular highlights
- Sphere centered at origin with radius 1.0

**Success Criteria**:
- Correct sphere geometry through ray tracing
- Proper normal calculation on sphere surface
- Accurate Phong lighting implementation

**Reference Equations** (Context Only):
```
Sphere equation: x² + y² + z² = r²
Phong model: I = I_a + I_d(N·L) + I_s(R·V)^n
Surface normal: N = position / radius
```

**Tags**: sphere, lighting, phong, ray-tracing, normals, intermediate

---

### **Problem 027: Animated Plasma**

**Objective**: Create an animated plasma effect using multiple sine waves with different frequencies and phases.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Wave interference and trigonometric combinations

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Colorful, animated plasma-like pattern
- Smooth wave interference patterns
- Colors cycling through spectrum over time

**Success Criteria**:
- Multiple wave frequencies creating complex patterns
- Smooth color transitions
- Continuous animation without repetition artifacts

**Reference Equations** (Context Only):
```
Plasma function: f(x,y,t) = sin(x*a + t) + sin(y*b + t) + sin((x+y)*c + t)
Color mapping: RGB = (sin(f), sin(f + 2π/3), sin(f + 4π/3))
```

**Tags**: plasma, waves, interference, animation, trigonometry, intermediate

---

### **Problem 028: Procedural Wood Grain**

**Objective**: Generate a realistic wood grain pattern using noise functions and color gradients.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Noise functions, pattern generation, and natural texture simulation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Realistic wood grain appearance
- Concentric growth rings
- Natural color variation from light to dark brown

**Success Criteria**:
- Recognizable wood grain pattern
- Smooth noise-based variation
- Appropriate color palette for wood

**Reference Equations** (Context Only):
```
Radial distance: r = length(uv)
Noise-based rings: rings = sin(r * frequency + noise(uv) * amplitude)
Wood colors: interpolate between browns based on ring value
```

**Tags**: wood, procedural, noise, texture, natural, intermediate

---

### **Problem 029: Tunnel Effect**

**Objective**: Create a perspective tunnel effect that appears to extend infinitely into the screen.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Polar coordinates, perspective projection, and texture mapping

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Tunnel appearing to recede into distance
- Animated texture flowing toward vanishing point
- Proper perspective distortion

**Success Criteria**:
- Convincing 3D tunnel illusion
- Smooth animation of texture flow
- Correct perspective scaling

**Reference Equations** (Context Only):
```
Polar coordinates: r = length(uv), θ = atan2(v, u)
Tunnel depth: z = 1/r
Texture coordinates: u_tex = θ/(2π), v_tex = z + time
```

**Tags**: tunnel, perspective, polar, animation, 3d-illusion, intermediate

---

### **Problem 030: Voronoi Diagram**

**Objective**: Generate a Voronoi diagram with 16 randomly positioned seed points, each cell colored differently.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Voronoi diagrams, distance fields, and spatial partitioning

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Voronoi cell pattern with 16 distinct regions
- Each cell colored uniquely
- Clean cell boundaries

**Success Criteria**:
- Correct Voronoi cell computation
- 16 distinct colored regions
- Sharp cell boundaries

**Reference Equations** (Context Only):
```
Voronoi cell: C_i = {p : d(p, s_i) ≤ d(p, s_j) for all j ≠ i}
Distance metric: d(p, s) = ||p - s||
Seed points: s_i at fixed positions
```

**Tags**: voronoi, distance-field, cells, partitioning, intermediate

---

### **Problem 031: Metaball Blending**

**Objective**: Render smooth blending between multiple circular metaballs using implicit surface techniques.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Implicit surfaces, potential fields, and smooth blending functions

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- 4 metaballs moving in circular paths
- Smooth blending when metaballs approach each other
- Organic, fluid-like appearance

**Success Criteria**:
- Smooth surface blending between balls
- Circular motion animation
- No sharp edges during blending

**Reference Equations** (Context Only):
```
Metaball potential: f_i(p) = r_i² / ||p - c_i||²
Combined field: F(p) = Σ f_i(p)
Surface threshold: F(p) = threshold for boundary
```

**Tags**: metaballs, blending, implicit-surface, animation, organic, intermediate

---

### **Problem 032: Fractal Tree**

**Objective**: Generate a 2D fractal tree using recursive branching patterns.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fractal geometry, recursive structures, and L-systems

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Tree-like fractal structure
- 6 levels of recursive branching
- Branches getting thinner at each level

**Success Criteria**:
- Clear tree structure with multiple branching levels
- Appropriate scaling and rotation at each level
- Organic appearance

**Reference Equations** (Context Only):
```
Branch transformation: scale by factor s, rotate by angle θ
Recursive depth: n levels of subdivision
Thickness reduction: t_n = t_0 * s^n
```

**Tags**: fractal, tree, recursive, branching, L-system, intermediate

---

### **Problem 033: Caustics Simulation**

**Objective**: Simulate light caustics pattern as seen on the bottom of a swimming pool.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Light refraction, wave simulation, and caustic formation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Animated caustic light patterns
- Bright concentrated lines and curves
- Flowing water-like animation

**Success Criteria**:
- Recognizable caustic patterns
- Smooth animation resembling water movement
- Proper light concentration effects

**Reference Equations** (Context Only):
```
Water surface: h(x,y,t) = A*sin(kx + ωt) + B*sin(ly + φt)
Light ray bending: Snell's law n₁sin(θ₁) = n₂sin(θ₂)
Caustic intensity: based on gradient magnitude
```

**Tags**: caustics, refraction, water, animation, optics, intermediate

---

### **Problem 034: Hexagonal Tiling**

**Objective**: Create a hexagonal tiling pattern with alternating colors and animated borders.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Hexagonal coordinate systems and tiling geometry

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Perfect hexagonal tiling across screen
- Alternating colors between adjacent hexagons
- Animated glowing borders around hexagons

**Success Criteria**:
- Perfect hexagonal geometry
- Correct tiling without gaps or overlaps
- Smooth border animation

**Reference Equations** (Context Only):
```
Hexagonal coordinates: conversion from Cartesian to hex grid
Hex center distance: d = 2/√3 * side_length
Neighbor pattern: 6-fold rotational symmetry
```

**Tags**: hexagon, tiling, tessellation, animation, geometry, intermediate

---

### **Problem 035: Spiral Galaxy**

**Objective**: Generate a spiral galaxy pattern with rotating arms and star field.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Logarithmic spirals, polar coordinates, and galaxy structure

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Spiral galaxy with 2 main arms
- Dense central bulge
- Scattered star field throughout
- Slow rotation animation

**Success Criteria**:
- Clear spiral arm structure
- Density variation from center to edge
- Smooth rotation animation

**Reference Equations** (Context Only):
```
Logarithmic spiral: r = a * e^(bθ)
Galaxy rotation: θ(t) = θ₀ + ω(r)t
Star density: ρ(r) = ρ₀ * e^(-r/r₀)
```

**Tags**: galaxy, spiral, stars, rotation, astronomy, intermediate

---

### **Problem 036: Perlin Noise Clouds**

**Objective**: Generate realistic cloud formations using multilayer Perlin noise.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Perlin noise, octave layering, and natural pattern generation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Realistic cloud-like patterns
- Multiple scales of detail (octaves)
- Gentle animation suggesting wind movement

**Success Criteria**:
- Natural cloud appearance
- Multiple noise octaves for detail
- Smooth temporal animation

**Reference Equations** (Context Only):
```
Perlin noise: P(x,y) with gradient interpolation
Octave layering: Σ(amplitude_i * P(x*freq_i, y*freq_i))
Cloud threshold: density = clamp(noise - threshold, 0, 1)
```

**Tags**: clouds, perlin-noise, octaves, natural, animation, intermediate

---

### **Problem 037: Kaleidoscope Effect**

**Objective**: Create a kaleidoscope effect with 8-fold symmetry using texture mirroring.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Symmetry groups, coordinate transformations, and mirroring

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- 8-fold rotational symmetry pattern
- Complex geometric patterns from simple source
- Animated rotation of the pattern

**Success Criteria**:
- Perfect 8-fold symmetry
- No seams at symmetry boundaries
- Smooth rotation animation

**Reference Equations** (Context Only):
```
Polar coordinates: r, θ = atan2(y, x)
Symmetry fold: θ_folded = mod(θ, 2π/8)
Mirror operation: reflection across symmetry lines
```

**Tags**: kaleidoscope, symmetry, mirroring, rotation, geometry, intermediate

---

### **Problem 038: Fluid Simulation**

**Objective**: Simulate simple 2D fluid flow using a velocity field and particle advection.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fluid dynamics, vector fields, and particle systems

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Visible fluid flow patterns
- Smooth particle motion following velocity field
- Swirling, organic flow behavior

**Success Criteria**:
- Convincing fluid motion
- Continuous particle trajectories
- No unrealistic jumps or discontinuities

**Reference Equations** (Context Only):
```
Velocity field: v(x,y) = (u(x,y), v(x,y))
Particle advection: dx/dt = v(x,y)
Flow visualization: streak lines or particle traces
```

**Tags**: fluid, simulation, velocity-field, particles, flow, intermediate

---

### **Problem 039: Mandala Pattern**

**Objective**: Generate an intricate mandala pattern with multiple layers of geometric elements.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Polar symmetry, layered patterns, and geometric construction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Complex mandala with at least 5 concentric layers  
- 12-fold rotational symmetry
- Intricate geometric details at each layer

**Success Criteria**:
- Perfect rotational symmetry
- Multiple distinct pattern layers
- Sharp, clean geometric elements

**Reference Equations** (Context Only):
```
Polar coordinates: r, θ
Symmetry: θ_sym = mod(θ, 2π/12)
Layer functions: f_i(r, θ) for each concentric ring
```

**Tags**: mandala, symmetry, geometric, layers, polar, intermediate

---

### **Problem 040: Crystal Growth**

**Objective**: Simulate crystal growth pattern using cellular automata-like rules.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Cellular automata, growth patterns, and crystalline structures

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Dendritic crystal growth from center
- Branching patterns typical of crystal formation
- Time-based growth animation

**Success Criteria**:
- Realistic crystal branching patterns
- Growth emanating from central seed
- Smooth temporal progression

**Reference Equations** (Context Only):
```
Growth probability: P(x,y,t) based on local conditions
Nucleation sites: seed points for crystal formation
Branching angle: preferred directions for growth
```

**Tags**: crystal, growth, cellular-automata, branching, simulation, intermediate

---

### **Problem 041: Warp Tunnel**

**Objective**: Create a sci-fi warp tunnel effect with streaking stars and tunnel walls.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Perspective transformation, motion blur, and cylindrical coordinates

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Tunnel walls with perspective distortion
- Streaking star field showing motion
- Central vanishing point

**Success Criteria**:
- Convincing perspective tunnel geometry
- Motion blur effects on stars
- Consistent vanishing point perspective

**Reference Equations** (Context Only):
```
Cylindrical projection: r, θ, z coordinates
Perspective scaling: scale ∝ 1/z
Motion blur: streak length ∝ velocity
```

**Tags**: warp, tunnel, perspective, motion-blur, sci-fi, intermediate

---

### **Problem 042: Interference Patterns**

**Objective**: Simulate wave interference patterns from multiple point sources.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Wave physics, superposition principle, and interference

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- 4 wave sources creating interference
- Visible constructive and destructive interference
- Animated wave propagation

**Success Criteria**:
- Clear interference patterns
- Proper wave phase relationships
- Smooth wave animation

**Reference Equations** (Context Only):
```
Wave equation: A*sin(kr - ωt + φ)
Superposition: ψ_total = Σ ψ_i
Phase difference: Δφ = k*Δr
```

**Tags**: waves, interference, physics, animation, superposition, intermediate

---

### **Problem 043: Magnetic Field Lines**

**Objective**: Visualize magnetic field lines around a dipole using vector field visualization.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Vector fields, magnetic dipoles, and field line integration

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Curved field lines around magnetic dipole
- Proper field line density and direction
- North and south pole configuration

**Success Criteria**:
- Accurate dipole field geometry
- Smooth field line curves
- Proper field line density variation

**Reference Equations** (Context Only):
```
Dipole field: B ∝ (3(m·r̂)r̂ - m)/r³
Field lines: tangent to B field everywhere
Line density: ∝ field strength
```

**Tags**: magnetic, field-lines, dipole, physics, vector-field, intermediate

---

### **Problem 044: Erosion Patterns**

**Objective**: Generate natural erosion patterns similar to water carved channels.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Erosion simulation, height fields, and natural pattern formation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Branching erosion channels
- Natural drainage patterns
- Heightmap-based visualization

**Success Criteria**:
- Realistic erosion channel geometry
- Proper branching and convergence
- Natural appearance

**Reference Equations** (Context Only):
```
Erosion rate: dh/dt = -k * |∇h| * flow_rate
Flow accumulation: water collection in channels
Slope computation: ∇h = (∂h/∂x, ∂h/∂y)
```

**Tags**: erosion, natural, channels, heightmap, simulation, intermediate

---

### **Problem 045: Fibonacci Spiral**

**Objective**: Create a visual representation of the Fibonacci spiral with golden ratio proportions.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fibonacci sequence, golden ratio, and logarithmic spirals

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Fibonacci spiral with proper proportions
- Golden rectangle subdivision visible
- Smooth spiral curve

**Success Criteria**:
- Mathematically accurate Fibonacci proportions
- Visible golden rectangle structure
- Smooth spiral geometry

**Reference Equations** (Context Only):
```
Golden ratio: φ = (1 + √5)/2
Fibonacci spiral: r = φ^(θ/π/2)
Rectangle sequence: F_n × F_(n+1)
```

**Tags**: fibonacci, golden-ratio, spiral, mathematics, proportions, intermediate

---

### **Problem 046: Lava Lamp Effect**

**Objective**: Simulate the blob behavior of a lava lamp with floating, deforming shapes.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fluid dynamics, buoyancy, and blob deformation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Multiple blob shapes floating upward
- Organic deformation of blobs
- Heat convection-like motion

**Success Criteria**:
- Smooth blob deformation
- Realistic buoyancy motion
- Organic, flowing appearance

**Reference Equations** (Context Only):
```
Blob function: smooth minimum/maximum operations
Buoyancy motion: upward velocity with oscillation
Deformation: noise-based shape perturbation
```

**Tags**: lava-lamp, blobs, fluid, buoyancy, organic, intermediate

---

### **Problem 047: Circuit Board Pattern**

**Objective**: Generate a realistic printed circuit board pattern with traces and components.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Graph theory, path finding, and electronic layout

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Circuit traces connecting component locations
- Component pads and via holes
- Realistic PCB green color scheme

**Success Criteria**:
- Connected trace network
- Realistic component placement
- Proper PCB aesthetics

**Reference Equations** (Context Only):
```
Trace width: constant width paths
Component placement: grid-based locations
Connection logic: graph connectivity
```

**Tags**: circuit, pcb, traces, electronic, pattern, intermediate

---

### **Problem 048: Ripple Effect**

**Objective**: Create expanding ripples from multiple sources like stones dropped in water.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Wave propagation, multiple sources, and interference

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Concentric ripples from 3 source points
- Wave interference where ripples meet
- Damping with distance from source

**Success Criteria**:
- Clear concentric wave patterns
- Proper wave interference
- Natural amplitude decay

**Reference Equations** (Context Only):
```
Ripple function: A*sin(k*r - ω*t) * decay(r)
Multiple sources: superposition of individual ripples
Damping: amplitude ∝ 1/√r
```

**Tags**: ripples, waves, interference, water, animation, intermediate

---

### **Problem 049: Maze Generation**

**Objective**: Generate a solvable maze using algorithmic maze generation techniques.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Graph algorithms, maze generation, and pathfinding

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Solvable maze with single solution path
- Clear walls and passages
- Entrance and exit points

**Success Criteria**:
- Maze has unique solution
- Proper wall/passage rendering
- Clear entrance/exit visibility

**Reference Equations** (Context Only):
```
Maze cell: wall/passage state
Connectivity: graph traversal properties
Generation: recursive backtracking or similar
```

**Tags**: maze, generation, algorithm, graph, pathfinding, intermediate

---

### **Problem 050: Fire Simulation**

**Objective**: Simulate realistic fire effect with flickering flames and particle motion.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Particle systems, heat simulation, and turbulence

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Flickering flame-like patterns
- Upward motion with turbulent flow
- Color gradient from red/orange to yellow

**Success Criteria**:
- Realistic flame appearance
- Proper upward convection motion
- Natural color progression

**Reference Equations** (Context Only):
```
Heat convection: upward velocity field
Turbulence: noise-based flow perturbation
Temperature mapping: color = f(temperature)
```

**Tags**: fire, flames, simulation, particles, heat, intermediate

---

### **Problem 051: DNA Double Helix**

**Objective**: Render a rotating DNA double helix structure with proper geometric proportions.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Parametric curves, helical geometry, and 3D projection

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Double helix structure with two intertwined strands
- Base pair connections between strands
- Smooth rotation animation

**Success Criteria**:
- Correct helix geometry and proportions
- Visible base pair connections
- Smooth 3D rotation

**Reference Equations** (Context Only):
```
Helix parametrization: x = r*cos(t), y = r*sin(t), z = h*t
Double helix: two helices with phase offset π
Base pairs: connections at regular intervals
```

**Tags**: dna, helix, biology, 3d, parametric, intermediate

---

### **Problem 052: Lightning Branches**

**Objective**: Generate realistic lightning bolt patterns with fractal branching.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fractal geometry, electric discharge patterns, and recursive branching

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Main lightning bolt from top to bottom
- Fractal side branches
- Electric glow effect around bolts

**Success Criteria**:
- Realistic lightning appearance
- Proper fractal branching structure
- Glowing electric effect

**Reference Equations** (Context Only):
```
Fractal branching: recursive L-system or similar
Branch probability: decreasing with generation
Electric field: potential gradient following path
```

**Tags**: lightning, fractal, electric, branching, glow, intermediate

---

### **Problem 053: Planet Atmosphere**

**Objective**: Render a planet with atmospheric scattering effects creating a realistic halo.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Light scattering, atmospheric physics, and ray tracing

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 lightDir` - light direction

**Expected Outputs**:
- Spherical planet with solid surface
- Atmospheric glow around planet rim
- Proper light scattering colors

**Success Criteria**:
- Convincing atmospheric effect
- Proper sphere geometry
- Realistic scattering color gradient

**Reference Equations** (Context Only):
```
Rayleigh scattering: intensity ∝ 1/λ⁴
Atmospheric thickness: varies with viewing angle
Rim lighting: enhanced scattering at planet edge
```

**Tags**: planet, atmosphere, scattering, sphere, lighting, intermediate

---

### **Problem 054: Sierpinski Triangle**

**Objective**: Generate the Sierpinski triangle fractal using iterative construction methods.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fractal geometry, self-similarity, and iterative construction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution

**Expected Outputs**:
- Sierpinski triangle with 8 levels of detail
- Clear triangular subdivision pattern
- Sharp fractal boundaries

**Success Criteria**:
- Mathematically accurate Sierpinski construction
- Multiple levels of self-similarity
- Clear triangular structure

**Reference Equations** (Context Only):
```
Sierpinski construction: midpoint subdivision
Fractal depth: recursive triangle generation
Binary representation: coordinates and fractal membership
```

**Tags**: sierpinski, fractal, triangle, self-similarity, recursive, intermediate

---

### **Problem 055: Hypnotic Spiral**

**Objective**: Create a hypnotic spiral pattern with alternating colors and rotation animation.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Archimedean spirals, periodic functions, and visual perception

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time

**Expected Outputs**:
- Spiral pattern with alternating black and white regions
- Smooth rotation creating hypnotic effect
- Consistent spiral arm spacing

**Success Criteria**:
- Clear spiral structure
- Smooth rotation animation
- Strong visual effect

**Reference Equations** (Context Only):
```
Archimedean spiral: r = aθ
Alternating pattern: based on spiral arm count
Rotation: θ_rotated = θ + ωt
```

**Tags**: hypnotic, spiral, rotation, alternating, visual-effect, intermediate

---

## Advanced Fragment Shader Challenges (25 Problems)

### **Problem 056: Ray-traced Reflective Spheres**

**Objective**: Implement full ray tracing with reflective spheres, including multiple reflection bounces.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Ray tracing, recursive reflections, and 3D intersection algorithms

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 cameraPos` - camera position
- `uniform vec3 lightPos` - light position

**Expected Outputs**:
- Scene with 3 reflective metal spheres
- Accurate reflections between spheres
- Proper lighting and shadows

**Success Criteria**:
- Mathematically correct ray-sphere intersections
- Multiple reflection bounces (minimum 3 levels)
- Realistic metallic appearance

**Reference Equations** (Context Only):
```
Ray-sphere intersection: ||(o + td) - c||² = r²
Reflection vector: R = I - 2(I·N)N
Fresnel reflectance: F = F₀ + (1-F₀)(1-cos(θ))^5
```

**Tags**: ray-tracing, reflections, spheres, lighting, advanced

---

### **Problem 057: Volumetric Clouds**

**Objective**: Render realistic 3D volumetric clouds using ray marching and multiple scattering.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Ray marching, volumetric rendering, and light scattering

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 sunDir` - sun direction
- `uniform float time` - elapsed time

**Expected Outputs**:
- 3D cloud formations with proper depth
- Realistic light scattering through clouds
- Animated cloud movement

**Success Criteria**:
- Convincing 3D cloud volume
- Proper light attenuation through medium
- Smooth animation without artifacts

**Reference Equations** (Context Only):
```
Ray marching: sampling along ray at regular intervals
Beer's law: I = I₀e^(-αd) for light attenuation
Multiple scattering: phase function and in-scattering
```

**Tags**: clouds, volumetric, ray-marching, scattering, 3d, advanced

---

### **Problem 058: Fractional Brownian Motion Terrain**

**Objective**: Generate realistic mountainous terrain using fractional Brownian motion noise.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Fractional Brownian motion, terrain generation, and procedural landscapes

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 cameraPos` - camera position

**Expected Outputs**:
- Realistic mountain terrain with multiple scales of detail
- Proper atmospheric perspective
- Height-based color mapping

**Success Criteria**:
- Natural-looking terrain features
- Multiple octaves of noise for realism
- Proper depth cueing and lighting

**Reference Equations** (Context Only):
```
fBm: Σ(amplitude_i * noise(x * frequency_i))
Terrain height: h(x,y) = fBm(x,y) with octaves
Ridge formation: |noise(x)| for sharp peaks
```

**Tags**: terrain, fbm, noise, mountains, procedural, advanced

---

### **Problem 059: Mandelbulb Fractal**

**Objective**: Render the 3D Mandelbulb fractal using ray marching and distance estimation.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: 3D fractals, distance estimation, and ray marching algorithms

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 cameraPos` - camera position
- `uniform vec3 lightPos` - light position

**Expected Outputs**:
- 3D Mandelbulb fractal with 8th power formula
- Proper surface shading and lighting
- Self-similar detail at multiple scales

**Success Criteria**:
- Mathematically accurate Mandelbulb geometry
- Efficient ray marching implementation
- Clear fractal structure visibility

**Reference Equations** (Context Only):
```
Mandelbulb iteration: z → z^n + c in 3D
Distance estimation: DE = |z| * log|z| / |dz|
Ray marching: step size = DE * safety_factor
```

**Tags**: mandelbulb, fractal, 3d, ray-marching, distance-estimation, advanced

---

### **Problem 060: Fluid Dynamics Visualization**

**Objective**: Implement 2D fluid simulation with proper Navier-Stokes dynamics visualization.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Navier-Stokes equations, fluid dynamics, and vector field visualization

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time
- `uniform vec2 mousePos` - mouse interaction position

**Expected Outputs**:
- Realistic fluid flow patterns
- Vorticity and turbulence visualization
- Interactive disturbance from mouse input

**Success Criteria**:
- Convincing fluid behavior
- Proper vortex formation and decay
- Stable numerical integration

**Reference Equations** (Context Only):
```
Navier-Stokes: ∂v/∂t + (v·∇)v = -∇p/ρ + ν∇²v + f
Vorticity: ω = ∇ × v
Advection: dφ/dt + v·∇φ = 0
```

**Tags**: fluid-dynamics, navier-stokes, vorticity, simulation, advanced

---

### **Problem 061: Raymarched Menger Sponge**

**Objective**: Render the Menger sponge fractal using distance fields and ray marching.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: 3D fractals, constructive solid geometry, and distance fields

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 cameraPos` - camera position
- `uniform mat3 rotation` - rotation matrix

**Expected Outputs**:
- 3D Menger sponge with 4-5 iteration levels
- Proper shadows and ambient occlusion
- Rotating animation showing structure

**Success Criteria**:
- Accurate Menger sponge construction
- Efficient distance field evaluation
- Clear fractal hole pattern

**Reference Equations** (Context Only):
```
Menger construction: recursive cube subdivision
Distance field: min/max operations for CSG
Ambient occlusion: AO = 1 - step_size/distance_ratio
```

**Tags**: menger-sponge, fractal, ray-marching, distance-field, csg, advanced

---

### **Problem 062: Holographic Interference**

**Objective**: Simulate holographic interference patterns with coherent light sources.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Wave optics, coherent light, and interference phenomena

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float wavelength` - light wavelength
- `uniform vec2 source1, source2` - coherent source positions

**Expected Outputs**:
- Complex interference fringe patterns
- Wavelength-dependent color effects
- High-resolution interference detail

**Success Criteria**:
- Accurate wave interference calculation
- Proper phase relationships
- Realistic optical appearance

**Reference Equations** (Context Only):
```
Wave function: ψ = A*e^(i(kr - ωt + φ))
Interference: |ψ₁ + ψ₂|² = |ψ₁|² + |ψ₂|² + 2Re(ψ₁*ψ₂*)
Phase difference: Δφ = 2π(r₁ - r₂)/λ
```

**Tags**: holography, interference, optics, waves, coherent-light, advanced

---

### **Problem 063: Gravitational Lensing**

**Objective**: Simulate gravitational lensing effects around a massive object distorting background starfield.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: General relativity, gravitational lensing, and spacetime curvature

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec2 lensPos` - gravitational lens position
- `uniform float lensMass` - lens mass parameter

**Expected Outputs**:
- Distorted star field around massive object
- Multiple images of background stars
- Einstein ring formation for aligned sources

**Success Criteria**:
- Physically accurate lensing equation
- Proper image distortion and magnification
- Realistic astronomical appearance

**Reference Equations** (Context Only):
```
Lens equation: β = θ - (4GM/c²D) * (θ/|θ|²)
Deflection angle: α = (4GM/c²) * (1/ξ)
Critical radius: θ_E = √(4GM D_ls / c² D_l D_s)
```

**Tags**: gravitational-lensing, relativity, astronomy, distortion, advanced

---

### **Problem 064: Quantum Probability Waves**

**Objective**: Visualize quantum wave function evolution for a particle in a 2D potential well.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Quantum mechanics, Schrödinger equation, and wave function visualization

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time
- `uniform float energy` - energy eigenvalue

**Expected Outputs**:
- Animated quantum wave function |ψ|²
- Standing wave patterns in potential well
- Probability density visualization

**Success Criteria**:
- Accurate quantum eigenstate patterns
- Proper time evolution animation
- Clear probability interpretation

**Reference Equations** (Context Only):
```
Time evolution: ψ(t) = ψ₀ * e^(-iEt/ℏ)
2D particle in box: ψ(x,y) = sin(nπx/L) * sin(mπy/L)
Probability density: ρ = |ψ|²
```

**Tags**: quantum, wave-function, schrodinger, probability, physics, advanced

---

### **Problem 065: Magnetic Reconnection**

**Objective**: Simulate magnetic field line reconnection with plasma particle acceleration.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Magnetohydrodynamics, plasma physics, and magnetic field topology

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - elapsed time
- `uniform float resistivity` - plasma resistivity

**Expected Outputs**:
- Magnetic field lines undergoing reconnection
- Particle acceleration visualization
- Current sheet formation

**Success Criteria**:
- Physically realistic reconnection geometry
- Proper field line topology changes
- Visible particle acceleration regions

**Reference Equations** (Context Only):
```
Magnetic diffusion: ∂B/∂t = η∇²B - ∇×(v×B)
Reconnection rate: proportional to resistivity
Current density: J = ∇×B/μ₀
```

**Tags**: magnetic-reconnection, plasma, mhd, field-lines, physics, advanced

---

### **Problem 066: Crystal Lattice Diffraction**

**Objective**: Simulate X-ray diffraction patterns from various crystal lattice structures.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Crystallography, X-ray diffraction, and reciprocal lattice theory

**Inputs**:
- `vec2 fragCoord` - fragment coordinates (representing detector screen)
- `vec2 resolution` - screen resolution
- `uniform vec3 latticeParams` - crystal lattice parameters
- `uniform float wavelength` - X-ray wavelength

**Expected Outputs**:
- Diffraction spot patterns characteristic of crystal structure
- Bragg peak intensities and positions
- Structure factor modulations

**Success Criteria**:
- Accurate Bragg condition implementation
- Correct reciprocal lattice geometry
- Realistic diffraction intensities

**Reference Equations** (Context Only):
```
Bragg's law: nλ = 2d*sin(θ)
Structure factor: F_hkl = Σ f_j * e^(2πi(hx_j + ky_j + lz_j))
Diffraction intensity: I ∝ |F_hkl|²
```

**Tags**: diffraction, crystallography, bragg, reciprocal-lattice, x-ray, advanced

---

### **Problem 067: Schwarzschild Black Hole**

**Objective**: Render gravitational lensing and photon orbits around a Schwarzschild black hole.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: General relativity, black hole physics, and geodesic equations

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec3 cameraPos` - observer position
- `uniform float schwarzschildRadius` - event horizon radius

**Expected Outputs**:
- Black hole silhouette with photon sphere
- Gravitational lensing of background stars
- Accretion disk with relativistic effects

**Success Criteria**:
- Accurate photon geodesic integration
- Proper event horizon rendering
- Realistic relativistic effects

**Reference Equations** (Context Only):
```
Schwarzschild metric: ds² = -(1-2GM/rc²)dt² + dr²/(1-2GM/rc²) + r²dΩ²
Photon orbit: d²u/dφ² + u = 3GMu²/c²
Redshift: ν_obs = ν_em * √(1-2GM/rc²)
```

**Tags**: black-hole, relativity, photon-orbit, lensing, spacetime, advanced

---

### **Problem 068: Spin Glass Dynamics**

**Objective**: Simulate spin glass behavior with frustrated magnetic interactions and slow dynamics.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Statistical mechanics, spin systems, and frustrated magnets

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float temperature` - system temperature
- `uniform float time` - Monte Carlo time

**Expected Outputs**:
- Spin configuration visualization
- Slow glassy dynamics
- Frustrated interaction effects

**Success Criteria**:
- Proper spin glass phase behavior
- Realistic slow relaxation dynamics
- Frustration effects visible

**Reference Equations** (Context Only):
```
Spin glass Hamiltonian: H = -Σ J_ij S_i S_j
Frustrated bonds: J_ij with random signs
Metropolis dynamics: accept rate = min(1, e^(-ΔE/kT))
```

**Tags**: spin-glass, statistical-mechanics, frustration, dynamics, advanced

---

### **Problem 069: Lorenz Attractor 3D**

**Objective**: Visualize the 3D Lorenz attractor with proper perspective projection and trajectory tracing.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Chaos theory, dynamical systems, and strange attractors

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - system evolution time
- `uniform vec3 cameraPos` - camera position

**Expected Outputs**:
- 3D Lorenz attractor trajectory
- Multiple orbits showing butterfly effect
- Proper perspective and depth cueing

**Success Criteria**:
- Accurate Lorenz system integration
- Clear attractor structure
- Smooth trajectory animation

**Reference Equations** (Context Only):
```
Lorenz system: dx/dt = σ(y-x), dy/dt = x(ρ-z)-y, dz/dt = xy-βz
Parameters: σ=10, ρ=28, β=8/3 for chaotic behavior
Trajectory integration: numerical ODE solving
```

**Tags**: lorenz-attractor, chaos, dynamical-systems, 3d, trajectory, advanced

---

### **Problem 070: Supernova Shockwave**

**Objective**: Simulate expanding supernova shockwave with proper hydrodynamics and radiative effects.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Astrophysical fluid dynamics, shock physics, and radiative transfer

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - time since explosion
- `uniform vec2 explosionCenter` - supernova location

**Expected Outputs**:
- Expanding spherical shock front
- Density and temperature gradients
- Radiative cooling effects

**Success Criteria**:
- Physically realistic shock expansion
- Proper density profile behind shock
- Realistic temperature and emission

**Reference Equations** (Context Only):
```
Shock jump conditions: Rankine-Hugoniot relations
Expansion: R(t) ∝ t^(2/5) for adiabatic phase
Radiative cooling: Λ(T) cooling function
```

**Tags**: supernova, shock, hydrodynamics, astrophysics, radiative, advanced

---

### **Problem 071: Neural Network Visualization**

**Objective**: Visualize neural network activation patterns and information flow in real-time.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Neural networks, activation functions, and information theory

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - network evolution time
- `uniform sampler2D inputPattern` - input activation pattern

**Expected Outputs**:
- Layer-by-layer activation visualization
- Weight matrix representations
- Information flow animation

**Success Criteria**:
- Clear network structure visualization
- Realistic activation propagation
- Interpretable weight patterns

**Reference Equations** (Context Only):
```
Activation: a_i^(l+1) = σ(Σ w_ij^(l) a_j^(l) + b_i^(l+1))
Sigmoid function: σ(x) = 1/(1 + e^(-x))
Information flow: forward propagation through layers
```

**Tags**: neural-network, activation, machine-learning, visualization, advanced

---

### **Problem 072: Topology Optimization**

**Objective**: Visualize structural topology optimization showing material distribution evolution.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Optimization theory, finite element analysis, and structural mechanics

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float iteration` - optimization iteration
- `uniform vec2 loadPoint` - applied load location

**Expected Outputs**:
- Evolving material density distribution
- Load path visualization
- Optimal structure emergence

**Success Criteria**:
- Realistic topology evolution
- Clear load transfer paths
- Convergence to optimal design

**Reference Equations** (Context Only):
```
Density update: ρ_new = ρ_old * (sensitivity)^damping
Compliance: C = U^T K U
SIMP interpolation: E(ρ) = E_0 * ρ^p
```

**Tags**: topology-optimization, structural, fem, optimization, engineering, advanced

---

### **Problem 073: Reaction-Diffusion Patterns**

**Objective**: Simulate complex pattern formation using reaction-diffusion systems like Gray-Scott model.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Pattern formation, reaction-diffusion equations, and nonlinear dynamics

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - system evolution time
- `uniform float feedRate, killRate` - Gray-Scott parameters

**Expected Outputs**:
- Complex self-organizing patterns
- Spots, stripes, and spiral waves
- Dynamic pattern evolution

**Success Criteria**:
- Realistic pattern formation
- Proper reaction-diffusion dynamics
- Rich pattern diversity

**Reference Equations** (Context Only):
```
Gray-Scott: ∂u/∂t = D_u∇²u - uv² + f(1-u)
           ∂v/∂t = D_v∇²v + uv² - (f+k)v
Pattern selection: depends on f, k parameters
```

**Tags**: reaction-diffusion, patterns, gray-scott, dynamics, self-organization, advanced

---

### **Problem 074: Hologram Reconstruction**

**Objective**: Reconstruct a 3D holographic image from interference pattern data.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Fourier optics, holography, and complex wave reconstruction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform sampler2D hologramData` - recorded interference pattern
- `uniform vec3 reconstructionAngle` - viewing angle

**Expected Outputs**:
- 3D holographic image reconstruction
- Parallax effects with viewing angle
- Proper depth information

**Success Criteria**:
- Accurate hologram reconstruction
- Convincing 3D depth effect
- Proper angular dependence

**Reference Equations** (Context Only):
```
Hologram reconstruction: ψ(x,y) = F^(-1)[H(k_x,k_y) * R(k_x,k_y)]
Fresnel propagation: convolution with quadratic phase
Angular reconstruction: phase shift with viewing angle
```

**Tags**: holography, reconstruction, fourier-optics, 3d, interference, advanced

---

### **Problem 075: Magnetosphere Dynamics**

**Objective**: Simulate planetary magnetosphere interaction with solar wind including reconnection events.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Space physics, magnetohydrodynamics, and plasma interactions

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform vec2 solarWindVelocity` - solar wind parameters
- `uniform float magneticMoment` - planetary magnetic moment

**Expected Outputs**:
- Magnetosphere boundary visualization
- Solar wind interaction effects
- Magnetic reconnection sites

**Success Criteria**:
- Realistic magnetosphere shape
- Proper solar wind deflection
- Visible reconnection processes

**Reference Equations** (Context Only):
```
Magnetopause position: balance of magnetic and dynamic pressure
Reconnection rate: depends on magnetic shear and plasma β
Particle acceleration: at reconnection sites
```

**Tags**: magnetosphere, solar-wind, reconnection, space-physics, plasma, advanced

---

### **Problem 076: Quantum Tunneling**

**Objective**: Visualize quantum tunneling probability through various potential barriers.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Quantum mechanics, tunneling phenomena, and wave function analysis

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float energy` - particle energy
- `uniform float barrierHeight` - potential barrier height

**Expected Outputs**:
- Wave function amplitude across potential barrier
- Tunneling probability visualization
- Reflection and transmission coefficients

**Success Criteria**:
- Accurate quantum tunneling calculation
- Proper wave function matching at boundaries
- Realistic transmission probabilities

**Reference Equations** (Context Only):
```
Schrödinger equation: -ℏ²/(2m) d²ψ/dx² + V(x)ψ = Eψ
Transmission coefficient: T = |t|² where t is transmission amplitude
Tunneling probability: T = e^(-2κa) for thick barriers
```

**Tags**: quantum-tunneling, wave-function, barriers, transmission, physics, advanced

---

### **Problem 077: Polymer Chain Dynamics**

**Objective**: Simulate polymer chain conformations and dynamics using statistical mechanics.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Polymer physics, statistical mechanics, and chain statistics

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float chainLength` - number of monomers
- `uniform float temperature` - system temperature

**Expected Outputs**:
- Polymer chain conformations
- End-to-end distance distribution
- Thermal fluctuation effects

**Success Criteria**:
- Realistic polymer statistics
- Proper thermal motion
- Correct scaling behavior

**Reference Equations** (Context Only):
```
Random walk: R² = Nb² (ideal chain)
Excluded volume: R ~ N^ν where ν ≈ 0.588
Persistence length: exponential correlation decay
```

**Tags**: polymer, statistical-mechanics, chain-dynamics, thermal, conformations, advanced

---

### **Problem 078: Acoustic Wave Propagation**

**Objective**: Simulate 2D acoustic wave propagation with obstacles and interference effects.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Wave physics, acoustics, and numerical wave propagation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - wave propagation time
- `uniform vec2 sourcePos` - acoustic source position

**Expected Outputs**:
- Propagating acoustic waves
- Diffraction around obstacles
- Standing wave patterns

**Success Criteria**:
- Accurate wave equation solution
- Proper boundary conditions
- Realistic diffraction effects

**Reference Equations** (Context Only):
```
Wave equation: ∂²p/∂t² = c²∇²p
Boundary conditions: rigid walls, absorption
Diffraction: Huygens-Fresnel principle
```

**Tags**: acoustics, wave-propagation, diffraction, interference, physics, advanced

---

### **Problem 079: Phase Transition Dynamics**

**Objective**: Simulate liquid-gas phase transition with critical phenomena and scaling behavior.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Statistical mechanics, phase transitions, and critical phenomena

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float temperature` - system temperature
- `uniform float density` - system density

**Expected Outputs**:
- Phase separation visualization
- Critical opalescence near critical point
- Scaling behavior demonstration

**Success Criteria**:
- Realistic phase behavior
- Proper critical phenomena
- Correct scaling laws

**Reference Equations** (Context Only):
```
Ising model: H = -J Σ s_i s_j - h Σ s_i
Critical exponents: β, γ, ν for various quantities
Correlation length: ξ ~ |T - T_c|^(-ν)
```

**Tags**: phase-transition, critical-phenomena, ising-model, scaling, statistical-mechanics, advanced

---

### **Problem 080: Galactic Spiral Arms**

**Objective**: Simulate galactic spiral arm formation using density wave theory and stellar dynamics.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Galactic dynamics, density wave theory, and stellar orbits

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `vec2 resolution` - screen resolution
- `uniform float time` - galactic time
- `uniform float patternSpeed` - spiral pattern speed

**Expected Outputs**:
- Spiral density wave propagation
- Star formation regions in spiral arms
- Realistic galactic structure

**Success Criteria**:
- Proper spiral arm geometry
- Density wave physics
- Realistic stellar distribution

**Reference Equations** (Context Only):
```
Density wave: Σ(r,θ,t) = Σ₀ + Σ₁cos(mθ - Ωₚt + φ(r))
Spiral shock: compression in density wave
Star formation: triggered by spiral compression
```

**Tags**: galaxy, spiral-arms, density-wave, stellar-dynamics, astrophysics, advanced

---

## Vertex Shader Challenges (20 Problems)

### **Problem 081: Morphing Geometries**

**Objective**: Create smooth morphing between different 3D geometric shapes using vertex interpolation.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Geometric interpolation, vertex blending, and shape transformation

**Inputs**:
- `attribute vec3 position1` - first geometry vertices
- `attribute vec3 position2` - second geometry vertices
- `uniform float morphFactor` - interpolation parameter [0,1]
- `uniform mat4 mvpMatrix` - model-view-projection matrix

**Expected Outputs**:
- Smooth transition between cube and sphere
- Preserved topology during morphing
- Consistent vertex correspondence

**Success Criteria**:
- Smooth geometric interpolation
- No vertex folding or artifacts
- Proper projection transformation

**Reference Equations** (Context Only):
```
Linear interpolation: P(t) = (1-t)P₁ + tP₂
Spherical interpolation: for rotations
Vertex blending: weighted combination of positions
```

**Tags**: morphing, interpolation, geometry, vertex-blending, intermediate

---

### **Problem 082: Procedural Terrain Displacement**

**Objective**: Generate mountainous terrain using vertex displacement with multiple octaves of noise.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Procedural generation, noise functions, and heightfield displacement

**Inputs**:
- `attribute vec3 position` - base grid vertices
- `uniform float time` - animation time
- `uniform float amplitude` - displacement amplitude
- `uniform mat4 mvpMatrix` - transformation matrix

**Expected Outputs**:
- Realistic mountain terrain geometry
- Multiple scales of surface detail
- Animated terrain evolution

**Success Criteria**:
- Natural terrain appearance
- Smooth height transitions
- Proper normal vector calculation for lighting

**Reference Equations** (Context Only):
```
Height displacement: h(x,z) = Σ A_i * noise(f_i * x, f_i * z)
Surface normal: N = normalize(cross(dP/dx, dP/dz))
Octave mixing: amplitude and frequency scaling
```

**Tags**: terrain, displacement, noise, procedural, heightfield, intermediate

---

### **Problem 083: Skeletal Animation**

**Objective**: Implement basic skeletal animation system with bone transformations and vertex skinning.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Skeletal animation, bone hierarchies, and linear blend skinning

**Inputs**:
- `attribute vec3 position` - vertex positions
- `attribute vec4 boneIndices` - bone influence indices
- `attribute vec4 boneWeights` - bone influence weights
- `uniform mat4 boneMatrices[32]` - bone transformation matrices

**Expected Outputs**:
- Animated character mesh
- Smooth deformation at joints
- Preserved volume during animation

**Success Criteria**:
- Proper bone hierarchy transforms
- Smooth skinning without artifacts
- Normalized bone weights

**Reference Equations** (Context Only):
```
Skinned position: P' = Σ w_i * M_i * P
Weight normalization: Σ w_i = 1
Bone hierarchy: M_bone = M_parent * M_local
```

**Tags**: skeletal-animation, skinning, bones, character, deformation, advanced

---

### **Problem 084: Cloth Simulation**

**Objective**: Simulate cloth dynamics using mass-spring system with vertex position updates.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Mass-spring systems, numerical integration, and cloth physics

**Inputs**:
- `attribute vec3 position` - current vertex positions
- `attribute vec3 velocity` - vertex velocities
- `uniform float deltaTime` - simulation time step
- `uniform vec3 gravity` - gravitational acceleration

**Expected Outputs**:
- Realistic cloth motion
- Proper constraint satisfaction
- Stable numerical integration

**Success Criteria**:
- Natural cloth behavior
- No unstable oscillations
- Proper collision handling

**Reference Equations** (Context Only):
```
Spring force: F = -k(|x| - L₀) * x/|x|
Verlet integration: x(t+dt) = 2x(t) - x(t-dt) + a*dt²
Constraint satisfaction: distance preservation
```

**Tags**: cloth, simulation, mass-spring, physics, dynamics, advanced

---

### **Problem 085: Particle System**

**Objective**: Create a particle system with various forces and behaviors using vertex shaders.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Particle systems, force integration, and numerical methods

**Inputs**:
- `attribute vec3 position` - particle positions
- `attribute vec3 velocity` - particle velocities
- `attribute float age` - particle age
- `uniform vec3 attractor` - attractive force center

**Expected Outputs**:
- Dynamic particle motion
- Force-based behavior
- Lifecycle management

**Success Criteria**:
- Realistic particle trajectories
- Proper force application
- Smooth animation

**Reference Equations** (Context Only):
```
Force integration: v(t+dt) = v(t) + a*dt
Position update: x(t+dt) = x(t) + v*dt
Attractive force: F = G*m₁*m₂/r² * r̂
```

**Tags**: particles, forces, integration, dynamics, simulation, intermediate

---

### **Problem 086: Vortex Deformation**

**Objective**: Deform mesh vertices using fluid vortex equations for swirling motion effects.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fluid dynamics, vortex mathematics, and vector field deformation

**Inputs**:
- `attribute vec3 position` - vertex positions
- `uniform vec3 vortexCenter` - vortex center position
- `uniform float vortexStrength` - circulation strength
- `uniform float time` - animation time

**Expected Outputs**:
- Swirling deformation around vortex center
- Smooth velocity field integration
- Realistic fluid-like motion

**Success Criteria**:
- Proper vortex velocity field
- Smooth deformation without artifacts
- Consistent circulation direction

**Reference Equations** (Context Only):
```
Vortex velocity: v = (Γ/2πr) * θ̂
Circulation: Γ = ∮ v·dl around closed path
Velocity integration: position update from flow field
```

**Tags**: vortex, fluid, deformation, velocity-field, circulation, intermediate

---

### **Problem 087: Geodesic Sphere**

**Objective**: Generate a geodesic sphere by recursively subdividing an icosahedron.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Spherical geometry, recursive subdivision, and geodesic polyhedra

**Inputs**:
- `attribute vec3 position` - base icosahedron vertices
- `uniform int subdivisionLevel` - recursion depth
- `uniform float radius` - sphere radius

**Expected Outputs**:
- Smooth spherical approximation
- Even vertex distribution
- Proper geodesic structure

**Success Criteria**:
- Accurate spherical projection
- Uniform triangle sizes
- Smooth surface normals

**Reference Equations** (Context Only):
```
Sphere projection: P' = radius * normalize(P)
Edge subdivision: midpoint calculation and normalization
Geodesic property: shortest paths on sphere surface
```

**Tags**: geodesic, sphere, subdivision, polyhedra, geometry, intermediate

---

### **Problem 088: Wave Interference**

**Objective**: Displace vertices based on multiple interfering wave sources creating complex patterns.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Wave physics, interference, and superposition principle

**Inputs**:
- `attribute vec3 position` - vertex positions
- `uniform vec3 waveSource[4]` - wave source positions
- `uniform float frequency[4]` - wave frequencies
- `uniform float time` - wave phase time

**Expected Outputs**:
- Complex interference patterns
- Multiple wave source effects
- Animated wave propagation

**Success Criteria**:
- Accurate wave superposition
- Proper phase relationships
- Smooth wave animation

**Reference Equations** (Context Only):
```
Wave function: A*sin(kr - ωt + φ)
Superposition: ψ_total = Σ ψ_i
Wave number: k = 2π/λ
```

**Tags**: waves, interference, superposition, physics, animation, intermediate

---

### **Problem 089: Fractal Displacement**

**Objective**: Apply fractal noise displacement to create complex surface detail on simple geometries.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Fractal geometry, noise functions, and surface displacement

**Inputs**:
- `attribute vec3 position` - base mesh vertices
- `attribute vec3 normal` - vertex normals
- `uniform float scale` - noise scale
- `uniform int octaves` - fractal octaves

**Expected Outputs**:
- Detailed surface structure
- Self-similar fractal patterns
- Natural-looking surface roughness

**Success Criteria**:
- Realistic fractal detail
- Proper normal direction displacement
- Multiple scales of surface features

**Reference Equations** (Context Only):
```
Fractal displacement: d = Σ A_i * noise(f_i * P)
Octave parameters: A_i = A₀/2^i, f_i = f₀*2^i
Normal displacement: P' = P + d * N
```

**Tags**: fractal, displacement, noise, surface-detail, octaves, intermediate

---

### **Problem 090: Magnetic Field Lines**

**Objective**: Generate and animate particle trajectories following magnetic field line paths.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Electromagnetic field theory, charged particle motion, and field line integration

**Inputs**:
- `attribute vec3 position` - particle positions
- `attribute vec3 velocity` - particle velocities
- `uniform vec3 magneticField` - magnetic field vector
- `uniform float charge` - particle charge

**Expected Outputs**:
- Helical particle trajectories
- Proper Lorentz force application
- Field line visualization

**Success Criteria**:
- Accurate charged particle motion
- Proper helical orbits
- Consistent field line following

**Reference Equations** (Context Only):
```
Lorentz force: F = q(v × B)
Cyclotron frequency: ω_c = qB/m
Helical motion: combination of circular and linear motion
```

**Tags**: magnetic-field, lorentz-force, particles, helical-motion, physics, advanced

---

### **Problem 091: Crystal Lattice**

**Objective**: Generate various crystal lattice structures with proper atomic positioning and symmetries.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Crystallography, lattice theory, and space group symmetries

**Inputs**:
- `attribute vec3 position` - unit cell positions
- `uniform vec3 latticeVectors[3]` - crystal lattice basis
- `uniform int latticeType` - crystal system type
- `uniform float scaleFactor` - lattice parameter

**Expected Outputs**:
- Proper crystal structure
- Correct lattice symmetries
- Scalable unit cell replication

**Success Criteria**:
- Accurate lattice geometry
- Proper symmetry implementation
- Correct atomic positions

**Reference Equations** (Context Only):
```
Lattice point: r = n₁a₁ + n₂a₂ + n₃a₃
Unit cell: fundamental repeat unit
Space group: symmetry operations
```

**Tags**: crystal, lattice, crystallography, symmetry, structure, intermediate

---

### **Problem 092: Tidal Deformation**

**Objective**: Simulate tidal deformation effects on celestial bodies using gravitational field gradients.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Gravitational physics, tidal forces, and celestial mechanics

**Inputs**:
- `attribute vec3 position` - surface vertices
- `uniform vec3 primaryMass` - main gravitational source
- `uniform vec3 objectCenter` - deformed object center
- `uniform float massRatio` - gravitational parameter

**Expected Outputs**:
- Prolate deformation toward gravitational source
- Proper tidal bulge geometry
- Realistic deformation magnitude

**Success Criteria**:
- Accurate tidal force calculation
- Proper deformation orientation
- Realistic deformation amplitude

**Reference Equations** (Context Only):
```
Tidal force: F_t ∝ GM(r/R³) along radial direction
Roche limit: critical distance for tidal disruption
Deformation: elongation toward perturbing mass
```

**Tags**: tidal-forces, gravity, deformation, celestial-mechanics, roche-limit, advanced

---

### **Problem 093: Spiral Galaxy Arms**

**Objective**: Generate spiral galaxy structure using logarithmic spiral mathematics and stellar distribution.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Galactic astronomy, spiral geometry, and stellar population synthesis

**Inputs**:
- `attribute vec3 position` - star positions in galactic plane
- `uniform float spiralPitch` - spiral arm pitch angle
- `uniform float rotationCurve` - galactic rotation
- `uniform float time` - galactic evolution time

**Expected Outputs**:
- Realistic spiral arm structure
- Proper stellar density distribution
- Rotating galaxy animation

**Success Criteria**:
- Accurate spiral geometry
- Proper stellar population gradients
- Realistic galactic rotation

**Reference Equations** (Context Only):
```
Logarithmic spiral: r = a*e^(bθ)
Pitch angle: tan(i) = r*(dθ/dr)
Rotation curve: v(r) galactic velocity profile
```

**Tags**: galaxy, spiral, stellar-distribution, astronomy, logarithmic-spiral, intermediate

---

### **Problem 094: DNA Double Helix**

**Objective**: Generate accurate DNA double helix geometry with proper base pair positioning and helical parameters.

**Shader Type**: Vertex Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Molecular geometry, helical structures, and biochemical modeling

**Inputs**:
- `attribute float baseIndex` - position along DNA sequence
- `uniform float helixRadius` - helix radius
- `uniform float helixPitch` - base pairs per turn
- `uniform float twist` - rotation animation

**Expected Outputs**:
- Accurate double helix structure
- Proper base pair spacing
- Realistic molecular proportions

**Success Criteria**:
- Correct helical geometry
- Accurate base pair positioning
- Proper major/minor groove structure

**Reference Equations** (Context Only):
```
Helix parametrization: x = r*cos(θ), y = r*sin(θ), z = h*θ
Base pair spacing: 3.4 Å between consecutive pairs
Major groove: wider spacing, minor groove: narrower
```

**Tags**: dna, helix, molecular, biochemistry, double-helix, intermediate

---

### **Problem 095: Quantum Orbital Shapes**

**Objective**: Visualize atomic orbital shapes using quantum mechanical wave function mathematics.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Quantum mechanics, atomic orbitals, and spherical harmonics

**Inputs**:
- `attribute vec3 position` - sampling points in 3D space
- `uniform int n, l, m` - quantum numbers
- `uniform float scale` - orbital size scaling
- `uniform float threshold` - probability density cutoff

**Expected Outputs**:
- Accurate orbital shape visualization
- Proper angular node structure
- Realistic probability distributions

**Success Criteria**:
- Mathematically correct orbital shapes
- Proper quantum number dependence
- Accurate nodal surface positioning

**Reference Equations** (Context Only):
```
Wave function: ψ(r,θ,φ) = R_nl(r) * Y_l^m(θ,φ)
Spherical harmonics: Y_l^m(θ,φ) angular dependence
Radial function: R_nl(r) with associated Laguerre polynomials
```

**Tags**: quantum, orbitals, atomic, spherical-harmonics, wave-function, advanced

---

### **Problem 096: Mandelbrot 3D**

**Objective**: Generate 3D Mandelbrot set visualization using quaternion mathematics and iterative algorithms.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: 3D fractals, quaternion algebra, and complex dynamical systems

**Inputs**:
- `attribute vec3 position` - 3D coordinate sampling points
- `uniform int maxIterations` - iteration limit
- `uniform float escapeRadius` - divergence threshold
- `uniform vec4 quaternionC` - quaternion constant parameter

**Expected Outputs**:
- 3D Mandelbrot fractal structure
- Proper iteration-based coloring
- Self-similar fractal details

**Success Criteria**:
- Accurate quaternion iteration
- Proper escape condition testing
- Clear fractal boundary definition

**Reference Equations** (Context Only):
```
Quaternion iteration: q_{n+1} = q_n² + c
Quaternion multiplication: (a+bi+cj+dk)²
Escape condition: |q_n| > escape_radius
```

**Tags**: mandelbrot-3d, quaternion, fractal, iteration, complex-dynamics, advanced

---

### **Problem 097: Muscle Fiber Simulation**

**Objective**: Simulate muscle fiber contraction using biomechanical models and vertex deformation.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Biomechanics, muscle physiology, and elastic deformation

**Inputs**:
- `attribute vec3 position` - muscle fiber vertices
- `attribute vec3 fiberDirection` - muscle fiber orientation
- `uniform float activation` - muscle activation level [0,1]
- `uniform float sarcomereLength` - basic contractile unit length

**Expected Outputs**:
- Realistic muscle contraction
- Proper fiber shortening and thickening
- Biomechanically accurate deformation

**Success Criteria**:
- Accurate force-length relationships
- Proper volume conservation
- Realistic activation dynamics

**Reference Equations** (Context Only):
```
Contractile force: F = F_max * activation * f(length)
Muscle shortening: ΔL ∝ activation level
Volume conservation: cross-sectional area increases
```

**Tags**: muscle, biomechanics, contraction, fiber-dynamics, physiology, advanced

---

### **Problem 098: Plasma Instabilities**

**Objective**: Simulate plasma instability growth using magnetohydrodynamic equations and vertex displacement.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Plasma physics, magnetohydrodynamics, and instability theory

**Inputs**:
- `attribute vec3 position` - plasma element positions
- `uniform vec3 magneticField` - background magnetic field
- `uniform float density` - plasma density
- `uniform float time` - instability evolution time

**Expected Outputs**:
- Growing plasma instability patterns
- Proper magnetic field line distortion
- Realistic plasma turbulence

**Success Criteria**:
- Accurate instability growth rates
- Proper magnetic field coupling
- Realistic turbulent structure

**Reference Equations** (Context Only):
```
MHD equations: ρ(∂v/∂t + v·∇v) = -∇p + (∇×B)×B/μ₀
Instability growth: exponential amplification
Magnetic field evolution: ∂B/∂t = ∇×(v×B)
```

**Tags**: plasma, instabilities, mhd, magnetic-field, turbulence, advanced

---

### **Problem 099: Topology Morphing**

**Objective**: Smoothly morph between different topological structures while preserving geometric constraints.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Topology, differential geometry, and smooth manifold deformation

**Inputs**:
- `attribute vec3 position1` - source topology vertices
- `attribute vec3 position2` - target topology vertices
- `uniform float morphParameter` - interpolation parameter
- `uniform mat4 topologyMatrix` - topological transformation

**Expected Outputs**:
- Smooth topological transitions
- Preserved geometric constraints
- No self-intersections during morphing

**Success Criteria**:
- Topologically consistent morphing
- Smooth geometric transitions
- Proper constraint satisfaction

**Reference Equations** (Context Only):
```
Topological invariants: genus, Euler characteristic
Smooth interpolation: geodesic paths on manifold
Constraint preservation: distance and angle constraints
```

**Tags**: topology, morphing, manifold, geometric-constraints, differential-geometry, advanced

---

### **Problem 100: Schwarzschild Geodesics**

**Objective**: Visualize particle trajectories following geodesics in Schwarzschild spacetime geometry.

**Shader Type**: Vertex Shader

**Difficulty Level**: Advanced

**Mathematical Context**: General relativity, geodesic equations, and curved spacetime geometry

**Inputs**:
- `attribute vec4 worldline` - spacetime coordinates (t,r,θ,φ)
- `uniform float schwarzschildRadius` - gravitational radius
- `uniform vec4 initialVelocity` - particle 4-velocity
- `uniform float properTime` - evolution parameter

**Expected Outputs**:
- Curved particle trajectories
- Proper time dilation effects
- Realistic orbital mechanics

**Success Criteria**:
- Accurate geodesic integration
- Proper relativistic effects
- Stable orbital solutions

**Reference Equations** (Context Only):
```
Geodesic equation: d²x^μ/dτ² + Γ^μ_νρ (dx^ν/dτ)(dx^ρ/dτ) = 0
Schwarzschild metric: ds² = -(1-2M/r)dt² + dr²/(1-2M/r) + r²dΩ²
Christoffel symbols: Γ^μ_νρ from metric tensor
```

**Tags**: relativity, geodesics, schwarzschild, spacetime, orbital-mechanics, advanced

---

**Total Problems Created**: 100

This comprehensive set of shader programming challenges covers the full spectrum from beginner to advanced levels, focusing on:

- **Beginner (25 problems)**: Basic shapes, colors, patterns, simple animations
- **Intermediate (30 problems)**: Lighting models, procedural generation, complex animations, physics simulations  
- **Advanced (25 problems)**: Ray tracing, volumetrics, fractals, quantum mechanics, astrophysics
- **Vertex Shaders (20 problems)**: Geometry manipulation, deformation, animation systems

Each challenge includes clear objectives, mathematical context, success criteria, and reference equations to guide implementation while testing LLM code generation capabilities effectively.