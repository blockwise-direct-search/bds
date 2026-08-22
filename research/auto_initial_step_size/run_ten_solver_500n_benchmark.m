function manifest = run_ten_solver_500n_benchmark( ...
        mode, output_parent, resume_root)
%RUN_TEN_SOLVER_500N_BENCHMARK Run the frozen ten-solver comparison.

if nargin < 1
    mode = 'full';
end
if nargin < 2 || isempty(output_parent)
    output_parent = fullfile(fileparts(mfilename('fullpath')), 'testdata');
end
if nargin < 3
    resume_root = '';
end
mode = validatestring(lower(char(mode)), {'smoke', 'full'});
resume_root = char(resume_root);

experiment_dir = fileparts(mfilename('fullpath'));
research_dir = fileparts(experiment_dir);
repo_dir = fileparts(research_dir);
tests_dir = fullfile(repo_dir, 'tests');
old_dir = pwd;
cleanup_dir = onCleanup(@() cd(old_dir));
cd(repo_dir);
setup;
addpath(tests_dir);
addpath(experiment_dir);
addpath(fullfile(tests_dir, 'competitors'));
optiprofiler_root = ensure_optiprofiler_paths();

spec = ten_solver_benchmark_spec();
problem_names = frozen_problem_names();
if strcmp(mode, 'smoke')
    problem_names = select_smoke_problems(problem_names);
    features = spec.smoke_features;
    n_jobs = 1;
    max_tol_order = 2;
else
    features = spec.features;
    n_jobs = 60;
    max_tol_order = spec.max_tol_order;
end
problem_dims = load_problem_dimensions(problem_names);
validate_protocol(spec, problem_names, problem_dims, features, mode);

if isempty(resume_root)
    timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    run_root = fullfile(output_parent, ...
        ['ten_solver_500n_', mode, '_', timestamp]);
    mkdir(run_root);
    manifest = build_manifest(repo_dir, optiprofiler_root, spec, mode, ...
        problem_names, problem_dims, features, run_root);
else
    run_root = resume_root;
    manifest = load_resume_manifest(run_root, spec, mode, ...
        problem_names, problem_dims, features);
end
manifest_file = fullfile(run_root, 'manifest.mat');
save(manifest_file, 'manifest');

fprintf('TEN_SOLVER_RUN_ROOT=%s\n', run_root);
for i_feature = 1:numel(features)
    feature_name = features{i_feature};
    feature_savepath = fullfile(run_root, feature_name);
    options = benchmark_options(spec, problem_names, feature_name, ...
        feature_savepath, n_jobs, max_tol_order);
    if exist(feature_savepath, 'dir')
        [data_file, diagnostics] = validate_raw_results( ...
            feature_savepath, options.benchmark_id, spec, ...
            problem_names, problem_dims, options.n_runs);
        manifest.data_files{i_feature} = data_file;
        manifest.diagnostics{i_feature} = diagnostics;
        save(manifest_file, 'manifest');
        fprintf('TEN_SOLVER_FEATURE_REUSED=%s\n', feature_name);
        report_diagnostics(feature_name, diagnostics);
        continue;
    end
    mkdir(feature_savepath);
    fprintf('TEN_SOLVER_FEATURE_START=%s N_RUNS=%d\n', ...
        feature_name, options.n_runs);
    profile_optiprofiler(options);
    [data_file, diagnostics] = validate_raw_results(feature_savepath, ...
        options.benchmark_id, spec, problem_names, problem_dims, ...
        options.n_runs);
    manifest.data_files{i_feature} = data_file;
    manifest.diagnostics{i_feature} = diagnostics;
    save(manifest_file, 'manifest');
    fprintf('TEN_SOLVER_FEATURE_OK=%s\n', feature_name);
    report_diagnostics(feature_name, diagnostics);
end

manifest.status = 'COMPLETE';
manifest.finished_at = char(datetime('now'));
save(manifest_file, 'manifest');
fprintf('TEN_SOLVER_%s_OK\n', upper(mode));
clear cleanup_dir

end

function options = benchmark_options(spec, problem_names, feature_name, ...
        savepath, n_jobs, max_tol_order)

options = struct();
options.problem_names = problem_names;
options.mindim = spec.dimension_limits(1);
options.maxdim = spec.dimension_limits(2);
options.plibs = 's2mpj';
options.feature_name = feature_name;
options.feature_display_name = feature_name;
options.n_runs = feature_n_runs(spec, feature_name);
options.seed = spec.seed;
options.max_eval_factor = spec.max_eval_factor;
options.max_tol_order = max_tol_order;
options.n_jobs = n_jobs;
options.draw_hist_plots = 'none';
options.solver_verbose = 0;
options.solver_names = spec.solver_names;
options.line_colors = spec.line_colors;
options.line_styles = spec.line_styles;
options.benchmark_id = 'ten_solver_500n';
options.savepath = savepath;

end

function names = select_smoke_problems(all_names)

first_problem = s2mpj_load(all_names{1});
second_index = [];
for i_problem = 2:numel(all_names)
    problem = s2mpj_load(all_names{i_problem});
    if problem.n ~= first_problem.n
        second_index = i_problem;
        break;
    end
end
assert(~isempty(second_index), ...
    'Cannot find two frozen smoke problems with different dimensions.');
names = all_names([1, second_index]);

end

function [data_file, diagnostics] = validate_raw_results( ...
        savepath, benchmark_id, spec, ...
        problem_names, problem_dims, expected_n_runs)

listing = dir(fullfile(savepath, [benchmark_id, '*'], '**', ...
    'data_for_loading.mat'));
assert(isscalar(listing), 'Expected exactly one raw result file.');
data_file = fullfile(listing(1).folder, listing(1).name);
loaded = load(data_file, 'results_plibs');
assert(isscalar(loaded.results_plibs), ...
    'Expected exactly one problem-library result.');
results = loaded.results_plibs{1};
assert(isequal(results.solver_names(:), spec.solver_names(:)), ...
    'The stored solver identities or ordering changed.');
assert(isequal(results.problem_names(:), problem_names(:)), ...
    'The stored problem identities or ordering changed.');
assert(size(results.n_evals, 2) == numel(spec.solver_names), ...
    'The raw results do not contain all ten solvers.');
assert(size(results.n_evals, 3) == expected_n_runs, ...
    'The raw results contain an unexpected number of runs.');
for i_problem = 1:numel(problem_dims)
    assert(all(results.n_evals(i_problem, :, :) <= ...
        spec.max_eval_factor*problem_dims(i_problem), 'all'), ...
        'A solver exceeded the 500N objective budget on %s.', ...
        problem_names{i_problem});
end

diagnostics = struct();
diagnostics.unsuccessful_runs = nnz(results.solvers_successes == 0);
diagnostics.abnormal_terminations = 0;
diagnostics.output_fallbacks = 0;
if isfield(results, 'solver_abnormal_terminations')
    diagnostics.abnormal_terminations = ...
        nnz(results.solver_abnormal_terminations);
end
if isfield(results, 'solver_output_fallbacks')
    diagnostics.output_fallbacks = nnz(results.solver_output_fallbacks);
end

end

function report_diagnostics(feature_name, diagnostics)

fprintf(['TEN_SOLVER_FEATURE_DIAGNOSTICS=%s UNSUCCESSFUL=%d ', ...
    'ABNORMAL=%d FALLBACK=%d\n'], feature_name, ...
    diagnostics.unsuccessful_runs, diagnostics.abnormal_terminations, ...
    diagnostics.output_fallbacks);

end

function validate_protocol(spec, problem_names, problem_dims, features, mode)

assert(numel(spec.solver_names) == 10 && ...
    numel(unique(spec.solver_names)) == 10, ...
    'The comparison must contain ten unique solver identities.');
assert(size(spec.line_colors, 1) == numel(spec.solver_names), ...
    'Every solver identity must have a fixed color.');
assert(numel(spec.line_styles) == numel(spec.solver_names), ...
    'Every solver identity must have a fixed line style.');
assert(all(problem_dims >= spec.dimension_limits(1) & ...
    problem_dims <= spec.dimension_limits(2)), ...
    'Every problem dimension must be in the frozen range.');
assert(feature_n_runs(spec, 'plain') == 1, ...
    'The plain feature must use exactly one run.');
nonplain_features = spec.features(~strcmp(spec.features, 'plain'));
assert(numel(nonplain_features) == 9 && ...
    all(cellfun(@(name) feature_n_runs(spec, name), ...
    nonplain_features) == 5), ...
    'The nine non-plain features must use exactly five runs each.');
if strcmp(mode, 'full')
    assert(numel(problem_names) == spec.problem_count, ...
        'The full run must contain the frozen 122 problems.');
    assert(isequal(features, spec.features), ...
        'The full run must contain the frozen ten features.');
end

end

function names = frozen_problem_names()

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

function dimensions = load_problem_dimensions(problem_names)

dimensions = zeros(1, numel(problem_names));
for i_problem = 1:numel(problem_names)
    problem = s2mpj_load(problem_names{i_problem});
    dimensions(i_problem) = problem.n;
end

end

function manifest = build_manifest(repo_dir, optiprofiler_root, spec, mode, ...
        problem_names, problem_dims, features, run_root)

manifest = struct();
manifest.schema_version = 3;
manifest.status = 'RUNNING';
manifest.mode = mode;
manifest.started_at = char(datetime('now'));
manifest.finished_at = '';
manifest.run_root = run_root;
manifest.problem_names = problem_names;
manifest.problem_dims = problem_dims;
manifest.features = features;
manifest.solver_names = spec.solver_names;
manifest.display_names = spec.display_names;
manifest.line_colors = spec.line_colors;
manifest.line_styles = spec.line_styles;
manifest.n_runs = cellfun(@(name) feature_n_runs(spec, name), features);
manifest.seed = spec.seed;
manifest.max_eval_factor = spec.max_eval_factor;
manifest.data_files = cell(size(features));
manifest.diagnostics = cell(size(features));
manifest.bds_commit = git_value(repo_dir, 'rev-parse HEAD');
manifest.bds_branch = git_value(repo_dir, 'branch --show-current');
manifest.bds_status = git_value(repo_dir, 'status --short');
manifest.optiprofiler_root = optiprofiler_root;
manifest.optiprofiler_commit = git_value(optiprofiler_root, 'rev-parse HEAD');
manifest.optiprofiler_status = git_value(optiprofiler_root, 'status --short');
manifest.matlab_version = version;

end

function manifest = load_resume_manifest(run_root, spec, mode, ...
        problem_names, problem_dims, features)

manifest_file = fullfile(run_root, 'manifest.mat');
assert(exist(manifest_file, 'file') == 2, ...
    'Cannot find the manifest for the requested resume root.');
loaded = load(manifest_file, 'manifest');
manifest = loaded.manifest;
assert(strcmp(manifest.mode, mode), 'The resume mode changed.');
assert(isequal(manifest.problem_names(:), problem_names(:)), ...
    'The resume problem identities or ordering changed.');
assert(isequal(manifest.problem_dims(:), problem_dims(:)), ...
    'The resume problem dimensions changed.');
assert(isequal(manifest.features(:), features(:)), ...
    'The resume feature identities or ordering changed.');
assert(isequal(manifest.solver_names(:), spec.solver_names(:)), ...
    'The resume solver identities or ordering changed.');
expected_n_runs = cellfun(@(name) feature_n_runs(spec, name), features);
assert(isequal(manifest.n_runs, expected_n_runs), ...
    'The resume run counts changed.');
assert(manifest.max_eval_factor == spec.max_eval_factor, ...
    'The resume objective budget changed.');
if ~isfield(manifest, 'diagnostics')
    manifest.diagnostics = cell(size(features));
end
manifest.status = 'RUNNING';
manifest.finished_at = '';
manifest.resumed_at = char(datetime('now'));
manifest.schema_version = 3;

end

function n_runs = feature_n_runs(spec, feature_name)

if strcmp(feature_name, 'plain')
    n_runs = spec.plain_n_runs;
else
    assert(ismember(feature_name, spec.features), ...
        'Unknown benchmark feature: %s.', feature_name);
    n_runs = spec.nonplain_n_runs;
end

end

function value = git_value(path_name, arguments)

command = sprintf('git -C %s %s', shell_quote(path_name), arguments);
[status, value] = system(command);
if status == 0
    value = strtrim(value);
else
    value = '';
end

end

function quoted = shell_quote(text)

quoted = ['''', strrep(char(text), '''', '''"''"'''), ''''];

end

function root = ensure_optiprofiler_paths()

root = fullfile(getenv('HOME'), 'local', 'optiprofiler', ...
    'matlab', 'optiprofiler');
paths = {root, fullfile(root, 'src'), fullfile(root, 'problem_libs'), ...
    fullfile(root, 'problem_libs', 's2mpj')};
for i_path = 1:numel(paths)
    if exist(paths{i_path}, 'dir')
        addpath(paths{i_path});
    end
end
assert(exist('benchmark', 'file') == 2, 'Cannot find OptiProfiler benchmark.');
assert(exist('s2mpj_select', 'file') == 2, 'Cannot find S2MPJ.');

end
