# Green rolling MP production integration

Date: 2026-11-06. Status: implemented and accepted on MATLAB R2026a.

## Scope and invariants

Integrate the accepted C15 candidate 1 (P0A1) into production BDS for the
cyclic coordinate configuration. Do not edit bds.tex, change stopping
thresholds/default switches, run new performance comparisons, or commit/push.
Keep other configurations on their existing batch acceleration path.
Reuse existing private interfaces, especially inner_direct_search, eval_fun,
run_post_poll_acceleration_phase, gradient estimation and error estimation.
Do not replace polling with a copied experimental solver.

The frozen oracle is collaborator_feedback/c15_stopping/bds_mp_experiment.m
in the sibling bds_paper repository, plus the sealed server C15 bundle.
Production starting commit is a70ab1cb56fff46f71e610b130d88fe4b24fd73d.

Preserve the exact ring-buffer summation order, current-poll-before-window
construction, acceleration contribution to future windows, per-block
momentum, and OR accumulation of acceleration success over a complete cycle.
The first cycle uses the legacy end-of-cycle MP bootstrap; its momentum is
assigned to the last block and its acceleration displacement enters that
block's history slot. Later cycles accelerate after successful block visits.
This bootstrap is part of the validated oracle, not a new design choice.

Keep batch-level iteration limits and output history units unchanged.
Function stopping records once per completed batch/cycle; both extra stop
checks are suppressed if acceleration succeeded anywhere in that batch.
Reference selection and the two-branch gradient threshold remain unchanged.
Do not silently repair behavior that changes oracle trajectories; investigate
and report any such discrepancy before broadening the algorithm.

## Ordered work

- [x] Inspect current source, private interfaces and existing verification.
- [x] Freeze oracle and baseline provenance in an isolated verification area.
- [x] Extract rolling history/momentum orchestration behind private interfaces.
- [x] Integrate a precise supported-configuration dispatch into bds.m.
- [x] Preserve bootstrap, output bookkeeping and stopping semantics.
- [x] Add structural/unit tests and full-trace frozen-oracle comparisons.
- [x] Verify all four stopping combinations and independent acceleration switches.
- [x] Verify non-default configurations against the unmodified production baseline.
- [x] Run maintained regression tests, documenting intentional old-MP test changes.
- [x] Document dispatch, preserved interfaces, verification evidence and limitations.

## Acceptance

MATLAB validation runs on the server in a new isolated directory, not in its
production checkout or sealed experiment directories. Use screen for the
verification runner, keep logs and MAT failure evidence, and check completion.
Comparison must inspect all objective calls (points, values and exceptions),
final point/value, exit flag and all existing output fields; experimental
instrumentation is excluded explicitly. Test incomplete budgets, nonfinite
values, target exits, stopping boundaries and repeatable noisy objectives.
Keep non-default legacy scheduling and random-stream consumption unchanged.
Report actual coverage and any pending checks. No manuscript changes.

## Completion record

Accepted on 2026-11-06, MATLAB 26.1.0.3203278 (R2026a).
Final runner exited normally with code 0 and ROLLING_ACCEPTANCE_PASSED.
No manuscript edit, Git commit/push, production-server checkout modification,
new tuning experiment or figure replacement was performed.

### Execution evidence

Isolated server directory:
`/home/lhtian97/Work/bds_rolling_verify_20261106_7sjnya`.
The server production checkout and the C13/C15 sources/results are unchanged.
`references/base` freezes a70ab1cb private dependencies, with only the entry
function renamed to bds_baseline. `references/c15` copies the sealed C15 src.
`candidate` holds the initial test snapshot; `candidate_final` is the final
snapshot, so a running MATLAB session never reads changing source files.
All 31 local production MATLAB source files match candidate_final by SHA-256.

Attempt 1 found a fixture mistake: custom partition options were combined
with Algorithm=cbds, so the established Algorithm-priority rule overrode the
partition. Remove the alias in those fixtures, not the production behavior.
The original failure MAT and log are retained. Attempt 2 passed all 251
fixtures and the maintained regression suite. Of its 532 fresh-evaluation
manifest comparisons, 497 completed with exact equality and no mismatches.
The remaining 35 were deliberately interrupted after complete saved-trajectory
verification passed; they are NOT reported as fresh-evaluation passes. The
negative exit code -2 in attempt2.log.runner.json records that intentional SIGINT.

The final snapshot differs from the initially tested numerical source only
in comments. It adds an independent-switch regression and saved-trace replay.
The final regression suite and actual C13/C15 trajectory replays passed before
ACCEPTED.mat was written. Its plain_evidence field explicitly identifies
saved trajectories, not 532 fresh objective reruns.

### Final acceptance coverage

| Check | Result |
| --- | --- |
| Independent frozen-reference fixtures | 251 passed, 0 failed |
| Maintained regression suite, including new rolling unit checks | Passed twice, final snapshot included |
| Independent pattern/momentum switch regression | 36 cases passed |
| All 133 plain problems, four stopping modes, saved trajectories | 532 passed, 1,841,811 calls checked |
| Six features, four stopping modes, 12 sampled traces per combination | 288 passed, 861,134 calls checked |
| Additional fresh objective comparisons | 497 exact passes; 35 canceled, not failures or passes |
| Production source identity | All 31 MATLAB source files match server SHA-256 |
| Code Analyzer, three new private interfaces | No findings |
| Existing bds.m Code Analyzer findings | Five existing dynamic-history allocation warnings |

The six-feature sample includes 48 plain traces already covered by the full
plain replay. Do not add the two replay counts as distinct trajectories.
Each replay checks every requested point before returning its saved value,
then checks call count, final point/value, exit flag and every existing solver
output field. Only the experimental c12_stats field is excluded. A point
mismatch is remembered outside eval_fun's exception handler, so catching the
test error cannot accidentally turn a mismatch into a pass.

An initial extension of the replay test shadowed its coverage-mode variable
with the stopping-mode loop variable and selected only 48 plain traces. That
run is not used as complete coverage. The loop variable was renamed, explicit
532/288 coverage assertions were added, and BOTH replay modes were rerun and
passed (full_replay2.log). Final acceptance asserts those counts again.

### Files and invariants

Production changes are in src/bds.m and the three new private interfaces
initialize_rolling_acceleration, run_rolling_acceleration and
finish_rolling_bootstrap. Existing private MATLAB files are byte-for-byte
unchanged, including inner_direct_search, eval_fun,
run_post_poll_acceleration_phase, estimate_gradient and get_gradient_error_bound.
The old numerical kernels remain the implementation interfaces.

Default cyclic coordinate MP matches the green frozen implementation.
Other configurations keep their pre-integration batch path. No new tuning
parameter was added; both acceleration switches remain independent, and
stopping thresholds, default switches and public history/index units remain
unchanged. The documented first-cycle bootstrap is preserved exactly.

The old cyclic MP oracle scripts are labeled historical; they were not
rewritten to pretend their old algorithms match rolling MP. The maintained
regression entry now includes verify_bds_rolling_switches. Independent frozen
checks use verify_bds_rolling_reference; actual experiment replay uses
verify_bds_rolling_saved_traces, including mode full-plain.

### Reproducibility and limits

Local ignored evidence and frozen sources are in
tests/testdata/rolling_integration_20261106/{results,references}.
The server directory above retains both candidate snapshots, all logs,
intermediate failures and reference private dependencies. Verification screens
and workers exited; no further validation job is left running.

The saved-trajectory checks establish exact reproduction of those recorded
experiments, not an independent rerun of their objective/noise generators.
The 251 fixtures and 497 fresh comparisons provide complementary fresh-run
evidence. General rolling rules for other bases, arbitrary block partitions,
random block visits and simultaneous batches remain deliberately out of scope.
The validity theory of general sampled-block gradient estimates is unchanged.
