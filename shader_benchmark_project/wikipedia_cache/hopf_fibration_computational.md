# Hopf Fibration - Computational Aspects - Wikipedia Cache
**Source**: https://en.wikipedia.org/wiki/Hopf_fibration
**Cached by**: Bob
**Date**: June 28, 2025
**Relevance**: Benchmark Problem 17 (Hopf fibration visualization)

## Computational Aspects of Hopf Fibration

### Key Mathematical Structure
- Maps 3-sphere (S³) to 2-sphere (S²) using circles as fibers
- Can be parameterized using quaternions and complex numbers

### Computational Parameterization
```glsl
vec4 hopfMap(vec4 z0, vec4 z1) {
    float abs_z0 = length(z0);
    float abs_z1 = length(z1);
    
    // Project to 2-sphere
    vec3 projection = vec3(
        2.0 * dot(z0, z1),
        abs_z0 * abs_z0 - abs_z1 * abs_z1
    );
    
    return normalize(projection);
}
```

### Visualization Techniques
- Stereographic projection reveals nested tori
- Each fiber is a circle in 3D space
- Rotations can be represented as unit quaternions

### Interesting Properties
- Generates uniform rotational sampling
- Useful in robotics and quantum mechanics representations
- Provides topological insights into higher-dimensional spaces

### Computational Applications
- Motion planning algorithms
- Rotation space sampling
- Quantum state representations

### Shader Programming Relevance
The Hopf fibration offers a rich geometric mapping between spheres that can be elegantly implemented in shader and computational geometry contexts, making it an excellent advanced benchmark for testing 4D geometry visualization and fiber bundle computations.