# Acceleration Helper Interface and Documentation Cleanup

## Objective

Make the acceleration-helper call chain readable at every function boundary
without changing the algorithm, evaluation order, histories, termination
decisions, or acceleration-off/on equivalence.

The cleanup replaces generic interface names such as `state`, `config`, and
`result` with phase-specific names, removes result structures that merely wrap
one or two logical values, and documents every input, output, and structure
field of the important acceleration helpers.

## Scope

Behavior-preserving changes are limited to:

- `tests/competitors/accelerated_bds_options.m`
- `tests/competitors/private/run_productive_direction_memory_phase.m`
- `tests/competitors/private/run_post_poll_acceleration_phase.m`
- `tests/competitors/private/remember_accelerated_bds_direction.m`
- `tests/competitors/private/insert_productive_direction_at_memory_front.m`
- `tests/competitors/private/try_accelerated_bds_extrapolation.m`
- `tests/competitors/private/set_accelerated_bds_options.m`
- `tests/competitors/private/get_accelerated_bds_default_constant.m`

Renames of the two leaf helpers may replace their old filenames. The
`get_auto_alpha_init.m` interface is explicitly out of scope pending agreement
with collaborators. The lean reference and `bds.m` remain unchanged and serve
as behavioral oracles.

## Invariants

Every stage must preserve all of the following:

1. No additional objective-function evaluation is introduced.
2. Productive directions are tried in the same order.
3. A newly admitted direction is normalized, checked for near parallel or
   antiparallel duplicates, subject to the same capacity rule, and inserted at
   the front.
4. A retained direction that succeeds is promoted to the front with the same
   stored step.
5. Pre-poll extrapolation performs at most two probes with the same doubling,
   budget, target, history, and invalid-value rules.
6. Post-poll pattern and momentum candidates retain their current ordering,
   duplicate-point suppression, acceptance rule, and momentum update.
7. The caller continues to own `terminate` and `exitflag` updates.
8. With all acceleration switches off, `accelerated_bds_options.m` remains
   equivalent to `bds.m`.
9. With all acceleration switches on, `accelerated_bds_options.m` remains
   equivalent to `lean_evolved_bds.m`.
10. Function-value and estimated-gradient stopping remain unchanged.

## Interface standard

Each important helper header must contain:

- the complete call syntax;
- a concise algorithm description;
- one definition for every input and output, including dimensions or scalar
  type where useful;
- every structure field read or written by the helper;
- ownership of mutable state and termination flags;
- evaluation-budget, history, invalid-value, and ordering guarantees relevant
  to that helper.

Structures are retained when they prevent a fragile interface with many
parallel mutable outputs. Their variables must identify the phase they belong
to. A structure that only wraps one or two logical outputs is not retained.

## Stage 0: baseline and scope lock

- [x] Inventory the acceleration-helper call chain and all generic interfaces.
- [x] Confirm that only the two phase helpers use the generic
  `[state, result]` interface.
- [x] Confirm the current gradient-stopping checks pass.
- [x] Confirm the current complete acceleration equivalence suite passes.
- [x] Confirm the current renamed front-insertion helper passes Code Analyzer.

Observed baseline:

```text
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
HELPER_CODE_ANALYZER_OK
BDS_ACCELERATION_EQUIVALENCE_OK
```

## Stage 1: pre-poll productive-direction phase

- [x] Replace generic `state`, `config`, and `result` names with
  phase-specific interface names.
- [x] Return the target-reached condition as a direct logical output instead
  of a one-field result structure.
- [x] Update the caller without changing the packed state fields or their
  pack/unpack order.
- [x] Rewrite the function header to document every argument, output, field,
  mutation, stopping condition, and evaluation-accounting rule.
- [x] Confirm the old generic pre-poll names have no remaining references.

Stage acceptance:

- Code Analyzer passes for the changed pre-poll files.
- Gradient-stopping, function-value-reference, and momentum regressions pass.
- The complete acceleration-off/on equivalence suite passes.

Observed Stage 1 results:

```text
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
PRE_POLL_STAGE_FOCUSED_OK
PRE_POLL_STAGE_EQUIVALENCE_OK
```

The pre-poll helper had no Code Analyzer diagnostics. The main solver retained
only its five pre-existing dynamic-history diagnostics outside the Stage 1
diff. Both synchronized files had identical local/server SHA-256 values after
the accepted run.

## Stage 2: post-poll pattern and momentum phase

- [x] Replace generic `state`, `config`, and `result` names with
  phase-specific interface names.
- [x] Return acceleration-succeeded and target-reached as direct logical
  outputs instead of a two-field result structure.
- [x] Update the caller while preserving the outer default value of
  `post_poll_acceleration_succeeded` when the phase is not entered.
- [x] Rewrite the function header to document every argument, output, field,
  mutation, candidate ordering, duplicate suppression, and evaluation rule.
- [x] Confirm the old generic post-poll names have no remaining references.

Stage acceptance:

- Code Analyzer passes for the changed post-poll files.
- Momentum-duplicate, function-value-reference, and gradient regressions pass.
- The complete acceleration-off/on equivalence suite passes.

Observed Stage 2 results:

```text
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
POST_POLL_STAGE_FOCUSED_OK
POST_POLL_STAGE_EQUIVALENCE_OK
```

The post-poll helper had no Code Analyzer diagnostics. The two synchronized
files had identical local/server SHA-256 values after the accepted run.

## Stage 3: productive-memory and extrapolation leaf helpers

- [x] Rename `remember_accelerated_bds_direction` to a name that describes
  admission into productive-direction memory.
- [x] Rename `try_accelerated_bds_extrapolation` to identify productive-
  direction extrapolation.
- [x] Replace abbreviated interface names such as `prod_memory`, `mem_size`,
  and `is_dup` with descriptive names.
- [x] Give the admission, front-insertion, and extrapolation helpers complete interface
  contracts.
- [x] Preserve the current duplicate threshold and every memory/extrapolation
  decision exactly; changing those mechanisms is out of scope.
- [x] Confirm the removed helper names have no remaining local or server
  references.

Stage acceptance:

- Code Analyzer introduces no new diagnostic in the changed leaf helpers or
  callers; any retained diagnostic is matched to the pre-change source.
- Focused acceleration, function-value, and gradient regressions pass.
- The complete acceleration-off/on equivalence suite passes.

Observed Stage 3 results:

```text
PREEXISTING_EXTRAPOLATION_AGROW_CONFIRMED
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
LEAF_HELPER_STAGE_FOCUSED_OK
LEAF_HELPER_STAGE_EQUIVALENCE_OK
```

The admission, front-insertion, and both phase helpers had no Code Analyzer
diagnostics. The extrapolation helper retained exactly the pre-change
diagnostic on dynamically appending an invalid point; the corresponding Git
baseline statement was `invalid_points = [invalid_points, xcand]`. No
suppression marker was added. Both removed helper files were absent on the
server, and all six synchronized files had identical local/server SHA-256
values after the accepted run.

## Stage 4: infrastructure documentation and static audit

- [x] Expand `set_accelerated_bds_options.m` documentation to define `options`,
  `n`, `x0`, the normalized output, and internal derived fields without
  duplicating the public option catalogue.
- [x] Expand `get_accelerated_bds_default_constant.m` documentation to define
  its input, output, historical role, and unknown-name behavior.
- [x] Confirm `get_auto_alpha_init.m` and its deferred interface are unchanged.
- [x] Inspect the complete interface/name diff for unrelated edits.

Stage acceptance:

- Relevant option/default unit tests pass.
- Code Analyzer reports no diagnostics introduced on changed lines.
- `git diff --check` passes.

Observed Stage 4 results:

```text
ACCELERATED_BDS_AUTO_ALPHA_INIT_OK
INFRASTRUCTURE_DOCUMENTATION_STAGE_OK
```

The default helper had no Code Analyzer diagnostics. The setter retained only
its two pre-existing allocation-probe diagnostics on executable lines 310 and
323, outside the documentation diff. `git diff --check` passed, active MATLAB
code contained none of the removed helper or generic phase-interface names,
and `get_auto_alpha_init.m` remained unchanged with SHA-256
`d134805c655295f511568de29e7dbea4add09216c110523721a3d8169269372a`.

## Stage 5: final acceptance

- [x] Run `verify_gradient_stopping_threshold`.
- [x] Run `verify_gradient_stop_no_extra_evaluations`.
- [x] Run `verify_gradient_estimate_validity`.
- [x] Run `verify_function_value_reference`.
- [x] Run `verify_bds_momentum_duplicate`.
- [x] Run the complete 2610-case `verify_bds_acceleration` gate.
- [x] Run Code Analyzer on every MATLAB file changed by this cleanup.
- [x] Confirm old function and generic phase-interface names are absent.
- [x] Run `git diff --check` and inspect the final name/content diff.
- [x] Confirm SHA-256 equality for every explicitly synchronized local/server
  file after all tests finish.

Acceptance: every checkbox is supported by an observed result, and the local
worktree contains no change outside the declared scope other than changes that
predated this checklist.

Observed Stage 5 results:

```text
FINAL_CODE_ANALYZER_BASELINE_OK
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
ACCELERATION_HELPER_FINAL_FOCUSED_OK
ACCELERATION_HELPER_FINAL_EQUIVALENCE_OK
```

The final equivalence gate covered 1350 acceleration-off cases against
`bds.m` and two sets of 630 acceleration-on cases against
`lean_evolved_bds.m`. Six checked MATLAB files had no Analyzer diagnostics.
The remaining 5 main-solver, 2 setter, and 1 extrapolation diagnostics matched
pre-existing lines outside the semantic interface changes. Active MATLAB code
contained none of the three removed helper names or the generic phase
interfaces. `git diff --check` passed, the final task-scope name/content diff
was inspected, all three old server helper files were absent, and all 10
explicitly synchronized files had matching local/server SHA-256 values after
the final MATLAB run.

## Stage 6: interface-comment alignment correction

The preceding documentation pass described every interface item but did not
match the flat, left-aligned parameter-table layout of
`accelerated_bds_options.m`. This stage corrects presentation only.

- [x] Start every input, output, and structure-field name at the same `%   `
  left boundary within its function header.
- [x] Put the first description text on the same line as its variable name.
- [x] Start every description at one fixed column within each function header
  and align all continuation lines to that column.
- [x] Do not indent structure fields; use the structure row and blank-line
  grouping to identify field ownership.
- [x] Reformat all seven headers introduced or expanded by this cleanup.
- [x] Confirm comment-stripped, nonblank MATLAB content is byte-for-byte
  unchanged in every reformatted file.
- [x] Run Code Analyzer, gradient-stopping regressions, and the complete
  acceleration-off/on equivalence gate.
- [x] Confirm final local/server SHA-256 equality and absence of old helper
  files on the server.

Stage acceptance: the seven interfaces can be scanned as flat two-column
tables matching `accelerated_bds_options.m`, all executable-content hashes are
unchanged, and all static and behavioral gates pass.

Observed static result: all seven comment-stripped executable-content hashes
matched their pre-formatting baselines, and `git diff --check` passed.

Observed MATLAB result:

```text
COMMENT_ALIGNMENT_CODE_ANALYZER_BASELINE_OK
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
COMMENT_ALIGNMENT_FOCUSED_REGRESSIONS_OK
acceleration-off-Algorithm-cbds OK
acceleration-off-Algorithm-pbds OK
acceleration-off-Algorithm-rbds OK
acceleration-off-Algorithm-pads OK
acceleration-off-Algorithm-ds OK
acceleration-on-default-vs-lean OK
acceleration-on-Algorithm-cbds-vs-lean OK
COMMENT_ALIGNMENT_FINAL_EQUIVALENCE_OK
```

The Code Analyzer counts matched the accepted Stage 5 baseline: six checked
files had no diagnostics, while the main solver retained five, the setter two,
and the extrapolation helper one pre-existing diagnostic. The complete gate
covered 1350 acceleration-off and 1260 acceleration-on cases.

Final synchronization result: all 10 explicitly synchronized files had equal
local/server SHA-256 values, and all three superseded server helper files were
absent. The checklist was synchronized once more after recording this result
and included in the final hash comparison.

## Execution rules

- Apply and validate one stage at a time.
- Force-sync only the explicit files needed by the current server test.
- Verify hashes before or after each accepted stage and again after the final
  MATLAB run.
- Do not delete or overwrite unrelated server-only experiment data.
- Stop at the first failed assertion, unexpected diff, or unexplained hash
  mismatch; diagnose it before proceeding.
- Do not commit or push unless explicitly requested.
