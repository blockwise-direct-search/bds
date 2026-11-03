# README 两项 workflow 的服务器验证

日期：2026-11-02。测试当前未提交的双分支梯度停机版本，基线 commit 为 `67014737eaa9dbe47f7eb40e6d6829e27617277e`。本次没有修改 production、测试文件或 workflow，没有运行外部 solver 比较，没有 commit/push。

## 结果

| README 项目 | 实际入口与环境 | 断言结果 | 进程退出 |
| --- | --- | --- | --- |
| Gradient estimation | `src/private/test_gradient()`；Linux R2024b、R2025a、R2026a | 三个版本均通过 | 最终均为 0；前两个版本首次退出异常，原样重跑正常 |
| Simplified BDS verification，串行 | R2024b，`verify_simplified_bds(struct('parallel', false))` | 172 个问题 × 5 次 = 860 个对照全部通过 | 成功标记后卡在退出阶段，终止后为 143；不能记为正常退出通过 |
| Simplified BDS verification，并行 | R2024b，`verify_simplified_bds(struct('parallel', true))`，8 workers | 同样的 860 个对照全部通过 | 0 |

简化版测试保留原有 1–10 维筛选、blacklist、随机次数、500n 预算和 `prec=0`，本次默认周种子为 2645。原测试比较 x、f、exitflag、funcCount，并不比较完整历史；没有修改测试以扩大或缩减其声明。

## 环境与异常

OptiProfiler 使用 workflow 固定的 `5a19e88cc34f9b8925e111934a6b12011422fcdb`。其 setup 会克隆 S2MPJ，本次实际版本为 `352f97a792cb2727158bbff51ba38d6b0a07cc20`。

首次 MATLAB 内的 Git 下载遇到 libcurl/libssh2 符号冲突，未进入简化版计算；改由普通 shell 安装同一公开依赖后，原样运行测试。所有安装路径仅在本次 MATLAB 会话生效：隔离的 `savepath` shim 避免修改共享 pathdef/startup。没有改 setup 文件。

R2024b/R2025a 首次梯度断言均通过，但 MATLAB 退出时发生原生库异常（137）；不将这些首次运行算作正常通过，后续原样重跑均为 0。

串行简化版在 15:22:45 UTC 打印 `README_CHECK_OK 2024b simplified_sequential`，但进程直到 15:25:30 UTC 仍处于等待状态，日志未再更新。只读检查后终止了本次精确 PID 369555，退出码 143。底层退出原因未确定，不应声称本次所有进程都正常通过。

## 证据与范围

- [结构化报告](FINAL_REPORT.json)：每项真实退出码、完整计数、历史失败尝试及限制。
- `logs/`：全部运行日志，包括初次失败与重跑。
- `README_VERIFICATION_EVIDENCE.tar.gz`：临时执行计划、控制脚本、日志、阶段状态、报告及源清单，不含 MATLAB 崩溃转储。
- `SYNC_MANIFEST.json`：222 个同步文件的 SHA-256。测试前后及本地回传核对一致。
- `EVIDENCE_SHA256.txt`：证据传输哈希。

服务器隔离目录：`/home/lhtian97/Work/bds_readme_checks_20261102.Ftr9ll`。核心运行命令为 `bash control/run.sh <R2024b|R2025a|R2026a> gradient`，以及 R2024b 的 `simplified_sequential`、`simplified_parallel`；重跑通过第三参数 `_retry1` 保留独立日志。各阶段已有状态时拒绝覆盖。

这是 Linux 服务器对 workflow 测试入口的验证，不是实际 GitHub Actions 全平台结果；没有验证 Windows/macOS 或本机未安装的 R2023b/R2024a。梯度估计测试也不等于最终梯度停机判据的回归测试，后者见前一次生产移植记录。
