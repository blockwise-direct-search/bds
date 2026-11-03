function threshold_experiment(stage)
%THRESHOLD_EXPERIMENT Compare only the final gradient stopping predicate.
%
%   stage                              'unit', 'preflight', 'seed1', 'seed2', or 'report'.
%   BDS_THRESHOLD_ROOT                 Environment variable naming the isolated workspace.
%
%   All six configurations are actual solver runs. During each case the
%   complete call sequences are checked against the both-off trajectory.
%   Only the true-value baseline history and compact outcomes are saved.

root = getenv('BDS_THRESHOLD_ROOT');
assert(isfolder(root));
bundle = '/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8';
opti = fullfile(bundle, 'optiprofiler', 'matlab', 'optiprofiler');
addpath(opti, fullfile(opti, 'src'), fullfile(opti, 'problem_libs'), ...
    fullfile(opti, 'problem_libs', 's2mpj'), fullfile(bundle, 'helpers'), ...
    fullfile(bundle, 'control'), fullfile(root, 'candidate', 'examples'), ...
    fullfile(root, 'candidate', 'src'), fullfile(root, 'control'));
assert(strcmp(which('bds'), fullfile(root, 'candidate', 'src', 'bds.m')));
assert(strcmp(which('bds_dual_threshold'), fullfile(root, 'candidate', 'src', 'bds_dual_threshold.m')));
assert(strcmp(version('-release'), '2026a'));
if strcmp(stage, 'unit')
    threshold_unit_test(root);
    return
elseif strcmp(stage, 'report')
    first = jsondecode(fileread(fullfile(root, 'seed1', 'SUMMARY.json')));
    second = jsondecode(fileread(fullfile(root, 'seed2', 'SUMMARY.json')));
    report = struct('status', 'completed', 'seed1', first, 'seed2', second, ...
        'gradient_qualified', first.gradient_qualified && second.gradient_qualified, ...
        'joint_qualified', first.joint_qualified && second.joint_qualified, ...
        'interpretation', 'Actual paired runs; completed does not imply qualified. No production change.');
    write_json(fullfile(root, 'SUMMARY.json'), report);
    fprintf('THRESHOLD_REPORT_OK gradient=%d joint=%d\n', report.gradient_qualified, report.joint_qualified);
    return
end

assert(ismember(stage, {'preflight', 'seed1', 'seed2'}));
seed_base = 20260828;
if strcmp(stage, 'seed2'), seed_base = 20261030; end
manifest = jsondecode(fileread(fullfile(root, 'problem_manifest.json')));
names = cellstr(manifest.problem_names);
assert(numel(names) == 133);
features = {'plain', 'noisy_1e-4', 'noisy_1e-2', 'linearly_transformed', ...
    'linearly_transformed_noisy_1e-4', 'linearly_transformed_noisy_1e-2'};
tasks = struct('problem', {}, 'problem_index', {}, 'feature', {}, ...
    'feature_index', {}, 'repeat', {}, 'seed_base', {});
for f = 1:numel(features)
    repeats = 5;
    if f == 1, repeats = 1; end
    for p = 1:numel(names)
        for r = 1:repeats
            tasks(end+1) = struct('problem', names{p}, 'problem_index', p, ...
                'feature', features{f}, 'feature_index', f, 'repeat', r, 'seed_base', seed_base);
        end
    end
end
assert(numel(tasks) == 3458);
if strcmp(stage, 'preflight')
    tasks = tasks(ismember({tasks.problem}, {'ARGLINB', 'ARWHEAD', 'BIGGS6', 'GAUSS1LS'}) ...
        & [tasks.repeat] == 1);
    assert(numel(tasks) == 24);
    current = bds_paper_options([1;2;3], 'external', 'mp');
    frozen = c04_options_record([1;2;3], 'bds-mp-noret');
    frozen = rmfield(frozen, {'use_productive_direction_memory', 'productive_direction_memory_size'});
    assert(strcmp(func2str(current.forcing_function), func2str(frozen.forcing_function)));
    assert(isequaln(rmfield(current, 'forcing_function'), rmfield(frozen, 'forcing_function')));
end
folder = fullfile(root, stage);
assert(~isfolder(folder), 'ThresholdExperiment:ExistingStage', 'Stage already exists: %s', folder);
mkdir(folder);
cluster = parcluster('local');
cluster.JobStorageLocation = fullfile(root, 'parallel_jobs');
pool = gcp('nocreate');
if isempty(pool), parpool(cluster, min(30, numel(tasks))); end
parfor i = 1:numel(tasks)
    result = paired_case(tasks(i));
    file = fullfile(folder, sprintf('f%d_p%03d_r%d.mat', ...
        tasks(i).feature_index, tasks(i).problem_index, tasks(i).repeat));
    save_result(file, result);
end
summary = summarize(folder, tasks, features);
if strcmp(stage, 'preflight')
    assert(summary.gradient_exit_counts(3) > 0 && summary.gradient_exit_counts(4) > 0, ...
        'ThresholdExperiment:NoGradientStop', 'Both old and new criteria must actually trigger.');
    assert(summary.early_stop_counts(3) > 0 && summary.early_stop_counts(4) > 0);
end
write_json(fullfile(folder, 'SUMMARY.json'), summary);
fprintf('THRESHOLD_STAGE_OK %s cases=%d actual_runs=%d\n', stage, numel(tasks), 6*numel(tasks));
end

function result = paired_case(task)
% B, F, G_old, G_new, FG_old, FG_new. No option tuning between runs.
labels = {'B', 'F', 'G_old', 'G_new', 'FG_old', 'FG_new'};
function_flags = [false, true, false, false, true, true];
gradient_flags = [false, false, true, true, true, true];
dual_flags = [false, false, false, true, false, true];
result = struct('task', task, 'labels', {labels});
for j = 1:6
    trace = run_case(task, function_flags(j), gradient_flags(j), dual_flags(j));
    if j == 1
        baseline = trace;
        result.baseline_truth = baseline.truth;
        result.initial_value = baseline.initial_value;
        result.options = baseline.options;
        result.options.forcing_function = func2str(result.options.forcing_function);
        result.feature_seed = baseline.feature_seed;
    else
        assert(trace.calls <= baseline.calls);
        assert(isequaln(trace.points, baseline.points(:, 1:trace.calls)));
        assert(isequaln(trace.values, baseline.values(1:trace.calls)));
        assert(isequaln(trace.truth, baseline.truth(1:trace.calls)));
    end
    outcome = struct('calls', trace.calls, 'exitflag', trace.flag, 'xopt', trace.x, ...
        'fopt', trace.f, 'output_index', trace.output_index, ...
        'returned_truth', trace.truth(trace.output_index), 'seconds', trace.seconds, ...
        'message', trace.output.message, 'function_stop', function_flags(j), ...
        'gradient_stop', gradient_flags(j), 'dual_threshold', dual_flags(j));
    result.outcomes(j) = outcome;
end
assert(result.outcomes(4).calls >= result.outcomes(3).calls);
assert(result.outcomes(6).calls >= result.outcomes(5).calls);
assert(result.outcomes(6).calls <= result.outcomes(2).calls);
result.all_prefixes_and_counts_verified = true;
end

function trace = run_case(task, function_stop, gradient_stop, dual)
problem = s2mpj_load(task.problem);
assert(problem.n >= 6 && problem.n <= 50);
record = struct('name', task.feature, 'n_runs', 5);
if strcmp(task.feature, 'plain'), record.n_runs = 1; end
feature_options = tsfsb_feature_options(record);
feature = Feature(feature_options.feature_name, rmfield(feature_options, {'feature_name', 'feature_stamp'}));
seed = mod(23333*task.seed_base + 211*task.repeat, 2^32);
budget = 500*problem.n;
featured = FeaturedProblem(problem, feature, budget, seed);
options = bds_paper_options(featured.x0, 'external', 'mp');
options.seed = task.seed_base;
options.use_function_value_stop = function_stop;
options.use_estimated_gradient_stop = gradient_stop;
assert(options.grad_tol == 1e-2 && options.grad_window_size == 1 && options.lipschitz_constant == 1e3);
points = nan(problem.n, budget);
values = nan(1, budget);
count = 0;
rng(task.seed_base, 'twister');
started = tic;
fprintf('CASE_START %s %s r=%d function=%d gradient=%d dual=%d\n', ...
    task.feature, task.problem, task.repeat, function_stop, gradient_stop, dual);
solver = @bds;
if dual, solver = @bds_dual_threshold; end
[x, f, flag, output] = solver(@objective, featured.x0, options);
elapsed = toc(started);
assert(count == output.funcCount && count == featured.n_eval_fun && count <= budget);
matches = find(all(points(:, 1:count) == x(:), 1));
assert(~isempty(matches));
trace = struct('calls', count, 'points', points(:, 1:count), 'values', values(1:count), ...
    'truth', featured.fun_hist, 'initial_value', featured.fun_init, 'feature_seed', seed, ...
    'options', options, 'x', x, 'f', f, 'flag', flag, 'output', output, ...
    'output_index', matches(end), 'seconds', elapsed);
assert(numel(trace.truth) == count && isfinite(trace.initial_value));
    function value = objective(point)
        count = count + 1;
        assert(count <= budget);
        points(:, count) = point(:);
        value = featured.fun(point);
        values(count) = value;
    end
end

function summary = summarize(folder, tasks, features)
count = numel(tasks);
taus = [1e-2, 1e-3, 1e-4];
best = inf(6, 133);
for i = 1:count
    file = fullfile(folder, sprintf('f%d_p%03d_r%d.mat', ...
        tasks(i).feature_index, tasks(i).problem_index, tasks(i).repeat));
    data = load(file, 'result');
    result = data.result;
    f = tasks(i).feature_index;
    p = tasks(i).problem_index;
    best(f,p) = min(best(f,p), min(result.baseline_truth, [], 'omitnan'));
end
calls = zeros(count, 6);
flags = zeros(count, 6);
success = false(count, 6, 3, 2);
details = cell(count, 1);
for i = 1:count
    file = fullfile(folder, sprintf('f%d_p%03d_r%d.mat', ...
        tasks(i).feature_index, tasks(i).problem_index, tasks(i).repeat));
    data = load(file, 'result');
    result = data.result;
    assert(result.all_prefixes_and_counts_verified);
    b = best(tasks(i).feature_index, tasks(i).problem_index);
    target = b + taus*(result.initial_value-b);
    prefix = cummin(result.baseline_truth);
    for j = 1:6
        calls(i,j) = result.outcomes(j).calls;
        flags(i,j) = result.outcomes(j).exitflag;
        success(i,j,:,1) = reshape(prefix(calls(i,j)) <= target, 1,1,3);
        success(i,j,:,2) = reshape(result.outcomes(j).returned_truth <= target, 1,1,3);
    end
    details{i} = struct('task', tasks(i), 'targets', target, 'calls', calls(i,:), ...
        'history_success', squeeze(success(i,:,:,1)), 'output_success', squeeze(success(i,:,:,2)));
end
losses = success(:,1,:,:) & ~success;
summary = struct('status', 'completed', 'cases', count, 'actual_solver_runs', 6*count, ...
    'seed_base', tasks(1).seed_base, 'labels', {result.labels}, 'taus', taus, ...
    'columns', {{'history', 'output'}}, 'total_evaluations', sum(calls,1), ...
    'savings_vs_both_off', 1-sum(calls,1)/sum(calls(:,1)), ...
    'gradient_exit_counts', sum(flags == 5,1), 'early_stop_counts', sum(calls < calls(:,1),1), ...
    'losses_vs_both_off', squeeze(sum(losses,1)), ...
    'gradient_qualified', ~any(losses(:,4,:,:), 'all'), ...
    'joint_qualified', ~any(losses(:,6,:,:), 'all'), ...
    'joint_added_loss_vs_function_only', squeeze(sum(success(:,2,:,:) & ~success(:,6,:,:),1)), ...
    'joint_added_loss_vs_old_joint', squeeze(sum(success(:,5,:,:) & ~success(:,6,:,:),1)), ...
    'gradient_added_loss_vs_old_gradient', squeeze(sum(success(:,3,:,:) & ~success(:,4,:,:),1)));
for f = 1:6
    rows = [tasks.feature_index] == f;
    summary.features(f) = struct('name', features{f}, 'cases', sum(rows), ...
        'total_evaluations', sum(calls(rows,:),1), ...
        'savings_vs_both_off', 1-sum(calls(rows,:),1)/sum(calls(rows,1)), ...
        'losses_vs_both_off', squeeze(sum(losses(rows,:,:,:),1)));
end
% The per-case success masks preserve exact failure sets, not merely counts.
write_json(fullfile(folder, 'CASE_ASSESSMENTS.json'), details);
end

function save_result(file, result)
assert(~isfile(file));
temporary = [tempname(fileparts(file)), '.mat'];
save(temporary, 'result', '-v7');
movefile(temporary, file);
fprintf('CASE_SAVED %s\n', file);
end

function write_json(file, value)
fid = fopen(file, 'w');
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(value, 'PrettyPrint', true));
end
