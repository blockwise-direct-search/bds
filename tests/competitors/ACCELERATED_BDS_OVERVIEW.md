# Accelerated BDS overview

This document records the current role, behavior contract, and verification
entry points of `accelerated_bds_options.m`. Historical refactor plans and
one-time implementation prompts are intentionally not retained here; Git
history is the archive for that process.

## Current role

- `lean_evolved_bds.m` is the active lean reference for accelerated BDS. Its
  optional third argument enables focused function-value and estimated-gradient
  stopping comparisons; the default two-argument behavior remains unchanged.
- `lean_evolved_bds_original.m` is the snapshot immediately before the
  first-finite function-value reference was added. The older pre-momentum-
  deduplication behavior remains in `misc/lean_evolved_bds_legacy.m`.
- `accelerated_bds_options.m` is the configurable experimental solver. It does
  not call `src/bds.m` directly or indirectly.
- The following acceleration mechanisms currently belong only to
  `accelerated_bds_options.m` and have not been migrated into `src/bds.m`:
  - productive-direction memory;
  - iteration pattern steps;
  - momentum extrapolation.
- Their public switches are `use_productive_direction_memory`,
  `use_iteration_pattern_step`, and `use_momentum_extrapolation`.
- All three switches default to `true`, preserving the historical accelerated
  reference behavior for the default base algorithm.
- The calibrated defaults are
  `productive_direction_memory_size = min(n, 5)` and
  `momentum_decay = 0.6`.

## Behavior contract

With all three acceleration switches disabled,
`accelerated_bds_options.m` must match `src/bds.m` under the same explicit
solver options for every algorithm covered by the strict checker:

```text
cbds, pbds, rbds, pads, ds
```

With all three acceleration switches enabled, it must match
`lean_evolved_bds.m` for both of the following entry paths:

```text
default base algorithm
Algorithm = "cbds"
```

The acceleration switches are otherwise orthogonal to `Algorithm`. For
example, enabling them with `Algorithm = "pbds"` defines an accelerated PBDS
variant, but no equivalence with `lean_evolved_bds.m` is claimed for that
combination.

Strict equivalence covers the complete function-evaluation sequence and count,
returned point and value, stopping behavior, exit flag, histories, random
behavior, and all other outputs checked by `iseqiv`.

## Verification

Run the acceleration equivalence gate from the repository root:

```matlab
addpath("tests");
verify_bds_acceleration
```

The current checker covers 2160 cases:

- 900 acceleration-off cases across `cbds`, `pbds`, `rbds`, `pads`, and `ds`;
- 630 acceleration-on cases using the default entry path;
- 630 acceleration-on cases using explicit `Algorithm = "cbds"`.

Changes that touch gradient stopping or evaluation bookkeeping must also run:

```matlab
addpath("tests");
verify_gradient_stop_no_extra_evaluations
verify_gradient_estimate_validity
```

These focused checks verify that the estimated-gradient stop is activated,
that its finalized defaults match the corresponding explicit options, that
zero and every other structurally valid finite estimate remain available while
`NaN` and `Inf` are rejected, and that the recorded function count and
histories include every objective evaluation.

Changes to recent-function-value stopping must also run:

```matlab
addpath("tests");
verify_function_value_reference
```

This check covers failed-initial-evaluation recovery, the fixed first-finite
reference, translation invariance, finite initial values, a nontriggering lean
snapshot comparison, and acceleration-off/on equivalence.

## Related active documents

- `ACCELERATED_BDS_ACCELERATION_INTERFACE_CONTRACTS.md` records the design
  rationale and current state/config/result boundary of the two acceleration
  phase helpers. It should be reviewed together with those helpers and reduced
  if their final function headers make part of it redundant.
- `ACCELERATED_BDS_MAIN_FUNCTION_DEFERRED_REVIEW.md` records main-function
  cleanup candidates intentionally deferred until the final solver structure
  is clear.
