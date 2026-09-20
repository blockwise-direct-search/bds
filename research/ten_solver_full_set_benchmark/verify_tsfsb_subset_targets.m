function verify_tsfsb_subset_targets(fixture_root)
%VERIFY_TSFSB_SUBSET_TARGETS Prove subset target recomputation in load mode.
%
%   New for TSFSB. Builds a synthetic minimal OptiProfiler stamp
%   directory with a hand-crafted data_for_loading.mat (three fake
%   solvers, two fake problems, one run; solver 3 is uniquely best on
%   problem 1) and calls benchmark in load mode with solvers_to_load
%   [1 2] and [1 2 3]. It asserts that the saved performance curves of
%   the [1 2] replot match the curves recomputed from the solver 1-2
%   merit slice (subset targets) and not the curves implied by the
%   global minima, and that the [1 2 3] replot uses the global minima.
%   This is the sensitivity fixture proving that OptiProfiler recomputes
%   the Moré-Wild targets from the loaded solver subset.

if nargin < 1 || isempty(fixture_root)
    fixture_root = tempname;
end

if isempty(which('benchmark'))
    home_dir = getenv('HOME');
    optiprofiler_root = fullfile(home_dir, 'local', 'optiprofiler_c02');
    addpath(fullfile(optiprofiler_root, 'matlab', 'optiprofiler', 'src'));
    addpath(fullfile(optiprofiler_root, 'matlab', 'optiprofiler', ...
        'problem_libs'));
end
if isempty(which('benchmark'))
    error('verify_tsfsb_subset_targets:MissingOptiProfiler', ...
        'Cannot find the OptiProfiler benchmark function.');
end

if exist(fixture_root, 'dir')
    error('TSFSB:ExistingFixture', 'Refusing to overwrite existing fixture directory.');
end
source_root = fullfile(fixture_root, 'source');
time_stamp = '20260920_000000';
test_log = fullfile(source_root, 'synthetic_stamp', 'test_log');
mkdir(test_log);
results_plibs = {synthetic_results()};
save(fullfile(test_log, 'data_for_loading.mat'), 'results_plibs', '-v7.3');
file_id = fopen(fullfile(test_log, ['time_stamp_', time_stamp, '.txt']), 'w');
assert(file_id >= 0);
fprintf(file_id, '%s', time_stamp);
fclose(file_id);

source_loaded = load(fullfile(test_log, 'data_for_loading.mat'), ...
    'results_plibs');
source_data = source_loaded.results_plibs{1};

subset_result = run_load_mode(source_root, time_stamp, [1, 2], ...
    fullfile(fixture_root, 'out_subset'));
full_result = run_load_mode(source_root, time_stamp, [1, 2, 3], ...
    fullfile(fixture_root, 'out_full'));

subset_data = load_result_data(subset_result);
full_data = load_result_data(full_result);

% Exact slice sanity: the loaded subset data equal the source slice.
assert(isequaln(subset_data.merit_histories, ...
    source_data.merit_histories(:, [1, 2], :, :)));
assert(isequaln(full_data.merit_histories, source_data.merit_histories));

% The per-problem merit minima (the More-Wild targets) must be the
% subset minima for [1 2] and the global minima for [1 2 3].
tolerance = 1e-1;
subset_minimum = problem_minimum(subset_data, 1);
full_minimum = problem_minimum(full_data, 1);
assert(subset_minimum == 0.5, ...
    'The subset target on problem 1 must be the solver 1-2 minimum.');
assert(full_minimum == 0.1, ...
    'The full-pool target on problem 1 must be the global minimum.');
assert(subset_minimum ~= full_minimum);

% The saved curves of each replot must equal the curves recomputed from
% its own loaded merit data.
subset_curves = load(fullfile(subset_result.test_log, 'curves.mat'), ...
    'curves');
full_curves = load(fullfile(full_result.test_log, 'curves.mat'), ...
    'curves');
recomputed_subset = tsfsb_recompute_perf_curves(subset_data, tolerance);
recomputed_full = tsfsb_recompute_perf_curves(full_data, tolerance);
for i_solver = 1:2
    assert_curve_match( ...
        subset_curves.curves{1}.hist.perf{i_solver, end}, ...
        recomputed_subset{i_solver}, 'subset', i_solver);
end
for i_solver = 1:3
    assert_curve_match( ...
        full_curves.curves{1}.hist.perf{i_solver, end}, ...
        recomputed_full{i_solver}, 'full', i_solver);
end

% Sensitivity: recomputing the subset curves with the global target must
% NOT reproduce the saved subset curves, and the saved solver-1 curve
% must change when solver 3 is included.
recomputed_global_target = tsfsb_recompute_perf_curves( ...
    truncate_solvers(source_data, [1, 2]), tolerance);
assert(isequaln(recomputed_global_target{1}, recomputed_subset{1}));
global_data_with_subset_solvers = subset_data;
global_data_with_subset_solvers.merit_histories(:, 2, :, :) = ...
    source_data.merit_histories(:, 3, :, :);
global_target_curve = tsfsb_recompute_perf_curves( ...
    global_data_with_subset_solvers, tolerance);
deviation = curve_deviation( ...
    subset_curves.curves{1}.hist.perf{1, end}, global_target_curve{1});
assert(deviation > 1e-6, ...
    ['The subset curves must depend on the subset targets: ', ...
    'replacing the problem 1 minimum must change them.']);
assert(~isequaln(subset_curves.curves{1}.hist.perf{1, end}, ...
    full_curves.curves{1}.hist.perf{1, end}), ...
    ['The solver 1 curve must differ between the [1 2] and the ', ...
    '[1 2 3] replots because the targets are recomputed.']);

fprintf('VERIFY_TSFSB_SUBSET_TARGETS_OK\n');

end

function results_plib = synthetic_results()

% Problem 1: solver 3 is uniquely best (minimum 0.1); solvers 1 and 2
% bottom out at 0.5 and 0.6. The histories are chosen so that the
% first-passage index of solver 1 differs between the subset target
% (0.5, threshold 1.45 at tau 1e-1) and the global target (0.1,
% threshold 1.09).
history_one = zeros(3, 8);
history_one(1, :) = [10, 3, 1.4, 1.2, 0.5, 0.5, 0.5, 0.5];
history_one(2, :) = [10, 4, 2, 0.6, 0.6, 0.6, 0.6, 0.6];
history_one(3, :) = [10, 5, 1, 0.1, 0.1, 0.1, 0.1, 0.1];
history_two = zeros(3, 8);
history_two(1, :) = [8, 4, 1, 0.2, 0.2, 0.2, 0.2, 0.2];
history_two(2, :) = [8, 3, 0.3, 0.3, 0.3, 0.3, 0.3, 0.3];
history_two(3, :) = [8, 6, 2, 0.4, 0.4, 0.4, 0.4, 0.4];

merit_histories = zeros(2, 3, 1, 8);
merit_histories(1, :, 1, :) = history_one;
merit_histories(2, :, 1, :) = history_two;

results_plib = struct();
results_plib.plib = 's2mpj';
results_plib.feature_stamp = 'synthetic';
results_plib.solver_names = {'s1', 's2', 's3'};
results_plib.problem_names = {'P1', 'P2'};
results_plib.problem_types = {'u', 'u'};
results_plib.ptype = 'u';
results_plib.problem_dims = [2; 3];
results_plib.problem_mbs = [0; 0];
results_plib.problem_mlcons = [0; 0];
results_plib.problem_mnlcons = [0; 0];
results_plib.problem_mcons = [0; 0];
results_plib.mindim = 2;
results_plib.maxdim = 3;
results_plib.minb = 0;
results_plib.maxb = 0;
results_plib.minlcon = 0;
results_plib.maxlcon = 0;
results_plib.minnlcon = 0;
results_plib.maxnlcon = 0;
results_plib.mincon = 0;
results_plib.maxcon = 0;
results_plib.fun_histories = merit_histories;
results_plib.maxcv_histories = zeros(2, 3, 1, 8);
results_plib.fun_outs = merit_histories(:, :, :, end);
results_plib.maxcv_outs = zeros(2, 3, 1);
results_plib.fun_inits = [10; 8];
results_plib.maxcv_inits = [0; 0];
results_plib.n_evals = 8 * ones(2, 3, 1);
results_plib.computation_times = ones(2, 3, 1);
results_plib.solvers_successes = true(2, 3, 1);
results_plib.merit_histories = merit_histories;
results_plib.merit_outs = merit_histories(:, :, :, end);
results_plib.merit_inits = [10; 8];
results_plib.solver_abnormal_terminations = false(2, 3, 1);
results_plib.solver_output_fallbacks = false(2, 3, 1);

end

function result = run_load_mode(source_root, time_stamp, solvers_to_load, ...
        output_root)

options = struct();
options.feature_name = 'plain';
options.load = time_stamp;
options.solvers_to_load = solvers_to_load;
solver_names_all = {'s1', 's2', 's3'};
options.solver_names = solver_names_all(solvers_to_load);
options.benchmark_id = '.';
options.savepath = output_root;
options.silent = true;
options.draw_hist_plots = 'none';
options.semilogx = true;
options.max_tol_order = 4;
options.summarize_performance_profiles = true;
options.summarize_data_profiles = false;
options.summarize_log_ratio_profiles = false;
options.summarize_output_based_profiles = true;

old_folder = pwd();
cleanup = onCleanup(@() cd(old_folder));
cd(source_root);
benchmark(options);
clear cleanup

result = tsfsb_locate_result(output_root);

end

function data = load_result_data(result)

loaded = load(result.data_file, 'results_plibs');
data = loaded.results_plibs{1};

end

function value = problem_minimum(results_plib, i_problem)

slice = results_plib.merit_histories(i_problem, :, :, :);
value = min(slice(:), [], 'omitnan');
value = min(value, results_plib.merit_inits(i_problem, :), 'omitnan');

end

function data = truncate_solvers(data, solver_indices)

data.solver_names = data.solver_names(solver_indices);
data.merit_histories = data.merit_histories(:, solver_indices, :, :);
data.merit_outs = data.merit_outs(:, solver_indices, :);

end

function assert_curve_match(saved_curve, recomputed_curve, label, i_solver)

assert(isequal(size(saved_curve), size(recomputed_curve)), ...
    'Curve shape mismatch in the %s replot, solver %d.', label, i_solver);
deviation = curve_deviation(saved_curve, recomputed_curve);
assert(deviation <= 1e-10, ...
    ['The saved %s curve of solver %d deviates from the curve ', ...
    'recomputed from the loaded merit data by %g.'], ...
    label, i_solver, deviation);

end

function deviation = curve_deviation(curve_a, curve_b)

if ~isequal(size(curve_a), size(curve_b))
    deviation = Inf;
    return;
end
deviation = max(abs(curve_a(:) - curve_b(:)));

end
