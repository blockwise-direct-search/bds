# One-block-visit execution loop: implementation and acceptance plan

## Contract and frozen baseline

Refactor production `src/bds.m` from nested batch/visit loops to one main
block-visit loop. Baseline: committed `37e80376` (green rolling MP integration).
This is a behavior-preserving structural change, not a new algorithm.
Do not edit the manuscript, frozen experiments, or existing private numerical
interfaces. No Git commit/push is requested in this turn.

Each loop pass performs one block visit. An explicit batch context records
the batch number, position, scheduled blocks and starting point/value. Batch
initialization and finalization are events, not a second execution loop.

### Invariants

- Keep RNG draws, block selection/order, replacement-delay interpretation,
  complete/opportunistic polling and direction cycling unchanged.
- Sequential visits update the current base immediately (except existing
  terminal exits). Parallel visits all use the same batch base and commit
  the shared result only at batch finalization, including partial batches.
- Keep green rolling windows, per-block momentum, first-cycle bootstrap,
  acceleration acceptance, budgets and target handling exactly unchanged.
- Non-default configurations retain existing batch MP, not a new rolling rule.
- Keep function/gradient stopping and history sampling at existing batch
  boundaries, including existing partial-batch/exit-priority behavior.
- Preserve gradient validity/reference logic and public output/history units.
- Reuse inner_direct_search, eval_fun, extrapolation and gradient interfaces;
  do not duplicate their numerical implementations.
- Retain the documented compact difference: an unused terminal base may
  differ after budget exhaustion. Do not change either algorithm to hide it.

## Checklist

- [x] Read the current scheduling, visit, finalization and verification code.
- [x] Freeze baseline source and all private source hashes independently.
- [x] Implement an explicit batch context and a single block-visit loop.
- [x] Update explanatory comments/docs without changing public options.
- [x] Add independent execution-schedule tests, including shared-base
      parallel polling, batch-boundary stopping and mid-batch budget exits.
- [x] Compare exact objective calls and every existing returned output with
      the pre-refactor snapshot across all selectors, bases, partitions,
      polling modes, acceleration switches, stopping switches and exit cases.
- [x] Run maintained regression/unit/switch tests.
- [x] Repeat frozen C15/C13 comparisons: 251 fixtures, all 532 saved plain
      traces, and the 288-trace six-feature sample (48 overlap with plain).
- [x] Repeat compact parity: 27 fresh probes plus all 133 C10 trajectories,
      with observer neutrality and terminal-state audit.
- [x] Inspect MATLAB diagnostics, source hashes, complete logs/MAT evidence
      and exit statuses; document results, limits and unresolved failures.

## Verification discipline

Use isolated server snapshots and screen with a watchdog. Do not mutate live
server repositories or experimental snapshots. Failures are preserved and
investigated, not removed from the cases or hidden by relaxed comparisons.
Saved-trajectory replay is distinguished from fresh objective computation.
Any numerical difference from 37e80376 blocks acceptance of this structural
refactor. Compare raw function exceptions as well as solver output where
applicable. Existing compact terminal-base differences must match the earlier
25-case finding rather than being labeled exact-all-state passes.

The compatibility matrix must cover cbds, pbds, rbds, pads, ds, custom bases,
unequal partitions, small batches, delayed replacement, partial final batches,
and initially terminating runs. Keep verification bounded; no new scientific
benchmark or tuning campaign is authorized by this refactor.

## Execution record

Server root: `/home/lhtian97/Work/bds_visit_refactor_20261106_YOKAQj`.
The baseline is an independent `git archive 37e80376 src`. Its additional
`bds_before_visit_refactor.m` differs only in the entry function name and
uses its own unchanged private directory. Candidate and frozen experiment
sources are separate. The new main loop is a `while` loop with explicit
`batch.index`, `batch.position`, `batch.indices`, `batch.xbase`, `batch.fbase`.

Smoke attempts 1/2 exposed an incorrect expectation in the new independent
test: parallel visits were assumed sorted, whereas existing parallel mode
keeps a seeded random permutation. Production code was not changed to make
that expectation pass. The test now computes the seeded order independently
and checks shared-base evaluation points and aggregation. Smoke attempt 3
printed two passes, but the subsequent path issue described below prevents
using that smoke run alone as evidence for the candidate. Failed logs and
their test-source versions are retained.

The first full run passed the maintained regression suite, then the new
matrix's path-identity assertion stopped it before numerical comparisons:
adding baseline and candidate directories together gave the baseline's
same-named bds.m priority. This also made the smoke runner's default handle
resolve to baseline after its initial path check. The runner/matrix now add
the candidate last in a separate call and explicitly recheck identity after
adding the baseline. The full suite and both independent schedule checks
were rerun; no earlier smoke result is used alone to certify candidate code.
The failed full-run sources and logs are preserved as attempt1_source/full.log.

The corrected full run (full2.log, results2/) passed the maintained regression
suite, all 3,108 exact pre-refactor comparisons (287,850 objective calls per
solver), and all 251 frozen C15/legacy fixtures. Production numerical source
did not change during either test-harness correction.

## Final acceptance

Status: completed and accepted on MATLAB R2026a. `full2.log` contains
`BLOCK_VISIT_ACCEPTANCE_PASSED`; its watchdog records a normal exit code 0
after 170 seconds. The parallel pool and all verification screen sessions
have exited. There is no outstanding computation or unresolved mismatch
against the frozen pre-refactor solver.

| Gate | Verified result |
| --- | --- |
| Independent hand-derived scheduling checks | 15 on baseline and 15 on candidate, plus maintained-suite invocation |
| Maintained regression suite | Passed, including 36 rolling-switch checks and 120 gradient-threshold behavior cases |
| Pre-refactor full trace/output matrix | 3,108 exact passes, 287,850 objective calls per solver |
| Frozen green/legacy fixtures | 251 passes |
| All plain saved experimental traces | 532 passes, 1,841,811 calls |
| Six-feature saved-trajectory sample | 288 passes, 861,134 calls |
| Compact all-off comparisons | 160 exact search/output/continuing-state passes, 628,533 calls per solver |
| Compact unused terminal-base differences | Same 25 cases and exact same final state records as before refactoring |
| Local/server production source identity | All 31 files match SHA-256 |
| Existing private source interfaces | All 29 files unchanged from 37e80376 |
| MATLAB Code Analyzer for bds.m | Only the five pre-existing dynamic-history AGROW warnings |

The six-feature sample overlaps the full plain set in 48 traces. Counts are
not to be added as unique experiments. Saved replay does not independently
regenerate S2MPJ objectives/noise; the fixture matrix and synthetic compact
probes provide separate fresh-evaluation checks. These checks provide strong
finite regression coverage, not a proof of equivalence for every possible
MATLAB objective or user configuration.

The compact reference intentionally retains the unused-terminal-base
difference previously discussed with the user. No assertion was relaxed to
accept an additional difference, and exact-all-internal-state parity with
compact is still not claimed. No compact source or existing private solver
kernel was changed.

## Deliverables and usage

- `src/bds.m`: one block visit per main-loop pass, explicit batch context,
  and unchanged numerical interfaces/defaults.
- `docs/BDS_ACCELERATION_OVERVIEW.md`: main-loop and parallel scheduling
  explanation, separate from acceleration behavior.
- `tests/verify_bds_visit_schedule.m`: maintained independent schedule checks.
- `tests/verify_bds_visit_refactor.m`: independent 37e80376 trace/output matrix.
- `tests/verify_bds_compact_thesis.m`: observer anchors support both loop
  structures; its numerical oracle/comparisons are unchanged.
- `tests/tools/run_block_visit_verification.m`: complete isolated acceptance.
- `tests/testdata/block_visit_refactor_20261106/`: Git-ignored frozen baseline,
  local logs, MAT evidence, observer sources and source-hash manifest.

The accepted server snapshot remains under the root above, with results in
`results2/`. Old failures and sources remain separately preserved. To repeat
the acceptance on that server, add `candidate/tests/tools` to MATLAB's path,
set `BDS_VISIT_VERIFY_ROOT` to that root and `BDS_VISIT_RESULTS` to a NEW result
directory, then call `run_block_visit_verification('full')`.

Public history indices still count batches. Default cyclic batches still
contain N visits; parallel still means shared-base polling, not a new
multicore implementation. Rolling dispatch has not been broadened to custom
bases/random/parallel configurations. Those would be algorithm changes.
The manuscript and external experiment figures were not edited. No Git
commit or push was performed in this turn.
