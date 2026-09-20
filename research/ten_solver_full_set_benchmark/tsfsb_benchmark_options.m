function [options, metadata] = tsfsb_benchmark_options(x0, configuration)
%TSFSB_BENCHMARK_OPTIONS Fixed BDS-family options for the TSFSB experiments.
%
%   Ported verbatim (option semantics) from the C02
%   c02_benchmark_options.m (commit 846d5c5f). The expected initial step
%   metadata kept here is used by the configuration verifier.

x0 = double(x0(:));
n = numel(x0);
if n < 1 || any(~isfinite(x0))
    error('tsfsb_benchmark_options:InvalidInitialPoint', ...
        'x0 must be a nonempty finite real vector.');
end

configuration = char(lower(string(configuration)));
valid_configurations = {'bds', 'bds-without-acceleration', 'ds'};
if ~ismember(configuration, valid_configurations)
    error('tsfsb_benchmark_options:InvalidConfiguration', ...
        'Unknown TSFSB BDS-family configuration ''%s''.', configuration);
end

step_tolerance = 1e-6;
coordinate_steps = max(abs(x0), step_tolerance);
coordinate_steps(x0 == 0) = max(1, step_tolerance);

options = struct();
if strcmp(configuration, 'ds')
    options.Algorithm = 'ds';
    use_acceleration = false;
    number_of_blocks = 1;
    expected_block_steps = max(coordinate_steps);
else
    options.Algorithm = 'cbds';
    use_acceleration = strcmp(configuration, 'bds');
    number_of_blocks = n;
    expected_block_steps = coordinate_steps;
end
options.alpha_init = 'auto';

options.MaxFunctionEvaluations = 500 * n;
options.StepTolerance = step_tolerance;
options.ftarget = -Inf;
options.expand = 2;
options.shrink = 0.5;
options.is_noisy = false;
options.forcing_function = @(alpha) alpha^2;
options.reduction_factor = [0, eps, eps];
options.polling_inner = 'opportunistic';
options.cycling_inner = 1;
options.use_productive_direction_memory = use_acceleration;
options.use_iteration_pattern_step = use_acceleration;
options.use_momentum_extrapolation = use_acceleration;
options.use_function_value_stop = true;
options.func_window_size = 20;
options.func_tol = 1e-6;
options.use_estimated_gradient_stop = true;
options.grad_window_size = 1;
options.grad_tol = 1e-2;
options.lipschitz_constant = 1e3;
options.use_gradient_reference_consistency = true;
options.grad_reference_finite_difference_error_tol = 1/30;

metadata = struct( ...
    'configuration', configuration, ...
    'number_of_blocks', number_of_blocks, ...
    'automatic_initial_step_sizes', true, ...
    'coordinate_initial_step_sizes', coordinate_steps, ...
    'expected_block_initial_step_sizes', expected_block_steps, ...
    'use_acceleration', use_acceleration, ...
    'use_function_value_stop', true, ...
    'use_estimated_gradient_stop', true, ...
    'gradient_reference_absolute_error_tolerance', 1e-3, ...
    'gradient_reference_relative_error_tolerance', 1e-1, ...
    'budget_factor', 500, ...
    'step_tolerance', step_tolerance);

end
