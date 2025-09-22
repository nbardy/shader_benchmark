# Shader Programming Challenge Template

## Problem Format Standard

Each shader programming challenge should follow this format:

### **Problem [ID]: [Title]**

**Objective**: [Clear description of what shader code should accomplish]

**Shader Type**: [Vertex/Fragment/Compute/Geometry]

**Difficulty Level**: [Beginner/Intermediate/Advanced/Expert]

**Mathematical Context**: [Relevant geometric/mathematical concepts involved]

**Inputs**:
- [List required inputs: vertex attributes, uniforms, textures, etc.]

**Expected Outputs**: 
- [Describe expected visual result or computed values]

**Success Criteria**:
- [How to evaluate if generated code works correctly]
- [Performance considerations if applicable]

**Reference Equations** (Context Only):
```
[Mathematical formulas relevant to the problem - NOT solutions]
```

**Tags**: [geometry, lighting, procedural, animation, etc.]

---

## Example Problem

### **Problem 001: Rotating Torus with Phong Lighting**

**Objective**: Generate a fragment shader that renders a procedurally defined torus with Phong lighting model.

**Shader Type**: Fragment Shader

**Difficulty Level**: Intermediate  

**Mathematical Context**: Parametric surface definition, surface normals, Phong reflection model

**Inputs**:
- `vec2 fragCoord` - screen coordinates
- `uniform float time` - animation time
- `uniform vec3 lightPos` - light position
- `uniform vec3 cameraPos` - camera position

**Expected Outputs**:
- Rendered torus that rotates over time
- Proper diffuse and specular highlights
- Smooth surface normals

**Success Criteria**:
- Torus geometry is mathematically correct
- Lighting calculations follow Phong model
- Animation is smooth and continuous
- No visual artifacts or incorrect normals

**Reference Equations** (Context Only):
```
Torus: (sqrt(x² + y²) - R)² + z² = r²
Phong: I = Ia + Id(N·L) + Is(R·V)^n
```

**Tags**: geometry, lighting, procedural, animation