# 给 BDS repo chat 的执行任务：PM 改为 MP，并与已接受实验实现严格验证

日期：2026-10-19。

请直接执行本文任务，不要只回复方案。先读本仓库 AGENTS.md，建立新的 Markdown 执行记录，再按下面清单实施、在服务器运行 MATLAB 验证、交付证据。本文补充并细化同目录的 `bds_solver_defaults_and_paper_reproducibility_handoff.md`。具体环境与验证方式以本文为准，执行时仍须检查文件是否被其他工作改变。

## 1. 已确定的目标，不再重新讨论方案

本机 BDS production solver 当前采用 pattern → momentum（PM）。将其改为论文及已接受实验使用的 momentum → pattern（MP）。保留 retained 功能，但将默认 `use_productive_direction_memory` 改为 `false`。默认 `use_iteration_pattern_step`、`use_momentum_extrapolation` 仍为 `true`。

这里不是重新设计 MP。服务器已有完成论文实验的 MP 实现，必须以冻结代码为数值参照，使用 BDS 仓库自带的 verify/iseqiv 体系验证新 production solver 与该参照一致。最终函数值接近、图形趋势接近或只通过无加速测试，均不足以验收。

保留已有显式选项及 retained 功能，不删代码，不改无关默认值。若当前代码没有顺序选项，不要求为了本任务另造一个 PM/MP 公共 API；目标就是把 production 加速顺序改为 MP。如果已有显式顺序入口，必须尊重其含义并测试兼容性。

不要修改论文仓库、已接受实验快照、原始结果或论文图表。不要启动新性能 benchmark。Git commit/push、发布版本等沿用用户在 BDS chat 中的明确授权；本文本身不新增发布授权。

## 2. 已核实的环境与工作树风险

2026-10-19，论文 chat 做了只读核查，没有修改 BDS，也没有启动 MATLAB。

### 本机

- BDS 仓库：`/Users/lht97/Work/bds`。
- 论文仓库：`/Users/lht97/Work/bds_paper`，仅供只读查证。
- 本机没有可用 MATLAB，`command -v matlab` 无输出。不要尝试本机跑 MATLAB，也不要安装 MATLAB 或用 Octave 替代验证。
- 本机 BDS HEAD 当时为 `4247229d6d8add2b0bd0327edff6c6f0441979d9`。
- 当时有未跟踪目录 `research/random_acceleration_comparison_20261006/`，必须保留。执行时重新检查全部 dirty state。
- `src/private/get_default_constant.m` 当时三个加速开关都默认 `true`。
- `src/private/run_post_poll_acceleration_phase.m` 当时确实先 pattern、再 momentum；`src/bds.m` 的帮助文字也描述 PM。

### 服务器

连接命令：

```sh
ssh -p 53781 -o BatchMode=yes -o ConnectTimeout=15 lhtian97@frp-pen.com
```

- 已成功连入，hostname 为 `zDP`。
- MATLAB 入口 `/usr/local/bin/matlab`，当时解析到 `/usr/local/MATLAB/R2026a/bin/matlab`。
- 已安装目录还包括 R2024b、R2025a；不要自行切换版本来掩盖验证差异。
- 本次只确认入口存在，没有验证当前许可、MATLAB 启动或并行池可用性。这些由你执行 preflight。
- `/home/lhtian97/Work/bds` **不是干净的本机镜像**。当时 HEAD 为 `04c246ac55e972afe3269cab1bef541550f74650`，有大量修改与未跟踪文件。
- 禁止对这个工作树 `reset --hard`、覆盖同步、`rsync --delete` 或直接 checkout 本机版本。

在服务器新建独立验证工作区，例如 `/home/lhtian97/Work/bds_mp_verify_20261019_r1`；若已存在则选择新的编号，不覆盖。将本次本机候选源码及测试作为完整快照同步到其中的 `candidate/`。保存来源 commit、dirty patch、纳入快照的文件清单和 SHA-256。本机工作树的 commit 不能单独代表未提交候选代码。

历史记录显示发生过 MathWorks services error 5001。若遇到，保存完整日志并区分许可/服务失败与算法验证失败；不要无上限重启 MATLAB，不要擅自重启账户服务或服务器。

## 3. 冻结 MP 参照：已找到，且两批结果一致

定义以下路径名称，仅为本文方便说明：

```text
C06 = /home/lhtian97/Work/c06_pure_internal_20261015/bundle_r1
C04 = /home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8
```

主要参照取 C06 的 `mp/` 整个目录。不要只拷贝一个 `.m` 文件，因为 MATLAB private 函数决定了实际行为。

| 用途 | C06 下相对路径 |
| --- | --- |
| 完整 MP solver | `mp/c03_bds_mp.m` |
| MP 阶段实现 | `mp/private/run_post_poll_acceleration_phase.m` |
| 可调用的阶段桥接函数 | `mp/c03_phase_mp.m` |
| 完整私有依赖 | `mp/private/` |
| 已有阶段测试 | `control/c05_phase_tests.m` |
| C06 显式设置入口 | `control/c04_options_record.m` |
| 加速开关与公共覆盖 | `control/c03_options.m` |
| 基础 benchmark options | `helpers/tsfsb_benchmark_options.m` |
| 冻结文件清单 | `bundle_manifest.json` |

关键 SHA-256：

```text
C06/mp/c03_bds_mp.m
db945eaec9042d50820ec899eb3297eea6797af7dd4e7331d905b9795243f302

C06/mp/private/run_post_poll_acceleration_phase.m
566972c99f1aef6fc1468670b79112ee63c6d4d8a9f3e714830872293527737f

C06/bundle_manifest.json
02c647432869ce78a12f0872c4aa13e9d2b5a037c600b19cf80268fa3dff09f5

C04/bundle_manifest.json
5e1b190532e3e311167642f713f264a47595a0705077d5576bfc55e285d33dc5
```

本轮已读取两个 manifest 的 `bundle_hashes`：两者各含 33 个 `mp/` 文件，两个 MP 清单完全相同；分别对全部 33 个实际文件重算 SHA-256，均与各自清单一致。因此内部和外部实验使用的冻结 MP 源码一致，实验 options 则不同。

执行时复核以上哈希，并将整个 MP 目录复制到新验证工作区的 `reference/mp/`，保持字节不变。可以增加独立 adapter，不要修改参照实现来让测试通过。保存复制后的清单。

不要调用旧实验的 launch/preflight 脚本来启动整个流程。部分脚本会写旧结果目录，而且 `tsfsb_setup_paths` 会强制 `bds` 指向冻结 production PM；不能直接把它当作候选 MP 的测试 setup。

## 4. MP 语义：照参照实现迁移，不凭论文文字重写

先比较 candidate 与 frozen MP 的 caller、state/config 字段及全部相关 helper。参照主函数约第 991 行开始计算 `iteration_step`，随后检查进入加速阶段的条件。行号会变化，应按符号定位。

冻结 MP phase 的关键事实如下，仍应以实际代码和 caller 为准：

1. `pattern_direction = iteration_step / norm(iteration_step)`，公共径向步长为 `max(norm(iteration_step), config.step_floor)`。
2. 若 momentum 启用，在搜索前更新其向量，权重 `momentum_decay=0.6`；更新不以随后外插是否成功为前提。norm 大于 `step_floor` 才生成归一化 momentum 方向，否则该次 momentum 搜索跳过。
3. 搜索顺序是 `{momentum_direction, pattern_direction}`，分别由两个开关控制。两者均从进入阶段时的 `state.xbase` 出发，使用 `[1,2,4]`，不是将每次成功点当作下一次外插基点。
4. 每次试探与阶段当前最佳值比较，严格变小才接受；一次搜索在第一次拒绝、预算耗尽或达到目标时停止。
5. 第一种搜索只要接受过任何点，就不再尝试第二种，即使第一种后来出现拒绝。只有第一种未产生任何改进或未尝试，且预算/目标条件允许，才可能进入第二种。
6. 第二种搜索的候选点若与第一种搜索已拒绝的点完全相同，立即停止该搜索，不重复求值。保持参照的 `isequal` 判定，不改成近似判等。
7. 保留 raw function history、无效值记录、求值计数、target handling 和 retained 显式启用时的更新规则。论文不写某项细节并不授权从实现中删掉它。

`control/c05_phase_tests.m` 已覆盖顺序、成功后不回退、首次失败后回退、动量更新、重复点、预算、目标、NaN、动量抵消以及 retained 开关。可以在新测试中复用测试构造，但必须让 **新 production phase** 也参与比较，不能仅跑冻结 PM/MP 两个桥接函数后声称 production 已通过。

## 5. 完整显式 options：内部与外部各验证一组

下面来自已核实的 `tsfsb_benchmark_options`、`c03_options(...,'D')` 和 C06 覆盖。请另外保存通过实际 options 函数生成的 MAT 记录，并检查 parser 接受哪些字段、是否有默认补充及相互覆盖。

```matlab
n = numel(x0);
o = struct();
o.Algorithm = 'cbds';
o.alpha_init = 'auto';
o.MaxFunctionEvaluations = 500*n;
o.StepTolerance = 1e-6;
o.ftarget = -Inf;
o.expand = 2;
o.shrink = 0.5;
o.is_noisy = false;
o.forcing_function = @(alpha) alpha^2;
o.reduction_factor = [0, eps, eps];
o.polling_inner = 'opportunistic';
o.cycling_inner = 1;
o.use_productive_direction_memory = false;
o.use_iteration_pattern_step = true;
o.use_momentum_extrapolation = true;
o.productive_direction_memory_size = max(1,min(n,5));
o.momentum_decay = 0.6;
o.use_function_value_stop = true;
o.func_window_size = 20;
o.func_tol = 1e-6;
o.use_estimated_gradient_stop = true;
o.grad_window_size = 1;
o.grad_tol = 1e-2;
o.lipschitz_constant = 1e3;
o.use_gradient_reference_consistency = true;
o.grad_reference_finite_difference_error_tol = 1/30;
o.seed = 20260828;
o.output_xhist = false;
o.output_alpha_hist = false;
o.output_block_hist = false;
o.output_grad_hist = false;
o.iprint = 0;
o.debug_flag = false;
```

以上是外部比较中 MP 的 solver options。`is_noisy=false` 是实际冻结设置，不能因目标函数带噪声自行改成 true。论文不介绍 consistency check 不代表可以在此删除该字段或关闭它。

C06 内部加速配置仅在以上基础上覆盖：

```matlab
o.alpha_init = 1;
o.use_function_value_stop = false;
o.use_estimated_gradient_stop = false;
```

加速关闭对照另将 pattern/momentum 开关同时设为 false；DS 对照再改 `Algorithm='ds'`。不要同时传 `Algorithm='cbds'` 与 `block_visiting_pattern`，冻结 parser 将其视为互斥。

验证时可以两边同时打开 histories、使用额外 objective recorder，并记录这些诊断设置；不要只改一边。公共默认调用与上述 benchmark options 是两件事：本任务不要求把软件所有默认参数改成 benchmark 参数。

## 6. 使用现有 verify，而不是另造宽松验收

本轮已检查以下本机文件：

- `tests/verify_bds.m`：将 production 的三个加速开关全部关闭，与 NORMA baseline 比较；**不能验证 MP 开启后的等价性**。
- `tests/verify_bds_acceleration.m`：通过 `tests/private/iseqiv.m` 比较加速关闭的参考实现，并比较原先三种加速全开与 `lean_evolved_bds`；后者是旧语义参照，不可要求新 MP 与旧 PM 天然一致。
- `tests/verify_bds_momentum_duplicate.m`：旧 PM 的重复点回归。迁移到 MP 后须逐项判断哪些预期仍适用，不能为通过测试随意改 expected values。
- `tests/private/iseqiv.m`：支持 solver function handles，入口为 `iseqiv(solvers,p,ir,single_test,prec,options)`。

请新增明确入口，例如 `tests/verify_bds_mp_reference.m`，复用现有 `iseqiv`，参照端调用原字节的 `c03_bds_mp`，候选端调用 production `bds`。放在 `tests/` 中，使 MATLAB 可以按正常 private 作用域访问 `tests/private/iseqiv.m`。不要将所有 private 目录递归加到 path。

### 必须处理的 verify 陷阱

1. 采用 `prec=0`，不通过放宽容差掩盖算术/顺序变化。目标是相同运行环境、相同输入/options/随机 realization 下与参照实现严格一致，不是跨平台逐位一致的承诺。
2. 当前 `iseqiv` 内部生成/随机覆盖测试 options，不会自动转发外层 options 的每个字段。wrapper 必须清楚合并配置，确保两边拿到同一份有效 options。分别做固定论文配置和随机参数压力测试，不能互相冒充。
3. 设置显式 seed，避免默认按日历周改变用例。参照现有 verify 的 seeds `[12345,23456,34567]`、维度 `1:10`、`ir=0:20`。记录最终生成的用例参数；先小规模 smoke 再完整执行。
4. 现有 `iseqiv` 只核对部分输出：`x/f`、部分字段名、截取后的 `fhist`，以及 `prec=0` 时的 exitflag/funcCount；它不核对完整 `xhist`，也不逐项比较全部 output 值。**调用 iseqiv 必须保留，但还要补充两侧真实 objective 调用点/值、次数、完整同长 histories 的严格断言。** NaN/Inf 用明确的 `isequaln` 等规则处理，不能让 NaN 比较静默通过。
5. 不得将 histories 截成公共后缀来声称完整轨迹一致。记录实际函数调用是为了发现求值顺序、重复点和额外求值差异。
6. 当前 `iseqiv` 在 `~equiv` 后有一个无条件 `keyboard`，后面还有条件 `keyboard`。仅设置 `options.sequential=false` 并不能避免无人值守挂起。请最小化增加非交互失败模式，保留原比较标准，失败先保存用例及两侧输出，再抛出 error。保留现有交互使用方式，新增 runner 显式启用非交互模式，并测试故意不一致能非零退出。
7. `tough` 与自定义噪声目标的随机实现要检查。两个 solver 调用不能消费不同 realization；分别重置/隔离相同随机状态，或使用经验证的确定性 realization 机制。不得凭“同一个 seed 字段”就认定噪声相同。
8. 不要修改冻结 reference 或旧 lean reference 来迎合候选代码。若旧全开 PM 测试因目标改变不再适用，明确保留其历史参照意义，另加新的 MP 验证；保留无加速回归覆盖，不能删除失败测试后宣称全部通过。

### 覆盖与判定

- 默认 retained 关闭，以及显式相同默认配置的等价性。
- 两种论文设置：C04 外部、C06 内部；覆盖两个 optional stopping 开关的独立组合及共同开启。
- MP phase 的各个分支，尤其“接受再拒绝”和“一次也未接受”的区别。
- 全部加速关闭、只有 pattern、只有 momentum、两者均开启；retained 显式开启的独立兼容性测试。
- 行/列初始向量、有限/NaN/Inf/异常返回、目标达成、小预算和预算恰好耗尽、重复点、动量抵消。
- 无加速下原有 `cbds/pbds/rbds/pads/ds` 回归；不要将 cbds 参照等价性扩大宣称到未测配置。
- 使用冻结 S2MPJ problem manifest 做论文范围的回归，至少对 manifest 中全部 133 个问题（6–50 维）做 plain 双实现轨迹比较，分别使用内部/外部设置。无需跑 OptiProfiler、绘图或重跑六个 feature 的性能 benchmark。
- noisy/异常压力测试使用仓库 verify 测试机制，明确它不等同于完整 OptiProfiler 性能实验；若要复用 OptiProfiler noise realization，必须使用冻结实现，不能自行重造论文噪声模型。

`verify_bds.m` 有历史 blacklist，不能将其问题集视为论文的全体 133 问题；上面新增的 manifest 回归不得静默排除失败问题。说明实际通过、失败、跳过数量，跳过不算通过。

## 7. 服务器执行与 MATLAB path 隔离

按顺序完成并记录：

- [ ] 本机记录 base commit/dirty，先创建执行记录。
- [ ] 复核冻结哈希、复制 reference 到新的隔离工作区。
- [ ] 完成候选代码及验证入口，静态检查后同步 candidate 快照并核对 SHA-256。
- [ ] 运行 MATLAB 启动 preflight，记录 `version`、`ver` 和实际可用依赖；先串行 smoke，确认后再决定是否并行。
- [ ] 每个测试 MATLAB 会话用 `restoredefaultpath` 和显式 `addpath` 建立必要路径，不用可能修改永久 MATLAB path 的 `setup install`。
- [ ] 记录并断言 `which bds -all`、`which c03_bds_mp -all`、相关 loader 路径；确认 candidate 与 reference 真是两个不同实现。
- [ ] 如用并行池，在 worker 上也验证路径和代码身份；没有必要时不建池，不默认抢占 30 workers。
- [ ] 先运行阶段测试及少量完整 solver smoke，再运行 verify suites 与 manifest 回归。

冻结 S2MPJ 所需路径可从 C06 中只读取用：

```text
optiprofiler/matlab/optiprofiler
optiprofiler/matlab/optiprofiler/problem_libs
optiprofiler/matlab/optiprofiler/problem_libs/s2mpj
optiprofiler/matlab/optiprofiler/src
problem_manifest.mat
```

只加所需依赖，不能调用冻结 `tsfsb_setup_paths` 后让 `bds` 意外解析成旧 production。若复用同名 `c04_options_record`，两个 bundle 必须分开解析，生成两组 options 后保存，防止 path shadowing 把内部/外部配置混成一组。

旧 `verify_bds` 还依赖 `bds_development/norma`。本次只读搜索没有确认该依赖可用，找到的其他项目下 `norma` 不是其可替代品。请按 `locate_norma.m` 检查；缺失则报告或依照仓库既有文档准备匹配版本，不得冒用 PRIMA 的同名目录。

## 8. 长测试必须 screen，失败必须可见

在隔离工作区创建 `run_verify.sh`、MATLAB runner、`logs/`、`results/`。启动方式：

```sh
screen -dmS bds_mp_verify_20261019_r1 bash /home/lhtian97/Work/bds_mp_verify_20261019_r1/run_verify.sh
```

这是建议的新目录名；若冲突请统一换名。该脚本尚未存在，必须由你实际创建和测试，不能复制命令后声称已运行。

每阶段使用有上限的命令，例如：

```sh
timeout --kill-after=30s 1800s /usr/local/bin/matlab -batch "run('/absolute/new/workspace/run_smoke.m')" > /absolute/new/workspace/logs/smoke.log 2>&1 < /dev/null
```

上面的 `1800s` 仅为 smoke 上限示例；完整测试上限应根据 smoke 计时设置并记录，不改变用例数来赶超时。脚本必须捕获 MATLAB/timeout 退出码，原子写入阶段状态（started/completed/failed/timeout），失败保存诊断并非零退出。不要因为 `set -e` 提前退出而漏写失败状态，也不要只凭日志出现 passed 就忽略退出码。

正式 screen 启动后核实 screen、PID、日志增长和已完成 case 数，而不是只确认会话存在。低频监视（例如每 5–10 分钟检查一次，依测试耗时调整），不要高频轮询消耗 token。SSH/本机断网不应影响服务器验证。完成后有明确总状态及数量汇总，失败时能按相同快照/配置恢复未完成阶段，不覆盖失败现场。

## 9. 验收交付

必须提供以下内容，不要仅回复“verify 通过”：

1. 本机修改文件、base commit、dirty diff、候选快照哈希。
2. 参照文件路径、关键哈希及整个 MP 目录清单核验结果。
3. PM → MP 和默认关闭 retained 的实际代码位置，帮助文字/示例同步结果。
4. 新 verify 入口、实际执行命令、非交互失败机制、seed 与有效 options。
5. iseqiv 与完整轨迹检查各自通过/失败数量，完整日志、MAT 与机器可读汇总位置。
6. 133 问题 manifest 回归的实际数量、内部/外部配置分别的状态，任何跳过或差异。
7. 原有无加速和其他相关回归状态，说明旧 PM 专属测试如何处理，不能冒充新 MP 通过证明。
8. 最终服务器工作区、screen/任务状态；将简洁报告和必要日志/MAT 拉回本机 BDS 实验目录，不写进论文仓库。
9. 若全部通过，明确结论限定为“本候选版本在所列配置与用例下，与已接受实验的冻结 MP 参照严格一致”。若不通过，列出第一个分歧点及原因，不以相近性能代替一致性。

测试完成并不自动授权替换服务器共享工作树或重跑论文实验。先交付候选实现和验证证据，论文 chat 再据此处理后续论文侧事项。


## 10. BDS chat 补充硬性约束与执行记录

- 所有加速关闭必须与 `bds_without_acceleration_reference.m` 保持等价，不修改该参照迎合候选代码。
- 新加速语义必须与指定冻结 MP 一致，旧全开 PM 参照不作为新 MP 等价性标准。
- 遵循 `src/bds.m` 与 `src/private/inner_direct_search.m` 的命名、注释排版及组织风格。
- 本次不 commit/push，不修改论文、冻结参照或历史结果。

### 执行基线

2026-10-19 本机 `/Users/lht97/Work/bds`，分支 `main`，HEAD `4247229d6d8add2b0bd0327edff6c6f0441979d9`。
已有未跟踪目录 `research/random_acceleration_comparison_20261006/`，完整保留。仓库无 AGENTS.md。

### 阶段状态

- [x] 读取任务并记录本机 baseline / dirty state。
- [x] 核验 C06/C04 冻结 MP 与论文配置，创建隔离服务器工作区。
- [x] 完成最小生产代码迁移、文档与显式论文配置入口。
- [x] 完成非交互 iseqiv 与完整轨迹验证入口、针对性阶段测试。
- [x] 同步候选完整快照、清单、dirty patch 与 SHA-256。
- [x] MATLAB preflight、smoke、故意失败的非交互验证。
- [x] 完整严格验证与 133 问题内部/外部回归。
- [x] 原有无加速、梯度停机等相关回归。
- [x] 回传证据、审查 diff、记录实际通过/失败/跳过和限制。

### 查证结果与第一轮实施

| 项目 | 修改前 | 目标 / 本次处理 |
| --- | --- | --- |
| retained 开关 | `use_productive_direction_memory=true` | 默认 false，显式 true 与实现保留 |
| 后轮询顺序 | pattern → momentum | momentum → pattern，第一次搜索接受过任一点后不得回退 |
| 顺序公共 API | 不存在 | 不新增 API |
| 两个后轮询开关 | 均 true | 不变 |
| 其他生产默认值 | alpha_init=1、额外停机均 false、expand=2 等 | 全部不变 |
| 内部配置 | C06 显式 options | 新 examples 入口逐项匹配，单位初始步长、停机关闭 |
| 外部配置 | C04 显式 options | 新 examples 入口逐项匹配，auto 与两种停机开启 |

production `src/bds.m` 与冻结 `c03_bds_mp.m` 原先仅函数名不同；private 目录原先
只有后轮询 phase 不同。全部 33 个冻结文件与两个 manifest 均重新计算哈希验证一致。
独立工作区：`/home/lhtian97/Work/bds_mp_verify_20261019_r1`。
原始 MP 已逐字节复制至 `reference/mp/`，未修改参照及服务器共享工作树。

MATLAB R2026a（26.1.0.3203278）preflight 成功，exit_code=0。C06 与 C04 的
`c04_options_record` 分开解析，保存 `results/frozen_options.mat`。
新 options 入口与这两个原始输出的字段及 forcing function 已在 smoke 中核对。

第一份打包过程遇到未初始化的 `.github/scripts` gitlink，未启动 MATLAB；保留不完整
快照到 `evidence/incomplete_snapshot_r1`，重新打包时如实保留空目录并记录 submodule
commit，不擅自安装。315 个文件的 r2 完整快照已核对所有 SHA-256。

第一轮 smoke 已通过 20 个 phase 分支、128 个显式开关/停机/目标组合、3 个默认等价
检查和 42 个 iseqiv+完整轨迹用例；随后发现新增 manifest adapter 把 `Problem.fun`
方法误当属性。修正为 `@(x) problem.fun(x)`，不涉及算法改动；失败日志与 MAT 原地
保留，重试使用独立的 `smoke_retry1` 结果目录，不覆盖失败现场。

现存旧 lean 比较中的一维重复点、常数目标、停机机制测试仍保留：这些特定用例的
语义不依赖一般 PM/MP 顺序差异，最终以实际执行结果为准。旧完整 PM 全开 verifier
移存 `tests/archive/legacy_pm/verify_bds_acceleration_pm.m`，不把它当 MP 的 oracle。

### 第二轮 smoke 与完整验证启动

候选完整快照 r3：315 个文件逐一 SHA-256 核验通过；未初始化的 gitlink 另存记录。
`candidate.tar.gz` SHA-256：
`2ce4ce5596cf0a0f9e4c596f898c6259b4343a69e73c1b4489f1729bff8bd7ab`。
完整快照、文件清单、base commit、tracked dirty patch 和 untracked 文件列表均位于
`evidence/bds_mp_snapshot_20261019_r3/`。

`smoke_retry1` exit_code=0：20 phase、3 默认配置、128 开关/停机/目标类型组合、
42 iseqiv+完整轨迹、4 S2MPJ pair 全部通过。显式 retained 的实际求值轨迹与关闭时不同，
确认测试确实执行了该功能。`deliberate_failure` exit_code=1，诊断 MAT 已保存，shell
状态为 expected_failure，确认非交互失败不会进入 keyboard。

另用隔离的原始 C04/C06 options 函数对维数 `[1,2,7,30]` 的 16 组设置做审计，
覆盖内部 MP/noacc/DS 与外部 MP，全部字段及 forcing function 检查通过；原始/候选
options 保存到 `results/paper_options_audit.mat`。

2026-10-19 05:49:02 UTC 启动两个独立串行会话，无 parallel pool：

```sh
screen -dmS bds_mp_strict_20261019 bash /home/lhtian97/Work/bds_mp_verify_20261019_r1/run_verify.sh /home/lhtian97/Work/bds_mp_verify_20261019_r1 strict regression
screen -dmS bds_mp_manifest_20261019 bash /home/lhtian97/Work/bds_mp_verify_20261019_r1/run_verify.sh /home/lhtian97/Work/bds_mp_verify_20261019_r1 manifest
```

smoke 总耗时约 33 秒，前两个 S2MPJ pair 约 3–5 秒。考虑全体问题有昂贵长尾，
完整 strict / regression 上限分别 6h，manifest 上限 12h；不缩减用例或预算。
启动后核对了 screen、MATLAB PID、日志增长和通过计数。

按 `locate_norma.m` 的目录签名在服务器 home 范围只读搜索，没有找到
`bds_development/norma`，因此依赖它的额外 `verify_bds.m` 不能声称运行通过。
这不替代或省略仓库内 `bds_without_acceleration_reference.m` 的五算法等价性验证。

完整 strict 于 05:53:45 UTC exit_code=0：固定内部 630、固定外部 630、随机参数压力
630，总计 1890 个 iseqiv 与完整轨迹检查全部通过。
第一次 regression 在已通过 unit、auto-alpha、重复点、无加速直接比较、函数值停机、
三项梯度验证与 workflow mappings 后，因 `lam_paper_exact` 未在 MATLAB path 上而失败。
原因是原 `run_bds_regression_suite` 只加入 src/tests，没有加入 LAM 所在的 competitors；
早前 verifiers 各自恢复 path，因此不能靠其临时 addpath 留下依赖。
最小修复是在 suite 入口显式加入 `tests/competitors`，不改变 LAM 或任何测试预期。
保持首轮失败日志和快照，重试阶段命名为 `regression_retry1`。此修复只涉及独立回归入口，
不改变正在运行的 manifest 使用的 solver/loader/轨迹检查文件。

在 manifest 长耗时问题运行期间补充无加速硬约束的直接覆盖：保留原先 1.8 扩张因子的
历史检查，另在 `500*n`、`expand=2`、固定 seed 下对五种算法比较真实调用点、原始值、
异常与全部 output。使用同一个 `record_bds_execution`，不修改无加速参照。
这只增加测试，完成后以独立 `regression_retry2` 重新运行整个维护回归入口。

`regression_retry2` 于 06:12:10 UTC exit_code=0：维护回归入口完整通过，包含五算法
各 270 例（共 1350 例）无加速 iseqiv，以及新增 5 个 `500*n` / `expand=2` 全轨迹
比较。原有函数值停机、梯度有效性、梯度停机不增加求值、梯度阈值等均通过，未改预期。
可选外部 solver 执行检查在隔离 path 下跳过 NOMAD、NEWUOA、BFO，单独记录，不计入通过。

另重算冻结 OptiProfiler/S2MPJ 与 problem manifest 共 1270 个文件的哈希，全部与
C06 bundle manifest 一致；最终收集脚本会再次复核这些依赖及 C04/C06/copied MP。

### 最终数值验证结果

manifest 于 2026-10-19 07:21:06 UTC 完成，exit_code=0。全部 133 个问题均使用
完整 `500*n` 上限，内部与外部设置各运行一遍，没有排除慢问题、截短历史或放宽比较。
这不是新性能 benchmark；两端相同环境下逐点验证同一候选与冻结参照。

| 检查 | 实际结果 |
| --- | --- |
| production phase 与冻结 MP 分支比较 | 20/20 |
| 默认调用与显式默认配置 | 3/3 |
| 加速开关 × 停机 × 目标类型 | 128/128，含 retained 显式启用 |
| 真实 C04/C06 options 审计 | 16/16 |
| `iseqiv(prec=0)` | 1890/1890，内部/外部/压力各 630 |
| 上述用例完整调用轨迹及全部返回值 | 1890/1890 |
| S2MPJ plain manifest 内部配置 | 133/133，失败 0、跳过 0 |
| S2MPJ plain manifest 外部配置 | 133/133，失败 0、跳过 0 |
| 无加速五算法 `iseqiv` | 1350/1350，每种算法 270 |
| 无加速 `500*n`、`expand=2` 完整轨迹补充 | 5/5 |
| 现有维护回归及函数值/梯度停机 | `regression_retry2` exit_code=0 |
| 故意不一致的非交互测试 | 按预期 exit_code=1，诊断 MAT 保存，无 keyboard 挂起 |

通过计数不包括历史 harness 失败；第一轮 smoke 与 regression 的失败及重试日志均保留。
完整轨迹比较使用相同 RNG 状态，核对真实 objective 调用点、原始值、异常标识、次数及
完整 output，NaN 使用 `isequaln`，不截取公共历史来代替全轨迹。
固定内部、固定外部与随机参数压力的有效 options 和输入分别保存在每例 MAT 中。

最终回归重试命令（同一隔离工作区）：

```sh
bash /home/lhtian97/Work/bds_mp_verify_20261019_r1/run_verify.sh /home/lhtian97/Work/bds_mp_verify_20261019_r1 smoke_retry1
bash /home/lhtian97/Work/bds_mp_verify_20261019_r1/run_verify.sh /home/lhtian97/Work/bds_mp_verify_20261019_r1 deliberate_failure
bash /home/lhtian97/Work/bds_mp_verify_20261019_r1/run_verify.sh /home/lhtian97/Work/bds_mp_verify_20261019_r1 regression_retry2
```

这些是已执行的阶段名；runner 拒绝覆盖已有结果。重新验证应使用新工作区或新 retry 名称。
strict/manifest 的完整 screen 命令见上节；MATLAB 实际入口由 runner 保存到日志中。

### 范围与未验证项

- NORMA 的要求目录未找到，`tests/verify_bds.m` 没有运行，不计入通过。
- 隔离 path 下可选 NOMAD、NEWUOA、BFO 执行检查跳过，不据此推断服务器全局未安装。
- 未重跑论文 noisy/transformed 性能实验，未验证跨 MATLAB 版本/平台逐位一致性。
- 旧 PM 全开比较只作历史归档；没有修改其 lean 参照，没有把它冒充 MP 验证。
- 没有发现需要论文 chat 修改的配置/执行语义冲突。论文仍不必介绍 retained；如后续需
  引用新的软件版本，应等用户授权 commit 后再记录正式 commit，本次不虚构版本号。
- 未修改论文、接受的历史结果、冻结 runner、服务器共享 BDS 工作树；未 commit/push。

结论限定为：**本候选版本在所列配置与用例下，与已接受实验的冻结 MP 参照严格一致。**
这不等于重新验证论文全部性能结论。

### 最终交付位置与源码核对

服务器阶段收集 exit_code=0，`screen -ls` 显示无剩余会话。本次验证任务全部结束。
证据包已经下载并解压到本机：
`research/mp_production_alignment_20261019/testdata/`（按现有规则 Git ignored）。
`verification_evidence.tar.gz` 的本机/服务器 SHA-256 均为：
`1043bbf039094f0b03321207e11a3138460125e02fec776cd2135b4536e6e319`。

- `verification_summary.json` / `results/verification_summary.json`：机器可读数量、退出码、跳过项。
- `logs/`：所有阶段日志，包括失败现场及后续成功重试。
- `results/strict/`、`results/manifest/`：逐例输入、有效 options、两侧完整轨迹与输出 MAT。
- `reference/mp/`、`evidence/reference_hashes.json`：原字节 MP 及哈希清单。
- `evidence/frozen_configuration/`：C04/C06 显式配置源及问题 manifest。
- `evidence/bds_mp_snapshot_20261019_r3/`：测试初始完整快照与 dirty patch。
- `candidate/`：服务器最终实际测试的源码，包含两项已重跑的 regression 测试修正。
- `final_snapshot/`：含最终交付文档的本机完整快照、文件哈希、dirty patch、base commit。
- `final_audit.json`：最终快照哈希、本机与实际测试源码的逐文件核对、未提交状态。

证据包内 `evidence/collection.status` 是打包时的 waiting 状态；包外本机根目录的
`collection.status` 单独下载自打包完成后，内容为 `completed exit_code=0`。
不覆盖原始包内文件来掩盖收集顺序。

本机 `src/`、`examples/`、`tests/` 与下载的实际测试 candidate 逐文件相同。
最后的文档补充不改变已测试 MATLAB 源码。`git diff --check`、runner 的 `bash -n`
均通过；`tests/competitors/` 和 `src/private/inner_direct_search.m` 无 tracked diff。
原始任务逐字保留在本记录开头，已有用户 research 目录保留。

核心修改位置：`src/private/get_default_constant.m:83` 默认关闭 retained；
`src/private/run_post_poll_acceleration_phase.m:113` 为 momentum 搜索，`:148` 为
pattern 回退。`src/bds.m` 只同步帮助说明，生产入口仍为 `bds`。
新增入口 `examples/bds_paper_options.m` 与可直接运行的 MATLAB 调用见
[`../PAPER_REPRODUCTION.md`](../PAPER_REPRODUCTION.md)。帮助文字、README、
Rosenbrock 示例及默认值单元测试均已同步。验证文件清单见本实验 README 与最终快照。

最终分支仍为 `main`，HEAD 仍为 `4247229d6d8add2b0bd0327edff6c6f0441979d9`。
工作区含本次修改/新文件及原有未跟踪目录，暂存区为空，未 commit、未 push。
该 HEAD 不是候选版本身份；必须同时使用快照和 dirty patch。
