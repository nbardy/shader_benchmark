# Superformula Explorer

Create an interactive WebGL visualization of Gielis' superformula, showing how parameter changes create diverse natural and abstract shapes.

## Requirements:

1. Implement the superformula:
   r(θ) = (|cos(m*θ/4)/a|^n2 + |sin(m*θ/4)/b|^n3)^(-1/n1)
2. Display multiple shapes simultaneously showing:
   - Star-like forms (varying m)
   - Flower-like patterns (specific n values)
   - Polygonal shapes
   - Asymmetric forms
3. Animate smooth transitions between parameter sets
4. Use HSL color mapping based on:
   - Angle (hue)
   - Radius (lightness)
   - Parameter values (saturation)
5. Add 3D extrusion option for selected shapes
6. Include parameter value display
7. Create organic particle effects around shapes