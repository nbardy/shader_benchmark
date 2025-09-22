# 3D Warps & Loxodromic Motion Shader Challenges

**Agent**: warp_loxodromic  
**Focus**: 3D space warps/deformations and loxodromic motion patterns  
**Deliverable**: 10 shader challenges featuring geometric transformations and complex motion

## Completed Challenges

### 1. Helical Twist Deformation
- **Type**: Space warp
- **Description**: Cube undergoing DNA-like helical twist with linear rotation variation
- **Key Math**: θ = k·z rotation, preserving cross-sections
- **Complexity**: Medium
- **Visual**: Metallic twisted cube with height-based color gradient

### 2. Spherical Inversion Mapping  
- **Type**: Conformal mapping
- **Description**: 3D grid turned inside-out through spherical inversion
- **Key Math**: p' = (R²/|p|²)·p transformation
- **Complexity**: Medium-High
- **Visual**: Dual grid showing space inversion with glow effects

### 3. Loxodromic Sphere Spirals
- **Type**: Loxodromic motion
- **Description**: Constant-angle spirals wrapping around sphere surface
- **Key Math**: Rhumb lines with 35° meridian angle
- **Complexity**: Medium
- **Visual**: 12 luminous spirals with spectrum colors

### 4. Cylindrical Bend Deformation
- **Type**: Space warp
- **Description**: Flat rectangular grid bent into cylindrical arc
- **Key Math**: θ = x/R cylindrical mapping
- **Complexity**: Low-Medium  
- **Visual**: Metallic bent plate with anisotropic highlights

### 5. Möbius Transformation in 3D
- **Type**: Conformal mapping
- **Description**: Complex Möbius transformation of cubic lattice
- **Key Math**: f(w,v) = ((aw+b)/(cw+d), v/|cw+d|²)
- **Complexity**: High
- **Visual**: Warped lattice with conformal preservation

### 6. Logarithmic Spiral Motion
- **Type**: Loxodromic motion
- **Description**: Particles following exponential spiral trajectories
- **Key Math**: r(t) = r₀·exp(kt), logarithmic growth
- **Complexity**: Medium
- **Visual**: 8 spiral arms with motion blur trails

### 7. Wave Deformation Field
- **Type**: Space warp
- **Description**: Planar mesh deformed by interfering wave sources
- **Key Math**: Superposition of circular waves with 1/r decay
- **Complexity**: Medium
- **Visual**: Water-like surface with interference patterns

### 8. Taper and Shear Transformation
- **Type**: Space warp
- **Description**: Cylindrical tower with quadratic taper and linear shear
- **Key Math**: s(z) = 1-0.6(z/4)² taper, linear shear
- **Complexity**: Low-Medium
- **Visual**: Leaning glass/steel tower with architectural details

### 9. Fractal Loxodromic Patterns
- **Type**: Loxodromic motion + fractals
- **Description**: Iterated Möbius transformations creating fractal spirals
- **Key Math**: Loxodromic fixed points with self-similar orbits
- **Complexity**: High
- **Visual**: Multi-scale spiral patterns with iteration-based coloring

### 10. Conformal Spiral Mapping
- **Type**: Conformal mapping
- **Description**: Rectangular grid transformed to Archimedean spiral
- **Key Math**: w = exp(αz) complex exponential map
- **Complexity**: Medium-High
- **Visual**: Glass grid with preserved angles in spiral configuration

## Technical Highlights

- **Mathematical Focus**: Emphasis on transformation equations and geometric preservation
- **Visual Beauty**: Each challenge creates stunning patterns from mathematical principles
- **Implementation**: Suitable for both raymarching (SDF) and vertex shader approaches
- **Complexity Range**: From simple linear transformations to complex conformal mappings

## Directory Structure
Each challenge has its own directory with:
- `generation_prompt.txt`: Detailed implementation specification
- `evaluation_prompt.txt`: Scoring rubric and visual verification criteria

## Integration Notes
These challenges complement other geometric challenges by focusing specifically on:
- Space deformation techniques
- Motion patterns in 3D
- Conformal and angle-preserving transformations
- Mathematical beauty through transformation