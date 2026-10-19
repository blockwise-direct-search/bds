function verify_saved_results(outdir)
% Independent saved-data-only acceptance. Never evaluates an objective.
data=load(fullfile(outdir,'results.mat'));
assert(isequal(size(data.records),[10,2]));
assert(numel(unique(data.manifest.selected_names))==10);
stream=RandStream('mt19937ar','Seed',data.manifest.seed);
assert(isequal(randperm(stream,numel(data.manifest.candidate_names),10), ...
    data.manifest.selected_indices));
switches={'use_productive_direction_memory','use_iteration_pattern_step', ...
    'use_momentum_extrapolation'};
for p=1:10
    pair=data.records(p,:);
    assert(isequal(pair{1}.x0,pair{2}.x0));
    a=rmfield(pair{1}.options,[switches,{'forcing_function'}]);
    b=rmfield(pair{2}.options,[switches,{'forcing_function'}]);
    assert(isequaln(a,b));
    for s=1:2
        r=pair{s};
        assert(strcmp(r.problem,data.manifest.selected_names{p}));
        assert(r.n>=6 && r.n<=10);
        assert(r.options.use_function_value_stop && r.options.use_estimated_gradient_stop);
        for j=1:3, assert(r.options.(switches{j})==(s==1)); end
        assert(r.output.funcCount==r.evaluation_count && r.evaluation_count<=500*r.n);
        assert(numel(r.output.fhist)==r.evaluation_count);
        assert(isequaln(r.output.xhist,r.evaluation_x));
        assert(all(isfinite(r.evaluation_f)));
        assert(isequaln(r.output.fhist(:),r.evaluation_f(:)));
        assert(r.fopt==min(r.output.fhist));
        one=load(fullfile(outdir,sprintf('result_%02d_%d.mat',p,s)));
        assert(isequaln(rmfield(r,'options'),rmfield(one.rec,'options')));
    end
end
txt=fileread(fullfile(outdir,'run.log'));
assert(numel(regexp(txt,'BEGIN_RESULT problem='))==20);
assert(numel(regexp(txt,'END_RESULT problem='))==20);
assert(contains(txt,'ALL_20_RUNS_COMPLETE_AND_RELOADED'));
assert(height(readtable(fullfile(outdir,'summary.csv')))==20);
fprintf('SAVED_DATA_ONLY_PASS 10 problems, 20 runs, identical paired options except acceleration, budget/history/output/log checks.\n');
disp(data.summary);
end
