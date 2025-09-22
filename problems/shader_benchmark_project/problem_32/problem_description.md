# Problem 32: Rounded Box

## Description
Create a 3D rounded box (rectangular prism with rounded edges and corners) using signed distance functions. The box should have different dimensions for each axis and smooth rounded edges with a radius of 0.3 units.

## Requirements

1. **Geometry**:
   - Box dimensions: 2.0 x 1.5 x 1.0 units (width x height x depth)
   - Corner/edge rounding radius: 0.3 units
   - Smooth transitions between flat faces and rounded edges

2. **Material Properties**:
   - Matte plastic finish
   - Color: Pastel mint green (#88e0b0)
   - Low specular reflection
   - Subtle diffuse shading

3. **Lighting**:
   - Single directional light source
   - Soft shadows with proper penumbra
   - Ambient lighting component

4. **Camera**:
   - Orbiting camera for 360° view
   - Fixed distance from origin
   - Looking at box center

## Technical Constraints
- Use signed distance functions (SDF) for geometry
- Implement proper normal calculation
- Shadow calculation using ray marching
- Efficient intersection testing