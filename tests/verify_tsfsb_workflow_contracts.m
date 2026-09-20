function verify_tsfsb_workflow_contracts()
%VERIFY_TSFSB_WORKFLOW_CONTRACTS Verify the fixed TSFSB workflow specification.
%
%   Ported from the C02 verify_c02_workflow_contracts.m (commit 846d5c5f),
%   adapted to the TSFSB workflow: ten solvers, no excludelist anywhere,
%   no hardcoded problem count, direct benchmark calls, and the TSFSB
%   commit ordering. Requires no external solver and is CI-safe.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
module_dir = fullfile(root_dir, 'research', 'ten_solver_full_set_benchmark');
old_path = path();
cleanup = onCleanup(@() path(old_path));
addpath(module_dir);

spec = tsfsb_benchmark_spec();
expected_features = { ...
    'plain', 'noisy_1e-1', 'noisy_1e-2', 'noisy_1e-3', 'noisy_1e-4', ...
    'linearly_transformed', ...
    'linearly_transformed_noisy_1e-1', ...
    'linearly_transformed_noisy_1e-2', ...
    'linearly_transformed_noisy_1e-3', ...
    'linearly_transformed_noisy_1e-4'};
assert(isequal({spec.features.name}, expected_features));
assert(isequal([spec.features.n_runs], [1, 5, 5, 5, 5, 5, 5, 5, 5, 5]));
assert(isequal([spec.features.noise_level], ...
    [0, 1e-1, 1e-2, 1e-3, 1e-4, 0, 1e-1, 1e-2, 1e-3, 1e-4]));
assert(isequal([spec.features.orthogonally_transformed], ...
    logical([0, 0, 0, 0, 0, 1, 1, 1, 1, 1])));
assert(spec.schema_version == 1);
assert(strcmp(spec.problem_library, 's2mpj'));
assert(strcmp(spec.problem_type, 'u'));
assert(spec.minimum_dimension == 6 && spec.maximum_dimension == 50);
assert(spec.budget_factor == 500);
assert(spec.worker_count == 30);
assert(spec.base_seed == 20260828);
assert(isequal(spec.run_identifiers, 1:5));
assert(isequal(spec.displayed_tolerance_orders, [2, 4]));
assert(spec.maximum_tolerance_order == 4);
% The spec must not fix a problem count or an excludelist. The problem
% set comes only from the frozen problem manifest.
assert(~isfield(spec, 'expected_problem_count'));
assert(~isfield(spec, 'excludelist'));
assert(~isfield(spec, 'excluded_problems'));
assert(numel(spec.pool) == 10);
assert(isequal({spec.pool.internal_label}, { ...
    'bds', 'bds-no-acceleration', 'ds', 'nomad', 'lam', 'newuoa', ...
    'fd-bfgs', 'pds', 'bfo', 'nelder-mead'}));
assert(isequal({spec.pool.display_name}, { ...
    'BDS', 'BDS without acceleration', 'DS', 'NOMAD', 'LAM', ...
    'NEWUOA', 'FD-BFGS', 'PDS', 'BFO', 'Nelder-Mead'}));
assert(isequal(spec.subsets.acceleration, [1, 2]));
assert(isequal(spec.subsets.blocking, [2, 3]));
assert(isequal(spec.subsets.direction_based, [1, 4, 5, 8, 9, 10]));
assert(isequal(spec.subsets.model_fd, [1, 6, 7]));
assert(isequal(spec.subsets.full_pool, 1:10));
assert(size(spec.line_colors, 1) == 10 && size(spec.line_colors, 2) == 3);
assert(numel(spec.line_styles) == 10);
assert(all(ismember(spec.line_styles, {'-', '--', '-.', ':'})));
assert(isequal(spec.line_widths, 1.5 * ones(1, 10)));

options = tsfsb_direct_profile_options(1:10);
assert(isequal(options.solver_names, {spec.pool.display_name}));
assert(isequal(options.line_colors, spec.line_colors));
assert(isequal(options.line_styles, spec.line_styles));
assert(isequal(options.line_widths, spec.line_widths));
assert(options.summarize_performance_profiles);
assert(options.summarize_output_based_profiles);
assert(~options.summarize_log_ratio_profiles);
subset_options = tsfsb_direct_profile_options(spec.subsets.model_fd);
assert(isequal(subset_options.solver_names, {'BDS', 'NEWUOA', 'FD-BFGS'}));

for i_feature = 1:numel(spec.features)
    feature = spec.features(i_feature);
    feature_options = tsfsb_feature_options(feature);
    assert(feature_options.n_runs == feature.n_runs);
    assert(strcmp(feature_options.feature_stamp, feature.name));
    if strcmp(feature.name, 'plain')
        assert(strcmp(feature_options.feature_name, 'plain'));
    elseif startsWith(feature.name, 'linearly_transformed_noisy')
        assert(strcmp(feature_options.feature_name, 'custom'));
        assert(isa(feature_options.mod_x0, 'function_handle'));
        assert(isa(feature_options.mod_affine, 'function_handle'));
        assert(isa(feature_options.mod_fun, 'function_handle'));
    elseif startsWith(feature.name, 'linearly_transformed')
        assert(strcmp(feature_options.feature_name, 'linearly_transformed'));
        assert(feature_options.rotated);
        assert(feature_options.condition_factor == 0);
    else
        assert(strcmp(feature_options.feature_name, 'noisy'));
        assert(feature_options.noise_level == feature.noise_level);
    end
end

bundle = tsfsb_solver_handles(spec.features(1));
assert(numel(bundle.handles) == 10);
assert(all(cellfun(@(h) isa(h, 'function_handle'), bundle.handles)));
assert(isequal(bundle.solver_names, {spec.pool.display_name}));
assert(isequal(bundle.machine_ids, {spec.pool.internal_label}));
assert(isequal(find(bundle.solver_isrand), [8, 9]));
bundle_noisy = tsfsb_solver_handles(spec.features(3));
fd_bfgs_detail = bundle_noisy.details(7);
assert(fd_bfgs_detail.options_static.with_gradient);
assert(fd_bfgs_detail.options_static.noise_level == 1e-2);
assert(~bundle.details(7).options_static.with_gradient);

seed_first = tsfsb_pds_seed([1; -2; 3]);
assert(seed_first == tsfsb_pds_seed([1; -2; 3]));
assert(seed_first >= 0 && seed_first <= 2^32 - 1 ...
    && seed_first == floor(seed_first));
assert(seed_first ~= tsfsb_pds_seed([1; -2; 4]));

runner_source = fileread(fullfile(module_dir, 'run_tsfsb_benchmark.m'));
assert(contains(runner_source, 'benchmark(bundle.handles, options)'));
assert(~contains(runner_source, 'profile_optiprofiler('));
assert(~contains(runner_source, 'options.excludelist'));
assert(contains(runner_source, 'FullBenchmarkSeedOverride'));
assert(contains(runner_source, 'options.n_jobs = spec.worker_count;'));
assert(contains(runner_source, ...
    'context.expected_worker_count = spec.worker_count;'));
assert(contains(runner_source, 'delete(gcp(''nocreate''));'));
spec_source = fileread(fullfile(module_dir, 'tsfsb_benchmark_spec.m'));
assert(~contains(spec_source, 'expected_problem_count'));
assert(~contains(spec_source, 'excludelist'));
audit_source = fileread(fullfile(module_dir, 'tsfsb_audit_result.m'));
assert(contains(audit_source, 'UnexpectedBdsSource'));
assert(contains(audit_source, 'WorkerCountMismatch'));
complete_position = strfind(runner_source, ...
    'write_complete_marker(result.root);');
accepted_position = strfind(runner_source, ...
    'tsfsb_write_json(accepted_path, manifest);');
assert(isscalar(complete_position) && isscalar(accepted_position) ...
    && complete_position < accepted_position, ...
    'The accepted feature manifest must be the final commit step.');

module_files = dir(fullfile(module_dir, '*.m'));
for i = 1:numel(module_files)
    source = lower(fileread(fullfile(module_dir, module_files(i).name)));
    assert(~contains(source, 'openfig'));
    assert(~contains(source, 'exportgraphics'));
    assert(~contains(source, 'fix_summary_feature_titles'));
    assert(~contains(source, 'merge_summary_pdfs'));
    assert(~contains(source, 'pdf_postprocessing = true'));
end

temporary_root = tempname;
mkdir(temporary_root);
temporary_cleanup = onCleanup(@() rmdir(temporary_root, 's'));
source_file = fullfile(temporary_root, 'source.bin');
write_bytes(source_file, uint8('TSFSB checksum round trip'));
digest = tsfsb_sha256(source_file);
assert(ischar(digest) && numel(digest) == 64);
json_path = fullfile(temporary_root, 'record.json');
tsfsb_write_json(json_path, struct('status', 'accepted', 'value', 7));
record = jsondecode(fileread(json_path));
assert(strcmp(record.status, 'accepted') && record.value == 7);

artifact_root = fullfile(temporary_root, 'artifact');
test_log = fullfile(artifact_root, 'test_log');
mkdir(test_log);
write_bytes(fullfile(artifact_root, 'TSFSB_COMPLETE'), uint8('accepted'));
audited_file = fullfile(test_log, 'report.txt');
write_bytes(audited_file, uint8('audited artifact'));
accepted_manifest = fullfile(temporary_root, 'accepted_manifest.json');
artifact_info = dir(audited_file);
manifest = struct( ...
    'status', 'accepted', ...
    'result_root', artifact_root, ...
    'artifact_checksums', struct( ...
    'path', fullfile('test_log', 'report.txt'), ...
    'sha256', tsfsb_sha256(audited_file), ...
    'bytes', artifact_info.bytes));
tsfsb_write_json(accepted_manifest, manifest);
tsfsb_verify_manifest(accepted_manifest);
write_bytes(audited_file, uint8('changed artifact'));
assert_throws(@() tsfsb_verify_manifest(accepted_manifest), ...
    'tsfsb_verify_manifest:ChecksumMismatch');
clear temporary_cleanup
clear cleanup

fprintf('VERIFY_TSFSB_WORKFLOW_CONTRACTS_OK\n');

end

function assert_throws(function_handle, identifier)

try
    function_handle();
catch error_record
    assert(strcmp(error_record.identifier, identifier));
    return;
end
error('verify_tsfsb_workflow_contracts:ExpectedError', ...
    'Expected error %s was not raised.', identifier);

end

function write_bytes(file_path, bytes)

file_id = fopen(file_path, 'w');
assert(file_id >= 0);
cleanup = onCleanup(@() fclose(file_id));
fwrite(file_id, bytes, 'uint8');
clear cleanup

end
