function verify_gradient_estimate_validity()
%VERIFY_GRADIENT_ESTIMATE_VALIDITY Check structural gradient availability.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
oldpath = path();
cleanup = onCleanup(@() path(oldpath));
addpath(fullfile(root_dir, 'src'));
addpath(fullfile(tests_dir, 'competitors'));

verify_valid_gradient_magnitudes();
verify_nonfinite_gradients();
verify_acceleration_off_zero_gradient_stop();
verify_acceleration_on_zero_gradient_stop();
verify_nontriggering_lean_snapshot();

fprintf('GRADIENT_ESTIMATE_VALIDITY_OK\n');

    function verify_valid_gradient_magnitudes()
        zero_results = run_validity_pair(@(x) 7);
        assert(isequal(zero_results.reference.output.grad_hist, 0), ...
            'An exact zero gradient was not recorded.');

        tiny_results = run_validity_pair(@tiny_gradient_objective);
        tiny_norm = norm(tiny_results.reference.output.grad_hist);
        assert(tiny_norm > 0 && tiny_norm < 10 * eps, ...
            'A finite gradient below the former lower cutoff was not recorded.');

        large_results = run_validity_pair(@large_gradient_objective);
        large_norm = norm(large_results.reference.output.grad_hist);
        assert(isfinite(large_norm) && large_norm > 1e30, ...
            'A finite gradient above the former upper cutoff was not recorded.');
    end

    function verify_nonfinite_gradients()
        nan_results = run_validity_pair(@nan_gradient_objective);
        assert(isempty(nan_results.reference.output.grad_hist), ...
            'A gradient containing NaN was recorded.');

        inf_results = run_validity_pair(@inf_gradient_objective);
        assert(isempty(inf_results.reference.output.grad_hist), ...
            'A gradient containing Inf was recorded.');
    end

    function results = run_validity_pair(objective)
        options = validity_options();
        [results.reference, reference_calls] = run_reference(objective, options);

        production_options = options;
        production_options.use_productive_direction_memory = false;
        production_options.use_iteration_pattern_step = false;
        production_options.use_momentum_extrapolation = false;
        [results.production, production_calls] = ...
            run_production(objective, production_options);

        assert_same_bds_result(results.reference, results.production);
        assert(isequal(reference_calls, [0, 1, -1]) ...
                && isequal(production_calls, reference_calls), ...
            'Gradient validity processing changed the objective-call sequence.');
        assert_objective_accounting(results.reference, reference_calls);
        assert_objective_accounting(results.production, production_calls);
    end

    function verify_acceleration_off_zero_gradient_stop()
        options = gradient_stop_options();
        [reference_result, reference_calls] = run_reference(@(x) 7, options);

        production_options = options;
        production_options.use_productive_direction_memory = false;
        production_options.use_iteration_pattern_step = false;
        production_options.use_momentum_extrapolation = false;
        [production_result, production_calls] = ...
            run_production(@(x) 7, production_options);

        expected_calls = [0, 1, -1, 0.5, -0.5, 0.25, -0.25];
        assert(isequal(reference_calls, expected_calls) ...
                && isequal(production_calls, expected_calls), ...
            'The acceleration-off zero-gradient stop occurred at the wrong evaluation.');
        assert_same_bds_result(reference_result, production_result);
        assert(strcmp(reference_result.output.message, 'The estimated gradient is small.'), ...
            'The acceleration-off case did not stop on the zero gradient.');
        assert_objective_accounting(reference_result, reference_calls);
        assert_objective_accounting(production_result, production_calls);
    end

    function verify_acceleration_on_zero_gradient_stop()
        options = gradient_stop_options();
        options.use_productive_direction_memory = true;
        options.use_iteration_pattern_step = true;
        options.use_momentum_extrapolation = true;
        options.use_gradient_reference_consistency = true;
        options.grad_reference_finite_difference_error_tol = 1/30;
        [production_result, production_calls] = ...
            run_production(@(x) 7, options);

        lean_options = struct( ...
            'use_estimated_gradient_stop', true, ...
            'grad_window_size', options.grad_window_size, ...
            'grad_tol', options.grad_tol, ...
            'lipschitz_constant', options.lipschitz_constant, ...
            'use_gradient_reference_consistency', true, ...
            'grad_reference_finite_difference_error_tol', 1/30);
        [lean_result, lean_calls] = run_lean(@(x) 7, lean_options, false);

        expected_calls = [0, 1, -1, 0.5, -0.5, 0.25, -0.25];
        assert(isequal(production_calls, expected_calls) ...
                && isequal(lean_calls, expected_calls), ...
            'The acceleration-on zero-gradient stop occurred at the wrong evaluation.');
        assert_same_lean_result(production_result, lean_result);
        assert(lean_result.exitflag == 5 && lean_result.output.iterations == 3, ...
            'The acceleration-on case did not stop on the zero gradient.');
        assert_objective_accounting(production_result, production_calls);
    end

    function verify_nontriggering_lean_snapshot()
        lean_options = struct('use_estimated_gradient_stop', true);
        [current_result, current_calls] = run_lean(@(x) -x, lean_options, false);
        [original_result, original_calls] = run_lean(@(x) -x, struct(), true);

        assert(isequal(current_calls, original_calls) ...
                && isequaln(current_result, original_result), ...
            ['The optional lean gradient path changed a trajectory on which ', ...
            'no gradient estimate was available.']);
    end

    function [result, calls] = run_reference(objective, options)
        calls = zeros(1, 0);
        [result.x, result.f, result.exitflag, result.output] = ...
            bds_without_acceleration_reference(@counted_objective, 0, options);

        function value = counted_objective(x)
            calls(end + 1) = x;
            value = objective(x);
        end
    end

    function [result, calls] = run_production(objective, options)
        calls = zeros(1, 0);
        [result.x, result.f, result.exitflag, result.output] = ...
            bds(@counted_objective, 0, options);

        function value = counted_objective(x)
            calls(end + 1) = x;
            value = objective(x);
        end
    end

    function [result, calls] = run_lean(objective, stop_options, use_original)
        calls = zeros(1, 0);
        if use_original
            [result.x, result.f, result.exitflag, result.output] = ...
                lean_evolved_bds_original(@counted_objective, 0);
        else
            [result.x, result.f, result.exitflag, result.output] = ...
                lean_evolved_bds(@counted_objective, 0, stop_options);
        end

        function value = counted_objective(x)
            calls(end + 1) = x;
            value = objective(x);
            if isnan(value)
                value = inf;
            end
        end
    end

end

function options = validity_options()

options = struct( ...
    'Algorithm', 'cbds', ...
    'MaxFunctionEvaluations', 3, ...
    'StepTolerance', 1e-12, ...
    'alpha_init', 1, ...
    'expand', 1.8, ...
    'seed', 0, ...
    'use_function_value_stop', false, ...
    'use_estimated_gradient_stop', false, ...
    'output_xhist', true, ...
    'output_grad_hist', true);

end

function options = gradient_stop_options()

options = struct( ...
    'Algorithm', 'cbds', ...
    'MaxFunctionEvaluations', 50, ...
    'StepTolerance', 1e-12, ...
    'alpha_init', 1, ...
    'expand', 2, ...
    'shrink', 0.5, ...
    'seed', 0, ...
    'use_function_value_stop', false, ...
    'use_estimated_gradient_stop', true, ...
    'grad_window_size', 1, ...
    'grad_tol', 1e-2, ...
    'lipschitz_constant', eps, ...
    'output_xhist', true, ...
    'output_grad_hist', true);

end

function value = tiny_gradient_objective(x)

value = 1 + x^2 + eps * x;

end

function value = large_gradient_objective(x)

value = 1e40 * x^2 + 1e31 * x;

end

function value = nan_gradient_objective(x)

if x > 0
    value = nan;
elseif x < 0
    value = 1;
else
    value = 0;
end

end

function value = inf_gradient_objective(x)

if x > 0
    value = inf;
elseif x < 0
    value = 1;
else
    value = 0;
end

end

function assert_same_bds_result(first, second)

assert(isequaln(first.x, second.x) ...
        && isequaln(first.f, second.f) ...
        && first.exitflag == second.exitflag ...
        && first.output.funcCount == second.output.funcCount ...
        && isequaln(first.output.fhist, second.output.fhist) ...
        && isequaln(first.output.xhist, second.output.xhist) ...
        && isequaln(first.output.grad_hist, second.output.grad_hist) ...
        && isequaln(first.output.grad_xhist, second.output.grad_xhist) ...
        && isequaln(first.output.grad_iter, second.output.grad_iter) ...
        && strcmp(first.output.message, second.output.message), ...
    'Production bds with acceleration off differs from the frozen reference.');

end

function assert_same_lean_result(production, lean)

assert(isequaln(production.x, lean.x) ...
        && isequaln(production.f, lean.f) ...
        && production.exitflag == lean.exitflag ...
        && production.output.funcCount == lean.output.funcCount, ...
    'Production bds with acceleration on differs from lean_evolved_bds.');

end

function assert_objective_accounting(result, calls)

assert(result.output.funcCount == numel(calls), ...
    'output.funcCount does not match the actual objective-call count.');
assert(isequaln(result.output.xhist, calls), ...
    'Some objective calls are missing from output.xhist.');
assert(numel(result.output.fhist) == numel(calls), ...
    'output.fhist does not match the actual objective-call count.');

end
