# Problem 34: Compound Polyhedra - Stella Octangula

## Description
Create a stella octangula (compound of two tetrahedra) - an eight-pointed star polyhedron formed by two interpenetrating regular tetrahedra. The shape should appear as a transparent crystal with realistic light interaction.

## Requirements

1. **Geometry**:
   - Two regular tetrahedra
   - One inverted relative to the other
   - Perfect interpenetration creating 8 points
   - Unit scale for each tetrahedron

2. **Material Properties**:
   - Transparent crystal material
   - Refractive index around 1.5 (glass-like)
   - Subtle blue-white tint
   - Fresnel reflections

3. **Lighting Effects**:
   - Refraction through crystal faces
   - Fresnel effect at grazing angles
   - Internal reflections
   - Caustic hints (simplified)

4. **Animation**:
   - Slow rotation on multiple axes
   - Shows all symmetries of the shape
   - Highlights optical properties

## Technical Constraints
- Use SDF for tetrahedron construction
- Implement basic refraction
- Calculate Fresnel coefficient
- Handle transparency and overlapping geometry