function manifest = run_auto_initial_step_size_500n_full_factorial(mode, problem_limit)
%RUN_AUTO_INITIAL_STEP_SIZE_500N_FULL_FACTORIAL Run the accelerated 4-by-4 grid.

if nargin < 1
    mode = 'full';
end
if nargin < 2
    problem_limit = Inf;
end
mode = validatestring(lower(char(mode)), {'pilot', 'full'});

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

problem_names = frozen_problem_names();
if strcmp(mode, 'pilot')
    problem_limit = min(problem_limit, 1);
end
if isfinite(problem_limit)
    problem_names = problem_names(1:min(problem_limit, numel(problem_names)));
end
if strcmp(mode, 'full') && numel(problem_names) ~= 122
    error('run_auto_initial_step_size_500n_full_factorial:ProblemCountMismatch', ...
        'Expected 122 frozen problems, found %d.', numel(problem_names));
end
problem_dims = load_problem_dimensions(problem_names);
if any(problem_dims < 6 | problem_dims > 50)
    error('run_auto_initial_step_size_500n_full_factorial:DimensionMismatch', ...
        'The frozen problem dimensions must be in [6, 50].');
end

[solver_names, coefficient_pairs] = candidate_grid();
assert(numel(solver_names) == 17 && numel(unique(solver_names)) == 17, ...
    'The full-factorial experiment must contain 17 unique solvers.');

timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
run_root = fullfile(experiment_dir, 'testdata', ...
    ['auto_initial_step_size_500n_full_factorial_', mode, '_', timestamp]);
mkdir(run_root);

manifest = build_manifest(repo_dir, experiment_dir, optiprofiler_root, mode, ...
    problem_names, problem_dims, solver_names, coefficient_pairs, ...
    run_root, timestamp);
manifest_file = fullfile(run_root, 'manifest.mat');
save(manifest_file, 'manifest');
write_manifest_text(fullfile(run_root, 'manifest.txt'), manifest);

fprintf('AUTO_ALPHA_RUN_ROOT=%s\n', run_root);
fprintf('AUTO_ALPHA_PROBLEM_COUNT=%d\n', numel(problem_names));
fprintf('AUTO_ALPHA_SOLVER_COUNT=%d\n', numel(solver_names));

options = struct();
options.problem_names = problem_names;
options.mindim = 6;
options.maxdim = 50;
options.plibs = 's2mpj';
options.feature_name = 'plain';
options.feature_display_name = 'auto_initial_step_size_accelerated_full_factorial';
options.n_runs = 1;
options.seed = 0;
options.max_eval_factor = 500;
options.max_tol_order = 4;
options.n_jobs = 40;
options.draw_hist_plots = 'none';
options.solver_verbose = 0;
options.solver_names = solver_names;
options.benchmark_id = 'auto_alpha_accel_4x4_500n';
options.savepath = fullfile(run_root, 'accelerated_all_on');
mkdir(options.savepath);
profile_optiprofiler(options);

data_file = validate_raw_results( ...
    options.savepath, solver_names, problem_names, problem_dims);
manifest.status = 'COMPLETE';
manifest.finished_at = char(datetime('now'));
manifest.data_file = data_file;
save(manifest_file, 'manifest');
write_manifest_text(fullfile(run_root, 'manifest.txt'), manifest);

fprintf('AUTO_ALPHA_DATA_FILE=%s\n', data_file);
fprintf('AUTO_ALPHA_500N_FULL_FACTORIAL_OK\n');
clear cleanup_dir

end

function [labels, pairs] = candidate_grid()

cx_values = [0.1, 0.2, 0.5, 1];
ctau_values = [1, 2, 5, 10];
labels = {'unit-accelerated-all-on-500n'};
pairs = repmat(struct('label', '', 'c_x', NaN, 'c_tau', NaN), ...
    numel(cx_values) * numel(ctau_values), 1);
index = 0;
for i_x = 1:numel(cx_values)
    for i_tau = 1:numel(ctau_values)
        index = index + 1;
        cx_token = coefficient_token(cx_values(i_x));
        ctau_token = coefficient_token(ctau_values(i_tau));
        label = sprintf('auto-cx-%s-ctau-%s-accelerated-all-on-500n', ...
            cx_token, ctau_token);
        labels{end + 1} = label;
        pairs(index) = struct('label', label, ...
            'c_x', cx_values(i_x), 'c_tau', ctau_values(i_tau));
    end
end

end

function token = coefficient_token(value)

token = strrep(sprintf('%.15g', value), '.', 'p');

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


function manifest = build_manifest(repo_dir, experiment_dir, optiprofiler_root, mode, ...
        problem_names, problem_dims, solver_names, coefficient_pairs, ...
        run_root, timestamp)

manifest = struct();
manifest.schema_version = 2;
manifest.study = 'accelerated_full_factorial';
manifest.status = 'RUNNING';
manifest.mode = mode;
manifest.started_at = char(datetime('now'));
manifest.finished_at = '';
manifest.timestamp = timestamp;
manifest.run_root = run_root;
manifest.data_file = '';
manifest.bds_commit = git_value(repo_dir, 'rev-parse HEAD');
manifest.bds_branch = git_value(repo_dir, 'branch --show-current');
manifest.bds_status = git_value(repo_dir, 'status --short');
manifest.optiprofiler_root = optiprofiler_root;
manifest.optiprofiler_commit = git_value(optiprofiler_root, 'rev-parse HEAD');
manifest.optiprofiler_status = git_value(optiprofiler_root, 'status --short');
manifest.matlab_version = version;
manifest.operating_system = system_dependent('getos');
manifest.launch_command = [ ...
    'matlab -batch "addpath(''', experiment_dir, ...
    '''); run_auto_initial_step_size_500n_full_factorial(''full'');"'];
manifest.problem_names = problem_names;
manifest.problem_dims = problem_dims;
manifest.problem_count = numel(problem_names);
manifest.dimension_limits = [6, 50];
manifest.problem_library = 's2mpj';
manifest.problem_type = 'u';
manifest.feature = 'plain';
manifest.solver_names = solver_names;
manifest.unit_baseline = solver_names{1};
manifest.coefficient_pairs = coefficient_pairs;
manifest.c_x_values = [0.1, 0.2, 0.5, 1];
manifest.c_tau_values = [1, 2, 5, 10];
manifest.max_eval_factor = 500;
manifest.analysis_checkpoints = [200, 500];
manifest.n_runs = 1;
manifest.profile_seed = 0;
manifest.n_jobs = 40;
manifest.max_tol_order = 4;
manifest.base_options = struct( ...
    'Algorithm', 'cbds', ...
    'effective_direction_set', 'eye(N)', ...
    'effective_num_blocks', 'N', ...
    'effective_batch_size', 'N', ...
    'effective_block_visiting_pattern', 'sorted', ...
    'StepTolerance', 1e-6, ...
    'expand', 1.8, 'shrink', 0.5, 'is_noisy', false, ...
    'forcing_function', '@(alpha) alpha^2', ...
    'reduction_factor', [0, eps, eps], ...
    'polling_inner', 'opportunistic', 'cycling_inner', 1, ...
    'ftarget', -Inf, 'use_function_value_stop', false, ...
    'use_estimated_gradient_stop', false, 'seed', 0);
manifest.acceleration = struct( ...
    'use_productive_direction_memory', true, ...
    'productive_direction_memory_size', 'max(1,min(N,5))', ...
    'use_iteration_pattern_step', true, ...
    'use_momentum_extrapolation', true, ...
    'momentum_decay', 0.6);

end


function data_file = validate_raw_results( ...
        savepath, expected_solvers, expected_names, expected_dims)

files = dir(fullfile(savepath, '**', 'data_for_loading.mat'));
assert(numel(files) == 1, ...
    'Expected one data_for_loading.mat, found %d.', numel(files));
data_file = fullfile(files(1).folder, files(1).name);
loaded = load(data_file, 'results_plibs');
assert(isfield(loaded, 'results_plibs') && numel(loaded.results_plibs) == 1, ...
    'Expected one saved problem library.');
result = loaded.results_plibs{1};
assert(isequal(result.solver_names(:)', expected_solvers(:)'), ...
    'The saved solver order differs from the manifest.');
assert(isequal(result.problem_names(:)', expected_names(:)'), ...
    'The saved problem order differs from the frozen snapshot.');
assert(isequal(result.problem_dims(:)', expected_dims(:)'), ...
    'The saved problem dimensions differ from the frozen snapshot.');
assert(size(result.computation_times, 2) == 17 && ...
    size(result.computation_times, 3) == 1, ...
    'Expected 17 solvers and one run.');
assert(all(result.solvers_successes(:)), 'At least one solver run failed.');
assert(~any(result.solver_abnormal_terminations(:)), ...
    'At least one solver terminated abnormally.');
assert(~any(result.solver_output_fallbacks(:)), ...
    'At least one solver used output fallback.');
budgets = repmat(500 * result.problem_dims(:), 1, 17);
assert(all(result.n_evals(:) <= budgets(:)), ...
    'At least one solver exceeded its 500*N budget.');

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


function write_manifest_text(path, manifest)

fid = fopen(path, 'w');
if fid < 0
    error('run_auto_initial_step_size_500n_full_factorial:ManifestOpenFailed', ...
        'Cannot create %s.', path);
end
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, 'schema_version=%d\n', manifest.schema_version);
fprintf(fid, 'study=%s\n', manifest.study);
fprintf(fid, 'status=%s\n', manifest.status);
fprintf(fid, 'mode=%s\n', manifest.mode);
fprintf(fid, 'started_at=%s\n', manifest.started_at);
fprintf(fid, 'finished_at=%s\n', manifest.finished_at);
fprintf(fid, 'run_root=%s\n', manifest.run_root);
fprintf(fid, 'data_file=%s\n', manifest.data_file);
fprintf(fid, 'bds_commit=%s\n', manifest.bds_commit);
fprintf(fid, 'bds_branch=%s\n', manifest.bds_branch);
fprintf(fid, 'bds_status=%s\n', strrep(manifest.bds_status, newline, ' | '));
fprintf(fid, 'optiprofiler_root=%s\n', manifest.optiprofiler_root);
fprintf(fid, 'optiprofiler_commit=%s\n', manifest.optiprofiler_commit);
fprintf(fid, 'matlab_version=%s\n', manifest.matlab_version);
fprintf(fid, 'operating_system=%s\n', ...
    strrep(manifest.operating_system, newline, ' '));
fprintf(fid, 'problem_count=%d\n', manifest.problem_count);
fprintf(fid, 'problem_names=%s\n', strjoin(manifest.problem_names, ','));
fprintf(fid, 'problem_dims=%s\n', sprintf('%d,', manifest.problem_dims));
fprintf(fid, 'solver_count=%d\n', numel(manifest.solver_names));
fprintf(fid, 'solver_names=%s\n', strjoin(manifest.solver_names, ','));
fprintf(fid, 'c_x_values=%s\n', sprintf('%.15g,', manifest.c_x_values));
fprintf(fid, 'c_tau_values=%s\n', sprintf('%.15g,', manifest.c_tau_values));
fprintf(fid, 'max_eval_factor=%d\n', manifest.max_eval_factor);
fprintf(fid, 'analysis_checkpoints=%s\n', ...
    sprintf('%d,', manifest.analysis_checkpoints));
fprintf(fid, 'n_runs=%d\n', manifest.n_runs);
fprintf(fid, 'profile_seed=%d\n', manifest.profile_seed);
fprintf(fid, 'n_jobs=%d\n', manifest.n_jobs);
fprintf(fid, 'launch_command=%s\n', manifest.launch_command);
clear cleanup

end


function root = ensure_optiprofiler_paths()

home_dir = char(java.lang.System.getProperty('user.home'));
root = fullfile(home_dir, 'local', 'optiprofiler', 'matlab', 'optiprofiler');
if ~exist('benchmark', 'file') || ~exist('s2mpj_select', 'file')
    addpath(fullfile(root, 'src'));
    addpath(fullfile(root, 'problem_libs'));
    addpath(fullfile(root, 'problem_libs', 's2mpj'));
end
if ~exist('benchmark', 'file') || ~exist('s2mpj_select', 'file')
    error('run_auto_initial_step_size_500n_full_factorial:OptiProfilerNotFound', ...
        'OptiProfiler or S2MPJ is not available.');
end

end
