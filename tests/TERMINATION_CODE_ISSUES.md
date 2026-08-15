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

## 3. One estimated gradient stopping threshold is redundant

### Current behavior

The solver stops when every value in the gradient window satisfies at least one
of

```text
G < omega_g min(1, G_ref)
G < nu_g    max(1, G_ref).
```

The reference experimental configuration uses
`omega_g = 1e-6` and `nu_g = 1e-2`. For every positive `G_ref`,

```text
omega_g min(1, G_ref) < nu_g max(1, G_ref).
```

The first condition is therefore always contained in the second and never
changes the stopping decision in the reported configuration.

### Why this matters

The interface and manuscript present two complementary thresholds, but the
reported parameter values implement only the second one. A reviewer may
reasonably ask why the additional parameter and branch exist.

### Design decision required

Choose one of the following directions before changing the implementation.

1. Replace the two branches by the single threshold that represents the
   intended absolute or relative stopping rule.
2. Redesign the two threshold formulas so that they express distinct absolute
   and reference relative criteria.
3. Retain the formulas but choose and justify parameter values for which both
   branches can affect the decision.

### Tests to add

- Boundary tests cover `G_ref < 1`, `G_ref = 1`, and `G_ref > 1`.
- Each retained branch has at least one test case in which it alone determines
  the stopping decision.
- Strict inequality behavior is tested at each threshold.
- The code and the mathematical condition in the manuscript are verified to be
  equivalent for a window containing more than one estimate.

### Manuscript synchronization

Once the design is chosen, update the stopping formula, its explanation, the
parameter table, and the experimental wrapper as one change. Existing profile
data must not be described as using a revised rule unless the experiments are
rerun or equivalence with the historical rule is established.
