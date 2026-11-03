# 连续 polling 失败参考值实验

**已于 2026-10-30 按用户要求终止。** 新机制未通过无精度损失验收，不再运行这些脚本。
服务器完整数据及本地 testdata 已永久清理；保留本目录历史实现供查阅。
最终结果、未完成项及清理记录见 [两轮探索归档](../gradient_stop_trials_20261030/README.md)。

计划见 `docs/development/BDS_POLL_FAILURE_REFERENCE_EXPERIMENT_20261030.md`。
控制代码只生成独立实验 solver，不改变 production。

事件列依次为 iteration、nf、函数值停机命中、梯度范数、e(1)、同点梯度差异、
返回点求值序号、原 e(1000)、polling 失败标志、连续失败计数。
回放从明确的 polling 失败标志独立重建计数，不用有无梯度记录猜测成功。

750 个新机制配置及两个对照，先比较只变 K 的五组。
开发种子 20260828，新验证种子 20261030。后者只验证事先固定的候选和对照，不调参。
目标仅由对应种子组的双关基线确定，不等同于原论文的多 solver 评价目标。
无合格候选时仍真实复跑失败诊断候选，并明确标记不合格。

`prepare_experiment.py` 生成副本，`freeze_controls.py` 冻结完整清单，
`run_verification.sh` 运行已有验证和新机制预检，`run_experiment.sh` 执行正式流水线。
两个 shell 脚本均无时间上限，遇错误停止并保存证据，不无限重试。
需要 results 下全部 production 验证通过，以及预检、流程测试、关闭梯度停机等价性
三个 ACCEPTED 标记，才能正式启动。

`run_after_verification.sh` 可在 screen 中等待已启动的验证工作，全部正常结束后再执行
启动审计和正式流水线。等待没有时间上限，失败状态立即停止；不会因为测试尚未结束就
绕过门禁。`launcher.status` 表示等待/启动，`compute.status` 才表示正式流水线状态。
`test_launch_gate.py` 用临时夹具检查此状态门禁，不启动 MATLAB。
