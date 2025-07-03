# Butterfly Curve

Create an animated WebGL visualization of the transcendental butterfly curve with color gradients that emphasize its wing-like structure.

## Requirements:

1. Implement the butterfly curve equation:
   - x = sin(t) * (e^cos(t) - 2*cos(4t) - sin(t/12)^5)
   - y = cos(t) * (e^cos(t) - 2*cos(4t) - sin(t/12)^5)
2. Animate the curve drawing from t=0 to t=12π
3. Apply a color gradient that changes based on:
   - The angle from center
   - The distance from center
   - Creating a butterfly wing effect
4. Add particle effects that follow the curve path
5. Implement a subtle glow effect on the curve
6. Include smooth camera zoom that reveals the full pattern
7. Add a complementary animated background