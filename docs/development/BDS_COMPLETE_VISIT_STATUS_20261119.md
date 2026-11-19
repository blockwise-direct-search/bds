# Complete visits, acceleration and the current BDS interface

2026-11-19. Keep all objective calls, accepted points, momentum, random streams, gradient samples and termination decisions identical on supported inputs. Historical solvers, frozen fixtures and experimental results are comparison evidence.

- [x] Freeze the current source and identify maintained callers and option validation.
- [x] Introduce complete visits before either use. Compute the latest covering start and completion of the current stopping interval from the same last-visit indices. Keep stopping eligibility and latest poll sample replacement in the main loop.
- [x] Keep the acceleration gate in bds and put the two-direction search in a private routine. Preserve duplicate reuse, acceptance, best point, exit priorities and evaluation order.
- [x] Document the current serial interface and reject unsupported names uniformly. Migrate current callers and tests while retaining historical data and independent numerical expectations.
- [x] Verify coverage against direct enumeration, repeated blocks and unavailable samples, public input rejection, exact before/after behavior, archived trace replay and the maintained MATLAB regression. Check tested file hashes and record results.

## Completed on 2026-11-19

The main loop records the most recent poll of each block, uses `complete_visit_status` for both coverage questions, calls `accelerate` after the polling gate and performs the additional stopping checks at `if visit_complete`. The next stopping interval starts at `k + 1`. The public option validator accepts the 31 documented fields and rejects an unknown field before the first objective call. Unsupported algorithms take the normal invalid-algorithm path. The user guide, example and maintained regression callers use the public acceleration switch. Frozen comparisons translate that switch on the reference side.

MATLAB verification ran in the isolated server directory `~/Work/bds_complete_GaELcy`. SHA-256 matched the 29 baseline and 136 candidate source, test and example files in the inventories.

- `visits.log`: all 15,309 prefixes across the 2,187 seven-visit sequences on three blocks agreed with an independent enumeration of both endpoints. Four tests injected the five-block order 1,1,2,2,3,3,4,4,5 only into a test copy. They checked last pre-shrink steps, an invalid latest sample, an incomplete final poll and the first eligible function-stopping boundary.
- `parity_final.log`: 1,280 supported configurations (21,386 calls per implementation) agreed exactly on objective points, point orientation, final outputs, exit flags and histories.
- `replay_final.log`: 3,432 and 1,489 archived runs replayed exactly. The callback supplied the saved values and checked every requested point.
- `accepted.log`: the maintained regression completed with BDS_REGRESSION_SUITE_OK, including 1,080 frozen acceleration-off comparisons, 540 independent reference cases and the new unknown-option and visit-coverage tests. The seven accepted algorithm names also passed a source-only smoke test. Code Analyzer introduced no new diagnostics in the modified production and unit-test files.
- `optional.log`: 96 additional serial-off cases and 768 solver-option traces plus six initialization and nine target cases matched the respective frozen implementations.
