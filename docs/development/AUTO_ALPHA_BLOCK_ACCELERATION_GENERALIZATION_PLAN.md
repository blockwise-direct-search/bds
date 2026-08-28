# 自动初始步长与任意分块加速推广计划

## 目标

使 `options.alpha_init = "auto"` 不再只支持默认的 `num_blocks = n`，而是对
任意合法块数和任意合法 `grouped_direction_indices` 都具有明确且一致的语义；同时
验证三项加速机制在单块、中间块数、默认逐方向分块以及自定义分块下均能正常工作
和自然退化。

本轮不改变 BDS 的“每个块共享一个步长”这一基本设计，也不试图让单个块的一个
步长同时适配块内所有坐标尺度。不同块拥有不同步长正是 BDS 相对单块 DS 的核心
动机。

## 已确认的自动步长规则

设第 `i` 个块包含方向列索引集合 `B_i`，该块的停止容差为 `tau_i`。对每个
`j in B_i`，先根据初始点计算方向候选步长：

```text
candidate_j = max(abs(x0(j)), tau_i),  if x0(j) ~= 0;
candidate_j = max(1,          tau_i),  if x0(j) == 0.
```

随后令该块的初始步长为：

```text
alpha_init(i) = max(candidate_j : j in B_i).
```

该规则与冻结的无加速 BDS reference 一致，并具有以下退化关系：

- `num_blocks = n`：每块包含一个方向列，与当前默认行为完全一致；
- `1 < num_blocks < n`：块内方向共享其候选步长的最大值；
- `num_blocks = 1`：单一步长为所有方向候选步长的最大值；
- 自定义 `grouped_direction_indices`：严格按照用户提供的方向列分块；
- 自定义 `direction_set`：继续采用 `bds.m` 已公开的既有语义，即方向集第 `j`
  列使用 `x0(j)` 的尺度，不在本轮引入投影尺度或改变接口。

## 实现范围

1. 删除生产 `set_options.m` 对 `num_blocks ~= n` 的 `auto` 禁用条件。
2. 复用 `divide_direction_set.m` 解析默认或自定义分块，不新增一次性辅助文件。
3. 逐块调用 `get_auto_alpha_init.m`，并对块内候选步长取最大值。
4. 使 `get_auto_alpha_init.m` 明确且安全地支持标量或逐坐标
   `StepTolerance`。
5. 完善 `bds.m`、`set_options.m` 和 `get_auto_alpha_init.m` 中与任意分块相关的
   注释，但不改变数值型 `alpha_init` 的现有处理。
6. 三项加速机制暂不预设代码改动；先通过针对不同块数的测试确认其使用的完整
   `n` 维位移确实与块数解耦。只有测试发现真实缺陷时才修改加速实现。

## 验证矩阵

### 自动步长与显式步长严格一致

针对以下配置，比较 `alpha_init = "auto"` 与按上述公式显式给出的数值步长，要求
solver 的 `x`、`f`、`exitflag` 和完整 `output` 均 `isequaln`：

- 默认 `num_blocks = n`；
- 多维单块 `num_blocks = 1`；
- 中间块数，例如 `n = 4, num_blocks = 2`；
- 非连续的自定义 `grouped_direction_indices`；
- `Algorithm = "ds"` 对块数的单块覆盖；
- 标量与逐块向量 `StepTolerance`；
- 加速全关和三项加速全开。

每个配置还应检查 `output.alpha_hist(:, 1)` 等于预期的逐块初始步长。

### 加速机制与既有回归门

- 增加多维单块、中间块数和自定义分块下的加速开启用例；
- 对 productive-direction memory、iteration pattern step 和 momentum
  extrapolation 保留现有定向测试，并确保至少有多维单块覆盖；
- 加速全关继续与冻结的 `bds_without_acceleration_reference.m` 严格等价；
- 默认逐方向分块且加速全开继续与 `lean_evolved_bds.m` 严格等价；
- 梯度停止、函数值停止、invalid evaluation 和其他生产 regression 不得退化。

## 执行与验收顺序

- [x] 1. 核对生产实现、公开文档、冻结 reference 和现有验证范围，固定上述语义。
- [x] 2. 先扩充自动步长测试矩阵，使新增用例在旧生产限制下准确失败。
- [x] 3. 实现任意合法分块的自动初始步长，并完善相关注释。
- [x] 4. 扩充不同块数下的加速退化与一致性测试；仅在测试暴露缺陷时修改算法。
- [x] 5. 运行本地语法/静态检查、测试契约检查和 `git diff --check`。
- [x] 6. 将当前工作区同步到服务器隔离副本，运行 MATLAB 生产 regression suite。
- [x] 7. 单独确认加速全关、加速全开、自动步长和梯度停止测试均通过。
- [x] 8. 回填完成记录，审阅最终 diff 和工作区状态。

## 完成标准

- `alpha_init = "auto"` 对所有合法块数和合法分块不再报人为限制错误；
- 默认 `num_blocks = n` 的历史行为保持不变；
- 多维 `num_blocks = 1` 与中间块数按照固定公式得到正确的逐块初始步长；
- 加速开启与关闭时，自动步长路径都与等价的显式步长路径完全一致；
- 加速全关/全开的既有严格等价性和梯度停止相关测试全部通过；
- 完整服务器 MATLAB regression suite 通过；
- 修改只涉及本计划、必要的 solver 私有实现、公开注释和维护测试，不夹带无关文件。

## 完成记录

- 新增测试先在旧生产实现上运行，并在多维 `num_blocks = 1` 用例准确触发
  `alpha_init = "auto"` 仅允许 `num_blocks = n` 的旧错误，证明测试确实覆盖本轮
  目标。
- `set_options.m` 已删除该人为限制，复用 `divide_direction_set.m` 解析实际分块，
  对每个块中的方向列计算初始点候选尺度并取最大值。默认逐方向分块的历史行为
  保持不变。
- `get_auto_alpha_init.m` 已支持一个块的标量 `StepTolerance` 同时作用于多个坐标，
  并增加同一块含多个精确零坐标的 source unit test。
- 自动步长严格等价测试现已覆盖默认逐方向分块、逐块向量容差、多维单块、中间
  两块、非连续自定义分块、自定义方向集和 `Algorithm = "ds"`。每种配置均测试
  加速全关、三项加速分别单独开启和三项全开，并与等价显式数值步长的完整 solver
  结果进行 `isequaln` 比较。
- 多维单块和中间两块的定向用例还确认 productive-direction memory、iteration
  pattern step、momentum extrapolation 单独开启时均实际改变 evaluated-point
  history，避免测试只验证开关能够被读取而没有进入机制。
- 冻结无加速 reference 的维护测试新增单块、中间块数和自定义分块下的 `auto`
  用例，生产 BDS 与 reference 完整一致。三项加速主算法无需改动。
- 本地 `git diff --check` 通过，没有残留旧限制或不一致调用；所有修改行均不超过
  120 字符。MATLAB `checkcode` 对本轮修改的自动步长 helper 和两份 focused test
  零诊断；`bds.m` 与 `set_options.m` 只有修改前已经存在的扩容和内存探测提示。
- 当前工作区两次同步到服务器 `/tmp` 隔离副本并运行完整
  `run_bds_regression_suite`。最终精确状态得到 `BDS_AUTO_ALPHA_INIT_OK`、
  `GRADIENT_ESTIMATE_VALIDITY_OK`、`GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK`、
  `GRADIENT_STOPPING_THRESHOLD_OK`、加速严格等价总验收和
  `BDS_REGRESSION_SUITE_OK`。
- 服务器原有的 `~/Work/bds` 是包含未提交实验文件的旧分支，本轮没有修改该目录；
  所有服务器验证均在独立 `/tmp` 副本中完成，验收后该临时副本已删除。
