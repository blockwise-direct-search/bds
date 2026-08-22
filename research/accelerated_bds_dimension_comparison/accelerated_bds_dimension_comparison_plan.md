# Accelerated BDS 维数区间比较实验计划

## 1. 目标

本轮实验研究 `Original BDS`、`Accelerated BDS` 和 `NEWUOA` 在不同维数区间上的
相对表现。最终需要得到六份严格的 two-solver `pairwise profiles`，每份均包含十个
`features`，并将十份 feature-level `summary PDF` 按固定顺序合并。

这里的六个目标 comparisons 不等于六套新的 `raw experiments`。OptiProfiler 的
`load` 和 `solvers_to_load` 可以从包含三个 solvers 的既有 raw data 中选择两个
solvers，然后重新计算 pairwise reference、profiles 和 normalized scores。因此：

- dimensions 1-5 只需新跑一套 three-solver raw experiment；
- dimensions 6-50 使用已有 raw data，只做 `pairwise redraw`；
- dimensions 51-200 只需新跑一套 three-solver raw experiment。

换言之，最终需要六份 pairwise outputs，但只需新增两套 raw experiment matrices。

## 2. Solver 定义

| 显示名称 | Implementation | Profiler alias | 必须设置 |
| --- | --- | --- | --- |
| `Original BDS` | `src/bds.m`, all acceleration switches off | `cbds-baseline-200n` | `Algorithm = 'cbds'`, all three acceleration switches disabled, `MaxFunctionEvaluations = 200n`, `StepTolerance = 1e-6` |
| `Accelerated BDS` | production `src/bds.m` | `accelerated-bds-all-on-200n` | `Algorithm = 'cbds'`, all three acceleration switches enabled, `MaxFunctionEvaluations = 200n`, `StepTolerance = 1e-6` |
| `NEWUOA` | PRIMA MATLAB implementation | `newuoa-200n` | `maxfun = 200n` |

三个 acceleration switches 为：

- `use_productive_direction_memory = true`;
- `use_iteration_pattern_step = true`;
- `use_momentum_extrapolation = true`.

旧数据中的 solver name `lean_evolved_bds_options` 是 `Accelerated BDS` 的 historical
name。该 solver 的 all-on behavior 已通过 `tests/verify_bds_acceleration.m` 与固定的
`lean_evolved_bds.m` reference 严格核验。Redraw 时只修改 display name，不修改任何
history data。

## 3. 共同设置

除第 7 节注明的已有数据外，新 raw experiments 使用以下统一设置：

- Problem library: `S2MPJ`
- Problem type: unconstrained (`u`)
- Function-evaluation budget: `200n`
- Random seed: `0`, explicitly set
- `plain`: `n_runs = 1`
- All other features: `n_runs = 5`
- Solver order: `Original BDS`, `Accelerated BDS`, `NEWUOA`
- Raw data location: `research/accelerated_bds_dimension_comparison/testdata`
- Merged pairwise summaries: `research/accelerated_bds_dimension_comparison/summaries`

十个 features 按照以下固定顺序合并：

1. `plain`
2. `noisy_1e-1`
3. `noisy_1e-2`
4. `noisy_1e-3`
5. `noisy_1e-4`
6. `linearly_transformed`
7. `linearly_transformed_noisy_1e-1`
8. `linearly_transformed_noisy_1e-2`
9. `linearly_transformed_noisy_1e-3`
10. `linearly_transformed_noisy_1e-4`

`StepTolerance` 只适用于两个 BDS implementations。`NEWUOA` 保留自己的 stopping rules；
三者统一使用 `200n` function-evaluation budget，以此保证 fairness。

## 4. 六个目标 Pairwise Comparisons

| ID | Dimension range | Pairwise comparison | Raw-data source | 当前状态 |
| --- | ---: | --- | --- | --- |
| E1 | 1-5 | `Original BDS` vs `Accelerated BDS` | New Low-dimensional raw experiment | `RAW-PENDING` |
| E2 | 51-200 | `Original BDS` vs `Accelerated BDS` | New High-dimensional raw experiment | `RAW-PENDING` |
| E3 | 1-5 | `Accelerated BDS` vs `NEWUOA` | New Low-dimensional raw experiment | `RAW-PENDING` |
| E4 | 6-50 | `Accelerated BDS` vs `NEWUOA` | Existing three-solver raw data | `REDRAW-ONLY` |
| E5 | 51-200 | `Original BDS` vs `NEWUOA` | New High-dimensional raw experiment | `RAW-PENDING` |
| E6 | 51-200 | `Accelerated BDS` vs `NEWUOA` | New High-dimensional raw experiment | `RAW-PENDING` |

E4 不得重新运行任何 solver。它只加载既有 histories，通过 `solvers_to_load` 去掉 BFGS，
然后重新计算 two-solver profiles 和 scores。

## 5. Raw Experiment L：Dimensions 1-5

针对全部十个 features，新运行一套 three-solver raw experiment：

```matlab
options.mindim = 1;
options.maxdim = 5;
options.plibs = 's2mpj';
options.seed = 0;
options.max_eval_factor = 200;
options.solver_names = { ...
    'cbds-baseline-200n', ...
    'accelerated-bds-all-on-200n', ...
    'newuoa-200n' ...
};
```

十个 features 全部完成后，从保存的数据生成以下 pairwise outputs：

- E1: `solvers_to_load = [1, 2]`;
- E3: `solvers_to_load = [2, 3]`.

E1 和 E3 展示的 normalized scores 必须是重新计算的 two-solver scores，不能把 raw
experiment 中的 three-solver scores 当作 pairwise results 报告。

## 6. Raw Experiment H：Dimensions 51-200

针对全部十个 features，新运行一套 three-solver raw experiment；solver order 和 common
settings 与 Experiment L 完全相同：

```matlab
options.mindim = 51;
options.maxdim = 200;
options.plibs = 's2mpj';
options.seed = 0;
options.max_eval_factor = 200;
options.solver_names = { ...
    'cbds-baseline-200n', ...
    'accelerated-bds-all-on-200n', ...
    'newuoa-200n' ...
};
```

从每个已保存的 feature 生成三组 pairwise outputs：

- E2: `solvers_to_load = [1, 2]`;
- E5: `solvers_to_load = [1, 3]`;
- E6: `solvers_to_load = [2, 3]`.

这一套 raw experiment 同时提供三个 High-dimensional comparisons。Redraw 期间不得再次
调用任何 solver。

## 7. E4 使用的 Existing Raw Experiment

完整的 dimensions 6-50、ten-feature raw data 已经存在于服务器：

```text
/home/lhtian97/Work/bds/tests/testdata/
lean_evolved_bds_options_newuoa_200n_bfgs_200n_6_50_10features_s2mpj_20260702_175908
```

原始 solver order 为：

1. `lean_evolved_bds_options` (current display name: `Accelerated BDS`)
2. `newuoa-200n` (`NEWUOA`)
3. `bfgs-200n` (excluded from E4)

对每个 feature，加载对应 timestamp，并使用：

```matlab
options.load = '<feature timestamp>';
options.solvers_to_load = [1, 2];
options.solver_names = {'Accelerated BDS', 'NEWUOA'};
options.max_eval_factor = 200;
benchmark(options);
```

OptiProfiler 会在 profile processing 之前截取所有 solver-indexed raw fields。因此 BFGS
不会影响 pairwise reference values、ratios、curves 或 normalized scores。

已经保存的 feature timestamps 为：

| Feature | Timestamp |
| --- | --- |
| `plain` | `20260702_180056` |
| `noisy_1e-1` | `20260702_181457` |
| `noisy_1e-2` | `20260702_183504` |
| `noisy_1e-3` | `20260702_185620` |
| `noisy_1e-4` | `20260702_192009` |
| `linearly_transformed` | `20260702_194704` |
| `linearly_transformed_noisy_1e-1` | `20260702_202858` |
| `linearly_transformed_noisy_1e-2` | `20260702_205432` |
| `linearly_transformed_noisy_1e-3` | `20260702_211820` |
| `linearly_transformed_noisy_1e-4` | `20260702_214338` |

这套 historical raw experiment 对 `plain` 和其他 features 都使用了 `n_runs = 5`。由于
`plain` 不引入 feature randomness，并且保留的两个 solvers 都是 deterministic，五个
plain runs 应当是 exact duplicates。接受合并后的 E4 PDF 之前，必须直接检查
`data_for_loading.mat` 中五次结果是否完全相同。这是 data-integrity check，不是重跑 E4
的理由；E4 仍然只使用 existing raw data 完成 redraw。

## 8. Pairwise Redraw 规则

每次 redraw 必须满足：

1. Load the matching feature's `data_for_loading.mat`; a merged PDF alone is insufficient.
2. Use solver indices from the original raw-data order.
3. Keep exactly two solvers with `solvers_to_load`.
4. Recompute profiles and normalized scores after solver truncation.
5. Preserve the original problems, feature realizations, runs, histories, and budget.
6. Give the output an unambiguous pairwise `benchmark_id` and solver display names.
7. Display the exact feature and noise level in every profile title.
8. Do not modify the OptiProfiler package source.

Redraw 应调用 OptiProfiler 的 load path，而不是重新运行 `profile_optiprofiler` solver
wrappers。可以新增 repository-level runner 来组织 load、title normalization 和 PDF merge，
但不得修改 OptiProfiler package source。

## 9. 必须生成的 Outputs

每个 comparison 生成一份合并后的 ten-feature summary：

1. `summary_original_bds_accelerated_bds_200n_u_1_5_10features_s2mpj_<timestamp>.pdf`
2. `summary_original_bds_accelerated_bds_200n_u_51_200_10features_s2mpj_<timestamp>.pdf`
3. `summary_accelerated_bds_newuoa_200n_u_1_5_10features_s2mpj_<timestamp>.pdf`
4. `summary_accelerated_bds_newuoa_200n_u_6_50_10features_s2mpj_<timestamp>.pdf`
5. `summary_original_bds_newuoa_200n_u_51_200_10features_s2mpj_<timestamp>.pdf`
6. `summary_accelerated_bds_newuoa_200n_u_51_200_10features_s2mpj_<timestamp>.pdf`

十个 feature-level PDFs 必须按照第 3 节规定的顺序合并。

## 10. Validation Checklist

将 comparison 标记为完成之前，必须确认：

- every feature has `time_stamp_*.txt` and `test_log/data_for_loading.mat`;
- solver names, solver order, dimension range, problem library, budget, and run count are correct;
- no solver exceeds `200n` function evaluations;
- abnormal terminations and output fallbacks are audited and reported;
- pairwise scores come from the redraw, not from a three-solver profile;
- feature titles distinguish all noise levels and transformed/noisy combinations;
- the merged PDF contains exactly ten summaries in the required order;
- E4 performs no new objective evaluations and makes no solver calls.

## 11. Execution Summary

| Work item | 是否需要执行 solver？ | 提供的 pairwise outputs |
| --- | --- | --- |
| New Low-dimensional raw experiment, dimensions 1-5 | Yes, once for three solvers | E1 and E3 |
| Existing Middle-dimensional raw experiment, dimensions 6-50 | No | E4 |
| New High-dimensional raw experiment, dimensions 51-200 | Yes, once for three solvers | E2, E5, and E6 |

因此，实际工作量是两套新的 three-solver raw experiment matrices，加上六个 pairwise
redraw-and-merge jobs。E4 严格限定为 redraw job。
