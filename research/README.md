# BDS research

This directory contains reproducible experiments and tuning studies that inform
BDS development but are not part of the production regression suite.

- `accelerated_bds_ablation/` records the acceleration-mechanism ablations.
- `accelerated_bds_dimension_comparison/` contains dimension-band comparisons.
- `auto_initial_step_size/` contains the automatic-step and stopping studies,
  including their versioned machine-readable evidence.
- `nbds/` contains exploratory nonmonotone-BDS diagnostics.
- `tuning/` contains the older general hyperparameter-tuning study.

Experiment drivers locate production code from `src/` and reuse maintained
profiling/oracle infrastructure from `tests/`. Generated run directories are
kept beside the relevant research project and excluded by `.gitignore`.
