# 移除 production retained acceleration：执行计划与记录

日期：2026-10-20（Asia/Shanghai）。用户授权实施与服务器验证，不包含 commit/push。

## 基线与不可破坏的原则

- 本机 `/Users/lht97/Work/bds`，`main`，基线 `ece5ab04d48a3110f8b4f521229102c8e6f3b108`，开始时工作区干净，无仓库 AGENTS.md。
- 删除 retained 的实现、方向/步长存储、容量、入队/淘汰及 pre-poll 流程；不重构 MP 或修改其他默认值。
- pattern、momentum 全关必须与 `bds_without_acceleration_reference.m` 一致。
- MP 必须与 C06/C04 的原字节冻结 MP（retained=false）严格一致；不修改 oracle 来通过测试。
- 风格参照 `bds.m`、`inner_direct_search.m`。保留论文、历史研究 runner、冻结结果和已有用户文件。
- 旧选项：逻辑 true 明确报错；false 兼容并移除内部字段；容量参数警告后移除。不创建 retained 状态。
- 旧开关空值沿用未指定语义；非空非法类型仍按原逻辑标量规则报错。容量既已弃用，不再用于计算或分配。

## 摸排与处理边界

生产入口涉及 `src/bds.m`、`private/set_options.m`、默认常量及 post-poll phase。
四个 retained 专属 helper 可删除：`run_productive_direction_memory_phase`、
`try_productive_direction_extrapolation`、`admit_productive_direction_to_memory`、
`insert_productive_direction_at_memory_front`。历史 Git commit 保留完整实现。

维护测试中存在 retained=true 的梯度、初始步长和函数停机用例。改为测试剩余 MP，
保留停机/计数断言；依赖 retained 的旧 lean 轨迹不能继续作为 MP oracle，须明确区分。
保留历史 lean 自身测试；新的 MP 预期须以冻结 MP 或独立行为推导为依据，不照候选输出来改。

`tests/profile_optiprofiler.m` 是当前维护入口，通用加速配置改为 MP；明确点名 memory 的
旧配置不得被静默映射到其他算法，必须明确报错。research 中的历史 runner 不改；
涉及其 options 的维护验证保留原配置审计，运行新 production 时显式记录必要转换。
旧 retained 配置不能再用于运行新 production；复现旧实验必须使用对应历史代码。

## 阶段清单

- [x] 核对基线、摸排生产逻辑、测试及文档调用链，先建立本记录。
- [x] 删除 production retained 状态与四个专属 helper，落实旧选项兼容。
- [x] 更新当前文档、论文 options 入口、维护调用方与测试；不改历史 runner/oracle。
- [x] 创建新的隔离服务器工作区，完整快照及哈希，核验冻结 MP、依赖与 MATLAB。
- [x] 通过旧 API 兼容、MP 分支、默认/显式行为和小规模 smoke；保存失败现场。
- [x] 完整 iseqiv + 全轨迹 1890 例，五算法无加速 1350 例及 5 个纸面预算全轨迹。
- [x] 内部/外部各 133 个 S2MPJ plain 问题，预算 500*n、expand=2，无排除。
- [x] 全部维护回归、梯度与函数值停机；不把缺失依赖/历史语义当作通过。
- [x] 下载日志/MAT/汇总，核对最终源码和 diff，报告范围与未验证项。

## 验证与取证约定

服务器使用 `ssh -p 53781 lhtian97@frp-pen.com`，不覆盖共享 dirty BDS 工作树。
主要参照 `/home/lhtian97/Work/c06_pure_internal_20261015/bundle_r1/mp/`，
同时核验 `/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8/mp/`。
solver SHA-256：`db945eaec9042d50820ec899eb3297eea6797af7dd4e7331d905b9795243f302`。
阶段 SHA-256：`566972c99f1aef6fc1468670b79112ee63c6d4d8a9f3e714830872293527737f`。

继续使用 MATLAB R2026a、现有非交互 runner、`iseqiv(prec=0)` 与完整实际调用轨迹。
参照端显式补回 retained=false 和冻结容量，候选端不传已弃用字段；双方有效 options
分别保存。阶段比较只移除参照中断言为空的 retained 状态字段，不忽略任何剩余字段。
随机输入及 RNG 状态一致，不裁剪历史，不放宽容差。shell 记录真实退出码及超时。
失败重试使用新阶段名/快照，禁止覆盖失败现场。此轮不是论文性能 benchmark。

## 执行结果

独立工作区 `/home/lhtian97/Work/bds_retained_removal_20261020_r1` 已创建，未覆盖共享工作树。
C04/C06 的 33 个 MP 文件及 bundle manifest 哈希核验通过，复制后逐字节一致。
MATLAB R2026a preflight exit_code=0；16 组实际论文 options 审计 exit_code=0，除已移除
的两个字段外所有值一致，forcing function 也核对。原始 options MAT 保留。

候选 r1：315 文件，压缩包 SHA-256
`f8b632aa47297fad2dc62257d7a85f2558359d5d03ec31ca67cd116ead14395a`。
源码及 dirty patch 位于服务器 `evidence/bds_retained_snapshot_20261020_r1/`。

独立冻结参照取证脚本首轮在 nested workspace 调用 restoredefaultpath 失败，未执行 solver。
retry1 已运行冻结 solver，但打印不存在的 output.iterations 字段失败；retry2 改打印
实际的 funcCount 并保存完整输出。两个失败现场保留，不计入算法验证失败/通过。
冻结 MP 对函数值停机专用用例给出 `[0,1,2,3,5,7,-1]`，flag=4、x=3、f=5。
旧 lean retained-on 的 `[0,1,2,3,7,5,1,5,5,4,2]` 仍单独断言不变；不再错误要求新
production 与 retained-on 的历史求值次数一致。两者的平移不变性分别检查。

首轮 smoke exit_code=0：20 phase、3 默认及 3 旧 false 等价性、64 个开关/停机/目标
组合、旧 API 拒绝/警告检查、42 iseqiv+全轨迹、4 manifest pair 全部通过。
为减少等待，完整 manifest 的 internal/external 两组分成两个独立串行 MATLAB 会话，
各自保存全部 133 例、独立状态和日志，不使用 parallel pool、不减少用例或预算。
完整汇总必须同时检查两组，不能用其中一组代表全部通过。

首轮 regression 在旧 retained-on 函数值停机轨迹断言处失败；当时服务器仍为 r1，
本机已依据独立冻结 MP 取证修正此项预期，未改任何 solver 数值行为。
后续完整 r2 包括这项测试区分、TSFSB 历史/当前配置区分、旧 profile 标签契约测试、
manifest 分组入口及文档。r2 的 316 个文件逐项核验通过。
r2 压缩包 SHA-256：`4f452416191aba77ea985c20d8216f8da1a5aacd56ba308353d3230cdef3d470`。

`smoke_retry1` exit_code=0；`regression_retry1` 完整通过，含源单元测试、旧 API 契约、
初始步长/一般 basis/一般块数、函数值与梯度停机、profiling mappings，以及五算法
各 270 例无加速 iseqiv 和 5 个 `500*n` / `expand=2` 完整轨迹补充。
`deliberate_failure` 按预期 exit_code=1，MAT 诊断保存，无交互挂起。
外部 solver 可选执行检查的 NOMAD、NEWUOA、BFO 因隔离 path 不可用而跳过，不计入通过。
本次只读搜索 `/home/lhtian97/Work`、`/home/lhtian97/local`（深度上限 6）未找到
`bds_development/norma`，没有执行 NORMA 专属 `verify_bds.m`。

完整验证于 2026-10-20 01:04:29 UTC 启动。实际命令：

```sh
screen -dmS bds_retained_strict_20261020 bash /home/lhtian97/Work/bds_retained_removal_20261020_r1/run_verify.sh /home/lhtian97/Work/bds_retained_removal_20261020_r1 strict
screen -dmS bds_retained_manifest_internal_20261020 bash /home/lhtian97/Work/bds_retained_removal_20261020_r1/run_verify.sh /home/lhtian97/Work/bds_retained_removal_20261020_r1 manifest_internal
screen -dmS bds_retained_manifest_external_20261020 bash /home/lhtian97/Work/bds_retained_removal_20261020_r1/run_verify.sh /home/lhtian97/Work/bds_retained_removal_20261020_r1 manifest_external
```

strict 上限 6h；两组 manifest 各上限 12h。各阶段独立 MATLAB 会话、无 parallel pool。
启动后核对 screen、MATLAB、日志增长及通过计数。collector 等待全部完成后重新核对
数量、退出码、MAT 存在性、候选/冻结代码和依赖哈希，再打包证据；失败不会生成成功汇总。

strict 于 01:08:33 UTC 完成，exit_code=0。固定内部、固定外部、随机参数压力各 630
例，共 1890 个 iseqiv 和 1890 个完整轨迹检查全部通过。seeds `[12345,23456,34567]`，
维数 `1:10`，`ir=0:20`；有效候选/参照 options、输入、RNG、实际求值与全部输出逐例保存。

## 最终数值验收

外部 manifest 于 01:41:39 UTC 完成，内部于 01:46:59 UTC 完成，均 exit_code=0。
两组各 133/133，没有跳过、排除或缩小预算。长耗时 FBRAIN3LS 两组均跑到 3000 次
求值，完整轨迹一致。服务器 collector 完成所有计数/文件/哈希断言，exit_code=0；
本次 screen 会话全部退出，没有遗留验证作业。

| 检查 | 结果 |
| --- | --- |
| production phase / 冻结 MP | 20/20 |
| 默认与显式配置 / 旧 false 完整轨迹 | 各 3/3 |
| 剩余两个加速开关 × 停机 × 目标类型 | 64/64 |
| 旧 API 兼容 | true 在任何函数求值前报错；false/empty 无影响；容量警告且无影响 |
| 真实论文 options 审计 | 16/16，保留两侧原始 options |
| 严格 MP iseqiv / 完整轨迹 | 各 1890/1890，失败/跳过均 0 |
| 内部 / 外部 manifest | 各 133/133，失败/跳过均 0 |
| 无加速五算法 iseqiv | 1350/1350，每种 270 |
| 无加速纸面预算完整轨迹补充 | 5/5 |
| 维护回归、初始步长、函数值与梯度停机 | 通过，regression_retry1 exit_code=0 |
| 故意不一致非交互测试 | 按预期非零退出并保存 MAT |

33 个 MP 文件在 C04、C06 与复制的 reference 三处重新计算哈希相同；1270 个冻结
OptiProfiler/S2MPJ/manifest 文件重新核验通过。316 个服务器 candidate 文件与 r2
清单一致，四个已删除 helper 确认不存在。没有在长测试运行中修改数值代码。

### 边界、失败现场与未验证项

- 3 个早期失败状态全部保留：取证脚本 static workspace、打印不存在的 iterations 字段、
  第一轮 regression 使用了 retained-on 旧轨迹。它们的原因、修正及重试见上文。
  没有修改 frozen MP 或放宽严格数值比较来消除失败。
- NORMA 专属验证未执行；可选 NOMAD、NEWUOA、BFO 执行检查跳过，均不计入通过。
- 当前 TSFSB 维护测试审计历史配置、检查 true 被拒绝，并明确运行 MP 适配版本；
  不声称历史 retained-on benchmark 仍能在当前 production 上原样运行。
- 未重新运行论文 noisy/transformed 性能实验，不作跨 MATLAB 版本或平台逐位一致承诺。
- 未修改论文、历史 runner/结果、无加速参照、冻结 MP 或服务器共享 BDS 工作树。
- 未 commit/push。旧 retained 实现可从 Git 基线 `ece5ab04` 恢复。

结论：**移除 retained 后，本候选版本在所列配置与用例下，与关闭 retained 的已接受
实验冻结 MP 严格一致；关闭剩余加速后，与无加速参照严格一致。**

## 最终交付与源码审计

完整证据已回传并解压至
`research/retained_removal_20261020/testdata/`，按现有规则 Git ignored。
`verification_evidence.tar.gz` 的本机/服务器 SHA-256 均为：
`a4edb5293e9dad8509306885b4dd6d791d5fa3699caa95ac065286e5bc808aab`。

- `verification_summary.json`：数量、退出码、跳过项及验证边界。
- `logs/`、`results/`：所有阶段日志、故意失败/早期失败及重试、每例完整 MAT。
- `results/strict/`：1890 例完整证据；`results/manifest_internal/` 和
  `results/manifest_external/`：各 133 例。
- `reference/mp/`、`evidence/reference_hashes.json`：原字节参照及清单。
- `evidence/frozen_configuration/`：两批原始显式 options 源及 manifest。
- `evidence/bds_retained_snapshot_20261020_r1/`、`..._r2/`：完整候选包、base commit、
  dirty patch、文件清单与哈希。r1 现场保留，完整验证使用 r2。
- `final_snapshot/`、`final_audit.json`：补齐交付文档后的最终快照/哈希和本机审计。

压缩包内的 `evidence/collection.status` 是打包时的等待状态；根目录单独下载的
`collection.status` 是打包完成后的 `completed exit_code=0`，不篡改包内旧状态。

本机 `src/`、`examples/`、`tests/` 与实际测试 candidate 逐文件相同；后续仅补充本记录。
tracked diff 与新增文件均完成空白格式检查，shell runner 通过 `bash -n`。
`tests/competitors/`、历史 research 和 `inner_direct_search.m` 无 tracked diff。
最终仍在 `main`，HEAD 为 `ece5ab04d48a3110f8b4f521229102c8e6f3b108`；工作区包含本次
修改、4 个 helper 删除和新增文档/测试，暂存区为空，未 commit/push。

关键位置：`src/private/set_options.m:32` 为兼容处理；post-poll phase 的 `:106` 和
`:140` 保留 MP 两阶段原算法。四个 helper 和所有 production 方向记忆状态/容量/更新已移除。
新示例不再传两个旧字段；历史 retained 配置应使用历史 solver，不会悄悄转为其他算法。

维护 smoke/重试实际入口为：

```sh
bash /home/lhtian97/Work/bds_retained_removal_20261020_r1/run_verify.sh /home/lhtian97/Work/bds_retained_removal_20261020_r1 smoke_retry1 regression_retry1
```

已有结果不允许覆盖；重新执行时创建新工作区或新的 retry 阶段名。完整三阶段命令见上文。
