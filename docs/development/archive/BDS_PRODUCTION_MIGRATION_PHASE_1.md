# BDS production migration and repository cleanup: Phase 1

Status: Phase 1 complete; ready for a separately authorized Phase 2.

## Objective

Complete all work required on `rebuilt_code_style` before any integration into
`main`:

1. Promote the implementation currently developed as
   `tests/competitors/accelerated_bds_options.m` to the public production entry
   point `src/bds.m`.
2. Move the acceleration helpers into `src/private` and integrate the option,
   default, validation, and automatic-step infrastructure under production BDS
   names.
3. Preserve independently testable references for both the pre-acceleration
   BDS behavior and the fully accelerated lean behavior.
4. Redirect active tests and scripts to the new production entry point and
   remove obsolete duplicate implementations.
5. Audit the repository and either retain, archive, delete, or explicitly defer
   every obsolete-looking file based on evidence.
6. Finish with a clean, documented, server-validated branch that is ready for a
   separate `main`-integration phase.

Replacing the filename alone is not sufficient. Phase 1 is complete only when
the production interface, private implementation, tests, documentation, and
repository layout all describe the same solver.

## Scope boundary

This checklist covers Phase 1 only. It does **not** authorize or include:

- switching to, merging into, rebasing, or pushing `main`;
- pushing `rebuilt_code_style` or creating a pull request;
- deleting server-only experiment results;
- changing the deferred four-argument `get_auto_alpha_init` interface;
- changing acceleration, stopping, polling, history, or evaluation-accounting
  mechanisms merely because the production migration exposes an opportunity to
  redesign them.

Any algorithmic change discovered to be desirable during the migration must be
recorded separately and approved before it is mixed into this work.

## Planning snapshot

This document was created on 2026-08-21 from a clean local worktree with the
following locally known Git state:

```text
branch                         rebuilt_code_style
HEAD                           7d30874056d0
origin/rebuilt_code_style      7d30874056d0
main                           81c3ef7bbb90
main...rebuilt_code_style      0 behind, 24 ahead
```

These values are planning evidence, not authorization to integrate. They must
be refreshed before Phase 2 because remote references may change.

## Behavioral oracles

The migration uses three distinct oracles. They must remain independent; one
implementation must not be compared with a wrapper that simply calls itself.

1. **Frozen non-accelerated reference**
   A fresh snapshot of the current `src/bds.m` is created before it is replaced.
   Its option/default/validation/automatic-step dependencies that will change
   during productionization are also frozen under reference-specific names.
   Unchanged shared algorithm helpers may remain shared only after their hashes
   are recorded and they are excluded from the migration diff.
2. **Pre-promotion accelerated implementation**
   `accelerated_bds_options.m` is retained temporarily while the new production
   files are assembled. It verifies that copying, renaming, and integrating the
   implementation did not change its behavior. It is removed only after this
   temporary migration gate passes and all active callers have moved to `bds`.
3. **Fully accelerated lean reference**
   `lean_evolved_bds.m` remains an independent regression oracle for the
   all-acceleration-on CBDS path. It must not be rewritten to call production
   `bds`.

The existing `bds_tmp.m` is not accepted as the frozen non-accelerated oracle:
it is an older implementation with different helper calls and behavior.

## Required equivalence contracts

The final production solver must satisfy all three contracts:

1. During migration, new `src/bds.m` matches the retained
   `accelerated_bds_options.m` under the same options.
2. With all acceleration switches disabled, new `src/bds.m` matches the fresh
   frozen non-accelerated reference.
3. With all acceleration switches enabled for the supported CBDS paths, new
   `src/bds.m` matches `lean_evolved_bds.m`.

Comparisons cover `xopt`, `fopt`, `exitflag`, evaluation counts, histories,
termination behavior, invalid objective values, deterministic seeded behavior,
and the presence and meaning of output fields. The acceleration-off gate must
not compare `bds` with itself after the promotion.

## Execution rules

- Complete stages in order; never begin Phase 2 while any Phase 1 item is open.
- Mark a checkbox only from an observed result and record that result below the
  relevant stage.
- Take a baseline before modifying a solver or deleting a file.
- Stop at the first failed check, diagnose it, and repair the current stage
  before continuing.
- Synchronize only the declared validation files to the MATLAB server. Do not
  use a deleting synchronization against server experiment data.
- Compare local and server hashes for every explicitly synchronized solver,
  helper, and regression file before accepting a server run.
- Keep unrelated worktree changes intact if any appear during execution.
- Use repository-wide reference searches before and after every rename or
  deletion.
- Do not use `#ok` suppressions to manufacture a clean Code Analyzer result.
- Do not archive a file merely to avoid deciding whether it is useful. Archive
  only unique historical material with continuing research or explanatory
  value; delete reproducible or redundant artifacts when deletion is approved.
- Git commits and all pushes remain separate, explicit actions. The intended
  commit boundaries may be prepared and reviewed during this phase.

## Stage 0: baseline, inventory, and decision lock

- [x] Record `git status`, the current branch, local `HEAD`, relevant remote
      tracking references, and the complete `main...rebuilt_code_style` diff.
- [x] Record the SHA-256 hashes of the current production, accelerated, and lean
      solver files and every private helper in their active call chains.
- [x] Inventory every active MATLAB and documentation reference to
      `accelerated_bds_options`, `bds`, `lean_evolved_bds`, and historical BDS
      copies.
- [x] Run the complete pre-migration server baseline before modifying code.
- [x] Confirm whether production adopts the accelerated implementation's public
      defaults or preserves selected old BDS defaults. At minimum, explicitly
      decide:
      - `MaxFunctionEvaluations`: accelerated `200*n` versus old `500*n`;
      - noiseless `expand`: accelerated `2.0` versus old `1.8`;
      - the defaults of `use_productive_direction_memory`,
        `use_iteration_pattern_step`, and `use_momentum_extrapolation`.
- [x] Confirm that the experimental name `accelerated_bds_options` needs no
      compatibility wrapper after active repository callers are migrated.
- [x] Produce the initial repository-cleanup inventory without moving or
      deleting files.

Final public-default decision: use `500*n` for
`MaxFunctionEvaluations`, `2.0` for noiseless `expand`, and enable all
three acceleration mechanisms by default. No
`accelerated_bds_options` compatibility wrapper is retained.

Stage acceptance:

- All baseline gates pass on the server.
- Every public-default difference is explicit.
- Every candidate cleanup path has an initial classification; no cleanup has
  yet been performed.

Observed Stage 0 results:

```text
Branch/HEAD/origin: rebuilt_code_style at 7d30874056d0 (0 behind, 24 ahead of main).
Baseline solver SHA-256:
  src/bds.m                                      3b0a88800ed81b9694f0823948ae389456462f57a76b9bf927b3d0368a214d0e
  tests/competitors/accelerated_bds_options.m   93513375d1c1779feaeb3b2c1cb5c166db1b2e31fbad982325ea07f18e1fa516
  tests/competitors/lean_evolved_bds.m          58f90b2308a1927040618570ca8d00ac99fb1c502c9aff8c3898e3028e90e66a
All pre-migration equivalence and focused stopping gates passed on MATLAB R2026a.
Final defaults locked: 500*n, expand=2.0, all three acceleration switches true.
```

## Stage 1: freeze independent references

- [x] Create a clearly named snapshot of the current non-accelerated
      `src/bds.m`, for example
      `tests/competitors/bds_without_acceleration_reference.m`.
- [x] Give the snapshot its own reference-specific option setter, default
      provider, validator, and automatic-step helper wherever production files
      will change. Do not let the oracle silently start using the new production
      option semantics.
- [x] Record which remaining algorithm helpers are intentionally shared and
      verify that they are byte-identical across the relevant paths.
- [x] Add or adapt a focused test proving that the frozen reference matches the
      current production `bds` before replacement.
- [x] Confirm `lean_evolved_bds.m` remains independent and record its hash.
- [x] Confirm historical files such as `bds_tmp.m` and
      `lean_evolved_bds_original.m` have not been substituted for either oracle.
- [x] Run the full baseline again after adding the references.

Stage acceptance:

- Both behavioral oracles execute independently.
- The new frozen non-accelerated reference matches the still-current production
  `bds` before replacement.
- Adding reference files changes no existing solver result.

Observed Stage 1 results:

```text
Created bds_without_acceleration_reference.m and five reference-specific option,
default, validation, automatic-step, and printing dependencies.
The frozen reference matched the then-current production bds before replacement.
lean_evolved_bds remained an independent implementation; bds_tmp was rejected as
an oracle.
```

## Stage 2: productionize the accelerated implementation

- [x] Replace the body and public help of `src/bds.m` with the reviewed
      accelerated implementation under the production function name `bds`.
- [x] Move the following acceleration helpers into `src/private` with their
      reviewed names and documentation:
      - `admit_productive_direction_to_memory.m`;
      - `insert_productive_direction_at_memory_front.m`;
      - `run_productive_direction_memory_phase.m`;
      - `run_post_poll_acceleration_phase.m`;
      - `try_productive_direction_extrapolation.m`.
- [x] Integrate `set_accelerated_bds_options.m` into the production
      `src/private/set_options.m` rather than retaining an accelerated-specific
      production name.
- [x] Integrate `get_accelerated_bds_default_constant.m` into
      `src/private/get_default_constant.m`.
- [x] Integrate the reviewed automatic-step implementation into
      `src/private/get_auto_alpha_init.m` while preserving its existing
      four-argument interface pending collaborator agreement.
- [x] Replace experimental error/warning identifiers and help references with
      production BDS identifiers.
- [x] Verify that all public options are validated, defaulted, documented, and
      consumed exactly once by the intended implementation.
- [x] Confirm no accidental algorithmic change, new objective evaluation, or
      output-schema drift entered through renaming or file movement.
- [x] Run Code Analyzer on every changed production MATLAB file and inspect each
      diagnostic manually.

Stage acceptance:

- Production `bds` runs without relying on an accelerated-specific private
  setter or default provider.
- The temporary new-`bds` versus pre-promotion-accelerated gate passes.
- Relevant focused stopping and acceleration tests pass on the server.

Observed Stage 2 results:

```text
Promoted the reviewed accelerated implementation to src/bds.m and moved five
acceleration helpers into src/private. Productionized set_options,
get_default_constant, and get_auto_alpha_init while retaining the four-argument
automatic-step interface. The temporary production-versus-pre-promotion gate
passed. Initial production Code Analyzer review found only inherited AGROW and
NASGU performance diagnostics.
```

## Stage 3: re-anchor permanent regression tests

- [x] Rewrite `verify_bds_acceleration.m` so its acceleration-off comparison is
      new `bds` versus the frozen non-accelerated reference, never new `bds`
      versus itself.
- [x] Preserve the existing five-algorithm acceleration-off coverage for CBDS,
      PBDS, RBDS, PADS, and DS.
- [x] Preserve both all-on CBDS comparisons against `lean_evolved_bds.m`:
      default algorithm selection and explicit `Algorithm="cbds"`.
- [x] Preserve the current 1350 off, 630 on-default, and 630 on-explicit cases,
      or document and approve any deliberate change to those counts.
- [x] Add a temporary migration-equivalence test comparing new `bds` with the
      retained `accelerated_bds_options.m` until the latter is removed.
- [x] Ensure default-option tests directly exercise the Stage 0 default
      decision rather than relying only on explicit test options.
- [x] Exercise triggering and nontriggering function-value and estimated-
      gradient stopping cases through the new production entry point.
- [x] Confirm no test oracle calls production `bds` internally.

Stage acceptance:

- The permanent off/on tests remain independent and meaningful.
- The temporary migration-equivalence gate and all permanent gates pass.
- Default behavior is covered explicitly.

Observed Stage 3 results:

```text
Permanent acceleration gate re-anchored to independent references:
  acceleration off: 1350 cases over cbds/pbds/rbds/pads/ds;
  acceleration on, default CBDS entry: 630 cases;
  acceleration on, explicit Algorithm="cbds": 630 cases.
Focused function-value, estimated-gradient, evaluation-accounting, momentum,
automatic-step, and default-option tests run through production bds.
```

## Stage 4: migrate callers and remove duplicate accelerated entry points

- [x] Redirect every active MATLAB script and test that calls
      `accelerated_bds_options` to production `bds`.
- [x] Update solver labels, paths, setup code, and test messages so they do not
      imply that acceleration is available only through a competitor file.
- [x] Decide historical documentation references individually; preserve a
      historical name only when it describes what was actually run.
- [x] Run the temporary direct migration-equivalence gate one final time.
- [x] Remove `accelerated_bds_options.m` after all active callers are migrated.
- [x] Remove its duplicate accelerated-specific setter/default files and any
      private symlinks made obsolete by productionization.
- [x] Remove the temporary migration-equivalence test that can no longer provide
      an independent oracle; retain the permanent off/on gates.
- [x] Confirm repository search finds no active executable reference to the
      removed entry point or private infrastructure.

Stage acceptance:

- `bds` is the only active public BDS solver entry point.
- The frozen non-accelerated and lean files remain test-only independent
  references.
- All permanent regression gates pass after duplicate removal.

Observed Stage 4 results:

```text
All active accelerated solver callers now use production bds. The duplicate
accelerated_bds_options entry point, its duplicate private infrastructure, and
the temporary migration gate were removed only after their final equivalence
run. Repository search finds no active executable dependency on the removed
entry point.
```

## Stage 5: public documentation and installation surface

- [x] Update `README.md` near the user-facing introduction to state that `bds`
      includes:
      - productive-direction memory before regular polling;
      - an iteration-pattern step after successful polling;
      - momentum-direction extrapolation after polling.
- [x] State that the two post-poll mechanisms share the documented factor
      sequence and explain how users enable or disable each acceleration.
- [x] Document the final default policy and provide a short production `bds`
      example.
- [x] Ensure `help bds` documents all acceleration options, important state,
      stopping behavior, outputs, and defaults under production terminology.
- [x] Update current overview and test documentation to reference production
      `bds`; retain historical names only in clearly historical records.
- [x] Check installation/setup code exposes `src/bds.m` and does not require the
      `tests/competitors` directory.
- [x] Run a clean-path smoke test using `setup`, `which bds`, `help bds`, and a
      small solve.

Stage acceptance:

- A first-time visitor can discover the accelerated production behavior from
  the README and `help bds` without reading test files.
- Installed production BDS runs without competitor paths.

Observed Stage 5 results:

```text
README and help bds now expose all three acceleration mechanisms, shared
post-poll factors 1/2/4, independent switches, 500*n, and expand=2.0.
A restoredefaultpath/setup/which/help/simple-solve smoke test resolved the
isolated src/bds.m and passed with BDS_INSTALLATION_SMOKE_OK.
```

## Stage 6: repository-wide cleanup

Perform cleanup only after the final production/test layout is known. Record
each reviewed path in the audit table below with exactly one disposition:

- **Keep:** active production, regression, reproducibility, or current
  documentation value.
- **Archive:** unique historical/research value that should remain accessible
  but is not part of the active surface.
- **Delete:** redundant, obsolete, generated, or reproducible material with no
  continuing repository value.
- **Defer:** a collaborator or external fact is required; state the owner and
  the precise unanswered question.

Audit categories:

- [x] Production source and private helpers.
- [x] Current regression and unit tests.
- [x] Competitor/reference solvers and their private helpers or symlinks.
- [x] Experiment drivers, benchmark launchers, and plotting scripts.
- [x] Markdown plans, completed migration records, overviews, and result notes.
- [x] Generated `.mat` files and other binary results.
- [x] GitHub workflows, including the workflow deletions already present
      relative to `main`.
- [x] Legacy, temporary, original, backup, and `_tmp` files, including
      `bds_tmp.m`, `lean_evolved_bds_original.m`, and files under `tests/misc`.
- [x] Empty directories, broken symlinks, duplicate setup logic, and stale path
      references left after the production migration.
- [x] Untracked and ignored files that could affect tests or packaging.

Cleanup execution:

- [x] Complete the audit table before the first deletion or archival move.
- [x] Execute approved changes in small, reviewable batches by category.
- [x] Before each deletion, search code, workflows, and documentation for all
      references and record why Git history is or is not sufficient recovery.
- [x] After each batch, run `git diff --check`, broken-link/reference checks,
      and the tests affected by that category.
- [x] Do not rewrite historical numerical claims to make them look as if they
      were generated by the new production interface.
- [x] Do not delete server-only data while mirroring repository cleanup.
- [x] Inspect the final repository tree manually for discoverability and
      duplication.

Cleanup audit table:

| Path or group | Evidence/references | Disposition | Planned action | Validation |
| --- | --- | --- | --- | --- |
| Production `src/bds.m` and private helpers | Active call graph and passing production tests | Keep | Promote acceleration helpers; remove orphan `validate_options.m` | Focused, unit, equivalence, analyzer, install smoke |
| Independent oracle layer | Permanent off/on and stopping regressions | Keep | Freeze old BDS dependencies; retain lean current/original/legacy references | 2610 cases plus focused regressions |
| Duplicate accelerated implementation | All active callers migrated; temporary gate already passed | Delete | Remove entry point and duplicate private files | Fresh post-removal server mirror passed |
| Current experiment drivers and 19 `.mat` result files | Active benchmark/reproducibility references | Keep | Migrate solver calls/labels; retain numerical evidence | Reference search and analyzer |
| Completed/stale migration notes | Superseded by current overview, deferred-review note, and this record | Delete/consolidate | Delete seven stale notes; add two current notes | Documentation/reference search |
| Temporary, backup, generated, and broken-link artifacts | No callers; duplicate or machine-generated content | Delete | Remove `*_tmp`, `*_bak`, `.DS_Store`, `.pyc`, stale copies, and broken symlinks | Reference search, broken-link scan, diff check |
| GitHub profile workflow matrix | 93 historical benchmark jobs; not production CI | Delete | Retain nine core workflows and their `.github/scripts` submodule dependency; remove profile matrix and README badge wall | Workflow/file-link audit |
| Historical material under `tests/misc` | Unique regression or research context | Keep selectively | Retain lean legacy and useful historical scripts; delete redundant backup files | Focused regressions and reference search |

Stage acceptance:

- Every candidate was classified from evidence.
- No retained active file references a deleted or archived path.
- The repository is smaller or clearer because redundant material was removed,
  not merely hidden in `misc`.
- Permanent regression oracles and reproducibility-critical material remain.

Observed Stage 6 results:

```text
Deleted 93 historical profile workflows, stale duplicate implementations,
seven superseded planning notes, backup/tmp files, generated desktop/bytecode
artifacts, and broken symlinks. Retained nine core workflows and their tracked
`.github/scripts` dependency, 19 reproducibility MAT files, permanent oracle
layers, and useful historical research material.
README testing documentation was reduced to the active CI and Optiprofiler
entry points. git diff --check, stale-reference, conflict-marker, suppression-
marker, temporary-file, and broken-symlink scans passed.
```

## Stage 7: complete server acceptance

Synchronize the exact intended Phase 1 validation files over SSH port `53781`
to a fresh isolated server directory. The server worktree
`lhtian97@frp-pen.com:~/Work/bds` is intentionally left untouched because it
contains unrelated local changes. Do not delete unrelated server files, then
run all of the following:

- [x] New `bds`, all acceleration off, versus the frozen non-accelerated
      reference: complete 1350-case gate.
- [x] New `bds`, all acceleration on, versus `lean_evolved_bds`: complete
      630-case default and 630-case explicit-CBDS gates.
- [x] `verify_gradient_stopping_threshold`.
- [x] `verify_gradient_stop_no_extra_evaluations`.
- [x] `verify_gradient_estimate_validity`.
- [x] `verify_function_value_reference`.
- [x] `verify_bds_momentum_duplicate`.
- [x] The automatic-initial-step regression suite through production `bds`.
- [x] `src/unit_test.m`, with any unrelated pre-existing numerical issue
      explicitly distinguished from a new failure.
- [x] Code Analyzer on every production, reference, and test MATLAB file changed
      in Phase 1.
- [x] Installation/path/help smoke test from a clean MATLAB path.
- [x] `git diff --check` and repository-wide searches for stale names, broken
      references, conflict markers, and suppression markers.
- [x] Local/server SHA-256 equality for every synchronized solver, helper, test,
      and setup file after the accepted run.

Stage acceptance:

- Every required marker and case count is recorded.
- No test relies on local MATLAB, which is unavailable.
- No server file drifts during the accepted run.
- No unexplained Code Analyzer or unit-test regression remains.

Observed Stage 7 results:

```text
Accepted isolated mirror: /tmp/bds-phase1-final.cOKQK1
MATLAB: R2026a
BDS_WITHOUT_ACCELERATION_REFERENCE_OK
GRADIENT_STOPPING_THRESHOLD_OK
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
GRADIENT_ESTIMATE_VALIDITY_OK
FUNCTION_VALUE_REFERENCE_OK
BDS_MOMENTUM_DUPLICATE_OK
BDS_AUTO_ALPHA_INIT_OK
BDS_FOCUSED_AND_UNIT_ACCEPTANCE_OK
BDS_ACCELERATION_EQUIVALENCE_OK (1350 + 630 + 630 = 2610 cases)
BDS_CODE_ANALYZER_OK files=43 diagnostics=66 failures=0
  Diagnostics inspected: AGROW, NASGU, ISCL, FNDSB, DATST, and TNOW1 only;
  they describe inherited/intentional performance or compatibility code, not
  correctness failures, and no suppression markers were added.
BDS_INSTALLATION_SMOKE_OK (resolved isolated src/bds.m; nf=133; exitflag=3)
BDS_LOCAL_SERVER_HASH_OK files=107 mismatches=0
```

## Stage 8: Phase 1 closeout

- [x] Inspect the complete Phase 1 diff, including renames and deletions rather
      than only changed file contents.
- [x] Compare the final tree with the Stage 0 inventory and resolve every
      unexplained file.
- [x] Record final defaults, public options, reference architecture, test
      markers, case counts, server hashes, and cleanup decisions.
- [x] Confirm `git status` contains only the intended reviewed changes, or is
      clean after separately authorized commits.
- [x] Prepare reviewable commit boundaries:
      1. frozen references and re-anchored tests;
      2. production solver/private migration;
      3. caller and public-documentation migration;
      4. repository cleanup and final records.
- [x] Decide the final disposition of this working checklist: keep a concise
      completed maintenance record, archive it, or remove it after transferring
      durable conclusions to current documentation.
- [x] Produce a Phase 1 completion report and explicitly state whether every
      gate for beginning Phase 2 is satisfied.

Phase 1 is complete only when every required checkbox above is supported by an
observed result. A partial implementation, a passing subset of tests, or a
clean-looking repository tree is not sufficient.

Observed Phase 1 result:

```text
COMPLETE.

Final defaults: MaxFunctionEvaluations=500*n, noiseless expand=2.0, and all
three acceleration switches enabled. Production bds is guarded by a frozen
non-accelerated reference and an independent all-on lean reference.

Final worktree inventory: 124 intended tracked deletions (93 profile workflows
and 31 obsolete/generated paths), 35 intended tracked modifications, and 16
intended new files. The .github/scripts submodule was restored after the final
reference audit confirmed that two retained core workflows require it.

The completed checklist is retained as the Phase 1 maintenance record. The
recommended commit boundaries remain the four groups listed above; no commit,
push, pull request, checkout, merge, rebase, or main-branch operation was
performed. All technical gates for beginning a separately authorized Phase 2
are satisfied.
```
