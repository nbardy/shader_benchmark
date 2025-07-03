# Visual Programming Benchmark

Currently all vision LLM benchmarks are focused on visual analysis (Give an image return fact X). No one is focusing on the opposite. Given X, make me an image! This benchmark fixes that with a set of challenging visual programming problems and a benchmark to judge them. Current models perform very poorly on these problems in a zero-shot setting, but can be incredibly capable when paired with a human. Current models have become incredibly capable at visual programming and have gone from basic to WOW!. For evidence check out my recent shadertoy collection (https://www.shadertoy.com/user/nbardy/sort=newest) all created with chatgpt and friends. Most of these are made by me passing back and forth rendering of each result and building up a long chain of context and critique until the model can get it right, as well as copy and pasting wikipedia articles in context. You **CAN** get LLMs to do advanced shader math and geometry, but it's a **LOT** of time and work. This shows a spark of generalization and with the current rapid pace of LLM development a spark of generalization turns into Expertise within months. All you need is a benchmark to motivate researchers. This benchmark aims to give LLM Researchers a platform to train and test their models in visual programming tasks. Sets out the ambitious goal of lowering the bar for advanced visual programming to the masses. Soon you can just ask ChatGPT for a demo reel!

Each problem has a prompt to ask the model for a shader.
Evaluates the shader
And uses a VLLM as a judge to test the success of the results across a rubric.

## Problems

### #1 - Hopf Fibration
A complex 4D dimensional object rendered in 3D via fibrations

### #2 - Menger Cube
A simple basic fractal

### #3 - Hyper Meneger Cube intersects the 3-Sphere in 4D dimensions
A 4d dimensional intersection rendering

### #4 A clear class spherical shell with a glowing red solid sphere inside
A Classic raytracing demo

### #5 - Poincaré Disc 
Regular hyperbolic triangle tessellation {3,8} in the Poincaré disk model with checkerboard coloring

### #6 - Mandelbulb Fractal (Advanced)
Order-8 Mandelbulb fractal with ray-marching, distance estimation, and rainbow escape-time coloring

### #7 - Voronoi Diagram (Intermediate) 
30-seed Voronoi tessellation with Poisson-disk sampling and distinct Tableau-20 coloring

### #8 - Crystal Lattice Diffraction (Advanced)
2D X-ray diffraction pattern of FCC crystal with proper structure factors and intensity mapping

### #9 - Schwarzschild Black Hole (Advanced)
Gravitational lensing visualization with starfield distortion and photon ring highlighting

### #10 - Reaction-Diffusion Patterns (Advanced)
Gray-Scott reaction-diffusion system simulation with zebra/spot patterns and turbo colormap

### #11 - Holographic Interference (Advanced)
RGB interference pattern from two coherent plane waves intersecting at 20° angle

### #12 - Menger Sponge Fractal (Advanced)
Order-4 Menger sponge ray-marching with signed distance functions and soft shadows

### #13 - Quantum Probability Waves (Advanced)
2D infinite square-well eigenstate superposition with magma palette and isolines

### #14 - Hopf Fibration 4D → 3D (Advanced)
Complete Hopf fibration visualization with stereographic projection from S³ to ℝ³

### #15 - Riemann Surface with Branch Cuts (Advanced)
Two-sheet Riemann surface of w=√z with branch cut along negative real axis

### #16 - Penrose Tiling (P3) (Advanced)
Rhombic Penrose tiling through three deflation steps with matching rule arrows

### #17 - Calabi-Yau Manifold Cross-Section (Advanced)
Quintic Calabi-Yau manifold isosurface with viridis coloring and 5-fold symmetry

### #18 - Lorenz Attractor with Poincaré Section (Advanced)
3D Lorenz butterfly trajectory with fractal Poincaré section visualization

### #19 - Mandala of Circles (Intermediate)
Sacred geometry mandala with 12-fold radial symmetry and mutually tangent circles

### #20 - Archimedean Spiral Galaxy (Advanced)
Two-arm spiral galaxy simulation with realistic star distribution and color temperature

### #21 - Rose Curves (Intermediate)
Polar curve r = cos(7θ) creating 7-petal rose pattern with grid overlay

### #22 - Epicycloids (Intermediate)
Classical epicycloid traced by circle rolling around fixed circle with 4 cusps

### #23 - Trigonometric Mandalas (Intermediate)
Harmonic mandala with multiple sine wave harmonics and radial gradient

### #24 - Cycloid Wave Patterns (Intermediate)
Classical cycloid wave tiling with mirror reflection and precise periodicity

### #25 - Five-Pointed Star Polygon (Beginner)
Regular pentagram with golden ratio proportions and proper vertex connections

### #26 - Sierpinski Triangle (Intermediate)  
6-iteration recursive fractal with 729 small triangles and perfect self-similarity

### #27 - Torus (Donut) (Intermediate)
Mathematical torus with major/minor radii and proper Phong lighting

### #28 - Barbell Shape (Beginner)
Two spheres connected by cylinder with tangent continuity and matte shading

### #29 - Icosahedron Wireframe (Intermediate)
Regular icosahedron with 30 edges, 12 vertices, and hidden edge visualization

### #30 - 2D Fractal Tree (Intermediate)
Recursive binary tree with 7 levels, ±45° branching, and perfect symmetry

## Advanced Topology & Geometry Problems (201-213)

### #201 - Möbius Strip (½-twist) (Advanced)
Single half-twist Möbius strip with dual-color visualization and topological verification

### #202 - DNA Double Helix (Advanced)
Anti-parallel helices with 3.4Å pitch, phase offset π, and 60 connecting rungs

### #203 - Trefoil Knot (Advanced)
Parametric trefoil with torsion-based coloring and three-fold rotational symmetry

### #204 - Klein Bottle (Advanced)
Non-orientable surface with self-intersection line and Gaussian curvature coloring

### #205 - Helical Twisted Cube (Advanced)
Cube with edges following true helical paths during 90° twist transformation

### #206 - Spinning Gear Assembly (Intermediate)
Three-gear kinematic system with proper tooth engagement and angular velocity vectors

### #207 - Braided Rope (Intermediate)
Three-strand helical braid with 120° phase offsets and ABCABC crossing pattern

### #208 - Twisted Stellated Polyhedron (Advanced)
Stellated dodecahedron with 20° rotated spikes creating drill-flute geometry

### #209 - Spiral Staircase Tower (Intermediate)
Twin helical staircases with 160 steps each around central column

### #210 - Rotating Hypercube Projection (Advanced)
4D tesseract with dual rotation matrices projected through 3D to 2D visualization

### #211 - Möbius Strip with 3 Half-Twists (Advanced)
Triple-twist Möbius strip with 540° rotation and three-cycle hue visualization

### #212 - Spinning Vortex Funnel (Advanced)
Fluid flow visualization with 150 logarithmic spiral streamlines and density field

### #213 - Gyroscopic Nested Rings (Intermediate)
Three concentric rings with orthogonal 30° rotations about x, y, z axes

## Historical Mathematics Visualizations (301-308)

### #301 - Apollonius's Conic Sections (~200 BCE) (Advanced)
Ancient Greek geometric construction showing ellipse, parabola, and hyperbola emerging from a double cone with different cutting planes

### #302 - Al-Khwarizmi's Geometric Algebra (9th Century) (Advanced)
Islamic Golden Age visualization of solving x² + 10x = 39 using geometric completion method that gave birth to algebra

### #303 - Archimedes' Spiral (225 BCE) (Advanced)
Ancient Greek spiral with demonstrations of angle trisection and circle quadrature using the exhaustion method

### #304 - Fermat's Parabolic Spiral (1636) (Advanced)
Renaissance mathematics showing Fermat's spiral with equal-area property and pre-calculus tangent construction

### #305 - Euler's Polyhedron Formula (1752) (Advanced)
Interactive demonstration of V - E + F = 2 through the five Platonic solids with 18th-century styling

### #306 - Gauss's Complex Plane (1831) (Advanced)
Visualization of Gaussian integers, complex primes, and the two-square theorem in 19th-century German style

### #307 - Chinese Remainder Theorem (3rd-5th Century) (Advanced)
Ancient Chinese modular arithmetic from Sunzi Suanjing with modern cryptographic connections

### #308 - Brahmagupta's Cyclic Quadrilaterals (628 CE) (Advanced)
Indian mathematical innovations including cyclic quadrilateral formula and systematic use of zero and negatives

## Implementation Status

### Missing Problem Directories
The following problems from the 80-item comprehensive list need to be implemented:

#### Basic Problems (1-30)
- [ ] **#19 - Sierpinski Pyramid** - TODO: Create sierpinski_pyramid directory
- [ ] **#21 - 3-D Fractal Tree** - TODO: Create fractal_tree_3d directory  
- [ ] **#23 - Eight-Pointed Star** - TODO: Create eight_pointed_star directory
- [ ] **#24 - Star Tetrahedron** - TODO: Create star_tetrahedron directory
- [ ] **#25 - Perfect Tetrahedron** - TODO: Create perfect_tetrahedron directory
- [ ] **#26 - Geometric Cube** - TODO: Create geometric_cube directory
- [ ] **#27 - Regular Octahedron** - TODO: Create regular_octahedron directory
- [ ] **#28 - Dodecahedron** - TODO: Create dodecahedron directory
- [ ] **#29 - Icosahedron** - TODO: Create icosahedron directory (Note: icosahedron_wireframe exists but may be different)

#### Intermediate Problems (31-50)
- [ ] **#32 - Rounded Box** - TODO: Create rounded_box directory
- [ ] **#33 - Capsule Shape** - TODO: Create capsule_shape directory
- [ ] **#34 - Compound Polyhedra (Stella Octangula)** - TODO: Create compound_polyhedra directory
- [ ] **#35 - Truncated Icosahedron** - TODO: Create truncated_icosahedron directory

#### Advanced Problems (51-80)
- [ ] **#57 - Weierstrass Function** - TODO: Create weierstrass_function directory (Note: tests/problem_5 might be this)
- [ ] **#58 - Ramanujan's Mock-Theta Functions** - TODO: Create ramanujan_mock_theta directory
- [ ] **#59 - Costa Minimal Surface** - TODO: Create costa_minimal_surface directory
- [ ] **#60 - Ackermann Function Growth** - TODO: Create ackermann_function directory
- [ ] **#61 - Riemann Zeta Zeros** - TODO: Create riemann_zeta_zeros directory
- [ ] **#62 - Kleinian Group Limit Sets** - TODO: Create kleinian_group directory
- [ ] **#63 - Alexander Polynomial Visualizer** - TODO: Create alexander_polynomial directory
- [ ] **#64 - Hyperbolic Heat Kernel** - TODO: Create hyperbolic_heat_kernel directory
- [ ] **#65 - Prime Crystal Lattice** - TODO: Move from novel_visualization_challenges
- [ ] **#66 - Fourier Architectural Blueprints** - TODO: Move from novel_visualization_challenges
- [ ] **#67 - Group-Theory Kaleidoscope** - TODO: Move from novel_visualization_challenges
- [ ] **#68 - Differential-Equation Water Simulation** - TODO: Move from novel_visualization_challenges
- [ ] **#69 - Number-Theory Music** - TODO: Move from novel_visualization_challenges
- [ ] **#70 - Topology Fabric Texture** - TODO: Move from novel_visualization_challenges
- [ ] **#71 - Probability Weather Patterns** - TODO: Move from novel_visualization_challenges
- [ ] **#72 - Complex-Analysis Stained-Glass** - TODO: Move from novel_visualization_challenges
- [ ] **#73 - Apollonius's Conic Sections** - TODO: Create apollonius_conic_sections directory
- [ ] **#74 - Al-Khwarizmi's Geometric Algebra** - TODO: Create al_khwarizmi_algebra directory
- [ ] **#75 - Archimedes' Spiral** - TODO: Create archimedes_spiral directory (Note: archimedean_spiral_galaxy exists but is different)
- [ ] **#76 - Fermat's Parabolic Spiral** - TODO: Create fermat_spiral directory
- [ ] **#77 - Euler's Polyhedron Formula (V-E+F=2)** - TODO: Create euler_polyhedron directory
- [ ] **#78 - Gauss's Complex Plane** - TODO: Create gauss_complex_plane directory
- [ ] **#79 - Chinese Remainder Theorem Illustration** - TODO: Create chinese_remainder directory
- [ ] **#80 - Brahmagupta's Cyclic Quadrilaterals** - TODO: Create brahmagupta_quadrilaterals directory

### Extra Visualization Directories
The following directories exist but are not part of the original 80-item list:
- `chladni_patterns`
- `conformal_spiral_mapping`
- `cylindrical_bend_deformation`
- `fractal_loxodromic_patterns`
- `helical_twist_deformation`
- `logarithmic_spiral_motion`
- `loxodromic_sphere_spirals`
- `mandala_circles`
- `mobius_transformation_3d`
- `parametric_gear_train`
- `phyllotaxis_spiral`
- `spherical_inversion_mapping`
- `taper_shear_transformation`
- `wave_deformation_field`

### Notes on tests/ Directory
The `tests/` directory contains 23 numbered problems (problem_1 through problem_23) which appear to be recent additions including:
- Problems 5-15: Recently added advanced mathematical visualizations
- Problems 16-23: Historical mathematics problems that should map to #73-80
