function summary = verify_gradient_threshold_candidate(reference_src, result_directory, mode)
%VERIFY_GRADIENT_THRESHOLD_CANDIDATE Compare production with the tested candidate.
%
%   reference_src                      Read-only src directory from the completed 20261030
%                                      experiment, containing bds_dual_threshold.m and private/.
%   result_directory                   New directory for exact trace evidence and a summary.
%   mode                               'matrix' for algorithm/switch/objective checks, or
%                                      's2mpj' for four problems, six features, and two seeds.
%
%   Requires the frozen MP oracle on the path in matrix mode and the frozen
%   OptiProfiler/S2MPJ helpers in s2mpj mode. No benchmark profiles are drawn.
%   Historical MP/no-acceleration comparisons disable gradient stopping;
%   enabled stopping is compared with the already tested new criterion.

assert(ismember(mode, {'matrix', 's2mpj'}));
assert(~isfolder(result_directory));
mkdir(result_directory);
tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
oldpath = path();
old_rng = rng();
cleanup = onCleanup(@() restore_state(oldpath, old_rng));
addpath(reference_src, fullfile(tests_dir, 'competitors'), fullfile(root_dir, 'examples'));
addpath(fullfile(root_dir, 'src'));
assert(strcmp(which('bds'), fullfile(root_dir, 'src', 'bds.m')));
assert(strcmp(which('bds_dual_threshold'), fullfile(reference_src, 'bds_dual_threshold.m')));
summary = struct('candidate_cases', 0, 'historical_cases', 0, 'gradient_stops', 0);

if strcmp(mode, 'matrix')
    for n = [1, 3, 7]
        x0 = (1:n)' / 3;
        for algorithm = {'cbds', 'pbds', 'rbds', 'pads', 'ds'}
            for acceleration = [false, true]
                for function_stop = [false, true]
                    for gradient_stop = [false, true]
                        options = bds_paper_options(x0, 'external', 'mp');
                        options.Algorithm = algorithm{1};
                        options.use_iteration_pattern_step = acceleration;
                        options.use_momentum_extrapolation = acceleration;
                        options.use_function_value_stop = function_stop;
                        options.use_estimated_gradient_stop = gradient_stop;
                        options = enable_histories(options);
                        for kind = 1:4
                            rng(options.seed, 'twister');
                            random_state = rng();
                            actual = record_bds_execution(@bds, @objective, x0, options, random_state);
                            expected = record_bds_execution(@bds_dual_threshold, @objective, x0, options, random_state);
                            summary.candidate_cases = summary.candidate_cases + 1;
                            file = fullfile(result_directory, sprintf('case_%04d.mat', summary.candidate_cases));
                            save(file, 'actual', 'expected', 'options', 'x0', 'kind', 'random_state');
                            assert(isequaln(actual, expected), 'Candidate trace mismatch: %s', file);
                            assert(actual.output.funcCount <= options.MaxFunctionEvaluations);
                            summary.gradient_stops = summary.gradient_stops + (actual.exitflag == 5);
                            if ~gradient_stop
                                reference_options = options;
                                if acceleration
                                    reference_options = frozen_mp_options(options, n);
                                    oracle = @c03_bds_mp;
                                else
                                    reference_options = rmfield(options, ...
                                        {'use_iteration_pattern_step', 'use_momentum_extrapolation', 'momentum_decay'});
                                    oracle = @bds_without_acceleration_reference;
                                end
                                historical = record_bds_execution(oracle, @objective, x0, reference_options, random_state);
                                save(file, 'historical', 'reference_options', '-append');
                                assert(isequaln(actual, historical), 'Historical trace mismatch: %s', file);
                                summary.historical_cases = summary.historical_cases + 1;
                            end
                        end
                    end
                end
            end
        end
    end
    assert(summary.candidate_cases == 480 && summary.historical_cases == 240);
else
    features = {'plain', 'noisy_1e-4', 'noisy_1e-2', 'linearly_transformed', ...
        'linearly_transformed_noisy_1e-4', 'linearly_transformed_noisy_1e-2'};
    tasks = struct('name', {}, 'feature', {}, 'seed', {}, 'function_stop', {}, 'gradient_stop', {});
    for seed = [20260828, 20261030]
        for name = {'ARGLINB', 'ARWHEAD', 'BIGGS6', 'GAUSS1LS'}
            for feature = features
                for function_stop = [false, true]
                    for gradient_stop = [false, true]
                        tasks(end + 1) = struct('name', name{1}, 'feature', feature{1}, ...
                            'seed', seed, 'function_stop', function_stop, 'gradient_stop', gradient_stop);
                    end
                end
            end
        end
    end
    cluster = parcluster('local');
    cluster.JobStorageLocation = fullfile(result_directory, 'parallel_jobs');
    mkdir(cluster.JobStorageLocation);
    pool = parpool(cluster, 8);
    pool_cleanup = onCleanup(@() delete(pool));
    gradient_stops = zeros(1, numel(tasks));
    % Each pair recreates both FeaturedProblem instances and resets the solver
    % RNG. Scheduling changes neither the cases nor their random realizations.
    parfor i = 1:numel(tasks)
        gradient_stops(i) = compare_featured_pair(tasks(i), result_directory, i, root_dir, reference_src);
    end
    summary.candidate_cases = numel(tasks);
    summary.gradient_stops = sum(gradient_stops);
    assert(summary.candidate_cases == 192);
end
assert(summary.gradient_stops > 0, 'The candidate comparison never exercised gradient stopping.');
save(fullfile(result_directory, 'summary.mat'), 'summary');
fprintf('GRADIENT_CANDIDATE_OK %s candidate=%d historical=%d gradient_stops=%d\n', ...
    mode, summary.candidate_cases, summary.historical_cases, summary.gradient_stops);

    function value = objective(x)
        value = sum(((1:numel(x))' .* (x(:) - 0.27)).^2);
        if kind == 2
            value = value * (1 + 0.01 * randn());
        elseif kind == 3 && x(1) > 0.7
            value = nan;
        elseif kind == 4
            if x(1) > 0.7
                error('verify_gradient_threshold_candidate:ObjectiveFailure', 'Intentional failure.');
            elseif x(1) < -0.7
                value = inf;
            end
        end
    end

end

function stopped = compare_featured_pair(task, result_directory, index, root_dir, reference_src)
% Keep saving outside the parfor body and verify worker path resolution.

assert(strcmp(which('bds'), fullfile(root_dir, 'src', 'bds.m')));
assert(strcmp(which('bds_dual_threshold'), fullfile(reference_src, 'bds_dual_threshold.m')));
actual = featured_run(@bds, task.name, task.feature, task.seed, task.function_stop, task.gradient_stop);
expected = featured_run(@bds_dual_threshold, task.name, task.feature, task.seed, task.function_stop, task.gradient_stop);
file = fullfile(result_directory, sprintf('case_%04d.mat', index));
save(file, 'actual', 'expected', 'task');
assert(isequaln(actual, expected), 'S2MPJ candidate trace mismatch: %s', file);
stopped = actual.exitflag == 5;
fprintf('S2MPJ_CANDIDATE_PAIR_OK %d/192 %s %s\n', index, task.name, task.feature);

end

function record = featured_run(solver, name, feature_name, seed, function_stop, gradient_stop)

problem = s2mpj_load(name);
assert(problem.n >= 6 && problem.n <= 50);
repeats = 5;
if strcmp(feature_name, 'plain'), repeats = 1; end
feature_options = tsfsb_feature_options(struct('name', feature_name, 'n_runs', repeats));
feature = Feature(feature_options.feature_name, rmfield(feature_options, {'feature_name', 'feature_stamp'}));
featured = FeaturedProblem(problem, feature, 500 * problem.n, mod(23333 * seed + 211, 2^32));
options = bds_paper_options(featured.x0, 'external', 'mp');
options.seed = seed;
options.use_function_value_stop = function_stop;
options.use_estimated_gradient_stop = gradient_stop;
options = enable_histories(options);
rng(seed, 'twister');
record = record_bds_execution(solver, @(x) featured.fun(x), featured.x0, options, rng());
assert(record.output.funcCount == featured.n_eval_fun ...
    && record.output.funcCount <= options.MaxFunctionEvaluations);
record.truth = featured.fun_hist;
record.initial_value = featured.fun_init;
assert(numel(record.truth) == record.output.funcCount);

end

function options = enable_histories(options)

options.output_xhist = true;
options.output_alpha_hist = true;
options.output_block_hist = true;
options.output_grad_hist = true;

end

function restore_state(oldpath, old_rng)

path(oldpath);
rng(old_rng);

end
