# 仅修改最终梯度停机判据的隔离实验

[计划与执行记录](PLAN.md) 是本轮范围与验收依据。正式 `src/bds.m` 不修改；不重启已否决的连续失败参考值机制。

**结果图入口：[6–50 维旧版/新版对比图及中文说明](plots/README.md)。**
正式计算已于北京时间 2026-10-31 12:23:59 完成；2026-11-02 的图仅从已有数据导出，没有重跑 solver。
绘图范围与校验见 [PLOT_PLAN.md](PLOT_PLAN.md)。

服务器目录：`/home/lhtian97/Work/bds_gradient_threshold_20261030`。
screen 名称：`bds_gradient_threshold_20261030`。

## 固定比较

| 标签 | 实际 solver | 函数值停机 | 梯度停机 |
|---|---|---|---|
| B | 原 bds | 关 | 关 |
| F | 原 bds | 开 | 关 |
| G_old | 原 bds | 关 | 开，原 max 判据 |
| G_new | bds_dual_threshold | 关 | 开，新双分支判据 |
| FG_old | 原 bds | 开 | 开，原 max 判据 |
| FG_new | bds_dual_threshold | 开 | 开，新双分支判据 |

各次实际运行均重新创建同种子 FeaturedProblem，重置 solver RNG。
保留默认参考值初始化和所有显式论文 external 参数，仅切换以上两个停机开关及 solver 入口。
实验入口由 prepare.py 从原文件机械生成，同目录共享 private；审计拒绝函数名与最后判据之外的源码差异。

## 文件与输出

- `prepare.py`：生成及审计隔离入口，当前冻结清单校验 262 个文件和 1348 个既有冻结依赖。共享依赖只读。
- `threshold_unit_test.m`：执行实际源代码中的判据表达式，以及真实 solver 的边界、窗口、参考初始化和关闭梯度停机等价检查。测试夹具的特殊参数不用于正式实验。
- `threshold_experiment.m`：24 例六特征预检；两个固定种子分别 3458 例、每例六次真实 solver 调用；不调参。
- `run.sh`：unit → regression → smoke → strict → preflight → seed1 → seed2 → report。任一步实现检查失败即停止，screen 无总时限。
- 服务器 `run.status` 和各阶段 `.status` 表示真实运行状态；`logs/` 保存日志。
- 每例落盘的 MAT 只保存基线真实函数值历史、参数和六个紧凑结果。评价点完整轨迹在内存中用于逐次前缀验证，不在每个配置重复落盘。
- 各种子目录的 `SUMMARY.json` 保存总计和六特征统计，`CASE_ASSESSMENTS.json` 保存逐实例/逐精度的历史与返回点成功掩码，以便核对失败集合。
- 顶层 `SUMMARY.json` 只有两个正式种子都完成后才生成。状态 completed 不等于机制合格。

报告中的 losses_vs_both_off 维度依次为配置（按表格顺序）、精度（1e-2/1e-3/1e-4）、口径（history/output）。同一实例可能在多档精度及两种口径出现，不能把所有计数相加当作独立失败问题数。

本轮目标只来自相应种子的双关 BDS，不是原多 solver 的论文 profile 目标。不会修改旧性能结论，也不会把预检当成完整实验结果。

## 只读检查进度

```bash
ssh -p 53781 lhtian97@frp-pen.com \
  'cat /home/lhtian97/Work/bds_gradient_threshold_20261030/run.status; ls -lt /home/lhtian97/Work/bds_gradient_threshold_20261030/logs'
```

不要在运行中修改服务器 control、candidate 或冻结清单。若出现失败，先读对应日志并保留原证据，不能跳过门禁直接运行 seed1/seed2。
