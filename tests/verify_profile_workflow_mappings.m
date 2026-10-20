function verify_profile_workflow_mappings()
%VERIFY_PROFILE_WORKFLOW_MAPPINGS Verify production workflow profile routing.
%
%   VERIFY_PROFILE_WORKFLOW_MAPPINGS() replaces OptiProfiler, BDS, the
%   simplified BDS, and the four comparison solvers with temporary recording
%   stubs. It checks that public workflow labels select the intended wrappers
%   and pass the exact production benchmark options.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
stub_dir = tempname;
mkdir(stub_dir);

old_path = path();
cleanup = onCleanup(@() restore_environment(old_path, stub_dir));

write_recording_stubs(stub_dir);
addpath(fullfile(root_dir, 'src'));
addpath(tests_dir);
addpath(fullfile(tests_dir, 'competitors'));
addpath(fullfile(stub_dir, 'prima', 'matlab', 'interfaces'), '-begin');
addpath(stub_dir, '-begin');

global BDS_PROFILE_MAPPING_CALLS

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile_pair('bds-production-500n', 'bfo-500n', stub_dir);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options, true, false, false);
assert_bfo_wrapper_call(BDS_PROFILE_MAPPING_CALLS.bfo_arguments, 1000);

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile_pair('bds-production-500n', 'nomad-500n', stub_dir);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options, true, false, false);
assert(strcmp(BDS_PROFILE_MAPPING_CALLS.nomad_parameters.MAX_BB_EVAL, '1000'));
assert(strcmp(BDS_PROFILE_MAPPING_CALLS.nomad_parameters.max_eval, '1000'));
assert(BDS_PROFILE_MAPPING_CALLS.nomad_objective_value == 5);

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile_pair('bds-production-500n', 'newuoa-500n', stub_dir);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options, true, false, false);
assert(BDS_PROFILE_MAPPING_CALLS.newuoa_options.maxfun == 1000);
assert(BDS_PROFILE_MAPPING_CALLS.newuoa_options.rhoend == 1e-6);
assert(BDS_PROFILE_MAPPING_CALLS.newuoa_options.rhobeg == 1);
assert(BDS_PROFILE_MAPPING_CALLS.newuoa_objective_value == 5);

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile_pair('bds-production-500n', ...
    'bfgs-no-gradient-500n', stub_dir);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options, true, false, false);
assert(strcmp(BDS_PROFILE_MAPPING_CALLS.fminunc_options.Algorithm, ...
    'quasi-newton'));
assert(strcmp(BDS_PROFILE_MAPPING_CALLS.fminunc_options.HessUpdate, 'bfgs'));
assert(BDS_PROFILE_MAPPING_CALLS.fminunc_options.MaxFunctionEvaluations == 1000);
assert(BDS_PROFILE_MAPPING_CALLS.fminunc_options.StepTolerance == 1e-6);
assert(~BDS_PROFILE_MAPPING_CALLS.fminunc_options.SpecifyObjectiveGradient);
assert(BDS_PROFILE_MAPPING_CALLS.fminunc_objective_value == 5);

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile({'bds-acceleration-off-500n', ...
    'bds-acceleration-on-500n'}, stub_dir);
assert(numel(BDS_PROFILE_MAPPING_CALLS.bds_options_history) == 2);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options_history{1}, false, false, false);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options_history{2}, true, false, false);

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile({'bds-function-value-stop-500n', ...
    'bds-estimated-gradient-stop-500n', ...
    'bds-combined-stop-500n'}, stub_dir);
assert(numel(BDS_PROFILE_MAPPING_CALLS.bds_options_history) == 3);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options_history{1}, true, true, false);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options_history{2}, true, false, true);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options_history{3}, true, true, true);

BDS_PROFILE_MAPPING_CALLS = struct();
run_profile({'bds-invalid-aware-500n', 'bds-simplified-500n'}, stub_dir);
assert(numel(BDS_PROFILE_MAPPING_CALLS.bds_options_history) == 1);
assert_benchmark_bds_options( ...
    BDS_PROFILE_MAPPING_CALLS.bds_options_history{1}, false, false, false);
assert(BDS_PROFILE_MAPPING_CALLS.recording_objective_calls > 0);

for name = {'cbds-memory-only-200n', 'cbds_memory_only_200n', ...
        'lean-evolved-bds-memory-only'}
    try
        run_profile(name, stub_dir);
        error('verify_profile_workflow_mappings:MissingError', 'Removed profile was accepted.');
    catch exception
        assert(strcmp(exception.identifier, ...
            'profile_optiprofiler:RemovedProductiveDirectionMemory'));
    end
end
for name = {'accelerated-bds-all-on-200n', 'accelerated-ds-all-on-200n', ...
        'bds-accelerated', 'lean-evolved-bds-no-memory'}
    BDS_PROFILE_MAPPING_CALLS = struct();
    run_profile(name, stub_dir);
    options = BDS_PROFILE_MAPPING_CALLS.bds_options;
    assert(~isfield(options, 'use_productive_direction_memory'));
    assert(options.use_iteration_pattern_step && options.use_momentum_extrapolation);
end

clear global BDS_PROFILE_MAPPING_CALLS
clear cleanup

fprintf('PROFILE_WORKFLOW_MAPPINGS_OK\n');

end

function run_profile_pair(solver_name, competitor_name, savepath)

run_profile({solver_name, competitor_name}, savepath);

end


function run_profile(solver_names, savepath)

options.feature_name = 'plain';
options.solver_names = solver_names;
options.problem_names = {'recording_stub'};
options.run_plain = false;
options.summarize_log_ratio_profiles = false;
options.savepath = savepath;
profile_optiprofiler(options);

end

function assert_benchmark_bds_options( ...
        options, use_acceleration, use_function_stop, use_gradient_stop)

assert(strcmp(options.Algorithm, 'cbds'));
assert(options.MaxFunctionEvaluations == 1000);
assert(options.StepTolerance == 1e-6);
assert(isinf(options.ftarget) && options.ftarget < 0);
assert(options.alpha_init == 1);
assert(options.expand == 2.0);
assert(options.shrink == 0.5);
assert(~options.is_noisy);
assert(options.forcing_function(3) == 9);
assert(isequal(options.reduction_factor, [0, eps, eps]));
assert(strcmp(options.polling_inner, 'opportunistic'));
assert(options.cycling_inner == 1);
assert(~isfield(options, 'use_productive_direction_memory'));
assert(options.use_iteration_pattern_step == use_acceleration);
assert(options.use_momentum_extrapolation == use_acceleration);
assert(options.use_function_value_stop == use_function_stop);
assert(options.func_window_size == 20);
assert(options.func_tol == 1e-6);
assert(options.use_estimated_gradient_stop == use_gradient_stop);
assert(options.grad_window_size == 1);
assert(options.grad_tol == 1e-2);
assert(options.lipschitz_constant == 1e3);
assert(options.use_gradient_reference_consistency);
assert(options.grad_reference_finite_difference_error_tol == 1/30);

end

function assert_bfo_wrapper_call(arguments, expected_budget)

epsilon_index = find(strcmp(arguments, 'epsilon'), 1);
maxeval_index = find(strcmp(arguments, 'maxeval'), 1);
verbosity_index = find(strcmp(arguments, 'verbosity'), 1);
assert(~isempty(epsilon_index) && arguments{epsilon_index + 1} == 1e-6);
assert(~isempty(maxeval_index) && arguments{maxeval_index + 1} == expected_budget);
assert(~isempty(verbosity_index) ...
    && strcmp(arguments{verbosity_index + 1}, 'silent'));

end

function write_recording_stubs(stub_dir)

prima_interface_dir = fullfile(stub_dir, 'prima', 'matlab', 'interfaces');
mkdir(prima_interface_dir);

write_text_file(fullfile(stub_dir, 'benchmark.m'), { ...
    'function [solver_scores, profile_scores, curves] = benchmark(solvers, ~)', ...
    'for i_solver = 1:numel(solvers)', ...
    '    solvers{i_solver}(@recording_objective, [1; 2]);', ...
    'end', ...
    'solver_scores = [];', ...
    'profile_scores = [];', ...
    'curves = [];', ...
    'end'});

write_text_file(fullfile(stub_dir, 'bds.m'), { ...
    'function x = bds(~, x0, options)', ...
    'global BDS_PROFILE_MAPPING_CALLS', ...
    'if ~isfield(BDS_PROFILE_MAPPING_CALLS, ''bds_options_history'')', ...
    '    BDS_PROFILE_MAPPING_CALLS.bds_options_history = {};', ...
    'end', ...
    'BDS_PROFILE_MAPPING_CALLS.bds_options_history{end + 1} = options;', ...
    'BDS_PROFILE_MAPPING_CALLS.bds_options = options;', ...
    'x = x0;', ...
    'end'});

write_text_file(fullfile(stub_dir, 'recording_objective.m'), { ...
    'function f = recording_objective(x)', ...
    'global BDS_PROFILE_MAPPING_CALLS', ...
    'if ~isfield(BDS_PROFILE_MAPPING_CALLS, ''recording_objective_calls'')', ...
    '    BDS_PROFILE_MAPPING_CALLS.recording_objective_calls = 0;', ...
    'end', ...
    'BDS_PROFILE_MAPPING_CALLS.recording_objective_calls = ...', ...
    '    BDS_PROFILE_MAPPING_CALLS.recording_objective_calls + 1;', ...
    'f = sum(x.^2);', ...
    'end'});

write_text_file(fullfile(stub_dir, 'bfo.m'), { ...
    'function varargout = bfo(~, x0, varargin)', ...
    'global BDS_PROFILE_MAPPING_CALLS', ...
    'BDS_PROFILE_MAPPING_CALLS.bfo_arguments = varargin;', ...
    'varargout = cell(1, max(1, nargout));', ...
    'varargout{1} = x0;', ...
    'for i_output = 2:nargout', ...
    '    varargout{i_output} = [];', ...
    'end', ...
    'end'});

write_text_file(fullfile(stub_dir, 'nomadOpt.m'), { ...
    'function varargout = nomadOpt(fun, x0, ~, ~, parameters)', ...
    'global BDS_PROFILE_MAPPING_CALLS', ...
    'BDS_PROFILE_MAPPING_CALLS.nomad_parameters = parameters;', ...
    'BDS_PROFILE_MAPPING_CALLS.nomad_objective_value = fun(x0.'');', ...
    'varargout = cell(1, max(1, nargout));', ...
    'varargout{1} = x0;', ...
    'for i_output = 2:nargout', ...
    '    varargout{i_output} = [];', ...
    'end', ...
    'end'});

write_text_file(fullfile(prima_interface_dir, 'newuoa.m'), { ...
    'function x = newuoa(fun, x0, options)', ...
    'global BDS_PROFILE_MAPPING_CALLS', ...
    'BDS_PROFILE_MAPPING_CALLS.newuoa_options = options;', ...
    'BDS_PROFILE_MAPPING_CALLS.newuoa_objective_value = fun(x0);', ...
    'x = x0;', ...
    'end'});

write_text_file(fullfile(stub_dir, 'optimoptions.m'), { ...
    'function options = optimoptions(~, varargin)', ...
    'options = struct();', ...
    'for i_argument = 1:2:numel(varargin)', ...
    '    options.(char(varargin{i_argument})) = varargin{i_argument + 1};', ...
    'end', ...
    'end'});

write_text_file(fullfile(stub_dir, 'fminunc.m'), { ...
    'function x = fminunc(fun, x0, options)', ...
    'global BDS_PROFILE_MAPPING_CALLS', ...
    'BDS_PROFILE_MAPPING_CALLS.fminunc_options = options;', ...
    'BDS_PROFILE_MAPPING_CALLS.fminunc_objective_value = fun(x0);', ...
    'x = x0;', ...
    'end'});

end

function write_text_file(file_path, lines)

file_id = fopen(file_path, 'w');
assert(file_id >= 0, 'Could not create recording stub %s.', file_path);
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '%s\n', lines{:});
clear cleanup

end

function restore_environment(old_path, stub_dir)

path(old_path);
if exist(stub_dir, 'dir')
    rmdir(stub_dir, 's');
end

end
