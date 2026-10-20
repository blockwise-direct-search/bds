# Retained 移除验证（2026-10-20）

执行记录：[`BDS_RETAINED_REMOVAL_EXECUTION_20261020.md`](../../docs/development/BDS_RETAINED_REMOVAL_EXECUTION_20261020.md)。

这是 production 与原字节冻结 MP（retained=false）的严格轨迹回归，不是论文性能 benchmark。
隔离服务器工作区：`/home/lhtian97/Work/bds_retained_removal_20261020_r1`。
本机 `testdata/` 保存快照、dirty patch、文件哈希、日志、逐例 MAT 与汇总，沿用 Git ignore。
结果以最终执行记录和机器可读汇总为准，不能因本 README 存在就认为全部通过。

候选端不再传 retained 字段；冻结端通过 `tests/private/frozen_mp_options.m` 显式补回
false 和历史容量。两个 options 结构分别保存在 MAT；没有改冻结 solver/private。
阶段级比较仅移除参照中已断言为空的 retained 状态，其他状态及全部求值逐项严格比较。

当前 profiling 的通用加速入口表示 MP，memory-only 旧标签明确报错。历史 research
runner 保持原样，必须用对应历史 solver 执行；维护测试会审计其原始 options，并明确
区分对当前 MP 的适配检查，不将适配后的执行冒充历史实验复现。
