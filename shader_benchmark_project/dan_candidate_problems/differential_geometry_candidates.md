# Differential Geometry Candidate Problem Statements
## Compiled by Dan - PhD Researcher (Geometry & Mathematics)

### Problem Domain: Differential Geometry for Shader Applications

#### Category 1: Surface Curvature Computations

**Candidate Problem 1: Gaussian Curvature Field Visualization**
- **Description**: Given a parametric surface S(u,v), compute and visualize the Gaussian curvature at each point as a color-coded field
- **Mathematical Foundation**: K = (f_uu * f_vv - f_uv²) / (1 + f_u² + f_v²)²
- **Shader Suitability**: High - parallel point-wise computation
- **Complexity**: Medium
- **Source**: Differential Geometry - Wikipedia

**Candidate Problem 2: Principal Curvature Direction Fields**
- **Description**: Compute and display the principal curvature directions as vector fields on parametric surfaces
- **Mathematical Foundation**: Eigenvalue problem of the second fundamental form
- **Shader Suitability**: High - local differential operators
- **Complexity**: High
- **Applications**: Surface analysis, mesh processing

**Candidate Problem 3: Mean Curvature Normal Evolution**
- **Description**: Simulate mean curvature flow on triangle meshes using discrete differential operators
- **Mathematical Foundation**: ∂S/∂t = H⃗n (mean curvature normal)
- **Shader Suitability**: Medium - requires iterative computation
- **Complexity**: High
- **Applications**: Surface smoothing, geometric flows

#### Category 2: Tangent Space Operations

**Candidate Problem 4: Tangent Space Basis Construction**
- **Description**: Given surface points and normals, construct orthonormal tangent space bases
- **Mathematical Foundation**: Gram-Schmidt orthogonalization on tangent vectors
- **Shader Suitability**: High - independent per-vertex computation
- **Complexity**: Low-Medium
- **Applications**: Normal mapping, surface parameterization

**Candidate Problem 5: Parallel Transport Visualization**
- **Description**: Visualize parallel transport of vectors along geodesics on curved surfaces
- **Mathematical Foundation**: Connection coefficients and covariant differentiation
- **Shader Suitability**: Medium - path-dependent computation
- **Complexity**: High
- **Applications**: Fiber bundles, geometric holonomy

#### Category 3: Differential Forms and Coordinate Systems

**Candidate Problem 6: Coordinate Transformation Jacobians**
- **Description**: Compute and visualize Jacobian determinants for coordinate transformations
- **Mathematical Foundation**: J = det(∂x^i/∂y^j)
- **Shader Suitability**: High - pointwise matrix computation
- **Complexity**: Medium
- **Applications**: Coordinate system analysis, distortion visualization

**Candidate Problem 7: Volume Form Computation**
- **Description**: Calculate volume forms on manifolds and visualize orientation
- **Mathematical Foundation**: ω = √|g| dx¹ ∧ dx² ∧ ... ∧ dxⁿ
- **Shader Suitability**: High - determinant computation
- **Complexity**: Medium
- **Applications**: Integration on manifolds, orientation analysis