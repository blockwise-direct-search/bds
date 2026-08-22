# BDS main integration plan

## Objective

Integrate the completed production-BDS migration and repository cleanup from
`rebuilt_code_style` into the current remote `main` without losing files,
publishing unintended artifacts, bypassing regression checks, or modifying
algorithm behavior during the integration itself.

This plan begins with inspection only. Staging, committing, publishing a branch,
opening a pull request, and merging are separate gates because they change
increasingly broader Git or GitHub state.

## Preserved behavioral baseline

- Production defaults remain `MaxFunctionEvaluations = 500*n` and
  `expand = 2.0`.
- Acceleration-off behavior matches the frozen non-accelerated BDS reference.
- Acceleration-on behavior matches `lean_evolved_bds.m`.
- Function-value and estimated-gradient stopping checks pass.
- The complete 2610-case acceleration equivalence comparison passes.
- The final pre-integration server validation is recorded in
  `/tmp/bds-tests-cleanup-final-clean.KEDFX6`.

No integration-only edit may change these contracts without returning to the
implementation and MATLAB-validation stages.

## Authorization gates

1. **Staging gate:** inspect the complete unstaged/untracked inventory before
   running `git add -A`.
2. **Commit gate:** inspect the complete staged diff before creating a local
   commit.
3. **Publication gate:** inspect the commit and PR text before pushing the branch
   or creating a GitHub pull request.
4. **Main gate:** inspect CI, reviews, mergeability, and the final PR diff before
   merging into `main`.

The recommended final GitHub operation is **Squash and merge**. Rebasing this
large, already-validated migration is not planned. If the remote `main` has
advanced, its changes will first be assessed for conflicts and behavioral risk;
the resolution strategy will be recorded before any integration commit.

## Stage 1 — Current-state snapshot

- [x] Record branch, HEAD, upstream, remote URL, commit identity availability,
      and clean/dirty state.
- [x] Detect and record the externally created commit and branch push that
      occurred after the final cleanup validation.
- [x] Record the current tracked-modification and untracked-file counts.

## Stage 2 — Refresh remote knowledge

- [x] Run `git fetch origin --prune` without changing the working tree.
- [x] Record `origin/main`, `origin/rebuilt_code_style`, and their divergence
      from the local branch.
- [x] Determine whether `main` advanced and whether the candidate branch has a
      textual conflict before staging or publishing anything.

## Stage 3 — Complete working-tree audit

- [x] Classify every modified, deleted, and untracked path as production code,
      regression/reference code, documentation, research relocation, workflow,
      or intentional cleanup.
- [x] Inspect ignored files and ensure no required source or result record would
      be omitted from the commit.
- [x] Check new or changed large/binary files; retain only the 19 validated
      research `.mat` files and other explicitly justified artifacts.
- [x] Check dangling symlinks, file modes, whitespace errors, conflict markers,
      generated metadata, and stale old paths.
- [x] Search filenames/diffs for likely credentials or private-key material
      without printing candidate secret values.
- [x] Confirm the intended commit boundary. Commit `5be8566e` already contains
      the coherent migration; the remaining work belongs in one small
      integration-preparation commit after validation.

### Pre-Gate-A findings and proposed corrections

- The pushed feature commit predates this plan and is recorded below; no commit
  was created by this execution.
- `git diff --check origin/main...HEAD` reports only mechanical whitespace
  defects. Remove those defects without changing executable behavior.
- The simplified-BDS workflow still compares acceleration-on production BDS
  against the non-accelerated simplified solver. Explicitly disable all three
  acceleration mechanisms in that legacy equivalence test. A server-side
  minimal reproduction confirms that default production BDS differs, while the
  all-off configuration matches `bds_simplified` exactly in solution, objective,
  exit flag, evaluation count, and histories.
- Remove the two interactive `keyboard` statements from the simplified
  verifier so that CI reports a numerical mismatch instead of waiting for an
  unavailable interactive debugger.
- Exclude `DEVGLA1` from the simplified verifier: its S2MPJ definition raises
  the second variable to noninteger powers, so polling at a negative value
  produces a complex objective outside BDS's real-valued objective contract.
  This caused platform- and worker-dependent overflow trajectories rather than
  a meaningful real-valued solver comparison.
- The TeX/Bib spelling workflow scans a newly retained mixed-language research
  presentation. Its reported tokens are technical identifiers, filenames,
  numeric notation, a commit hash, and Chinese text rather than misspelled
  English prose. Exclude the archived `research/` tree from the product spelling
  workflow instead of polluting the global dictionary with run-specific tokens.
- Fifteen executable MATLAB modes under `research/tuning` are inherited from
  the previously tracked files. Preserve them during this integration to avoid
  unrelated mode-only churn; mode normalization can be handled separately.
- After these corrections, rerun the focused simplified equivalence check, the
  acceleration-off/on and gradient-stopping suites, repository static checks,
  and the applicable spelling command before staging.

## Gate A — User approval to stage

- [x] Present the pre-staging audit and receive approval.

Gate A was approved by the user on 2026-08-22. The approved work included the
bounded integration corrections and their local/server validation before
staging.

## Stage 4 — Stage and inspect

- [x] Run `git add -A` only after Gate A.
- [x] Confirm the audited feature commit together with the staged corrective set
      includes every intended deletion, relocation, symlink, workflow, source,
      test, document, and research evidence file.
- [x] Review `git diff --cached --check`, diff statistics, rename detection,
      binary sizes, modes, and representative source/documentation diffs.
- [x] Confirm there are no remaining unstaged or untracked intended changes.

## Gate B — User approval to commit

- [x] Present the staged audit and proposed commit message; receive approval.

Gate B was approved by the user on 2026-08-22 with commit message
`Prepare production BDS migration for main`.

## Stage 5 — Create the feature-branch commit

- [ ] Create one local commit on `rebuilt_code_style`.
- [ ] Confirm the new commit, parent, branch, status, and diff against
      `origin/main`.
- [ ] If `origin/main` advanced, resolve the approved integration path on the
      feature branch and rerun all affected validation before publication.

## Gate C — User approval to publish

- [ ] Present the final commit hash and PR title/body; receive approval to push
      and create the PR.

## Stage 6 — Publish and validate the PR

- [ ] Push `rebuilt_code_style` to `origin` without force.
- [ ] Create a pull request targeting `main` if GitHub CLI authentication and
      repository permissions are available; otherwise provide the exact compare
      URL and PR text for the user.
- [ ] Verify the GitHub PR base/head, commit list, file count, and mergeability.
- [ ] Wait for required CI, including the maintained BDS regression workflow.
- [ ] Diagnose and fix any failure on the feature branch, then repeat the
      relevant local/server validation and CI checks.

## Gate D — User approval to merge main

- [ ] Present CI, review, mergeability, and final-diff evidence; receive final
      approval. Human confirmation of the public merge is preferred.

## Stage 7 — Merge and post-merge verification

- [ ] Squash-merge the PR into `main` without bypassing branch protection.
- [ ] Fetch the merged remote state and verify the expected commit ancestry.
- [ ] Update the local `main` only after confirming the working tree is safe.
- [ ] Run the post-merge path/help/solver smoke check and, if the merge resolution
      changed code, rerun the complete MATLAB regression suite.
- [ ] Record the PR URL, merge commit, final CI result, and post-merge validation.

## Execution record

- Status: in progress
- Started: 2026-08-22
- Current branch: `rebuilt_code_style`
- Current HEAD: `5be8566e04f52c3de779bf64e5ad937f3c353a08`
- Remote main: `81c3ef7bbb90faa3947160cbeabfaa080422bbba`
- Remote feature branch: `5be8566e04f52c3de779bf64e5ad937f3c353a08`
- Divergence from remote main: 0 behind, 25 ahead
- Feature commit: created and pushed externally before this execution
- Gate A: approved
- Gate B: approved
- Validation directory: `/tmp/bds-main-integration.QfdZLz`
- Maintained MATLAB regression: passed, including all 2610 acceleration
  equivalence cases and the function-value/gradient-stopping checks
- Simplified BDS: targeted case passed; full sequential 865/865 passed; final
  four-worker parallel run passed all 860 valid cases after excluding
  `DEVGLA1`
- TeX/Bib spelling command: passed with archived `research/` excluded
- Code Analyzer parse check: passed for all 111 MATLAB files under
  `src`, `tests`, and `examples`
- Static and synchronization checks: whitespace, YAML, shell syntax, conflict
  markers, generated metadata, symlinks, and content-level rsync dry-run passed
- Staged correction: 16 paths, 222 insertions, and 37 deletions; no binary or
  mode changes
- Current working tree: all intended changes staged; no unstaged or untracked
  paths
- Pull request: pending
- Main merge: pending
