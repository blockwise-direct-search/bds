function outputs = generate_final_stopping_native_profiles(run_root, output_root)
%GENERATE_FINAL_STOPPING_NATIVE_PROFILES rerenders the final four-way summaries.

if nargin < 2
    error('generate_final_stopping_native_profiles:ArgumentsRequired', ...
        'Provide the completed run root and the output directory.');
end

run_root = char(run_root);
output_root = char(output_root);
run_root = absolute_existing_path(run_root);
if ~exist(output_root, 'dir')
    mkdir(output_root);
end
output_root = absolute_existing_path(output_root);
optiprofiler_root = fullfile(getenv('HOME'), 'local', 'optiprofiler', ...
    'matlab', 'optiprofiler');
addpath(fullfile(optiprofiler_root, 'src'));

work_root = fullfile(output_root, '_final_stopping_generation_work');
if exist(work_root, 'dir')
    rmdir(work_root, 's');
end
mkdir(work_root);
cleanup = onCleanup(@() cleanup_work_root(work_root));

features = {'plain', 'linearly_transformed'};
display_names = {'No-stop baseline', 'Function-only stop', ...
    'Gradient-only stop', 'Combined OR stop'};
outputs = struct();

for i_feature = 1:numel(features)
    feature_name = features{i_feature};
    source = dir(fullfile(run_root, feature_name, '**', ...
        'data_for_loading.mat'));
    assert(isscalar(source), ...
        'Expected exactly one raw result file for feature %s.', feature_name);
    source_data = fullfile(source.folder, source.name);
    load_stamp = source_timestamp(source_data);
    benchmark_dir = fileparts(fileparts(fileparts(source_data)));
    load_root = fileparts(benchmark_dir);
    benchmark_id = basename(benchmark_dir);

    old_dir = pwd;
    cd_cleanup = onCleanup(@() cd(old_dir));
    cd(load_root);
    options = struct('load', load_stamp, 'benchmark_id', benchmark_id, ...
        'feature_name', feature_name, ...
        'solver_names', {display_names}, 'solvers_to_load', 1:4, ...
        'savepath', fullfile(work_root, feature_name), ...
        'max_eval_factor', 500, 'max_tol_order', 5, ...
        'summarize_performance_profiles', true, ...
        'summarize_data_profiles', false, ...
        'summarize_log_ratio_profiles', false, ...
        'summarize_output_based_profiles', true, ...
        'run_plain', false, 'draw_hist_plots', 'none', ...
        'score_only', false, 'silent', false);
    [solver_scores, profile_scores, curves] = benchmark(options);
    clear cd_cleanup

    summary = dir(fullfile(options.savepath, '**', 'summary_*.pdf'));
    assert(isscalar(summary), ...
        'Expected exactly one OptiProfiler summary for feature %s.', ...
        feature_name);
    destination = fullfile(output_root, sprintf( ...
        '%s_no_stop_function_gradient_combined_500n_optiprofiler.pdf', ...
        feature_name));
    copyfile(fullfile(summary.folder, summary.name), destination);
    outputs.(feature_name) = struct('source_data', source_data, ...
        'display_names', {display_names}, 'summary_pdf', destination, ...
        'solver_scores', solver_scores, 'profile_scores', profile_scores, ...
        'curves', {curves});
end

save(fullfile(output_root, 'final_stopping_native_scores.mat'), 'outputs');
clear cleanup
cleanup_work_root(work_root);
fprintf('FINAL_STOPPING_NATIVE_PROFILES_OK\n');

end

function stamp = source_timestamp(source_data)
listing = dir(fullfile(fileparts(source_data), 'time_stamp_*.txt'));
assert(isscalar(listing), 'Expected exactly one source timestamp marker.');
tokens = regexp(listing.name, ...
    '^time_stamp_(\d{8}_\d{6})\.txt$', 'tokens', 'once');
assert(~isempty(tokens), 'Could not parse the source timestamp marker.');
stamp = tokens{1};
end

function name = basename(path_name)
[~, name] = fileparts(path_name);
end

function absolute_path = absolute_existing_path(path_name)
[status, attributes] = fileattrib(path_name);
assert(status, 'Could not resolve path: %s', path_name);
absolute_path = attributes.Name;
end

function cleanup_work_root(work_root)
if exist(work_root, 'dir')
    rmdir(work_root, 's');
end
end
