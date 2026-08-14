# Open termination issues

This note records three issues found while aligning the termination mechanisms
in `tests/competitors/accelerated_bds_options.m` with the BDS manuscript. The
items are intentionally kept separate from the manuscript edits so that the
implementation, tests, and paper can be updated together after each design
choice is settled.

## 1. Zero and very small estimated gradients are discarded

### Current behavior

After reconstructing `grad`, `accelerated_bds_options.m` processes it only when

```matlab
(norm(grad) <= sqrt(n)*1e30) && (norm(grad) > 10*sqrt(n)*eps)
```

Consequently, an exact zero gradient and sufficiently small finite gradients
are discarded before the reference scale or stopping window can be updated.
The upper bound also retains the obsolete finite threshold `1e30`, although
failed objective evaluations are now represented by `Inf`.

### Why this matters

The estimated gradient stopping mechanism is intended to recognize approximate
stationarity. Discarding the smallest gradient estimates can prevent precisely
that behavior. It also conflicts with the manuscript description, in which
finite symmetric polling values produce an available gradient estimate.

### Recommended implementation direction

Replace the norm thresholds by structural and finiteness checks. In particular,
verify that the reconstructed vector has the expected dimension and that every
component is finite. Let the error and stopping tests decide whether a finite
small gradient is reliable.

### Tests to add

- A constant or stationary quadratic objective produces a zero estimated
  gradient that reaches the reference and stopping logic.
- A finite gradient with norm below `10*sqrt(n)*eps` is not discarded merely
  because of its size.
- A gradient containing `NaN` or `Inf` is rejected safely.
- Processing the estimate introduces no additional objective evaluations.

### Manuscript synchronization

After the implementation is corrected, the manuscript definition of an
available gradient estimate can continue to depend on finite symmetric polling
values without mentioning machine dependent norm cutoffs.

## 2. The recent function value reference is not the first finite value

### Current behavior

The recent function value test scales its thresholds with `abs(fopt - f0)`,
where `f0` is the algorithmic value of the initial evaluation. The manuscript
instead defines the reference as the first finite incumbent value
`F_ref = F_{t_f}`.

### Why this matters

If the initial evaluation fails, its algorithmic value is `Inf`. Once the
recent value window becomes finite, a threshold involving `abs(fopt - f0)` is
infinite and can trigger termination for the wrong reason. This behavior is
also inconsistent with the solver policy that allows recovery from a failed
initial evaluation.

### Recommended implementation direction

Maintain a reference that is initialized exactly once, when the incumbent first
becomes finite. Do not apply the recent function value test until both this
reference and a complete finite window are available. Use the same reference in
the implementation and manuscript.

### Tests to add

- The initial evaluation returns `NaN` or raises an error, a later trial is
  finite, and the solver does not stop merely because the original `f0` was
  infinite.
- The recorded reference equals the first finite incumbent and remains fixed.
- Adding a constant to every finite objective value leaves the stopping
  iteration unchanged.
- Runs with a finite initial evaluation retain their intended behavior.

### Manuscript synchronization

The current manuscript uses the first finite incumbent value. If a different
reference policy is chosen in code, the definition of `F_ref` and the failed
initial evaluation discussion must be revised together.

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

