function run_rolling_verification(stage)
%RUN_ROLLING_VERIFICATION Isolated server acceptance entry, never a benchmark.
% STAGE='supplement' runs regression/replay while the manifest is computing.
% STAGE='final' requires fixture and complete-plain coverage (fresh evaluations
% or saved trajectories), plus the six-feature replay and maintained tests.
if nargin<1,stage='all';end
assert(ismember(stage,{'all','final','supplement'}));
root=getenv('BDS_ROLLING_VERIFY_ROOT');assert(isfolder(root));
candidate=getenv('BDS_ROLLING_CANDIDATE_DIR');
if isempty(candidate),candidate=fullfile(root,'candidate');end
results=fullfile(root,'results');
addpath(fullfile(candidate,'src'),fullfile(candidate,'tests'));
assert(strcmp(which('bds'),fullfile(candidate,'src','bds.m')));
diary(fullfile(results,['matlab_' stage '_diary.log']));
cleanup=onCleanup(@()diary('off'));
reference_root=fullfile(root,'references');
op='/home/lhtian97/Work/c15_stopping_20261105/bundle/optiprofiler/matlab/optiprofiler';
addpath(op,fullfile(op,'src'),fullfile(op,'problem_libs'), ...
    fullfile(op,'problem_libs','s2mpj'));
% Existing regression fixtures also use the maintained competitor interfaces.
addpath(fullfile(candidate,'tests','competitors'));
reuse=false;
if strcmp(stage,'final') && isfile(fullfile(results,'SUPPLEMENT_PASSED.mat'))
    s=load(fullfile(results,'SUPPLEMENT_PASSED.mat'));
    assert(strcmp(s.acceptance.candidate,candidate));
    reuse=true;
end
if ~reuse
    workers=8;
    if strcmp(stage,'supplement'),workers=2;end
    pool=parpool('Processes',workers); pool_cleanup=onCleanup(@()delete(pool));
end
if strcmp(stage,'all')
    verify_bds_rolling_reference(reference_root,results,'fixtures');
elseif strcmp(stage,'final')
    f=load(fullfile(results,'fixtures_summary.mat'));
    if isfile(fullfile(results,'full_plain_replay_summary.mat'))
        m=load(fullfile(results,'full_plain_replay_summary.mat'));
        plain_evidence='all saved C13/C15 plain trajectories';
    else
        m=load(fullfile(results,'manifest_summary.mat'));
        plain_evidence='fresh frozen-reference comparisons';
    end
    assert(f.summary.failed==0 && f.summary.passed==251 ...
        && m.summary.failed==0 && m.summary.passed==532);
end
if ~reuse,run_bds_regression_suite();end
if strcmp(stage,'all')
    verify_bds_rolling_reference(reference_root,results,'manifest');
end
if ~reuse
    verify_bds_rolling_saved_traces('/home/lhtian97/Work/c15_stopping_20261105', ...
        '/home/lhtian97/Work/c13_rolling_external_20261104',results);
end
sample=load(fullfile(results,'saved_replay_summary.mat'));
assert(sample.summary.passed==288 && sample.summary.failed==0);
files={fullfile(candidate,'src','bds.m'), ...
    fullfile(candidate,'src','private','initialize_rolling_acceleration.m'), ...
    fullfile(candidate,'src','private','run_rolling_acceleration.m'), ...
    fullfile(candidate,'src','private','finish_rolling_bootstrap.m'), ...
    fullfile(candidate,'tests','verify_bds_rolling_reference.m'), ...
    fullfile(candidate,'tests','verify_bds_rolling_saved_traces.m'), ...
    fullfile(candidate,'tests','verify_bds_rolling_switches.m')};
analysis=cell(size(files));
for j=1:numel(files),analysis{j}=checkcode(files{j},'-id');end
save(fullfile(results,'code_analyzer.mat'),'files','analysis');
acceptance=struct('status','passed','matlab_version',version, ...
    'stage',stage,'candidate',candidate,'completed_at',datestr(now,30));
if strcmp(stage,'final'),acceptance.plain_evidence=plain_evidence;end
if strcmp(stage,'supplement')
    save(fullfile(results,'SUPPLEMENT_PASSED.mat'),'acceptance');
    fprintf('ROLLING_SUPPLEMENT_PASSED\n');
else
    save(fullfile(results,'ACCEPTED.mat'),'acceptance');
    fprintf('ROLLING_ACCEPTANCE_PASSED\n');
end
end
