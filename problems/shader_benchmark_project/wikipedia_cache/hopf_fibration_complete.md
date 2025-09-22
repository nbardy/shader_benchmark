# Hopf Fibration - Wikipedia Cache (Complete)
**Cached by Carol - June 28, 2025**
**Source**: https://en.wikipedia.org/wiki/Hopf_fibration

## Mathematical Formulation

The Hopf fibration is a fiber bundle mapping: S¹ ↪ S³ → S²
- Represents a continuous function mapping 3-sphere to 2-sphere
- Each point on 2-sphere mapped from a distinct great circle of 3-sphere
- Provides fundamental example of non-trivial fiber bundle

## Quaternion Representation

Identifies R⁴ with complex quaternion space using parametrization:
- z₀ = e^(i(x₁+x₂)/2) sin(η)
- z₁ = e^(i(x₂-x₁)/2) cos(η)

### Hopf Map Formula
h: S³ → S² given by h(z₁, z₂) = (2z₁z̄₂, |z₁|² - |z₂|²)

### Quaternion Form
For unit quaternion q = (w,x,y,z):
π(q) = q·î·q̄ where î = (0,1,0,0)

## Stereographic Projection

Maps S³ to R³ with key properties:
- **Preserves circles** - all fibers project to circles in R³
- **Creates nested tori** filled with Villarceau circles
- **One fiber maps to line** "through infinity"
- **Fills all of 3-space** except z-axis with linking circles

### Projection Formula
φ(x₁,x₂,x₃,x₄) = (x₁/(1-x₄), x₂/(1-x₄), x₃/(1-x₄))

## Computational Visualization Techniques

### 4D to 3D Mapping:
- Uses complex projective line (CP¹)
- Rotation group SO(3) mapping
- Interactive point transformation visualization
- Real-time fiber circle generation

### Implementation Strategies:
- **Uniform sampling** of rotation spaces
- **Motion planning** in robotics applications  
- **Quantum mechanical** state space visualization
- **Topological structure** exploration

## Shader Implementation Details

### Core Computations:
1. **Complex arithmetic** operations for z₁, z₂
2. **Quaternion multiplication** and conjugation
3. **Stereographic projection** calculations
4. **Circle generation** in 3D space

### Optimization Opportunities:
- **Parallel fiber computation** across pixels
- **Precomputed circle templates**
- **Level-of-detail** based on viewing distance
- **Interactive parameter** adjustment

## Applications in Benchmarks

### Mathematical Visualization:
- **4D geometry** exploration
- **Fiber bundle** structure demonstration
- **Topological mapping** illustration
- **Rotation group** visualization

### Computational Challenges:
- **Real-time 4D rendering**
- **Interactive navigation**
- **Multi-scale visualization**
- **Precision maintenance** in projections

## Connection to Other Concepts

- **Lie group theory**: Connection to SU(2) and SO(3)
- **Complex analysis**: Riemann sphere representation
- **Differential geometry**: Parallel transport and connections
- **Quantum mechanics**: Spin state representations

This provides fundamental infrastructure for advanced 4D geometry benchmarks in shader applications.