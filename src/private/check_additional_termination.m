function [state, exitflag, grad] = check_additional_termination( ...
    state, x, f, values, steps, basis, options, check_function, check_gradient)
%CHECK_ADDITIONAL_TERMINATION Apply the two optional complete-visit criteria.
%   The caller checks timing, absence of accepted acceleration and eligibility
%   of each criterion. This function never evaluates the objective. Function
%   history has already been recorded, including ineligible complete visits.

% LIPSCHITZ_CONSTANT describes a problem assumption, not just an algorithmic
% tuning scale. For exact function values and a Hessian Lipschitz constant no
% larger than the supplied value, the central-difference expression bounds the
% gradient error. A prescribed value that has not been verified for the problem
% gives a heuristic estimate; it does not certify an actual error bound.
%
% USE_GRADIENT_REFERENCE_CONSISTENCY and the tolerance below select the fixed
% reference only. Once it is selected, later available estimates enter the
% window without repeating the reference-selection checks.
%
% The following leading-error expansion is a calibration for sufficiently
% smooth functions. Its O(h^4) remainder requires stronger smoothness than
% Hessian Lipschitz continuity alone; it is not implied by that assumption.
%
% Let theta = options.shrink. For a fixed polling direction, denote by D_h and
% D_{theta*h} the central-difference estimates obtained with step sizes h and
% theta*h. Their leading truncation errors satisfy
%
%   D_h         = D + c*h^2         + O(h^4),
%   D_{theta*h} = D + c*theta^2*h^2 + O(h^4).
%
% Hence, D_h - D_{theta*h} has leading term c*(1-theta^2)*h^2, whereas the
% leading error of the finer estimate D_{theta*h} is c*theta^2*h^2. The error
% of the finer estimate is therefore approximated by
%
%   theta^2/(1-theta^2) * abs(D_h - D_{theta*h}).
%
% Consequently, if grad_reference_finite_difference_error_tol bounds the
% relative error of the finer estimate, the corresponding raw threshold for
% the relative difference between the two estimates is
%
%   grad_reference_finite_difference_error_tol * (1-theta^2)/theta^2.
%
% This is a leading-order calibration for reconstructed gradients, not an
% exact error identity. With theta=0.5 and the default tolerance 1/30, the
% resulting grad_reference_raw_tol is 0.1.
% The calibration assumes that corresponding paired steps shrink by the same
% factor. Repeated visits and unavailable estimates can produce other ratios.
% In such cases it remains a heuristic consistency check, not an exact estimate
% of the error of either reconstructed gradient.

exitflag = [];
grad = [];
if check_function
    change = state.function_window(1) - state.function_window(end);
    scale = abs(f - state.function_reference);
    if change < options.func_tol * min(1, scale) ...
        || change < 1e-3 * options.func_tol * max(1, scale)
        exitflag = get_exitflag('SMALL_OBJECTIVE_CHANGE');
    end
end

if check_gradient
    % Samples share a base point and each positive/negative pair shares its
    % recorded step. For nonorthogonal bases, solve the transposed system.
    directional_derivatives = (values(1:2:end) - values(2:2:end)) ./ (2 * steps);
    grad = basis' \ directional_derivatives;
    if ~all(isfinite(grad))
        grad = [];
        return;
    end
    if options.use_estimated_gradient_stop
        error_estimate = options.lipschitz_constant / (6 * min(svd(basis))) ...
            * sqrt(sum(steps .^ 4 .* vecnorm(basis)' .^ 6));
        estimate = norm(grad) + error_estimate;
        if isnan(state.gradient_reference)
            consistent = ~options.use_gradient_reference_consistency ...
                || (~isempty(state.previous_gradient) && isequal(x, state.previous_point) ...
                && norm(grad - state.previous_gradient) ...
                / max([1, norm(grad), norm(state.previous_gradient)]) ...
                <= options.grad_reference_raw_tol);
            if consistent && error_estimate < max(1e-3, 1e-1 * norm(grad))
                state.gradient_reference = estimate;
            else
                state.previous_gradient = grad;
                state.previous_point = x;
            end
        else
            % The reference is fixed; only subsequent available estimates enter
            % the window. Missing estimates do not shift or fill this window.
            state.gradient_window = [state.gradient_window(2:end), estimate];
            if all(isfinite(state.gradient_window))
                scale = state.gradient_reference;
                if max(state.gradient_window) < options.grad_tol * min(1, scale) ...
                    || max(state.gradient_window) < 1e-3 * options.grad_tol * max(1, scale)
                    exitflag = get_exitflag('SMALL_ESTIMATE_GRADIENT');
                end
            end
        end
    end
end
end
