# MP 测试分层调整：执行计划与记录

日期：2026-10-20。用户授权修改与验证，不包含 commit/push。

## 基线与范围

- 仓库：`/Users/lht97/Work/bds`，分支 `main`，HEAD
  `ece5ab04d48a3110f8b4f521229102c8e6f3b108`。
- 开始时存在上一轮 retained 移除的未提交修改；全部保留，不还原、不覆盖历史证据。
- 仓库与祖先目录未发现 `AGENTS.md`。遵守既有代码风格与先记录、后实施原则。
- 本次只调整测试与当前测试说明，不改变 production 算法、options、参考 solver 或论文。

## 测试职责

1. `src/unit_test.m` 通过正常 MATLAB private 可见性检查各子函数。
   将原 phase verifier 的 20 个场景归入此文件，使用独立的行为预期；
   不需要冻结 phase，不保留独立 production verify 入口或临时访问桥接。
2. 整体等价性验证位于 `tests/`，从 `bds` 与参考 solver 的入口调用，比较
   返回值、求值次数、完整实际求值轨迹与历史。不直接调用 production private phase。
3. 全关加速仍对照 `bds_without_acceleration_reference.m`；MP 仍对照服务器指定的
   原字节 `c03_bds_mp.m`。不放宽容差，不修改参照来通过测试。

## 执行清单

- [x] 只读核对当前文件、调用链、工作区及服务器 MATLAB 可用性。
- [x] 将 20 个 MP 分支用例纳入 `unit_test`，保留预算、目标、异常与状态检查。
- [x] 删除 `src/verify_bds_mp_phase.m`，移除 regression/smoke 中的独立 phase 调用。
- [x] 更新当前测试说明，明确单元测试与公开入口等价性测试的边界。
- [x] 在新的隔离服务器工作区运行完整维护回归、MP smoke 与严格 MP 等价性验证。
- [x] 核对本次未修改任何 production 数值代码/冻结参照；取回日志、记录结果及未验证项。

## 验证范围

本机没有 MATLAB，使用 `ssh -p 53781 lhtian97@frp-pen.com`。
不覆盖共享工作树或上一轮验证目录；在独立工作区部署当前完整快照，
并核对其与上一轮已验证快照的差异严格限于本次测试调整。
使用 MATLAB R2026a、既有 smoke、regression 和 strict runner。
完整维护回归包含单元测试、无加速等价性、初始步长及梯度/函数值停机检查。
MP strict 仍为 1890 例、零容差及完整轨迹比较。
本次未改数值算法，不重跑完整 133+133 个 S2MPJ 问题或论文性能 benchmark；
此前完整 manifest 证据保留，本次 smoke 仅作入口验证，不冒称整套实验复现。

## 执行结果

`src/unit_test.m` 新增 `run_post_poll_acceleration_phase_test`，沿用 function-based
单元测试体系。20 个场景以显式的预期求值点、最佳点和原始函数值序列构造完整预期
状态，逐项检查实际调用数、全部求值点、完整状态及成功/目标标志。保留所有原有场景，
并补齐原 verifier 依赖冻结 phase 才完成的完整状态/轨迹检查；不复制搜索循环来产生预期。

删除独立 `src/verify_bds_mp_phase.m` 及其 regression/smoke 调用。不新增桥接文件，
不修改 private 可见性。原文件可从 Git 基线和上一轮 retained 验证快照恢复。
旧执行记录中的 phase 比较描述保留作为历史事实，当前 `tests/README.md` 已更新。

独立服务器目录为 `/home/lhtian97/Work/bds_test_layering_20261020`。
上传 316 文件的完整候选快照，SHA-256：
`4312297fe8deb0f7e1dfc5f3612df7ca5ace2f82242e5deac5de9b8e9079be77`。
与上一轮最终已验证快照相比，差异严格限于本记录、unit_test、删除的 phase verifier、
两个测试 runner 和测试 README，共 6 个路径。所有 production 数值代码逐字节未变。
C04、C06 和本次复制的 33 个冻结 MP 文件逐项哈希一致。

实际运行命令（独立 screen 会话，按序执行，结果不覆盖）：

```sh
bash /home/lhtian97/Work/bds_test_layering_20261020/candidate/tests/tools/run_bds_mp_verification.sh /home/lhtian97/Work/bds_test_layering_20261020 regression smoke strict
```

`regression` 于 2026-10-20 02:15:51 UTC 完成，exit_code=0：源单元测试（含新增
20 个 MP 场景）、独立 test 文件、旧 retained API 兼容、默认配置、初始步长、
函数值停机、梯度有效性/停机/求值计数、workflow/profile/LAM/TSFSB 检查均通过。
无加速五算法各 270 例（共 1350 例）通过，另有 5 个 `500*n` / `expand=2`
完整轨迹检查通过。测试故意触发的 objective failure 警告是预期行为，不是失败。
隔离 path 中 NOMAD、NEWUOA、BFO 不可用，其可选执行检查明确 SKIP，不计入通过。

`smoke` 于 02:16:18 UTC 完成，exit_code=0：论文 options 核对、旧 API 兼容、
默认/显式配置、64 个开关/停机/目标组合、42 个严格 solver 轨迹对照及
4 个 S2MPJ manifest 用例通过。此阶段不再调用任何 production private phase。

`strict` 于 02:20:18 UTC 完成，exit_code=0：内部、外部、随机参数压力三组
各 630 例，共 1890 个零容差 iseqiv 和 1890 个完整轨迹比较全部通过。
1890 个逐例 MAT 证据文件齐全，未缩减用例、放宽容差或修改参考代码。

最终重新核对服务器 316 个候选文件及三处 33 个冻结 MP 文件，全部哈希一致。
本次 screen 会话已退出，没有遗留验证作业。本地最终只补写本执行记录，测试源码
与服务器实际运行版本相同。`git diff --check` 与 shell runner 的 `bash -n` 通过。
当前维护 `src/`、`tests/`、workflow 中已没有旧 verifier 或 `c03_phase_mp` 的调用；
现有 Unit tests 和 regression workflow 无需更改即可覆盖迁入的单元测试。

证据已回传至 Git 忽略目录 `tests/testdata/test_layering_20261020/`：

- `logs/`：完整三阶段日志与 `final_audit.log`。
- `results/`：真实退出码、阶段汇总与逐例 MAT。
- `evidence/`：测试快照、源码清单及哈希、初始 dirty state 与审计脚本。
- `reference/`：本次使用的原字节冻结 MP。
- `verification_evidence.tar.gz`：SHA-256 为
  `a7c3c4cb5a06d32dd67a365724382003706d3b0b1f7acde7ea50f6368e06039b`，
  本机与服务器一致。快照中的本记录为执行前版本；仓库中此文件补齐最终结果。

未验证项：本次不重跑完整 manifest/论文性能实验，不执行 NORMA 专属验证，
不将三个可选 solver 的 SKIP 计作通过。历史验证记录保持原样，不追改已接受结果。

最终仍在 `main`，HEAD 未变，保留上一轮 retained 移除与本轮测试分层的未提交修改；
暂存区为空，未执行 commit/push。
