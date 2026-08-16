# Gradient-stopping single-threshold migration

Status: in progress.

## Objective

Replace the redundant two-branch estimated-gradient stopping condition by the
single reference-scaled condition

```text
G_j < grad_tol * max(1, G_ref)    for every entry G_j in the window,
```

where `G_ref` is initialized from the first reliable estimated gradient and
both `G_ref` and each `G_j` conservatively include the computed gradient error.
The strict inequality is part of the contract.

The final public tolerance is `grad_tol`, with default `1e-2`.
`grad_reference_relative_tol` is removed because it would duplicate
`grad_tol` after this migration.

## Mechanism

The recent-function-value reference and the gradient reference play different
roles. The function-value scale

```text
abs(fopt - reference_function_value)
```

is zero when its reference is initialized and then changes throughout the run.
Its two guarded thresholds protect a scale that starts at zero and may later
become very large. In contrast, `G_ref` is the magnitude of a gradient estimate
and is initialized only after a structurally valid estimate passes the
reference-reliability checks. It is then fixed. Consequently,
`max(1, G_ref)` supplies an absolute scale when `G_ref <= 1` and a relative
scale when `G_ref > 1`; a complementary `min` branch is unnecessary.

The resulting exit condition expresses reference-scaled stationarity. It does
not claim that a gradient satisfying the relative branch is necessarily small
in an unscaled absolute sense.

## Behavioral contracts

1. With all acceleration switches disabled, `accelerated_bds_options.m` and
   `src/bds.m` must agree under the same explicit termination options, including
   cases that activate estimated-gradient stopping.
2. With all acceleration switches enabled for CBDS,
   `accelerated_bds_options.m` and `lean_evolved_bds.m` must agree in both a
   triggering and a nontriggering estimated-gradient case.
3. Estimated-gradient stopping must not perform an objective evaluation solely
   for termination.
4. Exact zero, tiny finite, and very large finite gradient estimates remain
   structurally valid; estimates containing `NaN` or `Inf` remain invalid.
5. Recent-function-value stopping and momentum duplicate suppression remain
   unchanged.
6. `lean_evolved_bds_original.m`, `bds_tmp.m`, and files under `tests/misc`
   remain historical snapshots unless a separate archival step explicitly
   names them.

## Historical-result equivalence

The reported accelerated configuration used

```text
omega_g = 1e-6
rho     = 1e-2
```

in

```text
G < omega_g * min(1, G_ref)
or
G < rho     * max(1, G_ref).
```

For every nonnegative `G_ref`, the first threshold is strictly smaller than
the second. Replacing the pair by

```text
G < 1e-2 * max(1, G_ref)
```

therefore preserves every reported stopping decision, including pointwise
window decisions and strict-inequality boundary behavior. The accelerated
benchmark does not need to be rerun. Historical records must retain their
original parameterization and explain this exact mapping rather than claiming
that the new interface was used at the time.

## Execution rules

- Complete stages in order.
- Do not mark a checkbox from intention; record only an observed result.
- After an algorithmic stage, synchronize the explicitly changed files to the
  MATLAB server and run that stage's focused checks before the full gate.
- Stop at the first failed check and repair the current stage before proceeding.
- Preserve unrelated local changes in the existing dirty worktree.
- Do not commit or push as part of this migration.

## Stage 0: baseline and inventory

- [x] Record the local worktree state.
- [x] Confirm the server copy of every already-modified solver/test file matches
      the local copy before taking the baseline.
- [x] Run `verify_bds_acceleration`.
- [x] Run `verify_gradient_stop_no_extra_evaluations`.
- [x] Run `verify_gradient_estimate_validity`.
- [x] Run `verify_function_value_reference`.
- [x] Run `verify_bds_momentum_duplicate`.

Acceptance: all existing markers are present and no baseline mismatch remains.

Observed baseline on the MATLAB server:

```text
BDS_ACCELERATION_EQUIVALENCE_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
```

The local worktree contained only this untracked migration document. The
server Git checkout had an older `HEAD` and retained historical untracked
experiment data, so the baseline used a non-deleting synchronization of local
tracked files. SHA-256 checks matched for all solver and regression files used
by these gates. No server-only result file was removed.

## Stage 1: behavior-preserving caller migration

- [x] Change active final accelerated configurations from the redundant pair
      `grad_tol=1e-6`, `grad_reference_relative_tol=1e-2` to the transitional
      equal pair `grad_tol=1e-2`, `grad_reference_relative_tol=1e-2`.
- [x] Keep historical experiment records factually unchanged.
- [x] Verify that the accelerated final criterion is unchanged because the
      `max` branch still determines every decision.
- [x] Run the focused gradient checks and the full acceleration equivalence
      gate on the server.

Acceptance: all gates remain green before the solver formula changes.

Observed Stage 1 results:

```text
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
BDS_ACCELERATION_EQUIVALENCE_OK
```

During the first focused run, the server copy of
`accelerated_bds_options.m` was externally replaced by an older version even
though it matched the local SHA-256 at baseline. The mismatch was diagnosed by
hash and a read-only diff, the complete validation file set was force-synced
without deleting server data, and both focused and full gates then passed.
Post-run hashes confirmed that the synchronized files did not drift during the
accepted run.

## Stage 2: unified implementation

- [x] Give `bds.m`, `accelerated_bds_options.m`, and `lean_evolved_bds.m` the
      same reliable-reference state transitions.
- [x] Use `norm(grad) + grad_error` for both the fixed reference and subsequent
      window entries.
- [x] Replace the two-branch decision in all three implementations by
      `all(norm_grad_window < grad_tol * max(1, reference_grad_norm))`.
- [x] Retain the existing rule that the reference-setting estimate is not also
      inserted into the stopping window.
- [x] Add solver-level tests for `G_ref < 1`, `G_ref = 1`, `G_ref > 1`, strict
      equality, and a window longer than one.
- [x] Extend acceleration-off equivalence coverage to estimated-gradient
      stopping options.

Acceptance: threshold tests, gradient checks, and full off/on equivalence pass.

Observed Stage 2 results:

```text
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
BDS_DEFAULT_CONSTANT_TEST_OK
BDS_ACCELERATION_EQUIVALENCE_OK
```

The acceleration-off `iseqiv` range now includes `ir=15:17`, so the accepted
full gate exercises estimated-gradient options rather than relying only on the
former zero-gradient special case. Post-run SHA-256 values matched for all
three implementations, the BDS option files, and the new threshold test.

The complete pre-existing `src/unit_test.m` suite also ran. Its affected
default-constant test passed, while the unrelated `get_auto_alpha_init_test`
retained three exact-equality failures at an absolute difference of
`8.470329472543e-22`. This migration does not alter that separate auto-alpha
floating-point test issue.

## Stage 3: public-interface cleanup

- [x] Set the `grad_tol` default to `1e-2` in both option systems and lean.
- [x] Remove `grad_reference_relative_tol` from the accelerated solver's help,
      defaults, validation, implementation, and active callers.
- [x] Keep any required legacy-name conversion confined to experimental result
      parsing; do not retain a solver compatibility alias.
- [x] Confirm repository search finds the removed option only in explicitly
      historical records, this migration record, and the guards/tests that
      verify the removed option is rejected rather than silently ignored.

Acceptance: option/unit tests, focused checks, and full equivalence pass.

Observed Stage 3 results:

```text
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
BDS_DEFAULT_CONSTANT_TEST_OK
BDS_ACCELERATION_EQUIVALENCE_OK
```

The accelerated and lean option entry points now reject the removed field
explicitly. BDS rejects it through its existing unknown-field validation. The
historical `-grs...` solver-name suffix is converted only inside
`profile_optiprofiler.m` to the effective single `grad_tol`; no solver accepts
or reconstructs the removed two-option interface.

## Stage 4: workflow and documentation cleanup

- [x] Remove obsolete gradient/profile GitHub workflows selected by the
      inventory. Workflow deletion is a separate, recoverable Git change.
- [x] Mark issue 3 in `TERMINATION_CODE_ISSUES.md` resolved.
- [x] Update active overview, README, and final-results descriptions.
- [x] Preserve historical numerical claims and document the exact old-to-new
      parameter mapping.

Acceptance: no active documentation describes two effective gradient
thresholds, and no retained workflow silently reuses a historical benchmark ID
with changed semantics.

Observed Stage 4 results:

- Deleted exactly 18 workflows whose commands fixed the obsolete
  `grad_tol=1e-6` plus reference-relative `1e-2` configuration; the 102
  unrelated workflows remain.
- A repository search found no retained workflow containing the removed field,
  the obsolete parameter assignment, or the corresponding historical workflow
  ID.
- Active documentation now presents the single threshold, while historical
  experiment records preserve their original numbers and state the exact
  equivalence to current `grad_tol=1e-2`.
- Remaining occurrences of the removed field are limited to migration/history
  records, rejection guards/tests, and the pre-existing `bds_tmp.m` snapshot.

## Stage 5: final acceptance

- [x] Run the dedicated gradient-stopping contract checks.
- [x] Run the complete acceleration-off/on equivalence suite.
- [x] Run function-value, gradient-validity, no-extra-evaluation, and momentum
      regression checks.
- [x] Run relevant MATLAB unit tests and Code Analyzer.
- [x] Run `git diff --check` and inspect the complete diff.
- [x] Confirm SHA-256 equality between every synchronized local and server file.

Acceptance: every checkbox above is supported by an observed passing result;
the local worktree contains no unintended file, interface, or workflow change.

Observed Stage 5 results so far:

```text
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
FOCUSED_FINAL_ACCEPTANCE_OK
BDS_ACCELERATION_EQUIVALENCE_OK
```

The focused unit selection `get_default_constant_test` passed. Code Analyzer
reported no diagnostics in the new threshold test, lean implementation,
default-constant functions, validators, or any changed gradient-stopping line.
Its 15 diagnostics are on pre-existing dynamic history growth, allocation
probes, and one `numel(...) == 1` line outside this diff. `git diff --check`
passed, the complete name/content diff was inspected, and repository searches
confirmed the intended interface and workflow cleanup. The final post-checklist
hash comparison was then performed.

All 21 explicitly synchronized files had identical local and server SHA-256
values after the final acceptance runs.
