function outputs = generate_ten_solver_native_subset( ...
        source_data, solver_indices, horizon_factor, output_root)
%GENERATE_TEN_SOLVER_NATIVE_SUBSET Draw a fixed-color native subset profile.

if nargin < 4
    error('generate_ten_solver_native_subset:ArgumentsRequired', ...
        'Provide source data, solver indices, horizon, and output root.');
end
source_data = char(source_data);
output_root = char(output_root);
solver_indices = solver_indices(:)';
assert(exist(source_data, 'file') == 2, 'Cannot find the source data.');
assert(ismember(horizon_factor, [200, 500]), ...
    'The supported horizons are 200N and 500N.');

spec = ten_solver_benchmark_spec();
assert(numel(solver_indices) >= 2 && ...
    numel(unique(solver_indices)) == numel(solver_indices) && ...
    all(solver_indices >= 1 & solver_indices <= numel(spec.solver_names)), ...
    'Select at least two distinct solver indices from the frozen pool.');
if ~exist(output_root, 'dir')
    mkdir(output_root);
end

loaded = load(source_data, 'results_plibs');
assert(isscalar(loaded.results_plibs), ...
    'Expected exactly one problem-library result.');
source_result = loaded.results_plibs{1};
assert(isequal(source_result.solver_names(:), spec.solver_names(:)), ...
    'The source solver identities or ordering differ from the frozen pool.');

work_root = fullfile(output_root, '_native_subset_work');
if exist(work_root, 'dir')
    rmdir(work_root, 's');
end
mkdir(work_root);
cleanup = onCleanup(@() remove_work_root(work_root));

if horizon_factor == 200
    [load_root, load_stamp, benchmark_id] = ...
        create_prefix_source(source_result, work_root, horizon_factor);
else
    [load_root, load_stamp, benchmark_id] = locate_source(source_data);
end

old_dir = pwd;
cd_cleanup = onCleanup(@() cd(old_dir));
cd(load_root);
options = struct();
options.load = load_stamp;
options.benchmark_id = benchmark_id;
options.solver_names = spec.display_names(solver_indices);
options.solvers_to_load = solver_indices;
options.line_colors = spec.line_colors(solver_indices, :);
options.line_styles = spec.line_styles(solver_indices);
options.savepath = fullfile(work_root, 'rendered');
options.max_eval_factor = horizon_factor;
options.max_tol_order = spec.max_tol_order;
options.summarize_performance_profiles = true;
options.summarize_data_profiles = true;
options.summarize_log_ratio_profiles = false;
options.summarize_output_based_profiles = true;
options.run_plain = false;
options.draw_hist_plots = 'none';
options.score_only = false;
options.silent = false;
[solver_scores, profile_scores, curves] = benchmark(options);
clear cd_cleanup

summary = dir(fullfile(options.savepath, '**', 'summary_*.pdf'));
assert(isscalar(summary), 'Expected exactly one OptiProfiler native summary.');
summary_pdf = fullfile(output_root, sprintf( ...
    'ten_solver_subset_%dn_optiprofiler.pdf', horizon_factor));
copyfile(fullfile(summary.folder, summary.name), summary_pdf);

outputs = struct();
outputs.source_data = source_data;
outputs.solver_indices = solver_indices;
outputs.solver_names = spec.solver_names(solver_indices);
outputs.display_names = spec.display_names(solver_indices);
outputs.line_colors = spec.line_colors(solver_indices, :);
outputs.line_styles = spec.line_styles(solver_indices);
outputs.horizon_factor = horizon_factor;
outputs.solver_scores = solver_scores;
outputs.profile_scores = profile_scores;
outputs.curves = curves;
outputs.summary_pdf = summary_pdf;
save(fullfile(output_root, sprintf( ...
    'ten_solver_subset_%dn_scores.mat', horizon_factor)), 'outputs');

clear cleanup
remove_work_root(work_root);
fprintf('TEN_SOLVER_NATIVE_SUBSET_%dN_OK\n', horizon_factor);

end

function [load_root, load_stamp, benchmark_id] = create_prefix_source( ...
        source_result, work_root, horizon_factor)

prefix_result = truncate_histories(source_result, horizon_factor);
load_root = fullfile(work_root, 'prefix_source');
benchmark_id = sprintf('ten_solver_%dn_prefix', horizon_factor);
load_stamp = '20260727_120000';
data_dir = fullfile(load_root, benchmark_id, ...
    ['u_6_50_prefix_', load_stamp], 'test_log');
mkdir(data_dir);
results_plibs = {prefix_result};
save(fullfile(data_dir, 'data_for_loading.mat'), ...
    'results_plibs', '-v7.3');
marker = fullfile(data_dir, ['time_stamp_', load_stamp, '.txt']);
file_id = fopen(marker, 'w');
assert(file_id >= 0, 'Cannot create the prefix timestamp marker.');
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '%s\n', load_stamp);
clear cleanup

end

function result = truncate_histories(source, horizon_factor)

result = source;
max_horizon = horizon_factor*max(source.problem_dims);
history_fields = {'fun_histories', 'maxcv_histories', 'merit_histories'};
for i_field = 1:numel(history_fields)
    name = history_fields{i_field};
    source_history = source.(name);
    history = NaN(size(source_history, 1), size(source_history, 2), ...
        size(source_history, 3), max_horizon);
    for i_problem = 1:numel(source.problem_dims)
        horizon = horizon_factor*source.problem_dims(i_problem);
        history(i_problem, :, :, 1:horizon) = ...
            source_history(i_problem, :, :, 1:horizon);
        if horizon < max_horizon
            endpoint = source_history(i_problem, :, :, horizon);
            history(i_problem, :, :, horizon + 1:end) = repmat( ...
                endpoint, [1, 1, 1, max_horizon - horizon]);
        end
        result.n_evals(i_problem, :, :) = min( ...
            source.n_evals(i_problem, :, :), horizon);
    end
    result.(name) = history;
end

% Output-based 200N profiles use the incumbent inside each 200N prefix.
for i_problem = 1:numel(source.problem_dims)
    horizon = horizon_factor*source.problem_dims(i_problem);
    for i_solver = 1:size(source.merit_histories, 2)
        for i_run = 1:size(source.merit_histories, 3)
            merit_history = squeeze(source.merit_histories( ...
                i_problem, i_solver, i_run, 1:horizon));
            [best_merit, best_index] = min(merit_history, [], 'omitnan');
            result.merit_outs(i_problem, i_solver, i_run) = best_merit;
            result.fun_outs(i_problem, i_solver, i_run) = ...
                source.fun_histories(i_problem, i_solver, i_run, best_index);
            result.maxcv_outs(i_problem, i_solver, i_run) = ...
                source.maxcv_histories(i_problem, i_solver, i_run, best_index);
        end
    end
end
if isfield(result, 'results_plib_plain')
    result = rmfield(result, 'results_plib_plain');
end

end

function [load_root, load_stamp, benchmark_id] = locate_source(source_data)

markers = dir(fullfile(fileparts(source_data), 'time_stamp_*.txt'));
assert(isscalar(markers), 'Expected one source timestamp marker.');
tokens = regexp(markers.name, ...
    '^time_stamp_(\d{8}_\d{6})\.txt$', 'tokens', 'once');
assert(~isempty(tokens), 'Cannot parse the source timestamp marker.');
load_stamp = tokens{1};
benchmark_dir = fileparts(fileparts(fileparts(source_data)));
load_root = fileparts(benchmark_dir);
[~, benchmark_id] = fileparts(benchmark_dir);

end

function remove_work_root(work_root)

if exist(work_root, 'dir')
    rmdir(work_root, 's');
end

end
