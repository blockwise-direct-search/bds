function verify_gradient_stopping_threshold()
%VERIFY_GRADIENT_STOPPING_THRESHOLD Check the two-branch gradient stopping rule.
%
%   These black-box cases call the production solver, not its private helpers.
%   Prescribed finite differences exercise both branches, strict boundaries,
%   reference initialization, and incomplete or nonuniform gradient windows.
%   The frozen reference retains its old rule. Compare it only where the two
%   criteria agree, and explicitly check the intended difference otherwise.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
oldpath = path();
cleanup = onCleanup(@() path(oldpath));
addpath(fullfile(root_dir, 'src'));
addpath(fullfile(tests_dir, 'competitors'));

behavior_cases = 0;
for reference_norm = [0, 2^-12, 0.25, 1, 4, 2^12]
    grad_tol = 0.25;
    if reference_norm < 1e-3 || reference_norm > 1e3
        % This fixture makes the fallback boundary exactly representable.
        % It is not a change to the production default or experiment options.
        grad_tol = 125;
    end
    threshold = max(grad_tol * min(1, reference_norm), ...
        1e-3 * grad_tol * max(1, reference_norm));
    for consistency = [false, true]
        reference_samples = 1 + consistency;
        for acceleration = [false, true]
            for factor = [0.5, 1, 2]
                options = stopping_options(1 + 2*(reference_samples + 1), ...
                    1, grad_tol, consistency, acceleration);
                actual = run_case(@bds, options, reference_norm, ...
                    factor * threshold, reference_samples);
                if factor < 1
                    assert(actual.exitflag == 5, 'A strictly sub-threshold gradient did not stop.');
                else
                    assert(actual.exitflag == 1, 'The strict threshold boundary was not respected.');
                end
                assert(actual.output.funcCount == options.MaxFunctionEvaluations);
                behavior_cases = behavior_cases + 1;
            end

            options = stopping_options(1 + 2*(reference_samples + 4), ...
                2, grad_tol, consistency, acceleration);
            actual = run_case(@bds, options, reference_norm, ...
                threshold * [0.5, 2, 0.5, 0.5], reference_samples);
            assert(actual.exitflag == 5 && actual.output.funcCount == options.MaxFunctionEvaluations, ...
                'The solver did not wait until every entry in the window was small.');

            options.MaxFunctionEvaluations = 1 + 2*(reference_samples + 1);
            actual = run_case(@bds, options, reference_norm, threshold / 2, reference_samples);
            assert(actual.exitflag == 1, 'The reference estimate was incorrectly included in the window.');
            behavior_cases = behavior_cases + 2;
        end
    end
end

% Both criteria stop at the first subsequent estimate in this shared case.
options = stopping_options(7, 1, 0.25, false, false);
actual = run_case(@bds, options, 0.25, 2^-5, 1);
reference = run_case(@bds_without_acceleration_reference, ...
    without_acceleration_fields(options), 0.25, 2^-5, 1);
assert(isequaln(actual, reference) && actual.exitflag == 5 && actual.output.funcCount == 5);

% The old threshold is 1/4 and the new threshold is 1/16. A value of 1/8
% must stop the old solver but not production; the following value 1/32
% must stop production. Preserve the common evaluation prefix exactly.
actual = run_case(@bds, options, 0.25, [2^-3, 2^-5], 1);
reference = run_case(@bds_without_acceleration_reference, ...
    without_acceleration_fields(options), 0.25, [2^-3, 2^-5], 1);
assert(reference.exitflag == 5 && reference.output.funcCount == 5);
assert(actual.exitflag == 5 && actual.output.funcCount == 7);
assert(isequaln(reference.calls, actual.calls(:, 1:5)) ...
    && isequaln(reference.output.fhist, actual.output.fhist(1:5)), ...
    'The new stopping rule changed the common evaluation prefix.');

% Turning gradient stopping off must recover complete frozen equivalence,
% including on this case where the enabled criteria deliberately disagree.
options.use_estimated_gradient_stop = false;
actual = run_case(@bds, options, 0.25, [2^-3, 2^-5], 1);
reference = run_case(@bds_without_acceleration_reference, ...
    without_acceleration_fields(options), 0.25, [2^-3, 2^-5], 1);
assert(isequaln(actual, reference) && actual.exitflag == 1);

removed_options = struct('grad_reference_relative_tol', 1e-2);
assert_throws(@() bds(@(x) x^2, 0, removed_options), ...
    'BDS:RemovedGradientReferenceRelativeTolerance');
assert_throws(@() lean_evolved_bds(@(x) x^2, 0, removed_options), ...
    'lean_evolved_bds:RemovedGradientReferenceRelativeTolerance');

fprintf('GRADIENT_STOPPING_THRESHOLD_OK behavior=%d shared=1 changed=1 disabled=1\n', behavior_cases);
end

function options = stopping_options(maxfun, window, grad_tol, consistency, acceleration)

options = struct('Algorithm', 'cbds', 'MaxFunctionEvaluations', maxfun, ...
    'StepTolerance', 0, 'alpha_init', 1, 'expand', 2, 'shrink', 0.5, 'seed', 0, ...
    'use_function_value_stop', false, 'use_estimated_gradient_stop', true, ...
    'grad_window_size', window, 'grad_tol', grad_tol, 'lipschitz_constant', realmin, ...
    'use_gradient_reference_consistency', consistency, ...
    'use_iteration_pattern_step', acceleration, 'use_momentum_extrapolation', acceleration, ...
    'output_xhist', true, 'output_grad_hist', true);

end

function options = without_acceleration_fields(options)

options = rmfield(options, {'use_iteration_pattern_step', 'use_momentum_extrapolation'});

end

function result = run_case(solver, options, reference_norm, later_norms, reference_samples)

calls = zeros(1, 0);
[result.x, result.f, result.exitflag, result.output] = solver(@objective, 0, options);
result.calls = calls;
assert(result.output.funcCount == numel(calls) && numel(calls) <= options.MaxFunctionEvaluations);
assert(isequaln(result.output.xhist, calls) && numel(result.output.fhist) == numel(calls));

    function value = objective(x)
        calls(end + 1) = x;
        if x == 0
            value = 0;
            return
        end
        iteration = 1 + round(-log2(abs(x)));
        gradient = reference_norm;
        if iteration > reference_samples
            gradient = later_norms(min(iteration - reference_samples, numel(later_norms)));
        end
        value = 10 * max(1, reference_norm) + gradient * x;
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
