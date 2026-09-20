function manifest = profile_tsfsb_saved_results( ...
        source_feature_root, subset_name, destination_root)
%PROFILE_TSFSB_SAVED_RESULTS Reprofile one solver subset from accepted data.
%
%   Ported from the C02 profile_c02_saved_results.m (commit 846d5c5f),
%   adapted to the ten-solver TSFSB pool and extended with a target
%   recomputation check: after each subset replot, the mean
%   history-based performance curves stored in the subset curves.mat are
%   compared against curves recomputed from the subset's own saved merit
%   histories (tsfsb_recompute_perf_curves). The Moré-Wild targets
%   depend on the per-problem merit minima over the loaded solvers, so
%   this match proves that the targets came from the subset.

accepted_path = fullfile(source_feature_root, 'accepted_manifest.json');
if ~exist(accepted_path, 'file')
    error('profile_tsfsb_saved_results:MissingAcceptedManifest', ...
        'No accepted evaluation manifest exists under %s.', ...
        source_feature_root);
end
source_manifest = tsfsb_verify_manifest(accepted_path);
source_result = tsfsb_locate_result( ...
    source_feature_root, source_manifest.time_stamp);

spec = tsfsb_benchmark_spec();
if ~isfield(spec.subsets, subset_name)
    error('profile_tsfsb_saved_results:InvalidSubset', ...
        'Unknown TSFSB solver subset %s.', subset_name);
end
solver_indices = spec.subsets.(subset_name);
if numel(solver_indices) < 2
    error('profile_tsfsb_saved_results:SmallSubset', ...
        'OptiProfiler requires at least two solvers for subset profiling.');
end

profile_root = fullfile(destination_root, source_manifest.feature.name, ...
    subset_name);
accepted_profile_path = fullfile(profile_root, 'accepted_manifest.json');
if exist(accepted_profile_path, 'file')
    manifest = tsfsb_verify_manifest(accepted_profile_path);
    fprintf('TSFSB_PROFILE_SKIP_ACCEPTED %s %s\n', ...
        source_manifest.feature.name, subset_name);
    return;
end
if ~exist(profile_root, 'dir')
    mkdir(profile_root);
end

source_pdf_hashes = source_direct_pdf_hashes(source_result);
before_markers = marker_paths(profile_root);
options = tsfsb_direct_profile_options(solver_indices);
options.load = source_manifest.time_stamp;
options.solvers_to_load = solver_indices;
options.savepath = profile_root;
options.benchmark_id = '.';
options.silent = false;

old_folder = pwd();
cleanup = onCleanup(@() cd(old_folder));
cd(source_feature_root);
benchmark(options);
clear cleanup

after_markers = marker_paths(profile_root);
new_markers = setdiff(after_markers, before_markers);
if numel(new_markers) ~= 1
    error('profile_tsfsb_saved_results:ResultMarkerCount', ...
        'Expected one new subset result marker and found %d.', ...
        numel(new_markers));
end
profile_result = tsfsb_locate_result(profile_root, ...
    marker_time_stamp(new_markers{1}));

context = struct();
context.kind = 'subset_profile';
context.feature = source_manifest.feature;
context.expected_solver_names = ...
    {spec.pool(solver_indices).display_name};
context.expected_machine_ids = ...
    {spec.pool(solver_indices).internal_label};
context.expected_solver_indices = solver_indices;
context.expected_problem_names = cellstr(source_manifest.problem_names);
context.expected_problem_dims = source_manifest.problem_dimensions;
context.expected_n_runs = source_manifest.n_runs;
context.expected_worker_count = [];
context.base_seed = source_manifest.base_seed;
context.budget_factor = source_manifest.budget_factor;
context.parent_manifest = accepted_path;
context.versions = source_manifest.versions;
[manifest, profile_data] = tsfsb_audit_result(profile_result, context);

source_loaded = load(source_result.data_file, 'results_plibs');
source_data = source_loaded.results_plibs{1};
assert_same_saved_data(source_data, profile_data, solver_indices);
if ~isequal(source_pdf_hashes, source_direct_pdf_hashes(source_result))
    error('profile_tsfsb_saved_results:SourcePdfChanged', ...
        ['At least one source direct output PDF changed during ', ...
        'subset profiling.']);
end

% Target recomputation check: the saved subset curves must match the
% curves recomputed from the subset's own merit data, which fixes the
% Moré-Wild targets to the loaded solver subset.
curves_loaded = load(profile_result.curves_file, 'curves');
max_deviation = 0;
for i_tol = spec.displayed_tolerance_orders
    tolerance = 10^(-i_tol);
    recomputed = tsfsb_recompute_perf_curves(profile_data, tolerance);
    for i_solver = 1:numel(solver_indices)
        saved_curve = ...
            curves_loaded.curves{i_tol}.hist.perf{i_solver, end};
        recomputed_curve = recomputed{i_solver};
        if ~isequal(size(saved_curve), size(recomputed_curve))
            error('profile_tsfsb_saved_results:TargetRecomputationMismatch', ...
                ['Curve shape mismatch at tolerance order %d, solver ', ...
                '%d. The subset targets may not come from the subset ', ...
                'merit data.'], i_tol, i_solver);
        end
        deviation = max(abs(saved_curve(:) - recomputed_curve(:)));
        max_deviation = max(max_deviation, deviation);
        if deviation > 1e-10
            error('profile_tsfsb_saved_results:TargetRecomputationMismatch', ...
                ['Saved subset curve deviates from the curve recomputed ', ...
                'from the subset merit data by %g at tolerance order ', ...
                '%d, solver %d.'], deviation, i_tol, i_solver);
        end
    end
end
manifest.target_recomputation = struct( ...
    'checked', true, ...
    'tolerance_orders', spec.displayed_tolerance_orders, ...
    'max_curve_deviation', max_deviation);

tsfsb_write_json(fullfile(profile_result.root, 'tsfsb_manifest.json'), ...
    manifest);
write_lines(fullfile(profile_result.root, 'TSFSB_COMPLETE'), {'accepted'});
tsfsb_write_json(accepted_profile_path, manifest);
fprintf('TSFSB_PROFILE_ACCEPTED %s %s %s\n', ...
    source_manifest.feature.name, subset_name, profile_result.time_stamp);

end

function assert_same_saved_data(source, profile, solver_indices)

if ~isequaln(profile.fun_histories, ...
        source.fun_histories(:, solver_indices, :, :)) ...
        || ~isequaln(profile.fun_outs, source.fun_outs(:, solver_indices, :)) ...
        || ~isequaln(profile.n_evals, source.n_evals(:, solver_indices, :))
    error('profile_tsfsb_saved_results:SavedDataMismatch', ...
        'Subset profiling did not preserve the selected saved solver data.');
end
if isfield(source, 'solver_abnormal_terminations') ...
        && ~isequaln(profile.solver_abnormal_terminations, ...
        source.solver_abnormal_terminations(:, solver_indices, :))
    error('profile_tsfsb_saved_results:AbnormalFlagMismatch', ...
        'Subset profiling changed abnormal termination flags.');
end
if isfield(source, 'solver_output_fallbacks') ...
        && ~isequaln(profile.solver_output_fallbacks, ...
        source.solver_output_fallbacks(:, solver_indices, :))
    error('profile_tsfsb_saved_results:FallbackFlagMismatch', ...
        'Subset profiling changed output fallback flags.');
end

end

function hashes = source_direct_pdf_hashes(result)

hashes = { ...
    tsfsb_sha256(result.performance_history_pdf), ...
    tsfsb_sha256(result.performance_output_pdf)};

end

function paths = marker_paths(search_root)

markers = dir(fullfile(search_root, '**', 'time_stamp_*.txt'));
paths = arrayfun(@(item) fullfile(item.folder, item.name), ...
    markers, 'UniformOutput', false);

end

function time_stamp = marker_time_stamp(marker_path)

[~, name] = fileparts(marker_path);
time_stamp = name(12:end);

end

function write_lines(file_path, lines)

file_id = fopen(file_path, 'w');
if file_id < 0
    error('profile_tsfsb_saved_results:RecordOpenFailed', ...
        'Cannot create record %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '%s\n', lines{:});
clear cleanup

end
