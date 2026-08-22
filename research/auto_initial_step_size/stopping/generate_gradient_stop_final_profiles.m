function manifest = generate_gradient_stop_final_profiles(source_data, final_solver_index, output_root)
%GENERATE_GRADIENT_STOP_FINAL_PROFILES creates native 500N and 200N profiles.

if nargin < 3
    error('generate_gradient_stop_final_profiles:ArgumentsRequired', ...
        'Provide source_data, final_solver_index, and output_root.');
end

source_data = char(source_data);
output_root = char(output_root);
optiprofiler_root = fullfile(getenv('HOME'), 'local', 'optiprofiler', ...
    'matlab', 'optiprofiler');
addpath(fullfile(optiprofiler_root, 'src'));
loaded = load(source_data, 'results_plibs');
assert(isscalar(loaded.results_plibs), 'Expected one problem library.');
source_result = loaded.results_plibs{1};
assert(final_solver_index >= 2 && final_solver_index <= ...
    numel(source_result.solver_names), 'Invalid final solver index.');

if ~exist(output_root, 'dir')
    mkdir(output_root);
end
work_root = fullfile(output_root, '_generation_work');
if exist(work_root, 'dir')
    rmdir(work_root, 's');
end
mkdir(work_root);

solver_indices = [1, final_solver_index];
display_names = {'no-stop', 'final pure gradient stop'};
feature_label = canonical_feature_label(source_result.feature_stamp);
source_stamp = source_timestamp(source_data);
source_benchmark_dir = fileparts(fileparts(fileparts(source_data)));
source_parent = fileparts(source_benchmark_dir);
source_benchmark_id = basename(source_benchmark_dir);

profile_500 = native_profile(source_parent, source_stamp, ...
    source_benchmark_id, solver_indices, display_names, 500, ...
    fullfile(work_root, 'h500n'));
copyfile(profile_500.native_summary, ...
    fullfile(output_root, [feature_label, ...
    '_no_stop_vs_final_gradient_500n_optiprofiler.pdf']));

derived_root = fullfile(work_root, 'h200n_load');
derived_id = 'gradient_stop_final_h200n_history_prefix';
derived_stamp = '20260726_120000';
derived_log = fullfile(derived_root, derived_id, ...
    ['u_6_50_gradient_stop_prefix_', derived_stamp], 'test_log');
mkdir(derived_log);
derived_result = truncate_to_200n(source_result);
results_plibs = {derived_result};
save(fullfile(derived_log, 'data_for_loading.mat'), 'results_plibs', '-v7.3');
write_timestamp(derived_log, derived_stamp);

profile_200 = native_profile(derived_root, derived_stamp, derived_id, ...
    solver_indices, display_names, 200, fullfile(work_root, 'h200n'));
copyfile(profile_200.native_summary, ...
    fullfile(output_root, [feature_label, ...
    '_no_stop_vs_final_gradient_200n_optiprofiler.pdf']));

manifest = struct('source_data', source_data, ...
    'source_solver_names', {source_result.solver_names}, ...
    'feature_label', feature_label, ...
    'solver_indices', solver_indices, 'display_names', {display_names}, ...
    'tolerances', 10.^(-1:-1:-5), ...
    'profile_500', rmfield(profile_500, 'native_summary'), ...
    'profile_200', rmfield(profile_200, 'native_summary'), ...
    'uses_extra_function_evaluations', false, ...
    'generated_at', char(datetime('now')));
save(fullfile(output_root, [feature_label, ...
    '_final_native_profile_scores.mat']), 'manifest');
rmdir(work_root, 's');
fprintf('GRADIENT_STOP_FINAL_NATIVE_PROFILES_OK\n');

end

function profile = native_profile(load_root, load_stamp, benchmark_id, ...
        solver_indices, solver_names, horizon_factor, savepath)

old_dir = pwd;
cleanup = onCleanup(@() cd(old_dir));
cd(load_root);
options = struct('load', load_stamp, 'benchmark_id', benchmark_id, ...
    'solver_names', {solver_names}, 'solvers_to_load', solver_indices, ...
    'savepath', savepath, 'max_eval_factor', horizon_factor, ...
    'max_tol_order', 5, 'summarize_performance_profiles', true, ...
    'summarize_data_profiles', false, ...
    'summarize_log_ratio_profiles', false, ...
    'summarize_output_based_profiles', true, ...
    'run_plain', false, 'draw_hist_plots', 'none', ...
    'score_only', false, 'silent', false);
[solver_scores, profile_scores, curves] = benchmark(options);
summary = dir(fullfile(savepath, '**', 'summary_*.pdf'));
assert(isscalar(summary), 'Expected exactly one OptiProfiler summary.');
profile = struct('solver_scores', solver_scores, ...
    'profile_scores', profile_scores, 'curves', {curves}, ...
    'horizon_factor', horizon_factor, ...
    'native_summary', fullfile(summary.folder, summary.name));
clear cleanup

end

function result = truncate_to_200n(source)

result = source;
for i_problem = 1:numel(source.problem_dims)
    cutoff = 200 * source.problem_dims(i_problem);
    result.fun_histories(i_problem, :, :, cutoff + 1:end) = NaN;
    result.maxcv_histories(i_problem, :, :, cutoff + 1:end) = NaN;
    result.merit_histories(i_problem, :, :, cutoff + 1:end) = NaN;
end
result.n_evals = min(source.n_evals, 200 * reshape(source.problem_dims, [], 1, 1));

% Output-based profiles at 200N use the incumbent at the 200N horizon.
for i_problem = 1:numel(source.problem_dims)
    cutoff = 200 * source.problem_dims(i_problem);
    for i_solver = 1:size(source.merit_histories, 2)
        history = squeeze(source.merit_histories( ...
            i_problem, i_solver, 1, 1:cutoff));
        [~, best_index] = min(history, [], 'omitnan');
        result.merit_outs(i_problem, i_solver, 1) = history(best_index);
        result.fun_outs(i_problem, i_solver, 1) = squeeze( ...
            source.fun_histories(i_problem, i_solver, 1, best_index));
        result.maxcv_outs(i_problem, i_solver, 1) = squeeze( ...
            source.maxcv_histories(i_problem, i_solver, 1, best_index));
    end
end

end

function stamp = source_timestamp(source_data)
listing = dir(fullfile(fileparts(source_data), 'time_stamp_*.txt'));
assert(isscalar(listing), 'Expected exactly one source timestamp marker.');
tokens = regexp(listing(1).name, ...
    '^time_stamp_(\d{8}_\d{6})\.txt$', 'tokens', 'once');
assert(~isempty(tokens), 'Could not parse source timestamp marker.');
stamp = tokens{1};
end

function name = basename(path_name)
[~, name] = fileparts(path_name);
end

function write_timestamp(log_dir, stamp)
fid = fopen(fullfile(log_dir, ['time_stamp_', stamp, '.txt']), 'w');
assert(fid >= 0, 'Could not create timestamp marker.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', stamp);
end

function label = canonical_feature_label(feature_stamp)
if startsWith(feature_stamp, 'linearly_transformed')
    label = 'linearly_transformed';
else
    label = 'plain';
end
end
