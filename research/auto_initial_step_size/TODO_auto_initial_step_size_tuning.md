# BDS 的 automatic initial step size 调参

本文件记录 automatic initial step size rule 的正式实验协议和执行状态。正文使用中文，
algorithm、option、benchmark、profile、history 等技术术语保留英文。

## 状态

- 实验方案设计：`[done]`
- production/test helper：`[done]`
- full factorial runner 与 one-problem pilot：`[done]`
- primary full factorial run：`[done]`
- `200*N`/`500*N` coefficient analysis：`[done]`
- local refinement decision：`[done: no refinement]`
- provisional coefficient decision：`[done: keep (1,1)]`
- problem-level paired analysis：`[todo]`
- independent validation：`[todo]`
- production formula：`[unchanged]`（当前 fixed `(1,1)`；omitted default 仍为 unit steps）

Primary screen 已经把 `c_x` 收敛到 `1`，目前没有足够证据把 incumbent `c_tau=1`
替换为 `2`，所以 BDS strategy 暂时不改，也不进行 local refinement。但按事先冻结的
protocol，formal close 仍需要 problem-level paired analysis 和 transformed validation。
完整 scores、provisional rationale 和 remaining gates 见
`results/SCORES.md`。

## 目标与范围

目标是在三个 acceleration mechanisms 全部启用的 cyclic BDS 上，为
`alpha_init = "auto"` 选择一个固定 coefficient pair：

- `use_productive_direction_memory = true`；
- `use_iteration_pattern_step = true`；
- `use_momentum_extrapolation = true`。

本研究直接在这一 accelerated all-on solver 上调参，不再先对 plain BDS 分阶段筛选，
也不再把 accelerated solver 仅作为事后的 transfer check。三个 acceleration switches
及其 parameters 在整个研究中固定；本研究不调整 acceleration 或 termination
parameters。

最终 rule 必须在 `200*N` 和 `500*N` 两个 analysis checkpoints 上都可靠。不得为
不同 problem、benchmark、budget 或 activation rate 选择不同 coefficients，也不得
引入 benchmark-dependent runtime rule。

## Candidate rule

令 `epsilon_i` 表示 coordinate block `i` 的 `StepTolerance`。对 positive
coefficients `c_x` 和 `c_tau`，定义

\[
  b_i(c_x)=
  \begin{cases}
    1, & x_i^0=0,\\
    c_x|x_i^0|, & x_i^0\ne0,
  \end{cases}
\]

以及

\[
  \alpha_0^i(c_x,c_\tau)
  =\max\{b_i(c_x),c_\tau\epsilon_i\}.
\]

exact zero coordinate 不提供 usable positive scale，因此回退到 neutral unit step。
每个 nonzero entry 都被视为 user 通过 initial point 提供的 scale signal，即使其很小。
所以 nonzero entry 趋近于零时的 discontinuity 是有意的 semantic convention，不是
tuning 问题。

若未来一个 block `j` 合并多个 coordinate pairs，自然 extension 是

\[
  \alpha_0^j=\max_{i\in I_j}\alpha_0^i.
\]

该 extension 不属于本 coefficient experiment。除非 direction set 已知由有序
coordinate pairs 构成，否则不得从 arbitrary direction indices 推断 coordinate
indices。

## Full factorial grid

primary grid 固定为

\[
  c_x\in\{0.1,0.2,0.5,1\},\qquad
  c_\tau\in\{1,2,5,10\}.
\]

一次性运行全部 `4*4=16` 个 coefficient pairs，不再先固定一个 coefficient、筛掉
另一维后再做 cross。这样 primary screen 直接观察 `c_x` 与 `c_tau` 的 interaction。

`c_tau` 的四个值代表 `shrink=0.5` 时的四个 contraction-depth groups：

- `{1}`：一次 contraction；
- `{2,3}`：两次 contractions，以 `2` 为 representative；
- `{4,5,6,7}`：三次 contractions，以 `5` 为 representative；
- `{8,9,10}`：四次 contractions，以 `10` 为 representative。

`(c_x,c_tau)=(1,1)` 是 current automatic rule，在 16 个 grid points 中只运行一次，
用于 current-rule diagnostic；它不享有预设胜出的优先级。

## Baseline 与 comparison pool

唯一额外 baseline 是 accelerated all-on solver 配合

```matlab
alpha_init = ones(N, 1);
```

即不启用 automatic scaling，但 acceleration configuration 与 16 个 candidates 完全
相同。primary benchmark 因此共有 17 个 configurations：一个 unit baseline 加 16 个
coefficient pairs。

除 numeric `alpha_init` vector 外，17 个 configurations 的所有 effective options、
problem order、initial point、transformation 和 random seed 必须相同。所有 17 条 raw
histories 必须属于同一个 benchmark/common-target pool，不得把 grid 拆成各自计算
targets 的 batches 后直接比较 PDF。

每个 solver label 必须无歧义地编码 coefficients、all-on mode 和 runtime budget，例如：

```text
unit-accelerated-all-on-500n
auto-cx-0p2-ctau-5-accelerated-all-on-500n
```

在正式 decision 前不得使用 `best`、`new` 或 `final` 等 label。

## Frozen base configuration

primary run 冻结为以下配置：

- solver：production `src/bds.m` with all three acceleration switches enabled；
- `Algorithm = "cbds"`；
- effective `direction_set = eye(N)`、`num_blocks = N`、`batch_size = N`、
  `block_visiting_pattern = "sorted"`；
- `StepTolerance = 1e-6`；
- `expand = 1.8`，`shrink = 0.5`；
- `is_noisy = false`；
- `forcing_function = @(alpha) alpha^2`；
- `reduction_factor = [0, eps, eps]`；
- `polling_inner = "opportunistic"`，`cycling_inner = 1`；
- `ftarget = -Inf`；
- `use_function_value_stop = false`；
- `use_estimated_gradient_stop = false`；
- BDS `seed = 0`；
- `use_productive_direction_memory = true`；
- `productive_direction_memory_size = max(1,min(N,5))`；
- `use_iteration_pattern_step = true`；
- `use_momentum_extrapolation = true`；
- `momentum_decay = 0.6`。

profile feature 名为 `plain`，意思是 untransformed/noiseless benchmark feature，
不是 plain solver。profile `seed=0`，每个 problem/configuration 运行一次。

## Test set 与 budget

primary benchmark 使用已经审计的 ordered snapshot：122 个 unconstrained S2MPJ
problems，dimension 在 `6` 到 `50`，并使用现有 exclusion list。准确 problem names、
dimensions 和 order 必须在 run manifest 中保存并与 raw results 一致。

每个 solver/problem/configuration combination 只运行一次到 `500*N`，保存完整 raw
history。该同一次运行提供两个 analysis checkpoints：

- `200*N`：仅取每条 history 的前 `200*N` 次 evaluations；
- `500*N`：使用完整 history。

必须分别从全部 17 个 configurations 的 `200*N` prefixes 和完整 `500*N` histories
计算两组 common targets。不得把 `500*N` pool 得到的 target 复用于 `200*N`，也
不得为了得到 `200*N` 图重新运行 solver。

至少分析 accuracies

\[
  \tau\in\{10^{-1},10^{-2},10^{-3},10^{-4}\}.
\]

`max_tol_order=4` 与该 decision grid 一致。不得依据单一 accuracy 或单张 summary
profile 选择 pair。

作为 extended diagnostic，另生成 `10^{-5}` 至 `10^{-10}` 的 history-based profiles，
使完整图覆盖 OptiProfiler 默认的 `10^{-1}` 至 `10^{-10}`。这些额外 accuracies 用于检查
高精度趋势，不事后改变已经冻结的四个 primary decision accuracies。

## Raw evidence 与 analysis

history-based evidence 是两个 checkpoints 的主要依据。对于每个 pair 和每个
accuracy，至少记录：

- solved count 与 solved fraction；
- 首次达到 common target 的 evaluation count；
- 相对 unit baseline 与 `(1,1)` 的 challenger-only、comparator-only、jointly-solved
  和 neither counts；
- jointly-solved problems 上的 paired evaluation ratios、wins/ties/losses、median、
  geometric mean 与 quartiles；
- 最坏 regressions、集中出现 regressions 的 problem names/classes；
- `500*N` 的 returned point、true objective value 和 termination status；
- initial step vector，以及 tolerance lower bound 生效的 coordinates/blocks。

`200*N` 只使用 history prefix，不使用 `500*N` returned-point/output evidence。
`500*N` 可额外检查 output-based diagnostics。17-solver summary PDF 只是辅助；正式
decision 必须依据 raw history 和 problem-level paired tables。

## Activation audit 与 controlled tests

activation audit 记录每个 problem、每个 grid pair 上：

- `x0` 的 exact-zero entries 数量；
- 满足 `c_x*abs(x0_i) < c_tau*StepTolerance_i` 的 nonzero entries 数量；
- tolerance lower bound 实际改变 initial step 的 coordinate/block 比例。

该 audit 只解释 `c_tau` 是否可由 primary benchmark 识别，不决定是否运行 grid，也
不得成为 per-problem runtime rule。如果多个 `c_tau` values 在 primary problems 上生成
identical `alpha_init`，必须把它们报告为 observationally equivalent，而不能从 numerical
noise 中制造 winner。

controlled tests 必须覆盖全部四个 `c_tau` candidates，并验证：

- `(1,1)` 复现 current simple rule；
- sign invariance；
- exact zero 得到 `max(1,c_tau*StepTolerance)`；
- zero 与 tiny nonzero 的有意 discontinuity；
- tolerance lower bound 激活与未激活两种情况；
- scalar 和 coordinate-sized `StepTolerance`；
- supported finite inputs 产生 finite positive steps；
- numeric `alpha_init` 经过 option processing 后保持不变；
- 三个 acceleration switches 对 unit baseline 和所有 grid candidates 均为 true；
- 除 `alpha_init` 外的 effective options 完全一致；
- large-coordinate floating-point cases 产生 intended distinct trial points。

明确的 formula test case 为：

```text
x0 = [0; 2; -3; 1e-8]
StepTolerance = 1e-6
c_x = 0.5
c_tau = 5
expected alpha_init = [1; 1; 1.5; 5e-6]
```

correctness failure 可直接淘汰 candidate；constructed tests 的 performance 不单独决定
coefficient winner。

## Reproducibility manifest

完整 run 在开始 benchmark 前保存 machine-readable manifest 和 text summary，至少包含：

- BDS commit、branch 与 dirty status；
- OptiProfiler root、commit/version 与 dirty status；
- MATLAB version、operating system、日期时间与 launch command；
- ordered problem names、dimensions、library、feature 与 exclusion protocol；
- 17 个 ordered solver labels，以及 label 到 `(c_x,c_tau)` 的 mapping；
- runtime budget、两个 analysis checkpoints、all base options；
- 三个 acceleration switches 及其 effective parameters；
- BDS/profile seeds、`n_runs` 与 `n_jobs`；
- run status、raw data path 和完成时间。

manifest 的存在不代表 benchmark 成功。完整 run 只有在 raw `data_for_loading.mat` 可加载、
122*17*1 identities 完整、所有 solver success、无 abnormal termination/fallback、且日志出现
exact completion marker 后才可标记 `COMPLETE`。

## 执行阶段

### T0：冻结 protocol 与 implementation

- `[done]` 冻结 `4*4` grid、unit accelerated baseline、`500*N` runtime 和两个
  analysis checkpoints。
- `[done]` 冻结三个 acceleration switches 与 `StepTolerance=1e-6`。
- `[done]` 将 production formula 剥离到 `src/private/get_auto_alpha_init.m`，同时保留
  test-only candidate helper。
- `[done]` 让 parameterized profile wrapper 显式生成 numeric `alpha_init`，并传给
  accelerated all-on solver。
- `[done]` 使用 caller-provided short `benchmark_id`，避免 17 个完整 labels 拼接后超过
  filesystem component length；完整 mapping 仍保存在 manifest/raw data。

### T1：formula 与 pilot checks

- `[done]` 已有 production helper formula unit tests 与 non-auto regression tests。
- `[done]` production formula tests 覆盖四参数 rule、`(1,1)` equivalence、zero/tiny
  nonzero、scalar/vector tolerance 和 invalid inputs；四个 `c_tau` candidates 使用同一
  validated helper 生成 numeric steps。
- `[done]` parameterized wrapper 对 unit baseline 和全部 candidates 共用同一
  accelerated path，并显式将三个 acceleration switches 设为 `true`。
- `[done]` 在一项 S2MPJ problem 上完成 17-configuration pilot。
- `[done]` 验证 pilot raw data、manifest、solver order、problem order和 budgets。

T1 的 deterministic pilot 通过后才能启动 full run。

### T2：primary full factorial run

- `[done]` 用 `screen` 完成 122-problem、17-configuration、one-run benchmark。
- `[done]` 保存一个可加载的 `data_for_loading.mat`。
- `[done]` 验证 122 problems、17 solvers、1 run 共 2074 个 identities 全部完整。
- `[done]` 验证 `n_evals <= 500*N`、全 success、无 abnormal termination/fallback。
- `[done]` 保存 completion marker、manifest 和 main log；process exit code 为 0。

正式 runner：

```text
research/auto_initial_step_size/run_auto_initial_step_size_500n_full_factorial.m
research/auto_initial_step_size/run_auto_initial_step_size_500n_full_factorial_screen.sh
```

### T3：两个 checkpoints 的 primary analysis

- `[done]` 从 17-config pool 的 `200*N` prefixes 重算 common targets，并生成
  `10^{-1}` 至 `10^{-10}` 的 OptiProfiler-native extended history profiles。
- `[done]` 从同一 pool 的完整 `500*N` histories 另行重算 common targets，并生成
  `10^{-1}` 至 `10^{-10}` 的 OptiProfiler-native extended history profiles。
- `[done]` 核验两份 summary PDF 均由 OptiProfiler `benchmark(..., load=...)`
  原生生成并显示完整 17-solver pool；不使用 custom plotting 产物作为 evidence。
- `[done]` 对每个 candidate 与 unit baseline 单独组成 two-solver pool，使用
  OptiProfiler 原生重算两端 scores；为 `(1,1)` 与 unit baseline 生成 `200*N`、
  `500*N` direct-comparison summaries。
- `[done]` 检查十个 accuracies 的 OptiProfiler-native curves、scores 和 solved
  fractions；`(1,1)` 在两个 checkpoints 均明显优于 unit baseline。
- `[done]` 比较全部 17 个 aggregate scores；唯一两端略高的 challenger `(1,2)` 只高
  `8.12e-5` 与 `2.70e-4`，且 tolerance-level profiles 存在 ties/轻微反转，不满足
  clear、stable、material improvement 门槛。
- `[done]` 将 primary shortlist 冻结为 `(1,1)` 与 `(1,2)`。前者是 incumbent，后者的
  aggregate advantage 太小，不能据此替换 incumbent，但 primary tolerances 尚未将其淘汰。
- `[todo]` 从已有 raw histories 生成四个 primary accuracies 下的 solved/paired/
  problem-level tables，用于区分 `(1,1)` 与 `(1,2)` 并检查 concentrated regressions。
- `[todo]` 量化 `c_tau` activation，并识别 observationally equivalent cases。

### T4：至多一轮 local refinement

查看 primary results 后，用户与 Codex 决定是否细分。若触发，必须在运行任何新增点前：

- 书面冻结一个 primary pair/region 作为 refinement center；
- 冻结最多八个新增 `(c_x,c_tau)` pairs；
- 将新增 `c_x` 限制在 primary grid 的 `[0.1,1]` 内；
- 将新增 `c_tau` 限制在 `[1,10]` 内；
- 记录 trigger、points、analysis plan 与 timestamp。

新增 points 仍使用 accelerated all-on、同一 base configuration、一次 `500*N` 和两个
checkpoints。refinement 最多一轮，不得 recursive refinement，也不得在查看 validation
后返回该 validation set 继续调参。若不触发，应明确记录 `no refinement`。

本次结果未触发 refinement：`c_x<1` 全部明显落后；`(1,2)` 相对 `(1,1)` 的万分位
差异不构成 material improvement。记录为 `no refinement`。

### T5：independent validation

primary/refinement 完成后先冻结 finalists，再打开 validation stage。validation 使用
同一 ordered 122-problem identities 的五个预先固定 pure orthogonal rotations：

- feature：`linearly_transformed`；
- profile `seed=0`；
- `n_runs=5`；
- `rotated=true`；
- `condition_factor=0`。

这是一组事先封存、与 primary plain instances 不同的 transformed instances；它不是
problem-identity holdout。validation 只比较 frozen finalists、unit accelerated baseline
和 `(1,1)` diagnostic，不再调参。validation failure 必须记录并停止本研究；不得在同一
validation set 上修改 grid 或选择另一 pair。

Primary shortlist 已冻结为 `(1,1)` 与 `(1,2)`。完成 problem-level paired analysis 后，
按本节打开 validation set；validation 只用于确认 frozen finalists，不再调参。

### T6：final decision 与 integration

- `[todo]` 结合 paired evidence 和 independent validation，在 `(1,1)`、`(1,2)` 中选择
  final fixed pair；在此之前 production 保持 `(1,1)`。
- `[todo]` final decision 后确定是否需要 production coefficient patch；omitted
  `alpha_init` 必须继续表示 unit steps。
- `[todo]` 运行 focused production regression tests 并记录结果。
- `[todo]` 若 final pair 改为 `(1,2)`，同步 production implementation 和 manuscript；若
  保留 `(1,1)`，记录 no coefficient patch required。
- `[out of scope]` 将 `tests/competitors` 中三项实验性 acceleration 合并进 released
  `src/bds.m` 是独立 integration task，不与 coefficient decision 混为一谈。

## Decision rules

1. Correctness 是硬门槛；invalid initial steps 或 formula mismatch 直接淘汰。
2. 以 coefficient pair 为 decision object，不再按 `c_x`、`c_tau` sequentially 晋级。
3. pair 必须在 `200*N` 与 `500*N` 两个 checkpoints、主要 accuracies 和
   problem-level comparisons 上表现稳定；单一 horizon 或单一 accuracy 的优势不够。
4. 优先保证 robustness。相对 unit accelerated baseline，任一 checkpoint 的
   history-based solved fraction 下降超过一个百分点，构成 material regression。
5. 即使 solved fraction 未下降，若 jointly-solved set 中相当大比例的 paired costs
   持续上升，或 regressions 集中在可识别 problem class，也构成 material regression。
6. `(1,1)` 用于判断新 pair 是否真正改进 current automatic rule；unit baseline 用于判断
   automatic scaling 是否值得启用。两者都必须报告，但 unit 是唯一额外 solver baseline。
7. 多个近似等价 pairs 应全部进入 shortlist，不得根据单张 profile 或 numerical noise
   强行选出唯一 winner。
8. 不使用未在查看结果前冻结且有明确解释的 weighted aggregate score。OptiProfiler
   summary score 仅作 diagnostic。
9. local refinement 最多一轮、最多八个新增 points，并且必须在 validation 前冻结。
10. final pair 必须通过封存的 transformed-instance validation；validation 不用于 tuning。

## Required outputs

- candidate helper、parameterized wrapper、runner 与 screen launcher；
- formula/controlled/pilot checks；
- 17-config ordered grid manifest 与 activation audit；
- raw `500*N` histories；
- 分别基于 `200*N` prefixes 与完整 `500*N` histories 的 common-target tables；
- history-based profiles、`500*N` output diagnostics 和 paired problem-level tables；
- primary shortlist 与 refinement trigger/points/no-refinement record；
- independent validation lock 与 results；
- written coefficient decision；
- production coefficient patch 或明确的 no-patch record、regression tests，以及按 final
  decision 需要的 manuscript update。

建议 result directory stamp：

```text
auto_initial_step_size_500n_full_factorial_<stage>_<timestamp>
```

## Decision record

### Frozen primary protocol

- grid：`c_x={0.1,0.2,0.5,1}` * `c_tau={1,2,5,10}`；
- baseline：`unit-accelerated-all-on-500n`；
- candidates：16 个 accelerated-all-on automatic pairs；
- runtime：每个 identity 一次到 `500*N`；
- analysis：同一 raw history 的 `200*N` prefix 和完整 `500*N`；
- `StepTolerance=1e-6`；
- dimensions：`6` 至 `50`；
- feature：untransformed `plain`；
- problem count：122；
- BDS/profile seed：0；
- workers：40。

### Existing exploratory result

2026-07-21 的 direct `200*N` run 只覆盖 `c_tau=1` slice，并分别运行 plain 与
accelerated all-on。它表明在该单一 slice/checkpoint 上 `c_x=1` 最好，但不能淘汰其他
`c_x` 与不同 `c_tau` 的 interactions，因此不作为 full factorial decision evidence。

### Primary full factorial result

- status：`[done]`
- completed screen session：`418651.auto_alpha_500n_grid`
- run path：`/home/lhtian97/Work/bds/tests/testdata/auto_initial_step_size_500n_full_factorial_full_20260721_232117`
- log path：`/home/lhtian97/Work/bds/tests/testdata/auto_initial_step_size_500n_full_factorial_status/full_20260721_232100.log`
- raw data path：`/home/lhtian97/Work/bds/tests/testdata/auto_initial_step_size_500n_full_factorial_full_20260721_232117/accelerated_all_on/auto_alpha_accel_4x4_500n_plain_s2mpj_26_07_21_23_21_17/u_6_50_plain_20260721_232119/test_log/data_for_loading.mat`
- `(1,1)` vs unit baseline 的 canonical `200*N` summary：
  `results/cx1_ctau1_vs_unit_200n.pdf`
- `(1,1)` vs unit baseline 的 canonical `500*N` summary：
  `results/cx1_ctau1_vs_unit_500n.pdf`
- score record：`results/SCORES.md`
- completion：2074/2074 identities，exit code 0，全 success，无 abnormal termination/fallback
- primary shortlist：`(1,1)` 与 `(1,2)`；production 暂时保留 incumbent `(1,1)`

### Refinement record

- trigger：未触发；没有 challenger 达到 clear、stable、material improvement 门槛
- frozen center/region：无（不需要 refinement）
- frozen added pairs：无
- status：`[done: no refinement]`

### Independent validation record

- finalists lock：`(1,1)` 与 `(1,2)`
- status：`[todo]`
- result：尚未打开 validation set

### Final decision

尚未完成 formal final decision。Current engineering choice 是继续使用
`(c_x,c_tau)=(1,1)`，不因万分位 aggregate difference 改 production；formal shortlist
为 `(1,1)` 与 `(1,2)`。完整 OptiProfiler scores、rationale 和 remaining gates 见
`results/SCORES.md`。

## Completion criteria

本 coefficient tuning task 尚未标记为 `[done]`。已完成：

- 122*17*1 primary identities 完整，raw histories 和 manifests 已保存；
- `200*N` 与 `500*N` 使用各自 horizon 的完整 common pool 重算 targets；
- 两个 checkpoints 的十个 accuracies、native curves、scores 和 solved fractions 已审查；
- `(1,2)` 的十档 aggregate advantage 不足 `0.03%`，不足以直接替换 incumbent；
- formula、zero/tiny nonzero、scalar/vector tolerance、`(1,1)` equivalence 和 non-auto
  regression tests 已写入 production unit tests；
- refinement 已明确记录为不执行。

Formal close 仍需：已有 histories 的 problem-level paired tables、`c_tau` activation
audit、冻结 shortlist 的 transformed validation、final decision 和相应 production test
record。将三项实验性 acceleration 从 `tests/competitors` 迁入 released BDS 仍是独立任务。
