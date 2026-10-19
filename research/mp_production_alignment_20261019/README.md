# Production MP 对齐验证（2026-10-19）

这不是性能 benchmark；它验证新的 production `bds` 与已接受实验的冻结 MP
在相同 MATLAB 环境、显式 options 和随机 realization 下严格一致。

主执行记录：[`docs/development/BDS_MP_ALIGNMENT_EXECUTION_20261019.md`](../../docs/development/BDS_MP_ALIGNMENT_EXECUTION_20261019.md)。
软件复现入口：[`examples/bds_paper_options.m`](../../examples/bds_paper_options.m)。

服务器独立工作区：`/home/lhtian97/Work/bds_mp_verify_20261019_r1`。
本机证据下载位置为本目录的 `testdata/`，按现有 `.gitignore` 规则不进入 Git。
其中保存日志、MAT、机器可读汇总、候选代码快照/dirty patch/哈希清单及冻结参照清单。
没有测试结果时，不应仅因本说明文件存在而声称验证已通过。

## 验证入口

- `src/verify_bds_mp_phase.m`：实际 production private phase 的分支与冻结桥接比较。
- `tests/verify_bds_mp_defaults.m`：默认/显式配置、retained、开关组合和噪声/无效值。
- `tests/verify_bds_mp_reference.m`：固定内部、固定外部、随机参数压力三个独立 suite；
  每个 suite 用 seeds `[12345,23456,34567]`、维数 `1:10`、`ir=0:20`，共 630 例。
  每例同时运行 `iseqiv(prec=0)` 和完整真实 objective trace / 全 output 的 `isequaln`。
- `tests/verify_bds_mp_manifest.m`：冻结 manifest 全部 133 问题的 plain 内部/外部配置，
  `500*n` 预算，没有排除列表。
- `tests/run_bds_regression_suite.m`：保留五种算法的无加速参照验证及梯度停机等回归。

每个 MATLAB 会话恢复默认 path 并断言 production、reference 和 loader 的实际路径。
完整测试通过 `screen` 启动，shell 保存 started/completed/failed/timeout 及真实退出码。
`deliberate_failure` 必须以非零退出并产生诊断 MAT，属于失败处理机制的通过证明，
不是一次算法等价性失败。

## 证据解读

以最终执行记录和 `testdata/verification_summary.json` 为验收结论，不能只看日志中的
单个 passed 字样。第一轮 manifest adapter 错误的日志和候选快照保留，重试不覆盖。
旧 PM 全开验证位于 `tests/archive/legacy_pm/`；它只适用于历史 PM 源码，不是 MP oracle。
冻结 MP 与无加速 reference 均没有为了通过比较而修改。
