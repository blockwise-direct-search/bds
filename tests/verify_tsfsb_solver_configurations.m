function verify_tsfsb_solver_configurations()
%VERIFY_TSFSB_SOLVER_CONFIGURATIONS Check production TSFSB solver options.
%
%   Ported from the C02 verify_c02_bds_family_configurations.m (commit
%   846d5c5f) for the three BDS-family configurations, extended with the
%   seven external solver configurations of the TSFSB pool. External
%   solver execution is gated on availability: NOMAD, PRIMA, and BFO are
%   skipped with a printed SKIP marker when absent (CI-safe), while the
%   BDS family, PDS, and paper-exact LAM are in the repository and must
%   always run.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
module_dir = fullfile(root_dir, 'research', 'ten_solver_full_set_benchmark');
old_path = path();
cleanup = onCleanup(@() path(old_path));
addpath(fullfile(root_dir, 'src'));
addpath(tests_dir);
addpath(fullfile(tests_dir, 'competitors'));
addpath(module_dir);

verify_bds_family();
verify_external_option_structs();
verify_external_execution();

fprintf('VERIFY_TSFSB_SOLVER_CONFIGURATIONS_OK\n');
clear cleanup

end

function verify_bds_family()

for n = [2, 7]
    x0 = (0:(n - 1))';
    coordinate_steps = max(abs(x0), 1e-6);
    coordinate_steps(x0 == 0) = 1;
    configurations = { ...
        'bds', coordinate_steps, true; ...
        'bds-without-acceleration', coordinate_steps, false; ...
        'ds', max(coordinate_steps), false};

    for i = 1:size(configurations, 1)
        configuration = configurations{i, 1};
        expected_steps = configurations{i, 2};
        use_acceleration = configurations{i, 3};
        [options, metadata] = tsfsb_benchmark_options(x0, configuration);

        assert(strcmp(options.Algorithm, tern(strcmp(configuration, 'ds'), ...
            'ds', 'cbds')));
        assert(strcmp(options.alpha_init, 'auto'));
        assert(options.MaxFunctionEvaluations == 500 * n);
        assert(options.StepTolerance == 1e-6);
        assert(options.ftarget == -Inf);
        assert(options.expand == 2 && options.shrink == 0.5);
        assert(~options.is_noisy);
        assert(isequal(options.reduction_factor, [0, eps, eps]));
        assert(strcmp(options.polling_inner, 'opportunistic'));
        assert(options.cycling_inner == 1);
        assert(options.use_productive_direction_memory == use_acceleration);
        assert(options.use_iteration_pattern_step == use_acceleration);
        assert(options.use_momentum_extrapolation == use_acceleration);
        assert(options.use_function_value_stop);
        assert(options.func_window_size == 20 && options.func_tol == 1e-6);
        assert(options.use_estimated_gradient_stop);
        assert(options.grad_window_size == 1 && options.grad_tol == 1e-2);
        assert(options.lipschitz_constant == 1e3);
        assert(options.use_gradient_reference_consistency);
        assert(options.grad_reference_finite_difference_error_tol == 1/30);
        assert(metadata.number_of_blocks == ...
            tern(strcmp(configuration, 'ds'), 1, n));
        assert(isequal(metadata.expected_block_initial_step_sizes, ...
            expected_steps));

        options.MaxFunctionEvaluations = 12;
        options.output_alpha_hist = true;
        [~, ~, ~, output] = bds(@focused_objective, x0, options);
        assert(isequal(output.alpha_hist(:, 1), expected_steps(:)), ...
            'Unexpected production initial steps for %s at n=%d.', ...
            configuration, n);
    end
end

end

function verify_external_option_structs()

n = 4;
x0 = ones(n, 1);

nomad_options = tsfsb_external_solver_options(x0, 'nomad');
assert(isequal(fieldnames(nomad_options), {'MaxFunctionEvaluations'}));
assert(nomad_options.MaxFunctionEvaluations == 500 * n);

lam_options = tsfsb_external_solver_options(x0, 'lam');
assert(lam_options.MaxFunctionEvaluations == 500 * n);
assert(lam_options.StepTolerance == 1e-5);
assert(isinf(lam_options.MaxIterations));
assert(lam_options.ftarget == -Inf);

newuoa_options = tsfsb_external_solver_options(x0, 'newuoa');
assert(strcmp(newuoa_options.Algorithm, 'newuoa'));
assert(newuoa_options.MaxFunctionEvaluations == 500 * n);
assert(newuoa_options.StepTolerance == 1e-6);
assert(newuoa_options.alpha_init == 1);

fd_options = tsfsb_external_solver_options(x0, 'fd-bfgs');
assert(fd_options.MaxObjectiveEvaluations == 500 * n);
assert(fd_options.StepTolerance == 1e-6);
assert(fd_options.ftarget == -Inf);
assert(~fd_options.with_gradient);
assert(~isfield(fd_options, 'noise_level'));
fd_noisy_options = tsfsb_external_solver_options(x0, 'fd-bfgs', 1e-3);
assert(fd_noisy_options.with_gradient);
assert(fd_noisy_options.noise_level == 1e-3);

pds_options = tsfsb_external_solver_options(x0, 'pds');
assert(isequal(sort(fieldnames(pds_options)), ...
    sort({'MaxFunctionEvaluations'; 'expand'; 'shrink'})));
assert(pds_options.MaxFunctionEvaluations == 500 * n);
assert(pds_options.expand == 2 && pds_options.shrink == 0.5);

bfo_options = tsfsb_external_solver_options(x0, 'bfo');
assert(isequal(sort(fieldnames(bfo_options)), ...
    sort({'MaxFunctionEvaluations'; 'StepTolerance'})));
assert(bfo_options.StepTolerance == 1e-6);
assert(bfo_options.MaxFunctionEvaluations == 500 * n);

nm_options = tsfsb_external_solver_options(x0, 'nelder-mead');
assert(isequal(sort(fieldnames(nm_options)), ...
    sort({'MaxFunctionEvaluations'; 'StepTolerance'})));
assert(nm_options.MaxFunctionEvaluations == 500 * n);
assert(nm_options.StepTolerance == 1e-6);

assert_throws(@() tsfsb_external_solver_options(x0, 'unknown-solver'), ...
    'tsfsb_external_solver_options:InvalidSolver');

end

function verify_external_execution()

n = 4;
budget = 500 * n;
x0 = ones(n, 1);
objective = @(x) sum((x - linspace(-0.5, 0.5, numel(x))').^2) ...
    + 0.01 * sum(sin(x));

% In-repository solvers must always run.
for configuration = {'bds', 'bds-without-acceleration', 'ds'}
    options = tsfsb_benchmark_options(x0, configuration{1});
    [x, ~, exitflag, output] = bds(objective, x0, options);
    assert(output.funcCount <= budget);
    assert(isnumeric(exitflag) && isscalar(exitflag));
    assert(all(isfinite(x)));
end

pds_options = tsfsb_external_solver_options(x0, 'pds');
pds_options.seed = tsfsb_pds_seed(x0);
[x, ~, exitflag, output] = pds(objective, x0, pds_options);
assert(output.funcCount <= budget);
assert(isnumeric(exitflag) && isscalar(exitflag));
assert(all(isfinite(x)));
[x_repeat, ~, ~, output_repeat] = pds(objective, x0, pds_options);
assert(isequal(x, x_repeat) && output.funcCount == output_repeat.funcCount);

lam_options = tsfsb_external_solver_options(x0, 'lam');
[x, ~, exitflag, output] = lam_paper_exact(objective, x0, lam_options);
assert(output.funcCount <= budget);
assert(isnumeric(exitflag) && isscalar(exitflag));
assert(all(isfinite(x)));

nm_options = optimset('MaxFunEvals', budget, 'MaxIter', 1e20, ...
    'TolFun', eps, 'TolX', 1e-6);
[x, ~, exitflag, output] = fminsearch(objective, x0, nm_options);
assert(output.funcCount <= budget);
assert(ismember(exitflag, [0, 1]));
assert(all(isfinite(x)));

% External solvers are gated on availability.
if isempty(which('fminunc'))
    fprintf('VERIFY_TSFSB_SOLVER_CONFIGURATIONS_SKIP fd-bfgs\n');
else
    fd_options = tsfsb_external_solver_options(x0, 'fd-bfgs');
    optim_options = optimoptions('fminunc', ...
        'Algorithm', 'quasi-newton', ...
        'HessUpdate', 'bfgs', ...
        'MaxFunctionEvaluations', fd_options.MaxObjectiveEvaluations, ...
        'MaxIterations', 1e20, ...
        'ObjectiveLimit', fd_options.ftarget, ...
        'StepTolerance', fd_options.StepTolerance, ...
        'OptimalityTolerance', eps, ...
        'SpecifyObjectiveGradient', false);
    [x, ~, exitflag, output] = fminunc(objective, x0, optim_options);
    assert(output.funcCount <= budget);
    assert(isnumeric(exitflag) && isscalar(exitflag));
    assert(all(isfinite(x)));
end

if isempty(which('nomadOpt'))
    fprintf('VERIFY_TSFSB_SOLVER_CONFIGURATIONS_SKIP nomad\n');
else
    nomad_options = tsfsb_external_solver_options(x0, 'nomad');
    params = struct('min_frame_size', '* 0.000001', ...
        'MAX_BB_EVAL', num2str(nomad_options.MaxFunctionEvaluations), ...
        'max_eval', num2str(nomad_options.MaxFunctionEvaluations));
    [x, ~, ~, ~, evaluations] = nomadOpt(@(x) objective(x(:)), x0, ...
        -inf(n, 1), inf(n, 1), params);
    assert(evaluations <= budget);
    assert(all(isfinite(x)));
end

if isempty(which('newuoa'))
    fprintf('VERIFY_TSFSB_SOLVER_CONFIGURATIONS_SKIP newuoa\n');
else
    newuoa_options = struct('rhobeg', 1, 'rhoend', 1e-6, ...
        'maxfun', budget, 'iprint', 0);
    [x, ~, exitflag, output] = newuoa(objective, x0, newuoa_options);
    if isfield(output, 'funcCount')
        assert(output.funcCount <= budget);
    end
    assert(isnumeric(exitflag) && isscalar(exitflag));
    assert(all(isfinite(x)));
end

if isempty(which('bfo'))
    fprintf('VERIFY_TSFSB_SOLVER_CONFIGURATIONS_SKIP bfo\n');
else
    [x, ~, ~, ~, evaluations] = bfo(objective, x0, 'epsilon', 1e-6, ...
        'maxeval', budget, 'verbosity', 'silent');
    assert(evaluations <= budget);
    assert(all(isfinite(x)));
end

end

function value = tern(condition, value_if_true, value_if_false)

if condition
    value = value_if_true;
else
    value = value_if_false;
end

end

function assert_throws(function_handle, identifier)

try
    function_handle();
catch error_record
    assert(strcmp(error_record.identifier, identifier));
    return;
end
error('verify_tsfsb_solver_configurations:ExpectedError', ...
    'Expected error %s was not raised.', identifier);

end

function f = focused_objective(x)

x = x(:);
target = linspace(-0.5, 0.5, numel(x))';
f = sum((x - target).^2) + 0.01 * sum(sin(x));

end
