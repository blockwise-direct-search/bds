function manifest = run_accelerated_auto_stopping_final_grid()
%RUN_ACCELERATED_AUTO_STOPPING_FINAL_GRID compares the final stop candidates.

stopping_dir = fileparts(mfilename('fullpath'));
auto_alpha_dir = fileparts(stopping_dir);
research_dir = fileparts(auto_alpha_dir);
repo_dir = fileparts(research_dir);
tests_dir = fullfile(repo_dir, 'tests');
cd(repo_dir);
setup;
addpath(tests_dir);
addpath(fullfile(tests_dir, 'competitors'));
optiprofiler_root = fullfile(getenv('HOME'), 'local', 'optiprofiler', ...
    'matlab', 'optiprofiler');
addpath(fullfile(optiprofiler_root, 'src'));
addpath(fullfile(optiprofiler_root, 'problem_libs'));
addpath(fullfile(optiprofiler_root, 'problem_libs', 's2mpj'));

problem_names = frozen_problem_names();
assert(numel(problem_names) == 122, 'Expected the frozen 122-problem set.');
[solver_names, stopping_parameters] = stopping_grid();
timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_root = fullfile(stopping_dir, 'testdata', ...
    ['accelerated_auto_stopping_final_grid_', timestamp]);
mkdir(run_root);

manifest = struct();
manifest.status = 'RUNNING';
manifest.started_at = char(datetime('now'));
manifest.run_root = run_root;
manifest.problem_names = problem_names;
manifest.problem_count = numel(problem_names);
manifest.dimension_limits = [6, 50];
manifest.features = {'plain', 'linearly_transformed'};
manifest.n_runs = 1;
manifest.max_eval_factor = 500;
manifest.tolerances = 10.^(-1:-1:-5);
manifest.solver_names = solver_names;
manifest.stopping_parameters = stopping_parameters;
manifest.base_strategy = 'acceleration all-on + auto (c_x,c_tau)=(1,1)';
manifest.selection_gate = ['match no-stop output solved fraction at every ', ...
    'target for both features; then minimize total evaluations'];
save(fullfile(run_root, 'manifest.mat'), 'manifest');

for i_feature = 1:numel(manifest.features)
    feature_name = manifest.features{i_feature};
    options = struct();
    options.problem_names = problem_names;
    options.mindim = 6;
    options.maxdim = 50;
    options.plibs = 's2mpj';
    options.feature_name = feature_name;
    options.feature_display_name = feature_name;
    options.n_runs = 1;
    options.seed = 0;
    options.max_eval_factor = 500;
    options.max_tol_order = 5;
    options.n_jobs = 40;
    options.draw_hist_plots = 'none';
    options.solver_verbose = 0;
    options.solver_names = solver_names;
    options.benchmark_id = ['accelerated_auto_stopping_final_grid_', ...
        feature_name];
    options.savepath = fullfile(run_root, feature_name);
    mkdir(options.savepath);

    fprintf('ACCELERATED_AUTO_STOPPING_FINAL_FEATURE_START=%s\n', ...
        feature_name);
    [solver_scores, profile_scores, curves] = profile_optiprofiler(options);
    output_performance_scores = profile_scores(:, 1:5, 2, 1);
    output_performance_mean = mean(output_performance_scores, 2);
    output_solved_fractions = extract_output_solved_fractions(curves, ...
        numel(solver_names), 5);
    [evaluation_totals, evaluation_means, evaluation_medians] = ...
        extract_evaluation_statistics(options.savepath, options.benchmark_id, ...
        solver_names);
    result_file = fullfile(run_root, [feature_name, '_scores.mat']);
    save(result_file, 'solver_scores', 'profile_scores', ...
        'output_performance_scores', 'output_performance_mean', ...
        'output_solved_fractions', 'evaluation_totals', ...
        'evaluation_means', 'evaluation_medians', 'curves', 'options');
    fprintf('ACCELERATED_AUTO_STOPPING_FINAL_%s_OUTPUT_PERF_MEAN=%s\n', ...
        upper(feature_name), join_numeric_row(output_performance_mean'));
    fprintf('ACCELERATED_AUTO_STOPPING_FINAL_%s_MIN_SOLVED=%s\n', ...
        upper(feature_name), ...
        join_numeric_row(min(output_solved_fractions, [], 2)'));
    fprintf('ACCELERATED_AUTO_STOPPING_FINAL_%s_EVALUATION_TOTALS=%s\n', ...
        upper(feature_name), join_numeric_row(evaluation_totals'));
    fprintf('ACCELERATED_AUTO_STOPPING_FINAL_FEATURE_OK=%s\n', feature_name);
end

manifest.status = 'COMPLETE';
manifest.finished_at = char(datetime('now'));
save(fullfile(run_root, 'manifest.mat'), 'manifest');
fprintf('ACCELERATED_AUTO_STOPPING_FINAL_RUN_ROOT=%s\n', run_root);
fprintf('ACCELERATED_AUTO_STOPPING_FINAL_GRID_OK\n');

end

function [solver_names, parameters] = stopping_grid()

solver_names = { ...
    'auto-accelerated-all-on-500n-no-optional-stop', ...
    'auto-accelerated-all-on-500n-default-combined-stop', ...
    'auto-accelerated-all-on-500n-function-stop-fw20-ft1em6-gw1-gt1em6', ...
    'auto-accelerated-all-on-500n-function-stop-fw20-ft1em5-gw1-gt1em6', ...
    'auto-accelerated-all-on-500n-function-stop-fw20-ft1em4-gw1-gt1em6', ...
    'auto-accelerated-all-on-500n-function-stop-fw15-ft1em6-gw1-gt1em6', ...
    'auto-accelerated-all-on-500n-function-stop-fw15-ft1em5-gw1-gt1em6', ...
    'auto-accelerated-all-on-500n-function-stop-fw10-ft1em6-gw1-gt1em6', ...
    'auto-accelerated-all-on-500n-stop-fw20-ft1em6-gw3-gt1em12', ...
    'auto-accelerated-all-on-500n-stop-fw20-ft1em6-gw5-gt1em10', ...
    'auto-accelerated-all-on-500n-stop-fw20-ft1em6-gw10-gt1em6', ...
    'auto-accelerated-all-on-500n-stop-fw20-ft1em5-gw5-gt1em10'};
parameters = [ ...
    stop_parameters('none', 20, 1e-6, 1, 1e-6), ...
    stop_parameters('combined', 20, 1e-6, 1, 1e-6), ...
    stop_parameters('function', 20, 1e-6, 1, 1e-6), ...
    stop_parameters('function', 20, 1e-5, 1, 1e-6), ...
    stop_parameters('function', 20, 1e-4, 1, 1e-6), ...
    stop_parameters('function', 15, 1e-6, 1, 1e-6), ...
    stop_parameters('function', 15, 1e-5, 1, 1e-6), ...
    stop_parameters('function', 10, 1e-6, 1, 1e-6), ...
    stop_parameters('combined', 20, 1e-6, 3, 1e-12), ...
    stop_parameters('combined', 20, 1e-6, 5, 1e-10), ...
    stop_parameters('combined', 20, 1e-6, 10, 1e-6), ...
    stop_parameters('combined', 20, 1e-5, 5, 1e-10)];

end

function parameters = stop_parameters(kind, func_window, func_tol, ...
        grad_window, grad_tol)

parameters = struct('stop_kind', kind, ...
    'func_window_size', func_window, 'func_tol', func_tol, ...
    'grad_window_size', grad_window, 'grad_tol', grad_tol);

end

function solved_fractions = extract_output_solved_fractions(curves, ...
        n_solvers, n_tolerances)

solved_fractions = nan(n_solvers, n_tolerances);
for i_tol = 1:n_tolerances
    for i_solver = 1:n_solvers
        curve = curves{i_tol}.out.perf{i_solver, end};
        solved_fractions(i_solver, i_tol) = curve(2, end);
    end
end

end

function [totals, means, medians] = extract_evaluation_statistics( ...
        savepath, benchmark_id, solver_names)

listing = dir(fullfile(savepath, [benchmark_id, '*'], '**', ...
    'data_for_loading.mat'));
assert(isscalar(listing), ...
    'Expected one OptiProfiler data_for_loading.mat file.');
loaded = load(fullfile(listing(1).folder, listing(1).name), ...
    'results_plibs');
assert(isscalar(loaded.results_plibs), ...
    'Expected exactly one problem library result.');
results = loaded.results_plibs{1};
assert(isequal(results.solver_names(:), solver_names(:)), ...
    'Solver ordering differs from the requested ordering.');
evaluation_counts = results.n_evals;
totals = squeeze(sum(evaluation_counts, [1, 3]));
means = squeeze(mean(evaluation_counts, [1, 3]));
medians = squeeze(median(evaluation_counts, 1));
totals = totals(:);
means = means(:);
medians = medians(:);

end

function text = join_numeric_row(values)

parts = arrayfun(@(value) sprintf('%.16g', value), values, ...
    'UniformOutput', false);
text = strjoin(parts, ',');

end

function names = frozen_problem_names()

selection = struct();
selection.ptype = 'u';
selection.mindim = 6;
selection.maxdim = 50;
selection.excludelist = { ...
    'DIAMON2DLS', 'DIAMON2D', 'DIAMON3DLS', 'DIAMON3D', ...
    'DMN15102LS', 'DMN15102', 'DMN15103LS', 'DMN15103', ...
    'DMN15332LS', 'DMN15332', 'DMN15333LS', 'DMN15333', ...
    'DMN37142LS', 'DMN37142', 'DMN37143LS', 'DMN37143', ...
    'ROSSIMP3_mp', 'BAmL1SPLS', 'FBRAIN3LS', 'GAUSS1LS', ...
    'GAUSS2LS', 'GAUSS3LS', 'HYDC20LS', 'HYDCAR6LS', ...
    'LUKSAN11LS', 'LUKSAN12LS', 'LUKSAN13LS', 'LUKSAN14LS', ...
    'LUKSAN17LS', 'LUKSAN21LS', 'LUKSAN22LS', 'METHANB8LS', ...
    'METHANL8LS', 'SPINLS', 'VESUVIALS', 'VESUVIOLS', ...
    'VESUVIOULS', 'YATP1CLS'};
names = s2mpj_select(selection);

end
