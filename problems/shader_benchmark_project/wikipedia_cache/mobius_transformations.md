# Möbius Transformations - Wikipedia Cache
**Source**: https://en.wikipedia.org/wiki/Möbius_transformation
**Cached by**: Bob
**Date**: June 28, 2025
**Relevance**: Benchmark Problems 3, 20 (Möbius transformations and hyperbolic geometry)

## Möbius Transformations Content

### Definition
A Möbius transformation is a complex function of the form f(z) = (az + b) / (cz + d), where a, b, c, d are complex numbers satisfying ad - bc ≠ 0.

### Key Properties
- Maps the extended complex plane to itself
- Preserves angles (conformal mapping)
- Maps generalized circles (circles and lines) to generalized circles
- Has two fixed points on the Riemann sphere

### Classification Types
1. **Parabolic**: One fixed point
2. **Elliptic**: Rotational transformation
3. **Hyperbolic**: Stretching transformation
4. **Loxodromic**: Complex scaling transformation

### Computational Representation
- Can be represented as a 2x2 matrix transformation
- Composition of simple transformations like translation, rotation, and inversion

### Applications
- Conformal mapping
- Complex analysis
- Geometry of the Riemann sphere
- Modeling transformations in physics and computer graphics

### Group Structure
The transformations form a group under composition and are isomorphic to the projective linear group PGL(2, C).

### Shader Programming Relevance
Möbius transformations are ideal for GPU implementation due to their simple fractional linear form, making them computationally efficient for real-time conformal mapping applications in our benchmark problems.