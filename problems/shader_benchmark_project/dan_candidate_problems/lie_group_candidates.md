# Lie Group Candidate Problem Statements
## Compiled by Dan - PhD Researcher (Geometry & Mathematics)

### Problem Domain: Lie Groups and Algebraic Structures for Shader Applications

#### Category 1: Matrix Lie Groups

**Candidate Problem 8: SO(3) Rotation Interpolation**
- **Description**: Implement geodesic interpolation between rotation matrices in SO(3) using matrix exponentials
- **Mathematical Foundation**: R(t) = R₁ exp(t log(R₁⁻¹R₂))
- **Shader Suitability**: High - matrix operations and exponentials
- **Complexity**: Medium-High
- **Applications**: Animation, camera interpolation, object rotation

**Candidate Problem 9: SU(2) Quaternion-Matrix Correspondence**
- **Description**: Visualize the double cover relationship between SU(2) and SO(3) through quaternion rotations
- **Mathematical Foundation**: SU(2) → SO(3) homomorphism mapping
- **Shader Suitability**: High - quaternion and matrix operations
- **Complexity**: Medium
- **Applications**: Orientation representation, gimbal lock avoidance

**Candidate Problem 10: GL(n) Determinant Preservation**
- **Description**: Track determinant changes under continuous GL(n) transformations
- **Mathematical Foundation**: det(AB) = det(A)det(B), matrix multiplication
- **Shader Suitability**: High - matrix determinant computation
- **Complexity**: Low-Medium
- **Applications**: Volume preservation analysis, linear transformations

#### Category 2: Exponential Maps and Lie Algebras

**Candidate Problem 11: Matrix Exponential Computation**
- **Description**: Compute matrix exponentials exp(tX) for various Lie algebra elements X
- **Mathematical Foundation**: exp(X) = I + X + X²/2! + X³/3! + ...
- **Shader Suitability**: Medium - series computation with convergence
- **Complexity**: High
- **Applications**: One-parameter subgroups, infinitesimal generators

**Candidate Problem 12: Logarithmic Map Visualization**
- **Description**: Compute and visualize logarithmic maps from group elements to algebra elements
- **Mathematical Foundation**: log: G → 𝔤 (inverse of exponential map)
- **Shader Suitability**: Medium - iterative methods required
- **Complexity**: High
- **Applications**: Tangent space projections, group analysis

**Candidate Problem 13: Adjoint Representation**
- **Description**: Compute adjoint actions Ad_g(X) = gXg⁻¹ for matrix groups
- **Mathematical Foundation**: Ad: G → GL(𝔤) group homomorphism
- **Shader Suitability**: High - matrix multiplication
- **Complexity**: Medium
- **Applications**: Group actions on algebras, symmetry analysis

#### Category 3: Group Actions and Transformations

**Candidate Problem 14: Circle Group S¹ Actions**
- **Description**: Visualize S¹ = SO(2) actions on the plane through rotation transformations
- **Mathematical Foundation**: (θ, (x,y)) → (x cos θ - y sin θ, x sin θ + y cos θ)
- **Shader Suitability**: High - trigonometric functions
- **Complexity**: Low
- **Applications**: Rotational symmetry, periodic transformations

**Candidate Problem 15: Möbius Transformations (PSL(2,ℂ))**
- **Description**: Implement Möbius transformations f(z) = (az+b)/(cz+d) on the complex plane
- **Mathematical Foundation**: 2×2 complex matrices with determinant 1
- **Shader Suitability**: High - complex arithmetic and rational functions
- **Complexity**: Medium
- **Applications**: Conformal mappings, hyperbolic geometry

**Candidate Problem 16: Scaling Group Actions**
- **Description**: Visualize one-parameter scaling groups R⁺ acting on geometric objects
- **Mathematical Foundation**: (t, x) → tx for t > 0
- **Shader Suitability**: High - simple scalar multiplication
- **Complexity**: Low
- **Applications**: Self-similarity, fractal generation, dilation

#### Category 4: Continuous Group Structure

**Candidate Problem 17: One-Parameter Subgroups**
- **Description**: Generate and visualize one-parameter subgroups {exp(tX) | t ∈ ℝ}
- **Mathematical Foundation**: Exponential map from ℝ to G
- **Shader Suitability**: High - parametric curve generation
- **Complexity**: Medium
- **Applications**: Flow visualization, continuous symmetries

**Candidate Problem 18: Group Commutator Computation**
- **Description**: Compute and visualize commutators [g,h] = ghg⁻¹h⁻¹ in matrix groups
- **Mathematical Foundation**: Lie bracket in algebra via commutator
- **Shader Suitability**: High - matrix operations
- **Complexity**: Medium
- **Applications**: Non-abelian structure, curvature analysis