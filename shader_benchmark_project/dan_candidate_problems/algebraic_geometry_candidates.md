# Algebraic Geometry Candidate Problem Statements
## Compiled by Dan - PhD Researcher (Geometry & Mathematics)

### Problem Domain: Algebraic Geometry and Projective Geometry for Shader Applications

#### Category 1: Polynomial Curves and Surfaces

**Candidate Problem 65: Cubic Curve Visualization**
- **Description**: Render families of cubic curves defined by ax³ + by³ + cxy² + dyx² + ex + fy + g = 0
- **Mathematical Foundation**: Implicit polynomial equation evaluation
- **Shader Suitability**: High - pointwise polynomial evaluation
- **Complexity**: Low-Medium
- **Applications**: Algebraic curve visualization, parametric families

**Candidate Problem 66: Quartic Surface Rendering**
- **Description**: Visualize quartic surfaces in 3D space using implicit surface techniques
- **Mathematical Foundation**: Fourth-degree polynomial equations in three variables
- **Shader Suitability**: High - implicit surface ray marching
- **Complexity**: Medium-High
- **Applications**: Complex surface visualization, algebraic variety representation

**Candidate Problem 67: Elliptic Curve Operations**
- **Description**: Implement elliptic curve point addition and visualization of group law
- **Mathematical Foundation**: y² = x³ + ax + b with chord-tangent construction
- **Shader Suitability**: High - geometric construction and algebraic operations
- **Complexity**: Medium
- **Applications**: Cryptographic visualization, algebraic group operations

**Candidate Problem 68: Rational Parametric Curves**
- **Description**: Render rational parametric curves with proper handling of singularities
- **Mathematical Foundation**: x(t) = P(t)/Q(t), y(t) = R(t)/S(t) rational functions
- **Shader Suitability**: High - rational function evaluation
- **Complexity**: Medium
- **Applications**: CAD applications, spline alternatives, algebraic curve parameterization

#### Category 2: Projective Geometry and Homogeneous Coordinates

**Candidate Problem 69: Projective Line Intersections**
- **Description**: Compute intersections of lines in projective plane including points at infinity
- **Mathematical Foundation**: Homogeneous coordinates [x:y:z] and line equations
- **Shader Suitability**: High - linear algebra and cross products
- **Complexity**: Low-Medium
- **Source**: Projective Geometry - Wikipedia
- **Applications**: Perspective drawing, geometric constructions

**Candidate Problem 70: Cross-Ratio Computation**
- **Description**: Calculate cross-ratios of collinear points and visualize invariance under projective transformations
- **Mathematical Foundation**: (A,B;C,D) = (AC/BC):(AD/BD) cross-ratio formula
- **Shader Suitability**: High - arithmetic operations and ratio computation
- **Complexity**: Low-Medium
- **Applications**: Projective invariants, perspective analysis

**Candidate Problem 71: Perspective Transformation Visualization**
- **Description**: Implement general projective transformations between planes
- **Mathematical Foundation**: 3×3 homogeneous transformation matrices
- **Shader Suitability**: High - matrix multiplication and homogeneous division
- **Complexity**: Medium
- **Applications**: Computer vision, perspective correction, image rectification

**Candidate Problem 72: Dual Plane-Point Correspondence**
- **Description**: Visualize point-line duality in projective plane
- **Mathematical Foundation**: Points [a:b:c] ↔ Lines ax + by + cz = 0
- **Shader Suitability**: High - coordinate transformation and visualization
- **Complexity**: Medium
- **Applications**: Projective duality, geometric theorem proving

#### Category 3: Algebraic Varieties and Zero Sets

**Candidate Problem 73: Polynomial Zero Set Visualization**
- **Description**: Visualize zero sets of multivariate polynomials using level set methods
- **Mathematical Foundation**: f(x,y,z) = 0 for polynomial f
- **Shader Suitability**: High - implicit function evaluation
- **Complexity**: Medium
- **Applications**: Algebraic variety visualization, equation solving

**Candidate Problem 74: Intersection of Algebraic Curves**
- **Description**: Compute and visualize intersections between algebraic plane curves
- **Mathematical Foundation**: Simultaneous polynomial system solving
- **Shader Suitability**: Medium - requires root finding algorithms
- **Complexity**: High
- **Applications**: Geometric intersection problems, algebraic system solving

**Candidate Problem 75: Singular Point Detection**
- **Description**: Identify and classify singular points of algebraic curves
- **Mathematical Foundation**: Vanishing of partial derivatives ∂f/∂x = ∂f/∂y = 0
- **Shader Suitability**: High - derivative computation and classification
- **Complexity**: Medium-High
- **Applications**: Curve analysis, singularity theory, geometric classification

#### Category 4: Gröbner Bases and Computational Algebra

**Candidate Problem 76: Ideal Membership Testing**
- **Description**: Test polynomial membership in ideals using reduction algorithms
- **Mathematical Foundation**: Polynomial division and normal form computation
- **Shader Suitability**: Medium - symbolic computation adaptation needed
- **Complexity**: High
- **Applications**: Algebraic system solving, computational algebra

**Candidate Problem 77: Hilbert Function Computation**
- **Description**: Compute dimensions of graded pieces of polynomial rings
- **Mathematical Foundation**: Vector space dimension counting for homogeneous polynomials
- **Shader Suitability**: Medium - combinatorial counting problems
- **Complexity**: High
- **Applications**: Algebraic geometry invariants, polynomial ring structure

#### Category 5: Rational Maps and Birational Geometry

**Candidate Problem 78: Rational Map Visualization**
- **Description**: Visualize rational maps between algebraic varieties
- **Mathematical Foundation**: f: V → W defined by ratios of polynomials
- **Shader Suitability**: High - rational function evaluation with domain restrictions
- **Complexity**: Medium-High
- **Applications**: Birational geometry, algebraic transformation visualization

**Candidate Problem 79: Blowup Construction Visualization**
- **Description**: Visualize blowup of algebraic varieties at points or subvarieties
- **Mathematical Foundation**: Resolution of singularities through blowup operations
- **Shader Suitability**: Medium - requires coordinate transformation and exceptional divisor handling
- **Complexity**: High
- **Applications**: Singularity resolution, birational geometry

#### Category 6: Arithmetic Geometry and Number Theory

**Candidate Problem 80: Rational Point Search**
- **Description**: Visualize rational points on algebraic curves over finite fields
- **Mathematical Foundation**: Solutions to polynomial equations in F_p or Q
- **Shader Suitability**: High - finite field arithmetic and point enumeration
- **Complexity**: Medium-High
- **Applications**: Number theory, cryptography, Diophantine equations

**Candidate Problem 81: L-function Zero Visualization**
- **Description**: Visualize zeros of L-functions associated to elliptic curves
- **Mathematical Foundation**: Complex analysis and special function evaluation
- **Shader Suitability**: Medium - complex function evaluation
- **Complexity**: High
- **Applications**: Analytic number theory, BSD conjecture visualization

#### Category 7: Toric Geometry and Polytopes

**Candidate Problem 82: Toric Variety Construction**
- **Description**: Construct toric varieties from lattice polytopes and fan data
- **Mathematical Foundation**: Correspondence between polytopes and projective varieties
- **Shader Suitability**: High - polytope visualization and coordinate computation
- **Complexity**: High
- **Applications**: Algebraic geometry, combinatorial geometry, mirror symmetry

**Candidate Problem 83: Newton Polytope Visualization**
- **Description**: Visualize Newton polytopes of multivariate polynomials
- **Mathematical Foundation**: Convex hull of exponent vectors in polynomial terms
- **Shader Suitability**: High - convex hull computation and 3D visualization
- **Complexity**: Medium
- **Applications**: Tropical geometry, polynomial analysis, optimization