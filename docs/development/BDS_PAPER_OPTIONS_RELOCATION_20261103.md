# 论文配置入口迁移到 tests

日期：2026-11-03。

## 范围与不变量

用户授权将 `examples/bds_paper_options.m` 移至 `tests/bds_paper_options.m`，并同步必要的论文仓库引用。只改变组织位置和说明，不改变配置字段、值、函数名或接口，不改 solver，不提交或推送。

基线为 main 的 `67014737eaa9dbe47f7eb40e6d6829e27617277e` 加已有未提交改动。特别保留该函数已有的梯度停机版本说明。迁移前文件 SHA-256 为 `2eeecdf77f1fa96e80e0d351db6003f9be6029acbe6298829019de91b95185d4`，迁移后应逐字节相同。

论文仓库已有用户改动包括 `pending_thesis_experiments.md`，以及未跟踪的 C09/C10/C11 目录和 V305–V307 记录，均保留。已完整阅读论文 AGENTS.md 和 reproducibility/README.md。本次只同步技术路径说明，不进行数学写作、正文修改或编译。

## Checklist

- [x] 查明活动调用、文档链接和论文仓库冻结实验依赖。
- [x] 原样迁移函数；更新活动文档及普通示例中的论文提示。
- [x] 论文复现说明补充新位置，明确 C09/C10/C11 冻结包保留原 examples 路径；不改实验脚本、数据、provenance 或 bds.tex。
- [x] 核对迁移前后文件哈希；检查活动入口能够从 tests 解析函数。
- [x] 在隔离服务器快照验证四种配置、迁移前后 options 与完整 solver 输出一致，并运行维护中的 regression suite。
- [x] 回传日志，核对两个仓库 diff；记录结果和限制。

## 调用审计

维护中的 tests 调用方、`tests/tools/run_bds_mp_verification.m` 和前一轮生产验证 runner 已包含 tests 路径，因此无需更改配置调用。冻结研究 runner 指向自己的 candidate/examples，不能替换成当前 production 路径。

论文 C09 的说明和 setup 指向冻结 commit 的 bundle/examples；C10/C11 复制该 bundle。这些是历史版本的真实位置，必须保持。bds.tex 没有本次函数路径引用。

## 验证结果

服务器隔离目录为 `/home/lhtian97/Work/bds_options_relocation_20261103.2O86pi`，使用默认 `matlab -singleCompThread -batch`（R2026a）。未改共享 checkout 或旧验证目录。

- 文件 SHA-256 与迁移前完全相同；旧 examples 文件不存在，普通 examples 不再引用该 helper。活动 Markdown 链接目标检查通过。
- `smoke` 于 2026-11-03 02:35:59 UTC 正常退出（0）：internal mp/noacc/ds、external mp，各测试 1/3/7 维，共 12 组 options 与完整 solver 输出精确一致；forcing function 比较表达式，其余字段比较 `isequaln`；额外检查非法 external/noacc 配置仍正确拒绝。显式断言 MATLAB 从 tests 解析函数。
- `regression` 于 02:36:46 UTC 正常退出（0）：完整 `run_bds_regression_suite` 通过，包括 1350 个关闭梯度停机的无加速参照等价案例、120 个梯度判据边界案例及其他维护中的测试。没有重跑独立冻结 MP 全矩阵；迁移函数字节不变，四种配置的前后完整输出比较均通过。
- 两阶段均正常退出，本轮没有遇到 MATLAB 退出异常。测试配置与算法均未修改以取得通过。
- 本地证据位于 `research/paper_options_relocation_20261103/`，包含日志、状态、执行脚本、同步清单与最终审计报告。224 个同步文件在服务器及本地逐项核对 SHA-256；最终记录文字更新后重新同步清单。
- 两个仓库 `git diff --check` 通过。BDS 的原有 dirty state 保留；论文只新增本次记录并更新 reproducibility/README.md，原有用户修改保留，未改 bds.tex 或实验脚本。

复现命令（新目录，避免覆盖本次结果）：`bash control/run.sh smoke` 和 `bash control/run.sh regression`。执行脚本记录了本次固定服务器路径；换环境须先定位对应的迁移前快照。

由于仅迁移文件，不重跑完整性能 benchmark 或上一轮耗时的 Simplified BDS 全集；本次回归不作为新的性能结论。没有编译论文、提交或推送代码。
