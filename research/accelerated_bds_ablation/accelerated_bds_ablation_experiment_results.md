# Accelerated BDS Ablation Experiment Results

## Scope

这个文件记录 `accelerated_bds_ablation_experiment_plan.md` 中 Group A-D 的实验结论。
Group A-C 用于拆分 acceleration strategies，Group D 用于衡量 original CBDS baseline
与 NOMAD 在 `200n` 和 `500n` budgets 下的差距。

## Three Questions, Direct Answers

### 1. Which acceleration strategy is the most important?

**Answer: `momentum extrapolation` has the strongest standalone numerical evidence, with
`pattern direction` a close second. More fundamentally, the key object is the aggregate
iteration direction used by both strategies.**

在 Group A 中，`momentum-only` 在 plain 和 linearly_transformed 上都得到 1.0000，
相应 baseline scores 分别只有 0.6290 和 0.5680。这个优势略强于 `pattern-only`；后者
对应的 baseline scores 是 0.6535 和 0.6429。因此，如果必须选出一个最关键的策略，
当前证据指向 momentum，尤其是在 linear transformation 下。不过，从几何机制上应把
pattern 和 momentum 联系起来理解：pattern 沿当前 iteration 的 total accepted step
外推，momentum 则在 iterations 之间平均这些 successful iteration directions。

### 2. Are all three acceleration strategies indispensable?

**Answer: no. `pattern direction + momentum extrapolation` form the minimal effective core;
`productive direction memory / acceleration search step` is helpful in the all-on solver but is
not indispensable.**

Group A 表明 `memory-only` 在两个 features 上都不如 baseline。Group B 则表明
`pattern-momentum` 已经明显优于 baseline，而 `all-on` 又进一步优于
`pattern-momentum`。因此，memory 不应被表述为 core standalone acceleration
mechanism；它是一个 optional additional search step，与 pattern 和 momentum 结合时
具有 measurable marginal benefit。删掉它可以得到更简单但仍然很强的 solver；保留它
则可以得到这些实验中 best observed performance。

### 3. Do the acceleration strategies also help classical DS?

**Answer: not reliably. They improve DS on plain problems but degrade it after linear
transformation, so the experiments do not support a generic DS acceleration claim.**

这个现象可以从 classical DS 与 CBDS 产生不同 iteration step 的角度解释。当
`Algorithm = 'ds'` 时，实现中只有一个 block。Opportunistic polling 接受第一个满足
sufficient decrease 的 trial direction；complete polling 虽然可能计算全部方向，但最终
仍至多接受一个 best trial point。因此，regular polling 后，iteration $k$ 的 accepted
step 要么为零，要么为

\[
s_k = \alpha_k d_{j_k}.
\]

所以，DS 的 pattern direction $s_k / \lVert s_k \rVert$ 就是刚刚成功的 polling
direction。沿该方向测试 factors `[1, 2, 4]` 并没有构造新的 directional geometry；它是
沿 last successful direction 的 finite directional extrapolation。Memory search step 的
作用相似：重新尝试过去成功的 polling directions，并且只测试有限个更远的点。因此，
二者主要属于 `line-search-like exploitation`；但它们都不是真正的 line search，因为
算法没有求解 one-dimensional subproblem。

Momentum 需要单独说明。它可以组合来自不同 iterations 的 successful DS directions：

\[
m_k = \beta m_{k-1} + (1-\beta)\frac{s_k}{\lVert s_k\rVert},
\]

所以它仍可能生成 polling set 之外的新方向。但是，这些信息来自不同 base points 和不同
iterations，而不是同一个 iteration 内相互协调的进展。在当前实现中，momentum 还是一个
fallback：只有 pattern probe 被关闭或失败时才尝试它。Group C 表明，这种可能的
directional enrichment 并不足以让 DS 在 linearly transformed problems 上获得 robust
gains。

Sequential CBDS 则不同：一个 iteration 可以在多个 blocks 中接受更新，其 total accepted
step 为

\[
s_k = \sum_{i\in\mathcal{S}_k} \alpha_{k,i} d_{k,i},
\]

它通常是一个不属于 polling direction set 的 new oblique direction。因此，pattern
extrapolation 使用的是同一个 iteration 内多个 successful block updates 合成的新方向；
momentum 再跨 iterations 平均这些已经聚合的方向。在 CBDS 中，这些策略同时提供
exploitation 和 `directional enrichment`；在 DS 中，pattern 和 memory 主要是在重复利用
单个 polling directions。这一区别为 Group C 的结果提供了具体的几何解释，但目前应把它
看作 an interpretation supported by the experiments，而不是 formal causal proof。

## Common Settings

- Problem library: S2MPJ
- Problem type: unconstrained
- Dimension range: 6-50
- Budget:
  - Group A-C: 200n function evaluations
  - Group D: 200n and 500n function evaluations
- StepTolerance: 1e-6
- Group A-C features:
  - plain, with `n_runs = 1`
  - linearly_transformed, with `n_runs = 5`
- Group D features:
  - plain, with `n_runs = 1`
  - noisy_1e-1, noisy_1e-2, noisy_1e-3, and noisy_1e-4, with `n_runs = 5`
  - linearly_transformed, with `n_runs = 5`
  - linearly_transformed combined with the same four noise levels, with `n_runs = 5`

这里的 score 是 OptiProfiler 输出的 solver score。每个表格都对应一个 pairwise
comparison，因此同一行内分数越高表示该 solver 在这一组比较中表现越好。

## Group A: CBDS Single-Strategy Ablation

Group A 的目的是判断每个 acceleration strategy 单独打开时是否有效。这里的
`baseline` 是 `cbds-baseline-200n`，即三个 acceleration switches 全部关闭；
`memory-only`, `pattern-only`, and `momentum-only` 分别只打开一个策略。

### Scores

| Strategy | Feature | Baseline score | Strategy score |
| --- | --- | ---: | ---: |
| `memory-only` | plain | 1.0000 | 0.8398 |
| `memory-only` | linearly_transformed | 1.0000 | 0.8606 |
| `pattern-only` | plain | 0.6535 | 1.0000 |
| `pattern-only` | linearly_transformed | 0.6429 | 1.0000 |
| `momentum-only` | plain | 0.6290 | 1.0000 |
| `momentum-only` | linearly_transformed | 0.5680 | 1.0000 |

### Interpretation

`memory-only` 单独打开时并不能加速 CBDS，反而在 plain 和
linearly_transformed 上都稳定输给 baseline。对应 score 分别是 0.8398 vs 1.0000
和 0.8606 vs 1.0000。因此，`productive direction memory / acceleration search step`
不应被解释为 standalone core acceleration mechanism。

相比之下，`pattern-only` 单独非常强。它在 plain 上把 baseline 的 score 从
0.6535 压到劣势位置，在 linearly_transformed 上也把 baseline 压到 0.6429。
这说明 `pattern direction` 本身就是一个主要收益来源。

`momentum-only` 单独也非常强，甚至在 linearly_transformed 上相对 baseline 的优势
更明显：baseline score 是 0.5680，而 `momentum-only` 是 1.0000。因此，
`momentum extrapolation` 也是主要收益来源，而不是只能依附于 pattern direction 的辅助项。

Group A 的直接结论是：

1. `memory / search step` 单独无效，甚至稳定拖后腿。
2. `pattern direction` 单独有效，并且在 plain and rotated problems 上都很强。
3. `momentum extrapolation` 单独有效，并且在 rotated problems 上尤其强。

## Group B: CBDS Minimal Combination

Group B 的目的是判断 `pattern direction + momentum extrapolation` 是否已经足够，
以及 `productive direction memory / acceleration search step` 是否在此基础上还有额外价值。

### Scores

| Comparison | Feature | Solver 1 score | Solver 2 score |
| --- | --- | ---: | ---: |
| `cbds-baseline-200n` vs `cbds-pattern-momentum-200n` | plain | 0.6338 | 1.0000 |
| `cbds-baseline-200n` vs `cbds-pattern-momentum-200n` | linearly_transformed | 0.5829 | 1.0000 |
| `cbds-pattern-momentum-200n` vs `accelerated-bds-all-on-200n` | plain | 0.9078 | 1.0000 |
| `cbds-pattern-momentum-200n` vs `accelerated-bds-all-on-200n` | linearly_transformed | 0.8497 | 1.0000 |
| `cbds-baseline-200n` vs `accelerated-bds-all-on-200n` | plain | 0.6292 | 1.0000 |
| `cbds-baseline-200n` vs `accelerated-bds-all-on-200n` | linearly_transformed | 0.6020 | 1.0000 |

### Interpretation

结合 Group A，`pattern direction` 和 `momentum extrapolation` 单独都已经很强。
Group B 进一步说明它们的组合 `pattern direction + momentum extrapolation`
也是非常强的组合。相对于
`cbds-baseline-200n`，它在 plain 和 linearly_transformed 上都取得了明显优势：
baseline 的 score 只有 0.6338 和 0.5829，而 `pattern-momentum` 都是 1.0000。

不过，`accelerated-bds-all-on-200n` 仍然进一步优于 `pattern-momentum`。在
`pattern-momentum` vs `all-on` 的直接比较中，`pattern-momentum` 的 score 分别为
0.9078 和 0.8497，说明 `productive direction memory / acceleration search step`
虽然不是 standalone core mechanism，但在 combined solver 中不是纯粹的冗余策略，
尤其在 linearly_transformed 问题上仍有可见增益。

因此，Group B 支持两个层次的结论：

1. 如果目标是最小化算法改动和解释成本，`pattern direction + momentum extrapolation`
   是一个很强的 candidate，因为 Group A 和 Group B 都显示这两个策略是主要收益来源。
2. 如果目标是保留目前最强的数值表现，`all-on` 仍然是更好的选择，因为 memory /
   search step 在 `pattern-momentum` 之上还有额外收益。

## Group C: DS Generalization

Group C 的目的是判断这些 acceleration strategies 是否也能自然推广到 classical direct
search，还是主要依赖 CBDS 的 cyclic / block-coordinate structure。

### Scores

| Comparison | Feature | Solver 1 score | Solver 2 score |
| --- | --- | ---: | ---: |
| `ds-baseline-200n` vs `accelerated-ds-all-on-200n` | plain | 0.9111 | 1.0000 |
| `ds-baseline-200n` vs `accelerated-ds-all-on-200n` | linearly_transformed | 0.9925 | 0.8729 |
| `ds-baseline-200n` vs `ds-pattern-momentum-200n` | plain | 0.8623 | 1.0000 |
| `ds-baseline-200n` vs `ds-pattern-momentum-200n` | linearly_transformed | 0.9974 | 0.8232 |
| `ds-pattern-momentum-200n` vs `accelerated-ds-all-on-200n` | plain | 0.9991 | 0.8466 |
| `ds-pattern-momentum-200n` vs `accelerated-ds-all-on-200n` | linearly_transformed | 1.0000 | 0.8033 |

### Interpretation

在 plain 问题上，给 DS 加 acceleration 确实可能带来收益：
`accelerated-ds-all-on-200n` 优于 `ds-baseline-200n`，`ds-pattern-momentum-200n`
也优于 `ds-baseline-200n`。

但是在 linearly_transformed 问题上，结论反过来了。`ds-baseline-200n` 对
`accelerated-ds-all-on-200n` 的 score 是 0.9925 vs 0.8729；对
`ds-pattern-momentum-200n` 的 score 是 0.9974 vs 0.8232。这说明这些 acceleration
strategies 并不能作为 generic direct search acceleration 在 rotated problems 上稳定泛化。

另外，`ds-pattern-momentum-200n` 明显优于 `accelerated-ds-all-on-200n`：
plain 上是 0.9991 vs 0.8466，linearly_transformed 上是 1.0000 vs 0.8033。
这说明 `productive direction memory / acceleration search step` 对 DS 很可能是负贡献，
至少在这组 6-50 维 S2MPJ 实验中如此。

这个现象与前面 direct answers 中的几何解释一致。对 one-block DS，pattern step 是沿刚刚
接受的 polling direction 做 finite extrapolation，memory 则重新利用过去的 polling
directions。对 sequential CBDS，pattern direction 可以由多个 accepted block updates
合成为 new oblique direction。Momentum 即使对 DS 也可能通过跨 iterations 组合信息而
产生新方向，但 Group C 表明，在当前实验中这并没有转化为 rotation-robust acceleration。

因此，Group C 支持的结论是：

1. 这些 acceleration strategies 不应被描述为 universally beneficial direct-search
   acceleration strategies。
2. 它们的主要价值更可能来自与 CBDS 的 cyclic / block-coordinate structure 的相互作用。
3. 对 DS 而言，`pattern direction + momentum extrapolation` 比 `all-on` 更稳，
   而 memory / search step 不宜直接移植。

## Group D: Original CBDS vs NOMAD

Group D 的目的是衡量 acceleration switches 全部关闭时，original CBDS baseline 与
NOMAD 的距离，并判断把 budget 从 `200n` 提高到 `500n` 是否会改变比较结论。这里每一行
都是 `cbds` vs `nomad` 的 pairwise comparison；分数仍按 OptiProfiler 默认定义计算，即
十个 tolerances 上 history-based performance-profile scores 的平均。

### Scores

| Feature | CBDS 200n | NOMAD 200n | CBDS 500n | NOMAD 500n |
| --- | ---: | ---: | ---: | ---: |
| plain | 0.9344 | 0.9421 | 0.8853 | 0.9602 |
| noisy_1e-1 | 0.8550 | 1.0000 | 0.8528 | 1.0000 |
| noisy_1e-2 | 0.9102 | 0.9906 | 0.9128 | 0.9901 |
| noisy_1e-3 | 0.7719 | 0.9953 | 0.7673 | 0.9974 |
| noisy_1e-4 | 0.7963 | 0.9895 | 0.7563 | 0.9932 |
| linearly_transformed | 0.7993 | 0.9662 | 0.7909 | 0.9790 |
| linearly_transformed_noisy_1e-1 | 0.6798 | 1.0000 | 0.6837 | 1.0000 |
| linearly_transformed_noisy_1e-2 | 0.7095 | 0.9874 | 0.7112 | 0.9908 |
| linearly_transformed_noisy_1e-3 | 0.6664 | 0.9930 | 0.6750 | 0.9938 |
| linearly_transformed_noisy_1e-4 | 0.7083 | 0.9821 | 0.6808 | 0.9829 |

For descriptive aggregation only, the unweighted means over the ten feature rows are:

| Budget | CBDS mean score | NOMAD mean score |
| --- | ---: | ---: |
| 200n | 0.7831 | 0.9846 |
| 500n | 0.7716 | 0.9887 |

这些跨 feature means 不是新的 OptiProfiler profile score，只用于简洁描述十个 pairwise
results 的整体方向。

### Interpretation

在 `200n plain` 上，original CBDS 已经接近 NOMAD：0.9344 vs 0.9421。这说明二者在
未旋转、无噪声的基础问题上差距很小，original CBDS 并不是普遍落后。

但是，只要加入 noise 或 linear transformation，NOMAD 就在所有 feature 上领先。
`200n` 下四个 noisy features 的平均分为 0.8334 vs 0.9938；五个包含 rotation 的
features 平均为 0.7127 vs 0.9858。最明显的差距出现在 rotation + noise，四项平均为
0.6910 vs 0.9906。因此，original CBDS 相对 NOMAD 的主要弱点不是 plain setting，
而是 robustness to rotation and noise，二者叠加时尤其明显。

把 budget 提高到 `500n` 没有扭转这个结论。十项平均从 0.7831 vs 0.9846 变为
0.7716 vs 0.9887；五个包含 rotation 的 features 也从 0.7127 vs 0.9858 变为
0.7083 vs 0.9893。个别 CBDS scores 有轻微上升，但不存在系统性追赶，plain 上的相对
差距反而从 0.0077 扩大到 0.0750。由于这些分数是在各自 budget 内归一化的 pairwise
profile scores，这里应解释为 relative ranking 对更大 budget 很稳定，而不是说增加
budget 会使 CBDS 的绝对解质量变差。

因此，Group D 支持的结论是：

1. Original CBDS 在 plain problems 上可以接近 NOMAD。
2. Original CBDS 的主要缺口集中在 noisy and/or rotated problems，rotation + noise
   的差距最大。
3. 从 `200n` 增加到 `500n` 并不能靠更多函数值计算消除该缺口；这更像是 search
   geometry and robustness 的问题，而不是单纯 budget 不足。
4. 因而 accelerated BDS 的价值不能只描述为在 plain problems 上节省 evaluations；
   更重要的是它改变了 original CBDS 在 rotation and noise 下相对强 solver 的竞争力。

## Integrated Takeaways

综合 Group A-D，最重要的结论是：

1. 对 CBDS，`pattern direction` 和 `momentum extrapolation` 都是主要收益来源；
   它们单独打开时已经明显优于 baseline。
2. `pattern direction + momentum extrapolation` 是目前最自然的 minimal effective
   combination。它相对 baseline 的提升非常大，并且机制上比 memory / search step
   更容易解释。
3. `productive direction memory / acceleration search step` 单独无效，plain 和
   linearly_transformed 上都输给 baseline。因此它不应被写成核心加速机制。
4. 但是在 CBDS 的 combined solver 中，memory / search step 仍然提供了 marginal
   benefit：`all-on` 在 plain 和 linearly_transformed 上都优于 `pattern-momentum`。
   更准确的表述是 additional acceleration search step with marginal benefit in the
   combined solver。
5. 对 classical DS，这些策略没有稳定泛化；rotated problems 上甚至会降低表现。
   A plausible geometric reason is that DS pattern and memory steps mainly repeat individual
   polling directions, whereas CBDS pattern directions aggregate several accepted block updates
   into a new oblique direction within one iteration。
6. 因此当前更合理的论文表述是 accelerated CBDS / accelerated BDS，而不是 generic
   acceleration for direct search methods。
7. Original CBDS 与 NOMAD 在 plain setting 下差距很小，但在 noise and rotation 下
   稳定落后；将 budget 从 `200n` 提高到 `500n` 不会改变这一结构性结论。
8. Group D 因而为 Group A-B 的 acceleration gains 提供了 baseline context：最终方法
   需要解决的核心不是简单增加 budget，而是改善 CBDS 对非坐标对齐结构和噪声的适应性。

一个自然的 solver-design 问题是：最终版本是否采用 `pattern-momentum` 作为更简洁
版本，还是保留 `all-on` 以追求最强数值表现。当前实验支持的判断是，若论文强调
simplicity and interpretability，`pattern-momentum` 很有吸引力；若论文强调 best
observed performance，`all-on` 更强，但需要谨慎解释 memory / search step 的角色。
