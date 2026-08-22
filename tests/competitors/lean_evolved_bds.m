function [xopt, fopt, exitflag, output] = lean_evolved_bds(fun, x0, termination_options)
%LEAN_EVOLVED_BDS MATLAB port of the Python Lean Evolved BDS competitor.
%
% This file follows tests/competitors/evolved_bds_solver_lean.py in bds_python
% and adds optional function-value and estimated-gradient stopping references
% for focused comparison with production bds. The solver keeps only:
%   - ordinary direction cycling within each coordinate block;
%   - explicit productive displacement memory;
%   - sweep-level pattern / momentum extrapolation.

if nargin < 3
    termination_options = struct();
end
if isfield(termination_options, 'grad_reference_relative_tol')
    error('lean_evolved_bds:RemovedGradientReferenceRelativeTolerance', ...
        ['termination_options.grad_reference_relative_tol has been removed; ', ...
        'use termination_options.grad_tol.']);
end

use_function_value_stop = false;
func_window_size = 20;
func_tol = 1e-6;
use_estimated_gradient_stop = false;
grad_window_size = 1;
grad_tol = 1e-2;
lipschitz_constant = 1e3;
use_gradient_reference_consistency = true;
grad_reference_finite_difference_error_tol = 1/30;
if isfield(termination_options, 'use_function_value_stop')
    use_function_value_stop = termination_options.use_function_value_stop;
end
if isfield(termination_options, 'func_window_size')
    func_window_size = termination_options.func_window_size;
end
if isfield(termination_options, 'func_tol')
    func_tol = termination_options.func_tol;
end
if isfield(termination_options, 'use_estimated_gradient_stop')
    use_estimated_gradient_stop = termination_options.use_estimated_gradient_stop;
end
if isfield(termination_options, 'grad_window_size')
    grad_window_size = termination_options.grad_window_size;
end
if isfield(termination_options, 'grad_tol')
    grad_tol = termination_options.grad_tol;
end
if isfield(termination_options, 'lipschitz_constant')
    lipschitz_constant = termination_options.lipschitz_constant;
end
if isfield(termination_options, 'use_gradient_reference_consistency')
    use_gradient_reference_consistency = ...
        termination_options.use_gradient_reference_consistency;
end
if isfield(termination_options, 'grad_reference_finite_difference_error_tol')
    grad_reference_finite_difference_error_tol = ...
        termination_options.grad_reference_finite_difference_error_tol;
end
fopt_window = inf(1, func_window_size);
reference_function_value = nan;

x0 = x0(:);
n = numel(x0);
maxfun = 500 * n;
maxit = maxfun;
alpha_tol = 1e-6;
alpha_all = ones(n, 1);
expand = 2.0;
shrink = 0.5;
eps_m = eps;
grad_reference_raw_tol = grad_reference_finite_difference_error_tol ...
    * (1 - shrink^2) / shrink^2;
norm_grad_window = nan(1, grad_window_size);
reference_grad_norm_initialized = false;
reference_candidate_reliable = ~use_gradient_reference_consistency;
previous_gradient = [];
previous_gradient_x = [];

D = zeros(n, 2 * n);
D(:, 1:2:end) = eye(n);
D(:, 2:2:end) = -eye(n);
grouped_direction_indices = cell(n, 1);
for k = 1:n
    grouped_direction_indices{k} = [2 * k - 1, 2 * k];
end

mem_size = max(1, min(n, 5));
prod_memory = struct('direction', {}, 'step', {});
momentum = zeros(n, 1);
momentum_decay = 0.6;

fopt_all = nan(n, 1);
xopt_all = nan(n, n);

f0 = fun(x0);
nf = 1;
xbase = x0;
fbase = f0;
xopt = x0;
fopt = f0;
if isfinite(fopt)
    reference_function_value = fopt;
end
fopt_window = [fopt_window(2:end), fopt];
exitflag = 0;
terminate = false;

for iter = 1:maxit
    xbase_sweep_start = xbase;
    fbase_sweep_start = fbase;
    sweep_improved = false;
    post_poll_acceleration_succeeded = false;
    if use_estimated_gradient_stop
        sampled_direction_indices_per_block = cell(n, 1);
        function_values_per_block = cell(n, 1);
        gradient_step_sizes = nan(n, 1);
        block_gradient_available = false(n, 1);
    end

    % Explicit productive displacement memory beyond cycling.
    if ~isempty(prod_memory) && nf < maxfun
        avg_alpha = mean(alpha_all);
        for m_idx = 1:numel(prod_memory)
            if nf >= maxfun
                break;
            end
            dir_vec = prod_memory(m_idx).direction;
            stored_step = prod_memory(m_idx).step;
            step = max(avg_alpha, stored_step);
            x_cand = xbase + step * dir_vec;
            f_cand = fun(x_cand);
            nf = nf + 1;
            if f_cand < fbase
                xbase = x_cand;
                fbase = f_cand;
                sweep_improved = true;
                [xbase, fbase, nf] = try_extrapolation(fun, xbase, fbase, dir_vec, step * 2.0, nf, maxfun);
                prod_memory(m_idx) = [];
                prod_memory = insert_memory_front(prod_memory, dir_vec, step);
                break;
            end
        end
    end

    % Baseline coordinate order.  Ordinary direction cycling is retained in
    % grouped_direction_indices exactly as in the Python solver.
    for i = 1:n
        if terminate || nf >= maxfun
            break;
        end
        direction_indices = grouped_direction_indices{i};
        if use_estimated_gradient_stop
            gradient_step_sizes(i) = alpha_all(i);
        end
        [sub_xopt, sub_fopt, ~, sub_output] = inner_direct_search( ...
            fun, xbase, fbase, D, direction_indices, alpha_all(i), max(0, maxfun - nf));
        nf = nf + sub_output.nf;
        if use_estimated_gradient_stop
            sampled_direction_indices_per_block{i} = direction_indices(1:sub_output.nf);
            function_values_per_block{i} = sub_output.function_values;
            block_gradient_available(i) = ...
                sub_output.nf == numel(direction_indices) ...
                && ~sub_output.sufficient_decrease;
        end
        fopt_all(i) = sub_fopt;
        xopt_all(:, i) = sub_xopt;
        grouped_direction_indices{i} = sub_output.direction_indices;

        xold = xbase;
        is_expand = sub_fopt + eps_m * (alpha_all(i) ^ 2) < fbase;
        if is_expand
            alpha_all(i) = alpha_all(i) * expand;
        else
            alpha_all(i) = alpha_all(i) * shrink;
        end

        if sub_output.terminate
            terminate = true;
            break;
        end
        if sub_fopt < fbase
            xbase = sub_xopt;
            fbase = sub_fopt;
            displacement_i = sub_xopt - xold;
            disp_norm_i = norm(displacement_i);
            if disp_norm_i > alpha_tol
                prod_memory = remember_direction(prod_memory, displacement_i, disp_norm_i, mem_size);
            end
        end
        if all(alpha_all < alpha_tol) || nf >= maxfun
            terminate = true;
            break;
        end
    end

    displacement = xbase - xbase_sweep_start;
    disp_norm = norm(displacement);
    if fbase < fbase_sweep_start
        sweep_improved = true;
    end

    % Sweep-level pattern / momentum extrapolation.
    if ~terminate && sweep_improved && disp_norm > alpha_tol && nf < maxfun
        pattern_dir = displacement / disp_norm;
        alpha_pat = max(disp_norm, alpha_tol);

        momentum = momentum_decay * momentum + (1.0 - momentum_decay) * pattern_dir;
        momentum_norm = norm(momentum);
        if momentum_norm > alpha_tol
            momentum_dir = momentum / momentum_norm;
        else
            momentum_dir = [];
        end

        factors = [1.0, 2.0, 4.0];
        x_pat = xbase;
        f_pat = fbase;
        best_dir = [];
        pat_improved = false;
        failed_pattern_point = [];

        for idx = 1:numel(factors)
            if nf >= maxfun
                break;
            end
            factor = factors(idx);
            x_candidate = xbase + factor * alpha_pat * pattern_dir;
            f_candidate = fun(x_candidate);
            nf = nf + 1;
            if f_candidate < f_pat
                x_pat = x_candidate;
                f_pat = f_candidate;
                best_dir = pattern_dir;
                pat_improved = true;
            else
                failed_pattern_point = x_candidate;
                break;
            end
        end

        if ~pat_improved && ~isempty(momentum_dir) && nf < maxfun
            for idx = 1:numel(factors)
                if nf >= maxfun
                    break;
                end
                factor = factors(idx);
                x_candidate = xbase + factor * alpha_pat * momentum_dir;
                if ~isempty(failed_pattern_point) && isequal(x_candidate, failed_pattern_point)
                    break;
                end
                f_candidate = fun(x_candidate);
                nf = nf + 1;
                if f_candidate < f_pat
                    x_pat = x_candidate;
                    f_pat = f_candidate;
                    best_dir = momentum_dir;
                else
                    break;
                end
            end
        end

        if f_pat < fbase
            post_poll_acceleration_succeeded = true;
            xbase = x_pat;
            fbase = f_pat;
            if ~isempty(best_dir)
                prod_memory = remember_direction(prod_memory, best_dir, alpha_pat, mem_size);
            end
        end
    end

    [fopt, xopt] = best_recorded_point(fopt_all, xopt_all, fopt, xopt);
    if fbase < fopt
        fopt = fbase;
        xopt = xbase;
    end

    if isnan(reference_function_value) && isfinite(fopt)
        reference_function_value = fopt;
    end
    fopt_window = [fopt_window(2:end), fopt];

    if use_function_value_stop && ~post_poll_acceleration_succeeded ...
            && isfinite(reference_function_value) && all(isfinite(fopt_window))
        func_change = max(fopt_window) - min(fopt_window);
        if func_change < (func_tol * min(1, abs(fopt - reference_function_value))) || ...
                func_change < (1e-3 * func_tol * max(1, abs(fopt - reference_function_value)))
            terminate = true;
            exitflag = 4;
        end
    end

    % The lean reference has the fixed CBDS structure: every block contains
    % the positive and negative coordinate directions. Reconstruct the same
    % central-difference estimate independently from the recorded poll values.
    if use_estimated_gradient_stop && ~post_poll_acceleration_succeeded ...
            && all(block_gradient_available)
        grad = nan(n, 1);
        for i = 1:n
            direction_indices = sampled_direction_indices_per_block{i};
            function_values = function_values_per_block{i};
            positive_position = find(direction_indices == 2 * i - 1, 1);
            negative_position = find(direction_indices == 2 * i, 1);
            if ~isempty(positive_position) && ~isempty(negative_position)
                grad(i) = (function_values(positive_position) ...
                    - function_values(negative_position)) ...
                    / (2 * gradient_step_sizes(i));
            end
        end

        if isreal(grad) && all(isfinite(grad))
            % For the canonical coordinate basis with all n blocks visited,
            % get_gradient_error_bound reduces to this expression.
            grad_error = lipschitz_constant / 6 ...
                * sqrt(sum(gradient_step_sizes.^4));

            if ~reference_grad_norm_initialized ...
                    && use_gradient_reference_consistency
                reference_candidate_reliable = ~isempty(previous_gradient) ...
                    && isequal(xbase, previous_gradient_x) ...
                    && (norm(grad - previous_gradient) ...
                        / max([1, norm(grad), norm(previous_gradient)]) ...
                        <= grad_reference_raw_tol);
            end
            if ~reference_grad_norm_initialized && reference_candidate_reliable ...
                    && grad_error < max(1e-3, 1e-1 * norm(grad))
                reference_grad_norm = norm(grad) + grad_error;
                reference_grad_norm_initialized = true;
            elseif reference_grad_norm_initialized
                norm_grad_window = [norm_grad_window(2:end), norm(grad) + grad_error];
            end

            if reference_grad_norm_initialized ...
                    && all(norm_grad_window ...
                        < grad_tol * max(1, reference_grad_norm))
                terminate = true;
                exitflag = 5;
            end

            if ~reference_grad_norm_initialized ...
                    && use_gradient_reference_consistency
                previous_gradient = grad;
                previous_gradient_x = xbase;
            end
        end
    end

    if ~terminate && (nf >= maxfun || all(alpha_all < alpha_tol))
        terminate = true;
    end
    if terminate
        break;
    end
end

if exitflag == 4 || exitflag == 5
    % Preserve a function-value or estimated-gradient stopping decision.
elseif nf >= maxfun
    exitflag = 1;
elseif all(alpha_all < alpha_tol)
    exitflag = 3;
end

output.funcCount = nf;
output.alpha_all = alpha_all;
output.fbase = fbase;
output.xbase = xbase;
output.iterations = iter;

end

function [xopt, fopt, exitflag, output] = inner_direct_search(fun, xbase, fbase, D, direction_indices, alpha, submaxfun)
exitflag = nan;
terminate = false;
nf = 0;
fopt = fbase;
xopt = xbase;
fnew = fopt;
function_values = nan(1, numel(direction_indices));
sufficient_decrease = false;

for j = 1:numel(direction_indices)
    if nf >= submaxfun
        terminate = true;
        break;
    end
    di = direction_indices(j);
    xnew = xbase + alpha * D(:, di);
    fnew = fun(xnew);
    nf = nf + 1;
    function_values(nf) = fnew;
    if fnew < fopt
        xopt = xnew;
        fopt = fnew;
    end
    if fnew <= -inf || nf >= submaxfun
        terminate = true;
        break;
    end
    sufficient_decrease = fnew < fbase;
    if sufficient_decrease
        direction_indices(1:j) = direction_indices([j, 1:j-1]);
        break;
    end
end

if fnew <= -inf
    exitflag = 0;
elseif nf >= submaxfun
    exitflag = 1;
end

output.nf = nf;
output.direction_indices = direction_indices;
output.terminate = terminate;
output.function_values = function_values(1:nf);
output.sufficient_decrease = sufficient_decrease;
end

function [xbest, fbest, nf] = try_extrapolation(fun, xbase, fbase, direction, step, nf, maxfun)
xbest = xbase;
fbest = fbase;
for k = 1:2
    if nf >= maxfun
        break;
    end
    xcand = xbest + step * direction;
    fcand = fun(xcand);
    nf = nf + 1;
    if fcand < fbest
        xbest = xcand;
        fbest = fcand;
        step = step * 2.0;
    else
        break;
    end
end
end

function prod_memory = remember_direction(prod_memory, direction, step, mem_size)
direction = direction(:);
norm_direction = norm(direction);
if norm_direction == 0
    return;
end
direction = direction / norm_direction;

is_dup = false;
for k = 1:numel(prod_memory)
    if abs(prod_memory(k).direction' * direction) > 0.95
        is_dup = true;
        break;
    end
end
if is_dup
    return;
end

if numel(prod_memory) >= mem_size
    prod_memory(end) = [];
end
prod_memory = insert_memory_front(prod_memory, direction, step);
end

function prod_memory = insert_memory_front(prod_memory, direction, step)
entry.direction = direction(:);
entry.step = double(step);
if isempty(prod_memory)
    prod_memory = entry;
else
    prod_memory = [entry, prod_memory];
end
end

function [fopt, xopt] = best_recorded_point(fopt_all, xopt_all, fopt, xopt)
valid = ~isnan(fopt_all);
if any(valid)
    valid_indices = find(valid);
    [best_value, rel_idx] = min(fopt_all(valid));
    idx = valid_indices(rel_idx);
    if best_value < fopt
        fopt = best_value;
        xopt = xopt_all(:, idx);
    end
end
end
