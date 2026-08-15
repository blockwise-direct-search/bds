function verify_bds_momentum_duplicate()
%VERIFY_BDS_MOMENTUM_DUPLICATE Check exact duplicate suppression.

tests_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(tests_dir, 'competitors'));
addpath(fullfile(tests_dir, 'misc'));
cleanup = onCleanup(@() restore_paths(tests_dir));

verify_accelerated_budget_case();
verify_reference_budget_case();
verify_nontriggering_case();

fprintf('BDS_MOMENTUM_DUPLICATE_OK\n');

    function verify_accelerated_budget_case()
        calls = zeros(1, 0);
        options = struct('Algorithm', 'cbds', ...
            'MaxFunctionEvaluations', 4, ...
            'StepTolerance', 1e-6, ...
            'use_productive_direction_memory', false, ...
            'use_iteration_pattern_step', true, ...
            'use_momentum_extrapolation', true, ...
            'output_xhist', true);
        [~, ~, ~, output] = accelerated_bds_options(@counted_quadratic, 0, options);

        expected = [0, 1, 2, 3];
        assert(isequal(calls, expected), ...
            'The accelerated budget case did not remove exactly the repeated point.');
        assert(isequal(output.xhist, expected) && output.funcCount == numel(expected), ...
            'The accelerated histories do not match the actual objective calls.');
        assert(isequal(output.fhist, [1, 0, 1, 4]), ...
            'The accelerated function history is incorrect after the skip.');

        function value = counted_quadratic(x)
            calls(end + 1) = x;
            value = (x - 1)^2;
        end
    end

    function verify_reference_budget_case()
        legacy_calls = run_reference_1d(@lean_evolved_bds_legacy);
        original_calls = run_reference_1d(@lean_evolved_bds_original);
        current_calls = run_reference_1d(@lean_evolved_bds);

        assert(isequal(legacy_calls(1:4), [0, 1, 2, 2]), ...
            'The misc legacy copy does not expose the expected duplicate.');
        assert(isequal(original_calls(1:4), [0, 1, 2, 3]), ...
            'The pre-termination lean snapshot did not preserve duplicate suppression.');
        assert(isequal(current_calls, original_calls), ...
            'The current lean solver changed when function-value stopping is disabled.');
    end

    function calls = run_reference_1d(solver, objective)
        if nargin < 2
            objective = @(x) (x - 1)^2;
        end
        calls = zeros(1, 0);
        solver(@counted_quadratic, 0);

        function value = counted_quadratic(x)
            calls(end + 1) = x;
            value = objective(x);
        end
    end

    function verify_nontriggering_case()
        original_calls = run_reference_1d(@lean_evolved_bds_original, @(x) -x);
        current_calls = run_reference_1d(@lean_evolved_bds, @(x) -x);
        assert(isequal(original_calls, current_calls), ...
            'The current lean solver changed a nontriggering trajectory.');
    end

end

function restore_paths(tests_dir)
rmpath(fullfile(tests_dir, 'misc'));
rmpath(fullfile(tests_dir, 'competitors'));
end
