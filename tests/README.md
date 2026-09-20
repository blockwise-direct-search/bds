# BDS tests

This directory contains maintained checks for the production solver. Research
experiments, tuning studies, and their recorded results live under
[`research/`](../research/README.md).

Run the complete production regression gate from MATLAB with:

```matlab
addpath("tests")
run_bds_regression_suite
```

That entry point runs the source unit tests, the standalone `test_*.m` tests,
the focused acceleration and stopping checks, and the full acceleration-off and
acceleration-on equivalence comparison. GitHub Actions invokes the same entry
point through `bds_regression_test.yml`.

The remaining top-level drivers cover stress, recursion, parallel execution,
compatibility, and profiling. `competitors/` holds independent regression
oracles and maintained comparison wrappers; `private/` holds test-only helpers;
`tools/` contains small maintained result-processing utilities.

The suite also runs three verifiers for the ten-solver full-set benchmark
(TSFSB) infrastructure in `research/ten_solver_full_set_benchmark/`:
`verify_lam_paper_exact` checks the paper-exact LAM port in
`competitors/lam_paper_exact.m`, `verify_tsfsb_workflow_contracts` checks the
frozen benchmark specification and runner contracts (no external solver
required), and `verify_tsfsb_solver_configurations` checks the fixed solver
option structs and runs smoke executions, skipping external solvers that are
not installed.
