# 梯度停机实验（2026-10-29）

计划与授权边界见 `docs/development/BDS_GRADIENT_STOP_EXPERIMENT_20261029.md`。
这里仅包含实验控制代码，不改变 production solver。

`prepare_experiment.py` 在独立服务器目录中，从当前 production 源码生成实验副本，
保留 private 函数的正常可见性。生成位置不在仓库 src 中。
`gradient_stop_update.m` 实现新判据；`gradient_experiment.m` 的回放独立实现判据，
小规模及最终真实复跑必须与回放预测一致。

运行前必须有 production 回归/严格 MP 通过状态以及本实验 PREFLIGHT_ACCEPTED.json。
`run_experiment.sh` 使用 flock 和总计 48h 的 timeout，按顺序执行 baseline、selection、
validation、report。所有阶段和逐实例结果持久化。失败不覆盖，不把回放当作真实求解。

目标值仅由双关 BDS 基线的未加噪历史确定，在每个 feature/problem 的重复之间取
最优值，按照 `f_best + tau*(f_init-f_best)` 固定。它们不是原来多 solver 比较的
目标值，因此本实验表格不得直接替换原论文 performance profiles。
同时检查历史达标和实际返回点达标，严格要求不丢失基线成功实例。
真实函数评价由冻结 FeaturedProblem 提供；该框架的评价调用不作为 solver 求值。

控制代码及配置由 SHA-256 清单冻结；所有源、依赖、逐例和阶段证据存服务器独立目录。
本目录的 `testdata/` 可存回传证据，已由仓库现有规则忽略。
