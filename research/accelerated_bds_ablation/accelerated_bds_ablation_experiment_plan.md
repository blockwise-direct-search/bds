# Accelerated BDS Ablation Experiment Plan

## Goal

这轮实验的目的不是单纯比较 solver 排名，而是回答 accelerated BDS 的机制问题：

1. Which acceleration strategy contributes the most?
2. Can we remove one or more strategies while preserving most gains?
3. Do the same acceleration ideas also work for classical direct search?
4. How far is the original BDS baseline from NOMAD under 200n and 500n budgets?

最终希望得到一个更小、更容易解释、也更接近原始 BDS 框架的 accelerated BDS 版本。

## Files

- `run_accelerated_bds_ablation_group.m`: run a complete Group A, B, C, or D.
- `run_accelerated_bds_ablation_remaining.m`: resume the split Group A experiments.
- `run_accelerated_bds_ablation_D_remaining.m`: resume the split Group D 500n experiment.
- `summaries/`: merged summary PDFs for the completed Group A-D experiments.
- `accelerated_bds_ablation_experiment_results.md`: scores and conclusions.

The runners keep raw OptiProfiler output under `tests/testdata` and place only merged summary
PDFs under this folder. Before calling a runner by function name, add this folder to the MATLAB
path, for example:

```matlab
addpath(fullfile(pwd, 'tests', 'accelerated_bds_ablation'));
run_accelerated_bds_ablation_group('A');
```

## Common Settings

除非特别说明，实验设置统一为：

- Problem library: S2MPJ
- Problem type: unconstrained
- Dimension range: 6-50
- Main budget: 200n function evaluations
- Main StepTolerance: 1e-6
- Ablation features:
  - plain
  - linearly_transformed
- Full baseline-comparison features:
  - plain
  - noisy_1e-1
  - noisy_1e-2
  - noisy_1e-3
  - noisy_1e-4
  - linearly_transformed
  - linearly_transformed_noisy_1e-1
  - linearly_transformed_noisy_1e-2
  - linearly_transformed_noisy_1e-3
  - linearly_transformed_noisy_1e-4

For the 500n sensitivity comparison, use:

- MaxFunctionEvaluations = 500n
- StepTolerance = 1e-12

## Acceleration Switches

The three acceleration strategies in production `src/bds.m` are:

| Short name | Option | Meaning |
| --- | --- | --- |
| memory / search step | `use_productive_direction_memory` | Try a bounded list of previously successful polling directions before the regular polling loop. This is an acceleration search step. |
| pattern direction | `use_iteration_pattern_step` | After a successful iteration, try the normalized total accepted iteration step as a Hooke-Jeeves style pattern direction. |
| momentum | `use_momentum_extrapolation` | Form an exponentially averaged direction from recent successful iteration directions and try it when the pattern direction does not improve. |

Naming convention:

- `baseline`: all three acceleration switches are off.
- `memory-only`: only `use_productive_direction_memory` is on.
- `pattern-only`: only `use_iteration_pattern_step` is on.
- `momentum-only`: only `use_momentum_extrapolation` is on.
- `pattern-momentum`: pattern direction and momentum are on, memory / search step is off.
- `all-on`: all three acceleration switches are on.

## Group A: CBDS Single-Strategy Ablation

Purpose: identify whether each individual strategy improves original CBDS.

Each comparison should use only two solvers in one profile plot.

1. `cbds-baseline-200n` vs `cbds-memory-only-200n`
2. `cbds-baseline-200n` vs `cbds-pattern-only-200n`
3. `cbds-baseline-200n` vs `cbds-momentum-only-200n`

Features:

- plain
- linearly_transformed

Questions answered:

- Does each strategy work by itself?
- Which single strategy has the clearest and most stable gain?
- Is memory / search step strong enough to justify its additional explanation cost?

## Group B: CBDS Minimal Combination

Purpose: decide whether a smaller strategy set can match the all-on solver.

Each comparison should use only two solvers in one profile plot.

1. `cbds-baseline-200n` vs `cbds-pattern-momentum-200n`
2. `cbds-pattern-momentum-200n` vs `accelerated-bds-all-on-200n`
3. `cbds-baseline-200n` vs `accelerated-bds-all-on-200n`

Features:

- plain
- linearly_transformed

Questions answered:

- Is pattern + momentum already enough?
- Does memory / search step add visible value beyond pattern + momentum?
- How large is the total gain of all acceleration strategies over original CBDS?

Decision rule:

- If `pattern-momentum` is close to `all-on`, then consider removing memory / search step from the final solver.
- If `all-on` is clearly better than `pattern-momentum`, keep memory / search step and explain it explicitly as an acceleration search step.

## Group C: DS Generalization

Purpose: test whether the acceleration ideas are specific to CBDS or also help classical direct search.

Each comparison should use only two solvers in one profile plot.

1. `ds-baseline-200n` vs `accelerated-ds-all-on-200n`
2. `ds-baseline-200n` vs `ds-pattern-momentum-200n`
3. `ds-pattern-momentum-200n` vs `accelerated-ds-all-on-200n`

Features:

- plain
- linearly_transformed

Questions answered:

- Do these acceleration strategies also help classical direct search?
- If yes, can we describe them as general direct-search acceleration strategies?
- If no, is the gain mainly due to the interaction between acceleration and the cyclic / block structure of CBDS?

## Group D: Original BDS vs NOMAD

Purpose: measure the gap between the unaccelerated BDS baseline and NOMAD.

Unlike the ablation groups, this group uses the full 10-feature set.

1. `cbds-baseline-200n` vs `nomad-200n`
2. `cbds-500n` vs `nomad-500n`

Features:

- plain
- noisy_1e-1
- noisy_1e-2
- noisy_1e-3
- noisy_1e-4
- linearly_transformed
- linearly_transformed_noisy_1e-1
- linearly_transformed_noisy_1e-2
- linearly_transformed_noisy_1e-3
- linearly_transformed_noisy_1e-4

Questions answered:

- How far is original CBDS from NOMAD before acceleration?
- Is the gap mainly on rotated problems, noisy problems, or both?
- Does increasing the budget from 200n to 500n change the qualitative comparison?

## Expected Outcomes

After running these experiments, we should be able to decide:

1. Which strategy is the strongest single contributor.
2. Whether memory / search step should be kept or removed.
3. Whether pattern + momentum is the minimal effective combination.
4. Whether the acceleration is CBDS-specific or works for DS as well.
5. Whether accelerated BDS mainly improves the original BDS baseline on plain/noisy problems, rotated problems, or both.

The final solver should prioritize the smallest strategy set that preserves most of the observed numerical gain.
