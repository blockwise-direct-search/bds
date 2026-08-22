# Automatic Initial Step Size

本目录只保留 automatic initial step size 调参所需的 protocol、可复现脚本和正式结果。
实验在三个 acceleration switches 全部开启的 BDS 上进行；baseline 使用 unit initial
steps，即“不启用 automatic initial-step strategy”的 accelerated BDS。

## 最值得看的结果

以下两张图是用户关心的直接比较：`(c_x,c_tau)=(1,1)` 对 accelerated unit-step
baseline。它们均由 OptiProfiler commit
`e8a4c44f555eafaddc3530b68c54fe1a78459cd9` 的
`benchmark(..., load=...)` 原生生成，覆盖 `1e-1` 至 `1e-10`，没有 custom plotting：

- `200*N`: `(1,1)` vs baseline
- `500*N`: `(1,1)` vs baseline

The two PDFs are generated server-side and are intentionally excluded by the
repository-wide PDF ignore rule. Their machine-readable curves and scores are
versioned as `results/cx1_ctau1_vs_unit_200n.mat` and
`results/cx1_ctau1_vs_unit_500n.mat`; generation provenance is recorded in
`results/pairwise_results.txt`.

全部 16 个 parameter pairs 各自与 baseline 组成 two-solver pool 后的 OptiProfiler
scores，以及 full-17 common-pool scores 和结论，统一记录在
[`results/SCORES.md`](results/SCORES.md)。

## 当前结论

`c_x=1` 明显优于更小的 `c_x`；current automatic rule `(1,1)` 在 `200*N` 和
`500*N` 都明显优于 accelerated unit-step baseline。`(1,2)` 的 full-pool aggregate
score 略高于 `(1,1)`，但优势仅为 `8.12e-5` 和 `2.70e-4`，不足以支持修改
production rule。因此 current engineering choice 是继续使用 `(1,1)`，不进行 local
refinement。

## Accelerated auto BDS 停机策略

在 acceleration 全开且 automatic initial-step rule 为 `(c_x,c_tau)=(1,1)` 的基础上，
function-value 与 pure-gradient 两种 stopping mechanisms 都已经调好。

function-only 推荐：

```matlab
options.use_function_value_stop = true;
options.func_window_size = 20;
options.func_tol = 1e-6;
options.use_estimated_gradient_stop = false;
```

final pure-gradient 推荐：

```matlab
options.use_function_value_stop = false;
options.use_estimated_gradient_stop = true;
options.grad_window_size = 1;
options.grad_tol = 1e-2;
options.use_gradient_reference_consistency = true;
options.grad_reference_finite_difference_error_tol = 1/30;
```

function-only 在 `plain` 和 `linearly_transformed` 的五个 output-based targets 上均保持
`122/122` solved fraction，同时相对 no-stop 分别减少 `19.46%` 和 `15.56%`
evaluations。pure-gradient 同样保持全部 targets，分别节省 `3618` 和 `17393` 次
evaluations，并独立触发 `14+11=25` 个 cases；solver 内不增加任何 function
evaluation。完整边界、OptiProfiler scores、failure diagnosis 和原生图见
[`stopping/RESULTS.md`](stopping/RESULTS.md)。

production combined stop 对两个 criteria 取 OR；两者都只有在本轮 post-poll
acceleration 没有成功时才允许触发。combined 已通过同一 formal gate，相对 no-stop 在
`plain` 节省 `20.15%`，在 `linearly_transformed` 节省 `18.78%` evaluations。
pure-gradient investigation 已经 close。

automatic initial step-size 的 primary decision 已记录在 protocol 和 score 文件中；
停机策略的 pure-gradient investigation 也已 close。若要继续做论文级 formal close，
按 [`TODO_auto_initial_step_size_tuning.md`](TODO_auto_initial_step_size_tuning.md) 中的
decision record 补充 paired analysis、`c_tau` audit 和 focused regression record。

## 文件导航

- `run_auto_initial_step_size_500n_full_factorial.m` 与对应 shell script：正式
  122-problem、17-configuration server run；
- `generate_pairwise_baseline_results.m` 与对应 shell script：从同一 `500*N` raw
  histories 重算全部 pairwise scores，并生成上面的两张 direct-comparison PDF；
- `results/run_manifest.*`：正式 run 的 environment、problem、solver 与 option record；
- `results/pairwise_results.*`：pairwise scores 和 figure provenance；
- `results/cx1_ctau1_vs_unit_*.mat`：两张 direct-comparison 图对应的 curves 和 scores。
- `stopping/GRADIENT_STOP_INVESTIGATION.md`：pure-gradient failure diagnosis、parameter
  search 和 formal boundary；
- `stopping/final_gradient_profiles/`：no-stop vs final pure-gradient 的 OptiProfiler 原生
  `500N/200N` profiles 与 machine-readable scores；
- `stopping/*no_stop_function_gradient_combined_500n_optiprofiler.pdf`：no-stop、
  function-only、pure-gradient 与 combined OR 的同池 OptiProfiler 原生 summaries。

258 MB 的正式 `data_for_loading.mat` 保留在 server manifest 记录的路径，不在 repository
中重复保存。目录中不保留 pilot、legacy summary、generation log、status marker 或其他
archive/intermediate artifacts。
