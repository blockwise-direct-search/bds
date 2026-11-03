# 连续 polling 失败后建立梯度参考值：实验计划与记录

**最终状态（2026-10-30）：用户决定终止并清理。** 预检和流程测试通过；正式基线与筛选完成，
没有合格新候选。真实复跑完成 3417/3458 组，已有反例经过实际复跑确认；新随机种子验证未开始。
本文件以下为原计划及历史执行记录，不是待继续执行的任务。旧回收路径亦已纳入永久清理，
不再承诺可恢复。最终证据和删除范围见
[两轮探索归档](../../research/gradient_stop_trials_20261030/README.md)。

日期 2026-10-30，北京时间。用户授权清理上一轮失败方案、创建计划并执行新实验，
明确要求不设置运行时限。只在 research 与独立服务器目录工作，不修改 production、
论文、已接受历史数据或函数值停机参数，不 commit/push。

## 清理范围与恢复位置

上一轮作业已正常结束，但 150 组新规则没有通过无损失筛选，不是计算程序失败。
其本地代码、计划、testdata 已移出工作区至
`/Users/lht97/.Trash/bds_gradient_stop_20261029_retired_20261030/`。
服务器旧目录约 676 MB，移至
`/home/lhtian97/Work/.bds_experiment_trash/bds_gradient_stop_20261029/`。
上述操作可恢复；未清理 C04/C06、论文图、其他实验或生产源码。
新实验不读取旧轨迹作为数据；可复用已验证的控制代码结构，并重新验证。

## 新机制与冻结边界

针对本次冻结的 opportunistic CBDS 配置，以当前迭代所有选中块完整 polling 且
均未取得充分下降作为 polling 失败的明确标志。在 polling 结束、加速之前计数。
成功时清零；失败时加一。失败不触发 momentum/pattern；用断言核对失败时基点和
函数值不变。无效梯度不伪装成 polling 成功，也不通过“有无梯度记录”猜测计数。

当连续失败次数至少 K，且当前有效梯度满足
`e < max(1e-3, G/11)`，取当前 `G=norm(grad)+e` 为固定参考值。
只看当前这次误差，前面的失败无需通过误差门槛。第 K 次不通过时，后续失败继续检查。
参考样本不进入后续梯度窗口。参考建立后不再用连续失败次数决定停机。
最终判据保留双阈值 `all(window < tol*min(1,Gref))` 或
`all(window < beta*tol*max(1,Gref))`。

误差门槛、计数和双阈值是待验证的机制，不宣称严格可靠性保证。
`e(L)=L*e(1)` 用于新规则与回放；旧规则对照保留原 L=1000 的直接计算。
初始步长、MP、预算 500*n、expand=2、shrink=0.5、forcing、分块及函数值停机
全部使用冻结 external paper options，只有验证随机输入按下文显式更换种子。

## 比较、参数和新验证数据

- 第一组只变 K={1,2,3,5,8}，固定 L=1000、tol=1e-2、beta=1e-3、window=1。
- 预声明扩展网格 K 上述五值，L={10,100,1000,10000,100000}，
  tol={1e-5,1e-4,1e-3,1e-2,3e-2}，beta={1e-3,1e-2,1e-1}，window={1,2}。
  合计 750 组（包含第一组），另保留旧规则及“旧参考初始化＋双阈值”两个对照。
- 先汇报只变 K 的五组，再检查有限扩展网格。优先选择基本五组中的无损失候选，
  若不存在才从扩展组选择。K=1 只作对照，正式新机制候选要求 K>=2。
- 精度 tau={1e-2,1e-3,1e-4}，历史达标和实际返回点达标均不得丢失基线成功实例。
  候选只用开发问题（固定序号非 5 的倍数）选择；原保留问题已经看过，不再称为未见数据。
- 若没有合格候选，固定开发集损失最少的一组作为“失败诊断候选”进行真实复跑，
  明确不能据此通过验收，禁止放宽成功要求或自动扩展参数范围。
- 问题集与六特征保持原范围，133 个 S2MPJ 问题，6–50 维，plain 一次，其他五种各五次。
  六种为 plain、noisy_1e-4、noisy_1e-2、linearly_transformed 及其 1e-4/1e-2 噪声组合。
- 开发随机种子 20260828，共 3458 例。固定候选之后才计算新种子 20261030 的 3458 例。
  FeaturedProblem 种子仍用 `mod(23333*seed_base+211*repeat,2^32)`。
  新种子结果不得反向调参；确定性 plain 可能相同，不夸大其独立性。
- 每个种子组内，目标来自双关 BDS 的真实未加噪最佳值，跨同 feature/problem 的重复
  固定 `best+tau*(initial-best)`。这不是原多 solver performance-profile 目标。
- 两个种子组都真实运行：双关、仅函数值、诊断/合格候选的仅梯度和联合、
  旧参考初始化＋双阈值对照的仅梯度和联合。函数值停机原有损失单独归因，不能调参掩盖。

## 分阶段检查清单

- [x] 精确核对并可恢复清理上一轮实验；不影响 accepted 数据。
- [x] 建立新独立源码快照及明确的逐迭代 polling 成败/计数记录，SHA-256 冻结。
- [x] 单元测试覆盖成功清零、失败计数、只检查最后一次误差、第 K 次不通过后继续、
  无效梯度、参考只设一次、参考样本排除、双阈值、预算和退出优先级。
- [x] production 原有 regression、MP smoke、1890 例严格 MP 对照重新通过。
- [x] 补充 120 例关闭梯度停机的仪器化等价性检查，覆盖 MP 全开/全关、函数值停机
  开/关、五种 K、三个维数和两个固定种子，完整输出必须等于未改的 production。
- [ ] 六个问题、六特征小规模实跑，包含 ARGLINB、ARWHEAD、BIGGS6、GAUSS1LS、
  SBRYBND、VESUVIALS，repeat=1。核对所有 K、旧规则、双阈值对照、两个停机开关组合。
  双关与 production 完整输出一致；实际提前停机须与独立回放逐次前缀、求值数和返回点一致。
- [ ] 小样本走完筛选及复跑，检查确实触发新规则提前停止，不能只通过永不停机的例子。
  流程测试另用 20261031 作为仅测试种子，覆盖固定候选的新种子评估分支；
  不提前查看正式新验证种子 20261030 的结果。
- [ ] screen 正式运行：开发基线→筛选并冻结候选→开发真实复跑→新种子基线→
  固定候选新种子真实复跑→评估→汇总。最多 30 worker，无总时限或阶段超时。
- [ ] 汇总每种 K、参考建立时刻/大小/误差比、未建立参考比例、未触发停机比例、
  精度损失及求值节省。按六特征及全部实例分别报告，不删除失败实例。

## 运行与证据约定

本机 `/Users/lht97/Work/bds`，main，基线 commit
`67014737eaa9dbe47f7eb40e6d6829e27617277e`。
服务器新目录 `/home/lhtian97/Work/bds_poll_failure_reference_20261030`。
MATLAB R2026a，通过 SSH 登录确认启动，再挂 screen；不访问或重置授权凭据。
无时间上限，但遇断言、程序或完整性错误必须停下保留证据，不无限自动重试。
独占锁防重复运行，逐例原子落盘、阶段日志和状态保存，支持检查后显式恢复。
只有实际完成状态和数据证据才能标为通过；完成实验不等于机制有效。

本计划使用 math-writing 的 core、group profile、V1–V3、P5–P7、S1–S5。
范围是实验算法说明及证据设计，不是论文审阅；证明、引用更新、排版和投稿检查不在本任务内。
新增显式失败事件是为了准确计数并使回放独立核对；新种子是为了避免把看过的数据当作独立验证。
当前机制效果与全量验证均待实测，不能由设计说明替代。

## 执行记录

计划已建立。隔离 solver、显式计数事件及独立回放已经实现。
交互式 SSH 启动 MATLAB R2026a 成功。新单元测试故意破坏计数时，暴露了
assert 自定义错误缺少 message 文本的问题；已修正实验代码的错误诊断形式，
数值机制不变，单元测试重新运行显示 GRADIENT_EXPERIMENT_UNIT_OK。
原有 production regression/smoke/strict 已在独立 screen 中启动，未设置时间限制。
实现、验证和正式启动结果按实际进度继续补充。

- regression 于 09:24:33、MP smoke 于 09:24:56、1890 例 strict 于 09:28:54 全部退出 0。
- 120 例关闭梯度停机等价性通过，`COUNTER_OFF_ACCEPTED.json` 已生成。
- 交互式 MATLAB 单元断言通过后退出仍出现 `free(): chunks in smallbin corrupted`，
  与上一轮交互退出时相同；未重置环境或删除授权数据。正式验收依赖独立批处理的
  正常退出状态，不能把交互式退出异常当作正常退出。
- 旧实验四个本地临时上传包也已移入对应回收目录，旧服务器启动探针也归入旧实验回收目录。
- 最终控制包 r3 SHA-256 为
  `5ed9c030038b19665b6a8d535747ecfbe46d00095a61fb9780570a86fd877618`。
  完整清单包含 391 个文件，清单 SHA-256 为
  `d607ff554b5d21517d3c016bfd372b2dd2bdac5e0ed71399f6580796c02d6842`。
  冻结依赖另有 1348 个文件。r3 只补充关闭梯度停机检查、启动门禁和说明，
  正在预检的数值实现与 r2 相同。
- scores 中 dev/holdout 的 loss 总数跨三个精度和历史/返回点两个口径累加，
  不是去重后的失败问题数；逐实例损失须查看 selected_cases.csv/per_case.mat。
- VESUVIALS 完整预算预检耗时较长，因此增加自动启动控制器，等待原有验证和
  preflight/pipeline_smoke 正常退出，再核对全部 ACCEPTED 与冻结清单后启动正式流水线。
  不降低预检预算、不删除慢实例、不设等待时限。失败状态立即停止，不默认重试。
  `launcher.status` 的 waiting 不代表正式计算已开始，必须另看 `compute.status` 和实际落盘数据。
- 自动门禁在本机和服务器都通过缺失、进行中、正常完成、失败、非零退出及未知状态测试。
  r4 仅增加此控制器及其测试，不改数值代码。控制包 SHA-256 为
  `3e614c3a8f1ac83f4556eea92f3da98f6909a1090558aac6cb39bbcd21d7edc4`，
  最终 393 文件清单 SHA-256 为
  `1ef1f6f001c522323526ec9b223f418f02a8439c9bc8a4be5747e3da52565b8f`。
- 为避免慢实例结束后才发现汇总代码问题，将使用已经完成的小例（最多 18 个），在额外隔离
  副本中提前跑同一 pipeline_smoke。原 preflight 和其后自动接续的 pipeline_smoke
  仍须完整通过，不替代或绕过正式启动门禁。
- 初次提前探针误以为 18 个小例都已完成，实际缺少 f4_p003_r1，因输入缺失退出 1。
  已保留 `pipeline_probe.status`、`logs/pipeline_probe.log` 和隔离副本的
  `failed_pipeline_smoke_attempt1/`。第二次只在诊断副本中过滤尚未完成的输入，
  实际使用 17 例，仍覆盖全部六特征；正式源码、正式预检和门禁均未缩减或改动。
- 自动控制器于 09:39:41 启动，screen 为
  `4049121.bds_poll_failure_reference_20261030`。截至 09:43:46 正式预检完成 32/36，
  控制器状态为 waiting_for_verification，正式全量计算尚未开始。
  原验证 screen 为 `4000143.bds_poll_failure_preflight`，通过后会自动进入原 pipeline_smoke。
- 已通过的 production/counter-off 证据在服务器 `evidence/production_verification.tar.gz`，
  本机 Git-ignored 的 `research/poll_failure_reference_20261030/testdata/` 已保存同一文件。
  SHA-256 为 `0d8c16bca0e137c9d8f42d5f28017e7401a9fc41d333c70ac5c3d74e2002fd6f`。
- 09:44 的可选提前探针正常退出 0，17 个已完成小例走完原种子筛选及真实复跑、
  固定候选的 20261031 测试种子基线及真实复跑、只评估固定候选的汇总。
  确实触发新规则提前停止 1 例，marker 在 `pipeline_probe/PIPELINE_SMOKE_ACCEPTED.json`。
  此探针只验证控制流程，不用其选出的参数替代正式开发集筛选。
- 本轮交接时保留所有强制门禁：原 36 例 preflight 及其后的原 pipeline_smoke
  正常结束后，已启动的控制器才会自动执行正式流水线。当前不得报告全量实验完成。

查看当前状态（waiting 不代表全量已开始）：

```bash
ssh -p 53781 lhtian97@frp-pen.com \
  'cat /home/lhtian97/Work/bds_poll_failure_reference_20261030/launcher.status; cat /home/lhtian97/Work/bds_poll_failure_reference_20261030/preflight.status; test ! -f /home/lhtian97/Work/bds_poll_failure_reference_20261030/compute.status || cat /home/lhtian97/Work/bds_poll_failure_reference_20261030/compute.status'
```
