# Automatic initial step size 的 10-feature benchmark 计划

## 目标

在保持 acceleration configuration 不变的前提下，验证已经选定的
automatic initial-step strategy 是否能够从现有的 `plain` 结果可靠地推广到完整的
10-feature benchmark，并分别回答以下两个问题：

- automatic initial-step strategy 相对 unit initial steps 是否带来独立增益；
- 使用该 strategy 的 accelerated BDS 相对外部 solvers 是否具有更好的整体表现。

## 执行顺序

### 1. 统一 production `auto` 语义 `[done]`

本节记录的是 acceleration 尚未并入 production `bds` 时完成的历史工作。当时先让
`accelerated_bds_options.m` 的 `alpha_init = "auto"` 使用已经敲定的
`(c_x,c_tau)=(1,1)` rule，而不是当前遗留的 piecewise/log rule：

\[
\alpha_i^0=\max\{|x_i^0|,\epsilon_i\},\quad x_i^0\ne0,
\qquad
x_i^0=0\Longrightarrow\alpha_i^0=\max\{1,\epsilon_i\}.
\]

同时增加 focused regression verification，确认 public `auto` path 与实验中已经验证过的
numeric `alpha_init` path 完全一致，并继续满足 acceleration 打开/关闭时的既有
equivalence gates。

完成记录：当时 `accelerated_bds_options.m` 的 public `auto` path 已改为调用与
production helper 相同的 `(1,1)` formula；该实现现已并入 `src/bds.m`。focused
verification 同时检查
acceleration 全关、全开和 vector `StepTolerance` 三种情况。正式 verification markers
为 `BDS_AUTO_ALPHA_INIT_OK`、
`BDS_ACCELERATION_EQUIVALENCE_OK` 和
`GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK`。

### 2. 运行完整 10-feature benchmark

使用 S2MPJ 中 dimensions `6:50` 的同一组 problems，运行一次 `500*N` benchmark。
十个 features 固定为：

- `plain`；
- `noisy_1e-1`、`noisy_1e-2`、`noisy_1e-3`、`noisy_1e-4`；
- `linearly_transformed`；
- `linearly_transformed_noisy_1e-1`、`linearly_transformed_noisy_1e-2`、
  `linearly_transformed_noisy_1e-3`、`linearly_transformed_noisy_1e-4`。

`plain` 使用 `n_runs=1`；其余九个 features 均使用 `n_runs=5`。manifest 按上述 feature
顺序逐项记录对应的 run count，runner 在每个 feature 开始时也会将实际 `n_runs` 写入 log。
正式实验使用服务器 MATLAB `Processes` profile 允许的全部 `60` 个 physical-core workers。
Solver-level failure、abnormal termination 和 output fallback 均由 OptiProfiler 原生记录并在
profiles 中处理；runner 只将其计数写入 manifest 和 log，不得因此终止整个 benchmark。

本实验用于隔离 automatic initial step 的贡献，因此 optional function-value stopping 和
gradient stopping 均关闭；其他 solver options、problem order、seeds、budgets 和
OptiProfiler settings 对所有 configurations 保持一致。

### 3. 在同一 comparison pool 中设置 solvers

同一个 benchmark/common-target pool 固定包含：

- accelerated BDS + unit initial steps + no optional stopping；
- accelerated BDS + finalized automatic initial steps + no optional stopping；
- accelerated BDS + finalized automatic initial steps + combined stopping；
- BFO；
- NOMAD；
- Nelder--Mead；
- DS（no acceleration and no optional stopping）；
- PDS；
- NEWUOA；
- finite-difference BFGS。

前两个 configurations 只允许在 `alpha_init` 上不同；第三个 configuration 只在第二个的
基础上增加已经敲定的 combined stopping。这样既能分别隔离 automatic initial-step
strategy 和 stopping strategy 的增量贡献，也能在完全相同的实验口径下与其他 solvers
比较。

正式 solver identities、display names、固定 colors 和 line styles 由
`ten_solver_benchmark_spec.m` 唯一定义；不同 subset 的 OptiProfiler-native figures 必须按
solver identity 复用同一组颜色。

### 启动前准备状态 `[done]`

- `profile_optiprofiler.m` 已支持十个 frozen `500N` solver identities；
- automatic configurations 使用 production `alpha_init = 'auto'`；
- combined configuration 显式使用最终 stopping parameters；
- noisy/custom finite-difference BFGS 按每次 callback 的真实 objective calls 换算 budget；
- local smoke 已覆盖两个不同 dimensions 的 frozen problems，以及 `plain`、`noisy_1e-3`、
  `linearly_transformed_noisy_1e-3` 三个代表 features；
- `500N` 和由同一 raw history 派生的 `200N` OptiProfiler-native subset replot 均已通过。

正式 122-problem、10-feature experiment 尚未启动。

### 4. 生成两类 OptiProfiler 原生结果

从同一批 raw histories 生成两类 OptiProfiler-native summary figures 和对应 scores：

- automatic initial steps 对 unit initial steps，用于证明增益确实来自 initial-step
  strategy；
- automatic accelerated BDS 对 BFO、NOMAD 和 Nelder--Mead，用于导师汇报和论文展示。

所有图必须由 OptiProfiler 的 `benchmark(..., load=...)` 原生生成，不使用 custom
plotting 代替正式 evidence；同时保存 raw data、manifest 和 machine-readable scores。

### 5. 从同一次 run 得到 `200*N` 与 `500*N` 结果

每个 solver/problem identity 只运行一次到 `500*N`。`500*N` profiles 使用完整
histories；`200*N` profiles 截取每个 problem 的前 `200*N` history，并在该 prefix 上
独立重新计算 common targets。不得复用 `500*N` targets，也不为 `200*N` 重新运行
solver。

## 完成判据

只有在十个 features 的 raw histories 完整、两个 budgets 的 targets 分别正确重算、两类
OptiProfiler 原生结果和 scores 均可复现后，才能判断 automatic initial-step strategy
是否具有可靠的跨 feature 增益。实验开始前不预设所有 features 都会改善。
