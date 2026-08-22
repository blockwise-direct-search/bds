# Evolved BDS 快速消融的代表问题选择标准

## 1. 目的

本文档说明：在比较 BDS 与 Evolved BDS 的全量 S2MPJ 实验之后，如何从
122 个问题中选出 15 个代表问题，用于低成本、快速的策略消融。

这项工作的目标不是用 15 个问题代替完整测试集，也不是生成正式的总体
performance profile，而是快速回答一个机制问题：

> Evolved BDS 相对 BDS 的优势主要来自哪些新增策略，哪些策略贡献不稳定，
> 甚至可能拖累算法？

因此，这 15 个问题构成的是一个 `mechanism-diagnostic probe set`，而不是一个
独立、无偏的 benchmark。

## 2. 全量结果来源

筛选依据来自以下全量实验：

- 问题库：S2MPJ；
- 维数范围：6--50；
- 问题数：122；
- feature：`plain`；
- 比较对象：BDS 与 full Evolved BDS；
- 统一分析预算：每个问题前 `200n` 次 objective evaluations。

原始实验目录为：

```text
/Users/lihaitian/Downloads/
    BDS_Evolved_BDS_u_6_50_plain_s2mpj_20260623_100711
```

筛选时主要读取 `test_log/data_for_loading.h5` 中的逐次函数评价历史
`fun_histories`。因此，依据是所有问题的 history 数值，而不是人工逐张查看
122 张 history plot。History plot 与这些数值表达的是同一批轨迹，但实际筛选
直接在数值数据上完成。

## 3. 为什么只分析前 `200n` 次评价

原始 full Evolved BDS 内部使用的预算曾与 OptiProfiler 的外部预算不一致，并在
全量实验中触发 abnormal termination。因此，这一轮调查不使用 solver 的最终
返回点判断优劣，而是把两条轨迹都截断到统一的前 `200n` 次评价，只比较
history 中实际评价过的点。

对 solver `s` 和问题 `p`，定义截至第 `k` 次评价的历史最优值：

```text
best_{p,s}(k) = min_{1 <= j <= k} f_{p,s}(j).
```

后续所有全量筛查以及 15 问题上的快速消融都使用这一 `best-so-far` 口径。

## 4. 第一层筛查：优势出现在哪个预算阶段

首先在每个问题的以下预算节点比较 BDS 与 Evolved BDS 的 `best-so-far`：

```text
5%, 10%, 25%, 50%, 75%, 100% of 200n.
```

全量统计为：

| 已用预算 | BDS 更好 | Evolved BDS 更好 | 持平 |
| ---: | ---: | ---: | ---: |
| 5% | 59 | 47 | 16 |
| 10% | 62 | 35 | 25 |
| 25% | 60 | 39 | 23 |
| 50% | 46 | 53 | 23 |
| 75% | 42 | 57 | 23 |
| 100% | 36 | 63 | 23 |

这个结果揭示了主要现象：Evolved BDS 并非普遍在初期更快，而是经常在中后期
追上或反超 BDS。在最终由 Evolved BDS 获胜的 63 个问题中：

- 26 个在 25% 预算时尚未领先；
- 13 个在 50% 预算时尚未领先。

因此，代表集需要覆盖 `late-takeover` 问题。这类问题最适合判断 pattern、
momentum、memory 和 extension 等 exploitation 机制是否真正发挥作用，而不是
只验证早期 polling 顺序。

## 5. 第二层筛查：严格精度下的覆盖差异

对每个问题，用两条 history 的共同最优值构造相对目标：

```text
f_target(tau) = f_min + tau * (f_init - f_min),

f_min = min(best_BDS(200n), best_Evolved(200n)).
```

调查了 `tau = 1e-3, 1e-8, 1e-10`，并识别：

- `Evolved-only`：Evolved BDS 在 `200n` 内达到目标，而 BDS 未达到；
- `BDS-only`：BDS 达到目标，而 Evolved BDS 未达到；
- 两者均达到时，谁更早达到目标。

在 `tau = 1e-3` 时，Evolved-only 已有 17 个问题，而 BDS-only 只有 3 个。
在更严格的 `1e-8` 和 `1e-10` 下，Evolved-only 分别增至 43 和 45 个。
这进一步表明，代表问题应重点覆盖严格精度下 Evolved BDS 独有或明显更强的
收敛行为。

这里的 tolerance 筛查用于识别候选问题，而快速消融本身仍直接比较固定
`200n` 预算下的最终 `best-so-far`，不是只对某一个 tolerance 打分。

## 6. 第三层筛查：维数和问题族覆盖

只选最终差距最大的若干问题容易把代表集限制在单一维数或单一问题族。因此，
筛选时还查看了以下分组：

- `n <= 10`：低维策略（尤其当时的 diagonal probing）可能生效；
- `n > 10`：diagonal probing 不生效，可用于判断高维优势是否来自其他机制；
- `n >= 20`：检查高维上的优势；
- 问题族关键词，例如 `CURLY`、`FLET`、`PALMER`、`LANCZOS`、`HEART`、
  `GENROSE`、`TRIGON`、`NCB` 和 `BROY`。

全量 history 的最终胜负包括：

| 分组 | 问题数 | BDS 更好 | Evolved BDS 更好 | 持平 |
| --- | ---: | ---: | ---: | ---: |
| `n <= 10` | 81 | 31 | 44 | 6 |
| `n > 10` | 41 | 5 | 19 | 17 |
| `n >= 20` | 16 | 2 | 13 | 1 |

这一步不是给问题建立严格的结构分类，而是避免快速 probe 只反映低维特化策略，
同时保留能区分不同机制的典型问题。

## 7. 最终 15 个问题

### 7.1 Evolved-favored examples

选择了 11 个在全量 history 中能清楚暴露 Evolved BDS 优势的例子：

```text
BIGGS6
EIGENBLS
GENROSE
HEART6LS
FLETCHBV
FLETCBV3
MOREBV
TRIGON2
BROYDNBDLS
CURLY10
THURBERLS
```

这些问题共同覆盖了：

- 严格 tolerance 下的 Evolved-only 或明显更强行为；
- 前期不领先、后期反超的轨迹；
- `n <= 10` 与 `n > 10`；
- 多种非线性、耦合或非坐标友好问题族。

这里没有使用一个固定公式自动选出 top 11。候选由全量数值筛查产生，最终名单
再依据维数、问题族和轨迹形态人工去重、组合。因此它们是诊断性 examples，
不能解释为随机样本或全量测试集的统计缩影。

### 7.2 BDS-favored controls

另外加入 4 个 BDS 更有优势的问题作为负面对照：

```text
PALMER1C
PALMER2C
LANCZOS1LS
INDEF
```

这些 controls 用来检查：

- 某策略是否只在有利问题上产生收益；
- 去掉某策略后，BDS-favored 问题是否反而改善；
- 新增的 exploitation 是否可能过度、浪费预算或产生搜索偏置。

如果只使用 11 个 Evolved-favored 问题，实验可以判断“优势由什么产生”，却无法
判断同一策略是否也在其他问题上拉后腿。4 个 controls 因而是代表集不可缺少的
组成部分。

## 8. 快速消融配置

在每个代表问题上，用完全相同的初始点和固定 `200n` 预算比较 9 个变体：

| 变体 | 含义 |
| --- | --- |
| `BDS` | 原始 BDS baseline |
| `Full` | 所有 Evolved 策略启用 |
| `NoSignOrder` | 去掉 sign preference 和 adaptive coordinate ordering |
| `NoMemory` | 去掉 productive direction memory 及其 reuse/extrapolation |
| `NoCoordExt` | 去掉 per-coordinate immediate extension |
| `NoSweepPat` | 去掉 sweep-level pattern 和 momentum 分支 |
| `NoDiagonal` | 去掉 stagnation-triggered diagonal probing |
| `NoRecovery` | 去掉 step-size recovery |
| `NoExploit` | 同时去掉 memory、coordinate extension、sweep pattern 和 diagonal probing |

对某个变体 `v`，以它相对 Full 的归一化差值衡量去掉策略后的影响：

```text
gap_v = (best_v(200n) - best_Full(200n))
        / max(1, |f_init|, |best_v(200n)|, |best_Full(200n)|).
```

历史脚本使用以下判据计数：

```text
gap_v >  1e-8  -> 去掉该策略后变差
gap_v < -1e-8  -> 去掉该策略后反而更好
otherwise      -> 基本持平
```

除了最终 `best-so-far`，临时脚本还记录每次新 best 来自哪个模块，例如
`coord_poll`、`memory`、`memory_extrap`、`coord_extension`、`sweep_pattern`、
`momentum_pattern` 或 `diagonal`。该记录用于解释机制联动，不作为问题筛选的硬条件。

## 9. 这套选择标准可以支持什么结论

这套快速消融适合支持以下探索性结论：

- 哪些策略在 Evolved-favored examples 上最经常不可缺少；
- 某项收益主要出现在低维、高维还是 late-stage；
- 某些策略是否在 BDS-favored controls 上产生负作用；
- 哪些模块需要进入下一轮更正式的 OptiProfiler 消融。

它不适合单独支持以下结论：

- 某策略在整个 S2MPJ 测试集上的无偏平均贡献；
- 某策略对所有问题都有稳定正效应；
- 15 个问题上的分数可以替代全量 performance profile；
- 根据同一份数据选择问题并验证策略后得到的结果具有独立确认性质。

## 10. 局限性与正确表述

这次选择是 `post-hoc exploratory selection`：先观察 full BDS/Evolved BDS 的全量
history，再挑选能区分机制的问题。因此存在有意的选择偏差。这个偏差对于快速
诊断并非错误，因为实验目的就是放大机制信号；但在写论文或作正式总体声明时，
必须明确其范围。

准确的表述是：

> We first screened the per-problem best-so-far histories from the full
> benchmark, then formed a small mechanism-diagnostic set containing
> Evolved-favored examples and BDS-favored controls. The set was used for
> rapid exploratory ablation, not as a replacement for full-benchmark
> validation.

更强的正式证据应当在策略确定后，再回到未筛选的完整测试集，或使用预先注册的
独立验证集，比较 Full 与各项 leave-one-out 变体的 OptiProfiler profiles。后续对
diagonal probing 和 productive direction memory 的进一步实验，正是在补强第一轮
快速 probe 的证据链。

## 11. 一句话总结

15 个代表问题不是由人工浏览所有 history plot 后凭印象选出，也不是由单一
top-15 排名自动生成。实际做法是：先对 122 个问题的 `fun_histories` 进行统一
`200n` 截断和 `best-so-far` 数值筛查，再综合 late takeover、严格 tolerance 覆盖、
维数、问题族和正负对照，人工组成 `11 个 Evolved-favored examples + 4 个
BDS-favored controls`，用于快速机制消融。
