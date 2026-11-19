# Serial BDS refactor, 2026-11-17

Implemented and verified. The approved design and completed acceptance record
are retained in the adjacent paper project:

- [Design and execution plan](../../../bds_paper/revision_history/V331.md)
- [Verification and cleanup evidence](../../../bds_paper/reproducibility/serial_refactor_20261117/README.md)
- [Current execution rules](../BDS_ACCELERATION_OVERVIEW.md)

The solver uses one main for-loop over actual block visits, backward rolling
windows and forward complete visits. Pattern directions use endpoint differences;
the current poll must improve even at the first complete window. Each actual
block owns momentum. Extrapolation has one shared helper; both additional
termination criteria share one helper, with call conditions visible in bds.m.

The full maintained regression passed, including 1,080 frozen serial polling
comparisons. Independent tests covered 3,240 accelerated traces, 96 pre-refactor
off traces, general complete visits, invalid evaluations, common-point gradient
samples, skipped estimates and stopping gates. The final stopping-priority
change passed all affected checks. Final installed-source checks passed, with
29 MATLAB files matching the server verification copy by SHA-256.

Historical experiment snapshots were not replaced. Parallel requests are
explicitly rejected. The future parallel entry is named pabds.m and is not
implemented. Algorithm='pbds' still denotes permuted serial visits.
