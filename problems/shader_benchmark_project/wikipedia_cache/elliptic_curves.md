# Elliptic Curves - Wikipedia Cache
**Cached by Carol - June 28, 2025**
**Source**: https://en.wikipedia.org/wiki/Elliptic_curve

## Mathematical Definition

### Standard Weierstrass Form
y² = x³ + ax + b

**Non-singular condition**: 4a³ + 27b² ≠ 0
- Defined over fields with characteristic ≠ 2, 3
- Forms smooth algebraic curve
- Admits group structure

## Group Law Operations

### Point Addition (P + Q)
1. **Draw line through P and Q**
2. **Find third intersection point R**  
3. **Reflect R across x-axis** to get P + Q

### Point Doubling (2P)
1. **Use tangent line at point P**
2. **Find second intersection point**
3. **Reflect point across x-axis**

### Computational Formulas

For points P = (x₁, y₁) and Q = (x₂, y₂):

**Case 1: P ≠ Q (Point Addition)**
- λ = (y₂ - y₁)/(x₂ - x₁)
- x₃ = λ² - x₁ - x₂  
- y₃ = λ(x₁ - x₃) - y₁

**Case 2: P = Q (Point Doubling)**
- λ = (3x₁² + a)/(2y₁)
- x₃ = λ² - 2x₁
- y₃ = λ(x₁ - x₃) - y₁

## Key Properties

### Group Structure:
- **Abelian group** with point at infinity as identity
- **Associative**: (P + Q) + R = P + (Q + R)
- **Commutative**: P + Q = Q + P
- **Identity element**: Point at infinity O
- **Inverse**: -P = (x, -y) for P = (x, y)

### Computational Considerations:
- **Coordinate transformations** depend on relative point positions
- **Special handling** for point at infinity (identity element)
- **Slope calculations** vary based on point relationships
- **Edge case management** for vertical lines and tangents

## Implementation for Shaders

### GPU Optimization Opportunities:
- **Parallel point operations** across curve points
- **Batch scalar multiplication** algorithms
- **Precomputed tables** for common operations
- **Montgomery ladder** for efficient scalar multiplication

### Computational Challenges:
- **Division operations** (expensive on GPU)
- **Conditional branching** for different cases
- **Precision management** for field arithmetic
- **Modular arithmetic** implementation

## Applications in Benchmarks

### Mathematical Operations:
- **Point addition chains**
- **Scalar multiplication algorithms**
- **Curve group order computation**
- **Discrete logarithm problems**

### Visualization Challenges:
- **Real-time curve rendering**
- **Group operation animation**
- **Multiple curves comparison**
- **Parameter space exploration**

## Advanced Forms

### Projective Coordinates:
- Eliminates division operations
- Uses homogeneous coordinates [X:Y:Z]
- More efficient for repeated operations

### Montgomery Form:
- Optimized for scalar multiplication
- Form: By² = x³ + Ax² + x
- Faster doubling operations

This provides foundation for elliptic curve benchmark problems focusing on algebraic operations and group theory computations.