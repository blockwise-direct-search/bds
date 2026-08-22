# BDS acceleration overview

## Production role

The public solver `src/bds.m` includes three acceleration mechanisms:

- productive-direction memory before regular block polling;
- iteration-pattern search after a productive polling iteration;
- momentum-direction extrapolation after polling.

All three mechanisms are enabled by default and can be controlled independently
with `use_productive_direction_memory`, `use_iteration_pattern_step`, and
`use_momentum_extrapolation`. The default function-evaluation budget is
`500*n`, the default noiseless expansion factor is `2.0`, the productive
memory holds at most `min(n, 5)` entries, and `momentum_decay` is `0.6`.

The two post-poll searches share candidate step factors `1`, `2`, and `4`.
Pattern candidates are considered first. Momentum candidates are considered
only when the pattern search does not improve the incumbent, or when the
pattern mechanism is disabled. An exactly repeated rejected candidate is not
evaluated twice.

The detailed public option contracts are part of `help bds`. The phase helper
headers in `src/private` document their complete state and configuration
interfaces.

## Independent references

Two test-only reference layers prevent production BDS from being compared with
itself:

- `bds_without_acceleration_reference.m` freezes production BDS immediately
  before acceleration was promoted. Its changing option/default/validation and
  automatic-step dependencies are frozen under reference-specific names.
- `lean_evolved_bds.m` is the independent all-acceleration-on CBDS reference.
  Its budget is aligned with the production `500*n` default.
- `lean_evolved_bds_original.m` preserves the pre-termination-change lean
  mechanism, while `tests/competitors/lean_evolved_bds_legacy.m` preserves the older
  pre-momentum-duplicate behavior needed by focused regression tests.

The historical `bds_tmp.m` was removed rather than used as an oracle because its
objective handling, helper calls, and stopping behavior were already stale.

## Behavioral contracts

With all acceleration switches disabled, production `bds` must match the
frozen non-accelerated reference under the same explicit algorithm parameters.
The permanent checker covers CBDS, PBDS, RBDS, PADS, and DS.

With all acceleration switches enabled, production `bds` must match
`lean_evolved_bds` for both the default algorithm entry and explicit
`Algorithm = "cbds"`.

Strict equivalence covers the function-evaluation sequence and count, returned
point and value, stopping behavior, exit flag, histories, seeded random
behavior, and the output fields checked by `iseqiv`.

## Verification

Run the permanent acceleration gate from the repository root:

```matlab
addpath("tests");
verify_bds_acceleration
```

It covers 2610 cases:

- 1350 acceleration-off cases across five BDS algorithms;
- 630 acceleration-on cases using the default entry;
- 630 acceleration-on cases using explicit CBDS.

Changes affecting stopping or evaluation accounting must also run:

```matlab
verify_gradient_stopping_threshold
verify_gradient_stop_no_extra_evaluations
verify_gradient_estimate_validity
verify_function_value_reference
verify_bds_momentum_duplicate
verify_bds_auto_alpha_init
```

The full acceptance gate additionally includes `src/unit_test.m`, Code
Analyzer, installation/path/help smoke testing, and local/server hash equality.
