function verify_function_value_reference()
%VERIFY_FUNCTION_VALUE_REFERENCE Check the first-finite incumbent reference.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
oldpath = path();
cleanup = onCleanup(@() path(oldpath));
addpath(fullfile(root_dir, 'src'));
addpath(fullfile(tests_dir, 'competitors'));

verify_acceleration_off_recovery();
verify_acceleration_on_recovery();
verify_nontriggering_lean_snapshot();
verify_finite_initial_value();

fprintf('FUNCTION_VALUE_REFERENCE_OK\n');

    function verify_acceleration_off_recovery()
        options = function_stop_options();
        options.expand = 1;

        [bds_result, bds_calls] = run_bds( ...
            @(x) delayed_recovery_objective(x, 0), options);

        accelerated_options = options;
        accelerated_options.use_productive_direction_memory = false;
        accelerated_options.use_iteration_pattern_step = false;
        accelerated_options.use_momentum_extrapolation = false;
        [accelerated_result, accelerated_calls] = run_accelerated( ...
            @(x) delayed_recovery_objective(x, 0), accelerated_options);

        expected_calls = [0, 1, 2, 3, 1];
        assert(isequal(bds_calls, expected_calls), ...
            ['bds stopped when the first complete finite window still ', ...
            'contained a substantial decrease.']);
        assert(isequal(accelerated_calls, expected_calls), ...
            ['The acceleration-off solver stopped when the first complete ', ...
            'finite window still contained a substantial decrease.']);
        assert_same_bds_result(bds_result, accelerated_result);
        assert(bds_result.exitflag == 4 && bds_result.x == 2 && bds_result.f == 5, ...
            'The acceleration-off recovery case did not use function-value stopping.');

        [shifted_bds_result, shifted_bds_calls] = run_bds( ...
            @(x) delayed_recovery_objective(x, 100), options);
        assert_translation_invariant( ...
            bds_result, bds_calls, shifted_bds_result, shifted_bds_calls, 100);
    end

    function verify_acceleration_on_recovery()
        options = function_stop_options();
        options.use_productive_direction_memory = true;
        options.use_iteration_pattern_step = true;
        options.use_momentum_extrapolation = true;
        stop_options = lean_stop_options(2);

        [accelerated_result, accelerated_calls] = run_accelerated( ...
            @(x) accelerated_recovery_objective(x, 0), options);
        [lean_result, lean_calls] = run_lean( ...
            @(x) accelerated_recovery_objective(x, 0), stop_options, false);

        expected_calls = [0, 1, 2, 3, 7, 5, 1, 5, 5, 4, 2];
        assert(isequal(accelerated_calls, expected_calls) ...
                && isequal(lean_calls, expected_calls), ...
            ['The acceleration-on solvers did not continue past the first ', ...
            'finite window before stopping on a stable window.']);
        assert_same_lean_result(accelerated_result, lean_result);
        assert(lean_result.exitflag == 4 && lean_result.output.iterations == 3, ...
            'The acceleration-on recovery case did not use function-value stopping.');

        [shifted_accelerated_result, shifted_accelerated_calls] = run_accelerated( ...
            @(x) accelerated_recovery_objective(x, 100), options);
        [shifted_lean_result, shifted_lean_calls] = run_lean( ...
            @(x) accelerated_recovery_objective(x, 100), stop_options, false);
        assert_translation_invariant(accelerated_result, accelerated_calls, ...
            shifted_accelerated_result, shifted_accelerated_calls, 100);
        assert_same_lean_result(shifted_accelerated_result, shifted_lean_result);
        assert(isequal(shifted_accelerated_calls, shifted_lean_calls), ...
            'The shifted acceleration-on objective changed the lean call sequence.');
    end

    function verify_nontriggering_lean_snapshot()
        stop_options = lean_stop_options(1000);
        objective = @(x) (x - 1)^2;
        [current_result, current_calls] = run_lean(objective, stop_options, false);
        [original_result, original_calls] = run_lean(objective, struct(), true);

        assert(isequal(current_calls, original_calls) ...
                && isequaln(current_result, original_result), ...
            ['lean_evolved_bds changed relative to its pre-termination ', ...
            'snapshot when the new stopping test could not trigger.']);
    end

    function verify_finite_initial_value()
        options = function_stop_options();
        constant_objective = @(x) 7;

        [bds_result, bds_calls] = run_bds(constant_objective, options);
        off_options = options;
        off_options.use_productive_direction_memory = false;
        off_options.use_iteration_pattern_step = false;
        off_options.use_momentum_extrapolation = false;
        [off_result, off_calls] = run_accelerated(constant_objective, off_options);
        assert_same_bds_result(bds_result, off_result);
        assert(isequal(bds_calls, off_calls) && bds_result.exitflag == 4, ...
            'Finite-initial-value behavior changed in the acceleration-off case.');

        on_options = options;
        on_options.use_productive_direction_memory = true;
        on_options.use_iteration_pattern_step = true;
        on_options.use_momentum_extrapolation = true;
        [on_result, on_calls] = run_accelerated(constant_objective, on_options);
        [lean_result, lean_calls] = run_lean( ...
            constant_objective, lean_stop_options(2), false);
        assert_same_lean_result(on_result, lean_result);
        assert(isequal(on_calls, lean_calls) && on_result.exitflag == 4, ...
            'Finite-initial-value behavior changed in the acceleration-on case.');
    end

    function [result, calls] = run_bds(objective, options)
        calls = zeros(1, 0);
        [result.x, result.f, result.exitflag, result.output] = ...
            bds(@counted_objective, 0, options);

        function value = counted_objective(x)
            calls(end + 1) = x;
            value = objective(x);
        end
    end

    function [result, calls] = run_accelerated(objective, options)
        calls = zeros(1, 0);
        [result.x, result.f, result.exitflag, result.output] = ...
            accelerated_bds_options(@counted_objective, 0, options);

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

function options = function_stop_options()

options = struct( ...
    'Algorithm', 'cbds', ...
    'MaxFunctionEvaluations', 200, ...
    'StepTolerance', 1e-6, ...
    'alpha_init', 1, ...
    'expand', 2, ...
    'shrink', 0.5, ...
    'seed', 0, ...
    'use_function_value_stop', true, ...
    'func_window_size', 2, ...
    'func_tol', 1e-6, ...
    'use_estimated_gradient_stop', false, ...
    'output_xhist', true);

end

function options = lean_stop_options(window_size)

options = struct( ...
    'use_function_value_stop', true, ...
    'func_window_size', window_size, ...
    'func_tol', 1e-6);

end

function value = delayed_recovery_objective(x, shift)

if x == 0
    value = nan;
elseif x == 1
    value = 10 + shift;
else
    value = 5 + shift;
end

end

function value = accelerated_recovery_objective(x, shift)

if x == 0
    value = nan;
elseif x == 1
    value = 10 + shift;
elseif x == 2
    value = 20 + shift;
else
    value = 5 + shift;
end

end

function assert_same_bds_result(first, second)

assert(isequaln(first.x, second.x) ...
        && isequaln(first.f, second.f) ...
        && first.exitflag == second.exitflag ...
        && first.output.funcCount == second.output.funcCount ...
        && isequaln(first.output.fhist, second.output.fhist) ...
        && isequaln(first.output.xhist, second.output.xhist) ...
        && strcmp(first.output.message, second.output.message), ...
    'accelerated_bds_options with acceleration off differs from bds.');

end

function assert_same_lean_result(accelerated, lean)

assert(isequaln(accelerated.x, lean.x) ...
        && isequaln(accelerated.f, lean.f) ...
        && accelerated.exitflag == lean.exitflag ...
        && accelerated.output.funcCount == lean.output.funcCount, ...
    'accelerated_bds_options with acceleration on differs from lean_evolved_bds.');

end

function assert_translation_invariant( ...
        original, original_calls, shifted, shifted_calls, shift)

assert(isequal(original_calls, shifted_calls) ...
        && isequaln(original.x, shifted.x) ...
        && shifted.f == original.f + shift ...
        && shifted.exitflag == original.exitflag ...
        && shifted.output.funcCount == original.output.funcCount, ...
    'Adding a constant to finite objective values changed the stopping iteration.');

end
