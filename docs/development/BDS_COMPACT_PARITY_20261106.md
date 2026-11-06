# Complete solver versus thesis compact implementation

## Scope

User requested exact evaluation-point, function-value and update-trajectory
comparison with `bds_compact_thesis.m`. Do not change production algorithms,
the frozen compact reference, the manuscript, or existing experiment data.
No Git commit/push is requested.

## Configuration

Use cyclic coordinate pairs, opportunistic polling, cycling strategy 1,
initial steps 1, expansion 2, shrinkage 0.5, step tolerance 1e-6,
budget and maximum outer iterations 500N, forcing function alpha^2,
and reduction_factor=[eps,eps,eps]. Disable both acceleration strategies,
initial-point-dependent steps, and both additional termination criteria.
Failure handling remains an intrinsic eval_fun interface difference: exact
parity is not promised for thrown errors or nonfinite initial values.

## Checklist

- [x] Inspect the actual compact reference and previous C10 checks.
- [x] Create an isolated observer-only instrumented copy of each solver.
- [x] Check uninstrumented and instrumented runs are identical externally.
- [x] Compare every evaluation point/value, returned point/value, count,
      block order and cycle-level step-size history.
- [x] Compare per-block pre/post base point/value, all step sizes and
      direction ordering; record terminal-block differences separately
      without silently treating them as exact matches.
- [x] Run finite synthetic probes, including near-threshold and budget exits.
- [x] Replay all 133 frozen C10 clean-problem traces against both current
      production and the original thesis compact source.
- [x] Save MAT/log evidence and record exact coverage and any discrepancies.

## Evidence policy

Saved-trajectory replay validates exact requests and state transitions for
recorded objective values, not independently regenerated objective functions.
Synthetic probes are fresh evaluations. Frozen C10 data are read-only.
Instrumentation only appends observer snapshots in temporary copies; original
source files and private numerical interfaces remain unchanged. No mismatch
will be repaired or waived without reporting its nature.

## Source provenance

Server directory: `/home/lhtian97/Work/bds_compact_verify_20261106_CZW0cl`.
The run uses a new immutable snapshot of the current local `src`, not a remote
live checkout. The compact source is copied unchanged from
`bds_paper/collaborator_feedback/c10_nan_matched/bds_compact_thesis.m`.
Original source text and observer copies are preserved with the result files.

- Production `bds.m` SHA-256:
  `17e2fe27153a32420670d28ef983d9603c8c88b5a11de8be84fd7fc507122500`.
- Compact SHA-256:
  `8b40e15af9f2d67f1e2b22ad178aa7c01a17f293e5809faf07b17c9e608bb9ba`.
- Historical data: all 133 problem traces in
  `/home/lhtian97/Work/c10_nan_matched_20261102/preflight`.
- Runner: `tests/verify_bds_compact_thesis.m`.
- Difference audit: `tests/tools/summarize_compact_parity.m`.

Each case runs original production, observed production, original compact,
and observed compact separately. Observer neutrality is checked against all
outputs and actual objective calls. The observer records per-block states
before polling and after updating, including early terminal exits. It does
not change comparison formulas, evaluation order, or return behavior.

## Initial result and process exception

Attempt 1 completed all 160 cases (27 freshly evaluated synthetic probes and
133 saved C10 traces), comparing 628,533 objective requests per solver.
All 160 had exactly equal evaluation points/values, returned point/value,
evaluation counts, block order and cycle-level step-size history. All 160
also had identical states before every block and after every nonterminal
block. Observer neutrality passed in all 160 cases.

Terminal snapshots matched in 135 cases; the other 25 were independently
audited. The exact-all-states flag is deliberately false: a discrepancy in
an unused final variable is still a discrepancy, not an exact-state pass.

After writing the complete summary, MATLAB R2026a printed
`free(): chunks in smallbin corrupted` and stalled during exit. No numerical
comparison failure preceded this message. The precise cause is unestablished.
All logs and MAT files are preserved. The exact MATLAB process 1952738 was
terminated with SIGTERM after confirming its work was complete. Attempt 1
must not be described as a normal process exit.

Attempt 2 uses identical numerical code, observers and assertions, with MAT
serialization changed from v7.3 to v7. It runs in a separate result directory
and retains the original evidence. This change does not establish the cause
of the first process exception.

## Final verified result

Attempt 2 completed with exit code 0 in 78 seconds on MATLAB R2026a.
The independent audit of its saved states also completed normally. Both
attempts produced identical coverage and mismatch counts:

| Item | Result |
| --- | --- |
| Fresh synthetic probes | 27 |
| All frozen C10 problem traces | 133 |
| Objective requests compared per solver | 628,533 |
| Exact requested points and raw function values | 160/160 |
| Exact returned point/value and evaluation counts | 160/160 |
| Exact block order and cycle-level step-size history | 160/160 |
| Exact pre-block states and nonterminal post-block states | 160/160 |
| Observer neutrality | 160/160 |
| Exact terminal post-block states | 135/160 |
| Terminal differences confined to unused base point/value | 25/25 |

The audit checks every field of the final snapshot. In all 25 differing
cases the evaluation budget is exhausted, and ONLY `xbase` and `fbase`
differ. All step sizes, direction order, evaluation count and block index
still match. In the production solver, the budget-exit branch precedes
updating the base point. In the compact solver, updating the base point
precedes the budget-exit branch. Both retain and return the same best point.
There is no next evaluation at which the different final base could affect
the run. This is not a rolling-acceleration difference: acceleration is off.

Conclusion: exact evaluation/search trajectories and returned results are
verified on this coverage. Exact equality of every internal state including
unused terminal variables is NOT verified and in fact fails in 25 cases.
No algorithm correction has been made or silently incorporated into the
reference. Aligning the final assignment order would be a separate change.

The saved traces include 26 raw NaN evaluations. They also matched in these
particular runs, but that observation does not establish general parity of
the distinct failure-handling policies. No thrown-error or invalid-initial-
value equivalence claim is made. Likewise, saved replay is not a fresh S2MPJ
objective recomputation or a proof covering all inputs/parameter choices.

## Deliverables

Local evidence: `tests/testdata/compact_parity_20261106/` (Git-ignored).
It contains the complete normal-run MAT files and observer sources under
`attempt2/`, the terminal audit, and process logs/exit records. The original
v7.3 attempt and its independent audit remain preserved on the server; that
audit also completed with the same 25 terminal differences. All verification
and audit screen sessions have exited.
The compact reference and production numerical source were not modified.
`bds.tex` was not modified. No commit or push was performed.
