# 自动初始步长向一般方向基推广计划

## 目标

将 `options.alpha_init = "auto"` 从坐标方向集推广到
`get_direction_set.m` 最终生成的任意正负基，并保持任意合法块数和自定义分块下的
明确语义。现有坐标基行为、
数值型 `alpha_init` 行为和三项加速机制均不得发生回归。

本轮不试图消除“同一块中的多个方向共享一个步长”这一结构性限制。单块 DS 只能使用
一个共同步长，而逐方向分块的 BDS 可以保留逐方向尺度；这正是从 DS 推广到 BDS 的
动机之一。

## 已确认的几何规则

设初始点为 `x0`，第 `b` 个块的步长下限为 `tau_b`。先把 `abs(x0)` 解释为原始
coordinate axes 上的尺度半径，并定义

```text
s_i^(b) = max(abs(x0_i), tau_b),  x0_i ~= 0;
s_i^(b) = max(1,         tau_b),  x0_i == 0.
```

记 `S_b = diag(s^(b))`。对于 `get_direction_set.m` 最终返回的正方向基
`D_+ = [d_1, ..., d_n]`，方向 `d_j` 的系数尺度为

```text
r_bj = 1 / norm(S_b^(-1) * d_j, 2).
```

若第 `b` 个块包含正方向索引集合 `J_b`，则该块共享的初始步长为

```text
alpha_b = max(tau_b, max(r_bj : j in J_b)).
```

这不是直接旋转尺度向量，也不是计算 `D_+^(-1) * x0`。它把 coordinate axes 上的
尺度半径看作一个轴对齐椭球，再计算每个实际 polling direction 到该椭球边界所需的
系数。外层 `tau_b` 还保证缩放过的非单位方向不会产生低于 `StepTolerance` 的步长。

## 兼容性要求

- 坐标基且 `num_blocks = n`：严格恢复逐坐标的既有自动步长。
- 坐标基且块数任意：严格恢复当前的块内最大值规则。
- 一般非奇异基：使用最终正方向列计算方向尺度，不使用原始未修复的
  `options.direction_set`。
- 一般基且块数任意：先得到每个实际方向的尺度，再对块内方向取最大值。
- 数值型标量或逐块 `alpha_init`：处理路径和结果保持不变。
- productive-direction memory、iteration pattern step 和 momentum extrapolation：
  继续作用于完整变量空间位移，不因本轮推广改变算法。
- 完整仿射不变性不属于本轮目标。

## 实现步骤与验证关卡

- [x] 1. 固定起点并保护无关工作区；确认本地与 canonical GitHub `main` 一致。
- [x] 2. 扩充测试，覆盖一般基、任意块数、缩放列、修复后的方向集和梯度停机；在旧实现
      上确认至少一个一般基用例准确失败。
- [x] 3. 将 `"auto"` 的数值解析延后到 `get_direction_set.m` 和分块完成之后；保持
      `get_auto_alpha_init.m` 的四参数接口和坐标尺度职责不变。
- [x] 4. 按上述椭球公式计算最终正方向的系数尺度，再形成逐块 `alpha_all`。
- [x] 5. 完善 `bds.m` 与 `set_options.m` 的公开和内部注释，执行格式、行宽、残留标记及
      `git diff --check` 审查。
- [x] 6. 将工作区同步到服务器 `/tmp` 隔离副本，运行新增 focused tests 和 MATLAB
      `checkcode`，不修改服务器现有 `~/Work/bds`。
- [x] 7. 运行完整 `run_bds_regression_suite`，并单独确认加速全关、加速全开、梯度估计和
      梯度停机相关标记全部通过。
- [x] 8. 回填本文件的完成记录，审阅最终 diff，只暂存本轮文件。
- [x] 9. 在本地提交，并只推送到 canonical
      `git@github.com:blockwise-direct-search/bds.git` 的 `main`，随后复核远端一致性。

## 完成标准

- 新旧坐标基用例完全一致；
- 一般基在逐方向块、中间块数、单块和非连续自定义分块下均与独立算出的显式步长路径
  `isequaln`；
- 缩放方向列和由 `get_direction_set.m` 修复的方向输入均使用最终基得到正确结果；
- 一般基下自动步长与显式步长的梯度停机行为一致；
- 三项加速分别开启、全部开启和全部关闭的自动/显式路径均一致；
- 全部既有 MATLAB regression 和严格等价性检查通过；
- 代码风格与现有生产文件一致，提交不包含无关研究目录。

## 完成记录

- 新增测试先在尚未修改的生产实现上运行，并在一般方向基的非连续自定义分块用例准确
  失败；失败发生在加速全关路径，证明旧代码仍把方向列索引直接解释为 `x0` 坐标索引。
- `set_options.m` 现在只校验并保留 `"auto"` 标记。`bds.m` 在
  `get_direction_set.m` 生成最终正负基且 `divide_direction_set.m` 完成分块后，按照本
  计划的椭球公式生成逐块 `alpha_all`。既有 `get_auto_alpha_init.m` 接口没有改变。
- 自动步长定向测试现覆盖坐标基历史行为、旋转基的逐方向分块/两块/单块/非连续分块、
  非单位方向列的 `StepTolerance` 下限，以及输入全零方向集被修复为最终基的情况。
- 每项一般方向基配置均比较 `"auto"` 和独立算出的显式数值步长；三项加速分别开启、
  全部开启和全部关闭时，返回值和完整 `output` 均通过 `isequaln`。
- 新增一般方向基梯度停机用例同时检查初始 `alpha_hist`、自动/显式路径完整一致，并确认
  实际以 `exitflag = 5` 触发梯度停机。
- `git diff --check` 和 120 字符行宽检查通过，没有新增 `%#ok`。MATLAB
  `checkcode` 对新增测试零诊断；两个生产文件只保留本轮未触及位置原有的数组扩容和
  内存探测提示。
- 服务器 `/tmp/bds-auto-basis.8L3Fny` 隔离副本中的完整
  `run_bds_regression_suite` 已通过，并取得 `BDS_AUTO_ALPHA_INIT_OK`、
  `GRADIENT_ESTIMATE_VALIDITY_OK`、`GRADIENT_STOP_NO_EXTRA_EVALUATIONS_OK`、
  `GRADIENT_STOPPING_THRESHOLD_OK`、加速严格等价总验收和
  `BDS_REGRESSION_SUITE_OK` 六项成功标记。
- 服务器验证结束后，隔离副本已删除。服务器现有 `~/Work/bds` 从未被修改；本地未跟踪的
  `research/common_pool_stopping_benchmark/` 也始终未被同步或纳入本轮差异。
