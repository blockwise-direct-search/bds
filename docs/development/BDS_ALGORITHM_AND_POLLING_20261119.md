# BDS algorithm options and polling state

2026-11-19. Change the serial BDS interface and clarify the implementation. Preserve the objective call sequence, random stream, returned point, evaluation histories, termination and accepted acceleration behavior for every previously valid, consistent configuration. Keep the current default and general cyclic partitions.

- [x] Freeze the pre-edit working source as a verification oracle.
- [x] Accept cyclic/cbds, permuted/pbds, random/rbds and ds, case-insensitively. Reject conflicting explicit block counts before evaluating the objective. Preserve matching counts, omitted and empty defaults, and the dedicated legacy parallel error. Update public help and interface tests.
- [x] Document row input, distinguish polling results from the fixed extrapolation base, clarify complete-visit flags and the block at the window start, and name both extrapolation strategies in execution order.
- [x] Store the actual pre-update polling step once per block. Build the direction-pair ownership map with the partition and use the most recent block step when estimating gradients.
- [x] Run the maintained MATLAB regression, focused interface/invalid-input tests, grouped-direction gradient checks and exact before/after comparisons across algorithms, stopping, acceleration, polling schedules and evaluation boundaries. Check test source identity against the local working files. Record scope and outcomes here.

## Verification completed on 2026-11-19

The server ran MATLAB against the local working source. SHA-256 comparisons passed for all 29 pre-edit source/test files and all 131 candidate source and active test files in the verification inventory. The isolated server directory is `~/Work/bds_algorithms_QEc3k1`. The maintained regression finished with `BDS_REGRESSION_SUITE_OK` in `suite_matched.log`.

- Public interface tests cover aliases, mixed case, character and string inputs, matching counts, empty counts, incompatible counts, invalid algorithm types and inconsistent partitions. Rejected inputs made zero objective calls.
- Exact old/new comparison passed for 1,280 configurations and 21,386 objective evaluations per implementation. All four returned outputs and every evaluated point agreed. Coverage includes row and column inputs, four canonical algorithms and custom grouped directions, both acceleration settings, all four additional stopping combinations, tight budgets, seeded noise and failures.
- The grouped-step test used unequal steps and noncontiguous pairs and recovered the analytic gradient at three successive complete visits. A separate test copy with only the visit order injected used 1,1,2,2,3,3,4,4,5. All five gradient components matched the central differences at the most recent pre-shrink steps. The production scheduler was unchanged.
- Frozen acceleration-off reference checks passed for all four algorithms (1,080 cases). The serial reference suite also passed 540 cases. Replay of the archived comparison and paper/supplement traces passed for 3,432 and 1,489 runs respectively, with exact points, supplied values, counts, final outputs and exit flags.
- The optional external configuration check was rerun with NOMAD, NEWUOA and BFO on the path and completed with no skips. NEWUOA used its MATLAB implementation because its double-precision Fortran MEX was unavailable. Code Analyzer reported the same diagnostic counts and identifiers as before for all four modified MATLAB files.
