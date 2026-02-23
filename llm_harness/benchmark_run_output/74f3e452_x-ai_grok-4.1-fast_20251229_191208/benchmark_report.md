# Shader Benchmark Report

**Model:** x-ai/grok-4.1-fast
**Generated:** 2025-12-29 19:49:25
**Total Tests:** 3
**Successful Renders:** 1
**Success Rate:** 1/3 (33.3%)
**Scored Tests:** 1  

---

## Summary Statistics

### Average Scores by Category

| Category | Average Score |
|----------|---------------|
| Mathematical Accuracy | 75.0/100 |
| Visual Quality | 60.0/100 |
| Color Implementation | 65.0/100 |
| Geometric Completeness | 55.0/100 |
| Reference Elements | 70.0/100 |
| **Overall Average** | **65.0/100** |

### Performance Highlights

**Best Test:** Apollonian Gasket (Total: 325/500)  
**Worst Test:** Apollonian Gasket (Total: 325/500)  

---

## Detailed Test Results

### Test 1: Ackermann Function Growth

**Test ID:** `000_ackermann_function_growth`  
**Shader Files:** shader_0.wgsl  
**Execution Status:** ❌ Failed  
**Image Generated:** ❌ No  
**Judge Scores:** ✅ Available  

#### Problem Prompt

> The plot should shock the viewer by how astronomically fast the Ackermann function explodes, even for modest inputs. Use a log₁₀ axis so the bars fit on screen yet their heights still dwarf each other.
> 
> Data table:
> A(3,n) values:
> - n=0: 1
> - n=1: 2
> - n=2: 2^2-1 = 3
> - n=3: 2^(2^2)-3 = 13
> - n=4: 2^(2^(2^2))-3 = 65533
> - n=5 through n=10: exponential towers of increasing height
> 
> Pre-compute exact integer values using bignum arithmetic; convert to log₁₀ with high-precision (at least 50 digits).
> 
> Visual spec:
> - Canvas 1600 × 1200, white background
> - 11 vertical bars, equally spaced 80 px apart
> - Bar widths 40 px; top-cap rounded
> - Fill colour gradient deep-blue (#0033CC) for n=0 to searing-red (#FF3300) for n=10 (linear in n)
> - y-axis log₁₀ scale 0→10, grid-lines every integer decade
> - Annotate each bar with exact exponent-tower notation beneath x-axis
> 
> Deliverable: Outputs a single image.

#### Rendered Output

*No image available (compilation or execution failed)*

---

### Test 2: Apollonian Gasket

**Test ID:** `002_apollonian_gasket`  
**Shader Files:** shader_0.wgsl  
**Execution Status:** ✅ Success  
**Image Generated:** ✅ Yes  
**Judge Scores:** ✅ Available  

#### Problem Prompt

> Craft a high-resolution, jewel-like image of the classical Apollonian gasket that emerges as the limit set of a rank-2 Kleinian group. The red and green "facets" should interlace so finely that the boundary between them looks like crystalline edges under a microscope.
> 
> Mathematical engine:
> 1. Möbius generators: Work in the Riemann sphere (identify plane C∪{∞}). Let
>    M₁(z) = (2z+1)/(z+1), M₂(z) = (2z-1)/(z-1)
> 2. Symbolic address & parity: Every orbit point is encoded by a word in {1, 2}. Mark points whose last generator is even length word in red (#ff3355) and odd length in green (#33ff55).
> 3. Sampling:
>    - Begin with seed z₀ = 0
>    - Randomly walk 3,000,000 steps (alias method, equal probability)
>    - Discard first 12 iterates of every walk to bypass transient region; plot the next 9 iterations (depth-limiting to emphasise detail)
> 
> Projection & canvas:
> - Use stereographic projection to map sphere to plane; scale so outermost circle fits a 2400 × 2400 px square with 120 px padding
> - Background pure black (#000000)
> - Each orbit point rendered as sub-pixel disk radius 0.6 px; enable additive alpha so high-density regions glow
> - After plotting, apply a single-pass Gaussian bloom σ = 1 px, 40% opacity, to make bright clusters sparkle
> 
> File: PNG-24, sRGB
> Deliverable: Outputs a single image.

#### Judge Scores

| Category | Score |
|----------|-------|
| Mathematical Accuracy | 75/100 |
| Visual Quality | 60/100 |
| Color Implementation | 65/100 |
| Geometric Completeness | 55/100 |
| Reference Elements | 70/100 |
| **Total** | **325/500** |
| **Average** | **65.0/100** |


#### Rendered Output

![Rendered Output](images/002_apollonian_gasket_result.png)

---

### Test 3: Apollonius Conic Sections

**Test ID:** `003_apollonius_conic_sections`  
**Shader Files:** shader_0.wgsl  
**Execution Status:** ❌ Failed  
**Image Generated:** ❌ No  
**Judge Scores:** ✅ Available  

#### Problem Prompt

> **Objective**
> Create a shader visualization of Apollonius's Conic Sections as they were understood in ancient Greece (~200 BCE), showing all three conic types emerging from a single double cone through different cutting planes, honoring the geometric construction methods of antiquity.
> 
> **Historical Context**
> Apollonius of Perga (c. 240-190 BCE), known as "The Great Geometer," revolutionized the study of conic sections in his eight-volume treatise "Conics." Unlike his predecessors who used finite right circular cones, Apollonius considered arbitrary oblique double cones extending infinitely in both directions. His definitions of ellipse, parabola, and hyperbola remain in use today.
> 
> **Mathematical Specification**
> 
> 1. **The Double Cone Construction**
>    - Generate an infinite double cone with vertex at origin
>    - Cone angle: 30° from vertical axis
>    - Use parametric form: x² + y² = (z·tan(30°))²
>    - Extend from z = -3 to z = 3 for visualization
> 
> 2. **Three Classical Cutting Planes**
>    - **Ellipse**: Plane at 45° angle to cone axis, intersecting both nappes
>    - **Parabola**: Plane parallel to cone generator (exactly 30° from vertical)
>    - **Hyperbola**: Plane at 15° angle to cone axis (steeper than cone angle)
> 
> 3. **Ancient Greek Construction Visualization**
>    - Show the cone as translucent wireframe (like ancient diagrams)
>    - Display cutting planes as semi-transparent colored surfaces
>    - Highlight the intersection curves in bold, using ancient color symbolism:
>      * Ellipse: Deep blue (celestial motion)
>      * Parabola: Green (earthly trajectories)
>      * Hyperbola: Red (infinite extension)
> 
> 4. **Geometric Annotations**
>    - Add construction lines showing:
>      * Cone generators (straight lines on cone surface)
>      * Plane normal vectors
>      * Dandelin spheres tangent points (optional advanced feature)
>    - Include Greek letters α, β, γ for the three plane angles
> 
> 5. **Rendering Requirements**
>    - Use orthographic projection (as Greeks would have drawn)
>    - Apply subtle shading to show 3D form while maintaining diagram clarity
>    - Background: Parchment color (#F4E8D0)
>    - Include a small inset showing Apollonius's original cone diagram style
>    - Resolution: 1600×1600 pixels minimum
> 
> **Educational Goals**
> - Demonstrate how all conic sections emerge from a single geometric object
> - Show the elegance of ancient Greek mathematical visualization
> - Connect historical mathematics to modern computer graphics
> - Honor Apollonius's systematic approach to mathematical classification
> 
> **Deliverable**
> A single shader that renders this complete historical mathematical visualization, bringing ancient geometric wisdom into the modern digital age.

#### Rendered Output

*No image available (compilation or execution failed)*

---

