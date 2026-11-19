# BDS option simplification, 2026-11-17

Completed after the serial refactor and restoration of detailed comments.
The implementation plan and verification evidence are retained in the adjacent
paper project:

- [Completed plan](../../../bds_paper/collaborator_feedback/solver_options_20261117/PLAN.md)
- [Acceptance record](../../../bds_paper/reproducibility/solver_options_20261117/README.md)

The expansion default is 2 for every objective, with explicit overrides retained.
The is_noisy option and duplicate batch scheduling options have been removed.
Algorithm selects the visit order; the established rbds exclusion rule remains.
Automatic initial steps are restricted to standard coordinate blocks. General
bases and grouped blocks still work with explicit positive initial steps.
The public help explains the problem assumptions behind lipschitz_constant;
the reference-calibration derivation is in check_additional_termination.m.
Initialization in bds.m is organized into named sections with detailed comments.

Verification passed: 13 source unit tests, 3,072 exact pre-change traces,
3,240 independent reference cases, 1,080 frozen serial polling cases, the full
maintained regression, and installed-source checks. All 29 MATLAB source files
match the server verification copy by SHA-256. Historical experiments and
manuscript figures were not replaced.
