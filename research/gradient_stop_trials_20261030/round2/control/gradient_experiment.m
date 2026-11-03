function gradient_experiment(stage)
%GRADIENT_EXPERIMENT Verify and run the isolated polling-failure experiment.

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
seed_base = 20260828;
data_root = root;
if endsWith(stage, '_fresh')
    seed_base = 20261030;
    data_root = fullfile(root, 'fresh');
end
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
configs = gradient_experiment_config();
assert(numel(configs) == 752);
phase = erase(stage, '_fresh');
stage_root = fullfile(data_root, phase);
if ~isfolder(stage_root), mkdir(stage_root); end
if strcmp(stage, 'preflight')
    gradient_experiment_unit_test();
    current = bds_paper_options([1; 2; 3], 'external', 'mp');
    frozen = c04_options_record([1; 2; 3], 'bds-mp-noret');
    frozen = rmfield(frozen, {'use_productive_direction_memory', 'productive_direction_memory_size'});
    assert(strcmp(func2str(current.forcing_function), func2str(frozen.forcing_function)));
    assert(isequaln(rmfield(current, 'forcing_function'), rmfield(frozen, 'forcing_function')));
    smoke_names = {'ARGLINB', 'ARWHEAD', 'BIGGS6', 'GAUSS1LS', 'SBRYBND', 'VESUVIALS'};
    smoke = tasks(ismember({tasks.problem}, smoke_names) & [tasks.repeat] == 1);
    assert(numel(smoke) == 36);
    start_pool(root, 12);
    parfor i = 1:numel(smoke)
        test_case(smoke(i), configs, stage_root);
    end
    write_json(fullfile(root, 'PREFLIGHT_ACCEPTED.json'), ...
        struct('status', 'accepted', 'cases', numel(smoke), 'real_runs_per_case', 19));
elseif strcmp(stage, 'pipeline_smoke')
    smoke = tasks(ismember({tasks.problem}, {'ARGLINB', 'ARWHEAD', 'BIGGS6'}) & [tasks.repeat] == 1);
    mkdir(fullfile(stage_root, 'baseline'));
    mkdir(fullfile(stage_root, 'validation'));
    for i = 1:numel(smoke)
        loaded = load(task_file(fullfile(root, 'preflight'), smoke(i)), 'result');
        save_trace(task_file(fullfile(stage_root, 'baseline'), smoke(i)), loaded.result.baseline);
    end
    select_config(stage_root, smoke, configs);
    chosen = load(fullfile(stage_root, 'selection', 'selection.mat'));
    start_pool(root, 6);
    early_stops = false(1, numel(smoke));
    parfor i = 1:numel(smoke)
        loaded = load(task_file(fullfile(stage_root, 'baseline'), smoke(i)), 'trace');
        result = validate_case(smoke(i), configs, chosen.selected, loaded.trace);
        early_stops(i) = result.gradient_only.calls < loaded.trace.calls;
        save_result(task_file(fullfile(stage_root, 'validation'), smoke(i)), result);
    end
    assert(any(early_stops), 'GradientExperiment:NoNewEarlyStopExercised', 'Verification failed: NoNewEarlyStopExercised.');
    % A separate smoke-only seed tests fixed-candidate evaluation without
    % looking at the formal new-seed validation data before selection.
    fresh_smoke = smoke;
    for i = 1:numel(fresh_smoke), fresh_smoke(i).seed_base = 20261031; end
    fresh_root = fullfile(stage_root, 'fresh');
    mkdir(fullfile(fresh_root, 'baseline'));
    mkdir(fullfile(fresh_root, 'validation'));
    parfor i = 1:numel(fresh_smoke)
        trace = gradient_experiment_case(fresh_smoke(i), configs(1), false, false, false);
        save_trace(task_file(fullfile(fresh_root, 'baseline'), fresh_smoke(i)), trace);
        result = validate_case(fresh_smoke(i), configs, chosen.selected, trace);
        save_result(task_file(fullfile(fresh_root, 'validation'), fresh_smoke(i)), result);
    end
    select_config(fresh_root, fresh_smoke, configs, chosen);
    write_json(fullfile(root, 'PIPELINE_SMOKE_ACCEPTED.json'), ...
        struct('status', 'accepted', 'cases', numel(smoke), 'selected', chosen.selected, ...
        'new_rule_early_stops_exercised', sum(early_stops), 'smoke_only_seed', 20261031));
elseif strcmp(phase, 'baseline')
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
        'cases', numel(tasks), 'features', {features}, 'seed_base', seed_base));
elseif strcmp(stage, 'selection')
    select_config(root, tasks, configs);
elseif strcmp(stage, 'evaluation_fresh')
    chosen = load(fullfile(root, 'selection', 'selection.mat'));
    select_config(data_root, tasks, configs, chosen);
elseif strcmp(phase, 'validation')
    chosen = load(fullfile(root, 'selection', 'selection.mat'));
    start_pool(root, 30);
    parfor i = 1:numel(tasks)
        file = task_file(stage_root, tasks(i));
        if ~isfile(file)
            loaded = load(task_file(fullfile(data_root, 'baseline'), tasks(i)), 'trace');
            result = validate_case(tasks(i), configs, chosen.selected, loaded.trace);
            save_result(file, result);
        end
    end
    assert(numel(dir(fullfile(stage_root, '*.mat'))) == numel(tasks));
    write_json(fullfile(stage_root, 'ACCEPTED.json'), struct('status', 'accepted', ...
        'cases', numel(tasks), 'selected', chosen.selected, 'real_runs_per_case', 5, ...
        'all_prefixes_and_stops_verified', true, 'seed_base', seed_base));
elseif strcmp(stage, 'report')
    development = jsondecode(fileread(fullfile(root, 'selection', 'SUMMARY.json')));
    fresh = jsondecode(fileread(fullfile(root, 'fresh', 'selection', 'SUMMARY.json')));
    validation = jsondecode(fileread(fullfile(root, 'validation', 'ACCEPTED.json')));
    validation_fresh = jsondecode(fileread(fullfile(root, 'fresh', 'validation', 'ACCEPTED.json')));
    assert(strcmp(validation.status, 'accepted') && strcmp(validation_fresh.status, 'accepted'));
    summary = struct('status', 'completed', 'development', development, 'new_seed', fresh, ...
        'gradient_qualified', development.gradient_qualified && fresh.gradient_qualified, ...
        'joint_qualified', development.joint_qualified && fresh.joint_qualified, ...
        'real_validation_cases', 6916, 'real_validation_runs', 34580, ...
        'interpretation', 'Completed is not qualified. Fixed new-seed evaluation does not retune the candidate.');
    write_json(fullfile(root, 'SUMMARY.json'), summary);
    fid = fopen(fullfile(root, 'REPORT.md'), 'w');
    cleanup = onCleanup(@() fclose(fid));
    fprintf(fid, '# 连续 polling 失败参考值实验结果\n\n');
    fprintf(fid, '候选编号 %d，K=%d，L_H=%.17g，tol=%.17g，beta=%.17g，window=%d。\n\n', ...
        development.selected, development.config.minimum_failures, development.config.lipschitz, ...
        development.config.tolerance, development.config.beta, development.config.window);
    fprintf(fid, '选择类型：%s。开发筛选合格：%d。\n\n', ...
        development.selection_kind, development.eligible_on_development);
    fprintf(fid, '全体无损失检查：仅梯度 %d，联合 %d。失败诊断候选不可当作合格方案。\n\n', ...
        summary.gradient_qualified, summary.joint_qualified);
    fprintf(fid, '开发/新种子仅梯度求值节省：%.4f%% / %.4f%%。\n\n', ...
        100*development.gradient_saving_fraction, 100*fresh.gradient_saving_fraction);
    fprintf(fid, '两个种子组各 3458 例基线和每例 5 次真实复跑均完成。\n\n');
    fprintf(fid, '完整基线与回放仅用于筛选；候选和旧参考双阈值对照均已真实复跑。\n\n');
    fprintf(fid, '六特征分项见 SUMMARY.json；仅改变 K 的五组与扩展组见 selection/scores.csv。\n');
    fprintf(fid, '参考值/时刻/误差比/计数、失败实例见 selection/per_case.mat 和 selected_cases.csv。\n');
    fprintf(fid, '新种子仅评估冻结候选和对照；不冒充原论文目标或数学保证。\n');
else
    error('GradientExperiment:UnknownStage', 'Unknown stage: %s', stage);
end
fprintf('GRADIENT_EXPERIMENT_STAGE_OK %s\n', stage);
end

function result = validate_case(task, configs, selected, baseline)
function_only = gradient_experiment_case(task, configs(1), true, false, false);
check_prediction(baseline, function_only, function_prediction(baseline));
gradient_only = gradient_experiment_case(task, configs(selected), false, true, false);
both = gradient_experiment_case(task, configs(selected), true, true, false);
control_gradient = gradient_experiment_case(task, configs(end), false, true, false);
control_both = gradient_experiment_case(task, configs(end), true, true, false);
check_prediction(baseline, gradient_only, gradient_experiment_replay(baseline, configs(selected), false));
check_prediction(baseline, both, gradient_experiment_replay(baseline, configs(selected), true));
check_prediction(baseline, control_gradient, gradient_experiment_replay(baseline, configs(end), false));
check_prediction(baseline, control_both, gradient_experiment_replay(baseline, configs(end), true));
result = struct('task', task, 'function_only', function_only, 'gradient_only', gradient_only, ...
    'both', both, 'control_gradient', control_gradient, 'control_both', control_both);
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
assert(~isfile(file), 'GradientExperiment:ExistingSmoke', 'Verification failed: ExistingSmoke.');
baseline = gradient_experiment_case(task, configs(1), false, false, false);
production = gradient_experiment_case(task, configs(1), false, false, true);
assert(isequaln(baseline.points, production.points) && isequaln(baseline.values, production.values));
assert(isequaln(baseline.truth, production.truth) && isequaln(baseline.xopt, production.xopt));
assert(isequaln(baseline.solver_output, production.solver_output) ...
    && baseline.exitflag == production.exitflag && isequaln(baseline.fopt, production.fopt));
function_only = gradient_experiment_case(task, configs(1), true, false, false);
check_prediction(baseline, function_only, function_prediction(baseline));
indices = [find(strcmp({configs.rule}, 'new') & [configs.lipschitz] == 10 ...
    & [configs.tolerance] == 3e-2 & [configs.beta] == 1e-1 & [configs.window] == 1), ...
    numel(configs)-1, numel(configs)];
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
assert(actual.calls == prediction.calls, 'GradientExperiment:StopMismatch', 'Verification failed: StopMismatch.');
assert(isequaln(actual.points, baseline.points(:, 1:actual.calls)), 'GradientExperiment:PointPrefix', 'Verification failed: PointPrefix.');
assert(isequaln(actual.values, baseline.values(1:actual.calls)), 'GradientExperiment:ValuePrefix', 'Verification failed: ValuePrefix.');
assert(isequaln(actual.truth, baseline.truth(1:actual.calls)), 'GradientExperiment:AssessmentPrefix', 'Verification failed: AssessmentPrefix.');
assert(isequaln(actual.xopt(:), baseline.points(:, prediction.output_index)), 'GradientExperiment:OutputMismatch', 'Verification failed: OutputMismatch.');
end

function select_config(root, tasks, configs, fixed_selection)
if nargin < 4, fixed_selection = []; end
if ~isfolder(fullfile(root, 'selection')), mkdir(fullfile(root, 'selection')); end
folder = fullfile(root, 'selection');
assert(~isfile(fullfile(folder, 'selection.mat')), 'GradientExperiment:ExistingSelection', 'Verification failed: ExistingSelection.');
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
reference_values = nan(count, number);
reference_iterations = nan(count, number);
reference_error_ratios = nan(count, number);
reference_failures = nan(count, number);
evaluated = 1:number;
if ~isempty(fixed_selection)
    evaluated = unique([fixed_selection.selected, number]);
end
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
    for j = evaluated
        gp = gradient_experiment_replay(t, configs(j), false);
        jp = gp;
        if fp.calls < gp.calls
            jp.calls = fp.calls;
            jp.output_index = fp.output_index;
        end
        calls_gradient(i, j) = gp.calls;
        calls_joint(i, j) = jp.calls;
        reference_calls(i, j) = gp.reference_call;
        reference_values(i, j) = gp.reference;
        reference_iterations(i, j) = gp.reference_iteration;
        reference_error_ratios(i, j) = gp.reference_error_ratio;
        reference_failures(i, j) = gp.reference_failures;
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
new_rule = strcmp({configs.rule}, 'new')' & [configs.minimum_failures]' >= 2;
primary = new_rule & [configs.lipschitz]' == 1000 & [configs.tolerance]' == 1e-2 ...
    & [configs.beta]' == 1e-3 & [configs.window]' == 1;
joint_eligible = find(new_rule & dev_g(:) == 0 & dev_j(:) == 0);
gradient_eligible = find(new_rule & dev_g(:) == 0);
selected = 0;
eligible_on_development = true;
selection_kind = 'primary_joint';
if ~isempty(fixed_selection)
    selected = fixed_selection.selected;
    eligible_on_development = fixed_selection.eligible_on_development;
    selection_kind = 'fixed_before_new_seed';
else
    choices = {joint_eligible(primary(joint_eligible)), gradient_eligible(primary(gradient_eligible)), ...
        joint_eligible, gradient_eligible};
    kinds = {'primary_joint', 'primary_gradient', 'extended_joint', 'extended_gradient'};
    for group = 1:numel(choices)
        available = choices{group};
        if isempty(available), continue; end
        cost = sum(calls_gradient(development, available) + calls_joint(development, available), 1);
        [~, index] = min(cost);
        selected = available(index);
        selection_kind = kinds{group};
        break;
    end
    if selected == 0
        eligible_on_development = false;
        selection_kind = 'failed_diagnostic_candidate';
        available = find(new_rule);
        minimum_loss = min(dev_g(available));
        available = available(dev_g(available) == minimum_loss);
        [~, index] = min(sum(calls_gradient(development, available), 1));
        selected = available(index);
    end
end
summary = struct('cases', count, 'configurations', number, 'taus', taus, ...
    'development_cases', sum(development), 'holdout_cases', sum(holdout), ...
    'selected', selected, 'selection_kind', selection_kind, ...
    'eligible_on_development', eligible_on_development, 'evaluated_indices', evaluated, ...
    'seed_base', tasks(1).seed_base, ...
    'gradient_qualified', false, 'joint_qualified', false, ...
    'baseline_evaluations', sum(baseline_calls), ...
    'function_only_evaluations', sum(calls_function), ...
    'function_only_losses', squeeze(sum(loss_function, 1)), ...
    'baseline_successes', squeeze(sum(baseline_success, 1)));
if selected > 0
    summary.config = configs(selected);
    summary.gradient_qualified = eligible_on_development && dev_g(selected) == 0 && hold_g(selected) == 0;
    summary.joint_qualified = summary.gradient_qualified && dev_j(selected) == 0 && hold_j(selected) == 0;
    summary.gradient_development_losses = dev_g(selected);
    summary.gradient_holdout_losses = hold_g(selected);
    summary.joint_development_losses = dev_j(selected);
    summary.joint_holdout_losses = hold_j(selected);
    summary.gradient_evaluations = sum(calls_gradient(:, selected));
    summary.joint_evaluations = sum(calls_joint(:, selected));
    summary.missing_references = sum(isnan(reference_calls(:, selected)));
    summary.gradient_early_stops = sum(calls_gradient(:, selected) < baseline_calls);
    summary.no_gradient_early_stop = sum(calls_gradient(:, selected) >= baseline_calls);
    summary.gradient_saving_fraction = 1 - summary.gradient_evaluations / summary.baseline_evaluations;
    summary.useful_gradient_candidate = summary.gradient_qualified && summary.gradient_saving_fraction > 0;
    summary.gradient_losses_by_tau_and_history_output = squeeze(sum(loss_gradient(:, selected, :, :), 1));
    summary.joint_losses_by_tau_and_history_output = squeeze(sum(loss_joint(:, selected, :, :), 1));
    summary.control_gradient_losses = squeeze(sum(loss_gradient(:, number, :, :), 1));
    summary.control_joint_losses = squeeze(sum(loss_joint(:, number, :, :), 1));
    summary.control_gradient_evaluations = sum(calls_gradient(:, number));
    summary.control_joint_evaluations = sum(calls_joint(:, number));
    feature_summaries = struct([]);
    for feature_index = 1:6
        rows = [tasks.feature_index] == feature_index;
        item = struct('feature', tasks(find(rows, 1)).feature, 'cases', sum(rows), ...
            'baseline_calls', sum(baseline_calls(rows)), ...
            'gradient_calls', sum(calls_gradient(rows, selected)), ...
            'joint_calls', sum(calls_joint(rows, selected)), ...
            'gradient_losses', squeeze(sum(loss_gradient(rows, selected, :, :), 1)), ...
            'joint_losses', squeeze(sum(loss_joint(rows, selected, :, :), 1)));
        feature_summaries = [feature_summaries, item];
    end
    summary.features = feature_summaries;
end
if isempty(fixed_selection)
    basic = find(strcmp({configs.rule}, 'new') & [configs.lipschitz] == 1000 ...
        & [configs.tolerance] == 1e-2 & [configs.beta] == 1e-3 & [configs.window] == 1);
    basic_summaries = struct([]);
    for index = basic
        item = struct('index', index, 'K', configs(index).minimum_failures, ...
            'gradient_losses', squeeze(sum(loss_gradient(:, index, :, :), 1)), ...
            'joint_losses', squeeze(sum(loss_joint(:, index, :, :), 1)), ...
            'gradient_evaluations', sum(calls_gradient(:, index)), ...
            'joint_evaluations', sum(calls_joint(:, index)), ...
            'missing_references', sum(isnan(reference_calls(:, index))), ...
            'no_gradient_early_stop', sum(calls_gradient(:, index) >= baseline_calls));
        basic_summaries = [basic_summaries, item];
    end
    summary.primary_k_comparison = basic_summaries;
end
save(fullfile(folder, 'per_case.mat'), 'tasks', 'configs', 'targets', 'best', 'baseline_calls', ...
    'baseline_success', 'first_hits', 'loss_gradient', 'loss_joint', 'loss_function', ...
    'calls_gradient', 'calls_joint', 'calls_function', 'reference_calls', 'reference_values', ...
    'reference_iterations', 'reference_error_ratios', 'reference_failures', 'evaluated', ...
    'development', 'holdout', '-v7');
save(fullfile(folder, 'selection.mat'), 'selected', 'eligible_on_development', 'summary');
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
fprintf(fid, 'index,rule,K,L_H,grad_tol,beta,window,dev_gradient_losses,dev_joint_losses,holdout_gradient_losses,holdout_joint_losses,gradient_evaluations,joint_evaluations\n');
for j = evaluated
    c = configs(j);
    fprintf(fid, '%d,%s,%d,%.17g,%.17g,%.17g,%d,%d,%d,%d,%d,%.0f,%.0f\n', ...
        j, c.rule, c.minimum_failures, c.lipschitz, c.tolerance, c.beta, c.window, dev_g(j), dev_j(j), ...
        hold_g(j), hold_j(j), sum(calls_gradient(:, j)), sum(calls_joint(:, j)));
end
end
