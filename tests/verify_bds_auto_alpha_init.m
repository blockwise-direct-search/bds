function verify_bds_auto_alpha_init()
%VERIFY_BDS_AUTO_ALPHA_INIT Check the public BDS automatic-step path.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
old_path = path();
cleanup = onCleanup(@() path(old_path));
addpath(fullfile(root_dir, 'src'));

x0 = [0; 2; -3; 1e-8];
StepTolerance = 1e-6;
expected_alpha = [1; 2; 3; 1e-6];
candidate_alpha = auto_alpha_init_candidate(x0, StepTolerance, 1, 1);
assert(isequal(candidate_alpha, expected_alpha), ...
    'The test-only (1,1) candidate no longer implements the frozen rule.');

for use_acceleration = [false, true]
    auto_result = run_solver('auto', use_acceleration, x0, ...
        StepTolerance, 80);
    numeric_result = run_solver(candidate_alpha, use_acceleration, x0, ...
        StepTolerance, 80);
    assert(isequaln(auto_result, numeric_result), ...
        ['The public auto path differs from the validated numeric (1,1) ', ...
        'path when use_acceleration=%d.'], use_acceleration);
    assert(isequal(auto_result.output.alpha_hist(:, 1), expected_alpha), ...
        'The public auto path produced unexpected initial steps.');
end

vector_tolerance = [2; 1e-6; 1e-2; 1e-10];
expected_vector_alpha = [2; 2; 3; 1e-8];
vector_result = run_solver('auto', true, x0, vector_tolerance, 1);
assert(isequal(vector_result.output.alpha_hist(:, 1), expected_vector_alpha), ...
    'The public auto path does not respect vector StepTolerance.');

fprintf('BDS_AUTO_ALPHA_INIT_OK\n');
clear cleanup

end

function result = run_solver(alpha_init, use_acceleration, x0, StepTolerance, maxfun)

options = struct();
options.Algorithm = 'cbds';
options.MaxFunctionEvaluations = maxfun;
options.StepTolerance = StepTolerance;
options.alpha_init = alpha_init;
options.seed = 0;
options.use_productive_direction_memory = use_acceleration;
options.use_iteration_pattern_step = use_acceleration;
options.use_momentum_extrapolation = use_acceleration;
options.use_function_value_stop = false;
options.use_estimated_gradient_stop = false;
options.output_xhist = true;
options.output_alpha_hist = true;
options.output_block_hist = true;

[result.x, result.f, result.exitflag, result.output] = ...
    bds(@focused_objective, x0, options);

end

function f = focused_objective(x)

x = x(:);
target = [1; -1; 0.5; 2];
A = diag([1, 2, 3, 4]) + 0.05 * ones(4);
f = sum((A * (x - target)).^2) + 0.01 * sum(sin(x));

end
