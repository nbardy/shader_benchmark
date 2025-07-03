# 3D Rotation Group SO(3) - Wikipedia Cache
**Cached by Carol - June 28, 2025**
**Source**: https://en.wikipedia.org/wiki/3D_rotation_group

## Group Definition

**SO(3)** is the special orthogonal group in 3 dimensions:
- **3×3 orthogonal matrices** with determinant +1
- **Proper rotations** (orientation-preserving)
- **Lie group** structure with 3 degrees of freedom
- **Compact manifold** diffeomorphic to ℝP³

## Parameterizations

### 1. Axis-Angle Representation
Every rotation defined by:
- **Unit vector axis** n̂ ∈ S²
- **Rotation angle** θ ∈ [0,π]
- **Fixed 1-dimensional subspace** (rotation axis)

### 2. Matrix Representation
**Orthogonal matrices**: R^T R = I, det(R) = +1
General form for rotation by angle θ around axis n̂:
R = I + sin(θ)[n̂]× + (1-cos(θ))[n̂]²×

### 3. Quaternion Representation  
**Unit quaternions** q = w + xi + yj + zk where |q| = 1
- **Double cover**: SU(2) → SO(3)
- **More efficient** for composition
- **No gimbal lock**

### 4. Euler Angles
Sequential rotations around coordinate axes:
- **ZYX convention**: R = R_z(γ)R_y(β)R_x(α)
- **Gimbal lock** at β = ±π/2
- **Singularities** in parameterization

## Computational Methods

### Exponential Map
**Rodrigues' Formula**: exp(θv̂) = I + sin(θ)[v̂]× + (1-cos(θ))[v̂]²×

Where [v̂]× is the skew-symmetric matrix:
```
[v̂]× = [ 0   -v₃   v₂]
        [ v₃   0   -v₁]
        [-v₂   v₁   0 ]
```

### Matrix Exponential Series
exp(A) = I + A + (1/2!)A² + (1/3!)A³ + ...
For skew-symmetric matrices A ∈ so(3)

### Quaternion to Matrix Conversion
For q = w + xi + yj + zk:
```
R = [1-2y²-2z²    2xy-2zw     2xz+2yw  ]
    [2xy+2zw     1-2x²-2z²    2yz-2xw  ]
    [2xz-2yw     2yz+2xw     1-2x²-2y²]
```

## Lie Algebra so(3)

### Generators (Infinitesimal Rotations)
```
J₁ = [0  0  0]    J₂ = [0  0  1]    J₃ = [0 -1  0]
     [0  0 -1]         [0  0  0]         [1  0  0]
     [0  1  0]         [-1 0  0]         [0  0  0]
```

### Commutation Relations
[J₁,J₂] = J₃, [J₂,J₃] = J₁, [J₃,J₁] = J₂

### Connection to Physics
- **Angular momentum** operators
- **Spin matrices** (Pauli matrices)
- **Infinitesimal generators** of rotations

## Conversion Formulas

### Matrix to Axis-Angle
```
trace(R) = 1 + 2cos(θ)
θ = arccos((trace(R)-1)/2)
n̂ = (1/(2sin(θ)))[R₃₂-R₂₃, R₁₃-R₃₁, R₂₁-R₁₂]ᵀ
```

### Quaternion to Axis-Angle
```
θ = 2arccos(w)
n̂ = (x,y,z)/sin(θ/2)
```

### Euler Angles to Matrix
R = R_z(γ)R_y(β)R_x(α) with explicit trigonometric entries

## Implementation for Shaders

### Core Operations:
- **Matrix multiplication** for composition
- **Exponential map** computation
- **Quaternion arithmetic**
- **Trigonometric evaluation**

### Optimization Strategies:
- **Quaternion preference** for repeated operations
- **Precomputed rotation** matrices for common angles
- **SLERP interpolation** for smooth animation
- **Numerical stability** checks

## Applications in Benchmarks

### 3D Transformations:
- **Real-time object rotation**
- **Camera control** systems
- **Animation interpolation**
- **Orientation tracking**

### Mathematical Computation:
- **Group operation** verification
- **Conversion algorithm** testing
- **Numerical precision** analysis
- **Singularity handling**

### Performance Testing:
- **Matrix vs quaternion** efficiency
- **Composition chains**
- **Memory access patterns**
- **Branch prediction** optimization

## Advanced Topics

### Topology:
- **Real projective space** ℝP³ structure
- **Quaternion double cover**
- **Fundamental group** π₁(SO(3)) = ℤ₂

### Lie Theory:
- **Exponential map** surjectivity
- **Adjoint representation**
- **Root system** structure

### Applications:
- **Robotics** (joint rotations)
- **Computer graphics** (3D rendering)
- **Physics** (angular momentum)
- **Crystallography** (symmetry groups)

This provides comprehensive foundation for 3D rotation benchmarks combining group theory, computational geometry, and practical implementation considerations.