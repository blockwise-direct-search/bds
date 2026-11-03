function threshold_unit_test(root)
%THRESHOLD_UNIT_TEST Check the actual predicate and full solver behavior.
%
%   root                               Isolated experiment directory containing candidate/src,
%                                      maintained tests, and the frozen MP reference.

addpath(fullfile(root, 'candidate', 'src'), fullfile(root, 'candidate', 'examples'), ...
    fullfile(root, 'candidate', 'tests', 'competitors'), fullfile(root, 'reference', 'mp'));
code = fileread(fullfile(root, 'candidate', 'src', 'bds_dual_threshold.m'));
start = strfind(code, 'if reference_grad_norm_initialized ...');
assert(numel(start) == 1);
tail = code(start:end);
finish = strfind(tail, 'terminate = true;');
expression = regexprep(strtrim(strrep(tail(4:finish(1)-1), '...', '')), '\s+', ' ');
predicate_cases = 0;
for reference_grad_norm = [0, 2^-12, 0.25, 1, 4, 2^12]
    grad_tol = 0.25;
    limit = max(grad_tol * min(1, reference_grad_norm), ...
        1e-3 * grad_tol * max(1, reference_grad_norm));
    for values = {[limit/2], [limit], [2*limit], [limit/2, limit], ...
            [limit/2, limit/2], [nan, limit/2], [inf, limit/2]}
        norm_grad_window = values{1};
        for reference_grad_norm_initialized = [false, true]
            actual = eval(expression);
            expected = reference_grad_norm_initialized && all(norm_grad_window < limit);
            assert(actual == expected);
            assert(~actual || all(norm_grad_window < grad_tol * max(1, reference_grad_norm)));
            predicate_cases = predicate_cases + 1;
        end
    end
end

% Prescribed finite differences exercise both branches through the real solver.
% Artificial tolerances/error constants are fixtures only, not benchmark settings.
behavior_cases = 0;
for reference_norm = [2^-12, 0.25, 1, 4, 2^12]
    tol = 0.25;
    threshold = max(tol * min(1, reference_norm), 1e-3 * tol * max(1, reference_norm));
    for consistent = [false, true]
        reference_samples = 1 + consistent;
        for acceleration = [false, true]
            for factor = [0.5, 2]
                options = fixture_options(1 + 2*(reference_samples+1), 1, tol, consistent, acceleration);
                actual = prescribed_run(@bds_dual_threshold, options, reference_norm, factor*threshold, reference_samples);
                assert((actual.flag == 5) == (factor < 1));
                assert(actual.output.funcCount == options.MaxFunctionEvaluations);
                behavior_cases = behavior_cases + 1;
            end
            options = fixture_options(1 + 2*(reference_samples+4), 2, tol, consistent, acceleration);
            actual = prescribed_run(@bds_dual_threshold, options, reference_norm, ...
                threshold*[0.5, 2, 0.5, 0.5], reference_samples);
            assert(actual.flag == 5 && actual.output.funcCount == options.MaxFunctionEvaluations);
            % The reference sample must not count toward a two-sample window.
            options = fixture_options(1 + 2*(reference_samples+1), 2, tol, consistent, acceleration);
            actual = prescribed_run(@bds_dual_threshold, options, reference_norm, threshold/2, reference_samples);
            assert(actual.flag ~= 5);
            behavior_cases = behavior_cases + 2;
        end
    end
end

equivalence_cases = 0;
for n = [1, 3, 7]
    x0 = (1:n)' / 3;
    for algorithm = {'cbds', 'pbds', 'rbds', 'pads', 'ds'}
        for acceleration = [false, true]
            for function_stop = [false, true]
                options = bds_paper_options(x0, 'external', 'mp');
                options.Algorithm = algorithm{1};
                options.use_iteration_pattern_step = acceleration;
                options.use_momentum_extrapolation = acceleration;
                options.use_function_value_stop = function_stop;
                options.use_estimated_gradient_stop = false;
                options.output_xhist = true;
                options.output_alpha_hist = true;
                options.output_block_hist = true;
                options.output_grad_hist = true;
                for kind = 1:3
                    first = recorded_run(@bds, x0, options, kind);
                    second = recorded_run(@bds_dual_threshold, x0, options, kind);
                    assert(isequaln(first, second));
                    if acceleration
                        reference_options = options;
                        reference_options.use_productive_direction_memory = false;
                        reference_options.productive_direction_memory_size = max(1, min(n, 5));
                        oracle = recorded_run(@c03_bds_mp, x0, reference_options, kind);
                    else
                        reference_options = rmfield(options, ...
                            {'use_iteration_pattern_step', 'use_momentum_extrapolation', 'momentum_decay'});
                        oracle = recorded_run(@bds_without_acceleration_reference, x0, reference_options, kind);
                    end
                    assert(isequaln(second, oracle));
                    equivalence_cases = equivalence_cases + 1;
                end
            end
        end
    end
end
save(fullfile(root, 'results', 'threshold_unit.mat'), ...
    'predicate_cases', 'behavior_cases', 'equivalence_cases');
fprintf('THRESHOLD_UNIT_OK predicate=%d behavior=%d equivalence=%d\n', ...
    predicate_cases, behavior_cases, equivalence_cases);
end

function options = fixture_options(maxfun, window, tol, consistent, acceleration)
options = struct('Algorithm', 'cbds', 'MaxFunctionEvaluations', maxfun, ...
    'StepTolerance', 0, 'alpha_init', 1, 'expand', 2, 'shrink', 0.5, 'seed', 0, ...
    'use_function_value_stop', false, 'use_estimated_gradient_stop', true, ...
    'grad_window_size', window, 'grad_tol', tol, 'lipschitz_constant', realmin, ...
    'use_gradient_reference_consistency', consistent, ...
    'use_iteration_pattern_step', acceleration, 'use_momentum_extrapolation', acceleration, ...
    'output_xhist', true, 'output_grad_hist', true);
end

function result = prescribed_run(solver, options, reference_norm, later, reference_samples)
calls = [];
[result.x, result.f, result.flag, result.output] = solver(@objective, 0, options);
assert(result.output.funcCount == numel(calls));
assert(isequaln(result.output.xhist, calls));
    function value = objective(x)
        calls(end+1) = x;
        if x == 0
            value = 0;
            return
        end
        iteration = 1 + round(-log2(abs(x)));
        gradient = reference_norm;
        if iteration > reference_samples
            gradient = later(min(iteration-reference_samples, numel(later)));
        end
        value = 10*max(1, reference_norm) + gradient*x;
    end
end

function result = recorded_run(solver, x0, options, kind)
rng(options.seed, 'twister');
calls = zeros(numel(x0), 0);
[result.x, result.f, result.flag, result.output] = solver(@objective, x0, options);
result.calls = calls;
assert(result.output.funcCount == size(calls, 2));
assert(size(calls, 2) <= options.MaxFunctionEvaluations);
    function value = objective(x)
        calls(:, end+1) = x(:);
        value = sum(((1:numel(x))'.*(x(:)-0.27)).^2);
        if kind == 2
            value = value * (1 + 0.01*randn());
        elseif kind == 3 && x(1) > 0.7
            value = nan;
        end
    end
end
