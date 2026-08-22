# Deferred review of the production `bds` main function

This note records possible cleanup in the main body of
`src/bds.m` that is intentionally deferred until the solver's
final structure is clear.

These items are not current correctness defects. They do not add objective
function evaluations, which are normally the dominant cost in derivative-free
optimization, and the proposed cleanup must not alter the estimated-gradient
stopping criterion. Deciding too early may also create unnecessary rework while
the acceleration helpers and their interfaces are still evolving.

## Deferred cleanup candidates

### 1. Skip unused gradient-estimation work

The main loop currently estimates a gradient whenever every visited batch
qualifies, even when both of the following options are false:

- `output_grad_hist`
- `use_estimated_gradient_stop`

In that configuration, the estimated gradient and its histories have no
observable consumer. A later revision could introduce a clearly named condition
such as `need_gradient_estimate` and execute the estimation pipeline only when at
least one option needs it. The gradient histories could likewise be updated only
when `output_grad_hist` is true.

Reasons to defer:

- This saves internal linear-algebra and history-management work, not objective
  function evaluations.
- The best location for the condition depends on the final division of
  responsibilities between the main loop and the gradient-related helpers.
- The gradient-stopping path must remain byte-for-byte equivalent in behavior
  when `use_estimated_gradient_stop` is true.

### 2. Compute `norm(grad)` once when it has several consumers

The valid-gradient and gradient-stopping block evaluates `norm(grad)` multiple
times. A local `grad_norm` would have a clear meaning and several genuine
consumers, unlike a temporary variable that merely renames a one-time
expression.

Reasons to defer:

- The performance benefit is small compared with an objective evaluation.
- The final gradient-stopping structure may move this computation into a helper,
  making a main-loop variable unnecessary.

### 3. Maintain `fopt_window` only when function-value stopping is enabled

`fopt_window` is initialized and shifted on every iteration even when
`use_function_value_stop` is false. Initialization and updates could be guarded
by that option.

Reasons to defer:

- This is a small allocation and array-update cleanup, not an objective-evaluation
  saving.
- The final form of the stopping logic should determine whether conditional
  initialization is clearer than unconditional state with a conditional
  consumer.

### 4. Remove the duplicate initialization of `invalid_points`

`invalid_points` is initialized before allocating the optional point history and
then initialized again inside the `output_xhist` branch before any intervening
write. The second initialization is redundant in the current code.

Reason to defer:

- It has negligible runtime cost, and the preferred initialization site depends
  on the final organization of optional output state.

## Separate cross-implementation issue

When an earlier condition has already set `terminate` and `exitflag`, the later
function-value or estimated-gradient stopping checks may still run and overwrite
that exit flag. This behavior is shared by production `src/bds.m` and its frozen
references. It must not be changed in only one implementation, because doing so
would invalidate the corresponding equivalence contract.

If revisited, it should be treated as an algorithm-semantics decision covering
all corresponding solver implementations, with an explicitly chosen precedence
for simultaneous termination conditions. It is not part of routine code-style
cleanup.

## Code Analyzer observations that do not require immediate action

MATLAB Code Analyzer currently reports dynamic-growth warnings for histories
such as `invalid_points`, `alpha_hist`, `grad_hist`, `grad_xhist`, and `grad_iter`.
Preallocation should not be applied mechanically: some histories are optional,
and unconditional large allocations may be less appropriate than controlled
growth. Reconsider these warnings only after the final output and helper
interfaces are settled.

## Decision criteria for the final review

Reconsider each candidate after the acceleration and gradient-related helper
interfaces stabilize. Apply it only if it does at least one of the following
without obscuring the algorithm:

- removes work whose result has no consumer;
- gives optional state a clearer lifetime;
- reduces duplicated computation with multiple real consumers;
- makes ownership between the main function and helpers clearer.

Do not apply a change merely to reduce the line count or silence a static warning.

## Required verification for any later change

Any implementation of the deferred items must pass all existing behavioral
gates:

1. With all acceleration switches disabled, `src/bds.m` matches
   `tests/competitors/bds_without_acceleration_reference.m`.
2. With all acceleration switches enabled, `src/bds.m` matches
   `lean_evolved_bds.m` through both the
   default and explicit `Algorithm="cbds"` paths.
3. `verify_gradient_stop_no_extra_evaluations` passes.
4. The targeted gradient-stopping test with
   `use_gradient_reference_consistency=false` passes.
