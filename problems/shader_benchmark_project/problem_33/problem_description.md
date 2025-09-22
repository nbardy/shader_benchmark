# Problem 33: Capsule Shape

## Description
Create a 3D capsule shape (a cylinder with hemispherical caps on both ends) using signed distance functions. The capsule should rotate slowly to show all angles and demonstrate the smooth blending between the cylindrical body and spherical caps.

## Requirements

1. **Geometry**:
   - Total height: 2.0 units (excluding caps)
   - Radius: 0.5 units
   - Seamless blend between cylinder and hemispheres
   - Centered at origin

2. **Material Properties**:
   - Semi-glossy porcelain finish
   - Color: Off-white/cream (subtle warm tone)
   - Medium specular highlights
   - Soft reflections

3. **Lighting**:
   - Key light from upper right
   - Ambient occlusion for depth
   - Specular highlights to show surface quality

4. **Animation**:
   - Slow rotation around Y-axis
   - Constant angular velocity
   - Full 360° rotation

## Technical Constraints
- Use capsule SDF (line segment + radius)
- Implement Phong or Blinn-Phong shading
- Calculate ambient occlusion
- Smooth normal calculation for highlights