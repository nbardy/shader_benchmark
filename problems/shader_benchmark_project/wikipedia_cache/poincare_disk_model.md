# Poincaré Disk Model - Wikipedia Cache
**Cached by Carol - June 28, 2025**
**Source**: https://en.wikipedia.org/wiki/Poincar%C3%A9_disk_model

## Model Definition

The **Poincaré disk model** represents the **hyperbolic plane** within the unit disk in Euclidean space:
- **Interior points** of unit disk represent hyperbolic points
- **Boundary circle** represents "points at infinity"
- **Conformal model**: preserves angles
- **Constant negative curvature**: K = -1

## Distance Formulas

### Primary Distance Formula
d(p,q) = ln(|aq||pb| / |ap||qb|)

Where:
- **a, b** are ideal points where hyperbolic line through p,q meets boundary
- **|xy|** represents Euclidean distance between points x,y

### Vector Form
For points u, v ∈ ℝⁿ with ||u||, ||v|| < 1:
d(u,v) = 2tanh⁻¹(||u-v|| / ||1-ūv||)

### Alternative Cayley-Klein Form  
d(u,v) = arccosh((1-2||u-v||²/((1-||u||²)(1-||v||²))) + 1)

## Metric Tensor

### Riemannian Metric
ds² = 4(dx² + dy²) / (1 - x² - y²)²

### In General Dimension
ds² = 4∑ᵢ(dxᵢ)² / (1 - ∑ᵢxᵢ²)²

## Geodesics

### Geodesic Types:
1. **Diameters**: Straight lines through origin
2. **Circular arcs**: Circles intersecting boundary at right angles

### Parametric Geodesic (Unit Speed)
For geodesic through origin in direction n̂:
γ(t) = n̂ · tanh(t/2)

## Isometry Group

### Möbius Transformations
Orientation-preserving isometries: f(z) = e^(iθ) · (z+a)/(āz+1)
Where |a| < 1

### Matrix Representation
Elements of PSU(1,1) ≅ SL(2,ℝ)/±I acting on disk

### Key Properties:
- **Group action** is transitive
- **Preserves hyperbolic distances**
- **Maps geodesics to geodesics**

## Computational Aspects

### Circle Inversions:
- **Construction** of hyperbolic lines
- **Intersection** calculations
- **Reflection** operations

### Complex Coordinate Methods:
- **Conformal mapping** techniques
- **Analytic continuation**
- **Fractional linear transformations**

### Practical Algorithms:
- **Point-to-point distance** calculation
- **Geodesic construction** between points
- **Parallel line** construction
- **Angle measurement** (preserved from Euclidean)

## Implementation for Shaders

### Core Operations:
- **Complex arithmetic** for Möbius transformations
- **Inverse trigonometric** functions for distances
- **Circle-circle intersection** for geodesics
- **Boundary condition** checking

### Optimization Strategies:
- **Lookup tables** for hyperbolic functions
- **Precomputed geodesic** segments
- **Level-of-detail** for complex curves
- **Parallel computation** across pixels

## Applications in Benchmarks

### Hyperbolic Navigation:
- **Real-time exploration** of hyperbolic space
- **Geodesic path** computation
- **Distance field** generation
- **Tiling pattern** creation

### Mathematical Visualization:
- **Non-Euclidean geometry** education
- **Transformation group** demonstration
- **Limit circle** behavior
- **Hyperbolic tessellation**

### Computational Challenges:
- **Precision near boundary**
- **Numerical stability** of transformations
- **Real-time geodesic** computation
- **Multi-scale rendering**

## Connection to Other Models

### Klein Model:
Projective transformation: w = 2z/(1+|z|²)

### Upper Half-Plane:
Cayley transform: w = i(1-z)/(1+z)

### Hyperboloid Model:
Stereographic projection from hyperboloid

## Advanced Topics

### Tessellations:
- **Regular polygon** tilings
- **Fundamental domains**
- **Symmetry groups**

### Limit Sets:
- **Fractal boundaries**
- **Kleinian groups**
- **Dynamical systems**

This provides comprehensive foundation for hyperbolic geometry benchmarks combining non-Euclidean visualization, transformation mathematics, and computational geometry.