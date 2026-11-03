# 普通用户说明与精简克隆验证

日期：2026-11-03。

## 范围

按用户确认，README 独立描述两个加速机制，移除未公开论文的配置与复现入口；保留公开 slides 链接、一页版实现和专门复现文档。检查 src，不删除必要算法解释或公开参考来源。保留此前全部未提交修改，不 commit/push。

发现 README 的 `git sparse-checkout set src examples` 不检出 tests，但 setup.m 强制添加 tests 并检查存在性，会使安装失败。因此最小修正 setup：src/examples 仍必需，tests 仅在存在时添加；精简安装不再提示运行不存在的 testbds。完整安装行为不变，solver 算法不变。

## Checklist

- [x] 检查 README、src、setup 及当前 dirty state。
- [x] 更新面向用户的说明，保留公开 slides 引用；修复 setup 的可选 tests 路径。
- [x] 在临时目录按 README 命令克隆当前 GitHub main，记录远端现状。
- [x] 在独立临时 Git 快照中验证未提交候选的 sparse checkout：仅 src/examples 及根文件，没有论文配置、研究/文档/测试目录。
- [x] 服务器 MATLAB 测试旧精简 setup 的实际失败、新精简 setup 的成功及基本 solver 调用，并检查完整 checkout 的 setup。
- [x] 核对源码与克隆文件哈希、文档搜索及 diff，记录证据与当前远端/候选区别。

Sparse checkout 是工作目录选择，不是访问权限控制，也不从公开仓库历史删除研究资料。用户仍可以主动检出其他目录或在 GitHub 查看。本次不修改论文仓库。

## 结果

## 完成记录

- README 删除了 “the paper's” 及论文配置/复现入口段落；保留公开 slides、正常算法说明和 workflow。补充 sparse checkout 不限制仓库访问、根目录 Git 元数据仍会检出的说明。
- src 搜索未发现依赖未公开论文的文字；只有获准保留的 DFOS2024 公开链接，因此本轮没有修改 src。一页版实现未改。
- 实际从 `https://github.com/blockwise-direct-search/bds.git` 执行 README 的 shallow/partial/sparse clone，随后 `git sparse-checkout set src examples`。远端 main 仍为 `67014737eaa9dbe47f7eb40e6d6829e27617277e`，仍含旧的 examples/bds_paper_options.m。不能声称当前远端已完成迁移。
- 在 `/tmp/bds-sparse-install.EwTQFS/candidate-source` 建立独立临时 Git 快照，再按同样 sparse 规则克隆至 candidate-bds。临时提交仅用于测试，不在用户仓库历史中，也没有 push。候选精简目录有 35 个非 .git 文件，仅包含 src/examples 和根目录 README.md、LICENSE、setup.m、.gitignore、.gitmodules。无 bds_paper_options.m，也无 docs/tests/research/.github 或论文目录。全部 35 个文件与本地候选 SHA-256 相同。
- 服务器隔离目录 `/home/lhtian97/Work/bds_sparse_install_20261103.4rbwfs`，MATLAB R2026a：旧精简 setup 实际失败为 `bds:PathNotExist`，错误明确指向缺失 tests；新精简与完整 checkout 的 setup 均通过，路径解析正确；完整 checkout 保留 testbds 提示和 tests 路径，精简版不提示不存在的 testbds。
- 两组梯度停机开/关的基本调用在精简与完整布局下返回完整相同结果；完整 run_bds_regression_suite 通过，包括 1350 个无加速参照案例和 120 个梯度判据案例。整个 MATLAB 进程于 2026-11-03 12:16:03 UTC 正常退出（0）。未重跑性能 benchmark。
- 为避免污染共享服务器，验证使用隔离 savepath shim，仅阻止 setup 写全局 pathdef/startup；实际路径添加、存在性检查及 solver 调用均执行。这不等于测试全局路径持久化权限。
- 本地证据目录 `research/user_facing_sparse_install_20261103/` 保存 CLONE_REPORT.json、FINAL_REPORT.json、测试时完整快照清单及压缩执行证据。测试后仅补全本记录，不改变已验证运行文件。
- git diff --check 与用户可见 README/src/examples 的论文关键词检查通过。用户仓库未 commit/push，论文仓库未修改。上述新的用户体验需在这些改动正式提交并推送后才会出现在 GitHub 克隆中。
