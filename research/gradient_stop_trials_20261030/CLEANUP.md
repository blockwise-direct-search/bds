# 两轮梯度停机探索的终止与清理

日期：2026-10-30。用户授权停止本次实验，删除两轮失败探索的原始结果和服务器数据，保留小体量研究记录。不得修改 production solver、论文、已接受实验、共享依赖或其他作业，不 commit/push。

## 顺序与检查清单

- [x] 核对路径、磁盘占用、Git 状态和实验进程归属。
- [x] 停止本次流水线及其专属 MATLAB worker，确认不会自动进入下一阶段。
- [x] 保存两轮配置、汇总、失败实例清单、验证状态、必要日志及来源校验信息，不保存完整逐次轨迹。
- [x] 在本目录记录失败结论和未完成验证，区别原有参考初始化与最终停机门槛。
- [x] 核对保留文件可读取且来源哈希一致后，永久删除明确列出的实验数据。
- [x] 复核作业已停止、目标目录不存在、正式代码未改，并记录释放空间。

## 精确删除范围

服务器完整隔离目录（包含专用源码/依赖副本，不是共享依赖原件）：

- `/home/lhtian97/Work/bds_poll_failure_reference_20261030`
- `/home/lhtian97/Work/.bds_experiment_trash/bds_gradient_stop_20261029`

本地：

- `/Users/lht97/Work/bds/research/poll_failure_reference_20261030/testdata`
- `/Users/lht97/.Trash/bds_gradient_stop_20261029_retired_20261030`，其中小体量控制代码与原计划先保留。
- 与本轮明确对应、逐个核对过的临时上传包（若存在，实际路径另记）。

保留本地 `research/poll_failure_reference_20261030` 控制代码作为历史实验实现，不再运行；原执行计划追加终止说明。删除是永久清理，保留的摘要不能还原完整实验轨迹。

## 执行记录

开始核对时 production 基线为 main / `67014737eaa9dbe47f7eb40e6d6829e27617277e`；仅本轮研究代码和计划为未跟踪文件。服务器本轮约 1.8 GiB、旧轮约 676 MiB；本地 testdata 及旧回收目录待清理。

### 完成记录

- 北京时间 2026-10-30 18:45 完成主要删除操作。
- 核实 PID/PGID 4049123 为本次 run_experiment.sh，MATLAB 主进程 259260 及 30 个 worker 均属于该组。先暂停专属组防止进入下一阶段，再 TERM/CONT；5 秒后对仍存活的 2 个组内进程 KILL。该组原有 95 个进程，最终没有活跃进程，screen 亦已退出。未使用按用户名或 matlab 名称的全局杀进程命令。
- 最终基线 3458/3458；真实复跑 3417/3458 组（17085 次已完成并通过回放一致性检查的 solver 调用）。剩余 41 组未完成，新种子正式验证未开始。原 started 状态文件作为原件保存，不改写成 completed。
- 第一轮保留 53 个服务器原件，第二轮 44 个，全部逐文件 SHA-256 核对通过。另保留旧本地计划、只读清单工具、删除前清单和本次总结。归档约 4.54 MiB，本地第二轮历史控制代码约 88 KiB。
- 服务器两个明确目录均已永久删除：分别 1869476 KiB 与 691456 KiB，合计 2560932 KiB（约 2.44 GiB）。删除后确认路径不存在；服务器可用空间约 1505838600 KiB。
- 本地 testdata（26148 KiB）、旧实验回收目录（31728 KiB）及下列 5 个临时包已永久删除并逐个确认不存在：
  - `/private/tmp/bds_poll_failure_control_20261030_r1.tar.gz`
  - `/private/tmp/bds_poll_failure_control_20261030_r2.tar.gz`
  - `/private/tmp/bds_poll_failure_control_20261030_r3.tar.gz`
  - `/private/tmp/bds_poll_failure_control_20261030_r4.tar.gz`
  - `/private/tmp/bds_poll_failure_production_20261030.tar.gz`
- `git diff --exit-code` 与 `git diff --cached --exit-code` 均通过，未修改任何已跟踪正式文件。改动只在未跟踪的研究记录与实验计划内；没有 commit/push。论文仓库、已接受数据及共享依赖未操作。
- 删除不是移动到回收站：完整轨迹和逐实例 MAT 数据无法从本次轻量归档恢复。后续工作回到现有 production 机制，不自动续跑这些历史实验。
