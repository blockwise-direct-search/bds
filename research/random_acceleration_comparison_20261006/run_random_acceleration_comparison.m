function run_random_acceleration_comparison(source_root, dependency_root, outdir)
% Reproducible 10-problem comparison using identical production BDS code.
assert(~exist(fullfile(outdir, 'results.mat'), 'file'), 'Results already exist.');
if ~exist(outdir, 'dir'), mkdir(outdir); end
addpath(fullfile(source_root, 'src'));
addpath(fullfile(source_root, 'research', 'ten_solver_full_set_benchmark'));
libdir = fullfile(dependency_root, 'matlab', 'optiprofiler', 'problem_libs');
addpath(fullfile(dependency_root, 'matlab', 'optiprofiler', 'src'));
addpath(libdir, fullfile(libdir, 's2mpj'));
assert(strcmp(which('bds'), fullfile(source_root, 'src', 'bds.m')));
diary(fullfile(outdir, 'run.log'));
diary_cleanup = onCleanup(@() diary('off'));
format long g
seed = 20261006;
selector_options = struct('ptype', 'u', 'mindim', 6, 'maxdim', 10, ...
    'excludelist', {{}});
[candidate_names, ~] = s2mpj_select(selector_options);
candidate_names = sort(candidate_names(:));
meta = load(fullfile(libdir, 's2mpj', 'probinfo_matlab.mat'), 'probinfo');
metadata_names = {};
for k = 2:size(meta.probinfo, 1)
    if strcmp(meta.probinfo{k,2}, 'u') && meta.probinfo{k,4} >= 6 ...
            && meta.probinfo{k,4} <= 10
        metadata_names{end+1,1} = char(meta.probinfo{k,1}); %#ok<AGROW>
    end
end
assert(isequal(sort(metadata_names), candidate_names), 'Selector excludes eligible problems.');
stream = RandStream('mt19937ar', 'Seed', seed);
selected_indices = randperm(stream, numel(candidate_names), 10);
selected_names = candidate_names(selected_indices);
manifest = struct('seed', seed, 'generator', 'mt19937ar', ...
    'candidate_names', {candidate_names}, 'selected_indices', selected_indices, ...
    'selected_names', {selected_names}, 'selector_options', selector_options, ...
    'matlab_version', version, 'source_root', source_root, ...
    'bds_entry', which('bds'), 's2mpj_entry', which('s2mpj_load'));
print_full('manifest', manifest);
save(fullfile(outdir, 'manifest.mat'), 'manifest');
records = cell(10,2);
rows = cell(20,9);
current_problem = []; evaluation_count = 0; evaluation_x = []; evaluation_f = [];
switches = {'use_productive_direction_memory', 'use_iteration_pattern_step', ...
    'use_momentum_extrapolation'};
for pidx = 1:10
    name = selected_names{pidx};
    initial_problem = s2mpj_load(name);
    x0 = initial_problem.x0(:); n = numel(x0);
    assert(n >= 6 && n <= 10 && strcmp(initial_problem.ptype, 'u') ...
        && initial_problem.mb == 0 && initial_problem.mcon == 0);
    opts = cell(1,2);
    keys = {'bds','bds-without-acceleration'};
    names = {'BDS','BDS without acceleration'};
    for sidx = 1:2
        opts{sidx} = tsfsb_benchmark_options(x0, keys{sidx});
        opts{sidx}.seed = seed;
        opts{sidx}.productive_direction_memory_size = max(1,min(n,5));
        opts{sidx}.momentum_decay = 0.6;
        opts{sidx}.direction_set = eye(n);
        opts{sidx}.output_xhist = true;
        opts{sidx}.output_alpha_hist = true;
        opts{sidx}.output_block_hist = true;
        opts{sidx}.output_grad_hist = true;
        opts{sidx}.iprint = 0;
        opts{sidx}.debug_flag = false;
    end
    a = rmfield(opts{1}, [switches, {'forcing_function'}]);
    b = rmfield(opts{2}, [switches, {'forcing_function'}]);
    assert(isequaln(a,b));
    assert(strcmp(func2str(opts{1}.forcing_function),func2str(opts{2}.forcing_function)));
    for sidx = 1:2
        current_problem = s2mpj_load(name);
        assert(isequal(current_problem.x0(:),x0));
        evaluation_count = 0;
        evaluation_x = zeros(n,500*n); evaluation_f = nan(1,500*n);
        options = opts{sidx};
        rng(seed, 'twister');
        fprintf('\nBEGIN_RESULT problem=%s n=%d solver=%s\n',name,n,names{sidx});
        print_full('options',options);
        timer = tic;
        try
            [xopt,fopt,exitflag,output] = bds(@counted_objective,x0,options);
        catch err
            error_report = getReport(err,'extended','hyperlinks','off');
            save(fullfile(outdir,sprintf('failure_%02d_%d.mat',pidx,sidx)), ...
                'name','options','evaluation_count','error_report');
            fprintf('%s\n',error_report); rethrow(err);
        end
        elapsed = toc(timer);
        assert(evaluation_count == output.funcCount && evaluation_count <= 500*n);
        assert(numel(output.fhist)==evaluation_count);
        assert(size(output.xhist,2)==evaluation_count);
        assert(isequaln(output.xhist,evaluation_x(:,1:evaluation_count)));
        assert(isfinite(fopt) && fopt == min(output.fhist));
        best_index = find(output.fhist == fopt);
        assert(any(all(output.xhist(:,best_index) == xopt(:),1)));
        rec = struct('problem',name,'n',n,'solver',names{sidx},'seed',seed, ...
            'x0',x0,'f0',evaluation_f(1),'options',options,'xopt',xopt, ...
            'fopt',fopt,'exitflag',exitflag,'output',output,'elapsed_seconds',elapsed, ...
            'evaluation_count',evaluation_count, ...
            'evaluation_x',evaluation_x(:,1:evaluation_count), ...
            'evaluation_f',evaluation_f(1:evaluation_count));
        print_full('result',rec);
        fprintf('END_RESULT problem=%s solver=%s\n',name,names{sidx});
        records{pidx,sidx} = rec;
        save(fullfile(outdir,sprintf('result_%02d_%d.mat',pidx,sidx)),'rec','-v7.3');
        rows{2*pidx+sidx-2,1}=name; rows{2*pidx+sidx-2,2}=n;
        rows(2*pidx+sidx-2,3:9)={names{sidx},rec.f0,fopt,output.funcCount, ...
            exitflag,char(output.message),elapsed};
        save(fullfile(outdir,'checkpoint.mat'),'manifest','records','rows','-v7.3');
    end
end
summary = cell2table(rows,'VariableNames', ...
    {'problem','n','solver','f0','fopt','funcCount','exitflag','message','seconds'});
writetable(summary,fullfile(outdir,'summary.csv'));
save(fullfile(outdir,'results.mat'),'manifest','records','summary','-v7.3');
loaded = load(fullfile(outdir,'results.mat'));
assert(all(~cellfun(@isempty,loaded.records),'all'));
assert(height(loaded.summary)==20 && numel(unique(loaded.summary.problem))==10);
fprintf('\nSUMMARY\n'); disp(summary);
fprintf('ALL_20_RUNS_COMPLETE_AND_RELOADED\n');
clear diary_cleanup

    function f = counted_objective(x)
        evaluation_count = evaluation_count+1;
        assert(evaluation_count <= 500*numel(x0),'External budget exceeded.');
        evaluation_x(:,evaluation_count)=x(:);
        f=current_problem.fun(x);
        evaluation_f(evaluation_count)=f;
    end
end

function print_full(label,value)
% No shortened MATLAB struct display: numeric arrays are printed in full.
if isstruct(value)
    fields=fieldnames(value);
    for i=1:numel(value)
        for j=1:numel(fields)
            print_full(sprintf('%s(%d).%s',label,i,fields{j}),value(i).(fields{j}));
        end
    end
elseif iscell(value)
    fprintf('%s cell_size=%s\n',label,mat2str(size(value)));
    for i=1:numel(value), print_full(sprintf('%s{%d}',label,i),value{i}); end
elseif isnumeric(value) || islogical(value)
    fprintf('%s size=%s value=%s\n',label,mat2str(size(value)),mat2str(value,17));
elseif isa(value,'function_handle')
    fprintf('%s function=%s\n',label,func2str(value));
else
    fprintf('%s=%s\n',label,char(string(value)));
end
end
