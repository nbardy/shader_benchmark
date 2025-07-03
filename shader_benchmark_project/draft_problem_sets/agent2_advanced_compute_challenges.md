# Agent2: Advanced Compute Shader Programming Challenges
## Expert-Level Mathematical Computations and GPU Algorithms

### **Problem 101: Fast Fourier Transform on GPU**

**Objective**: Implement a radix-2 decimation-in-time FFT algorithm using compute shaders to transform complex-valued input data.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Discrete Fourier Transform, complex number arithmetic, butterfly operations, bit-reversal permutation

**Inputs**:
- `buffer<vec2> inputData` - Complex numbers as (real, imaginary) pairs
- `uniform int N` - Size of transform (power of 2)
- `uniform int stage` - Current FFT stage
- `buffer<vec2> twiddle` - Precomputed twiddle factors

**Expected Outputs**:
- `buffer<vec2> outputData` - Transformed complex data
- Bit-perfect numerical accuracy within floating-point precision
- Proper handling of all FFT stages

**Success Criteria**:
- Correctly implements butterfly operations for each stage
- Proper indexing and memory access patterns
- Numerical stability across all transform sizes
- Efficient GPU utilization with proper workgroup sizing

**Reference Equations** (Context Only):
```
X[k] = Σ(n=0 to N-1) x[n] * e^(-2πikn/N)
Butterfly: X[k] = A[k] + W_N^k * B[k]
Twiddle Factor: W_N^k = e^(-2πik/N) = cos(2πk/N) - i*sin(2πk/N)
```

**Tags**: signal-processing, complex-arithmetic, parallel-algorithms, expert

---

### **Problem 102: Singular Value Decomposition via Jacobi Method**

**Objective**: Implement iterative SVD computation using Jacobi rotations in a compute shader for arbitrary rectangular matrices.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Linear algebra, eigenvalue decomposition, orthogonal transformations, numerical analysis

**Inputs**:
- `buffer<float> matrix` - Input matrix A (m×n) in column-major format
- `uniform int m` - Number of rows
- `uniform int n` - Number of columns
- `uniform float tolerance` - Convergence threshold
- `uniform int maxIterations` - Maximum iteration limit

**Expected Outputs**:
- `buffer<float> U` - Left singular vectors (m×m)
- `buffer<float> S` - Singular values (min(m,n))
- `buffer<float> V` - Right singular vectors (n×n)
- Convergence indicator and iteration count

**Success Criteria**:
- Numerical accuracy comparable to CPU implementations
- Proper convergence detection
- Stable computation for ill-conditioned matrices
- Correct handling of rank-deficient cases

**Reference Equations** (Context Only):
```
A = UΣV^T
Jacobi Rotation: G(i,j,θ) with cos(θ) and sin(θ)
Off-diagonal elimination: tan(2θ) = 2A[i,j]/(A[i,i] - A[j,j])
```

**Tags**: linear-algebra, numerical-methods, iterative-algorithms, expert

---

### **Problem 103: N-Body Gravitational Simulation with Barnes-Hut**

**Objective**: Implement the Barnes-Hut algorithm for hierarchical N-body force calculation using compute shaders with spatial tree traversal.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Computational physics, spatial data structures, tree algorithms, gravitational dynamics

**Inputs**:
- `buffer<vec4> positions` - Particle positions (x,y,z,mass)
- `buffer<vec4> velocities` - Current velocities and time data
- `buffer<TreeNode> octree` - Spatial octree structure
- `uniform float theta` - Barnes-Hut approximation parameter
- `uniform float dt` - Time step
- `uniform int numParticles` - Total particle count

**Expected Outputs**:
- `buffer<vec3> forces` - Computed gravitational forces
- `buffer<vec4> newVelocities` - Updated velocity vectors
- Performance metrics (tree traversal statistics)

**Success Criteria**:
- Correct implementation of multipole approximation
- Efficient tree traversal with proper pruning
- Numerical stability over long simulations
- Scalability to large particle counts (10^6+)

**Reference Equations** (Context Only):
```
F = G * m1 * m2 / r^2
Barnes-Hut Criterion: s/d < θ
Multipole Expansion: φ(r) ≈ Σ q_l Y_l(θ,φ) / r^(l+1)
Leapfrog Integration: v(t+dt/2) = v(t-dt/2) + a(t)*dt
```

**Tags**: physics-simulation, spatial-algorithms, tree-traversal, expert

---

### **Problem 104: Delaunay Triangulation via Incremental Construction**

**Objective**: Generate 2D Delaunay triangulation using incremental point insertion with proper edge flipping in compute shaders.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Computational geometry, triangulation algorithms, circle predicates, convex hull

**Inputs**:
- `buffer<vec2> points` - Input point set
- `uniform int numPoints` - Point count
- `buffer<int> permutation` - Random insertion order
- `buffer<Edge> initialTriangulation` - Starting triangle mesh

**Expected Outputs**:
- `buffer<Triangle> triangles` - Final triangulation
- `buffer<int> adjacency` - Triangle adjacency information
- Validation flags for Delaunay property

**Success Criteria**:
- All triangles satisfy Delaunay criterion (empty circumcircle)
- Proper handling of degenerate cases (collinear points)
- Efficient edge flipping algorithm
- Correct boundary handling

**Reference Equations** (Context Only):
```
Circumcircle Test: |x-cx|² + |y-cy|² < r²
Orientation Test: det([x1-x3, y1-y3; x2-x3, y2-y3])
Edge Flip Criterion: ∠APB + ∠CPD > π
```

**Tags**: computational-geometry, triangulation, geometric-predicates, advanced

---

### **Problem 105: Lattice Boltzmann Method for Fluid Dynamics**

**Objective**: Implement D2Q9 Lattice Boltzmann simulation with collision and streaming steps for incompressible fluid flow.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Computational fluid dynamics, kinetic theory, lattice gas automata, Navier-Stokes equations

**Inputs**:
- `buffer<float> distributions` - Distribution functions f_i
- `buffer<float> density` - Fluid density field
- `buffer<vec2> velocity` - Velocity field
- `uniform float tau` - Relaxation time
- `uniform float omega` - Collision frequency
- `buffer<int> obstacles` - Solid boundary markers

**Expected Outputs**:
- `buffer<float> newDistributions` - Updated distributions after streaming
- `buffer<float> newDensity` - Updated density field
- `buffer<vec2> newVelocity` - Updated velocity field

**Success Criteria**:
- Correct implementation of BGK collision operator
- Proper boundary condition handling (bounce-back, velocity)
- Conservation of mass and momentum
- Stable evolution with realistic Reynolds numbers

**Reference Equations** (Context Only):
```
Boltzmann Equation: ∂f/∂t + v·∇f = Ω(f)
BGK Collision: Ω(f) = -1/τ (f - f^eq)
Equilibrium: f_i^eq = w_i ρ (1 + (c_i·u)/c_s² + (c_i·u)²/2c_s⁴ - u²/2c_s²)
Moments: ρ = Σf_i, ρu = Σc_i f_i
```

**Tags**: fluid-dynamics, physics-simulation, lattice-methods, expert

---

### **Problem 106: Quaternion-Based Attitude Estimation (QUEST Algorithm)**

**Objective**: Implement the QUaternion ESTimator algorithm for spacecraft attitude determination from vector observations using compute shaders.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Quaternion algebra, attitude determination, optimization theory, aerospace engineering

**Inputs**:
- `buffer<vec3> referenceVectors` - Known reference directions
- `buffer<vec3> observedVectors` - Measured sensor directions
- `buffer<float> weights` - Observation weights
- `uniform int numObservations` - Number of vector pairs
- `uniform float tolerance` - Convergence criterion

**Expected Outputs**:
- `vec4 optimalQuaternion` - Attitude quaternion estimate
- `mat3 attitudeMatrix` - Equivalent rotation matrix
- `float residualError` - Final optimization residual
- Convergence statistics

**Success Criteria**:
- Globally optimal quaternion solution
- Proper handling of observation weights
- Numerical stability for near-singular cases
- Accurate attitude matrix conversion

**Reference Equations** (Context Only):
```
Loss Function: L(q) = Σ w_i |r_i - A(q)b_i|²
Attitude Matrix: A(q) = (q₀² - q·q)I + 2qq^T + 2q₀[q×]
QUEST Matrix: K = Σ w_i (b_i r_i^T - r_i b_i^T)
Eigenvalue Problem: (K + K^T - trace(K)I)q = λq
```

**Tags**: quaternions, optimization, aerospace, attitude-estimation, expert

---

### **Problem 107: Voxel Cone Tracing for Global Illumination**

**Objective**: Implement voxel cone tracing algorithm for real-time global illumination using hierarchical 3D textures in compute shaders.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Computer graphics, light transport, spatial data structures, Monte Carlo methods

**Inputs**:
- `texture3D voxelGrid` - 3D voxelized scene representation
- `buffer<vec3> coneDirections` - Sampling cone directions
- `uniform vec3 worldPosition` - Shading point location
- `uniform vec3 normal` - Surface normal vector
- `uniform float coneAngle` - Cone aperture angle
- `uniform int maxSteps` - Maximum ray marching steps

**Expected Outputs**:
- `vec3 indirectIllumination` - Computed indirect lighting
- `float ambientOcclusion` - Occlusion factor
- `vec3 reflectionColor` - Glossy reflection contribution

**Success Criteria**:
- Physically plausible light transport simulation
- Efficient hierarchical traversal of voxel mipmap
- Proper cone aperture handling and filtering
- Temporal stability across frames

**Reference Equations** (Context Only):
```
Rendering Equation: L_o = L_e + ∫ f_r L_i (ω_i · n) dω_i
Cone Tracing: I = ∫ σ(t) L(x + td) e^(-∫₀ᵗ σ(s)ds) dt
Voxel Filtering: τ = diameter/distance
Mipmap Level: level = log₂(τ)
```

**Tags**: global-illumination, ray-tracing, voxelization, computer-graphics, expert

---

### **Problem 108: Marching Cubes with Dual Contouring**

**Objective**: Generate high-quality isosurface meshes using dual contouring enhancement to standard marching cubes algorithm.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Isosurface extraction, mesh generation, gradient estimation, topology preservation

**Inputs**:
- `texture3D scalarField` - 3D scalar field data
- `uniform float isovalue` - Target isosurface level
- `uniform vec3 gridSpacing` - Voxel dimensions
- `uniform ivec3 gridSize` - Volume resolution
- `buffer<int> edgeTable` - Marching cubes lookup table

**Expected Outputs**:
- `buffer<vec3> vertices` - Generated mesh vertices
- `buffer<ivec3> triangles` - Triangle connectivity
- `buffer<vec3> normals` - Vertex normal vectors
- Quality metrics (triangle aspect ratios)

**Success Criteria**:
- Topologically correct mesh generation
- Sharp feature preservation via dual contouring
- Consistent triangle orientation (outward normals)
- Efficient GPU memory utilization

**Reference Equations** (Context Only):
```
Isosurface: f(x,y,z) = isovalue
Gradient: ∇f = (∂f/∂x, ∂f/∂y, ∂f/∂z)
Dual Point: argmin Σ (n_i · (x - p_i))²
Linear Interpolation: v = v₁ + t(v₂ - v₁), t = (iso - f₁)/(f₂ - f₁)
```

**Tags**: isosurface-extraction, mesh-generation, marching-cubes, advanced

---

### **Problem 109: Spherical Harmonic Lighting Coefficients**

**Objective**: Compute spherical harmonic coefficients for environment lighting using Monte Carlo integration in compute shaders.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Spherical harmonics, Monte Carlo integration, importance sampling, computer graphics lighting

**Inputs**:
- `textureCube environmentMap` - HDR environment texture
- `uniform int numSamples` - Monte Carlo sample count
- `uniform int maxBands` - Maximum SH band (typically 3-5)
- `buffer<vec3> sampleDirections` - Precomputed sample directions
- `buffer<float> sampleWeights` - Importance sampling weights

**Expected Outputs**:
- `buffer<vec3> shCoefficients` - RGB SH coefficients for each band
- `float totalEnergy` - Integrated environment energy
- Convergence statistics and variance estimates

**Success Criteria**:
- Mathematically correct SH coefficient computation
- Proper handling of HDR input values
- Efficient stratified sampling patterns
- Numerical stability for high-frequency environments

**Reference Equations** (Context Only):
```
SH Basis: Y_l^m(θ,φ) = N_l^m P_l^|m|(cos θ) e^{imφ}
Projection: c_l^m = ∫ f(θ,φ) Y_l^m(θ,φ) sin θ dθ dφ
Reconstruction: f(θ,φ) ≈ Σ_l Σ_m c_l^m Y_l^m(θ,φ)
Monte Carlo: ∫f dΩ ≈ (4π/N) Σ f(ω_i)
```

**Tags**: spherical-harmonics, monte-carlo, environment-lighting, advanced

---

### **Problem 110: Cloth Simulation with Position-Based Dynamics**

**Objective**: Simulate cloth behavior using position-based dynamics with distance, bending, and collision constraints in compute shaders.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Physical simulation, constraint satisfaction, mass-spring systems, collision detection

**Inputs**:
- `buffer<vec4> positions` - Particle positions (x,y,z,invMass)
- `buffer<vec4> prevPositions` - Previous positions for Verlet integration
- `buffer<DistanceConstraint> distanceConstraints` - Structural constraints
- `buffer<BendingConstraint> bendingConstraints` - Bending resistance
- `buffer<CollisionSphere> colliders` - Collision objects
- `uniform float timeStep` - Simulation time step

**Expected Outputs**:
- `buffer<vec4> newPositions` - Updated particle positions
- `buffer<vec3> velocities` - Computed velocities
- Constraint satisfaction metrics

**Success Criteria**:
- Stable simulation without energy blow-up
- Realistic cloth behavior (stretching, folding)
- Proper collision response and friction
- Efficient constraint solving convergence

**Reference Equations** (Context Only):
```
Verlet Integration: x(t+Δt) = 2x(t) - x(t-Δt) + a(t)Δt²
Distance Constraint: |p₁ - p₂| = rest_length
Constraint Force: Δp = -∇C/|∇C|² × C × w
Bending Angle: cos θ = (n₁ · n₂)/(|n₁||n₂|)
```

**Tags**: physics-simulation, cloth-dynamics, constraint-solving, advanced

---

### **Problem 111: Discrete Gaussian Curvature via Angle Defect**

**Objective**: Compute discrete Gaussian curvature at mesh vertices using angle defect method with proper handling of boundary vertices.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Discrete differential geometry, curvature measures, mesh analysis, topology

**Inputs**:
- `buffer<vec3> vertices` - Mesh vertex positions
- `buffer<ivec3> triangles` - Triangle connectivity
- `buffer<int> vertexTriangles` - Vertex-triangle adjacency
- `uniform int numVertices` - Total vertex count
- `buffer<int> boundaryFlags` - Boundary vertex indicators

**Expected Outputs**:
- `buffer<float> gaussianCurvature` - Discrete Gaussian curvature per vertex
- `buffer<float> angleDefects` - Total angle defect per vertex
- `buffer<float> voronoiAreas` - Vertex Voronoi cell areas

**Success Criteria**:
- Correct implementation of angle defect formula
- Proper boundary handling (different defect computation)
- Numerical stability for degenerate triangles
- Agreement with analytical results for known surfaces

**Reference Equations** (Context Only):
```
Angle Defect: κ(v) = (2π - Σθᵢ)/A_mixed
Mixed Area: A_mixed = 1/3 Σ A_triangle (non-obtuse case)
Gauss-Bonnet: Σ κ(v) A(v) = 2π χ(M) (for closed meshes)
Triangle Angle: cos(θ) = (u·v)/(|u||v|)
```

**Tags**: discrete-geometry, curvature-analysis, mesh-processing, advanced

---

### **Problem 112: Poisson Disk Sampling via Dart Throwing**

**Objective**: Generate Poisson disk distributions using parallel dart throwing with conflict detection and resolution mechanisms.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Stochastic geometry, spatial point processes, blue noise generation, sampling theory

**Inputs**:
- `uniform vec2 domainSize` - Sampling domain dimensions
- `uniform float minDistance` - Minimum separation distance
- `uniform int maxAttempts` - Maximum sample attempts per thread
- `buffer<uint> randomSeeds` - Per-thread random seeds
- `uniform int gridResolution` - Background grid resolution

**Expected Outputs**:
- `buffer<vec2> samples` - Generated sample points
- `buffer<int> sampleCount` - Actual number of valid samples
- `buffer<int> grid` - Background spatial grid for conflict detection
- Statistics on sampling efficiency

**Success Criteria**:
- No samples closer than minimum distance
- Good coverage of sampling domain
- Efficient parallel execution without race conditions
- Statistical properties approaching Poisson disk distribution

**Reference Equations** (Context Only):
```
Poisson Process: P(N(A) = k) = (λ|A|)^k e^(-λ|A|) / k!
Minimum Distance: d(pᵢ, pⱼ) ≥ r_min ∀ i ≠ j
Grid Cell Size: cell_size = r_min / √2
Conflict Detection: check 5×5 neighborhood
```

**Tags**: sampling-algorithms, stochastic-geometry, parallel-algorithms, advanced

---

### **Problem 113: Hodge Decomposition of Vector Fields**

**Objective**: Decompose 2D vector fields into curl-free, divergence-free, and harmonic components using discrete exterior calculus.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Vector calculus, Hodge theory, differential forms, computational topology

**Inputs**:
- `buffer<vec2> vectorField` - Input 2D vector field on grid
- `uniform ivec2 gridSize` - Grid dimensions
- `uniform float spacing` - Grid cell spacing
- `buffer<int> boundaryConditions` - Boundary condition types
- `uniform float tolerance` - Solver convergence tolerance

**Expected Outputs**:
- `buffer<vec2> curlFreeComponent` - ∇φ (gradient of scalar potential)
- `buffer<vec2> divFreeComponent` - ∇×ψ (curl of vector potential)
- `buffer<vec2> harmonicComponent` - Harmonic remainder
- `buffer<float> scalarPotential` - Scalar potential φ
- `buffer<float> vectorPotential` - Vector potential ψ

**Success Criteria**:
- Mathematical correctness: v = ∇φ + ∇×ψ + h
- Proper boundary condition enforcement
- Convergence of iterative Poisson solvers
- Orthogonality of decomposed components

**Reference Equations** (Context Only):
```
Hodge Decomposition: v = ∇φ + ∇×ψ + h
Poisson Equations: ∇²φ = ∇·v, ∇²ψ = ∇×v
Discrete Gradient: (∇φ)ᵢⱼ = (φᵢ₊₁,ⱼ - φᵢⱼ, φᵢ,ⱼ₊₁ - φᵢⱼ)/h
Discrete Curl: (∇×ψ)ᵢⱼ = (ψᵢ,ⱼ₊₁ - ψᵢⱼ, ψᵢⱼ - ψᵢ₊₁,ⱼ)/h
```

**Tags**: vector-calculus, hodge-theory, field-decomposition, expert

---

### **Problem 114: Spectral Graph Clustering via Normalized Cuts**

**Objective**: Perform spectral clustering on weighted graphs using normalized Laplacian eigendecomposition in compute shaders.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Spectral graph theory, linear algebra, clustering algorithms, machine learning

**Inputs**:
- `buffer<float> adjacencyMatrix` - Weighted graph adjacency matrix
- `uniform int numVertices` - Number of graph vertices
- `uniform int numClusters` - Desired number of clusters
- `uniform float sigma` - Gaussian kernel parameter
- `uniform int maxIterations` - Maximum eigensolver iterations

**Expected Outputs**:
- `buffer<float> eigenVectors` - k smallest eigenvectors of normalized Laplacian
- `buffer<float> eigenValues` - Corresponding eigenvalues
- `buffer<int> clusterAssignments` - Final vertex cluster assignments
- Clustering quality metrics (modularity, conductance)

**Success Criteria**:
- Correct normalized Laplacian construction: L = D^(-1/2) W D^(-1/2)
- Stable eigendecomposition for large sparse matrices
- Meaningful cluster assignments via k-means on eigenvectors
- Scalability to graphs with 10^4+ vertices

**Reference Equations** (Context Only):
```
Normalized Laplacian: L = I - D^(-1/2) A D^(-1/2)
Generalized Eigenvalue: L v = λ D v
Normalized Cut: NCut(A,B) = cut(A,B)/vol(A) + cut(A,B)/vol(B)
RatioCut: RCut(A,B) = cut(A,B)/|A| + cut(A,B)/|B|
```

**Tags**: spectral-methods, graph-clustering, eigendecomposition, expert

---

### **Problem 115: Variational Surface Smoothing (Laplace-Beltrami)**

**Objective**: Smooth 3D triangle meshes using discrete Laplace-Beltrami operator with cotangent weights preserving geometric features.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Discrete differential geometry, variational methods, mesh processing, heat equation

**Inputs**:
- `buffer<vec3> vertices` - Original mesh vertex positions
- `buffer<ivec3> triangles` - Triangle connectivity
- `buffer<int> neighborIndices` - Vertex neighborhood information
- `uniform float timeStep` - Diffusion time step
- `uniform float featureThreshold` - Feature preservation threshold

**Expected Outputs**:
- `buffer<vec3> smoothedVertices` - Smoothed vertex positions
- `buffer<float> curvatureIndicator` - Local curvature estimates
- `buffer<float> featureWeights` - Adaptive smoothing weights

**Success Criteria**:
- Preservation of overall mesh topology
- Smooth surface regions while preserving sharp features
- Numerical stability over multiple iterations
- Proper cotangent weight computation handling obtuse triangles

**Reference Equations** (Context Only):
```
Heat Equation: ∂v/∂t = λ Δv
Discrete Laplacian: Δv = (1/2A) Σ (cot α + cot β)(vⱼ - vᵢ)
Cotangent Weights: wᵢⱼ = (cot αᵢⱼ + cot βᵢⱼ)/2
Mixed Voronoi Area: A_mixed = Σ area(Voronoi_cell ∩ triangle)
```

**Tags**: mesh-smoothing, laplace-beltrami, discrete-geometry, advanced

---

### **Problem 116: Eulerian Fluid Simulation with MacCormack Advection**

**Objective**: Implement MacCormack advection scheme for high-quality fluid simulation with reduced numerical dissipation.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Computational fluid dynamics, numerical methods, advection schemes, finite differences

**Inputs**:
- `buffer<vec3> velocity` - Velocity field on staggered grid
- `buffer<float> density` - Scalar density field
- `buffer<float> pressure` - Pressure field
- `uniform float dt` - Time step size
- `uniform vec3 gridSpacing` - Grid cell dimensions
- `buffer<int> boundaryMask` - Solid boundary indicators

**Expected Outputs**:
- `buffer<vec3> newVelocity` - Advected velocity field
- `buffer<float> newDensity` - Advected density field
- `buffer<float> divergence` - Velocity divergence for pressure projection
- Advection error estimates

**Success Criteria**:
- Higher-order accuracy compared to simple semi-Lagrangian
- Reduced numerical dissipation and artificial damping
- Proper boundary condition handling
- Stable evolution for high Reynolds numbers

**Reference Equations** (Context Only):
```
Advection: ∂q/∂t + (v·∇)q = 0
MacCormack: q* = q^n - Δt(v·∇)q^n
             q^(n+1) = (q^n + q* - Δt(v·∇)q*)/2
Correction: q^(n+1) = q* + 0.5(q^n - q_back)
Error Estimate: ε = |q_forward - q_backward|
```

**Tags**: fluid-simulation, advection-schemes, numerical-methods, expert

---

### **Problem 117: Mesh Parameterization via Least Squares Conformal Maps**

**Objective**: Compute conformal parameterization of triangle meshes to 2D domain using least squares conformal mapping.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Conformal geometry, complex analysis, mesh parameterization, optimization

**Inputs**:
- `buffer<vec3> vertices` - 3D mesh vertex positions
- `buffer<ivec3> triangles` - Triangle connectivity
- `buffer<int> boundaryVertices` - Boundary vertex indices
- `buffer<vec2> boundaryUV` - Fixed boundary UV coordinates
- `uniform float lambda` - Regularization parameter

**Expected Outputs**:
- `buffer<vec2> uvCoordinates` - 2D parameterization coordinates
- `buffer<float> conformality` - Conformal distortion per triangle
- `buffer<float> areaDistortion` - Area distortion ratios
- Convergence statistics

**Success Criteria**:
- Minimal angle distortion (conformal property)
- Bijective mapping (no triangle flips)
- Smooth parameterization across mesh
- Proper handling of mesh boundaries

**Reference Equations** (Context Only):
```
Conformal Energy: E = ∫ |∂f/∂z̄|² dA
Complex Coordinates: z = x + iy, ∂/∂z̄ = (∂/∂x + i∂/∂y)/2
Discrete Conformal: minimize Σ |∇u + i∇v|²
Linear System: (L + λM)u = λb_boundary
```

**Tags**: conformal-mapping, mesh-parameterization, complex-analysis, expert

---

### **Problem 118: Multigrid Poisson Solver with V-Cycles**

**Objective**: Implement geometric multigrid method for solving 2D/3D Poisson equations with V-cycle iteration scheme.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Numerical analysis, iterative methods, multigrid theory, partial differential equations

**Inputs**:
- `buffer<float> rightHandSide` - RHS vector b in Ax = b
- `buffer<float> initialGuess` - Starting solution estimate
- `uniform ivec3 gridSize` - Fine grid dimensions
- `uniform int numLevels` - Multigrid hierarchy levels
- `uniform int preSmoothSteps` - Pre-smoothing iterations
- `uniform int postSmoothSteps` - Post-smoothing iterations

**Expected Outputs**:
- `buffer<float> solution` - Approximate solution vector
- `buffer<float> residual` - Final residual vector
- Convergence history and iteration statistics
- Per-level performance metrics

**Success Criteria**:
- O(N) complexity scaling for grid problems
- Geometric convergence rate independent of grid size
- Proper implementation of restriction and prolongation operators
- Numerical accuracy competitive with direct solvers

**Reference Equations** (Context Only):
```
Poisson Equation: -∇²u = f
Multigrid V-Cycle: v^h ← S_ν₁(A^h, v^h, f^h)
                   r^h = f^h - A^h v^h
                   r^2h = I^2h_h r^h (restriction)
                   Solve: A^2h e^2h = r^2h
                   v^h ← v^h + I^h_2h e^2h (prolongation)
                   v^h ← S_ν₂(A^h, v^h, f^h)
```

**Tags**: multigrid-methods, poisson-solver, numerical-analysis, expert

---

### **Problem 119: Anisotropic Diffusion for Edge-Preserving Smoothing**

**Objective**: Implement Perona-Malik anisotropic diffusion for image denoising while preserving important edge features.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Partial differential equations, image processing, variational methods, edge detection

**Inputs**:
- `texture2D inputImage` - Noisy input image
- `uniform float timeStep` - Diffusion time step
- `uniform float conductanceParameter` - Edge sensitivity parameter K
- `uniform int maxIterations` - Maximum diffusion iterations
- `uniform float convergenceThreshold` - Stopping criterion

**Expected Outputs**:
- `texture2D denoisedImage` - Edge-preserving smoothed result
- `texture2D edgeMap` - Detected edge strength map
- `texture2D conductanceMap` - Anisotropic conductance values
- Convergence metrics and iteration count

**Success Criteria**:
- Effective noise reduction in smooth regions
- Preservation of important edges and features
- Numerical stability over long time integration
- Proper handling of image boundaries

**Reference Equations** (Context Only):
```
Anisotropic Diffusion: ∂I/∂t = ∇·(c(x,y,t)∇I)
Perona-Malik: c(|∇I|) = 1/(1 + (|∇I|/K)²)
Discrete Update: I^(n+1) = I^n + λ[c_N∇_N I + c_S∇_S I + c_E∇_E I + c_W∇_W I]
Gradient Magnitude: |∇I| = √((∂I/∂x)² + (∂I/∂y)²)
```

**Tags**: anisotropic-diffusion, edge-preservation, image-processing, advanced

---

### **Problem 120: Discrete Morse Theory for Topological Analysis**

**Objective**: Compute discrete Morse function and critical points for topological analysis of simplicial complexes using GPU parallelization.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Algebraic topology, Morse theory, computational topology, homology computation

**Inputs**:
- `buffer<vec3> vertices` - Vertex coordinates of simplicial complex
- `buffer<ivec4> simplices` - Simplex connectivity (tetrahedra/triangles)
- `buffer<float> scalarFunction` - Scalar function values on vertices
- `uniform int complexDimension` - Dimension of simplicial complex
- `uniform float persistenceThreshold` - Minimum feature persistence

**Expected Outputs**:
- `buffer<int> criticalPoints` - Critical point classifications (0,1,2-cells)
- `buffer<float> morseFunction` - Discrete Morse function values
- `buffer<int> gradientField` - Discrete gradient vector field
- Persistence diagram and Betti numbers

**Success Criteria**:
- Correct identification of critical points and their indices
- Valid discrete gradient field (no closed orbits)
- Topological accuracy verified against known test cases
- Efficient parallel computation of Morse-Smale complex

**Reference Equations** (Context Only):
```
Morse Inequality: m_k ≥ β_k (number of k-critical points ≥ k-th Betti number)
Discrete Gradient: V(σ) = τ where σ < τ and dim(τ) = dim(σ) + 1
Critical Simplex: no V(σ) defined (unpaired in gradient field)
Persistence: birth-death pairs in filtration sequence
```

**Tags**: morse-theory, computational-topology, critical-points, expert

---

### **Problem 121: Implicit Surface Reconstruction via Radial Basis Functions**

**Objective**: Reconstruct smooth implicit surfaces from scattered 3D point clouds using radial basis function interpolation.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Approximation theory, interpolation methods, scattered data reconstruction, implicit surfaces

**Inputs**:
- `buffer<vec3> pointCloud` - Input 3D point positions
- `buffer<vec3> normals` - Surface normal vectors at points
- `uniform float supportRadius` - RBF influence radius
- `uniform int rbfType` - RBF kernel type (Gaussian, multiquadric, etc.)
- `uniform float smoothingParameter` - Regularization parameter

**Expected Outputs**:
- `buffer<float> rbfWeights` - Computed RBF interpolation weights
- `texture3D implicitField` - 3D implicit function values on grid
- Surface reconstruction quality metrics
- Memory usage and performance statistics

**Success Criteria**:
- Smooth surface reconstruction without artifacts
- Proper handling of sparse and noisy input data
- Efficient solution of large linear systems (10^4+ points)
- Accurate normal constraint satisfaction

**Reference Equations** (Context Only):
```
RBF Interpolation: f(x) = Σ wᵢ φ(||x - xᵢ||) + p(x)
Gaussian RBF: φ(r) = e^(-εr²)
Multiquadric: φ(r) = √(1 + (εr)²)
Linear System: [A P; P^T 0][w; λ] = [f; 0]
Normal Constraints: ∇f(xᵢ) = nᵢ
```

**Tags**: surface-reconstruction, radial-basis-functions, scattered-data, expert

---

### **Problem 122: Persistent Homology Computation**

**Objective**: Compute persistent homology of point clouds using alpha complex filtration and matrix reduction algorithms.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Algebraic topology, homology theory, persistent homology, topological data analysis

**Inputs**:
- `buffer<vec3> pointCloud` - Input point set
- `uniform float maxAlpha` - Maximum alpha value for filtration
- `uniform int maxDimension` - Maximum homology dimension to compute
- `buffer<Simplex> simplexComplex` - Precomputed simplicial complex
- `uniform int numSimplices` - Total number of simplices

**Expected Outputs**:
- `buffer<PersistencePair> persistenceDiagram` - Birth-death pairs
- `buffer<int> bettiNumbers` - Betti numbers over filtration
- `buffer<float> persistenceValues` - Persistence values for features
- Topological summary statistics

**Success Criteria**:
- Correct computation of persistent homology groups
- Efficient matrix reduction using column operations
- Proper handling of infinite persistence features
- Scalability to point clouds with 10^3+ points

**Reference Equations** (Context Only):
```
Alpha Complex: K_α = {σ ∈ Delaunay | α-ball(σ) ≤ α}
Persistence: H_k(K_α) for α ∈ [0, ∞)
Matrix Reduction: R = DV where D is boundary matrix
Birth-Death: (αᵢ, αⱼ) where feature born at αᵢ, dies at αⱼ
```

**Tags**: persistent-homology, topological-data-analysis, alpha-complex, expert

---

### **Problem 123: Texture Synthesis via Patch-Based Optimization**

**Objective**: Generate seamless texture patterns using patch-based optimization with GPU-accelerated neighborhood matching.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Computer vision, optimization theory, texture analysis, image processing

**Inputs**:
- `texture2D exemplarTexture` - Input texture example
- `uniform ivec2 outputSize` - Desired output texture dimensions
- `uniform ivec2 patchSize` - Patch dimensions for matching
- `uniform int numIterations` - Optimization iterations
- `uniform float overlapWeight` - Overlap error weighting

**Expected Outputs**:
- `texture2D synthesizedTexture` - Generated texture result
- `texture2D errorMap` - Per-pixel reconstruction error
- Convergence statistics and iteration metrics
- Patch assignment visualization

**Success Criteria**:
- Visually plausible texture synthesis
- Seamless boundaries and minimal artifacts
- Preservation of texture features and statistics
- Efficient parallel patch matching

**Reference Equations** (Context Only):
```
Patch Distance: d(P₁, P₂) = Σ ||P₁(i,j) - P₂(i,j)||²
Energy Function: E = Σ d(patch(x,y), best_match(x,y))
Overlap Error: E_overlap = Σ ||T_new - T_old||² in overlap region
Min-Cut Optimization: find seam minimizing boundary cost
```

**Tags**: texture-synthesis, patch-matching, optimization, advanced

---

### **Problem 124: Seam Carving for Content-Aware Image Resizing**

**Objective**: Implement seam carving algorithm for intelligent image resizing using energy-based seam detection and removal.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Dynamic programming, image processing, energy minimization, computational photography

**Inputs**:
- `texture2D inputImage` - Source image to resize
- `uniform int targetWidth` - Desired output width
- `uniform int targetHeight` - Desired output height
- `uniform float edgeWeight` - Edge preservation weight
- `uniform float gradientWeight` - Gradient energy weight

**Expected Outputs**:
- `texture2D resizedImage` - Content-aware resized result
- `buffer<ivec2> verticalSeams` - Computed vertical seam paths
- `buffer<ivec2> horizontalSeams` - Computed horizontal seam paths
- `texture2D energyMap` - Per-pixel energy values

**Success Criteria**:
- Preservation of important image features
- Smooth seam paths without visual artifacts
- Correct implementation of dynamic programming
- Efficient parallel seam computation

**Reference Equations** (Context Only):
```
Energy Function: e(i,j) = |∂I/∂x| + |∂I/∂y|
Seam Energy: E(s) = Σ e(sᵢ)
Dynamic Programming: M(i,j) = e(i,j) + min(M(i-1,j-1), M(i-1,j), M(i-1,j+1))
Seam Path: s* = argmin E(s)
```

**Tags**: seam-carving, dynamic-programming, image-processing, advanced

---

### **Problem 125: Variational Optical Flow via Horn-Schunck Method**

**Objective**: Compute dense optical flow between image frames using variational formulation with smoothness constraints.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Computer vision, variational methods, partial differential equations, motion estimation

**Inputs**:
- `texture2D frame1` - First image frame
- `texture2D frame2` - Second image frame
- `uniform float alpha` - Smoothness regularization parameter
- `uniform int maxIterations` - Maximum solver iterations
- `uniform float convergenceThreshold` - Convergence tolerance

**Expected Outputs**:
- `texture2D flowU` - Horizontal flow component
- `texture2D flowV` - Vertical flow component
- `texture2D flowMagnitude` - Flow magnitude field
- Convergence metrics and residual error

**Success Criteria**:
- Smooth flow fields with proper motion capture
- Correct implementation of brightness constancy assumption
- Stable iterative solution convergence
- Proper boundary condition handling

**Reference Equations** (Context Only):
```
Brightness Constancy: I(x,y,t) = I(x+u,y+v,t+1)
Linearization: Iₓu + Iᵧv + Iₜ = 0
Energy Functional: E = ∫∫ (Iₓu + Iᵧv + Iₜ)² + α²(|∇u|² + |∇v|²) dx dy
Euler-Lagrange: α²∇²u = (Iₓu + Iᵧv + Iₜ)Iₓ
```

**Tags**: optical-flow, variational-methods, motion-estimation, advanced

---

### **Problem 126: Geodesic Distance Transform on Meshes**

**Objective**: Compute geodesic distances from source vertices to all mesh vertices using fast marching method on triangulated surfaces.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Differential geometry, numerical methods, geodesic computation, mesh processing

**Inputs**:
- `buffer<vec3> vertices` - Mesh vertex positions
- `buffer<ivec3> triangles` - Triangle connectivity
- `buffer<int> sourceVertices` - Source vertex indices for distance computation
- `buffer<float> edgeLengths` - Precomputed edge lengths
- `uniform float maxDistance` - Maximum distance threshold

**Expected Outputs**:
- `buffer<float> geodesicDistances` - Distance values per vertex
- `buffer<ivec2> shortestPaths` - Geodesic path connectivity
- `buffer<int> farthestVertices` - Vertices at maximum distance
- Distance field visualization data

**Success Criteria**:
- Accurate geodesic distance computation on curved surfaces
- Proper handling of mesh topology and boundaries
- Efficient fast marching implementation
- Numerical stability for large meshes

**Reference Equations** (Context Only):
```
Eikonal Equation: |∇T| = 1/F (where F is speed function)
Fast Marching Update: T = min(T_candidate) over triangle neighbors
Upwind Scheme: solve aT² - 2bT + c = 0 for T
Geodesic Path: ∇T·γ'(s) = 0 (gradient descent on distance field)
```

**Tags**: geodesic-distance, fast-marching, mesh-processing, expert

---

### **Problem 127: Quantum Circuit Simulation via State Vector**

**Objective**: Simulate quantum circuits using state vector representation with GPU parallelization for gate operations.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Quantum computing, linear algebra, complex number arithmetic, quantum algorithms

**Inputs**:
- `buffer<vec2> stateVector` - Complex amplitudes of quantum states
- `buffer<QuantumGate> gateSequence` - Sequence of quantum gates
- `uniform int numQubits` - Number of qubits in circuit
- `uniform int numGates` - Total number of gates to apply
- `buffer<mat2> gateMatrices` - Unitary gate matrices

**Expected Outputs**:
- `buffer<vec2> finalState` - Final quantum state after circuit
- `buffer<float> probabilities` - Measurement probabilities
- `buffer<float> entanglementEntropy` - Entanglement measures
- Quantum circuit fidelity metrics

**Success Criteria**:
- Correct unitary evolution of quantum states
- Proper handling of multi-qubit gate operations
- Numerical precision preservation for complex amplitudes
- Scalability to circuits with 15+ qubits

**Reference Equations** (Context Only):
```
State Evolution: |ψ⟩ = U|ψ₀⟩ where U = G_n...G_2G_1
Multi-qubit Gate: U = I^⊗k ⊗ G ⊗ I^⊗(n-k-1)
Measurement: P(|k⟩) = |⟨k|ψ⟩|²
Entanglement Entropy: S = -Tr(ρ_A log ρ_A)
```

**Tags**: quantum-computing, state-vector-simulation, linear-algebra, expert

---

### **Problem 128: Cellular Automata with Custom Neighborhood Rules**

**Objective**: Implement generalized cellular automata with programmable neighborhood rules and state transition functions.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Discrete dynamical systems, complexity theory, emergence, mathematical biology

**Inputs**:
- `buffer<int> currentState` - Current cellular automaton state
- `buffer<int> neighborhoodMask` - Custom neighborhood pattern
- `buffer<int> transitionTable` - State transition lookup table
- `uniform ivec2 gridSize` - Automaton grid dimensions
- `uniform int numStates` - Number of possible cell states

**Expected Outputs**:
- `buffer<int> nextState` - Next iteration state
- `buffer<int> stateHistory` - Evolution history over time
- `buffer<float> entropy` - Spatial entropy measures
- Pattern recognition statistics

**Success Criteria**:
- Correct implementation of custom transition rules
- Efficient parallel state updates
- Proper boundary condition handling
- Detection of periodic and chaotic behaviors

**Reference Equations** (Context Only):
```
State Update: s_i^(t+1) = f(s_i^(t), N_i^(t))
Neighborhood: N_i = {s_j : j ∈ neighborhood(i)}
Entropy: H = -Σ p_i log p_i (over state probabilities)
Pattern Density: ρ = |{i : s_i = target_state}| / |total|
```

**Tags**: cellular-automata, discrete-dynamics, emergence, advanced

---

### **Problem 129: Voronoi Diagram Construction via Jump Flooding**

**Objective**: Generate 2D Voronoi diagrams using jump flooding algorithm optimized for parallel GPU execution.

**Shader Type**: Compute Shader

**Difficulty Level**: Advanced

**Mathematical Context**: Computational geometry, Voronoi diagrams, parallel algorithms, spatial data structures

**Inputs**:
- `buffer<vec2> seedPoints` - Voronoi site positions
- `uniform ivec2 gridResolution` - Output grid resolution
- `uniform int numSeeds` - Number of Voronoi sites
- `uniform float distanceMetric` - Distance function type (Euclidean, Manhattan)
- `uniform int maxJumpSteps` - Maximum jump flooding iterations

**Expected Outputs**:
- `buffer<int> voronoiRegions` - Region ID per grid cell
- `buffer<float> distanceField` - Distance to nearest seed
- `buffer<vec2> nearestSeed` - Closest seed point per cell
- Voronoi edge detection and boundary maps

**Success Criteria**:
- Correct Voronoi cell assignment for all grid points
- Efficient O(log n) convergence via jump flooding
- Proper handling of degenerate cases (coincident points)
- Accurate distance field computation

**Reference Equations** (Context Only):
```
Voronoi Cell: V(p_i) = {x : d(x,p_i) ≤ d(x,p_j) ∀j ≠ i}
Jump Distance: step_size = max(1, grid_size / 2^iteration)
Distance Function: d_euclidean = ||x - p||, d_manhattan = |x₁-p₁| + |x₂-p₂|
Delaunay Dual: connect sites sharing Voronoi edge
```

**Tags**: voronoi-diagrams, jump-flooding, computational-geometry, advanced

---

### **Problem 130: Monte Carlo Path Tracing with Importance Sampling**

**Objective**: Implement Monte Carlo path tracing for global illumination with multiple importance sampling and Russian roulette termination.

**Shader Type**: Compute Shader

**Difficulty Level**: Expert

**Mathematical Context**: Monte Carlo methods, light transport, importance sampling, computer graphics

**Inputs**:
- `buffer<Triangle> sceneGeometry` - Triangle mesh scene representation
- `buffer<Material> materials` - Surface material properties
- `buffer<Light> lightSources` - Scene light sources
- `uniform int maxBounces` - Maximum path length
- `uniform int samplesPerPixel` - Sample count per pixel
- `uniform vec3 cameraPosition` - Camera position and orientation

**Expected Outputs**:
- `texture2D radianceImage` - Accumulated radiance per pixel
- `texture2D varianceImage` - Monte Carlo variance estimates
- `buffer<float> convergenceMetrics` - Sampling convergence data
- Performance statistics (rays per second)

**Success Criteria**:
- Physically accurate light transport simulation
- Proper implementation of BRDF sampling and evaluation
- Effective variance reduction via importance sampling
- Numerical stability over long sample sequences

**Reference Equations** (Context Only):
```
Rendering Equation: L_o = L_e + ∫ f_r L_i (ω_i · n) dω_i
Monte Carlo: ∫ f(x) dx ≈ (1/N) Σ f(X_i)/p(X_i)
Importance Sampling: choose p(x) ∝ f(x) to reduce variance
Russian Roulette: P(continue) = min(1, throughput/threshold)
Multiple IS: w_i = (n_i p_i) / Σ(n_j p_j) (balance heuristic)
```

**Tags**: path-tracing, monte-carlo, global-illumination, expert

---

## **Summary: Agent2 Advanced Compute Shader Challenges**

**Challenge Count**: 30 Expert/Advanced Level Problems (101-130)

**Domain Coverage**:
- **Signal Processing**: Fast Fourier Transform algorithms
- **Linear Algebra**: SVD, eigendecomposition, multigrid methods 
- **Physics Simulation**: N-body dynamics, fluid dynamics, cloth simulation
- **Computational Geometry**: Delaunay triangulation, mesh parameterization, geodesic computation
- **Computer Graphics**: Global illumination, voxel cone tracing, path tracing
- **Differential Geometry**: Curvature computation, surface smoothing, Hodge decomposition
- **Topological Analysis**: Morse theory, persistent homology
- **Computer Vision**: Optical flow, seam carving, texture synthesis
- **Quantum Computing**: State vector simulation
- **Complex Systems**: Cellular automata, Voronoi diagrams
- **Numerical Methods**: Anisotropic diffusion, surface reconstruction

**Difficulty Distribution**:
- **Expert Level**: 18 problems (60%)
- **Advanced Level**: 12 problems (40%)

**Key Features**:
- All problems target compute shader implementation
- Complex mathematical algorithms requiring sophisticated understanding
- Designed to push boundaries of LLM code generation capabilities
- Focus on parallel algorithms suitable for GPU execution
- Each problem includes detailed mathematical context without solution hints
- Comprehensive input/output specifications and success criteria

**Team Coordination**:
- Complementary to Bob's basic/intermediate vertex/compute challenges
- Distinct from Alice's fragment shader focus
- Avoids overlap with Agent1's basic-intermediate coverage
- Fills advanced/expert difficulty gap in the benchmark suite

---
