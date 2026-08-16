# Accelerated auto BDS 停机参数结果

## 最终结论

在 acceleration 全开、automatic initial step `(c_x,c_tau)=(1,1)` 的基础上，已经找到
安全且具有独立作用的 pure-gradient stopping strategy：

```matlab
options.use_function_value_stop = false;
options.use_estimated_gradient_stop = true;
options.grad_window_size = 1;
options.grad_tol = 1e-2;
options.use_gradient_reference_consistency = true;
options.grad_reference_finite_difference_error_tol = 1/30;
```

最后两个 reference parameters 的算法语义是：先要求同一 `xbase` 上两个连续 gradient
estimates 的 relative difference 不超过 `0.1`，才允许初始化 reliable reference；随后
每个 window entry `G` 必须满足
`G < grad_tol*max(1,reliable_reference_grad_norm)`。因此 `grad_tol=1e-2` 在 reference
不超过 1 时是 absolute tolerance，在 reference 大于 1 时是 relative tolerance。

该 pure-gradient strategy 在 solver 内不增加任何 function evaluation。它只复用正常
polling 已经得到的 points 与 function values；true gradient 仅用于离线 failure diagnosis。
而且与 function-value stop 一样，只有本轮 post-poll acceleration 没有成功时才允许
触发，避免在 acceleration 仍能推进时停机。

## Frozen protocol

- problems：冻结的 122 个 unconstrained S2MPJ problems，dimension `6:50`；
- features：`plain`、`linearly_transformed`；
- `n_runs=1`，seed `0`，budget `500*N`；
- OptiProfiler targets：`tau=10^-1,...,10^-5`；
- base solver：三个 acceleration switches 全开，automatic initial step `(1,1)`；
- gate：两种 feature、五个 targets 的 output solved fraction 都不得低于 no-stop；
- 通过 gate 后，比较 total evaluations 与独立 activation。

## Final four-way result

四种 strategies 属于同一 benchmark/common-target pool。表中 solved 是五个 targets 的
最小值。

| Feature | Strategy | Minimum solved | Evaluations | Savings vs no-stop | Activations |
|---|---|---:|---:|---:|---:|
| `plain` | no-stop | `122/122` | `443927` | `0` | `0` |
| `plain` | function-only, `fw=20,ft=1e-6` | `122/122` | `357520` | `86407` | `76` |
| `plain` | final pure-gradient | `122/122` | `440309` | `3618` | `14` |
| `plain` | final combined OR | `122/122` | `354495` | `89432` | `81` |
| `linearly_transformed` | no-stop | `122/122` | `534414` | `0` | `0` |
| `linearly_transformed` | function-only, `fw=20,ft=1e-6` | `122/122` | `451251` | `83163` | `70` |
| `linearly_transformed` | final pure-gradient | `122/122` | `517021` | `17393` | `11` |
| `linearly_transformed` | final combined OR | `122/122` | `434060` | `100354` | `77` |

pure-gradient 合计节省 `21011` 次 evaluations，并在 25 个 feature-problem cases 上独立
触发。它的节省小于 function-only，但这不影响其独立有效性：两个 stopping mechanisms
现在都具有各自的 benchmark evidence。production combined stop 对二者取 OR，同时保留
共同的 post-poll acceleration failure gate。combined 相对 function-only 在 `plain`
额外节省 `3025` 次，在 `linearly_transformed` 额外节省 `17191` 次；因此
pure-gradient 在 combined strategy 中提供了实际增益，不是只重复 function-only。

combined 相对 no-stop 的 reduction 为：

- `plain`：节省 `89432` 次，即 `20.15%`；
- `linearly_transformed`：节省 `100354` 次，即 `18.78%`。

同池 OptiProfiler output-performance scores 如下；score 只在本 four-solver pool 内解释：

| Feature | no-stop | function-only | pure-gradient | combined OR |
|---|---:|---:|---:|---:|
| `plain` | `0.8940` | `0.9852` | `0.9114` | `1.0000` |
| `linearly_transformed` | `0.8866` | `0.9689` | `0.9186` | `1.0000` |

五个 targets 上每个 strategy 的 score 相同，因为各 solver 在五个 tolerances 上的相对
排序一致；每个 strategy 的 solved fraction 均为 `1.0`。

正式的两张 four-way summary PDFs 从同一份 raw histories 通过 OptiProfiler
`benchmark(load=...)` 原生重绘，没有重新运行 solver。图中仅将内部 solver IDs 替换为
`No-stop baseline`、`Function-only stop`、`Gradient-only stop` 和
`Combined OR stop` 四个 display names；重绘后的 scores 保存在
`final_stopping_native_scores.mat`，与原始 score artifacts 一致（仅有 machine-epsilon
量级的浮点舍入差）。

## Boundary 与选择依据

formal boundary run 给出：

| `rho` | `plain` minimum solved | transformed minimum solved | Total savings |
|---:|---:|---:|---:|
| `0.0100` | `122/122` | `122/122` | `21011` |
| `0.0110` | `122/122` | `122/122` | `21062` |
| `0.0115` | `122/122` | `121/122` | `21368` |

`rho=0.0115` 在 `linearly_transformed/PALMER2C` 的 `tau=1e-5` target 上失败；
`rho=0.011` 只比 `0.01` 多省 51 次。因此选择自然、易解释且离失效边界更远的
`rho=0.01`。

固定 `rho=0.01` 时，`consistency_tol=0.1` 与 `0.3` 结果完全相同，而 `0.5`
丢失一个 problem；因此取安全平台左端点 `0.1`。`grad_window_size=1` 比更大的 windows
有更多安全 activation。历史配置中的 `grad_tol=1e-6` 对最终判断没有作用，因为
`rho=1e-2` 的 `max` threshold 对每个非负 reference 都严格更大；当前接口将有效的
`rho=1e-2` 直接记为唯一的 `grad_tol=1e-2`。

## 为什么原 criterion 会失败

旧 criterion 的 failure chain 是：

1. early gradient estimate 在部分 transformed high-curvature cases 上极度失真；
2. 固定 `lipschitz_constant=1e3` 的 error bound 比 actual error 小很多数量级；
3. 第一个 estimate 永久污染 `reference_grad_norm`；
4. reference-scaled fallback threshold 被放大，导致错误早停。

代表性数据：

| Case | Wrong stop | `norm(g_est)` | `norm(g_true)` | Actual error / bound |
|---|---:|---:|---:|---:|
| transformed `SBRYBND` | `181` | `6.69e14` | `1.28e7` | `5.98e17` |
| transformed `SCURLY20` | `1044` | `3.72e9` | `3.08e7` | `5.72e13` |

`plain/POWERSUM` 则证明只调整 `lipschitz_constant` 不够：错误停止时 estimate
`145.350063` 与 true norm `145.350061` 很准，问题来自 early reference
`8.34e11`。所以最终修正针对 reference reliability，而不是继续调主观 Hessian
Lipschitz guess。

## 500N/200N 原生 profiles

四张 pairwise 图均由 OptiProfiler 原生 `benchmark(load=...)` 生成，没有 custom
plotting，也没有重跑 solver。`200N` 使用每个 problem 的 `200*N` history prefix，并在
该 prefix 上重新计算 `200N` common targets。

| Feature | Horizon | no-stop output-performance score | pure-gradient score | Minimum solved |
|---|---:|---:|---:|---:|
| `plain` | `500N` | `0.949469743` | `1.000000000` | both `122/122` |
| `plain` | `200N` | `0.951238341` | `1.000000000` | both `122/122` |
| `linearly_transformed` | `500N` | `0.968006662` | `1.000000000` | both `122/122` |
| `linearly_transformed` | `200N` | `0.971470871` | `1.000000000` | both `122/122` |

## Verification 与 provenance

- `verify_bds_acceleration`：acceleration off 与 `bds.m` 在五种 Algorithms 下一致；
  acceleration on 与 `lean_evolved_bds.m` 一致；
- `verify_gradient_stop_no_extra_evaluations`：objective-call counter 验证所有 calls 与
  `funcCount/xhist` 一一对应，explicit final options 与 solver defaults 行为相同，
  并确实由 final pure-gradient criterion 退出；
- final four-way marker：`GRADIENT_STOP_FINAL_COMPARISON_OK`，exit code `0`；
- no-extra-evaluation marker：`GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK`。

最重要的本地 artifacts：

- `plain_no_stop_function_gradient_combined_500n_optiprofiler.pdf`；
- `linearly_transformed_no_stop_function_gradient_combined_500n_optiprofiler.pdf`；
- `final_stopping_native_scores.mat`；
- `final_gradient_profiles/*_no_stop_vs_final_gradient_{500n,200n}_optiprofiler.pdf`；
- `final_stopping_manifest.mat`、`final_stopping_{plain,linearly_transformed}_scores.mat`；
- `run_gradient_stop_final_comparison.m` 与对应 screen launcher；
- `generate_gradient_stop_final_profiles.m`；
- `GRADIENT_STOP_INVESTIGATION.md`。

服务器 raw run roots：

```text
/home/lhtian97/Work/bds/tests/testdata/gradient_reference_final_boundary_validation_20260726_062519
/home/lhtian97/Work/bds/tests/testdata/gradient_stop_final_comparison_20260726_073936
```

结论：pure-gradient stopping 调查可以 close。它满足 solved-fraction gate、具有独立
activation、减少 evaluations，并且没有为停机增加任何 function evaluation。
