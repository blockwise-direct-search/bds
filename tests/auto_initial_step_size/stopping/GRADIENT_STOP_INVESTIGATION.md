# Accelerated BDS pure-gradient stopping 调查

## Goal

为 acceleration all-on + auto initial step `(c_x,c_tau)=(1,1)` 找到一组
gradient-only stopping strategy。最终 candidate 必须同时满足：

- `plain` 与 `linearly_transformed` 的 122-problem benchmark；
- `tau=10^-1,...,10^-5` 每个 target 的 solved fraction 与 no-stop 相同；
- 至少在一个 problem 上安全触发，并相对 no-stop 减少 evaluations；
- criterion 与参数具有 problem-independent、reviewer-resistant 的解释；
- full benchmark 通过后才允许在 candidate 附近做局部微调。
- stopping 只能复用算法正常 polling 已经计算的 points 与 function values；
  不得为估计、确认或停机增加任何 function evaluation。

## Stage 1: Diagnose concrete failures

- [x] 冻结 `SBRYBND`、`SCURLY20` 与 `POWERSUM` 的 feature、seed、dimension、initial point 和 transformation；controlled runner 使用 OptiProfiler 同一 `real_seed=211`，并把 exact `x0,A,b` 写入机器结果。
- [x] 复现 `SBRYBND` 在 `181` evaluations 的错误早停和 `SCURLY20` 的错误早停。
- [x] 判断主要失败属于 error bound 失真、relative scaling 过宽、非最优 stationary point，还是 acceleration-state mismatch。

## Stage 2: Design and controlled search

- [x] 根据 Stage 1 证据写出最小且可解释的 criterion 修正。
- [x] 在 `SBRYBND`、`SCURLY20`、`POWERSUM` 和已知安全 cases 上做 controlled test。
- [x] 冻结 `grad_tol=1e-6`，诊断未证明需要改变 tolerance 本身。
- [x] 搜索少量有解释的 reliability/window 参数，不采用 problem-name rule，也不使用额外差分 confirmation。
- [x] 保留所有通过 controlled safety gate 且具有独立 activation 的 candidates。

## Stage 3: Full benchmark and local refinement

- [x] 对第一轮 candidates 运行 `plain`、`linearly_transformed`、122 problems、`500*N`、`n_runs=1`。
- [x] 首先检查五个 targets 的 solved fraction；任何损失直接淘汰。
- [x] 对通过 gate 的 candidates 比较 total evaluations、activation count 和 problem-level merit changes。
- [x] 只在最优 candidate 附近做一次小范围微调。
- [x] 用 OptiProfiler 原生 summary 比较 no-stop、function-only 和最终 gradient-only candidate。

## Stage 4: Close

- [x] 在 `RESULTS.md` 记录 exact configuration、scores、solved fractions、evaluations 和失败/成功 cases。
- [x] 保留机器可读 results、manifest、runner 和 OptiProfiler 原生图。
- [x] 给出最终 gradient-only 参数及其算法解释。

## 不可违反的 evaluation 约束

DFO 的核心成本是 function evaluation。真实 gradient 只用于离线分析，绝不进入
solver。最终 stopping criterion 只能使用 solver 在正常运行中已经拥有的
state、polling points、function values、step sizes 和由它们生成的 gradient estimate。
任何需要额外 finite difference、重复采样或 confirmation evaluation 的方案均直接淘汰。

## Stage 1 诊断结论

冻结 OptiProfiler 的 `real_seed=211` 后，两个已知失败都被精确复现：

| Case | Stop evaluations | `norm(g_est)` | `norm(g_true)` | Actual error | Computed bound | Absolute fallback threshold |
|---|---:|---:|---:|---:|---:|---:|
| `linearly_transformed/SBRYBND` | 181 | `6.69e14` | `1.28e7` | `6.69e14` | `1.12e-3` | `2.87e15` |
| `linearly_transformed/SCURLY20` | 1044 | `3.72e9` | `3.08e7` | `3.71e9` | `6.50e-5` | `2.90e10` |

这不是 acceleration 成功后立即停机造成的：两个 stop iteration 的
`post_poll_acceleration_succeeded` 都是 false。主要失败链条是：

1. 线性变换后的高曲率区域使 early central-difference estimates 极度失真；
2. 固定的 `lipschitz_constant=1e3` 给出的 theoretical error bound 比 actual error
   小十几个到二十几个数量级，因此原 reliability test 没有拦住污染 estimate；
3. 第一个 estimate 被永久固定为 `reference_grad_norm`；
4. absolute fallback `1e-3*grad_tol*reference_grad_norm` 随污染 reference 膨胀，
   最终把仍然巨大的 gradient estimate 判定为“小”。

`plain/POWERSUM` 还揭示了第二层问题：stop 时 estimate `145.350063` 与 true
gradient `145.350061` 非常准确，但 early reference 约 `8.34e11` 仍把 fallback
threshold 放大到约 `834`。因此只修 error bound 不够；reference 本身必须具有
可靠的 scale 语义。

## Stage 2 criterion 与 controlled result

当前 candidate 对 reference 增加一个不产生 evaluations 的准入条件：只有正常
polling 在同一个 `xbase` 上自然形成两个连续 estimates，且

```text
norm(g_k-g_{k-1}) / max(1,norm(g_k),norm(g_{k-1})) <= consistency_tol
```

时，第二个 estimate 才能初始化 reference。该规则只复用现有 polling values；
真实 gradient 仍只用于离线诊断。

controlled search 使用 `consistency_tol={0.01,0.03,0.1,0.3}`、`gw=1`、
`gt=1e-6`。四个值均消除 `SBRYBND` 和 `SCURLY20` 错停，恢复与 no-stop 相同的
evaluation counts 和 outputs；也消除了 `plain/POWERSUM` 在 gradient norm 仍约
`145` 时的提前停机。

这只证明 safety mechanism 在已知 cases 上方向正确；是否过度保守以及是否具有
独立 activation，必须由 full benchmark 决定。

### 实际 poll points 与 true gradient 对照

调查记录保存的是 solver 正常 polling 已经计算过的 points 和 function values；
下面的 true gradient 仅在 run 后离线计算。以 reference 初始化和错误 stop 两个时刻
为例：

| Case | 时刻 | Eval | Poll offset norm 范围 | `norm(g_est)` | `norm(g_true)` | Actual error / bound |
|---|---|---:|---:|---:|---:|---:|
| `linearly_transformed/SBRYBND` | reference | 21 | `8.19e-2...5.52e-1` | `2.87e24` | `1.28e7` | `3.92e22` |
| `linearly_transformed/SBRYBND` | stop | 181 | `3.20e-4...2.16e-3` | `6.69e14` | `1.28e7` | `5.98e17` |
| `linearly_transformed/SCURLY20` | reference | 153 | `1.79e-1...8.54` | `2.90e19` | `2.21e13` | `1.65e15` |
| `linearly_transformed/SCURLY20` | stop | 1044 | `3.05e-5...5.52e-4` | `3.72e9` | `3.08e7` | `5.72e13` |
| `plain/POWERSUM` | reference | 21 | `2` | `8.34e11` | `1.91e9` | `3.96e8` |
| `plain/POWERSUM` | stop | 758 | `6.71e-9...2.45e-3` | `145.350063` | `145.350061` | `1.12e-2` |

`SBRYBND` 第一轮各 coordinate pair 的 sampled function values 已达到
`10^22...10^27`，reference estimate 因而不是 problem 的 usable local scale；到
stop 时 sampled offsets 已缩小三数量级以上，但 estimate 误差仍比 computed bound
大 `5.98e17` 倍。`POWERSUM` 则相反：stop 时 estimate 已很准确，错误完全来自永久
保留的 early reference。这两种失败共同说明：既不能信任固定 Hessian Lipschitz
guess 给出的 error bound，也不能让任意第一个 estimate 定义全程 absolute scale。

## Stage 3 第一轮 full benchmark 与离线参数搜索

第一轮 full benchmark 使用 `gw={1,2,3,5}`、
`consistency_tol={0.01,0.03,0.1,0.3}`、`gt=1e-6` 和历史
`reference_scale_factor=1e-3`。全部 candidates 在两种 feature 的五个 targets
均保持 `122/122`。但 `plain` 下全部 inactive；`linearly_transformed` 下只有
`gw=1` 触发两个 problems，总 evaluations 从 `534414` 降至 `534384`，仅节省
`30` 次。因此 reliability gate 已经找到安全且具有独立 activation 的区域，
但历史 reference threshold 过于保守。

为避免为调参反复重跑 solver，随后对两种 feature 的全部 244 个 cases 各运行一次
no-stop，并记录算法正常 polling 自然产生的 gradient estimates。离线 replay 不计算新点、
不调用 objective，只改变 stopping decision。粗搜索预测固定 `gw=1`、
`consistency_tol=0.1` 时：

| `reference_scale_factor` | Activations | Predicted savings | Changed final merit |
|---:|---:|---:|---:|
| `10` | 14 | 1182 | 0 |
| `30` | 14 | 1307 | 0 |
| `100` | 16 | 1455 | 0 |
| `300` | 17 | 2126 | 4 |

因此正式 scale validation 检查 `0.001,0.01,0.1,1,10,30,100,300`；若安全边界
落在 `100` 与 `300` 之间，再只对 `125:25:275` 做一次局部微调。离线 replay
只用于筛选，最终结论必须由真实 solver run 与 OptiProfiler 原生 profiles 决定。

正式 scale validation 的第一批结果表明，`scale=300` 仍通过两种 feature 的五个
targets gate。相对 no-stop，`plain` 节省 `1617` 次、
`linearly_transformed` 节省 `509` 次，共 `2126` 次 evaluations，17 个 cases
发生独立 activation。其 final merit 在四个 `plain` cases 有 `10^-11` 到 `10^-9`
量级差异，但仍全部满足五个预定 targets；因此“bitwise 相同的 final merit”不是
本实验的淘汰规则，预先确定的 solved-fraction gate 才是。下一批正式验证继续检查
`scale=400:100:1000`，寻找第一个真正损失 solved fraction 的区域。

`scale=300` 还通过了已知 failure cases 的独立 controlled rerun：
`linearly_transformed/SBRYBND` 保持 `529` evaluations、
`linearly_transformed/SCURLY20` 保持 `7173` evaluations，
`plain/POWERSUM` 保持 `5000` evaluations，均未再次发生原 criterion 的错误早停。

随后正式 upper-scale validation 检查 `scale=400:100:1000`，所有 candidates 仍在
两种 feature 的五个 targets 上保持 `122/122`。`scale=1000` 相对 no-stop 在
`plain` 节省 `3207` 次、在 `linearly_transformed` 节省 `12274` 次，共节省
`15481` 次 evaluations，明显优于 `scale=300`。

采用正式 OptiProfiler common-target 语义离线 replay 后，粗边界为：

| `scale` | `rho=scale*gt` | Activations | Predicted savings | Minimum solved count |
|---:|---:|---:|---:|---:|
| `10000` | `1e-2` | 25 | 21011 | 122 |
| `11000` | `1.1e-2` | 25 | 21062 | 122 |
| `11500` | `1.15e-2` | 25 | 21368 | 121 |
| `30000` | `3e-2` | 27 | 25416 | 119 |

最终 formal boundary run 因此只验证 `10000,11000,11500`。即使 `11000` 实跑安全，
若它相对 `10000` 仍只多节省约 51 次，则选择自然的 `rho=1e-2`：它更易解释，且与
预测失效边界保持明显距离。

## Stage 3 formal boundary 与最终参数

formal solver run 完整验证了 replay 的边界：

| `rho` | `plain` minimum solved | `linearly_transformed` minimum solved | Total savings | Activations |
|---:|---:|---:|---:|---:|
| `1e-2` | `122/122` | `122/122` | `21011` | `25` |
| `1.1e-2` | `122/122` | `122/122` | `21062` | `25` |
| `1.15e-2` | `122/122` | `121/122` | `21368` | `25` |

`rho=1.15e-2` 唯一丢失的是 `linearly_transformed/PALMER2C` 在 `tau=1e-5`
的 target：no-stop 使用 `4000` evaluations，`rho=1e-2` 在 `541` 停止并通过全部
targets，而 `rho=1.15e-2` 在 `235` 停止并失败。这给出了真实 solver 的明确失效
边界。`rho=1.1e-2` 相对 `1e-2` 只多节省 `51` 次，占总预算约 `0.005%`，不足以支持
贴近失效边界。

固定 `rho=1e-2` 的邻域 replay 进一步得到：

| `consistency_tol` | Minimum solved | Total savings | Activations |
|---:|---:|---:|---:|
| `0.003,0.01,0.03` | `122/122` | `20552` | `24` |
| `0.1,0.3` | `122/122` | `21011` | `25` |
| `0.5` | `121/122` | `37832` | `26` |

因此 `0.1` 是安全平台 `{0.1,0.3}` 的左端点；更小的 values 少一次有效 activation，
`0.5` 已越界。下面保留当时运行实验所用的历史参数表示：

```text
grad_window_size = 1
grad_tol = 1e-6
grad_reference_finite_difference_error_tol = 1/30
reference-relative tolerance rho = 1e-2
```

历史实验代码中 `rho=1e-2` 等价于当时的
`grad_reference_relative_tol=1e-2`；reference threshold 是
`rho*max(1,reliable_reference_grad_norm)`。由于该 threshold 在最终参数下严格包含
`grad_tol=1e-6` 的 `min` threshold，当前完全等价的正式接口只使用
`grad_tol=1e-2`。`10000` 只保留为历史 solver-name label 的解析 encoding，不是
problem-dependent constant，也不是当前 solver option。

## Stage 4 close

同池 final comparison 使用 no-stop、function-only、final pure-gradient 与 combined OR
四个 solvers。两种 feature、五个 targets 的 solved fraction 全部为 `122/122`。
pure-gradient 相对 no-stop 的精确结果是：

- `plain`：`443927 -> 440309`，节省 `3618` 次，14 个 problems activation；
- `linearly_transformed`：`534414 -> 517021`，节省 `17393` 次，11 个 problems
  activation；
- 合计节省 `21011` 次，25 个 feature-problem cases 独立 activation。

combined OR 也通过 formal gate：`plain` 为 `443927 -> 354495`，
`linearly_transformed` 为 `534414 -> 434060`；它比 function-only 分别额外节省
`3025` 和 `17191` 次。这证明两个 stopping mechanisms 在最终 strategy 中确实互补。

focused objective-call accounting 还验证了：`output.funcCount`、`xhist` 与实际 calls
一一对应，explicit final options 与 solver defaults 行为完全相同，并且 constructed
case 由 pure-gradient criterion 退出。marker 为：

```text
GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK
```

所以本调查已经 close：找到了安全、有独立作用、且不增加任何 function evaluation 的
pure-gradient stopping strategy。true gradient 只出现在离线诊断中，从未进入 solver。
