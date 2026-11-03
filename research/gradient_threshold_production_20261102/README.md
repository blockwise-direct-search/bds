# 最终梯度停机判据的生产移植验证

本目录验证 production 与已完成实验的 `bds_dual_threshold.m` 精确一致，不运行新的性能 benchmark。

实施范围、命令、异常及完整结果见 [执行记录](../../docs/development/BDS_DUAL_GRADIENT_STOP_IMPLEMENTATION_20261102.md)。

- `run_production_verification.m`：MATLAB 隔离入口，调用正式测试。
- `run.sh`：逐阶段执行并记录真实进程退出码，拒绝覆盖已有阶段。
- `audit.py`：只读审计生产代码与冻结实验、同步文件清单。
- `collect_evidence.py`：要求最终门禁通过后汇总证据，保留失败尝试和运行环境警告。
- `evidence/`：从服务器回传的最终报告、SHA-256 清单和压缩日志证据。完整逐案例轨迹留在服务器。

脚本记录了本次服务器的固定路径和依赖。迁移环境时必须重新定位并核验冻结候选和依赖，不能用当前 defaults 替换历史设置。
