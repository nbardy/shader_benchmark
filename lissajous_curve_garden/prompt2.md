## Prompt #2 – **Verbose Evaluation / Scoring Prompt**

**Context (ground‑truth)**

* Nine curves defined by $(a,b)∈\{1,2,3\}²$.
* Parametric period $T=2π$.  For integers a,b the curve closes after $T_c=\frac{2π}{\gcd(a,b)}$.
* Number of axial intercepts: $N_x=2b$, $N_y=2a$.

**Evaluation procedure**

1. **Locate cell centres** by detecting the 150‑px gutters (pure white RGB 255).
2. For each cell:

   1. Resample the raster curve into 2048 equally spaced points (edge detection, centre of stroke).
   2. FFT the x‑ and y‑coordinate sequences – the dominant peak indexes must equal a and b (within ±0.5).
   3. Count zero‑crossings of x and y to confirm $N_x,N_y$.
   4. Compute bounding‑box width W; ensure $0.80≤W/Cell≤0.88$.
   5. Extract median HSV hue of stroke pixels; verify hue ≈ atan2(a,b)/π within ±6 ° (convert both to degrees).
3. Check axis lines: Hough transform should return two perpendicular grey (≈#bbbbbb) lines per cell, each ≤1 px thick.

**Scoring rubric (10 pts)**

| Weight    | Criterion               | Pass condition                                 | Notes                                |
| --------- | ----------------------- | ---------------------------------------------- | ------------------------------------ |
| **4 pts** | Frequency match         | FFT peaks equal (a,b) in every cell            | −1 pt per mismatch, cap at 0         |
| **2 pts** | Lobe / intercept counts | $N_x,N_y$ correct in ≥8/9 cells                | −0.5 pt for each failing cell        |
| **1 pt**  | Scale & centring        | 0.80–0.88 window range all cells               | subtract proportional to worst error |
| **1 pt**  | Hue mapping             | Mean hue error across grid < 6 °               |                                      |
| **2 pts** | Grid hygiene            | Gutters pure white (σ<3), axes present & ≤1 px | −1 pt per issue                      |