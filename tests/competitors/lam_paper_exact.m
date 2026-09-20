function [xval, fval, exitflag, output] = lam_paper_exact(fun, x0, options)
%LAM_PAPER_EXACT Paper-exact Linesearch Algorithm Model of Brilli et al. (2024).
%   Provenance: byte-level rename port of tests/competitors/lam.m from the
%   accepted C02 clone (commit 846d5c5f3905a1f906356a34a979c965db20e36a,
%   original file SHA-256
%   15203df0388734c434b6ab081d963e9a70fc6e37bbf68ff61cd6338e3919ba7b).
%   Only the function name, internal call names, and error identifiers were
%   renamed (lam -> lam_paper_exact); the algorithm is otherwise
%   byte-equivalent to the C02 original. The port is renamed so that the
%   current monotone-baseline tests/competitors/lam.m stays untouched.

    if nargin < 3
        options = struct();
    end

    if ischar(fun) || (isstring(fun) && isscalar(fun))
        fun = str2func(char(fun));
    end
    if ~isa(fun, 'function_handle')
        error('lam_paper_exact:InvalidObjective', 'The objective must be a function handle.');
    end

    x0 = double(x0(:));
    n = numel(x0);
    if n < 1 || any(~isfinite(x0))
        error('lam_paper_exact:InvalidInitialPoint', ...
            'The initial point must be a nonempty finite real vector.');
    end

    maxfun = get_option(options, 'MaxFunctionEvaluations', 500 * n);
    step_tolerance = get_option(options, 'StepTolerance', 1e-5);
    max_iterations = get_option(options, 'MaxIterations', Inf);
    ftarget = get_option(options, 'ftarget', -Inf);

    validateattributes(maxfun, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'integer', 'positive'}, mfilename, ...
        'MaxFunctionEvaluations');
    validateattributes(step_tolerance, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'nonnegative'}, mfilename, ...
        'StepTolerance');
    validateattributes(max_iterations, {'numeric'}, ...
        {'scalar', 'real', 'positive'}, mfilename, 'MaxIterations');
    validateattributes(ftarget, {'numeric'}, {'scalar', 'real'}, mfilename, ...
        'ftarget');

    % Parameters used in the numerical experiments of Brilli et al. (2024).
    coupling = 1e-10;
    shrink = 0.5;
    expansion_inverse = 0.5;
    sufficient_decrease = 1e-6;

    alpha_tilde = ones(n, 1);
    direction_signs = ones(n, 1);

    fhist = NaN(1, maxfun);
    xhist = NaN(n, maxfun);
    nf = 1;
    xval = x0;
    fval = fun(xval);
    fhist(nf) = fval;
    xhist(:, nf) = xval;

    best_x = xval;
    best_f = fval;
    iterations = 0;
    last_alpha_bar = alpha_tilde;
    next_alpha_bar = alpha_tilde;

    EXIT_TARGET = 1;
    EXIT_SMALL_STEP = 0;
    EXIT_MAXFUN = -1;
    EXIT_MAXITER = -2;
    EXIT_NONFINITE_INITIAL = -3;

    if ~isfinite(fval)
        exitflag = EXIT_NONFINITE_INITIAL;
    elseif fval <= ftarget
        exitflag = EXIT_TARGET;
    else
        exitflag = NaN;
    end

    while isnan(exitflag)
        if nf >= maxfun
            exitflag = EXIT_MAXFUN;
            break;
        end
        if iterations >= max_iterations
            exitflag = EXIT_MAXITER;
            break;
        end

        xk = xval;
        y = xval;
        fy = fval;
        alpha_max = max(alpha_tilde);
        alpha_bar = max(alpha_tilde, coupling * alpha_max);
        alpha_used = zeros(n, 1);
        last_alpha_bar = alpha_bar;
        pass_complete = true;

        for i = 1:n
            remaining = maxfun - nf;
            result = lam_paper_exact_linesearch(fun, y, fy, i, direction_signs(i), ...
                alpha_bar(i), remaining, sufficient_decrease, ...
                expansion_inverse, ftarget);

            if result.nf > 0
                indices = (nf + 1):(nf + result.nf);
                fhist(indices) = result.fhist;
                xhist(:, indices) = result.xhist;
                [best_x, best_f] = update_best(best_x, best_f, ...
                    result.xhist, result.fhist);
                nf = nf + result.nf;
            end

            direction_signs(i) = result.direction_sign;
            alpha_used(i) = result.alpha;
            if result.success
                y = result.x;
                fy = result.f;
            end

            if result.target_reached
                xval = result.x;
                fval = result.f;
                exitflag = EXIT_TARGET;
                pass_complete = false;
                break;
            end

            if result.budget_exhausted
                xval = y;
                fval = fy;
                exitflag = EXIT_MAXFUN;
                pass_complete = false;
                break;
            end
        end

        if ~pass_complete
            break;
        end

        xval = y;
        fval = fy;
        iterations = iterations + 1;

        if isequal(xval, xk)
            alpha_tilde = shrink * alpha_bar;
        else
            alpha_tilde = max(alpha_bar, alpha_used);
        end
        next_alpha_bar = max(alpha_tilde, coupling * max(alpha_tilde));

        if max(alpha_tilde) <= step_tolerance
            exitflag = EXIT_SMALL_STEP;
        elseif nf >= maxfun
            exitflag = EXIT_MAXFUN;
        elseif iterations >= max_iterations
            exitflag = EXIT_MAXITER;
        end
    end

    output.funcCount = nf;
    output.iterations = iterations;
    output.fhist = fhist(1:nf);
    output.xhist = xhist(:, 1:nf);
    output.alphaTilde = alpha_tilde;
    output.directionSigns = direction_signs;
    output.lastAlphaBar = last_alpha_bar;
    output.nextAlphaBar = next_alpha_bar;
    output.finalIterate = xval;
    output.finalValue = fval;
    output.bestEvaluatedPoint = best_x;
    output.bestEvaluatedValue = best_f;
    output.paperParameters = struct( ...
        'coupling', coupling, ...
        'theta', shrink, ...
        'delta', expansion_inverse, ...
        'gamma', sufficient_decrease, ...
        'initialTentativeStep', 1);
    output.message = lam_paper_exact_exit_message(exitflag);

end

function value = get_option(options, name, default_value)

    if isfield(options, name)
        value = options.(name);
    else
        value = default_value;
    end

end

function [best_x, best_f] = update_best(best_x, best_f, xhist, fhist)

    finite_indices = find(isfinite(fhist));
    if isempty(finite_indices)
        return;
    end
    [candidate_f, local_index] = min(fhist(finite_indices));
    if ~isfinite(best_f) || candidate_f < best_f
        best_f = candidate_f;
        best_x = xhist(:, finite_indices(local_index));
    end

end

function message = lam_paper_exact_exit_message(exitflag)

    if exitflag == 1
        message = 'The target objective value was reached.';
    elseif exitflag == 0
        message = 'The maximum tentative step satisfies StepTolerance.';
    elseif exitflag == -1
        message = 'The function evaluation budget was exhausted.';
    elseif exitflag == -2
        message = 'The outer iteration limit was reached.';
    elseif exitflag == -3
        message = 'The initial objective value is not finite.';
    else
        message = 'LAM terminated with an unknown exit flag.';
    end

end
