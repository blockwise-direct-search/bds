function result = lam_paper_exact_linesearch(fun, y, fy, coordinate, direction_sign, ...
    alpha_bar, max_evaluations, gamma, delta, ftarget)
%LAM_PAPER_EXACT_LINESEARCH Paper-exact DF-Linesearch of Brilli et al. (2024).
%   Provenance: byte-level rename port of
%   tests/competitors/private/lam_linesearch.m from the accepted C02 clone
%   (commit 846d5c5f3905a1f906356a34a979c965db20e36a, original file SHA-256
%   cb24e20d68edcb73fa028986dade2640a491625f06c0fe7dd5c39236cac95f02).
%   Only the function name was renamed (lam_linesearch ->
%   lam_paper_exact_linesearch); the algorithm is otherwise byte-equivalent
%   to the C02 original.

    n = numel(y);
    result = struct( ...
        'x', y, ...
        'f', fy, ...
        'alpha', 0, ...
        'direction_sign', direction_sign, ...
        'success', false, ...
        'target_reached', false, ...
        'budget_exhausted', false, ...
        'completed', false, ...
        'nf', 0, ...
        'fhist', NaN(1, max_evaluations), ...
        'xhist', NaN(n, max_evaluations));

    if max_evaluations < 1
        result.budget_exhausted = true;
        result.fhist = result.fhist(1:0);
        result.xhist = result.xhist(:, 1:0);
        return;
    end

    alpha = alpha_bar;
    accepted_sign = direction_sign;
    [xtrial, ftrial, result] = evaluate_trial( ...
        fun, y, coordinate, accepted_sign, alpha, result);
    if target_is_reached(ftrial, ftarget)
        result = accept_target(result, xtrial, ftrial, alpha, accepted_sign);
        result = trim_history(result);
        return;
    end

    initial_threshold = fy - gamma * alpha^2;
    if isfinite(ftrial) && ftrial <= initial_threshold
        accepted = true;
    else
        accepted = false;
        if result.nf >= max_evaluations
            result.budget_exhausted = true;
            result = trim_history(result);
            return;
        end

        opposite_sign = -direction_sign;
        [xtrial, ftrial, result] = evaluate_trial( ...
            fun, y, coordinate, opposite_sign, alpha, result);
        if target_is_reached(ftrial, ftarget)
            result = accept_target(result, xtrial, ftrial, alpha, opposite_sign);
            result = trim_history(result);
            return;
        end
        if isfinite(ftrial) && ftrial <= initial_threshold
            accepted = true;
            accepted_sign = opposite_sign;
        end
    end

    if ~accepted
        result.completed = true;
        result = trim_history(result);
        return;
    end

    result.x = xtrial;
    result.f = ftrial;
    result.alpha = alpha;
    result.direction_sign = accepted_sign;
    result.success = true;

    while true
        if result.nf >= max_evaluations
            result.budget_exhausted = true;
            result = trim_history(result);
            return;
        end

        expanded_alpha = alpha / delta;
        [xtrial, ftrial, result] = evaluate_trial( ...
            fun, y, coordinate, accepted_sign, expanded_alpha, result);
        if target_is_reached(ftrial, ftarget)
            result = accept_target(result, xtrial, ftrial, ...
                expanded_alpha, accepted_sign);
            result = trim_history(result);
            return;
        end

        expansion_displacement = (1 / delta - 1) * alpha;
        expansion_threshold = result.f - gamma * expansion_displacement^2;
        if isfinite(ftrial) && ftrial <= expansion_threshold
            alpha = expanded_alpha;
            result.x = xtrial;
            result.f = ftrial;
            result.alpha = alpha;
        else
            result.completed = true;
            result = trim_history(result);
            return;
        end
    end

end

function [xtrial, ftrial, result] = evaluate_trial( ...
    fun, y, coordinate, direction_sign, alpha, result)

    xtrial = y;
    xtrial(coordinate) = xtrial(coordinate) + alpha * direction_sign;
    ftrial = fun(xtrial);
    result.nf = result.nf + 1;
    result.fhist(result.nf) = ftrial;
    result.xhist(:, result.nf) = xtrial;

end

function reached = target_is_reached(ftrial, ftarget)

    reached = isfinite(ftrial) && ftrial <= ftarget;

end

function result = accept_target( ...
    result, xtrial, ftrial, alpha, direction_sign)

    result.x = xtrial;
    result.f = ftrial;
    result.alpha = alpha;
    result.direction_sign = direction_sign;
    result.success = true;
    result.target_reached = true;

end

function result = trim_history(result)

    result.fhist = result.fhist(1:result.nf);
    result.xhist = result.xhist(:, 1:result.nf);

end
