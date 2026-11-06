function run_block_visit_verification(stage)
%RUN_BLOCK_VISIT_VERIFICATION Isolated structural-refactor acceptance.
if nargin<1,stage='full';end
assert(ismember(stage,{'smoke','full'}));
root=getenv('BDS_VISIT_VERIFY_ROOT');assert(isfolder(root));
candidate=getenv('BDS_VISIT_CANDIDATE');
if isempty(candidate),candidate=fullfile(root,'candidate');end
results=getenv('BDS_VISIT_RESULTS');
if isempty(results),results=fullfile(root,'results');end
if ~isfolder(results),mkdir(results);end
addpath(fullfile(candidate,'src'),fullfile(candidate,'tests'), ...
    fullfile(candidate,'tests','tools'),fullfile(candidate,'tests','competitors'));
assert(strcmp(which('bds'),fullfile(candidate,'src','bds.m')));
diary(fullfile(results,[stage '_diary.log']));diary_cleanup=onCleanup(@()diary('off'));
analysis=checkcode(fullfile(candidate,'src','bds.m'),'-id');
save(fullfile(results,'code_analysis.mat'),'analysis');
addpath(fullfile(root,'baseline','src'));
addpath(fullfile(candidate,'src'));
assert(strcmp(which('bds'),fullfile(candidate,'src','bds.m')));
verify_bds_visit_schedule(@bds_before_visit_refactor);
verify_bds_visit_schedule();
if strcmp(stage,'smoke')
    fprintf('BLOCK_VISIT_SMOKE_OK\n');return;
end
op='/home/lhtian97/Work/c15_stopping_20261105/bundle/optiprofiler/matlab/optiprofiler';
addpath(op,fullfile(op,'src'),fullfile(op,'problem_libs'), ...
    fullfile(op,'problem_libs','s2mpj'));
pool=parpool('Processes',4);pool_cleanup=onCleanup(@()delete(pool));
run_bds_regression_suite();
matrix=verify_bds_visit_refactor(fullfile(root,'baseline','src'),results);
assert(matrix.passed==3108 && matrix.failed==0);
legacy='/home/lhtian97/Work/bds_rolling_verify_20261106_7sjnya/references';
verify_bds_rolling_reference(legacy,results,'fixtures');
verify_bds_rolling_saved_traces('/home/lhtian97/Work/c15_stopping_20261105', ...
    '/home/lhtian97/Work/c13_rolling_external_20261104',results,'full-plain');
verify_bds_rolling_saved_traces('/home/lhtian97/Work/c15_stopping_20261105', ...
    '/home/lhtian97/Work/c13_rolling_external_20261104',results,'sample');
compact=verify_bds_compact_thesis(fullfile(root,'reference','bds_compact_thesis.m'), ...
    '/home/lhtian97/Work/c10_nan_matched_20261102',fullfile(results,'compact'));
assert(compact.external_equal==160 && compact.continuing_states_equal==160 ...
    && compact.instrumentation_equal==160 && compact.terminal_state_equal==135);
audit=summarize_compact_parity(fullfile(results,'compact'));
assert(audit.only_unused_final_base && numel(audit.terminal_differences)==25);
prior=load('/home/lhtian97/Work/bds_compact_verify_20261106_CZW0cl/attempt2/terminal_audit.mat');
assert(isequaln(audit.terminal_differences,prior.audit.terminal_differences), ...
    'Terminal states changed relative to the earlier compact audit.');
f=load(fullfile(results,'fixtures_summary.mat'));assert(f.summary.passed==251);
p=load(fullfile(results,'full_plain_replay_summary.mat'));assert(p.summary.passed==532);
s=load(fullfile(results,'saved_replay_summary.mat'));assert(s.summary.passed==288);
acceptance=struct('status','passed','baseline','37e80376','candidate',candidate, ...
    'matrix_cases',matrix.passed,'plain_replays',p.summary.passed, ...
    'sample_replays',s.summary.passed,'compact_cases',compact.cases, ...
    'documented_compact_terminal_differences',25,'matlab',version);
save(fullfile(results,'ACCEPTED.mat'),'acceptance');
fprintf('BLOCK_VISIT_ACCEPTANCE_PASSED\n');
end
