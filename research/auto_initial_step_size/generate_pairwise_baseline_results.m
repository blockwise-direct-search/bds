function manifest = generate_pairwise_baseline_results(source_data, output_root)
%GENERATE_PAIRWISE_BASELINE_RESULTS Compare every auto pair with unit steps.
%
% Every score and figure is produced by OptiProfiler benchmark(..., load=...).
% The 200N data is a per-problem prefix of the completed 500N histories.

if nargin < 2
    error('generate_pairwise_baseline_results:ArgumentsRequired', ...
        'Provide source_data and output_root.');
end

source_data = char(source_data);
output_root = char(output_root);
if ~exist(source_data, 'file')
    error('generate_pairwise_baseline_results:SourceMissing', ...
        'Cannot find %s.', source_data);
end
if ~exist(output_root, 'dir')
    mkdir(output_root);
end

optiprofiler_root = fullfile(getenv('HOME'), 'local', 'optiprofiler', ...
    'matlab', 'optiprofiler');
addpath(fullfile(optiprofiler_root, 'src'));
addpath(fullfile(optiprofiler_root, 'problem_libs'));

loaded = load(source_data, 'results_plibs');
assert(isscalar(loaded.results_plibs), ...
    'Expected one problem library in the source data.');
source_result = loaded.results_plibs{1};
validate_source(source_result);

source_stamp = source_timestamp(source_data);
source_benchmark_dir = fileparts(fileparts(fileparts(source_data)));
source_parent = fileparts(source_benchmark_dir);
source_benchmark_id = basename(source_benchmark_dir);

work_root = fullfile(output_root, '_generation_work');
if exist(work_root, 'dir')
    rmdir(work_root, 's');
end
mkdir(work_root);

derived_root = fullfile(work_root, 'h200n_load');
derived_id = 'auto_alpha_full17_h200n_history_prefix';
derived_stamp = '20260722_120000';
derived_log = fullfile(derived_root, derived_id, ...
    ['u_6_50_plain_', derived_stamp], 'test_log');
mkdir(derived_log);
derived_result = truncate_to_200n(source_result);
results_plibs = {derived_result};
save(fullfile(derived_log, 'data_for_loading.mat'), ...
    'results_plibs', '-v7.3');
write_timestamp(derived_log, derived_stamp);
validate_derived(source_result, derived_result);

old_dir = pwd;
cleanup_dir = onCleanup(@() cd(old_dir));

scores_200 = pairwise_scores(derived_root, derived_stamp, derived_id, ...
    derived_result.solver_names, 200, fullfile(work_root, 'scores_200n'));
scores_500 = pairwise_scores(source_parent, source_stamp, ...
    source_benchmark_id, source_result.solver_names, 500, ...
    fullfile(work_root, 'scores_500n'));

[incumbent_200, artifacts_200] = incumbent_summary(derived_root, ...
    derived_stamp, derived_id, 200, ...
    fullfile(work_root, 'figure_200n'));
assert(max(abs(scores_200(14, :) - incumbent_200(:)')) <= 1e-12, ...
    'The 200N incumbent scores are inconsistent.');
save_incumbent_artifacts(output_root, artifacts_200, 200);

[incumbent_500, artifacts_500] = incumbent_summary(source_parent, ...
    source_stamp, source_benchmark_id, 500, ...
    fullfile(work_root, 'figure_500n'));
assert(all(isfinite(scores_200(2:end, :)), 'all'), ...
    'At least one 200N pairwise score is not finite.');
assert(all(isfinite(scores_500(2:end, :)), 'all'), ...
    'At least one 500N pairwise score is not finite.');
assert(max(abs(scores_500(14, :) - incumbent_500(:)')) <= 1e-12, ...
    'The 500N incumbent scores are inconsistent.');
save_incumbent_artifacts(output_root, artifacts_500, 500);

manifest = struct();
manifest.source_data = source_data;
manifest.source_timestamp = source_stamp;
manifest.problem_count = numel(source_result.problem_names);
manifest.source_solver_names = source_result.solver_names;
manifest.configuration_labels = source_result.solver_names(2:end);
manifest.pairwise_scores_200 = scores_200(2:end, :);
manifest.pairwise_scores_500 = scores_500(2:end, :);
manifest.score_columns = {'unit_baseline', 'auto_configuration'};
manifest.analysis_horizons = [200, 500];
manifest.tolerances = 10.^(-1:-1:-10);
manifest.output_based_profiles = false;
manifest.figure_200 = 'cx1_ctau1_vs_unit_200n.pdf';
manifest.figure_500 = 'cx1_ctau1_vs_unit_500n.pdf';
manifest.figure_data_200 = 'cx1_ctau1_vs_unit_200n.mat';
manifest.figure_data_500 = 'cx1_ctau1_vs_unit_500n.mat';
manifest.optiprofiler_root = optiprofiler_root;
manifest.optiprofiler_commit = git_value(optiprofiler_root, 'rev-parse HEAD');
manifest.generated_at = char(datetime('now'));
save(fullfile(output_root, 'pairwise_results.mat'), 'manifest');
write_manifest(fullfile(output_root, 'pairwise_results.txt'), manifest);

clear cleanup_dir
remove_tree(work_root);
fprintf('AUTO_ALPHA_PAIRWISE_SCORES_OK\n');
fprintf('AUTO_ALPHA_PAIRWISE_H200N_OK\n');
fprintf('AUTO_ALPHA_PAIRWISE_H500N_OK\n');

end

function save_incumbent_artifacts(output_root, artifacts, horizon_factor)

data_file = fullfile(output_root, sprintf( ...
    'cx1_ctau1_vs_unit_%dn.mat', horizon_factor));
pdf_file = fullfile(output_root, sprintf( ...
    'cx1_ctau1_vs_unit_%dn.pdf', horizon_factor));
copyfile(artifacts.native_summary, pdf_file);
artifacts = rmfield(artifacts, 'native_summary');
save(data_file, '-struct', 'artifacts');

end

function scores = pairwise_scores(load_root, load_stamp, benchmark_id, ...
        solver_names, horizon_factor, savepath)

scores = NaN(numel(solver_names), 2);
old_dir = pwd;
cleanup = onCleanup(@() cd(old_dir));
cd(load_root);
options = native_options(load_stamp, benchmark_id, solver_names(1:2), ...
    [1, 2], savepath, horizon_factor);
options.score_only = true;
options.silent = true;
for i_solver = 2:numel(solver_names)
    options.solver_names = solver_names([1, i_solver]);
    options.solvers_to_load = [1, i_solver];
    pair_scores = benchmark(options);
    assert(isequal(size(pair_scores), [2, 1]), ...
        'Unexpected pairwise score shape for solver %d.', i_solver);
    scores(i_solver, :) = pair_scores(:)';
end
clear cleanup

end

function [scores, artifacts] = incumbent_summary(load_root, load_stamp, ...
        benchmark_id, horizon_factor, savepath)

old_dir = pwd;
cleanup = onCleanup(@() cd(old_dir));
cd(load_root);
display_names = {'BDS + acceleration', ...
    'BDS + acceleration + auto (c_x=1, c_tau=1)'};
options = native_options(load_stamp, benchmark_id, display_names, ...
    [1, 14], savepath, horizon_factor);
options.score_only = false;
[scores, profiles, curves] = benchmark(options);
assert(isequal(size(scores), [2, 1]), 'Unexpected incumbent score shape.');
assert(size(profiles, 1) == 2 && size(profiles, 2) == 10 && ...
    size(profiles, 3) == 2, 'Unexpected incumbent profile score shape.');
assert(numel(curves) == 10 && size(curves{1}.hist.perf, 1) == 2, ...
    'Unexpected incumbent curve data.');
artifacts = struct();
artifacts.solver_scores = scores;
artifacts.profile_scores = profiles;
artifacts.curves = curves;
artifacts.solver_names = display_names;
artifacts.horizon_factor = horizon_factor;
artifacts.tolerances = 10.^(-1:-1:-10);
artifacts.native_summary = newest_native_summary(savepath);
clear cleanup

end

function summary = newest_native_summary(savepath)

summary_files = dir(fullfile(savepath, '**', 'summary_*.pdf'));
assert(isscalar(summary_files), ...
    'Expected exactly one native summary under %s.', savepath);
summary = fullfile(summary_files(1).folder, summary_files(1).name);

end

function options = native_options(load_stamp, benchmark_id, solver_names, ...
        solvers_to_load, savepath, horizon_factor)

options = struct();
options.load = load_stamp;
options.benchmark_id = benchmark_id;
options.solver_names = solver_names;
options.solvers_to_load = solvers_to_load;
options.savepath = savepath;
options.max_eval_factor = horizon_factor;
options.max_tol_order = 10;
options.summarize_performance_profiles = true;
options.summarize_data_profiles = true;
options.summarize_log_ratio_profiles = false;
options.summarize_output_based_profiles = false;
options.run_plain = false;
options.draw_hist_plots = 'none';
options.silent = false;
options.score_only = true;

end

function validate_source(result)

assert(numel(result.problem_names) == 122, 'Expected 122 source problems.');
assert(size(result.merit_histories, 2) == 17, ...
    'Expected 17 source solvers.');
expected_unit = 'unit-accelerated-all-on-500n';
expected_incumbent = 'auto-cx-1-ctau-1-accelerated-all-on-500n';
assert(strcmp(result.solver_names{1}, expected_unit), ...
    'Source solver 1 is not the accelerated unit-step baseline.');
assert(strcmp(result.solver_names{14}, expected_incumbent), ...
    'Source solver 14 is not the (c_x,c_tau)=(1,1) incumbent.');
assert(size(result.merit_histories, 3) == 1, 'Expected one source run.');
assert(all(result.solvers_successes(:)), ...
    'Expected every source solver run to succeed.');
if isfield(result, 'solver_abnormal_terminations')
    assert(~any(result.solver_abnormal_terminations(:)), ...
        'Source contains an abnormal solver termination.');
end
if isfield(result, 'solver_output_fallbacks')
    assert(~any(result.solver_output_fallbacks(:)), ...
        'Source contains a solver output fallback.');
end
for i_problem = 1:numel(result.problem_dims)
    assert(size(result.merit_histories, 4) >= ...
        500 * result.problem_dims(i_problem), ...
        'Source history is shorter than 500*N for problem %s.', ...
        result.problem_names{i_problem});
end

end

function derived = truncate_to_200n(source)

derived = source;
max_horizon = 200 * max(source.problem_dims);
history_fields = {'fun_histories', 'maxcv_histories', 'merit_histories'};
for i_field = 1:numel(history_fields)
    name = history_fields{i_field};
    source_history = source.(name);
    derived_history = NaN(size(source_history, 1), size(source_history, 2), ...
        size(source_history, 3), max_horizon);
    for i_problem = 1:numel(source.problem_names)
        horizon = 200 * source.problem_dims(i_problem);
        prefix = source_history(i_problem, :, :, 1:horizon);
        derived_history(i_problem, :, :, 1:horizon) = prefix;
        if horizon < max_horizon
            endpoint = source_history(i_problem, :, :, horizon);
            derived_history(i_problem, :, :, horizon + 1:end) = ...
                repmat(endpoint, [1, 1, 1, max_horizon - horizon]);
        end
    end
    derived.(name) = derived_history;
end
for i_problem = 1:numel(source.problem_names)
    horizon = 200 * source.problem_dims(i_problem);
    derived.n_evals(i_problem, :, :) = min( ...
        source.n_evals(i_problem, :, :), horizon);
end
derived.fun_outs(:) = NaN;
derived.maxcv_outs(:) = NaN;
derived.merit_outs(:) = NaN;
derived.computation_times(:) = NaN;
derived.feature_stamp = 'plain_h200n_prefix_from_500n';
derived.solver_names = cellfun(@(name) strrep(name, '-500n', ...
    '-h200n-prefix'), source.solver_names, 'UniformOutput', false);
if isfield(derived, 'results_plib_plain')
    derived = rmfield(derived, 'results_plib_plain');
end

end

function validate_derived(source, derived)

assert(size(derived.merit_histories, 4) == 200 * max(source.problem_dims), ...
    'Derived history has the wrong global length.');
for i_problem = 1:numel(source.problem_names)
    horizon = 200 * source.problem_dims(i_problem);
    assert(isequaln(source.merit_histories(i_problem, :, :, 1:horizon), ...
        derived.merit_histories(i_problem, :, :, 1:horizon)), ...
        'Derived prefix differs for problem %s.', source.problem_names{i_problem});
end

end

function stamp = source_timestamp(source_data)

listing = dir(fullfile(fileparts(source_data), 'time_stamp_*.txt'));
assert(isscalar(listing), 'Expected exactly one source time_stamp file.');
tokens = regexp(listing(1).name, ...
    '^time_stamp_(\d{8}_\d{6})\.txt$', 'tokens', 'once');
assert(~isempty(tokens), 'Invalid source time_stamp filename.');
stamp = tokens{1};

end

function write_timestamp(path, stamp)

fid = fopen(fullfile(path, ['time_stamp_', stamp, '.txt']), 'w');
assert(fid >= 0, 'Cannot write derived time_stamp file.');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s', stamp);
clear cleanup

end

function write_manifest(path, manifest)

fid = fopen(path, 'w');
assert(fid >= 0, 'Cannot write %s.', path);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'source_data=%s\n', manifest.source_data);
fprintf(fid, 'source_timestamp=%s\n', manifest.source_timestamp);
fprintf(fid, 'problem_count=%d\n', manifest.problem_count);
fprintf(fid, 'analysis_horizons=200*N,500*N\n');
fprintf(fid, 'tolerances=1e-1,...,1e-10\n');
fprintf(fid, 'score_columns=unit_baseline,auto_configuration\n');
fprintf(fid, 'output_based_profiles=false\n');
fprintf(fid, 'figure_200=%s\n', manifest.figure_200);
fprintf(fid, 'figure_500=%s\n', manifest.figure_500);
fprintf(fid, 'figure_data_200=%s\n', manifest.figure_data_200);
fprintf(fid, 'figure_data_500=%s\n', manifest.figure_data_500);
fprintf(fid, 'optiprofiler_commit=%s\n', manifest.optiprofiler_commit);
for i = 1:numel(manifest.configuration_labels)
    fprintf(fid, ['configuration_%02d=%s | 200N=%.15g,%.15g | ', ...
        '500N=%.15g,%.15g\n'], i, manifest.configuration_labels{i}, ...
        manifest.pairwise_scores_200(i, 1), ...
        manifest.pairwise_scores_200(i, 2), ...
        manifest.pairwise_scores_500(i, 1), ...
        manifest.pairwise_scores_500(i, 2));
end
fprintf(fid, 'generated_at=%s\n', manifest.generated_at);
clear cleanup

end

function name = basename(path)

[~, name] = fileparts(path);

end

function value = git_value(repo_dir, arguments)

[status, value] = system(sprintf( ...
    'git -c color.ui=false -C "%s" %s', repo_dir, arguments));
if status ~= 0
    value = 'unavailable';
else
    value = strtrim(value);
end

end

function remove_tree(path)

if exist(path, 'dir')
    rmdir(path, 's');
end

end
