# 最终梯度停机双分支判据：生产代码实施记录

日期：2026-11-02。

## 授权与基线

用户已确认采用经过 6–50 维实验的最终梯度停机机制，并授权执行本仓库代码修改与服务器 MATLAB 验证。外部 solver 比较不属于本次验收；论文由另一个 chat 处理。本次不修改论文，不运行完整 benchmark，不提交或推送代码。

本地仓库 `/Users/lht97/Work/bds`，分支 `main`，起始 commit `67014737eaa9dbe47f7eb40e6d6829e27617277e`。仓库内无 AGENTS.md。已有四项未跟踪内容原样保留：

- `docs/development/BDS_POLL_FAILURE_REFERENCE_EXPERIMENT_20261030.md`
- `research/gradient_stop_trials_20261030/`
- `research/gradient_threshold_20261030/`
- `research/poll_failure_reference_20261030/`

实验基线只读：服务器 `/home/lhtian97/Work/bds_gradient_threshold_20261030`。其中 `candidate/src/bds_dual_threshold.m` 为已实际运行的候选版本，`candidate/src/bds.m` 为实验前正式版本；源清单及实验数据不能改写。此次另建独立验证目录，记录同步清单、SHA-256、命令、退出码与日志。

## 唯一算法改动与不变量

保留可靠参考值 G_ref 的确定方式、误差估计、同点一致性检查和后续窗口更新。参考值本身不计入后续窗口。

旧最终判据为窗口中所有 G 均严格小于 `grad_tol * max(1, G_ref)`。
新最终判据为以下两项之一成立：

1. 窗口中所有 G 均严格小于 `grad_tol * min(1, G_ref)`；
2. 窗口中所有 G 均严格小于 `1e-3 * grad_tol * max(1, G_ref)`。

采用实验的原表达式，不新增公开 option、不改变 API。`grad_tol=1e-2`、`grad_window_size=1`、`lipschitz_constant=1e3` 及参考值检查参数不变。两个额外停机开关仍默认关闭。函数值停机、预算、步长、forcing function、MP 加速及返回格式均不改。

## 验证边界

- 不修改 `bds_without_acceleration_reference.m`、lean 历史实现、冻结 MP 或历史实验 runner 来制造等价性。
- 梯度停机关闭：加速全关与无加速参照完全一致；加速打开与冻结 MP 完全一致，包括输出与实际求值轨迹。
- 梯度停机开启：用黑盒边界、参考初始化/窗口测试检查新判据；与已接受候选实现比较完整输出、求值次数及轨迹。旧判据触发而新判据继续运行属于已授权差异，单独断言，不能泛化为“允许任意差异”。
- 原有随机等价测试若覆盖到有意更改的梯度停机语义，显式区分关闭梯度停机的历史等价门禁与开启时的新机制检查。不得跳过失败或放宽数值容差。
- 小规模固定种子 S2MPJ 六特征验证仅检查移植是否精确，不开展外部比较或重新论证性能。

## Checklist

- [x] 查明当前代码、已有测试、冻结候选、MATLAB 可用性与空间。
- [x] 最小修改正式判据及相邻注释；更新必要的软件说明和过时错误提示。
- [x] 更新黑盒梯度阈值测试，覆盖小/单位/大参考、两分支、严格边界、完整窗口及已知新旧差异。
- [x] 明确历史参照等价测试的梯度开关范围；保留参照原文件。
- [x] 建立独立服务器验证快照，核对本地与服务器文件哈希及只读实验清单。
- [x] 运行聚焦测试和全部维护中的 regression suite；完成无加速参照与 MP 的严格等价门禁。
- [x] 对照已测试候选做配置矩阵和小规模六特征 S2MPJ 精确回归，检查预算、实际计数和 histories。
- [x] 验证后再次核对源码同步与冻结清单；回传证据并检查最终 diff。
- [x] 记录通过项、预期差异、未验证项和修改文件，交付用户。

## 执行结果

独立服务器目录：`/home/lhtian97/Work/bds_dual_gradient_production_20261102`。
使用登录后可直接调用的 `matlab -singleCompThread -batch`（R2026a）。未改共享的服务器 BDS checkout。

### 已完成门禁

- `focused`：正常退出，120 个实际 solver 阈值/窗口/参考初始化案例，以及共享停机、预期改变、梯度关闭等价三个额外案例；梯度有效性、无额外求值、无加速参照检查全部通过。
- `regression`：正常退出，完整 `run_bds_regression_suite` 通过，包括源级单元测试、维护中的所有聚焦检查和 1350 个加速全关精确等价案例。此随机等价门禁显式关闭两侧梯度停机，梯度开启的语义由新判据测试与候选对照覆盖。
- `mp_strict_gradient_off`：正常退出，1890 个 iseqiv(prec=0) 和完整轨迹对照通过，无失败。调用为 `verify_bds_mp_reference(folder, 'full', false)`；新第三参数仅用于明确旧参照比较的梯度停机开关，省略参数仍保留历史测试设置。
- `matrix_retry1`：正常退出，480 个 production/已测试候选完整对照，另有 240 个梯度关闭的历史参照对照；142 个案例实际触发梯度停机。覆盖三种维数、五个算法、加速全开/全关、四个停机组合、光滑/噪声/NaN/error+Inf 目标，预算 500n、expand=2。
- 源码审计：生产主函数与实验候选除函数名及整行注释外，可执行语句完全相同；26 个 private MATLAB 文件中只有 `set_options.m` 的过时错误提示文字改变，其余逐字节不变。原冻结实验的 262 个文件和 1348 个依赖全部通过原清单审计。

### 异常与重跑

第一次 matrix 的全部断言及结果保存已完成，但 MATLAB 退出时报告 `free(): chunks in smallbin corrupted` 并以 137 退出，不能算作通过。保留日志与阶段状态；相同代码/参数在新进程中的 `matrix_retry1` 正常完成。具体底层崩溃原因未确定，没有为绕过该异常改 solver 或断言。

S2MPJ 回归固定为 4 个问题（ARGLINB、ARWHEAD、BIGGS6、GAUSS1LS）、6 特征、2 seeds（20260828、20261030）、4 停机组合，共 192 个两 solver 对照，仍使用 500n 预算。首轮单进程较慢，明确终止该进程（143），保留已完成记录；只将测试调度改为 8 个 worker，随后从头执行全部相同案例。每个 worker 检查 production 与 frozen candidate 的实际解析路径，每对测试重新创建 FeaturedProblem 并重置 RNG。最终再执行 `matrix_retry2`，确保最终测试文件版本也通过配置矩阵。

### 最终复验

- `s2mpj_retry1`：192 个精确配对全部完成，4 个实际触发梯度停机；主 MATLAB 进程于 2026-11-02 14:17:48 UTC 正常退出（0）。比较完整输出、实际求值点/值、历史记录和 OptiProfiler 的真实函数值历史，无容差、无截断。
- `matrix_retry2`：最终测试文件版本再次通过 480 个候选配对、240 个历史参照配对，其中 142 个触发梯度停机；14:18:31 UTC 正常退出（0）。
- S2MPJ 的所有断言及汇总完成后，并行池关闭时一个 worker 在 14:17:45 UTC 留下 `abort()` 转储。客户端仍正常退出，192 份案例及汇总齐全；没有求值比较失败或丢失案例的报告。转储保留在该阶段 `parallel_jobs/Job1/` 中，不纳入对外证据包。此结果表示算法对照通过，不表示 MATLAB 运行环境全程无异常；底层退出异常原因未确定。
- 最终源码审计再次检查 222 个同步文件、26 个 private 文件、冻结实验的 262 个文件和 1348 个依赖。执行记录的最终文字更新一并同步并重新生成清单；未改已验证的 solver/test 代码。

### 命令与证据

服务器工作目录记作 `W=/home/lhtian97/Work/bds_dual_gradient_production_20261102`。本次运行命令如下；runner 拒绝覆盖已有阶段，重现时须另建隔离目录或使用新的 retry 后缀。

```bash
bash "$W/control/run.sh" focused
bash "$W/control/run.sh" regression
bash "$W/control/run.sh" mp_strict_gradient_off
bash "$W/control/run.sh" matrix
bash "$W/control/run.sh" matrix_retry1 s2mpj
bash "$W/control/run.sh" s2mpj_retry1 matrix_retry2
python3 "$W/control/collect_evidence.py" "$W" > "$W/results/FINAL_VERIFICATION.json"
```

控制脚本位于 `research/gradient_threshold_production_20261102/`。本地 `evidence/FINAL_VERIFICATION.json` 汇总门禁退出状态、计数及哈希；`evidence/verification_evidence.tar.gz` 保存日志、阶段状态、阶段汇总、同步清单和控制脚本，不包含崩溃转储。完整逐案例 MAT 轨迹保留在服务器 `results/`。最终同步源码另存为服务器 `candidate_verified.tar.gz`；最初的 `candidate.tar.gz` 仅是首次同步快照，不作为最终版本凭证。

### 修改范围、版本与未验证项

- production：`src/bds.m` 仅修改最终判据及说明；`src/private/set_options.m` 仅修正过时错误提示。
- 文档：`README.md`、`docs/PAPER_REPRODUCTION.md`、`examples/bds_paper_options.m` 的注释明确新判据及历史复现版本边界。
- 测试：`tests/verify_gradient_stopping_threshold.m`、`tests/verify_bds_acceleration.m`、`tests/verify_bds_mp_reference.m`，新增 `tests/verify_gradient_threshold_candidate.m`；冻结 oracle 不变。
- 本记录及独立验证控制脚本/证据新增；已有未跟踪研究内容保留。最终 `git diff --check` 通过。
- 当前仍为 `main`、commit `67014737eaa9dbe47f7eb40e6d6829e27617277e` 加上述未提交修改；没有 git add/commit/push，没有触发或声称验证 GitHub Actions。
- 本次小规模 S2MPJ 精确回归验证生产移植，不等于重跑完整性能实验。没有新跑外部 solver 比较，也没有修改论文、历史结果或图。论文中的旧 `max` 公式需由论文 chat 独立同步，这是已约定的分工而非本次阻塞项。
