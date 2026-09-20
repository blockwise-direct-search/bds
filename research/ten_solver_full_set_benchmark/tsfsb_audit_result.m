function [manifest, results] = tsfsb_audit_result(result, context)
%TSFSB_AUDIT_RESULT Validate and describe one direct OptiProfiler result.
%
%   Ported from the C02 c02_audit_result.m (commit 846d5c5f) with the
%   TSFSB adaptations: the expected problem set is the frozen problem
%   manifest (exact ordered match of problem names and dimensions), the
%   budget factor comes from the context, and the version record covers
%   the ten-solver dependency set.

required_context_fields = { ...
    'kind', 'feature', 'expected_solver_names', 'expected_solver_indices', ...
    'expected_machine_ids', 'expected_problem_names', ...
    'expected_problem_dims', 'expected_n_runs', 'expected_worker_count', ...
    'base_seed', 'budget_factor'};
for i = 1:numel(required_context_fields)
    if ~isfield(context, required_context_fields{i})
        error('tsfsb_audit_result:MissingContextField', ...
            'Missing context field %s.', required_context_fields{i});
    end
end

required_files = { ...
    result.data_file, result.options_user_file, result.options_refined_file, ...
    result.report_file, result.curves_file, result.profile_scores_file, ...
    result.performance_history_pdf, result.performance_output_pdf};
for i = 1:numel(required_files)
    if ~exist(required_files{i}, 'file')
        error('tsfsb_audit_result:MissingArtifact', ...
            'Missing required OptiProfiler artifact %s.', required_files{i});
    end
end

loaded = load(result.data_file, 'results_plibs');
if ~isfield(loaded, 'results_plibs') || isempty(loaded.results_plibs)
    error('tsfsb_audit_result:MissingResults', ...
        'The saved data do not contain results_plibs.');
end
results = loaded.results_plibs{1};

refined = load(result.options_refined_file, 'options_refined');
if ~isempty(context.expected_worker_count)
    if ~isfield(refined, 'options_refined') ...
            || ~isfield(refined.options_refined, 'n_jobs') ...
            || refined.options_refined.n_jobs ~= context.expected_worker_count
        error('tsfsb_audit_result:WorkerCountMismatch', ...
            'The refined worker count does not match the fixed protocol.');
    end
end

if ~isequal(results.solver_names(:), context.expected_solver_names(:))
    error('tsfsb_audit_result:SolverNamesMismatch', ...
        'The saved solver names do not match the expected pool order.');
end
if ~isequal(results.problem_names(:), context.expected_problem_names(:))
    error('tsfsb_audit_result:ProblemNamesMismatch', ...
        ['The saved problem names do not match the frozen problem ', ...
        'manifest in content or order.']);
end
problem_dimensions = double(results.problem_dims(:))';
if ~isequal(problem_dimensions, double(context.expected_problem_dims(:))')
    error('tsfsb_audit_result:ProblemDimensionsMismatch', ...
        ['The saved problem dimensions do not match the frozen problem ', ...
        'manifest.']);
end

n_runs = size(results.n_evals, 3);
if n_runs ~= context.expected_n_runs
    error('tsfsb_audit_result:RunCountMismatch', ...
        'Expected %d runs and found %d.', context.expected_n_runs, n_runs);
end
evaluation_budgets = context.budget_factor * ...
    reshape(problem_dimensions, [], 1, 1);
if any(~isfinite(results.n_evals(:))) || any(results.n_evals(:) < 0) ...
        || any(results.n_evals > evaluation_budgets, 'all')
    error('tsfsb_audit_result:InvalidEvaluationCount', ...
        ['At least one saved function evaluation count violates the ', ...
        '%dN budget.'], context.budget_factor);
end

abnormal = false(size(results.n_evals));
fallback = false(size(results.n_evals));
if isfield(results, 'solver_abnormal_terminations')
    abnormal = logical(results.solver_abnormal_terminations);
end
if isfield(results, 'solver_output_fallbacks')
    fallback = logical(results.solver_output_fallbacks);
end
if ~isequal(size(abnormal), size(results.n_evals)) ...
        || ~isequal(size(fallback), size(results.n_evals))
    error('tsfsb_audit_result:DiagnosticShapeMismatch', ...
        'The abnormal or fallback flags do not match n_evals.');
end

checksums = artifact_checksums(result.root);
manifest = struct();
manifest.schema_version = 1;
manifest.status = 'accepted';
manifest.kind = context.kind;
manifest.created_at = char(datetime('now', ...
    'TimeZone', 'Asia/Shanghai', 'Format', 'yyyy-MM-dd HH:mm:ss Z'));
manifest.result_root = result.root;
manifest.time_stamp = result.time_stamp;
manifest.feature = context.feature;
manifest.base_seed = context.base_seed;
manifest.run_identifiers = 1:context.expected_n_runs;
manifest.solver_indices = context.expected_solver_indices;
manifest.solver_names = results.solver_names;
manifest.machine_ids = context.expected_machine_ids;
manifest.display_names = results.solver_names;
manifest.problem_names = results.problem_names;
manifest.problem_dimensions = problem_dimensions;
manifest.n_runs = n_runs;
manifest.worker_count = context.expected_worker_count;
manifest.budget_factor = context.budget_factor;
manifest.evaluation_counts = results.n_evals;
manifest.abnormal_termination_count = nnz(abnormal);
manifest.output_fallback_count = nnz(fallback);
manifest.abnormal_termination_flags = abnormal;
manifest.output_fallback_flags = fallback;
manifest.pdf_postprocessing = false;
manifest.performance_history_pdf = result.performance_history_pdf;
manifest.performance_output_pdf = result.performance_output_pdf;
manifest.data_for_loading_sha256 = tsfsb_sha256(result.data_file);
manifest.artifact_checksums = checksums;
if isfield(context, 'versions')
    manifest.versions = context.versions;
else
    manifest.versions = source_versions();
end
if isfield(context, 'parent_manifest')
    manifest.parent_manifest = context.parent_manifest;
end

end

function checksums = artifact_checksums(result_root)

pdf_files = dir(fullfile(result_root, '**', '*.pdf'));
key_names = { ...
    fullfile('test_log', 'data_for_loading.mat'), ...
    fullfile('test_log', 'options_user.mat'), ...
    fullfile('test_log', 'options_refined.mat'), ...
    fullfile('test_log', 'curves.mat'), ...
    fullfile('test_log', 'profile_scores.mat'), ...
    fullfile('test_log', 'report.txt')};
checksums = repmat(struct('path', '', 'sha256', '', 'bytes', 0), ...
    1, numel(pdf_files) + numel(key_names));
for i = 1:numel(pdf_files)
    path = fullfile(pdf_files(i).folder, pdf_files(i).name);
    checksums(i) = checksum_entry(result_root, path, pdf_files(i).bytes);
end
for i = 1:numel(key_names)
    path = fullfile(result_root, key_names{i});
    info = dir(path);
    checksums(numel(pdf_files) + i) = ...
        checksum_entry(result_root, path, info.bytes);
end

end

function entry = checksum_entry(result_root, path, bytes)

relative_path = erase(path, [result_root, filesep]);
entry = struct( ...
    'path', relative_path, ...
    'sha256', tsfsb_sha256(path), ...
    'bytes', bytes);

end

function versions = source_versions()

module_dir = fileparts(mfilename('fullpath'));
bds_root = fileparts(fileparts(module_dir));
benchmark_path = which('benchmark');
s2mpj_select_path = which('s2mpj_select');
bds_path = which('bds');
expected_bds_path = fullfile(bds_root, 'src', 'bds.m');
if ~strcmp(bds_path, expected_bds_path)
    error('tsfsb_audit_result:UnexpectedBdsSource', ...
        'Expected production BDS at %s and found %s.', ...
        expected_bds_path, bds_path);
end

versions = struct();
versions.matlab = version;
versions.bds_root = bds_root;
versions.bds_path = bds_path;
versions.bds_commit = git_value(bds_root, 'rev-parse HEAD');
versions.bds_dirty_state = git_value(bds_root, 'status --porcelain');
versions.optiprofiler_path = benchmark_path;
versions.optiprofiler_commit = git_value( ...
    fileparts(benchmark_path), 'rev-parse HEAD');
versions.optiprofiler_dirty_state = git_value(fileparts(benchmark_path), 'status --porcelain');
versions.benchmark_sha256 = tsfsb_sha256(benchmark_path);
versions.feature_sha256 = tsfsb_sha256(which('Feature'));
versions.featured_problem_sha256 = tsfsb_sha256(which('FeaturedProblem'));
versions.s2mpj_path = s2mpj_select_path;
versions.s2mpj_commit = git_value( ...
    fileparts(s2mpj_select_path), 'rev-parse HEAD');
versions.bds_sha256 = tsfsb_sha256(bds_path);

key_files = { ...
    'nomad_wrapper', 'prima_wrapper', 'fminunc_budgeted_wrapper', ...
    'bfo_wrapper', 'fminsearch_wrapper', 'lam_paper_exact', ...
    'pds', 'newuoa', 'nomadOpt', 'bfo'};
for i = 1:numel(key_files)
    path = which(key_files{i});
    record = struct('path', path, 'sha256', '');
    if ~isempty(path) && exist(path, 'file')
        record.sha256 = tsfsb_sha256(path);
    end
    if ismember(key_files{i}, {'bfo','newuoa','nomadOpt'})
        record.commit = git_value(fileparts(path),'rev-parse HEAD');
        record.dirty_state = git_value(fileparts(path),'status --porcelain');
    end
    versions.(matlab.lang.makeValidName(key_files{i})) = record;
end
% The line search is a private function of tests/competitors and does not
% resolve through WHICH from this context; locate it directly.
linesearch_path = fullfile(bds_root, 'tests', 'competitors', 'private', ...
    'lam_paper_exact_linesearch.m');
versions.lam_paper_exact_linesearch = struct( ...
    'path', linesearch_path, ...
    'sha256', tsfsb_sha256(linesearch_path));

end

function value = git_value(path, arguments)

quoted_path = ['''', strrep(path, '''', '''"''"'''), ''''];
[status, output] = system(sprintf('git -C %s %s', quoted_path, arguments));
if status == 0
    value = strtrim(output);
else
    value = '';
end

end
