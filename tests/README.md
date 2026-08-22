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
