# Shader Benchmark Report

**Model:** anthropic/claude-haiku-4.5  
**Generated:** 2025-12-27 15:21:54  
**Total Tests:** 1  
**Successful Renders:** 1  
**Scored Tests:** 1  

---

## Summary Statistics

### Average Scores by Category

| Category | Average Score |
|----------|---------------|
| Mathematical Accuracy | 28.0/100 |
| Visual Quality | 78.0/100 |
| Color Implementation | 33.0/100 |
| Geometric Completeness | 62.0/100 |
| Reference Elements | 32.0/100 |
| **Overall Average** | **46.6/100** |

### Performance Highlights

**Best Test:** Shader 0 (Total: 233/500)  
**Worst Test:** Shader 0 (Total: 233/500)  

---

## Detailed Test Results

### Test 1: Shader 0

**Test ID:** `000_geometric_cube`  
**Shader Files:** shader_0.wgsl  
**Execution Status:** ✅ Success  
**Image Generated:** ✅ Yes  
**Judge Scores:** ✅ Available  

#### Problem Prompt

> Axis-aligned cube, side = 2, centred at origin.
> 
> Rendering:
> - Wireframe style: edges 3 px midnight-blue (#003366); transparent faces α = 0.1 sky-blue
> - Hidden edges dashed
> - Camera: Elevated view from upper-right, looking down at cube corner (approx 45° elevation, 30° azimuth)
> - Perspective: Orthographic projection. Canvas 1800×1800
> 
> Deliverable: Outputs a single image.

#### Judge Scores

| Category | Score |
|----------|-------|
| Mathematical Accuracy | 28/100 |
| Visual Quality | 78/100 |
| Color Implementation | 33/100 |
| Geometric Completeness | 62/100 |
| Reference Elements | 32/100 |
| **Total** | **233/500** |
| **Average** | **46.6/100** |


#### Rendered Output

![Rendered Output](images/000_geometric_cube_result.png)

---

