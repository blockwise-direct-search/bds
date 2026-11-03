# 梯度停机简化与双阈值实验：计划与执行记录

日期：2026-10-29（北京时间）。本任务授权隔离实验、验证和服务器 screen 作业，
不授权修改 production 默认值、论文、已接受实验结果、删除旧数据或 commit/push。

## 目标与不可变项

- 基线为当前 production BDS。只改变梯度停机机制及其参数，其他数值选项逐项冻结。
- 取消参考梯度的两次同点一致性检查。首次有限的 G=norm(grad)+e 满足
  `e < max(reference_absolute_tol, reference_fraction*G)` 时固定参考值。
  主方案 `reference_absolute_tol=1e-3`、`reference_fraction=1/11`，该误差门槛在
  精确算术下等价于原来的 `e < max(1e-3,0.1*norm(grad))`。
- 参考样本本身不进入后续梯度窗口；窗口满且有新有效梯度时才检查停机。
- 最终梯度停机严格采用函数值判据的结构：窗口内所有 G 均小于
  `grad_tol*min(1,G_ref)`，或均小于 `beta_g*grad_tol*max(1,G_ref)`。
- 只调整 L_H、上述梯度参考参数、梯度容差、beta_g 与梯度窗口；函数值停机保持
  window=20、tol=1e-6、fallback factor=1e-3，绝不调参。
- 预算 500*n、expand=2、shrink=0.5、MP、初始点步长初始化及其余 options
  使用已验证的 external paper 配置。不运行其他 solver。
- 以 tau=1e-4 为必须保持的精度，同时检查 1e-2、1e-3；不接受用丢失基线成功实例
  换取更早停机。有限样本的无损失不宣称普遍保证。

## 数据与比较

使用冻结 C04/C06 的 133 个 S2MPJ 问题，6<=n<=50，MATLAB R2026a。
特征为 plain、noisy_1e-4、noisy_1e-2、linearly_transformed、
linearly_transformed_noisy_1e-4、linearly_transformed_noisy_1e-2。
plain 一次，其余每种五次，沿用冻结特征生成器和 seed=20260828。
问题清单按固定序号划分开发集与保留集（每五个问题中的第五个为保留集），
全部特征/重复沿用同一划分。参数只用开发集排序，保留集不参与再调参。

核心比较是双关、仅开梯度、函数值与梯度全开。仅开函数值用于识别不可通过
梯度调参解决的精度损失；现有 production 梯度规则作为历史机制对照。
固定评价目标，使用未加噪的评价函数，不随候选改变目标。分别报告首次达标成本、
实际总求值、输出质量、参考建立时刻、无法建立参考比例及失败实例。

## 执行路线

- [x] 核对本机/服务器源码、冻结依赖、磁盘和资源；保存哈希及完整显式配置。
- [x] 仅在 research 中建立控制代码，在隔离目录生成实验 solver，不改 src。
- [x] 建立无额外目标函数调用的事件记录与独立回放判据；记录梯度范数、误差尺度、
  求值计数、函数值停机时刻和返回点所在求值序号。
- [x] 验证双关轨迹与 production 完全相同，旧 production 与冻结 MP/无加速参照
  继续通过已有检查。验证参考选择、小梯度、窗口、两条阈值、预算及停机优先级。
- [x] 六特征小规模检查：实际运行候选与回放预测逐次轨迹/终止求值/返回值一致。
- [x] 通过后以 screen 挂完整双关基线计算（已重启，worker 已开始计算且首批结果已落盘；全量仍运行中），保存全部事件与求值，
  不额外反复跑大网格。
- [ ] 自动回放有限梯度参数网格，先用开发集零损失条件筛选，再固定候选进行保留集
  检查。若无候选满足条件，明确报告，不修改无关参数或降低精度标准。
- [ ] 对选定候选的仅梯度/联合配置进行真实 solver 运行，核对与回放及基线前缀一致。
- [ ] 保存逐实例结果、参数排序、无损失检查、求值节省与失败清单，形成可读取汇总。

## 搜索、预算及独立验证

首轮网格 L_H={10,100,1000,10000,100000}，grad_tol={1e-5,1e-4,1e-3,1e-2,3e-2}，
beta_g={1e-3,1e-2,1e-1}，N_g={1,2}；参考参数首轮固定如上。
共 150 组新规则候选，另有 3 组消融对照，总计 153 组。
包含旧规则、只简化参考、只改阈值和二者合并的消融对照。
这些是预先声明的有限候选，不按某张图临时添加参数或删除失败问题。

搜索使用完整双关轨迹的回放，前提是实际小规模/最终复跑验证停机前轨迹不变。
已提前终止的旧结果不用于假定后续轨迹。回放是筛选证据，不冒充实际候选求解。
在相同参考规则下从严格容差向宽松容差观察边界；L_H 改变可能使参考时刻变化，
不假定其单调性。若最保守候选也有丢失，保留双关基线并报告搜索范围内无合格解。

服务器独立目录 `/home/lhtian97/Work/bds_gradient_stop_20261029`。
最多 30 个 MATLAB worker，每 worker 单计算线程；启动前再次确认资源。
正式流水线总时限 48h，不是每个特征分别 48h。时间从正式作业启动时计。
临时文件与并行缓存放本次 Work 目录，避免占满 /tmp。需要至少 100 GiB 磁盘余量。
flock 防重复启动；每阶段状态/日志/失败持久化，失败不伪造完成，不覆盖已有结果。
screen 支持聊天关闭后继续运行，但报告以实际完成标记为准。

## 验证与发布边界

新停机启用时允许提前结束，与旧 solver 比较共同轨迹前缀而不是要求完整历史同长。
production 代码、参考 solver 和既有测试不为实验修改。原有完整回归和严格 MP
对照在原 production 快照上运行；实验版本另做分层测试。
不自动替换论文曲线，不重新计算 NOMAD/LAM1/NEWUOA/FD-BFGS，不清理服务器历史数据。

## 执行记录

### 源码与数据冻结

- 本机实际 checkout：`/Users/lht97/Work/bds`，分支 `main`，
  commit `67014737eaa9dbe47f7eb40e6d6829e27617277e`；开始时 clean。
  本次仅新增本计划及 `research/gradient_stop_20261029/`。
- 服务器 `candidate/` 来自该 commit 的 git archive，不是服务器其他工作树的未提交版本。
  实验 solver 位于独立 `experiment/`；不修改 `candidate/src` 或本机 `src`。
- 依赖使用已接受的 `c04_external_comparison_20261010/bundle_r8`，问题名单来自
  `c06_pure_internal_20261015/bundle_r1`。冻结依赖文件 1348 个均通过 SHA-256 核对。
- seed 沿用 20260828，FeaturedProblem 实际随机种子按冻结 runner 的
  `mod(23333*20260828 + 211*repeat, 2^32)` 计算。
- 基线总计 3458 个 feature/problem/repeat 实例；开发集 2782 个，保留集 676 个。
  新规则仅用开发集挑选；保留集不参与重新选择或扩大参数范围。
- 每个 feature/problem 的评价参考值来自本次双关基线所有重复的未加噪最佳函数值；
  三个精度目标为 `best + tau*(initial-best)`。目标不依赖候选，不冒充原论文多 solver 目标。
  同时检查历史达标与实际返回点达标；损失汇总跨精度/两种口径累加，不是去重问题数。
- 新规则记录 `e(1)` 并按 `e(L_H)=L_H*e(1)` 回放与运行（误差公式对 L_H 线性）。
  这不额外调用目标函数，但浮点运算顺序与原函数直接传入 L_H 可以略有差异。
  因此旧规则对照另存原函数以 L_H=1000 直接计算的误差，实际调用保留原停机代码；
  不用数学等价代替旧版本的逐次运行核对。

### 已完成与正在进行的验证

- MATLAB R2026a；production 的 `regression`、`smoke`、`strict` 均已退出 0。
  原无加速 5 个 Algorithm 共 1350 例、现有梯度相关测试及单元测试通过；
  冻结 MP smoke 42 例与 4 个 manifest 实例通过；严格 MP 对照 1890 例通过。
  证据：服务器 `results/{regression,smoke,strict}.status`、对应 logs 及 stage_summary.mat。
  本机备份：`research/gradient_stop_20261029/testdata/production_validation.tar.gz`
  （Git ignored），SHA-256 `136e5f72e6e8dae899932e1af11853b47b89828cfd2fc6589f04573d767fbc7a`。
- 实验预检覆盖 3 个问题、全部 6 个特征及对应重复，共 78 例，每例 13 次真实求解。
  检查双关与 production 全输出一致、旧规则与 production 一致、三种机制与回放一致。
- 首轮 2-worker 预检没有观察到断言失败，因服务器资源充裕，23:07:21 手动停止并调整
  为 12-worker 的 `preflight_retry1`；原 `preflight/`、日志与 exit_code=124 状态保留，
  该状态代表本次主动中止，不作为通过证据。
- 另有 `pipeline_smoke`：18 例（3 个问题、6 个特征、repeat=1），实际走参数筛选与复跑，
  并要求较宽松的新规则至少触发一次真实提前停机。其结果和参数不用于正式选择。
- `preflight_retry1` 于 23:13:13 完成，78/78 例、1014 次真实求解全部通过。
  `pipeline_smoke` 于 23:14:40 完成，18/18 例通过，11 例实际触发新规则提前停止。
  小样本候选在保留集有损失，被正确标记为不合格；这只验证筛选程序，不据此调参。
- 实验预检本机证据：`research/gradient_stop_20261029/testdata/experiment_preflight_validation.tar.gz`，
  SHA-256 `f68582e3f25a7c95c64e1d43a2cbad2c80af86c86a705d8f228df0fafeb5cf54`。
- 控制代码 r3 压缩包 SHA-256：
  `c9411011c844665182947f17028b8c312f1f21dffa75b7f2ed773559a6b8bc84`。
  完整源码清单 401 文件，`CONTROL_MANIFEST.json` SHA-256：
  `59e37c0dc4e9f5261f56abd55d8639da88516e14c4689821e9f74b397c030615`。
  清单包含全部 candidate/control/experiment/reference、问题名单和冻结 options；
  启动和每个阶段核对文件集合及内容，旧清单存入 evidence，不覆盖历史证据。

### 首次启动失败记录（历史状态；最新重启状态见下）

已取得两个 ACCEPTED 标记，并通过 audit 的 launch 门禁。

- 首次启动尝试：**2026-10-29 23:15:12 北京时间**（15:15:12 UTC），
  screen 曾为 `1077285.bds_gradient_experiment_20261029`。
- **23:16:55 启动失败，exit_code=1；screen 已退出。** MATLAB 尚未执行入口，
  因而没有建立 baseline 结果目录，也没有任何完整基线计算结果。
- `logs/baseline.log` 报告：`Please enter your MathWorks Account email address and press Enter:`，
  随后 `Sign-in failed. Would you like to retry? y/n [n]`。
- 独立无交互启动探针（仅打印版本，不调用实验）也退出 1 并出现同一提示，证据为
  `logs/startup_probe1.log`。目前只能确认 MATLAB 许可/登录阻塞，不能据此断言登录过期的具体原因。
- 没有访问账号密码、删除授权缓存、重启共享许可服务或修改系统配置。
  当时曾判断需要用户恢复登录/许可；后续诊断已撤回这一未经充分证实的判断，见下文。
- **48h 正式计算尚未开展；不得将 screen 曾创建视为实验已经运行。**
  恢复时须先把本次失败的 compute/baseline 状态和日志备份到 evidence 的独立目录，
  再重新通过 launch audit，禁止直接覆盖失败证据。正式开始后重新记录起止时间。
- 后续 selection、validation、report 仍已配置为自动接续；任何阶段失败即停止，
  不掩盖失败、不自动放宽验收条件。当前没有正式性能结论。
- 最终输出：`SUMMARY.json`、`REPORT.md`、`selection/scores.csv`、
  `selection/selected_cases.csv`（若选出候选）、`selection/per_case.mat`、逐例真实验证 MAT。
- `compute.status` 为整个作业状态，`baseline.status` 等为各阶段状态；日志在 `logs/`。
  只有 `compute.status` 显示 `completed exit_code=0` 才表示流水线结束；
  即使流水线成功结束，也必须看 qualified 字段，不能默认参数效果合格。
- 开始前磁盘余量约 1.5 TB；本任务没有清理任何历史数据，也没有 commit/push。

查看进度：

```bash
ssh -p 53781 lhtian97@frp-pen.com \
  'cat /home/lhtian97/Work/bds_gradient_stop_20261029/compute.status; tail -20 /home/lhtian97/Work/bds_gradient_stop_20261029/logs/baseline.log'
```

本机新增文件不代表 production 的变更；原 commit、src、examples、tests、README 和
workflow 均未修改。之后根据完整结果讨论是否采用新机制，不自动替换论文或软件默认值。

### 用户授权的正式重启

用户确认 SSH 登录后直接运行 MATLAB 正常，并明确授权重启正式实验。
随后检查中，无交互、实验 TMPDIR 和 screen 三种启动均成功退出 0；先前的
“必须重新登录”判断并无充分依据，撤回该判断，不将暂时失败推断为账户失效。

本轮按以下顺序执行，先记录再操作：

1. 通过交互式 SSH 登录，直接启动 MATLAB 并打印版本，确认用户的启动方式正常。
2. 检查没有本实验的运行进程；重新核对 401 个冻结文件、1348 个依赖文件及全部验证门禁。
3. 将首次失败的状态及将被重写的日志移入 evidence 下的独立目录，保留全部失败证据。
4. 使用原冻结控制脚本重新挂 screen，不修改算法、参数、随机种子或验收条件。
5. 确认 30-worker 池、首批真实基线结果及日志持续推进，再交接后台运行状态。
6. 补记本次启动时间、48h 截止时间、screen 名称及证据位置。

后续 MATLAB 启动排查以用户的交互式 SSH → MATLAB 方式为基准；
长实验仍使用已验证的 screen/batch 方式脱离聊天运行，不要求用户提供登录凭据。

本轮执行结果：

- 交互式 SSH 登录后直接输入 `matlab`，成功进入 R2026a 命令行并输出版本。
  退出时出现 `free(): chunks in smallbin corrupted` / `MATLAB is exiting because of fatal error`；
  如实保留这一退出异常，不将此探针算作正常退出，也不据此推断算法有错。
- 在同一个 SSH 登录终端执行 `matlab -singleCompThread -batch ...`，输出
  `BATCH_STARTUP_OK`，并确认 `BATCH_EXIT_CODE=0`，随后才有条件地启动 screen。
- 启动门禁重新通过，401 个冻结文件与 1348 个依赖文件未变化。
- 首次失败的 `compute.status`、`baseline.status`、`baseline.log`、`baseline_audit.json`
  已在独占 experiment.lock 时移入 `evidence/failed_start_20261029_231512/`；没有删除结果。
- 正式重启时间：**2026-10-29 23:31:26 北京时间**（15:31:26 UTC）。
- screen：`1108666.bds_gradient_experiment_20261029_r1`。
- 48h 截止：**2026-10-31 23:31:26 北京时间**，另留至多 120 秒退出宽限。
- 当前 baseline 阶段已实际开始计算：23:34:24 已有 23/3458 个真实基线 MAT 文件，
  日志有持续的 `CASE_START` 和 `BASELINE_SAVED`；并非只有 screen 会话存在。
  全量基线、筛选、候选真实复跑和汇总尚未完成，后续仍自动接续原流水线。
- screen 本身的日志：`logs/restart1_screen.log`；阶段日志仍为 `logs/baseline.log` 等。
