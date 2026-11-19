# BDS tests

This directory contains maintained checks for the production solver. Research
experiments, tuning studies, and their recorded results live under
[`research/`](../research/README.md).

`bds_paper_options.m` supplies explicit paper configurations for reproduction
and verification. Add `src` and `tests` to the MATLAB path before using it;
see [paper reproduction settings](../docs/PAPER_REPRODUCTION.md). Ordinary
solver examples remain under `examples/` and do not require this helper.

Run the complete production regression gate from MATLAB with:

```matlab
addpath("tests")
run_bds_regression_suite
```

That entry point runs the source unit tests (including explicit extrapolation and stopping cases),
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
`verify_bds_unknown_options` checks that unsupported fields raise an error before any objective evaluation.
The standalone suite does not claim these external-reference
tests have run; see the dated execution record for actual results and commands.

Tests have two distinct responsibilities. `src/unit_test.m` exercises private
helpers using MATLAB's normal private visibility. Its extrapolation cases check
explicit expected points, histories, budget limits, invalid evaluations and
target flags without a frozen helper oracle. Solver equivalence
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

## Serial refactor verification

`verify_serial_refactor` uses an independent history-scanning coordinate solver
for 3,240 combinations of dimension, schedule, seed, switches, momentum decay,
budget and objective. It also checks forward coverage with repeated visits.
An optional baseline source directory enables 96 exact comparisons against the
pre-refactor serial solver with both accelerations and additional stops off.
`verify_serial_boundaries` checks the first-window polling gate, invalid values
and exceptions, target/budget edges, output switches, row inputs, general bases,
uneven partitions and explicit rejection of parallel requests.

Frozen off comparisons cover the four serial algorithms. Additional stopping
and gradient-history equivalence to old partial batches is intentionally not
asserted: these now follow general complete visits. Their dedicated tests
validate the revised behavior. Historical parallel-algorithm drivers require old source; concurrent independent
serial solver calls remain supported;
`pabds.m` is reserved for future work and has not been implemented.

## Option simplification, 2026-11-17

`verify_solver_options` checks removed-field errors before any objective call,
uniform expansion defaults and explicit expansion values. With a pre-change
source directory it also compares complete histories and outputs across all
four retained Algorithm choices, acceleration/stopping switches, seeds,
budgets, targets and failing objectives. `verify_bds_auto_alpha_init` checks
the coordinate formula, row inputs, scalar/vector tolerances, unsupported-auto
rejection and retained general-basis support with explicit initial steps.

The independent serial reference now uses the retained rbds exclusion rule.
The removed with-replacement/custom-batch interface is not silently remapped.
Cross-permutation rolling windows still exercise repeated blocks and windows
longer than the block count. General forward-coverage logic remains in the
solver, while the retained default schedules finish each complete visit after
one visit to every block. Historical TSFSB option structs remain frozen; their
current-production smoke counterparts remove `is_noisy` and explicitly supply
the historical DS initial step when the grouped auto case is no longer supported.
