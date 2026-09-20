# Ten-Solver Full-Set Benchmark — Execution Record

Task ID: TSFSB (ten_solver_full_set_benchmark). Created 2026-09-20.
This record governs a fresh common-pool benchmark: 10 solver configurations x
10 features x all S2MPJ unconstrained problems with default dimension
6 <= N <= 50, with no excludelist. It follows the user task prompt dated
2026-09-20 (stored in the commissioning conversation; the matching planning
document is `TEN_SOLVER_FULL_SET_BENCHMARK_AGENT_PROMPT.md` in the
bds_convergence reproducibility directory, read-only reference).

## 1. Objective and scope

- 10 solvers (fixed order): BDS, BDS without acceleration, DS, NOMAD, LAM,
  NEWUOA, FD-BFGS, PDS, BFO, Nelder-Mead.
- 10 features: plain (1 run), noisy sigma in {1e-1..1e-4} (5 runs),
  linearly_transformed (5 runs), linearly_transformed_noisy sigma in
  {1e-1..1e-4} (5 runs). 46 feature/run conditions.
- Problems: S2MPJ, ptype 'u', default dimension 6 <= N <= 50,
  variable_size=default, no excludelist. Metadata enumeration of the frozen
  S2MPJ (084dc1e0) gives P = 133 candidates, including all 11 instances
  wrongly excluded by the old 42-name list. Expected outcomes: 460*133 =
  61,180. P must be re-derived on the server in MATLAB; any difference must
  be explained with explicit set differences.
- Budget: 500*N recorded function evaluations per solver/problem/run,
  enforced by OptiProfiler FeaturedProblem plus solver-internal budgets.
- All configurations re-run from scratch. No splicing with old experiments.

## 2. Invariants

1. No modification of bds_theory, bds_convergence, ds_complexity, slides, or
   thesis material. Old records are read-only references.
2. No deletion or overwrite of old benchmark data
   (/home/lhtian97/Work/bds_c02_*, bds_cpsb_*, etc.). No killing of other
   users' MATLAB processes. The dirty server clone
   /home/lhtian97/Work/bds (branch rebuilt_code_style) is not touched.
3. Source freeze: the full run uses one BDS commit, identical on local main,
   GitHub main, and a fresh dedicated server clone. No pulls during the run.
4. No silent filtering: the problem manifest is built independently of the
   runner; the runner passes explicit problem_names and an empty excludelist;
   every load failure is investigated, never dropped from the manifest.
5. Solver failures are recorded as outcomes (OptiProfiler penalty rules).
   Infrastructure failures are fixed and the affected units re-run with the
   same configuration, seed, and budget; original failure records kept.
6. All figures from OptiProfiler native output only. No post-processing of
   PDFs. File copies must be byte-identical (SHA-256).
7. No reduction of solvers, features, runs, problems, or budget for speed.

## 3. Verified environment facts (2026-09-20)

Local (macOS, /Users/lht97/Work/bds): HEAD fbbe05472d882dbaa829c83e887e5eb8ae693e9d
"Update BDS slides link", clean, == origin/main (fetched). Submodule
.github/scripts not initialized locally (not needed). No local MATLAB.

Server (ssh -p 53781 lhtian97@frp-pen.com, host zDP): Ubuntu, 120 CPUs,
250 GiB RAM, 2.1 TiB free. MATLAB R2026a 26.1.0.3203278 at /usr/local/bin/matlab
(Optimization + Parallel Computing toolboxes confirmed in C02). No Slurm/PBS;
detached GNU screen is the accepted mechanism. No MATLAB compute jobs running
(only fluxbox X processes of user zhuhuat). /home/lhtian97/Work/bds is a
dirty clone on branch rebuilt_code_style at 04c246ac — NOT touched; a fresh
dedicated clone will be created for this experiment.

Dependencies on server (frozen versions):
- OptiProfiler: /home/lhtian97/local/optiprofiler_c02 @ fdf2c550bd429cbfe2e4656a90859d2b32718b2d, clean.
  (The other copy /home/lhtian97/local/optiprofiler @ 1c4b7d91 is dirty and
  NOT used. Note: ensure_optiprofiler_on_path in tests/profile_optiprofiler.m
  probes ~/local/optiprofiler first — our runner must add the _c02 copy
  explicitly and verify with which -all.)
- S2MPJ: submodule of optiprofiler_c02 at
  matlab/optiprofiler/problem_libs/s2mpj @ 084dc1e0b4838b8723884e6c563235e4cafbd113,
  clean; config.txt: variable_size=default, test_feasibility_problems=0.
- PRIMA: /home/lhtian97/local/prima @ bb663c197edc10f7923dda6cb46486998ea08387
  (v0.7.2-947-gbb663c19); newuoa.m SHA-256 090946899b85bc35da5b3171f9c91517725f939e47277cf03a5a82a5489ec7e0
  (matches C02 record).
- NOMAD: /home/lhtian97/local/nomad @ f281734f3a421dfc71b3bbd03efcb802cff0ad9d
  (v.4.5.1-19-gf281734f-dirty; dirty build state preserved from C02, not
  rebuilt). MEX: build/release/interfaces/Matlab_MEX/nomadOpt.mexa64.
- BFO: /home/lhtian97/local/BFO @ 2075e99c76a02ba934d1708c9028529bceb3b29c,
  bfo.m locally patched (function-existence probe forced to `found = 1`;
  one-line patch, diff recorded; BFO v2.0 by Porcelli-Toint). Frozen as-is
  with SHA-256; the patch does not affect algorithmic behavior. BFO has a
  documented 'random-seed' option (rng(seed,'twister')) — the legal
  randomness control interface; default behavior to be recorded.

C02 reference material retrieved locally (read-only):
- /Users/lht97/Work/bds_c02_ref/bds_c02_clone @ 846d5c5f3905a1f906356a34a979c965db20e36a
  (accepted C02 source; bundle SHA-256
  5d10f850b10458f4b806a8cf848f3352bdd45ece8dcfa8cd645190a951899ca1).
- /Users/lht97/Work/bds_c02_ref/optiprofiler_c02 (rsync copy for reading).

## 4. Verified OptiProfiler facts (fdf2c550, read from source)

- Run seed rule (solveOneProblem.m:70): real_seed = mod(23333*seed +
  211*i_run, 2^32), i_run = 1..n_runs, identical for all 10 solvers.
  With base seed 20260828: runs 1..5 = 299497375, 299497586, 299497797,
  299498008, 299498219. Verified against source; runtime reproducibility
  will be smoke-tested (same seed -> identical histories; changed seed ->
  changed histories).
- Noise (Feature.m:935-937, 1158-1190): f_tilde = f + sigma*max(1,|f|)*Z,
  Z ~ N(0,1), stream seeded from (real_seed, f(x), x, n_eval); fresh draw per
  evaluation; aligned across solvers by evaluation index. Saved
  fun_histories/fun_outs/fun_inits are noise-free; solver sees noisy values.
- linearly_transformed (Feature.m:596-622): Q from QR of randn (sign-fixed),
  depends only on (real_seed, n); condition_factor default 0 -> A = Q',
  purely orthogonal, no scaling/translation; y0 = Q*x0; f_Q(y) = f(Q'*y).
  Q reconstructable from (seed, n). Solver never sees Q.
- Budget: max_eval = ceil(500*n) enforced by FeaturedProblem; recorded
  n_evals never exceed it; real calls beyond 2*max_eval raise -> abnormal.
  Checking evaluations (output assessment, fun_init, maxcv) bypass counters
  and are not charged to the solver.
- Problem selection: s2mpj_select unions 5 hard-coded exclusions
  (DANWOODLS, MISRA1CLS, ROSSIMP1-3 — all dim 2, outside 6..50 for this
  S2MPJ version, verified in probinfo_matlab.csv). User problem_names are
  intersected with selector output. Load failures are silently dropped by
  benchmark -> our audit must detect any missing manifest problem.
- solver_isrand only affects run-count logic; OptiProfiler never touches
  solver RNGs. With explicit n_runs everywhere, the flag has no practical
  effect; recorded truthfully per solver.
- Load mode (benchmark.m:533-537, 964): solvers argument discarded with
  warning; solve loop guarded by ~is_load; no solver re-call is possible.
  Subset targets recomputed from selected solvers' saved merit histories
  (processResults.m:28-33). Profile tolerance set 10.^(-1:-1:-max_tol_order);
  threshold = f_min + tau*(f0 - f_min) with f_min over the loaded subset.
- Saved files per feature stamp dir: data_for_loading.mat (-v7.3,
  results_plibs), options_user.mat, options_refined.mat, curves.mat,
  profile_scores.mat, report.txt, log.txt, time_stamp_*.txt, README.txt,
  summary PDF + perf/data PDFs + detailed_profiles/ + history_plots/.
- Native figure options that exist in this version: line_colors,
  line_styles (fixed whitelist), line_widths, bar_colors,
  xlabel_/ylabel_* (latex, %s), semilogx, errorbar_type, hist_aggregation,
  draw_hist_plots, feature_stamp. No font/legend/marker options beyond
  these (font sizes hard-coded) — native fonts kept and stated.
- Load path is searched under pwd/benchmark_id -> replot scripts must cd to
  the result root (as C02 did).

## 5. Solver configurations (fixed; contract-tested before full run)

Common: budget 500*N, StepTolerance per the table, ftarget=-Inf, no solver
receives OptiProfiler accuracy targets; only FD-BFGS receives sigma (noise
level) on noisy features, as in C02.

1. bds / "BDS": production src/bds.m, Algorithm='cbds' (num_blocks=n,
   batch_size=n, 'sorted' cyclic), alpha_init='auto', expand=2, shrink=0.5,
   StepTolerance=1e-6, MaxFunctionEvaluations=500*n, ftarget=-Inf,
   is_noisy=false, forcing_function=@(alpha)alpha^2,
   reduction_factor=[0,eps,eps], polling_inner='opportunistic',
   cycling_inner=1, use_productive_direction_memory=true,
   use_iteration_pattern_step=true, use_momentum_extrapolation=true,
   use_function_value_stop=true, func_window_size=20 (W_f), func_tol=1e-6,
   use_estimated_gradient_stop=true, grad_window_size=1 (W_g),
   grad_tol=1e-2, lipschitz_constant=1e3 (L_H),
   use_gradient_reference_consistency=true,
   grad_reference_finite_difference_error_tol=1/30.
   Verified against current src (get_default_constant.m, bds.m): fv
   tolerances (1e-6,1e-3): 1e-6=func_tol option, 1e-3 hard-coded scale
   factor (bds.m:1045-1052); reference error tolerances (1e-3,1e-1)
   hard-coded (bds.m:1125-1128); retained-direction cap min(n,5) =
   option default productive_direction_memory_size; similarity 0.95
   hard-coded (admit_productive_direction_to_memory.m:36); extrapolation
   trials 2 / increment 2 hard-coded (try_productive_direction_extrapolation.m);
   pattern multipliers (1,2,4) hard-coded (run_post_poll_acceleration_phase.m:106);
   momentum_decay=0.6 option; "momentum tolerance 1e-6" is
   max(StepTolerance) (bds.m:608), not a separate constant.
2. bds-no-acceleration / "BDS without acceleration": identical to (1)
   except the three acceleration switches = false.
3. ds / "DS": identical to (2) except Algorithm='ds' (num_blocks=1).
4. nomad / "NOMAD": nomad_wrapper.m; params min_frame_size='* 0.000001',
   MAX_BB_EVAL=max_eval=num2str(500*n); bounds +/-inf; column-vector fun
   adapter. MEX + wrapper frozen with hashes.
5. lam / "LAM": paper-exact LAM ported from C02 846d5c5f
   (tests/competitors/lam.m SHA-256 15203df0..., lam_linesearch.m
   cb24e20d...), renamed lam_paper_exact to avoid overwriting current
   main's monotone-baseline lam.m. Options: MaxFunctionEvaluations=500*n,
   StepTolerance=1e-5, MaxIterations=Inf, ftarget=-Inf. Paper constants
   c=1e-10, theta=delta=0.5, gamma=1e-6, initial tentative steps 1.
   verify_lam_paper_exact (13 test classes) must pass on the server.
6. newuoa / "NEWUOA": prima_wrapper.m; rhobeg=1, rhoend=1e-6, maxfun=500*n,
   iprint=0.
7. fd-bfgs / "FD-BFGS": fminunc_budgeted_wrapper.m; quasi-newton BFGS,
   StepTolerance=1e-6, OptimalityTolerance=eps, MaxIterations=1e20,
   ObjectiveLimit=-Inf. Noiseless features: SpecifyObjectiveGradient=false
   (fminunc default FD rule, fminunc counts evaluations itself).
   Noisy features: wrapper FD gradient, h=sqrt(sigma*max(1,|f_tilde(x)|)),
   all n+1 calls per gradient budgeted via max_callbacks=floor(500n/(n+1));
   NaN gradient components -> 0, clipped to +/-1e10 (accepted C02 handling,
   kept unchanged).
8. pds / "PDS": tests/competitors/pds.m (Li-Zhang 2023 randomized PDS,
   standalone). As pds_500n_test: expand=2, shrink=0.5,
   MaxFunctionEvaluations=500*n. Remaining defaults (StepTolerance,
   forcing, polling) read from pds.m and recorded, not tuned. Randomness:
   pds.m accepts options.seed (existing legal interface; RandStream
   mt19937ar per run). Per-problem deterministic seed derived from x0
   (documented derivation); OptiProfiler's interface cannot pass per-run
   seeds to solver handles, so the PDS stream is fixed per problem across
   the 5 runs of a feature (runs still differ through the feature noise/Q).
   PDS on plain runs exactly once (n_runs=1).
9. bfo / "BFO": official BFO v2.0 (Porcelli-Toint) at
   /home/lhtian97/local/BFO + tests/competitors/bfo_wrapper.m:
   epsilon=1e-6 (StepTolerance), maxeval=500*n, verbosity='silent'.
   Randomness: BFO 'random-seed' option; default behavior and per-run
   control decision recorded after source inspection (Section 7 task T4).
10. nelder-mead / "Nelder-Mead": MATLAB fminsearch via
    fminsearch_wrapper.m: MaxFunEvals=500*n, MaxIter=1e20, TolFun=eps,
    TolX=1e-6. MATLAB release and resolved path recorded.

## 6. Features and seeds

Feature mapping (ported from profile_optiprofiler.m lines 57-129, to be
re-verified by contract test): plain -> feature_name 'plain', n_runs 1;
noisy_1e-k -> 'noisy', noise_level 1e-k, n_runs 5; linearly_transformed ->
'linearly_transformed' (rotated, condition_factor 0), n_runs 5;
linearly_transformed_noisy_1e-k -> 'linearly_transformed' + noise_level
1e-k, n_runs 5. feature_stamp set to the logical name for stable directory
identity. Base seed 20260828 for the full run; smoke runs may override the
seed only together with explicit problem_names (ported C02 guard).

## 7. Ordered tasks and acceptance

- [x] T1 Read instructions, audit local/GitHub/server, determine resources
  and dependencies (Sections 3-5 evidence).
- [x] T2 This execution record + fresh output root; old results preserved.
- [x] T3 Finalize options, LAM provenance, dependency freeze, three-way
  sync plan (recorded in Section 5 and Section 8).
- [x] T4 Port/integrate runner, wrappers, contract tests, budget boundary
  tests; run production regression suite + new verifiers on the server
  (BDS_REGRESSION_SUITE_OK, VERIFY_TSFSB_*_OK). Record PDS/BFO randomness
  decisions with evidence.
- [ ] T5 Freeze source; verify local main == GitHub main == fresh server
  clone (commit, tree, submodule, dirty state); SHA-256 of src/bds.m,
  options parser, runner, every wrapper, LAM/PDS/BFO key files; MATLAB
  which -all + worker path checks prove the frozen copies are used.
- [x] T6 Build full problem manifest on the server (metadata enumeration +
  selector enumeration + per-problem load check); assert no effective
  exclusions; confirm the 11 re-added instances; freeze manifest + SHA-256;
  record P and dimension distribution; explain any difference vs 133.
- [x] T7 Smoke: all 10 solvers on a small problem subset including the
  re-added GAUSS1LS instance (all other additions pass the full load check), features
  plain + noisy + linearly_transformed + combined; check N-block/single-
  block automatic initial steps, evaluation counting, failure paths,
  same-seed reproducibility and changed-seed sensitivity. Smoke data
  separate from full results.
- [x] T8 Save/reload native subset smoke from smoke data (solvers_to_load,
  exact-slice assertions, subset target recomputation sensitivity fixture,
  zero solver re-calls).
- [ ] T9 Full run: 10 features sequentially via restart-safe runner;
  per-feature acceptance (outcomes, budgets, problem set, solver order,
  run counts, non-finite classification, flag gate) before the next
  feature; screen + logs + exit status recorded.
- [ ] T10 Monitor to completion; then saved-data-only native replot: 5
  subsets ([1,2],[2,3],[1,4,5,8,9,10],[1,6,7],1:10) x 10 features x tau
  {1e-2,1e-4} x {history,output} = 200 combinations; subset target
  recomputation evidence incl. sensitivity fixture; no solver/objective
  re-calls; native figure hashes unchanged; total inventory.
- [ ] T11 Local handoff: SUMMARY.md + machine-checkable acceptance report +
  records/options/manifests/logs/checksums/recovery scripts in this
  directory; raw data remains on the server with explicit paths and
  verification procedure.

## 8. Three-way sync plan

1. Develop on local branch tsfsb_integration (new files under
   research/ten_solver_full_set_benchmark/ + renamed paper-exact LAM port +
   verifiers wired into run_bds_regression_suite where safe). No changes to
   src/bds.m or current production fixes; no overwrite of competitors/lam.m.
2. Push branch; create scratch server clone of the branch; run contract
   tests and smokes; iterate with ordinary commits.
3. When green: merge to main (no force-push; re-check origin/main first),
   push, create the FROZEN server clone at the merge commit, verify hashes.
4. Full run only from the frozen clone; no pulls during the run.

## 9. Server layout (to be created)

- Source (frozen, after T5): /home/lhtian97/Work/tsfsb_src_<commit>/
- Scratch (pre-freeze branch testing): /home/lhtian97/Work/tsfsb_scratch/
- Artifacts: /home/lhtian97/Work/tsfsb_artifacts/v01_full_<commit>_<date>/
  with evaluations/<feature>/, profiles/, manifests, logs.
- Reference bundle already at /home/lhtian97/Work/tsfsb_ref/.

## 10. Deviations and decisions log

- 2026-09-20: Task started. Local/GitHub at fbbe054; server dirty clone on
  rebuilt_code_style left untouched; fresh clones will be used instead.
- 2026-09-20: Metadata enumeration (probinfo_matlab.csv of frozen S2MPJ)
  gives P=133 with zero intersection with the selector's 5 built-in
  exclusions; all 11 previously excluded instances present. To be
  re-verified in MATLAB on the server (T6).
- 2026-09-20: BFO bfo.m carries a one-line local patch (function-existence
  probe). Frozen as-is; solver output is captured by OptiProfiler evalc so
  the patch's display side effect does not pollute logs. Decision on
  'random-seed' handling pending T4 source inspection.
- 2026-09-20: Paper-exact LAM will be ported under the name lam_paper_exact
  to avoid overwriting the current monotone-baseline competitors/lam.m;
  content provenance from C02 846d5c5f recorded by SHA-256.

(Records below are appended as tasks complete.)


## V32 接手补充（2026-09-20；此节优先于上面的初稿）

- 本轮先在 theory 的 revision_history/V32.md 写执行清单，再接手本目录；不重写已有 runner。
- 全库 metadata / selector / load 三重检查：133 个 unconstrained default-size 问题，6 <= N <= 50。
  不传 excludelist；selector 内置 exclusions 与 eligible metadata 交集为 0。
- 生产源码未修改。完整 run_bds_regression_suite 已在 R2026a 服务器通过，日志：
  /home/lhtian97/Work/tsfsb_artifacts/v32_preflight/regression.log。
- tsfsb_trace_solver 保存每次实际 solver-visible 调用的 point/value、已有 noise-free assessment、
  返回点、异常及真实调用计数，不增加 objective evaluation。verify_tsfsb_trace_solver 已通过。
  对试图超过 500N 的 solver，统一预算层拒绝额外 evaluation，并以已见函数值的最好点返回；
  budget_guard_used 单独记录，不能把 budget exhaustion 算成 solver failure。
- PDS/BFO 的 solver_isrand=true，其他为 false。每个 feature 的 n_runs 均显式指定。
  PDS 使用原接口 tsfsb_pds_seed(x0)，同一 x0 的内部流固定；BFO 固定其原默认 seed=0。
- noisy+rotation 通过原生 custom feature modifiers 组合，不给 linearly_transformed 传不支持的 noise_level。
- OptiProfiler 的噪声 stream 用 seed、f、x、evaluation index 派生，重复 point 也更新；
  不宣称跨 solver 在不同 point 得到相同 Z。保留 C02 的原生模型，不改 OptiProfiler。
- 正式问题 manifest 位于输出目录，TSFSB_PROBLEM_MANIFEST 指向它，避免污染冻结源码。
- screen 驱动在每个 feature 后核验数据和异常，再继续；未知异常停止，不缩减问题。
  只对 C02 已核实的 INDEF/FD-BFGS 的 6 个失败沿用分类，必须同时匹配本次异常 ID 和实际计数。
- 全部 features 完成后自动用 solvers_to_load 恢复 5 类子集，再生成最终数据 SHA-256 inventory。
  inventory 不包含持续追加的 logs 和 screen exit markers；这些日志仍完整保留。
- 只使用 OptiProfiler 原生生成图，不编辑 PDF，不拼接旧实验数据。
- 最终 source freeze、screen session、输出路径及启动验收在 V32.md 回填；成功启动不等于实验完成。

### V32 启动前验收结果

- 2026-09-20：BDS_REGRESSION_SUITE_OK、VERIFY_TSFSB_TRACE_SOLVER_OK、
  VERIFY_TSFSB_KNOWN_FAILURES_OK、VERIFY_TSFSB_SUBSET_TARGETS_OK、TSFSB_PREFLIGHT_SMOKE_OK。
- 四类 smoke：plain 为 ARWHEAD/GAUSS1LS；其余 noisy_1e-4、linearly_transformed、
  linearly_transformed_noisy_1e-4 为 ARWHEAD/BROWNAL；十 solver 全部参与，预算仍为 500N，
  stochastic features 各 5 runs。20 次 saved-data-only 子集恢复及 target 重算全部通过。
- 原 smoke 在 plain 验收后被主动中断，将后续 GAUSS1LS 换为 BROWNAL 以控制预检时间；
  原始日志和部分 smoke raw traces 保留。正式实验不作这一替换，仍含全部 133 个问题。
- 一次恢复验收因 JSON 列向量 / native 行向量表示差异误报 names mismatch，已修复；
  原实验数据不受影响，只重做该次 load/replot。旧日志 smoke_continued.log 保留。
- OptiProfiler 可选自动复制 caller script 功能有 warning；不用此功能保证复现，
  另存 Git source archive、完整 options、hashes。原生 performance PDFs 和 MAT 均已验收。
- 正式长算在 screen 启动，完整完成与最终验收由脚本接续。最终 launch 信息写入
  theory/bds_convergence/revision_history/V32.md 及本目录 testdata 下的本机交接包；
  T9–T11 不能仅因为成功启动就勾选为完成。
