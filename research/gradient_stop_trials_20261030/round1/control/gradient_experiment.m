function gradient_experiment(stage)
%GRADIENT_EXPERIMENT Execute one auditable stage of the isolated experiment.

root = getenv('BDS_GRADIENT_ROOT');
assert(isfolder(root));
bundle = '/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8';
opti = fullfile(bundle, 'optiprofiler', 'matlab', 'optiprofiler');
addpath(opti, fullfile(opti, 'src'), fullfile(opti, 'problem_libs'), ...
    fullfile(opti, 'problem_libs', 's2mpj'), fullfile(bundle, 'helpers'), ...
    fullfile(bundle, 'control'), fullfile(root, 'candidate', 'examples'), ...
    fullfile(root, 'candidate', 'src'), fullfile(root, 'experiment'), fullfile(root, 'control'));
assert(strcmp(which('bds'), fullfile(root, 'candidate', 'src', 'bds.m')));
assert(strcmp(version('-release'), '2026a'));
manifest = jsondecode(fileread(fullfile(root, 'problem_manifest.json')));
names = cellstr(manifest.problem_names);
assert(numel(names) == 133);
features = {'plain', 'noisy_1e-4', 'noisy_1e-2', 'linearly_transformed', ...
    'linearly_transformed_noisy_1e-4', 'linearly_transformed_noisy_1e-2'};
tasks = struct('problem', {}, 'problem_index', {}, 'feature', {}, 'feature_index', {}, 'repeat', {});
for f = 1:numel(features)
    repeats = 5;
    if f == 1, repeats = 1; end
    for p = 1:numel(names)
        for r = 1:repeats
            tasks(end+1) = struct('problem', names{p}, 'problem_index', p, ...
                'feature', features{f}, 'feature_index', f, 'repeat', r);
        end
    end
end
assert(numel(tasks) == 3458);
configs = gradient_experiment_config();
stage_root = fullfile(root, stage);
if ~isfolder(stage_root), mkdir(stage_root); end
if startsWith(stage, 'preflight')
    gradient_experiment_unit_test();
    % Audit all non-retained explicit paper options against the accepted runner.
    current = bds_paper_options([1; 2; 3], 'external', 'mp');
    frozen = c04_options_record([1; 2; 3], 'bds-mp-noret');
    frozen = rmfield(frozen, {'use_productive_direction_memory', 'productive_direction_memory_size'});
    assert(strcmp(func2str(current.forcing_function), func2str(frozen.forcing_function)));
    assert(isequaln(rmfield(current, 'forcing_function'), rmfield(frozen, 'forcing_function')));
    smoke = tasks(ismember([tasks.problem_index], [1, 3, 5]));
    start_pool(root, 12);
    parfor i = 1:numel(smoke)
        test_case(smoke(i), configs, stage_root);
    end
    write_json(fullfile(root, 'PREFLIGHT_ACCEPTED.json'), ...
        struct('status', 'accepted', 'stage', stage, 'cases', numel(smoke), 'real_runs_per_case', 13, ...
        'features', {features}, 'production_unchanged', true));
elseif strcmp(stage, 'pipeline_smoke')
    % Exercise selection and the selected real reruns before the long job.
    smoke = tasks(ismember([tasks.problem_index], [1, 3, 5]) & [tasks.repeat] == 1);
    preflight = jsondecode(fileread(fullfile(root, 'PREFLIGHT_ACCEPTED.json')));
    mkdir(fullfile(stage_root, 'baseline'));
    mkdir(fullfile(stage_root, 'selection'));
    mkdir(fullfile(stage_root, 'validation'));
    for i = 1:numel(smoke)
        loaded = load(task_file(fullfile(root, preflight.stage), smoke(i)), 'result');
        save_trace(task_file(fullfile(stage_root, 'baseline'), smoke(i)), loaded.result.baseline);
    end
    select_config(stage_root, smoke, configs);
    selection = load(fullfile(stage_root, 'selection', 'selection.mat'));
    start_pool(root, 6);
    early_stops = false(1, numel(smoke));
    parfor i = 1:numel(smoke)
        loaded = load(task_file(fullfile(stage_root, 'baseline'), smoke(i)), 'trace');
        baseline = loaded.trace;
        actual = gradient_experiment_case(smoke(i), configs(1), true, false, false);
        check_prediction(baseline, actual, function_prediction(baseline));
        result = struct('function_only', actual);
        % A permissive new candidate must also exercise an actual early stop,
        % not merely agree with a replay that always exhausts the baseline.
        for function_stop = [false, true]
            actual = gradient_experiment_case(smoke(i), configs(29), function_stop, true, false);
            check_prediction(baseline, actual, ...
                gradient_experiment_replay(baseline, configs(29), function_stop));
            if ~function_stop
                early_stops(i) = actual.calls < baseline.calls;
            end
        end
        if selection.selected > 0
            for function_stop = [false, true]
                actual = gradient_experiment_case(smoke(i), configs(selection.selected), ...
                    function_stop, true, false);
                check_prediction(baseline, actual, ...
                    gradient_experiment_replay(baseline, configs(selection.selected), function_stop));
            end
            result.selected = selection.selected;
        end
        save_result(task_file(fullfile(stage_root, 'validation'), smoke(i)), result);
    end
    assert(any(early_stops), 'GradientExperiment:NoNewEarlyStopExercised');
    write_json(fullfile(root, 'PIPELINE_SMOKE_ACCEPTED.json'), ...
        struct('status', 'accepted', 'cases', numel(smoke), 'selected', selection.selected, ...
        'new_rule_early_stops_exercised', sum(early_stops)));
elseif strcmp(stage, 'baseline')
    start_pool(root, 30);
    parfor i = 1:numel(tasks)
        file = task_file(stage_root, tasks(i));
        if ~isfile(file)
            trace = gradient_experiment_case(tasks(i), configs(1), false, false, false);
            save_trace(file, trace);
        end
    end
    assert(numel(dir(fullfile(stage_root, '*.mat'))) == numel(tasks));
    write_json(fullfile(stage_root, 'ACCEPTED.json'), struct('status', 'accepted', ...
        'cases', numel(tasks), 'features', {features}, 'budget_factor', 500));
elseif strcmp(stage, 'selection')
    select_config(root, tasks, configs);
elseif strcmp(stage, 'validation')
    selection = load(fullfile(root, 'selection', 'selection.mat'));
    selected = selection.selected;
    start_pool(root, 30);
    parfor i = 1:numel(tasks)
        file = task_file(stage_root, tasks(i));
        if ~isfile(file)
            loaded = load(task_file(fullfile(root, 'baseline'), tasks(i)), 'trace');
            baseline = loaded.trace;
            function_only = gradient_experiment_case(tasks(i), configs(1), true, false, false);
            expected = function_prediction(baseline);
            check_prediction(baseline, function_only, expected);
            result = struct('task', tasks(i), 'function_only', function_only);
            if selected > 0
                gradient_only = gradient_experiment_case(tasks(i), configs(selected), false, true, false);
                both = gradient_experiment_case(tasks(i), configs(selected), true, true, false);
                check_prediction(baseline, gradient_only, ...
                    gradient_experiment_replay(baseline, configs(selected), false));
                check_prediction(baseline, both, ...
                    gradient_experiment_replay(baseline, configs(selected), true));
                result.gradient_only = gradient_only;
                result.both = both;
            end
            save_result(file, result);
        end
    end
    assert(numel(dir(fullfile(stage_root, '*.mat'))) == numel(tasks));
    write_json(fullfile(stage_root, 'ACCEPTED.json'), struct('status', 'accepted', ...
        'cases', numel(tasks), 'selected', selected, 'all_prefixes_and_stops_verified', true));
elseif strcmp(stage, 'report')
    data = load(fullfile(root, 'selection', 'selection.mat'));
    validation = jsondecode(fileread(fullfile(root, 'validation', 'ACCEPTED.json')));
    summary = data.summary;
    summary.real_validation = validation;
    summary.status = 'completed';
    summary.interpretation = ['Replay is screening evidence; selected configurations were rerun. ', ...
        'Zero observed losses are not a universal guarantee. No production defaults or paper figures changed.'];
    write_json(fullfile(root, 'SUMMARY.json'), summary);
    fid = fopen(fullfile(root, 'REPORT.md'), 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# 梯度停机实验结果\n\n');
    fprintf(fid, '完整实例数：%d。候选数：%d。选定候选编号：%d。\n\n', ...
        numel(tasks), numel(configs), data.selected);
    fprintf(fid, '开发集和保留集的损失统计分别保留；没有根据保留集重新调参。\n\n');
    fprintf(fid, '联合配置通过全部无损失条件：%d。仅梯度配置通过全部无损失条件：%d。\n\n', ...
        summary.joint_qualified, summary.gradient_qualified);
    fprintf(fid, '双关总求值：%.0f；仅函数值总求值：%.0f。\n\n', ...
        summary.baseline_evaluations, summary.function_only_evaluations);
    if data.selected > 0
        fprintf(fid, '选定参数：L_H=%.17g，grad_tol=%.17g，beta_g=%.17g，N_g=%d。\n\n', ...
            summary.config.lipschitz, summary.config.tolerance, summary.config.beta, summary.config.window);
        fprintf(fid, '仅梯度总求值：%.0f；联合总求值：%.0f。\n\n', ...
            summary.gradient_evaluations, summary.joint_evaluations);
        fprintf(fid, '仅梯度求值减少 %.4f%%；联合求值减少 %.4f%%。只有无损失检查通过才视为合格。\n\n', ...
            100 * (1 - summary.gradient_evaluations / summary.baseline_evaluations), ...
            100 * (1 - summary.joint_evaluations / summary.baseline_evaluations));
        fprintf(fid, '仅梯度开发/保留集损失计数：%d/%d；联合：%d/%d。\n\n', ...
            summary.gradient_development_losses, summary.gradient_holdout_losses, ...
            summary.joint_development_losses, summary.joint_holdout_losses);
        fprintf(fid, '上述计数跨三个精度及历史/返回点两种口径累加，不是去重后的问题数。\n\n');
    else
        fprintf(fid, '预声明范围内没有开发集无损失的新候选，不能宣称新停机方案合格。\n\n');
    end
    fprintf(fid, '目标值来自本次双关基线，而非论文原多 solver 目标；此报告不是论文实验复现。\n\n');
    fprintf(fid, '详见 SUMMARY.json、selection/scores.csv 和 selection/per_case.mat。\n');
    fprintf(fid, '选定候选的逐实例/逐精度结果见 selection/selected_cases.csv（如有合格候选）。\n');
    fprintf(fid, 'validation 中保存真实复跑及前缀核对，不把参数回放当作真实求解。\n');
    clear cleanup;
else
    error('GradientExperiment:UnknownStage', 'Unknown stage: %s', stage);
end
fprintf('GRADIENT_EXPERIMENT_STAGE_OK %s\n', stage);

end

function start_pool(root, workers)
cluster = parcluster('local');
cluster.JobStorageLocation = fullfile(root, 'parallel_jobs');
if ~isfolder(cluster.JobStorageLocation), mkdir(cluster.JobStorageLocation); end
pool = gcp('nocreate');
if ~isempty(pool) && pool.NumWorkers ~= workers, delete(pool); pool = []; end
if isempty(pool), parpool(cluster, workers); end
end

function file = task_file(folder, task)
file = fullfile(folder, sprintf('f%d_p%03d_r%d.mat', ...
    task.feature_index, task.problem_index, task.repeat));
end

function save_trace(file, trace)
assert(~isfile(file));
temporary = [tempname(fileparts(file)), '.mat'];
save(temporary, 'trace', '-v7');
movefile(temporary, file);
fprintf('BASELINE_SAVED %s calls=%d seconds=%.3f\n', file, trace.calls, trace.seconds);
end

function save_result(file, result)
assert(~isfile(file));
temporary = [tempname(fileparts(file)), '.mat'];
save(temporary, 'result', '-v7');
movefile(temporary, file);
fprintf('VALIDATION_SAVED %s\n', file);
end

function write_json(file, value)
fid = fopen(file, 'w');
assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(value, 'PrettyPrint', true));
end

function test_case(task, configs, folder)
file = task_file(folder, task);
assert(~isfile(file), 'GradientExperiment:ExistingSmoke');
baseline = gradient_experiment_case(task, configs(1), false, false, false);
production = gradient_experiment_case(task, configs(1), false, false, true);
assert(isequaln(baseline.points, production.points) && isequaln(baseline.values, production.values));
assert(isequaln(baseline.truth, production.truth) && isequaln(baseline.xopt, production.xopt));
assert(isequaln(baseline.solver_output, production.solver_output) ...
    && baseline.exitflag == production.exitflag && isequaln(baseline.fopt, production.fopt));
function_only = gradient_experiment_case(task, configs(1), true, false, false);
check_prediction(baseline, function_only, function_prediction(baseline));
indices = [150, 151, 152, 153];
checks = cell(2, numel(indices));
for j = 1:numel(indices)
    for function_stop = [false, true]
        actual = gradient_experiment_case(task, configs(indices(j)), function_stop, true, false);
        predicted = gradient_experiment_replay(baseline, configs(indices(j)), function_stop);
        check_prediction(baseline, actual, predicted);
        if strcmp(configs(indices(j)).rule, 'legacy')
            original = gradient_experiment_case(task, configs(indices(j)), function_stop, true, true);
            assert(isequaln(actual.points, original.points) && isequaln(actual.values, original.values));
            assert(isequaln(actual.xopt, original.xopt) && actual.exitflag == original.exitflag);
            assert(isequaln(actual.solver_output, original.solver_output));
        end
        checks{1 + function_stop, j} = struct('config', indices(j), ...
            'calls', actual.calls, 'prediction', predicted);
    end
end
result = struct('baseline', baseline, 'checks', {checks});
save_result(file, result);
end

function prediction = function_prediction(trace)
prediction = struct('calls', trace.calls, 'output_index', trace.output_index);
event = find(trace.events(:, 3), 1);
if ~isempty(event)
    prediction.calls = trace.events(event, 2);
    prediction.output_index = trace.events(event, 7);
end
end

function check_prediction(baseline, actual, prediction)
assert(actual.calls == prediction.calls, 'GradientExperiment:StopMismatch');
assert(isequaln(actual.points, baseline.points(:, 1:actual.calls)), 'GradientExperiment:PointPrefix');
assert(isequaln(actual.values, baseline.values(1:actual.calls)), 'GradientExperiment:ValuePrefix');
assert(isequaln(actual.truth, baseline.truth(1:actual.calls)), 'GradientExperiment:AssessmentPrefix');
assert(isequaln(actual.xopt(:), baseline.points(:, prediction.output_index)), 'GradientExperiment:OutputMismatch');
end

function select_config(root, tasks, configs)
folder = fullfile(root, 'selection');
assert(~isfile(fullfile(folder, 'selection.mat')), 'GradientExperiment:ExistingSelection');
count = numel(tasks);
number = numel(configs);
taus = [1e-2, 1e-3, 1e-4];
best = inf(6, 133);
baseline_calls = zeros(count, 1);
initial = zeros(count, 1);
for i = 1:count
    loaded = load(task_file(fullfile(root, 'baseline'), tasks(i)), 'trace');
    t = loaded.trace;
    value = min(t.truth, [], 'omitnan');
    assert(isfinite(value));
    best(tasks(i).feature_index, tasks(i).problem_index) = ...
        min(best(tasks(i).feature_index, tasks(i).problem_index), value);
    baseline_calls(i) = t.calls;
    initial(i) = t.initial_value;
end
targets = zeros(count, 3);
loss_gradient = false(count, number, 3, 2);
loss_joint = false(count, number, 3, 2);
loss_function = false(count, 3, 2);
calls_gradient = zeros(count, number);
calls_joint = zeros(count, number);
calls_function = zeros(count, 1);
reference_calls = nan(count, number);
baseline_success = false(count, 3, 2);
first_hits = nan(count, 3);
for i = 1:count
    loaded = load(task_file(fullfile(root, 'baseline'), tasks(i)), 'trace');
    t = loaded.trace;
    b = best(tasks(i).feature_index, tasks(i).problem_index);
    targets(i, :) = b + taus * (initial(i) - b);
    prefix_best = cummin(t.truth);
    baseline_success(i, :, 1) = prefix_best(end) <= targets(i, :);
    baseline_success(i, :, 2) = t.truth(t.output_index) <= targets(i, :);
    for q = 1:3
        hit = find(prefix_best <= targets(i, q), 1);
        if ~isempty(hit), first_hits(i, q) = hit; end
    end
    fp = function_prediction(t);
    calls_function(i) = fp.calls;
    loss_function(i, :, 1) = baseline_success(i, :, 1) & ~(prefix_best(fp.calls) <= targets(i, :));
    loss_function(i, :, 2) = baseline_success(i, :, 2) & ~(t.truth(fp.output_index) <= targets(i, :));
    for j = 1:number
        gp = gradient_experiment_replay(t, configs(j), false);
        jp = gp;
        if fp.calls < gp.calls
            jp.calls = fp.calls;
            jp.output_index = fp.output_index;
        end
        calls_gradient(i, j) = gp.calls;
        calls_joint(i, j) = jp.calls;
        reference_calls(i, j) = gp.reference_call;
        loss_gradient(i, j, :, 1) = reshape(baseline_success(i, :, 1) ...
            & ~(prefix_best(gp.calls) <= targets(i, :)), 1, 1, 3);
        loss_gradient(i, j, :, 2) = reshape(baseline_success(i, :, 2) ...
            & ~(t.truth(gp.output_index) <= targets(i, :)), 1, 1, 3);
        loss_joint(i, j, :, 1) = reshape(baseline_success(i, :, 1) ...
            & ~(prefix_best(jp.calls) <= targets(i, :)), 1, 1, 3);
        loss_joint(i, j, :, 2) = reshape(baseline_success(i, :, 2) ...
            & ~(t.truth(jp.output_index) <= targets(i, :)), 1, 1, 3);
    end
end
development = mod([tasks.problem_index], 5) ~= 0;
holdout = ~development;
dev_g = squeeze(sum(loss_gradient(development, :, :, :), [1, 3, 4]));
dev_j = squeeze(sum(loss_joint(development, :, :, :), [1, 3, 4]));
hold_g = squeeze(sum(loss_gradient(holdout, :, :, :), [1, 3, 4]));
hold_j = squeeze(sum(loss_joint(holdout, :, :, :), [1, 3, 4]));
new_rule = strcmp({configs.rule}, 'new')';
joint_eligible = find(new_rule & dev_g(:) == 0 & dev_j(:) == 0);
gradient_eligible = find(new_rule & dev_g(:) == 0);
selected = 0;
selection_kind = 'no_eligible_candidate';
if ~isempty(joint_eligible)
    cost = sum(calls_gradient(development, joint_eligible) + calls_joint(development, joint_eligible), 1);
    [~, index] = min(cost);
    selected = joint_eligible(index);
    selection_kind = 'joint_development_zero_loss';
elseif ~isempty(gradient_eligible)
    [~, index] = min(sum(calls_gradient(development, gradient_eligible), 1));
    selected = gradient_eligible(index);
    selection_kind = 'gradient_only_development_zero_loss';
end
summary = struct('cases', count, 'configurations', number, 'taus', taus, ...
    'development_cases', sum(development), 'holdout_cases', sum(holdout), ...
    'selected', selected, 'selection_kind', selection_kind, ...
    'gradient_qualified', false, 'joint_qualified', false, ...
    'baseline_evaluations', sum(baseline_calls), ...
    'function_only_evaluations', sum(calls_function), ...
    'function_only_losses', squeeze(sum(loss_function, 1)), ...
    'baseline_successes', squeeze(sum(baseline_success, 1)));
if selected > 0
    summary.config = configs(selected);
    summary.gradient_qualified = dev_g(selected) == 0 && hold_g(selected) == 0;
    summary.joint_qualified = summary.gradient_qualified && dev_j(selected) == 0 && hold_j(selected) == 0;
    summary.gradient_development_losses = dev_g(selected);
    summary.gradient_holdout_losses = hold_g(selected);
    summary.joint_development_losses = dev_j(selected);
    summary.joint_holdout_losses = hold_j(selected);
    summary.gradient_evaluations = sum(calls_gradient(:, selected));
    summary.joint_evaluations = sum(calls_joint(:, selected));
    summary.missing_references = sum(isnan(reference_calls(:, selected)));
end
save(fullfile(folder, 'per_case.mat'), 'tasks', 'configs', 'targets', 'best', 'baseline_calls', ...
    'baseline_success', 'first_hits', 'loss_gradient', 'loss_joint', 'loss_function', ...
    'calls_gradient', 'calls_joint', 'calls_function', 'reference_calls', 'development', 'holdout', '-v7');
save(fullfile(folder, 'selection.mat'), 'selected', 'summary');
write_json(fullfile(folder, 'SUMMARY.json'), summary);
if selected > 0
    fid = fopen(fullfile(folder, 'selected_cases.csv'), 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, ['problem,feature,repeat,split,tau,target,baseline_history_success,baseline_output_success,', ...
        'gradient_history_loss,gradient_output_loss,joint_history_loss,joint_output_loss,', ...
        'function_history_loss,function_output_loss,baseline_calls,gradient_calls,joint_calls,', ...
        'function_calls,baseline_first_hit,gradient_reference_call\n']);
    for i = 1:count
        split = 'development';
        if holdout(i), split = 'holdout'; end
        for q = 1:3
            fprintf(fid, '%s,%s,%d,%s,%.17g,%.17g,%d,%d,%d,%d,%d,%d,%d,%d,%.0f,%.0f,%.0f,%.0f,%.0f,%.0f\n', ...
                tasks(i).problem, tasks(i).feature, tasks(i).repeat, split, taus(q), targets(i, q), ...
                baseline_success(i, q, 1), baseline_success(i, q, 2), ...
                loss_gradient(i, selected, q, 1), loss_gradient(i, selected, q, 2), ...
                loss_joint(i, selected, q, 1), loss_joint(i, selected, q, 2), ...
                loss_function(i, q, 1), loss_function(i, q, 2), baseline_calls(i), ...
                calls_gradient(i, selected), calls_joint(i, selected), calls_function(i), ...
                first_hits(i, q), reference_calls(i, selected));
        end
    end
    clear cleanup;
end
fid = fopen(fullfile(folder, 'scores.csv'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'index,rule,L_H,grad_tol,beta,window,dev_gradient_losses,dev_joint_losses,holdout_gradient_losses,holdout_joint_losses,gradient_evaluations,joint_evaluations\n');
for j = 1:number
    c = configs(j);
    fprintf(fid, '%d,%s,%.17g,%.17g,%.17g,%d,%d,%d,%d,%d,%.0f,%.0f\n', ...
        j, c.rule, c.lipschitz, c.tolerance, c.beta, c.window, dev_g(j), dev_j(j), ...
        hold_g(j), hold_j(j), sum(calls_gradient(:, j)), sum(calls_joint(:, j)));
end
end
