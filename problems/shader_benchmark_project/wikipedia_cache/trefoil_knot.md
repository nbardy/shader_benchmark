# Trefoil Knot - Wikipedia Cache
**Cached by Carol - June 28, 2025**
**Source**: https://en.wikipedia.org/wiki/Trefoil_knot

## Definition

The **trefoil knot** is the simplest example of a **non-trivial knot** in knot theory:
- **Crossing number**: 3 (minimum crossings needed)
- **Prime knot**: Cannot be decomposed into simpler knots
- **Chiral**: Has distinct left and right-handed variants
- **Notation**: 3₁ in Alexander-Briggs notation

## Parameterizations

### Standard Cartesian Form
```
x = sin(t) + 2sin(2t)
y = cos(t) - 2cos(2t)
z = -sin(3t)
```
**Period**: 2π, **Parameter range**: t ∈ [0, 2π]

### Torus Knot Form (2,3-torus knot)
```
x = (2 + cos(3t))cos(2t)
y = (2 + cos(3t))sin(2t)
z = sin(3t)
```
**Wrapping**: 2 times around major axis, 3 times around minor axis

### Alternative Symmetric Form
```
x = sin(t) + 2sin(2t)
y = cos(t) - 2cos(2t)  
z = -sin(3t)
```

## Computational Characteristics

### Topological Properties:
- **Tricolorable**: Can be colored with 3 colors following crossing rules
- **Unknotting number**: 1 (one crossing change converts to unknot)
- **Bridge number**: 2 (minimum number of local maxima)
- **Genus**: 1 (minimal genus surface bounded by knot)

### Polynomial Invariants:

#### Alexander Polynomial
Δ(t) = t - 1 + t⁻¹
- **Symmetric**: Δ(t) = Δ(t⁻¹)
- **Cannot distinguish** left/right chirality
- **Laurent polynomial** in one variable

#### Jones Polynomial  
V(q) = q⁻¹ + q⁻³ - q⁻⁴
- **Distinguishes chirality**: V_left ≠ V_right
- **Skein relation**: Recursive computation method
- **More sensitive** than Alexander polynomial

#### HOMFLY Polynomial
L(α,z) = -α⁴ + α²z² + 2α²
- **Two-variable generalization**
- **Contains both** Alexander and Jones as specializations
- **Most powerful** polynomial invariant

## Computational Methods

### Knot Generation:
- **Parametric curve evaluation**
- **Trigonometric function computation**
- **Real-time curve generation**
- **Adaptive sampling** for smooth rendering

### Invariant Calculation:
- **Crossing pattern analysis**
- **Skein relation recursion**
- **Reidemeister move implementation**
- **Polynomial arithmetic**

## Visualization Techniques

### 3D Rendering:
- **Tube rendering** around parametric curve
- **Adaptive tessellation** for smooth appearance
- **Crossing highlighting** with depth cues
- **Color coding** for mathematical properties

### Interactive Features:
- **Real-time rotation** and scaling
- **Parameter animation** (t-value sweeping)
- **Projection methods** for 2D representations
- **Isotopy animation** showing knot equivalence

## Shader Implementation

### Core Computations:
- **Trigonometric evaluation** for parameterization
- **Vector math** for tangent/normal calculation
- **Distance field** generation for tube rendering
- **Intersection testing** for crossing detection

### Optimization Strategies:
- **Precomputed lookup tables** for trigonometric functions
- **Level-of-detail** based on viewing distance
- **Parallel curve evaluation** across parameters
- **GPU-optimized polynomial** evaluation

## Applications in Benchmarks

### Mathematical Visualization:
- **Knot theory education**
- **Topological invariant demonstration**
- **Chirality illustration**
- **Polynomial computation verification**

### Computational Challenges:
- **Real-time knot deformation**
- **Crossing number optimization**
- **Isotopy path finding**
- **Multi-knot interaction simulation**

### Performance Testing:
- **Complex trigonometric evaluation**
- **Recursive algorithm implementation**
- **Memory-intensive polynomial storage**
- **Numerical precision maintenance**

## Extensions and Variations

### Other Torus Knots:
- **(3,2)**: Mirror image of trefoil
- **(4,3)**: Eight-crossing torus knot
- **(5,2)**: Ten-crossing torus knot

### Knot Families:
- **Twist knots**: Systematic construction
- **Pretzel knots**: Multiple crossing regions
- **Satellite knots**: Composite constructions

This provides comprehensive foundation for knot theory benchmarks combining topology, parametric geometry, and computational mathematics.