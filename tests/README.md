# BDS tests

This directory contains maintained checks for the production solver. Research
experiments, tuning studies, and their recorded results live under
[`research/`](../research/README.md).

Run the complete production regression gate from MATLAB with:

```matlab
addpath("tests")
run_bds_regression_suite
```

That entry point runs the source unit tests (including 20 MP phase scenarios),
the standalone `test_*.m` tests, the default and stopping checks, and the full acceleration-off
equivalence comparison. GitHub Actions invokes the same entry
point through `bds_regression_test.yml`.

The old all-on lean/PM verifier is preserved under `archive/legacy_pm/`; it is
not an oracle for the new MP order. With the unmodified frozen MP directory on
the path, `verify_bds_mp_reference(results_directory, 'full')` runs `iseqiv` at
zero tolerance **and** compares complete objective traces and all outputs.
`verify_bds_mp_defaults(@c03_bds_mp, results_directory)` checks explicit switches
and stopping combinations. `verify_bds_mp_manifest` covers the frozen 133-problem
S2MPJ manifest. After retained removal, the frozen side explicitly receives
the historical disabled retained fields; candidate and reference options are
saved separately.
`verify_bds_removed_retained_options` checks legacy false/empty compatibility,
the capacity warning, and rejection of true before any objective evaluation.
The standalone suite does not claim these external-reference
tests have run; see the dated execution record for actual results and commands.

Tests have two distinct responsibilities. `src/unit_test.m` exercises private
helpers using MATLAB's normal private visibility. Its MP phase cases check
explicit expected points, complete states, histories, budget limits, invalid
evaluations and target flags, without a frozen phase oracle. Solver equivalence
verifiers under `tests/` call the public production and reference solver entries;
they do not call the production private phase. The server runner's `regression`
stage runs unit tests; its `smoke` and `strict` stages perform solver-level checks.

Batch `iseqiv` callers should set `noninteractive=true` and an existing
`failure_directory`. A mismatch saves evidence and throws an error instead of
entering `keyboard`. `verify_iseqiv_noninteractive_failure` deliberately throws
that error and must be launched as a separate expected-failure MATLAB process.

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
not installed. Historical TSFSB options are audited unchanged. Their retained-on
BDS setting is now explicitly rejected; current-production smoke checks remove
that legacy flag and exercise MP, not the historical retained experiment.
Current generic profiling labels (including `all-on`) likewise mean the two
remaining accelerations. Explicit memory-only labels raise an error. Use the
historical code and options together when reproducing old retained results.
