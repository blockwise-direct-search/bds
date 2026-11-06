# BDS acceleration overview

## Production behavior

The default cyclic coordinate configuration uses the green C15 rolling MP
strategy (candidate 1, P0A1). Momentum is attempted before pattern; pattern is
a fallback only if momentum is unavailable or accepts no point. Both switches
remain independently optional. The extrapolation distances use factors 1, 2,
and 4, with the existing acceptance, duplicate suppression and evaluation rules.

Rolling is selected from resolved options: coordinate basis, one signed pair
per block in coordinate order, all blocks selected in sorted order, and zero
replacement delay. Other bases, partitions, random selection and simultaneous
batch updates retain the pre-integration batch MP behavior. Configuration
dispatch is deterministic and consumes no random numbers.

## Window and momentum state

Each cyclic visit overwrites its ring slot with the current polling update.
Summing the slots in their existing order gives the direction used for this
visit. Previous acceleration updates are included in the other slots.
Acceleration from the current visit is added afterward, for future windows.
There is no requirement for two successful polling directions.

Each block owns a momentum vector. From the second cycle onward, an improving
polling visit can update that block's momentum and run MP if the window norm
exceeds the step tolerance and evaluations remain.

The first cycle is a bootstrap, not an acceleration-free cycle: after polling
all blocks, the original batch MP is attempted along the cycle's net polling
update. Its momentum initializes the last block's momentum; its accepted
update enters that block's history slot. The other momenta remain zero.
This ordering matches the frozen C15 experiment, including floating-point
summation and addition order.

## Stopping and compatibility

Function-value history is recorded once per batch, which is once per complete
cycle for the default. Any accepted acceleration point anywhere in the batch
suppresses both additional termination checks for that batch. The original
function and gradient window parameters, reference selection, two-branch
thresholds, iteration limits and output history units are unchanged.
Budget, target and step-size exits retain their existing positions.

Gradient data remain separate from the acceleration window. This integration
does not replace the existing gradient estimator or broaden its validity
conditions. The full-cycle coordinate experiment is not a validation of
arbitrary sampled-block gradient estimates.

The interface names use_iteration_pattern_step and the existing output fields
are retained. No new user-facing tuning parameter is introduced. Disabling
both accelerations retains the existing non-accelerated path.

## Private interfaces

- inner_direct_search performs the existing block polling and returns its
  unchanged result interface.
- initialize_rolling_acceleration selects the supported path and allocates
  the ring slots and per-block momentum.
- run_rolling_acceleration records one poll, constructs its window direction
  and calls run_post_poll_acceleration_phase.
- finish_rolling_bootstrap transfers the first cycle's MP state.
- run_post_poll_acceleration_phase remains the common, unchanged numerical
  MP kernel; its historical argument iteration_step now also accepts a rolling
  window direction.
- eval_fun, estimate_gradient and get_gradient_error_bound remain in use.

## Execution loop

The main execution loop visits exactly one block per pass. The explicit
`batch` context contains its index, current position, selected block indices
and starting point/value. The three stages in `bds.m` are BEGIN BATCH,
VISIT ONE BLOCK and FINALIZE BATCH; there is no nested batch/visit loop.

Sequential visits commit the current point immediately and the default
configuration considers rolling MP before visiting the next block. Parallel
visits share the batch starting point and defer its update to finalization.
The word parallel describes this shared-base rule; this refactor does not
introduce actual worker-level parallel execution.

Block selection and its random draws occur only at batch initialization.
Histories, legacy batch MP and additional stopping remain at the same batch
boundaries, including existing partial-batch termination behavior. Public
history indices still count batches. Structural refactoring does not turn
the function or gradient stopping criteria into per-visit tests.

## Verification

Run run_bds_regression_suite from tests for maintained unit and compatibility
checks, including the explicit rolling-state tests in src/unit_test.m.

verify_bds_rolling_reference adds independent full-trace comparisons:
fixtures covers C15 MP with all four stopping combinations, small budgets,
targets, noise and evaluation failures, plus legacy non-default configurations.
manifest covers all 133 frozen S2MPJ problems with all four stopping modes,
using the paper's 500*N budget. These are correctness checks, not new tuning
experiments.

Frozen source files and private dependencies live in an isolated verification
directory, never in production src. The C15 oracle is selected as p0a1; only
its experimental instrumentation field is excluded from output comparison.
The legacy oracle is the unmodified production commit a70ab1cb. Older cyclic
MP oracles do not describe the new default and must not be relabeled as rolling
oracles.

See docs/development/BDS_ROLLING_MP_IMPLEMENTATION_20261106.md for the execution
record, source provenance and actual acceptance results.
