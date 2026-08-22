# Tests Directory Cleanup Plan

## Objective

Make `tests/` describe the executable verification surface of BDS rather than a
mixture of regression tests, research experiments, historical workflows, and
duplicated utilities. Preserve reproducible research under a top-level
`research/` directory, delete only files whose obsolete or duplicated status is
supported by reference and content checks, and finish with the same MATLAB
behavioral guarantees used for the production `bds.m` migration.

This work is performed on `rebuilt_code_style`. It does not include committing,
pushing, switching branches, or merging into `main`.

## Non-negotiable validation gates

- [x] Preserve the current production defaults, including `MaxFunctionEvaluations = 500*n`
      and `expand = 2.0`.
- [x] Preserve acceleration-off equivalence with
      `bds_without_acceleration_reference.m`.
- [x] Preserve acceleration-on equivalence with `lean_evolved_bds.m`.
- [x] Pass the function-value and estimated-gradient stopping tests, including
      the no-extra-evaluation and threshold/reference cases.
- [x] Run all existing core unit tests and the complete acceleration comparison.
- [x] Run MATLAB Code Analyzer on every production or test/research MATLAB file
      changed by this cleanup; introduce no new warning category or failure.
- [x] Run installation smoke testing from a clean temporary server directory.
- [x] Leave the server's existing `~/Work/bds` checkout untouched.

## Disposition rules

1. `tests/` keeps executable unit, regression, stress, recursion, profiling, and
   compatibility checks that validate the maintained code.
2. `research/` keeps experiment drivers, tuning studies, generated evidence,
   and their documentation. Binary `.mat` evidence is relocated without being
   rewritten.
3. `examples/` keeps compact pedagogical implementations intended for readers.
4. A file is deleted only after checking active references and confirming that
   it is duplicated, broken, superseded, or an inactive workflow artifact.
5. Historical recovery is provided by Git; no second in-tree archive of deleted
   workflow YAML or byte-identical source copies is created.

## Stage 1 — Establish one executable regression gate

- [x] Add `tests/run_bds_regression_suite.m` as the single maintained entry point
      for core unit tests, input-shape/seed/scalar-function tests, the focused
      acceleration and stopping verifiers, and full acceleration equivalence.
- [x] Add a GitHub Actions workflow that invokes this entry point.
- [x] Run the new entry point on the MATLAB server before structural cleanup to
      establish a clean baseline.

## Stage 2 — Remove high-confidence historical debris

- [x] Move `tests/misc/lean_evolved_bds_legacy.m` to `tests/competitors/`, because
      it remains an active oracle for momentum-duplicate verification.
- [x] Move `tests/misc/evolved_bds_fast_ablation_problem_selection.md` with the
      acceleration-ablation research material.
- [x] Delete the remaining `tests/misc/profile_*.yml`; workflows outside
      `.github/workflows/` are inactive and have no maintained callers.
- [x] Delete `tests/misc/tuning/`; its surviving contents duplicate
      `tests/tuning/misc/` byte for byte.
- [x] Delete the uncalled and invalid `tests/misc/difference_matcutest_s2mpj.m`
      and `tests/misc/dimensions.m`.
- [x] Delete `tests/test_expand_shrink/`; it is uncalled and relies on the
      unsupported `options.verbose` interface.
- [x] Delete the uncalled `tests/competitors/nlopt_wrapper.m` and
      `tests/competitors/private/warnoff.m`.
- [x] Delete `tests/tools/get_base_info.sh`, `tests/tools/merge_pdf.sh`, and the
      duplicated `tests/tools/trim_time.m` after confirming their only callers
      are being removed.

## Stage 3 — Separate research from verification

- [x] Move `tests/accelerated_bds_ablation/` and
      `tests/run_accelerated_bds_memory_ablation.m` to
      `research/accelerated_bds_ablation/`.
- [x] Move `tests/accelerated_bds_dimension_comparison/` to
      `research/accelerated_bds_dimension_comparison/`.
- [x] Move `tests/auto_initial_step_size/` to
      `research/auto_initial_step_size/`, retaining all `.mat` evidence.
- [x] Move the four NBDS exploration drivers to `research/nbds/`; retain the
      reusable competitor implementation in `tests/competitors/`.
- [x] Move `tests/tuning/` to `research/tuning/` and relocate its tuning-only
      helpers so the study is self-contained.
- [x] Repair all repository-root, tests-directory, helper, and competitor paths
      affected by these moves.
- [x] Replace broken links to server-generated benchmark PDFs with an explicit
      explanation of where those artifacts are produced.

## Stage 4 — Resolve remaining ambiguous files explicitly

- [x] Move `tests/competitors/bds_simplified_one_page.m` to `examples/` as a
      pedagogical implementation rather than silently deleting it.
- [x] Delete the orphaned manual launcher `tests/profile_optiprofiler_script.m`;
      retain the maintained `tests/profile_optiprofiler.m` API used by research.
- [x] Delete `tests/tools/strip_profile_timestamp.sh` and its isolated self-test;
      no maintained workflow or MATLAB test calls them.
- [x] Keep the parser/fixer utilities that still have direct tests or current
      result-maintenance value.

## Stage 5 — Documentation and repository hygiene

- [x] Move research/development notes out of `tests/` while preserving current
      README links and useful history.
- [x] Add concise README files for `tests/` and `research/` that explain their
      different roles and supported entry points.
- [x] Update `.gitignore` for the new research locations and remove stale
      `tests/misc/tuning` rules.
- [x] Remove obsolete spelling exceptions that named deleted helper files.
- [x] Search the entire repository for stale old paths, deleted function names,
      broken relative links, and dangling symlinks.

## Stage 6 — Final verification

- [x] Run shell/YAML/symlink/reference sanity checks locally.
- [x] Synchronize only the required clean file set to a fresh `/tmp` directory on
      the MATLAB server.
- [x] Run `run_bds_regression_suite` and require its success marker.
- [x] Run Code Analyzer on all affected MATLAB files and compare with the known
      baseline rather than hiding warnings.
- [x] Run installation smoke testing from the isolated directory.
- [x] Compare hashes of the synchronized source and test files.
- [x] Inspect final `git diff --check`, `git status`, and diff statistics.

## Completion record

- Status: complete
- Started: 2026-08-22
- Completed: 2026-08-22
- MATLAB server validation:
  - pre-cleanup regression baseline passed in
    `/tmp/bds-tests-cleanup-baseline.9Q0c4I`;
  - final validation passed in
    `/tmp/bds-tests-cleanup-final-clean.KEDFX6`;
  - 160 synchronized MATLAB/setup paths matched the local aggregate SHA-256;
  - all unit and focused checks passed, followed by the complete 2610-case
    acceleration equivalence comparison;
  - Code Analyzer parsed 32 source, 77 test, 2 example, and 48 research files
    with no parse failure and no added suppression;
  - isolated path, `help bds`, and objective-evaluation smoke testing passed.
- Commit/push/main integration: intentionally not performed
