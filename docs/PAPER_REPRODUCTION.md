# 论文配置与生产 BDS 的对应关系

本次对齐以 2026-10-19 核对的 C06 内部实验、C04 外部实验为依据。
生产入口是 `src/bds.m`。默认使用 momentum → pattern（MP），retained
productive-direction memory 已从 production 移除。其余默认参数不变。
这里的配置入口不启动 benchmark，也不声称修改默认值验证了历史性能结论。

## 可运行入口

在仓库根目录的 MATLAB 会话中：

```matlab
addpath('src', 'examples');
x0 = [-1.2; 1];
fun = @(x) 100*(x(2)-x(1)^2)^2 + (1-x(1))^2;
options = bds_paper_options(x0, 'internal', 'mp');
[xopt, fopt, exitflag, output] = bds(fun, x0, options);
```

`examples/bds_paper_options.m` 逐项列出实际 option 名称和值，不根据 solver
显示名称猜测，也不依赖默认值补齐论文设置。已移除的 retained 两个字段不再传给
production；冻结 MP 比较端仍显式使用原来的 false 和 `max(1,min(n,5))`，两侧 options
分别保存。移除的是从未启用的机制，不改变论文 MP 的配置含义。

解析约定也需明确：`Algorithm='cbds'` / `'ds'` 确定分块及访问方式，因此不再同时传入
互斥的 `num_blocks`、`batch_size` 或 `block_visiting_pattern`；冻结入口没有传
`direction_set`，在本次核对的 production parser 中对应坐标方向 `{±e_i}`。
标量步长和容差按块展开。这里核对这些解析行为，
不声称任意未来版本改变接口约定后仍无需重新验证。除上述两个弃用字段外，原始 options
字段和值不变。

| 入口参数 | 块/加速 | 初始步长 | 函数值/梯度额外停机 |
| --- | --- | --- | --- |
| `'internal','mp'` | CBDS，MP，无 retained | `alpha_init=1` | 均关闭 |
| `'internal','noacc'` | CBDS，全部加速关闭 | `alpha_init=1` | 均关闭 |
| `'internal','ds'` | DS，一块，全部加速关闭 | `alpha_init=1` | 均关闭 |
| `'external','mp'` | CBDS，MP，无 retained | `alpha_init='auto'` | 均开启 |

内部加速比较使用前两项；分块比较使用后两种无加速算法（CBDS 与 DS）。
外部比较的 MP 使用最后一项，不能套用内部停机/初始化设置。
共同参数包括预算 `500*n`、`expand=2`、`shrink=0.5`、`StepTolerance=1e-6`、
`forcing_function=@(alpha)alpha^2`、`reduction_factor=[0,eps,eps]`、
`momentum_decay=0.6`、`seed=20260828`。完整字段以该入口为准。
即使目标带噪声，冻结实验中的 `is_noisy` 仍为 `false`。

普通软件默认值不等于外部比较设置：软件默认 `alpha_init=1`，两种额外停机
关闭；默认 seed 仍为 `'shuffle'`。需要复现时使用显式入口。
旧 retained 开关 false 或空值兼容，true 明确报错；旧容量参数警告后忽略。
需要复现 retained 历史实验时应使用相应历史代码（移除前版本 `ece5ab04`），
不能把当前 MP 冒充原实验配置。没有新增 PM/MP 顺序 API。

## 与算法参数分开的 benchmark 协议

- 问题集：冻结 S2MPJ manifest 的全部 133 个无约束问题，维数 6–50，无排除。
- 接受的内部实验：C06，plain 一次，`noisy_1e-4` / `noisy_1e-2` 各五次。
- 接受的外部实验：C04，`plain` 一次；`noisy_1e-2`、`noisy_1e-4`、
  `linearly_transformed`、`linearly_transformed_noisy_1e-2`、
  `linearly_transformed_noisy_1e-4` 各五次。当前图的 provenance 使用这六个 feature；
  后三项在冻结配置中标记为正交变换。
- base seed 为 20260828；随机 realization 由冻结 OptiProfiler 协议产生，不能
  把 solver 的 `seed` 字段当成整个 benchmark 的随机协议。
- OptiProfiler commit：`fdf2c550bd429cbfe2e4656a90859d2b32718b2d`。
- S2MPJ commit：`084dc1e0b4838b8723884e6c563235e4cafbd113`。
- 外部图是已接受 C04 数据的 C06 原生重新导出，不是新的外部计算。其他 solver
  的选项及各 feature 的运行协议仍以 C04 显式 runner / 当前图 provenance 为准；
  本入口只覆盖其中 BDS MP，不重建未知的外部 solver 选项。

## 冻结证据与验证范围

服务器参照为 `c06_pure_internal_20261015/bundle_r1/mp/`，与
`c04_external_comparison_20261010/bundle_r8/mp/` 的 33 个文件逐字节一致。
冻结 solver `c03_bds_mp.m` 的 SHA-256 是
`db945eaec9042d50820ec899eb3297eea6797af7dd4e7331d905b9795243f302`。
冻结 MP phase 的 SHA-256 是
`566972c99f1aef6fc1468670b79112ee63c6d4d8a9f3e714830872293527737f`。
历史 runner、结果和论文文件不随本次生产代码修改。

执行记录、精确命令与实际测试结论见
[`BDS_MP_ALIGNMENT_EXECUTION_20261019.md`](development/BDS_MP_ALIGNMENT_EXECUTION_20261019.md)。
验证同时记录 `iseqiv(prec=0)` 与完整轨迹比较；诊断时两边同时打开 histories，
与冻结实验默认关闭输出历史的设置区分记录。smoke test 和 plain 轨迹回归都不等于
整套论文性能实验复现。

后续 retained 移除与重新验证记录见
[`BDS_RETAINED_REMOVAL_EXECUTION_20261020.md`](development/BDS_RETAINED_REMOVAL_EXECUTION_20261020.md)。
