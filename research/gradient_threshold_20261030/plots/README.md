# 6–50 维：旧版与新梯度停机判据对比图

## 先看什么

下表每行是论文关注的一种特征。先看 **history 的 1e-2、1e-4 两列**，再看 output 图与总求值数。
所有 PDF 均为冻结 OptiProfiler 直接导出，未裁剪、重绘或修改。

- **BDS-old（蓝色实线）**：FG_old，函数值停机开启，原梯度停机开启。
- **BDS-new（橙色虚线）**：FG_new，函数值停机开启，新双分支梯度停机开启。
- 两版保留同一首次可靠梯度参考机制，只改变最终梯度停机条件。本次没有改变正式 solver。
- S2MPJ，133 个 6–50 维无约束问题，预算 500n；plain 每问题运行一次，其余特征五次。
- 两个种子各 3458 个 problem/feature/repeat 实例，分开出图，没有挑选种子或混合平均。

### 第一组：seed_base = 20260828

| 特征（点击名称看 history 四档精度汇总） | history 1e-2 | history 1e-4 | output 四档精度 |
|---|---|---|---|
| [plain](seed1/plain/history_all_tolerances.pdf) | [图](seed1/plain/history_tau_1e-2.pdf) | [图](seed1/plain/history_tau_1e-4.pdf) | [图](seed1/plain/output_all_tolerances.pdf) |
| [noisy 1e-4](seed1/noisy_1e-4/history_all_tolerances.pdf) | [图](seed1/noisy_1e-4/history_tau_1e-2.pdf) | [图](seed1/noisy_1e-4/history_tau_1e-4.pdf) | [图](seed1/noisy_1e-4/output_all_tolerances.pdf) |
| [noisy 1e-2](seed1/noisy_1e-2/history_all_tolerances.pdf) | [图](seed1/noisy_1e-2/history_tau_1e-2.pdf) | [图](seed1/noisy_1e-2/history_tau_1e-4.pdf) | [图](seed1/noisy_1e-2/output_all_tolerances.pdf) |
| [linearly transformed](seed1/linearly_transformed/history_all_tolerances.pdf) | [图](seed1/linearly_transformed/history_tau_1e-2.pdf) | [图](seed1/linearly_transformed/history_tau_1e-4.pdf) | [图](seed1/linearly_transformed/output_all_tolerances.pdf) |
| [transformed + noisy 1e-4](seed1/linearly_transformed_noisy_1e-4/history_all_tolerances.pdf) | [图](seed1/linearly_transformed_noisy_1e-4/history_tau_1e-2.pdf) | [图](seed1/linearly_transformed_noisy_1e-4/history_tau_1e-4.pdf) | [图](seed1/linearly_transformed_noisy_1e-4/output_all_tolerances.pdf) |
| [transformed + noisy 1e-2](seed1/linearly_transformed_noisy_1e-2/history_all_tolerances.pdf) | [图](seed1/linearly_transformed_noisy_1e-2/history_tau_1e-2.pdf) | [图](seed1/linearly_transformed_noisy_1e-2/history_tau_1e-4.pdf) | [图](seed1/linearly_transformed_noisy_1e-2/output_all_tolerances.pdf) |

### 第二组：seed_base = 20261030

| 特征（点击名称看 history 四档精度汇总） | history 1e-2 | history 1e-4 | output 四档精度 |
|---|---|---|---|
| [plain](seed2/plain/history_all_tolerances.pdf) | [图](seed2/plain/history_tau_1e-2.pdf) | [图](seed2/plain/history_tau_1e-4.pdf) | [图](seed2/plain/output_all_tolerances.pdf) |
| [noisy 1e-4](seed2/noisy_1e-4/history_all_tolerances.pdf) | [图](seed2/noisy_1e-4/history_tau_1e-2.pdf) | [图](seed2/noisy_1e-4/history_tau_1e-4.pdf) | [图](seed2/noisy_1e-4/output_all_tolerances.pdf) |
| [noisy 1e-2](seed2/noisy_1e-2/history_all_tolerances.pdf) | [图](seed2/noisy_1e-2/history_tau_1e-2.pdf) | [图](seed2/noisy_1e-2/history_tau_1e-4.pdf) | [图](seed2/noisy_1e-2/output_all_tolerances.pdf) |
| [linearly transformed](seed2/linearly_transformed/history_all_tolerances.pdf) | [图](seed2/linearly_transformed/history_tau_1e-2.pdf) | [图](seed2/linearly_transformed/history_tau_1e-4.pdf) | [图](seed2/linearly_transformed/output_all_tolerances.pdf) |
| [transformed + noisy 1e-4](seed2/linearly_transformed_noisy_1e-4/history_all_tolerances.pdf) | [图](seed2/linearly_transformed_noisy_1e-4/history_tau_1e-2.pdf) | [图](seed2/linearly_transformed_noisy_1e-4/history_tau_1e-4.pdf) | [图](seed2/linearly_transformed_noisy_1e-4/output_all_tolerances.pdf) |
| [transformed + noisy 1e-2](seed2/linearly_transformed_noisy_1e-2/history_all_tolerances.pdf) | [图](seed2/linearly_transformed_noisy_1e-2/history_tau_1e-2.pdf) | [图](seed2/linearly_transformed_noisy_1e-2/history_tau_1e-4.pdf) | [图](seed2/linearly_transformed_noisy_1e-2/output_all_tolerances.pdf) |

汇总 PDF 共四页，依次为 1e-1、1e-2、1e-3、1e-4；单图已单独提取为原生导出的对应文件，不是裁剪汇总 PDF。

## 这批图实际显示了什么

- **1e-2：**两个种子的全部六种特征，history 均值曲线完全一致。
- **1e-4：**两个种子的 plain，新版均比旧版多覆盖 1/133 的问题（约 0.752 个百分点）；第二种子的 linearly transformed 多覆盖 1/(133×5)（均值约 0.150 个百分点）。其余 history 曲线一致。
- **output 并非全部一致：**新版往往需要更大的性能比才能达到相同覆盖率，反映晚停的求值代价。不能把 history 的一致性推广成所有指标一致。

上述结论由原生曲线数值逐项比较得到，见 [NATIVE_CURVE_SUMMARY.json](NATIVE_CURVE_SUMMARY.json)，不是只靠肉眼判断。每组同时提供 PNG 预览，文件名与单图对应；`output_tau_1e-4.png` 是 output 汇总第四页的渲染。

## 总函数求值成本

下表来自已完成的真实运行汇总，不是从图中估算。成本包括达标之后到实际停机之间的求值。

| seed_base | 旧版 FG_old | 新版 FG_new | 新版比旧版增加 | 新版相比停机双关节省 |
|---|---:|---:|---:|---:|
| 20260828 | 6,990,321 | 7,085,225 | 94,904（1.36%） | 16.62% |
| 20261030 | 6,873,348 | 6,972,453 | 99,105（1.44%） | 16.88% |

证据：[原实验数值摘要](evidence/EXPERIMENT_SUMMARY.json)。该摘要的成功判断使用原实验 B 基线目标，与本次两 solver 图的目标定义不同，不应逐项混用计数。

## 如何解读，不能据此声称什么

1. **history-based** 用首次达到精度目标所需的求值数。两版在较短运行结束之前轨迹一致，因此在共同达到同一目标时首次达标成本相同，曲线可能完全重合。横轴只有 `1` 的图表示所有有限性能比均为 1，是原生图的退化坐标范围，不是遗漏刻度。
2. **output-based** 用最终返回点的真实函数值判定是否成功，成功时成本为实际总求值数；有噪声时不使用带噪声的 solver fopt。它能显示新版继续运行的代价，但衡量的不是 history 的首次达标成本。
3. 本次原生目标由每个问题、每次重复下 FG_old 与 FG_new 的真实历史及初始值共同确定。每张图独立计算，不使用其他 solver，也不把旧摘要的目标直接搬过来。
4. 因而这些图是**新旧版本的成对诊断图**，不是论文已有多 solver 图的重绘；不能据此声称与外部 solver 的排名不变，也不能把相似曲线当成完整论文复现。
5. 原实验摘要仍标记 `gradient_qualified=true`、`joint_qualified=false`。后者包含原函数值停机已有的相对双关损失；新联合配置没有在函数值单独停机或旧联合配置之上新增损失。绘图不修改这些判断，也不自动授权正式代码上线。

## 来源与检查

- 实验完成于北京时间 2026-10-31 12:23:59；导图日期 2026-11-02，未新增 solver 求值。
- 原始数据：服务器 `/home/lhtian97/Work/bds_gradient_threshold_20261030`。
- 独立后处理：服务器 `/home/lhtian97/Work/bds_gradient_threshold_plots_20261102`。
- 原生 OptiProfiler：冻结的 C04 `bundle_r8/optiprofiler/matlab/optiprofiler`，与本次实验依赖一致。
- 每组 `SOURCES.json` 记录原始 case 文件哈希；`VERIFIED.json` 记录计数、原生数据精确一致、四档曲线独立校验和 PDF 哈希；`curves.mat` 保存原生曲线。
- 所有图只从已保存并在实验时逐次验证过的真实轨迹前缀恢复；没有重新调用目标函数来补齐历史。
- [执行记录](../PLOT_PLAN.md)；[绘图脚本](../plot_threshold_results.m)；[下载检查](../check_plot_download.py)。
- 本地检查通过：48 个 PDF、120 页；125 个传输文件哈希全部一致；6916 个来源 case 的总求值数与原实验汇总一致。PDF 流程完成渲染抽查和全页文本检查。
