# Catenoid-Helicoid Minimal Surface

Create an animated transformation between a catenoid and helicoid, showcasing the unique property that they are locally isometric minimal surfaces.

## Requirements:

1. Implement the parametric transformation:
   - x = cos(θ) * sinh(v) * sin(u) + sin(θ) * cosh(v) * cos(u)
   - y = -cos(θ) * sinh(v) * cos(u) + sin(θ) * cosh(v) * sin(u)
   - z = u * cos(θ) + v * sin(θ)
   Where θ varies from 0 (helicoid) to π/2 (catenoid)
2. Use a soap bubble-like material with:
   - Thin film interference colors
   - Transparency
   - Reflective properties
3. Animate smooth transformation between surfaces
4. Add wireframe overlay to show surface structure
5. Implement proper two-sided rendering
6. Include ambient particles to show air flow
7. Create a minimalist background that doesn't distract