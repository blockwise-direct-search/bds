function trace = gradient_experiment_case(task, config, function_stop, gradient_stop, production)
%GRADIENT_EXPERIMENT_CASE Run one paired frozen-feature BDS experiment.
%
%   task         Frozen problem name/index, feature name, and repeat index.
%   config       Gradient-only configuration; an observer is attached locally.
%   production   Whether to call unmodified production instead of the experiment.
%   trace        Actual solver calls, true assessments, events, options and outputs.

problem = s2mpj_load(task.problem);
assert(problem.n >= 6 && problem.n <= 50);
feature_record = struct('name', task.feature, 'n_runs', 5);
if strcmp(task.feature, 'plain')
    feature_record.n_runs = 1;
end
feature_options = tsfsb_feature_options(feature_record);
feature = Feature(feature_options.feature_name, ...
    rmfield(feature_options, {'feature_name', 'feature_stamp'}));
seed = mod(23333 * task.seed_base + 211 * task.repeat, 2^32);
budget = 500 * problem.n;
featured = FeaturedProblem(problem, feature, budget, seed);
options = bds_paper_options(featured.x0, 'external', 'mp');
options.seed = task.seed_base;
options.use_function_value_stop = function_stop;
options.use_estimated_gradient_stop = gradient_stop;
if gradient_stop && ~strcmp(config.rule, 'legacy')
    options.lipschitz_constant = config.lipschitz;
    options.grad_tol = config.tolerance;
    options.grad_window_size = config.window;
end
count = 0;
points = nan(problem.n, budget);
values = nan(1, budget);
events = zeros(0, 10);
best_index = 1;
best_value = inf;
config.observe = @observe;
rng(task.seed_base, 'twister');
started = tic;
fprintf('CASE_START %s %s repeat=%d rule=%s function=%d gradient=%d production=%d\n', ...
    task.feature, task.problem, task.repeat, config.rule, function_stop, gradient_stop, production);
if production
    [x, f, flag, output] = bds(@objective, featured.x0, options);
else
    [x, f, flag, output] = gradient_experiment_bds(@objective, featured.x0, options, config);
end
elapsed = toc(started);
assert(count == output.funcCount && count <= budget && count == featured.n_eval_fun);
matches = find(all(points(:, 1:count) == x(:), 1));
assert(~isempty(matches), 'GradientExperiment:UnknownOutput', 'Verification failed: UnknownOutput.');
output_index = matches(end);
trace = struct('task', task, 'seed', seed, 'budget', budget, 'options', options, ...
    'config', rmfield(config, 'observe'), 'production', production, ...
    'calls', count, 'points', points(:, 1:count), 'values', values(1:count), ...
    'truth', featured.fun_hist, 'initial_value', featured.fun_init, ...
    'events', events, 'xopt', x, 'fopt', f, 'exitflag', flag, ...
    'output_index', output_index, 'solver_output', output, 'seconds', elapsed);
assert(numel(trace.truth) == count && isfinite(trace.initial_value));

    function value = objective(point)
        count = count + 1;
        assert(count <= budget, 'GradientExperiment:BudgetExceeded', 'Verification failed: BudgetExceeded.');
        points(:, count) = point(:);
        value = featured.fun(point);
        values(count) = value;
        if value < best_value
            best_value = value;
            best_index = count;
        end
    end

    function observe(iteration, calls, incumbent, function_hit, gradient_norm, ...
            error_scale, consistency, legacy_error, poll_failed, poll_failures)
        assert(calls == count);
        % Ties may choose another occurrence of the same point. Fall back to
        % an exact point lookup instead of assuming a particular tie policy.
        index = best_index;
        if ~isequal(incumbent(:), points(:, index))
            matches = find(all(points(:, 1:count) == incumbent(:), 1));
            assert(~isempty(matches), 'GradientExperiment:UnknownIncumbent', 'Verification failed: UnknownIncumbent.');
            index = matches(end);
        end
        events(end+1, :) = [iteration, calls, function_hit, gradient_norm, ...
            error_scale, consistency, index, legacy_error, poll_failed, poll_failures];
    end

end
