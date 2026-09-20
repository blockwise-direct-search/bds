function manifests = run_tsfsb_benchmark(user_options)
%RUN_TSFSB_BENCHMARK Execute fixed TSFSB feature evaluations with safe restart.
%
%   Ported from the C02 run_c02_benchmark.m (commit 846d5c5f) with the
%   TSFSB changes: the runner requires a frozen problem manifest and
%   passes its names explicitly through options.problem_names (it never
%   passes an excludelist to OptiProfiler), it calls OptiProfiler benchmark(solvers,
%   options) directly with handles from tsfsb_solver_handles, it deletes
%   any existing parallel pool before each call so that the fresh
%   30-worker pool inherits the runner path, and it commits artifacts in
%   the C02 order: manifest JSON plus audit markdown, then the
%   TSFSB_COMPLETE marker, then accepted_manifest.json.

if nargin < 1
    user_options = struct();
end
if ~isfield(user_options, 'artifact_root') || isempty(user_options.artifact_root)
    error('run_tsfsb_benchmark:MissingArtifactRoot', ...
        'user_options.artifact_root is required.');
end

spec = tsfsb_benchmark_spec();
features = select_features(spec.features, user_options);
[pool, ~] = tsfsb_solver_pool();
problem_set = effective_problem_set(spec, user_options);
tsfsb_setup_paths();
manifests = cell(1, numel(features));

for i_feature = 1:numel(features)
    feature = features(i_feature);
    feature_root = fullfile(user_options.artifact_root, ...
        'evaluations', feature.name);
    accepted_path = fullfile(feature_root, 'accepted_manifest.json');
    if exist(accepted_path, 'file')
        manifest = tsfsb_verify_manifest(accepted_path);
        verify_accepted_root(manifest, feature_root);
        assert(isequal(cellstr(manifest.problem_names(:)), problem_set.names(:)), ...
            'TSFSB:ResumeProblemMismatch');
        assert(isequal(cellstr(manifest.solver_names(:)), {pool.display_name}'), ...
            'TSFSB:ResumeSolverMismatch');
        assert(manifest.n_runs == feature.n_runs && ...
            manifest.base_seed == effective_seed(spec,user_options), 'TSFSB:ResumeProtocolMismatch');
        manifests{i_feature} = manifest;
        fprintf('TSFSB_SKIP_ACCEPTED %s\n', feature.name);
        continue;
    end

    if ~exist(feature_root, 'dir')
        mkdir(feature_root);
    end
    before_markers = marker_paths(feature_root);
    bundle = tsfsb_solver_handles(feature);
    trace_parent = fullfile(feature_root, 'raw_traces');
    if ~exist(trace_parent, 'dir'), mkdir(trace_parent); end
    trace_root = tempname(trace_parent);
    mkdir(trace_root);
    for i_solver = 1:numel(bundle.handles)
        solver = bundle.handles{i_solver};
        machine_id = bundle.machine_ids{i_solver};
        bundle.handles{i_solver} = @(fun,x0) tsfsb_trace_solver( ...
            solver, fun, x0, machine_id, trace_root);
    end
    options = evaluation_options(spec, pool, feature, feature_root, ...
        user_options, bundle, problem_set);
    try
        % Delete any existing pool so that the fresh pool created by the
        % parfor loop inside benchmark inherits the runner path (worker
        % visibility of the NOMAD, PRIMA, and BFO MEX paths comes from
        % client path inheritance at pool creation).
        delete(gcp('nocreate'));
        benchmark(bundle.handles, options);
        % The pool created by the parfor loop inside benchmark persists;
        % verify that every worker of that pool resolves the same solver
        % paths as the client.
        if ~isempty(gcp('nocreate'))
            tsfsb_setup_paths('verify_workers');
        end
        after_markers = marker_paths(feature_root);
        new_markers = setdiff(after_markers, before_markers);
        if numel(new_markers) ~= 1
            error('run_tsfsb_benchmark:ResultMarkerCount', ...
                'Expected one new result marker and found %d.', ...
                numel(new_markers));
        end
        result = tsfsb_locate_result(feature_root, ...
            marker_time_stamp(new_markers{1}));
        context = evaluation_context(spec, pool, feature, user_options, ...
            bundle, problem_set);
        [manifest, data] = tsfsb_audit_result(result, context);
        manifest.raw_traces = tsfsb_audit_traces(trace_root, data, context);
        write_result_records(result.root, manifest);
        write_solver_configuration(feature_root, bundle);
        write_complete_marker(result.root);
        tsfsb_write_json(accepted_path, manifest);
        manifests{i_feature} = manifest;
        fprintf('TSFSB_ACCEPTED %s %s\n', feature.name, result.time_stamp);
    catch error_record
        write_failure_record(feature_root, error_record);
        rethrow(error_record);
    end
end

end

function features = select_features(all_features, user_options)

if ~isfield(user_options, 'feature_names') ...
        || isempty(user_options.feature_names)
    features = all_features;
    return;
end
requested = cellstr(user_options.feature_names);
all_names = {all_features.name};
if numel(unique(requested)) ~= numel(requested) ...
        || ~all(ismember(requested, all_names))
    error('run_tsfsb_benchmark:InvalidFeatureNames', ...
        'feature_names must be unique names from tsfsb_benchmark_spec.');
end
[~, indices] = ismember(requested, all_names);
features = all_features(indices);

end

function problem_set = effective_problem_set(spec, user_options)

manifest_path = spec.problem_manifest;
if isfield(user_options, 'problem_manifest') ...
        && ~isempty(user_options.problem_manifest)
    manifest_path = user_options.problem_manifest;
end
if ~exist(manifest_path, 'file')
    error('run_tsfsb_benchmark:MissingProblemManifest', ...
        ['The frozen problem manifest is required and was not found ', ...
        'at %s. Build it with tsfsb_build_problem_manifest.'], ...
        manifest_path);
end
loaded = load(manifest_path, 'problem_names', 'problem_dims');
if ~isfield(loaded, 'problem_names') || ~isfield(loaded, 'problem_dims') ...
        || isempty(loaded.problem_names)
    error('run_tsfsb_benchmark:InvalidProblemManifest', ...
        'The problem manifest at %s lacks problem_names or problem_dims.', ...
        manifest_path);
end
problem_names = cellstr(loaded.problem_names);
problem_dims = double(loaded.problem_dims(:))';
if numel(problem_names) ~= numel(problem_dims)
    error('run_tsfsb_benchmark:InvalidProblemManifest', ...
        'The problem manifest names and dimensions have different lengths.');
end

if isfield(user_options, 'problem_names') ...
        && ~isempty(user_options.problem_names)
    requested = cellstr(user_options.problem_names);
    if ~all(ismember(requested, problem_names))
        error('run_tsfsb_benchmark:SmokeProblemsOutsideManifest', ...
            ['Smoke problem_names must be a subset of the frozen ', ...
            'problem manifest.']);
    end
    % The saved order follows the selector order, so the expected smoke
    % set is the manifest restricted to the requested names.
    keep = ismember(problem_names, requested);
    problem_names = problem_names(keep);
    problem_dims = problem_dims(keep);
end

problem_set = struct( ...
    'names', {problem_names}, ...
    'dims', problem_dims, ...
    'manifest_path', manifest_path);

end

function options = evaluation_options(spec, pool, feature, feature_root, ...
        user_options, bundle, problem_set)

options = tsfsb_direct_profile_options(1:numel(pool));
options.solver_isrand = bundle.solver_isrand;
feature_options = tsfsb_feature_options(feature);
feature_fields = fieldnames(feature_options);
for i = 1:numel(feature_fields)
    options.(feature_fields{i}) = feature_options.(feature_fields{i});
end
options.seed = effective_seed(spec, user_options);
options.run_plain = false;
options.solver_verbose = 0;
options.silent = false;
options.ptype = spec.problem_type;
options.mindim = spec.minimum_dimension;
options.maxdim = spec.maximum_dimension;
options.max_eval_factor = spec.budget_factor;
options.n_jobs = spec.worker_count;
options.plibs = spec.problem_library;
options.problem_names = problem_set.names;
options.savepath = feature_root;
options.benchmark_id = ['tsfsb_evaluations_', feature.name];
% History plots for every problem are not needed; the full evaluation
% data are saved regardless (draw_hist_plots only controls plotting,
% see benchmark.m and checkValidityProfileOptions.m).
options.draw_hist_plots = 'none';

end

function context = evaluation_context(spec, pool, feature, user_options, ...
        bundle, problem_set)

context = struct();
if isfield(user_options, 'problem_names') ...
        && ~isempty(user_options.problem_names)
    context.kind = 'smoke';
else
    context.kind = 'full_feature';
end
context.feature = feature;
context.expected_solver_names = bundle.solver_names;
context.expected_machine_ids = bundle.machine_ids;
context.expected_solver_indices = 1:numel(pool);
context.expected_problem_names = problem_set.names;
context.expected_problem_dims = problem_set.dims;
context.expected_n_runs = feature.n_runs;
context.expected_worker_count = spec.worker_count;
context.base_seed = effective_seed(spec, user_options);
context.budget_factor = spec.budget_factor;

end

function seed = effective_seed(spec, user_options)

seed = spec.base_seed;
if ~isfield(user_options, 'base_seed') || isempty(user_options.base_seed)
    return;
end
if ~isfield(user_options, 'problem_names') || isempty(user_options.problem_names)
    error('run_tsfsb_benchmark:FullBenchmarkSeedOverride', ...
        'The fixed full benchmark base seed cannot be overridden.');
end
validateattributes(user_options.base_seed, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'nonnegative'});
seed = double(user_options.base_seed);

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

function verify_accepted_root(manifest, feature_root)

if ~startsWith(manifest.result_root, feature_root)
    error('run_tsfsb_benchmark:InvalidAcceptedManifest', ...
        'The accepted manifest does not belong to %s.', feature_root);
end

end

function write_result_records(result_root, manifest)

tsfsb_write_json(fullfile(result_root, 'tsfsb_manifest.json'), manifest);
lines = { ...
    '# TSFSB artifact audit', '', ...
    ['Status: ', manifest.status], ...
    ['Kind: ', manifest.kind], ...
    ['Feature: ', manifest.feature.name], ...
    sprintf('Problems: %d', numel(manifest.problem_names)), ...
    sprintf('Runs: %d', manifest.n_runs), ...
    sprintf('Abnormal terminations: %d', ...
    manifest.abnormal_termination_count), ...
    sprintf('Output fallbacks: %d', manifest.output_fallback_count), ...
    'PDF postprocessing: false'};
write_lines(fullfile(result_root, 'tsfsb_audit.md'), lines);

end

function write_complete_marker(result_root)

write_lines(fullfile(result_root, 'TSFSB_COMPLETE'), {'accepted'});

end

function write_solver_configuration(feature_root, bundle)

details = bundle.details;
for i = 1:numel(details)
    details(i).options_static = sanitize_handles(details(i).options_static);
end
record = struct( ...
    'schema_version', 1, ...
    'machine_ids', {bundle.machine_ids}, ...
    'solver_names', {bundle.solver_names}, ...
    'solver_isrand', bundle.solver_isrand, ...
    'details', details);
tsfsb_write_json(fullfile(feature_root, 'tsfsb_solver_config.json'), record);

end

function value = sanitize_handles(value)

if isa(value, 'function_handle')
    value = func2str(value);
elseif isstruct(value)
    names = fieldnames(value);
    for i = 1:numel(names)
        value.(names{i}) = sanitize_handles(value.(names{i}));
    end
end

end

function write_failure_record(feature_root, error_record)

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
file_path = fullfile(feature_root, ['FAILED_', stamp, '.txt']);
write_lines(file_path, { ...
    error_record.identifier, error_record.message, ...
    getReport(error_record, 'extended', 'hyperlinks', 'off')});

end

function write_lines(file_path, lines)

file_id = fopen(file_path, 'w');
if file_id < 0
    error('run_tsfsb_benchmark:RecordOpenFailed', ...
        'Cannot create record %s.', file_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '%s\n', lines{:});
clear cleanup

end
