# Serial acceleration and additional termination

The production entry is `src/bds.m`. One main `for` advances one actual block
visit. `Algorithm` accepts `'cyclic'` or `'cbds'`, `'permuted'` or `'pbds'`,
`'random'` or `'rbds'` for randomized visits,
and `'ds'` uses one block. `Algorithm` is the sole visit-order option. Cyclic
visits advance directly through block indices; permuted visits draw a new
permutation each round. Randomized visits preserve the established default
exclusion of the preceding `num_blocks-1` visited blocks.

## Complete visits and acceleration

A complete visit covers every block at least once in consecutive visits.
At a given iteration, acceleration uses the latest start that still covers
every block. For extra stopping checks, BDS fixes a start and takes the first
end that covers every block. Both answers come from
`src/private/complete_visit_status.m` using the last visit index of each block.
At each visit BDS also saves the point from which it polled that block.

The pattern displacement is the current point after polling minus that saved
start point. It includes accepted accelerations from earlier visits. There is
no special first-cycle path. Every acceleration requires a complete window,
strict improvement in the current poll, and a pattern norm larger than the
largest step tolerance.

Each block stores a momentum vector. The candidate combines the saved vector
and the normalized pattern direction with weights 0.6 and 0.4. Search along the
candidate momentum first when its norm exceeds the largest step tolerance.
Then search along the pattern from the same point after polling. Keep the
best point found, and save the candidate momentum if the pattern search
accepts a point. The two searches are organized in `src/private/accelerate.m`. The public option `use_search_acceleration` controls both
searches together.

`src/private/extrapolate.m` considers factors 1, 2, 4, 8 and 16 from the same
base. It stops at the first rejection, target or budget. Identical points
reuse evaluations within the two searches. The history records new evaluations
only. Function values are compared through `eval_fun`.

## Additional termination checks

The first interval starts at iteration zero. As soon as every block has been
visited, BDS checks the applicable criteria and starts the next interval at
the following iteration. The main function records whether any
acceleration was accepted in the interval. Both additional criteria require
that none was accepted. Function values are recorded at every complete-visit
end, including intervals that are ineligible for stopping.

`src/private/check_additional_termination.m` contains both criteria, their
windows and the gradient reference selection. It performs no objective calls.
The software continues to accept `func_window_size=1`; the paper's discussion
of window sizes at least two is not a validation constraint.

A gradient estimate requires complete finite paired samples at a common
unchanged point and their actual polling steps before shrinkage. No polling
point can have been accepted during that complete visit. Repeated visits replace
the samples of the same block. A general basis uses the transposed linear solve.
The reference error and consistency checks apply only when choosing the fixed
reference. Only subsequent available estimates enter the gradient window.

Budget and target checks occur during evaluations; basic step stopping is
checked after block updates. An additional criterion completed on the last
allowed evaluation can supply the exit reason without another evaluation.
A reached target retains priority. `grad_iter` counts completed visits, whereas
`alpha_hist` records each round for cyclic/permuted visits and each visit for
randomized/direct search, with a terminating partial round included.

## Verification and historical results

Run `tests/run_bds_regression_suite.m`. The independent `serial_reference.m`
scans full histories backwards and does not call production helpers. The suite
checks general windows, the first-window gate, invalid evaluations, input and
output conventions, stopping references and windows, and frozen serial polling
with acceleration disabled. The dated refactoring record reports actual runs.

## Step sizes and reference documentation

The expansion default is 2 for every objective; explicit `expand` values remain
supported. `alpha_init='auto'` implements only the
standard coordinate blocks, using `max(abs(x0(i)),StepTolerance(i))` for a nonzero
coordinate and `max(1,StepTolerance(i))` for a zero coordinate. Other bases or
partitions require explicit numeric initial steps. General-basis polling and
gradient recovery remain available with such steps.

The detailed gradient-reference calibration is documented in
`src/private/check_additional_termination.m`. `lipschitz_constant` estimates a
problem property: a Hessian Lipschitz constant. Without verification of the
constant and the required assumptions, its error expression is heuristic.
The public help retains option meanings and defaults and refers to this helper
for the derivation. Initialization in `bds.m` is organized into named sections.
