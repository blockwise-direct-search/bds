# Termination issues

This note records three issues found while aligning the termination mechanisms
in `tests/competitors/accelerated_bds_options.m` with the BDS manuscript. The
items are intentionally kept separate from the manuscript edits so that the
implementation, tests, and paper can be updated together after each design
choice is settled.

## 1. Resolved: accept every structurally valid finite gradient estimate

### Resolution

`bds.m` and `accelerated_bds_options.m` now process a reconstructed gradient
exactly when it is a real `n`-by-1 vector and every component is finite:

```matlab
isrealcolumn(grad) && numel(grad) == n && all(isfinite(grad))
```

Magnitude no longer determines availability. Exact zero, very small finite,
and very large finite estimates are retained; estimates containing `NaN` or
`Inf` are rejected. The active lean reference implements the same rule in its
optional estimated-gradient stopping path.

### Why this matters

The estimated gradient stopping mechanism is intended to recognize approximate
stationarity. Discarding the smallest gradient estimates can prevent precisely
that behavior. It also conflicts with the manuscript description, in which
finite symmetric polling values produce an available gradient estimate.

### Regression coverage

`verify_gradient_estimate_validity.m` checks exact zero, nonzero values below
the former lower cutoff, finite values above the former `1e30` upper cutoff,
safe rejection of `NaN` and `Inf`, objective-evaluation accounting,
acceleration-off equivalence with `bds.m`, acceleration-on equivalence with the
active lean reference on a triggered zero-gradient stop, and a nontriggering
comparison with the pre-termination lean snapshot.

### Manuscript synchronization

The implementation now agrees with the manuscript definition of an available
gradient estimate based on finite symmetric polling values, without
machine-dependent norm cutoffs.

## 2. Resolved: use the first finite recent-function-value reference

### Resolution

`bds.m`, `accelerated_bds_options.m`, and the active lean reference now
initialize `F_ref` exactly once, when the incumbent first becomes finite. The
recent function value test remains inactive until both `F_ref` and the complete
sliding window are finite, and its thresholds scale with
`abs(fopt - F_ref)`.

### Why this matters

If the initial evaluation fails, its algorithmic value is `Inf`. Once the
recent value window becomes finite, a threshold involving `abs(fopt - f0)` is
infinite and can trigger termination for the wrong reason. This behavior is
also inconsistent with the solver policy that allows recovery from a failed
initial evaluation.

### Regression coverage

`verify_function_value_reference.m` checks failed-initial-evaluation recovery,
the fixed first-finite reference behavior, invariance under adding a constant
to every finite objective value, unchanged finite-initial-value behavior,
acceleration-off equivalence with `bds.m`, acceleration-on equivalence with
`lean_evolved_bds.m`, and a nontriggering comparison with the pre-change lean
snapshot.

### Manuscript synchronization

The implementation now agrees with the manuscript definition of `F_ref` as the
first finite incumbent value.

## 3. Resolved: use one reference-scaled estimated-gradient threshold

### Resolution

`bds.m`, `accelerated_bds_options.m`, and the active lean reference now stop
when every conservative gradient norm `G` in the window satisfies

```text
G < grad_tol * max(1, G_ref).
```

The public `grad_tol` default is `1e-2`. When `G_ref <= 1`, the right-hand side
is the absolute threshold `grad_tol`; when `G_ref > 1`, the condition is the
relative reduction test `G/G_ref < grad_tol`. The former
`grad_reference_relative_tol` option has been removed.

### Why the gradient and function-value scales differ

The function-value scale `abs(fopt - F_ref)` is zero when `F_ref` is
initialized and then changes throughout the run, so its guarded `min/max`
construction protects a scale that starts at zero and may later become very
large. The gradient reference is different: it is initialized only when a
structurally valid gradient estimate passes the consistency and computed-error
checks, and it is then fixed. The single `max(1, G_ref)` normalization therefore
provides both required regimes without a complementary `min` branch.

The condition expresses reference-scaled stationarity. The relative branch
does not claim that the current gradient is small in an unscaled absolute
sense.

### Historical-result equivalence

The reported accelerated experiments used `omega_g=1e-6` and `nu_g=1e-2` in
the former two-branch condition. For every nonnegative `G_ref`,

```text
omega_g min(1, G_ref) < nu_g max(1, G_ref).
```

The first condition was therefore strictly contained in the second for every
window entry. The new `grad_tol=1e-2` rule is pointwise identical to the
reported configuration, so the benchmark does not need to be rerun.

### Regression coverage

- Boundary tests cover `G_ref < 1`, `G_ref = 1`, and `G_ref > 1`.
- Strict inequality behavior is tested at each threshold.
- A window containing more than one estimate verifies that every entry must be
  below the threshold.
- Acceleration-off cases compare with `bds.m`; an acceleration-on triggering
  case compares with the lean reference.
- The removed option is rejected by all three entry paths.

### Manuscript synchronization

The manuscript formula and parameter table should use the single condition and
`grad_tol=1e-2`. Historical profile data must be described through the exact
equivalence above, not as having been rerun with a different algorithm.
