# 随机 10 个小维 S2MPJ 问题的加速对照

日期：2026-10-06（Asia/Shanghai）。用户要求执行，不修改论文，不提交 Git。

## 配置与不变量

- 从 S2MPJ 默认维度满足 6 <= n <= 10 的全部无约束问题中无放回抽取
  10 个不同问题。MATLAB RandStream mt19937ar，抽样 seed=20261006。
  不强制维度均衡，不根据结果重抽，不添加 exclusion list。
- 原始无噪声、不旋转问题，每配置一次，预算 500n。
- 使用本机 production BDS，commit
  `4247229d6d8add2b0bd0327edff6c6f0441979d9`，开始时工作树干净。
  src/bds.m SHA-256 为
  `3fb6d16ca9d527fe1e74ecd5fff7c19f83ac4a2ff701022a211a1e212a74dd81`。
- 没有本机 BDS AGENTS.md，已阅读 tests/README.md、research/README.md、
  论文实验说明和 TSFSB options/verifier。
- 当前服务器 /home/lhtian97/Work/bds 是旧且 dirty 的工作树，不覆盖它。
  传输本机源码到独立输出目录，逐文件核验源码哈希。
- 配置继承 tsfsb_benchmark_options，alpha_init=auto、expand=2、shrink=0.5、
  StepTolerance=1e-6、cbds，两个额外停机均开启，保持一致性检查开启。
  function window=20、func_tol=1e-6、gradient window=1、grad_tol=1e-2、
  L_H=1e3、reference finite difference tolerance=1/30。
- 三个加速开关全部 on/off，除三个开关以外选项严格相同。
  显式记录 memory size=min(n,5)、momentum decay=0.6、同一 solver seed。
  为保留输出，两者均打开 x/alpha/block/gradient histories，不做额外 debug evaluations。
- 使用服务器冻结依赖 /home/lhtian97/local/optiprofiler_c02 中的 S2MPJ，
  OptiProfiler commit=fdf2c550bd429cbfe2e4656a90859d2b32718b2d。
  直接调用 BDS，不生成 profiles。
- 完整保存四个返回值、所有输出字段、options、初始点、实际评价历史、
  seed、抽样候选池和 selected manifest。日志打印完整数组，不用 MATLAB
  struct display 的省略摘要替代完整输出。每次运行单独 MAT 并汇总 results.mat。

## 顺序清单

- [x] 核对本机源码、实验配置、服务器及依赖，先建立本记录。
- [x] 编写 runner，核验两配置只差三个开关，完整保存/打印输出。
- [x] 隔离部署源码并验证 SHA-256，执行 20 次调用。
- [x] 验收 10 个问题、20 个结果，n 范围、预算、返回输出与历史一致性。
- [x] saved-data-only 验收 MAT 和日志，将结果下载本地并校验哈希。
- [x] 填写完成记录，整理逐问题对比及实际停机原因。

## 完成记录

首次启动在任何抽样和 solver 调用前失败。MATLAB restoredefaultpath
脚本不能在含 nested function 的静态 workspace 中创建内部变量。
已将路径重置移到 batch 启动表达式，不改配置或 seed；保留首次错误日志。
原配置重试成功，未换题或缩小预算，20 次 solver 调用无失败。

### 完成与环境

- 服务器独立目录 `/home/lhtian97/Work/bds_small_comparison_20261006`。
  原有 dirty BDS 目录未动。screen 名称 bds_small_20261006，完成后退出。
- MATLAB 26.1.0.3203278 (R2026a)，单线程，无 parallel pool。
- S2MPJ src commit `084dc1e0b4838b8723884e6c563235e4cafbd113`。
  probinfo_matlab.mat SHA-256
  `17de6acd7b966be6c038ad790e4d163e8ba2649903aa0f08d86497faf04d8911`。
- 候选池 88 个问题，与 metadata 独立筛选一致，无排除项。
  按名称排序后用固定 seed 抽样，未按表现挑选。
- 抽样结果依次为 SSCOSINE(10)、ERRINRSM(10)、SPARSQUR(10)、COSINE(10)、
  TRIGON1(10)、GENHUMPS(10)、DIXON3DQ(10)、VIBRBEAM(8)、THURBERLS(7)、
  LANCZOS3LS(6)。不要求覆盖每个维度，本次未抽到 9 维。
- 32 个 production src 文件的服务器/本机 SHA-256 全部一致。
  部署包传输前后 SHA-256 一致；本地另存 production_source.tgz。
- 20 个独立 result MAT、manifest.mat、checkpoint.mat、results.mat、summary.csv、
  完整 run.log 均保留。results.mat 存全部四个返回值、完整 options、历史、初始点，
  以及独立计数的实际评价点和函数值。

### 验收结果

运行进程 exit_status=0。另一次 MATLAB 调用仅加载保存文件，输出
`SAVED_DATA_ONLY_PASS`，verification_exit_status=0。
验证了抽样可复现、问题不重复、维度、两个 stopping switches 开启、
两个配置除三个加速开关外 options 一致、20 个开始/结束日志标记，
独立计数=funcCount=fhist 长度，xhist 与独立 trace 一致，
实际函数值均有限且等于 fhist，fopt 为历史最小值，返回点曾实际评价。
所有调用满足 500n 预算。下载文件逐项 SHA-256 与服务器一致。

本地结果在本目录 `testdata/results/`，汇总表为 `summary.csv`，
完整输出日志为 `run.log`，合并数据为 `results.mat`。
验收日志在 `testdata/verification.log`，全部数据校验值在
`testdata/results_hashes.sha256`。服务器文件结构相同。

- results.mat SHA-256：`d58fedd393e86207352dbb4ffd6b279a3fe6cd187a49477128d21cf6c7888200`
- run.log SHA-256：`4b1581cd696e6a1a7ca431b51ecf6ca7ba8aeb4b7ad6a5ff1b14b03f56cbfcf0`
- results_bundle.tgz SHA-256：`d57fa23ef8c14a1d0535798c7821d831698aeb8412103b3b8752dcc5cddafe18`

### 解释范围

这是单次小样本、不同停机时刻的返回值比较，不是固定共同精度的性能排名。
BDS 合计 19299 次评价，无加速版合计 21942 次，但不能据此单独断言更优。
特别是 LANCZOS3LS，BDS 在 710 次评价时因梯度停机返回约 1.6934e-2，
无加速版在预算 3000 次处返回约 1.8444e-5。尚未调查此差异的因果机制。
没有重跑大规模 benchmark，没有修改论文、算法、原生图，也没有提交 Git。
