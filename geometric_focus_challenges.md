# Geometric Focus Shader Challenges
## 20 Pure Geometric Beauty Challenges for LLM Testing

**Created by**: Geometric Focus Agent  
**Focus**: Pure geometric forms and mathematical elegance  
**Target**: Distance field rendering, parametric surfaces, fractal geometry  
**Total Challenges**: 20  

---

### **Problem 001: Sierpinski Triangle Fractal**

**Objective**: Generate a 2D Sierpinski triangle fractal using recursive subdivision or iterative construction.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Self-similar fractal geometry, recursive triangular subdivision

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float iterations` - recursion depth control
- `uniform vec2 resolution` - screen resolution

**Expected Outputs**:
- Sharp, mathematically precise Sierpinski triangle
- Clear fractal structure at multiple scales
- High contrast black and white pattern

**Success Criteria**:
- Triangle maintains perfect self-similarity
- Clean geometric boundaries without aliasing
- Scalable iteration depth without performance issues

**Reference Equations** (Context Only):
```
Sierpinski: Remove center triangles recursively
Barycentric coordinates for triangle membership
```

**Tags**: fractal, 2d, recursive, geometric-pattern

---

### **Problem 002: 3D Sierpinski Pyramid (Tetrahedron Fractal)**

**Objective**: Render a 3D Sierpinski pyramid using distance field raymarching with proper lighting.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: 3D fractal geometry, tetrahedral recursion, distance field construction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - rotation animation
- `uniform int iterations` - fractal depth
- `uniform vec3 lightPos` - lighting position

**Expected Outputs**:
- Volumetric 3D tetrahedral fractal
- Smooth rotation animation
- Proper surface normals and lighting

**Success Criteria**:
- Maintains tetrahedral self-similarity in 3D
- Smooth lighting across fractal surfaces
- Real-time performance with reasonable iteration count

**Reference Equations** (Context Only):
```
Tetrahedron SDF: max of 4 plane distances
Fractal: Recursive tetrahedron subdivision
```

**Tags**: fractal, 3d, tetrahedron, distance-field, lighting

---

### **Problem 003: Perfect Platonic Solids Collection**

**Objective**: Render all five Platonic solids (tetrahedron, cube, octahedron, dodecahedron, icosahedron) with distance fields.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Regular polyhedra, distance field construction, geometric perfection

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - animation timer
- `uniform int solidType` - which Platonic solid to display
- `uniform vec3 rotation` - rotation parameters

**Expected Outputs**:
- Mathematically perfect Platonic solids
- Smooth transitions between different solids
- Proper geometric proportions and symmetry

**Success Criteria**:
- Each solid maintains perfect regularity
- All faces/edges are geometrically equivalent
- Smooth animation and lighting

**Reference Equations** (Context Only):
```
Tetrahedron: 4 triangular faces
Cube: 6 square faces  
Octahedron: 8 triangular faces
Dodecahedron: 12 pentagonal faces
Icosahedron: 20 triangular faces
```

**Tags**: platonic-solids, 3d, distance-field, geometry, perfect-forms

---

### **Problem 004: Multi-Pointed Star Polygon Generator**

**Objective**: Create parametric 2D star polygons with configurable points (5, 6, 8, 12-pointed stars).

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Regular star polygon construction, angular mathematics, parametric curves

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform int points` - number of star points
- `uniform float innerRadius` - inner radius ratio
- `uniform float rotation` - rotation angle

**Expected Outputs**:
- Sharp, geometrically perfect star shapes
- Configurable number of points and proportions
- Clean edges and symmetric form

**Success Criteria**:
- Stars maintain perfect rotational symmetry
- Smooth parameter transitions
- Mathematical precision in point placement

**Reference Equations** (Context Only):
```
Star polygon: alternating outer/inner vertices
Angular step: 2π/n for n-pointed star
Polar coordinates: (r, θ) system
```

**Tags**: star-polygon, 2d, parametric, geometric-construction

---

### **Problem 005: 3D Barbell (Dumbbell) Shape**

**Objective**: Construct a 3D barbell shape using sphere-cylinder combinations with distance field blending.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Constructive solid geometry, distance field operations, primitive combinations

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float sphereRadius` - end sphere size
- `uniform float cylinderRadius` - connecting bar radius
- `uniform float length` - total barbell length

**Expected Outputs**:
- Smooth barbell with two spherical ends
- Cylindrical connecting bar
- Seamless geometric transitions

**Success Criteria**:
- Perfect sphere-cylinder connections
- Smooth surface normals at junctions
- Scalable proportions

**Reference Equations** (Context Only):
```
Sphere SDF: length(p) - radius
Cylinder SDF: length(p.xz) - radius
Union operation: min(sdf1, sdf2)
```

**Tags**: barbell, 3d, distance-field, primitive-combination

---

### **Problem 006: 2D Fractal Tree Generator**

**Objective**: Generate a 2D fractal tree with configurable branching angle and recursion depth.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: L-system fractals, recursive branching, tree generation algorithms

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float branchAngle` - branching angle in radians
- `uniform int depth` - recursion depth
- `uniform float lengthRatio` - branch length reduction factor

**Expected Outputs**:
- Natural-looking fractal tree structure
- Consistent branching patterns
- Scalable complexity with depth parameter

**Success Criteria**:
- Branches follow mathematical growth rules
- No overlapping or disconnected segments
- Smooth scaling with parameters

**Reference Equations** (Context Only):
```
Branch generation: recursive L-system rules
Rotation matrix: cos/sin transformations
Scaling factor: geometric progression
```

**Tags**: fractal-tree, 2d, recursive, branching, l-system

---

### **Problem 007: 3D Fractal Tree with Cylindrical Branches**

**Objective**: Create a 3D fractal tree using cylindrical branches and distance field operations.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: 3D recursive structures, cylindrical geometry, fractal growth patterns

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - animation parameter
- `uniform vec3 branchDirection` - primary growth direction
- `uniform int generations` - tree complexity

**Expected Outputs**:
- Volumetric 3D tree structure
- Realistic branching with proper thickness variation
- Smooth surface rendering with lighting

**Success Criteria**:
- Branches taper naturally with generation
- No intersection artifacts between branches
- Maintains tree-like proportions

**Reference Equations** (Context Only):
```
Cylinder SDF: distance to axis + radius check
Branch transformation: rotation + translation
Thickness reduction: exponential decay
```

**Tags**: fractal-tree, 3d, cylindrical, branching, volumetric

---

### **Problem 008: Regular Torus with Perfect Geometry**

**Objective**: Render a mathematically perfect torus using parametric surface definition.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Parametric torus definition, surface of revolution, distance fields

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float majorRadius` - main torus radius
- `uniform float minorRadius` - tube radius
- `uniform vec3 rotation` - orientation parameters

**Expected Outputs**:
- Smooth torus surface with proper proportions
- Clean surface normals for lighting
- No geometric distortions

**Success Criteria**:
- Maintains perfect circular cross-sections
- Smooth surface everywhere
- Mathematically accurate proportions

**Reference Equations** (Context Only):
```
Torus SDF: length(vec2(length(p.xz) - R, p.y)) - r
Parametric: (R + r*cos(v))*cos(u), (R + r*cos(v))*sin(u), r*sin(v)
```

**Tags**: torus, 3d, parametric-surface, distance-field

---

### **Problem 009: Capsule (Rounded Cylinder) Shape**

**Objective**: Create a perfect capsule shape using distance field construction with hemispherical ends.

**Shader Type**: Fragment Shader

**Difficulty Level**: Beginner

**Mathematical Context**: Capsule geometry, distance field primitives, rounded shapes

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float height` - cylinder height
- `uniform float radius` - capsule radius
- `uniform vec3 orientation` - capsule axis direction

**Expected Outputs**:
- Smooth capsule with hemispherical ends
- Seamless cylinder-sphere transitions
- Proper surface normal calculation

**Success Criteria**:
- Perfect geometric continuity at transitions
- Uniform radius throughout
- Clean surface normals

**Reference Equations** (Context Only):
```
Capsule SDF: cylinder with clamped height + sphere caps
Distance to line segment + radius
```

**Tags**: capsule, 3d, distance-field, rounded-cylinder

---

### **Problem 010: Regular Polygon Construction**

**Objective**: Generate regular polygons (triangle, square, pentagon, hexagon, octagon) with perfect symmetry.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Regular polygon geometry, angular symmetry, distance field construction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform int sides` - number of polygon sides
- `uniform float radius` - polygon circumradius
- `uniform float rotation` - rotation angle

**Expected Outputs**:
- Sharp-edged regular polygons
- Perfect rotational symmetry
- Scalable side count

**Success Criteria**:
- All sides exactly equal length
- All angles exactly equal
- Clean geometric boundaries

**Reference Equations** (Context Only):
```
Regular polygon: vertices at 2πk/n intervals
Distance to polygon edge
Angular symmetry: 2π/n rotation
```

**Tags**: regular-polygon, 2d, geometric-construction, symmetry

---

### **Problem 011: Rounded Box (Cube with Filleted Edges)**

**Objective**: Create a cube with rounded edges using distance field operations and smooth blending.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Rounded primitive construction, distance field modification, geometric blending

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform vec3 dimensions` - box dimensions
- `uniform float roundness` - edge rounding radius
- `uniform vec3 rotation` - orientation

**Expected Outputs**:
- Cube with smoothly rounded edges and corners
- Maintains box proportions with rounding
- Clean surface transitions

**Success Criteria**:
- Consistent rounding radius throughout
- No geometric artifacts at corners
- Smooth surface normals everywhere

**Reference Equations** (Context Only):
```
Rounded box SDF: box SDF - rounding radius
Distance field modification
Corner blending operations
```

**Tags**: rounded-box, 3d, distance-field, blending, smooth-geometry

---

### **Problem 012: Platonic Solid Wireframes**

**Objective**: Render wireframe representations of Platonic solids showing only edges and vertices.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Edge detection, wireframe rendering, geometric topology

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform int solidType` - which Platonic solid
- `uniform float lineWidth` - wireframe thickness
- `uniform vec3 rotation` - rotation parameters

**Expected Outputs**:
- Clean wireframe showing only geometric edges
- Proper depth ordering of lines
- Sharp, well-defined edge lines

**Success Criteria**:
- All geometric edges clearly visible
- No spurious lines or missing edges
- Consistent line thickness

**Reference Equations** (Context Only):
```
Edge detection: distance to geometric edges
Line rendering: distance field techniques
Platonic solid edge definitions
```

**Tags**: wireframe, platonic-solids, edges, geometric-topology

---

### **Problem 013: 2D Sierpinski Carpet**

**Objective**: Generate the Sierpinski carpet fractal using recursive square subdivision.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Area-filling fractal, recursive subdivision, geometric self-similarity

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform int iterations` - subdivision depth
- `uniform vec2 offset` - pattern offset
- `uniform float scale` - zoom level

**Expected Outputs**:
- Clear Sierpinski carpet pattern
- Perfect self-similarity at all scales
- Sharp geometric boundaries

**Success Criteria**:
- Maintains fractal structure at all iterations
- Clean square subdivisions
- No blurring or artifacts

**Reference Equations** (Context Only):
```
Sierpinski carpet: remove center squares recursively
3x3 grid subdivision pattern
Coordinate transformation for recursion
```

**Tags**: sierpinski-carpet, 2d, fractal, recursive, area-filling

---

### **Problem 014: 3D Icosahedron with Golden Ratio**

**Objective**: Construct a perfect icosahedron using golden ratio proportions and distance field rendering.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Icosahedral geometry, golden ratio mathematics, regular polyhedra

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - rotation animation
- `uniform vec3 lightDirection` - lighting direction
- `uniform float scale` - size parameter

**Expected Outputs**:
- Geometrically perfect icosahedron
- Golden ratio proportions maintained
- Smooth rotation and lighting

**Success Criteria**:
- All 20 triangular faces identical
- Correct golden ratio edge relationships
- Perfect 5-fold rotational symmetry

**Reference Equations** (Context Only):
```
Golden ratio φ = (1 + √5)/2
Icosahedron vertices using φ proportions
20 equilateral triangular faces
```

**Tags**: icosahedron, golden-ratio, 3d, platonic-solid, perfect-geometry

---

### **Problem 015: Hexagonal Close-Packed Structure**

**Objective**: Create a 2D hexagonal tiling pattern with perfect geometric regularity.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate

**Mathematical Context**: Hexagonal tiling, regular tessellation, geometric packing

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float hexSize` - hexagon size
- `uniform vec2 offset` - pattern offset
- `uniform float time` - animation parameter

**Expected Outputs**:
- Perfect hexagonal tiling pattern
- No gaps or overlaps between hexagons
- Clean geometric boundaries

**Success Criteria**:
- All hexagons perfectly regular
- Seamless tiling across screen
- Maintains proportions at all scales

**Reference Equations** (Context Only):
```
Hexagonal coordinates
Regular hexagon construction
Tessellation mathematics
```

**Tags**: hexagonal-tiling, 2d, tessellation, regular-pattern

---

### **Problem 016: 3D Dodecahedron with Pentagonal Faces**

**Objective**: Render a perfect dodecahedron emphasizing its 12 pentagonal faces using distance fields.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Dodecahedral geometry, pentagonal face construction, regular polyhedra

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform vec3 rotation` - rotation parameters
- `uniform float time` - animation timer
- `uniform vec3 cameraPos` - camera position

**Expected Outputs**:
- Perfect dodecahedron with 12 pentagonal faces
- Clear face boundaries and edges
- Proper geometric proportions

**Success Criteria**:
- All 12 faces are regular pentagons
- Maintains perfect symmetry
- Clean surface rendering

**Reference Equations** (Context Only):
```
Dodecahedron: 12 pentagonal faces
Regular pentagon construction
Platonic solid geometry
```

**Tags**: dodecahedron, pentagonal-faces, 3d, platonic-solid

---

### **Problem 017: Star Tetrahedron (Stella Octangula)**

**Objective**: Create a compound of two interpenetrating tetrahedra forming a three-dimensional star.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Compound polyhedra, tetrahedral geometry, 3D star construction

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - rotation animation
- `uniform float separation` - tetrahedron offset
- `uniform vec3 colors[2]` - colors for each tetrahedron

**Expected Outputs**:
- Two interpenetrating tetrahedra
- Clear geometric star pattern
- Proper depth ordering and blending

**Success Criteria**:
- Both tetrahedra maintain perfect geometry
- Clear visual separation of components
- Smooth animation and intersection handling

**Reference Equations** (Context Only):
```
Compound tetrahedron: dual tetrahedra
Stella octangula construction
3D star polyhedron geometry
```

**Tags**: star-tetrahedron, compound-polyhedra, 3d, geometric-star

---

### **Problem 018: 2D Penrose Tiling Pattern**

**Objective**: Generate a portion of the Penrose tiling using rhomb tiles with perfect geometric precision.

**Shader Type**: Fragment Shader

**Difficulty Level**: Expert

**Mathematical Context**: Quasicrystalline tiling, golden ratio geometry, aperiodic tessellation

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float scale` - tiling scale
- `uniform vec2 offset` - pattern offset
- `uniform int tileType` - rhomb type selection

**Expected Outputs**:
- Mathematically correct Penrose tiling
- Perfect rhomb tile geometry
- No periodic repetition

**Success Criteria**:
- Tiles follow Penrose matching rules
- Golden ratio proportions maintained
- Aperiodic tiling structure

**Reference Equations** (Context Only):
```
Penrose rhombs: golden ratio angles
Quasicrystalline structure
Aperiodic tiling mathematics
```

**Tags**: penrose-tiling, rhombs, aperiodic, golden-ratio, quasicrystal

---

### **Problem 019: 3D Tetrahedron with Dual Relationship**

**Objective**: Render a tetrahedron showing its self-dual nature with inscribed/circumscribed relationships.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Dual polyhedra, tetrahedral self-duality, geometric relationships

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float dualScale` - dual tetrahedron scale
- `uniform float time` - animation parameter
- `uniform bool showDual` - dual visibility toggle

**Expected Outputs**:
- Primary tetrahedron with clear geometry
- Dual tetrahedron showing self-dual relationship
- Proper geometric proportions and alignment

**Success Criteria**:
- Both tetrahedra geometrically perfect
- Correct dual relationship positioning
- Clear visualization of self-dual nature

**Reference Equations** (Context Only):
```
Tetrahedron self-duality
Dual polyhedron construction
Geometric center relationships
```

**Tags**: tetrahedron, self-dual, geometric-relationships, dual-polyhedra

---

### **Problem 020: 3D Geometric Kaleidoscope**

**Objective**: Create a kaleidoscopic effect using geometric symmetry operations on basic shapes.

**Shader Type**: Fragment Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Symmetry groups, geometric transformations, kaleidoscopic reflections

**Inputs**:
- `vec2 fragCoord` - fragment coordinates
- `uniform float time` - animation timer
- `uniform int symmetryOrder` - rotational symmetry order
- `uniform float reflectionAngle` - mirror plane angle

**Expected Outputs**:
- Perfect geometric kaleidoscope pattern
- Multiple reflection symmetries
- Smooth animation with geometric precision

**Success Criteria**:
- Maintains perfect symmetry throughout animation
- Clean geometric reflections
- No distortion in symmetric patterns

**Reference Equations** (Context Only):
```
Kaleidoscope: multiple mirror reflections
Symmetry group operations
Geometric transformation matrices
```

**Tags**: kaleidoscope, symmetry, geometric-transformations, reflections

---

## Summary

These 20 challenges focus on **pure geometric beauty** and **mathematical perfection**:

- **Fractal Geometry**: Sierpinski triangle, pyramid, carpet, and fractal trees
- **Platonic Solids**: All five regular polyhedra with various presentations
- **Star Shapes**: Multi-pointed stars, star tetrahedron, geometric stars
- **Perfect Forms**: Torus, capsule, rounded box, regular polygons
- **Advanced Geometry**: Penrose tiling, kaleidoscope, compound polyhedra

Each challenge emphasizes:
- Mathematical precision and accuracy
- Clean geometric construction
- Distance field techniques for 3D rendering
- Pure geometric elegance without mystical elements
- Scalable complexity and parametric control

The challenges progress from intermediate to expert level, focusing on geometric concepts that showcase the beauty of mathematical forms and their computational representation.