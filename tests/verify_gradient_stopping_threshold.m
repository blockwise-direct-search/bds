function verify_gradient_stopping_threshold()
%VERIFY_GRADIENT_STOPPING_THRESHOLD Check the reference-scaled gradient rule.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
oldpath = path();
cleanup = onCleanup(@() path(oldpath));
addpath(fullfile(root_dir, 'src'));
addpath(fullfile(tests_dir, 'competitors'));

verify_reference_regimes();
verify_window_requires_every_entry();
verify_acceleration_on_matches_lean();
verify_removed_option_is_rejected();

fprintf('GRADIENT_STOPPING_THRESHOLD_OK\n');

    function verify_reference_regimes()
        grad_tol = 0.25;
        reference_norms = [0.25, 1, 4];

        for reference_norm = reference_norms
            threshold = grad_tol * max(1, reference_norm);
            current_norms = [threshold / 2, threshold, 2 * threshold];
            expected_exitflags = [5, 1, 1];

            for i = 1:numel(current_norms)
                [reference_result, reference_calls] = run_reference_case( ...
                    reference_norm, current_norms(i), 1, 5, grad_tol);
                [production_result, production_calls] = run_production_case( ...
                    reference_norm, current_norms(i), 1, 5, grad_tol, false);

                assert_same_result(reference_result, production_result);
                assert(isequal(reference_calls, production_calls), ...
                    'Acceleration-off changed the objective-call sequence.');
                assert(reference_result.exitflag == expected_exitflags(i), ...
                    'Unexpected decision at a gradient threshold boundary.');
                if expected_exitflags(i) == 5
                    assert(reference_result.output.funcCount == 5, ...
                        'A sub-threshold gradient did not stop at the expected estimate.');
                end
            end
        end
    end

    function verify_window_requires_every_entry()
        reference_norm = 0.25;
        grad_tol = 0.25;
        low = grad_tol * max(1, reference_norm) / 2;
        high = 2 * grad_tol * max(1, reference_norm);
        later_norms = [low, high, low, low];

        [reference_result, reference_calls] = run_reference_case( ...
            reference_norm, later_norms, 2, 11, grad_tol);
        [production_result, production_calls] = run_production_case( ...
            reference_norm, later_norms, 2, 11, grad_tol, false);

        assert_same_result(reference_result, production_result);
        assert(isequal(reference_calls, production_calls), ...
            'Acceleration-off changed the multi-entry-window call sequence.');
        assert(reference_result.exitflag == 5 ...
                && reference_result.output.funcCount == 11, ...
            'The solver stopped before every gradient-window entry was small.');
    end

    function verify_acceleration_on_matches_lean()
        reference_norm = 4;
        grad_tol = 0.25;
        current_norm = grad_tol * reference_norm / 2;

        [production_result, production_calls] = run_production_case( ...
            reference_norm, current_norm, 1, 5, grad_tol, true);
        [lean_result, lean_calls] = run_lean_case( ...
            reference_norm, current_norm, grad_tol);

        assert(isequal(production_calls, lean_calls), ...
            'Acceleration-on and lean used different objective-call sequences.');
        assert(isequaln(production_result.x, lean_result.x) ...
                && isequaln(production_result.f, lean_result.f) ...
                && production_result.exitflag == lean_result.exitflag ...
                && production_result.output.funcCount == lean_result.output.funcCount, ...
            'Acceleration-on differs from lean at the reference-scaled threshold.');
        assert(production_result.exitflag == 5 ...
                && production_result.output.funcCount == 5, ...
            'The acceleration-on threshold case did not trigger as expected.');
    end

    function verify_removed_option_is_rejected()
        removed_options = struct('grad_reference_relative_tol', 1e-2);
        assert_throws(@() bds(@(x) x^2, 0, removed_options), ...
            'BDS:RemovedGradientReferenceRelativeTolerance');
        assert_throws(@() lean_evolved_bds(@(x) x^2, 0, removed_options), ...
            'lean_evolved_bds:RemovedGradientReferenceRelativeTolerance');
    end

    function [result, calls] = run_reference_case( ...
            reference_norm, later_norms, window_size, maxfun, grad_tol)
        options = stopping_options(window_size, maxfun, grad_tol);
        [result, calls] = run_solver( ...
            @bds_without_acceleration_reference, options, reference_norm, later_norms);
    end

    function [result, calls] = run_production_case( ...
            reference_norm, later_norms, window_size, maxfun, grad_tol, acceleration_on)
        options = stopping_options(window_size, maxfun, grad_tol);
        options.use_productive_direction_memory = acceleration_on;
        options.use_iteration_pattern_step = acceleration_on;
        options.use_momentum_extrapolation = acceleration_on;
        [result, calls] = run_solver( ...
            @bds, options, reference_norm, later_norms);
    end

    function [result, calls] = run_lean_case(reference_norm, later_norms, grad_tol)
        calls = zeros(1, 0);
        options = struct( ...
            'use_estimated_gradient_stop', true, ...
            'grad_window_size', 1, ...
            'grad_tol', grad_tol, ...
            'lipschitz_constant', realmin, ...
            'use_gradient_reference_consistency', false);
        [result.x, result.f, result.exitflag, result.output] = ...
            lean_evolved_bds(@objective, 0, options);

        function value = objective(x)
            calls(end + 1) = x;
            value = prescribed_value(x, reference_norm, later_norms);
        end
    end

    function [result, calls] = run_solver( ...
            solver, options, reference_norm, later_norms)
        calls = zeros(1, 0);
        [result.x, result.f, result.exitflag, result.output] = ...
            solver(@objective, 0, options);

        function value = objective(x)
            calls(end + 1) = x;
            value = prescribed_value(x, reference_norm, later_norms);
        end
    end

end

function assert_throws(call, expected_identifier)

try
    call();
catch exception
    assert(strcmp(exception.identifier, expected_identifier), ...
        'The removed option raised an unexpected error.');
    return
end
error('The removed gradient-reference option was silently accepted.');

end

function options = stopping_options(window_size, maxfun, grad_tol)

options = struct( ...
    'Algorithm', 'cbds', ...
    'MaxFunctionEvaluations', maxfun, ...
    'StepTolerance', 0, ...
    'alpha_init', 1, ...
    'expand', 2, ...
    'shrink', 0.5, ...
    'seed', 0, ...
    'use_function_value_stop', false, ...
    'use_estimated_gradient_stop', true, ...
    'grad_window_size', window_size, ...
    'grad_tol', grad_tol, ...
    'lipschitz_constant', realmin, ...
    'use_gradient_reference_consistency', false, ...
    'output_xhist', true, ...
    'output_grad_hist', true);

end

function value = prescribed_value(x, reference_norm, later_norms)

if x == 0
    value = 0;
    return
end

step = abs(x);
if step == 1
    gradient = reference_norm;
else
    index = max(1, round(-log2(step)));
    gradient = later_norms(min(index, numel(later_norms)));
end
value = 100 + gradient * x;

end

function assert_same_result(first, second)

assert(isequaln(first.x, second.x) ...
        && isequaln(first.f, second.f) ...
        && first.exitflag == second.exitflag ...
        && first.output.funcCount == second.output.funcCount ...
        && isequaln(first.output.fhist, second.output.fhist) ...
        && isequaln(first.output.xhist, second.output.xhist) ...
        && isequaln(first.output.grad_hist, second.output.grad_hist), ...
    'Production acceleration-off differs from the frozen BDS reference.');

end
