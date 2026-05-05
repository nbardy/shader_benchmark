# Frontier Problem List

20 frontier-level shader benchmark candidates ranked by tie-breaks favoring
benchmark discrimination, novelty, and evaluability.

Each row corresponds to a directory under `problems/base_set/<slug>/` with
`category.txt = "Frontier"`. Status column shows whether `request.txt` +
`critic.txt` have been filled by the science pass yet. See
`problems/FRONTIER_PROMPT_FORMAT.md` for the schema.

| Rank | Score | Status | Problem | Slug | Why |
|---|---|---|---|---|---|
| 1  | 93 | ✅ filled | Topological quantum-code defect braiding             | `topological_quantum_code_defect_braiding`     | Frontier topology + temporal structure; exposes whether a model understands constraints over time |
| 2  | 92 | ✅ filled | Mean-curvature flow with singularity surgery         | `mean_curvature_flow_surgery`                  | Hard geometry + animation, clear visual failure modes |
| 3  | 92 | ✅ filled | Minimal surfaces spanning changing boundary knots    | `minimal_surface_knot_boundaries`              | Beautiful, precise, difficult; tests geometry + rendering |
| 4  | 91 | ✅ filled | Quantum-error-correction threshold phase diagram     | `qec_threshold_phase_diagram`                  | Scientific content + scalability + evaluability |
| 5  | 91 | ✅ filled | Optimal transport between shapes as mass-flow tubes  | `optimal_transport_mass_flow_tubes`            | Highly visual, mathematically grounded, qualitative-judge friendly |
| 6  | 91 | ✅ filled | 3D spinodal decomposition                            | `spinodal_decomposition_3d`                    | Simulation/rendering with measurable morphology |
| 7  | 90 | ✅ filled | Coxeter-group reflection kaleidoscope                | `coxeter_reflection_kaleidoscope`              | Beauty + rigor + parameterized difficulty |
| 8  | 90 | ✅ filled | Braid-group word reduction as ribbon tightening      | `braid_word_reduction_ribbons`                 | "Looks easy, is hard" — visually intuitive but mathematically nontrivial |
| 9  | 90 | ✅ filled | Ocean eddy Lagrangian coherent structures            | `ocean_eddy_lcs`                               | Applied-science visualization with motion + uncertainty + flow geometry |
| 10 | 90 | ✅ filled | Earthquake fault slip and seismic wavefronts         | `earthquake_fault_slip_wavefronts`             | Spatiotemporal viz with clear structure and evaluation hooks |
| 11 | 89 | ✅ filled | Protein-folding energy landscape                     | `protein_folding_energy_landscape`             | Frontier-ish, scientifically meaningful, naturally interactive |
| 12 | 89 | ✅ filled | Navier–Stokes vortex reconnection                    | `navier_stokes_vortex_reconnection`            | Brutal test of topology + simulation intuition + 3D rendering |
| 13 | 89 | ✅ filled | Error-correcting-code decoding landscape             | `error_correcting_code_decoding_landscape`     | Tests abstract-to-visual translation in a technical domain |
| 14 | 89 | ✅ filled | Differentiable-rendering ambiguity landscape         | `differentiable_rendering_ambiguity_landscape` | Relevant to modern AI/graphics; conceptually deep |
| 15 | 89 | ✅ filled | Eigenfunctions on fractal drums                      | `fractal_drum_eigenfunctions`                  | Precise, scalable, beautiful, surprisingly diagnostic |
| 16 | 89 | ✅ filled | Riemann-surface branch cuts as covering sheets       | `riemann_surface_covering_sheets`              | Tests complex analysis + topology + projection + visual clarity |
| 17 | 89 | ✅ filled | Reaction–diffusion on nonorientable surfaces         | `reaction_diffusion_nonorientable_surfaces`    | Striking, parameterizable, requires real geometric consistency |
| 18 | 89 | ✅ filled | Polyrhythm phase torus                               | `polyrhythm_phase_torus`                       | Unusual, multimodal-adjacent, highly visual |
| 19 | 89 | ✅ filled | Crystal dislocation network under stress             | `crystal_dislocation_network`                  | Applied physics with topology + dynamics |
| 20 | 89 | ✅ filled | Cellular-Potts tissue folding                        | `cellular_potts_tissue_folding`                | Biologically meaningful, visually compelling, simulation-heavy |

Prior `#` column from the source ranking is not preserved here — it was an
external ranking ID from a separate evaluation pass.

## Slug-rename notes

The science pass refined some slugs from my originals to keep dir names
shorter and more idiomatic. Old empty dirs were removed; new dirs match
the slugs in the table above. If any external file references the old
slugs, update:

```
mean_curvature_flow_singularity_surgery   →   mean_curvature_flow_surgery
minimal_surfaces_changing_knot_boundary   →   minimal_surface_knot_boundaries
braid_word_ribbon_reduction               →   braid_word_reduction_ribbons
ocean_eddy_lagrangian_coherent_structures →   ocean_eddy_lcs
earthquake_fault_slip_seismic_wavefronts  →   earthquake_fault_slip_wavefronts
reaction_diffusion_nonorientable          →   reaction_diffusion_nonorientable_surfaces
crystal_dislocation_network_stress        →   crystal_dislocation_network
```

**One slug-collision rename was applied during import:** the science pass
named #16 `riemann_surface_branch_cuts`, but a *different and simpler*
problem with that exact slug already exists in `base_set/` (single branch
cut along the negative real axis, classified under Historical
Mathematics). To avoid clobbering it, the new frontier problem (which has
four branch points + monodromy trails) was placed at slug
`riemann_surface_covering_sheets` instead. Both problems coexist — the
classical one as historical-math, the frontier one as Frontier.
