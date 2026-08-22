function [xopt, fopt, exitflag, output] = nbds_simplified(fun, x0, options)
%NBDS_SIMPLIFIED Minimal nonmonotone BDS prototype for experiments.
%
% This solver intentionally stays close to bds_simplified.m.  The only
% algorithmic change is the reference value in the acceptance test:
%
%     f(xbase + alpha*d) + c*alpha^2 < C,
%
% where C is the Zhang-Hager average reference value.  A step that also
% satisfies the ordinary BDS test relative to fbase is treated as a strong
% success and expands the block step.  A step accepted only by the
% nonmonotone reference is a weak success and keeps the block step unchanged
% by default.

if nargin < 3
    options = struct();
end

x0 = x0(:);
n = length(x0);
maxfun = get_option(options, "maxfun", 500 * n);
maxit = maxfun;
alpha_tol = get_option(options, "alpha_tol", 1e-6);
alpha_all = get_option(options, "alpha_init", ones(1, n));
if isscalar(alpha_all)
    alpha_all = alpha_all * ones(1, n);
end
expand = get_option(options, "expand", 2);
shrink = get_option(options, "shrink", 0.5);
weak_factor = get_option(options, "weak_factor", 1);
forcing_coeff = get_option(options, "forcing_coeff", eps);
eta = get_option(options, "eta", 0.85);
slack_coeff = get_option(options, "slack_coeff", Inf);
best_slack_coeff = get_option(options, "best_slack_coeff", Inf);
weak_min_failures = get_option(options, "weak_min_failures", 0);
weak_accept_resets_failures = get_option(options, "weak_accept_resets_failures", false);
weak_accept_resets_reference = get_option(options, "weak_accept_resets_reference", false);
max_weak_per_cycle = get_option(options, "max_weak_per_cycle", Inf);
max_weak_per_cycle_fraction = get_option(options, "max_weak_per_cycle_fraction", Inf);
weak_min_stalled_cycles = get_option(options, "weak_min_stalled_cycles", 0);
weak_min_failed_block_fraction = get_option(options, "weak_min_failed_block_fraction", 0);
weak_min_failed_blocks_in_cycle = get_option(options, "weak_min_failed_blocks_in_cycle", 0);
weak_credit_window = get_option(options, "weak_credit_window", Inf);
weak_credit_window_factor = get_option(options, "weak_credit_window_factor", Inf);
weak_credit_cooldown = get_option(options, "weak_credit_cooldown", 0);
weak_credit_cooldown_factor = get_option(options, "weak_credit_cooldown_factor", Inf);
weak_credit_gain_coeff = get_option(options, "weak_credit_gain_coeff", 0);
weak_credit_max_pending = get_option(options, "weak_credit_max_pending", Inf);
weak_credit_max_pending_fraction = get_option(options, "weak_credit_max_pending_fraction", Inf);
weak_burst_gain_coeff = get_option(options, "weak_burst_gain_coeff", 0);
weak_burst_cooldown_cycles = get_option(options, "weak_burst_cooldown_cycles", 0);

if max_weak_per_cycle_fraction < 0
    error("options.max_weak_per_cycle_fraction must be nonnegative.");
end
if isfinite(max_weak_per_cycle_fraction)
    max_weak_per_cycle = min(max_weak_per_cycle, ...
        max(0, ceil(max_weak_per_cycle_fraction * n)));
end

if weak_credit_window < 0 || weak_credit_window_factor < 0 ...
        || weak_credit_cooldown < 0 || weak_credit_cooldown_factor < 0 ...
        || weak_credit_gain_coeff < 0 || weak_credit_max_pending < 0 ...
        || weak_credit_max_pending_fraction < 0 ...
        || weak_burst_gain_coeff < 0 || weak_burst_cooldown_cycles < 0
    error("Weak-credit options must be nonnegative.");
end
if isfinite(weak_credit_window_factor)
    weak_credit_window = min(weak_credit_window, ...
        max(0, ceil(weak_credit_window_factor * n)));
end
if isfinite(weak_credit_cooldown_factor)
    weak_credit_cooldown = max(weak_credit_cooldown, ...
        max(0, ceil(weak_credit_cooldown_factor * n)));
end
if isfinite(weak_credit_max_pending_fraction)
    weak_credit_max_pending = min(weak_credit_max_pending, ...
        max(0, ceil(weak_credit_max_pending_fraction * n)));
end
weak_credit_active = isfinite(weak_credit_window) && weak_credit_window > 0 ...
    && weak_credit_cooldown > 0;
weak_burst_active = weak_burst_cooldown_cycles > 0;

if eta < 0 || eta >= 1
    error("options.eta must satisfy 0 <= eta < 1 for this prototype.");
end

D = zeros(n, 2 * n);
D(:, 1:2:2*n-1) = eye(n);
D(:, 2:2:2*n) = -eye(n);
grouped_direction_indices = arrayfun(@(i) [2*i-1, 2*i], 1:n, "UniformOutput", false);

fopt_all = nan(1, n);
xopt_all = nan(n, n);
exitflag = 0;
terminate = false;

f0 = fun(x0);
fscale = max(1, abs(f0));
fhist = f0;
xhist = x0;
nf = 1;
xbase = x0;
fbase = f0;
xopt = x0;
fopt = f0;

C = f0;
Q = 1;
C_hist = C;
Q_hist = Q;
fbase_hist = fbase;
fbest_hist = fopt;
alpha_min_hist = min(alpha_all);
alpha_max_hist = max(alpha_all);
block_failure_count = zeros(1, n);
trace = init_trace();

strong_success_count = 0;
weak_success_count = 0;
failure_count = 0;
cycle_failure_count = 0;
attempt_count = 0;
weak_credit_deadlines = [];
weak_credit_cooldown_remaining = 0;
weak_credit_paid_count = 0;
weak_credit_debt_count = 0;
weak_credit_blocked_count = 0;
weak_burst_paid_count = 0;
weak_burst_debt_count = 0;
weak_burst_blocked_count = 0;
weak_burst_cooldown_remaining = 0;

for iter = 1:maxit
    cycle_strong_success = false;
    cycle_weak_count = 0;
    cycle_failed_block_count = 0;
    cycle_fbest_start = fopt;
    failed_block_gate = max(weak_min_failed_blocks_in_cycle, ...
        ceil(weak_min_failed_block_fraction * n));
    for i = 1:n
        attempt_count = attempt_count + 1;
        if weak_credit_active
            expired = weak_credit_deadlines < attempt_count;
            if any(expired)
                weak_credit_debt_count = weak_credit_debt_count + sum(expired);
                weak_credit_deadlines(expired) = [];
                weak_credit_cooldown_remaining = max( ...
                    weak_credit_cooldown_remaining, weak_credit_cooldown);
            end
        end

        direction_indices = grouped_direction_indices{i};
        base_allow_weak = block_failure_count(i) >= weak_min_failures ...
            && cycle_failure_count >= weak_min_stalled_cycles ...
            && cycle_failed_block_count >= failed_block_gate ...
            && cycle_weak_count < max_weak_per_cycle;
        credit_allows_weak = ~weak_credit_active ...
            || (weak_credit_cooldown_remaining <= 0 ...
                && numel(weak_credit_deadlines) < weak_credit_max_pending);
        burst_allows_weak = ~weak_burst_active ...
            || weak_burst_cooldown_remaining <= 0;
        if base_allow_weak && ~credit_allows_weak
            weak_credit_blocked_count = weak_credit_blocked_count + 1;
        end
        if base_allow_weak && credit_allows_weak && ~burst_allows_weak
            weak_burst_blocked_count = weak_burst_blocked_count + 1;
        end
        allow_weak = base_allow_weak && credit_allows_weak && burst_allows_weak;
        alpha_before = alpha_all(i);
        fbase_before = fbase;
        fbest_before = fopt;
        C_before = C;
        block_failure_before = block_failure_count(i);
        [sub_x, sub_f, sub_exitflag, sub_output] = inner_nonmonotone_search( ...
            fun, xbase, fbase, fopt, C, D(:, direction_indices), direction_indices, ...
            alpha_all(i), maxfun - nf, forcing_coeff, slack_coeff, ...
            best_slack_coeff, allow_weak);

        nf = nf + sub_output.nf;
        fhist = [fhist, sub_output.fhist];
        xhist = [xhist, sub_output.xhist];
        grouped_direction_indices{i} = sub_output.direction_indices;

        if sub_output.accepted
            xbase = sub_x;
            fbase = sub_f;
            reset_reference = false;
            if sub_output.strong_success
                alpha_all(i) = expand * alpha_all(i);
                strong_success_count = strong_success_count + 1;
                cycle_strong_success = true;
                block_failure_count(i) = 0;
            else
                alpha_all(i) = weak_factor * alpha_all(i);
                weak_success_count = weak_success_count + 1;
                cycle_weak_count = cycle_weak_count + 1;
                if weak_accept_resets_failures
                    block_failure_count(i) = 0;
                end
                reset_reference = weak_accept_resets_reference;
            end
        else
            alpha_all(i) = shrink * alpha_all(i);
            failure_count = failure_count + 1;
            cycle_failed_block_count = cycle_failed_block_count + 1;
            block_failure_count(i) = block_failure_count(i) + 1;
            reset_reference = false;
        end

        if sub_f < fopt_all(i) || isnan(fopt_all(i))
            fopt_all(i) = sub_f;
            xopt_all(:, i) = sub_x;
        end
        if fbase < fopt
            fopt = fbase;
            xopt = xbase;
        end
        [~, index] = min(fopt_all, [], "omitnan");
        if ~isempty(index) && fopt_all(index) < fopt
            fopt = fopt_all(index);
            xopt = xopt_all(:, index);
        end
        best_improved = fopt < fbest_before;

        if weak_credit_active
            best_gain = max(0, fbest_before - fopt);
            paid_now = best_gain > 0 ...
                && best_gain >= weak_credit_gain_coeff * fscale;
            if paid_now
                weak_credit_paid_count = weak_credit_paid_count ...
                    + numel(weak_credit_deadlines);
                weak_credit_deadlines = [];
                weak_credit_cooldown_remaining = 0;
            end
            if sub_output.accepted && ~sub_output.strong_success
                if paid_now
                    weak_credit_paid_count = weak_credit_paid_count + 1;
                else
                    weak_credit_deadlines(end+1) = attempt_count + weak_credit_window;
                end
            end
        end

        trace = append_trace(trace, iter, i, nf, sub_output, allow_weak, ...
            alpha_before, alpha_all(i), fbase_before, fbase, fbest_before, ...
            fopt, C_before, block_failure_before, block_failure_count(i), ...
            cycle_failure_count, cycle_failed_block_count, best_improved);

        if reset_reference
            C = fbase;
            Q = 1;
        else
            [C, Q] = update_reference(C, Q, fbase, eta);
        end
        C_hist(end+1) = C;
        Q_hist(end+1) = Q;
        fbase_hist(end+1) = fbase;
        fbest_hist(end+1) = fopt;
        alpha_min_hist(end+1) = min(alpha_all);
        alpha_max_hist(end+1) = max(alpha_all);

        if sub_output.terminate
            terminate = true;
            exitflag = sub_exitflag;
            break;
        end
        if all(alpha_all < alpha_tol)
            terminate = true;
            exitflag = 3;
            break;
        end
        if nf >= maxfun
            terminate = true;
            exitflag = 1;
            break;
        end
        if weak_credit_active && weak_credit_cooldown_remaining > 0
            weak_credit_cooldown_remaining = weak_credit_cooldown_remaining - 1;
        end
    end
    if cycle_strong_success
        cycle_failure_count = 0;
    else
        cycle_failure_count = cycle_failure_count + 1;
    end
    if weak_burst_active
        if cycle_weak_count > 0
            cycle_gain = max(0, cycle_fbest_start - fopt);
            if cycle_gain >= weak_burst_gain_coeff * fscale
                weak_burst_paid_count = weak_burst_paid_count + 1;
                weak_burst_cooldown_remaining = 0;
            else
                weak_burst_debt_count = weak_burst_debt_count + 1;
                weak_burst_cooldown_remaining = max( ...
                    weak_burst_cooldown_remaining, weak_burst_cooldown_cycles);
            end
        elseif weak_burst_cooldown_remaining > 0
            weak_burst_cooldown_remaining = weak_burst_cooldown_remaining - 1;
        end
    end
    if terminate
        break;
    end
end

output.funcCount = nf;
output.fhist = fhist;
output.xhist = xhist;
output.C_hist = C_hist;
output.Q_hist = Q_hist;
output.fbase_hist = fbase_hist;
output.fbest_hist = fbest_hist;
output.alpha_min_hist = alpha_min_hist;
output.alpha_max_hist = alpha_max_hist;
output.trace = trace;
output.strong_success_count = strong_success_count;
output.weak_success_count = weak_success_count;
output.failure_count = failure_count;
output.eta = eta;
output.weak_factor = weak_factor;
output.forcing_coeff = forcing_coeff;
output.slack_coeff = slack_coeff;
output.best_slack_coeff = best_slack_coeff;
output.weak_min_failures = weak_min_failures;
output.weak_accept_resets_failures = weak_accept_resets_failures;
output.weak_accept_resets_reference = weak_accept_resets_reference;
output.max_weak_per_cycle = max_weak_per_cycle;
output.max_weak_per_cycle_fraction = max_weak_per_cycle_fraction;
output.weak_min_stalled_cycles = weak_min_stalled_cycles;
output.weak_min_failed_block_fraction = weak_min_failed_block_fraction;
output.weak_min_failed_blocks_in_cycle = weak_min_failed_blocks_in_cycle;
output.weak_credit_active = weak_credit_active;
output.weak_credit_window = weak_credit_window;
output.weak_credit_cooldown = weak_credit_cooldown;
output.weak_credit_gain_coeff = weak_credit_gain_coeff;
output.weak_credit_max_pending = weak_credit_max_pending;
output.weak_credit_paid_count = weak_credit_paid_count;
output.weak_credit_debt_count = weak_credit_debt_count;
output.weak_credit_blocked_count = weak_credit_blocked_count;
output.weak_credit_pending_count = numel(weak_credit_deadlines);
output.weak_credit_cooldown_remaining = weak_credit_cooldown_remaining;
output.weak_burst_active = weak_burst_active;
output.weak_burst_gain_coeff = weak_burst_gain_coeff;
output.weak_burst_cooldown_cycles = weak_burst_cooldown_cycles;
output.weak_burst_paid_count = weak_burst_paid_count;
output.weak_burst_debt_count = weak_burst_debt_count;
output.weak_burst_blocked_count = weak_burst_blocked_count;
output.weak_burst_cooldown_remaining = weak_burst_cooldown_remaining;
output.block_failure_count = block_failure_count;
output.cycle_failure_count = cycle_failure_count;
output.iterations = iter;

end

function trace = init_trace()
trace.iter = [];
trace.block = [];
trace.nf = [];
trace.accepted = [];
trace.strong = [];
trace.weak = [];
trace.allow_weak = [];
trace.best_improved = [];
trace.trial_count = [];
trace.alpha_before = [];
trace.alpha_after = [];
trace.fbase_before = [];
trace.fbase_after = [];
trace.fbest_before = [];
trace.fbest_after = [];
trace.C_before = [];
trace.C_gap_before = [];
trace.base_gap_before = [];
trace.accept_gap_before = [];
trace.block_failure_before = [];
trace.block_failure_after = [];
trace.cycle_failure_count = [];
trace.cycle_failed_block_count = [];
trace.accepted_trial_index = [];
trace.accepted_trial_f = [];
end

function trace = append_trace(trace, iter, block, nf, sub_output, allow_weak, ...
    alpha_before, alpha_after, fbase_before, fbase_after, fbest_before, ...
    fbest_after, C_before, block_failure_before, block_failure_after, ...
    cycle_failure_count, cycle_failed_block_count, best_improved)

is_accepted = sub_output.accepted;
is_strong = sub_output.strong_success;
is_weak = is_accepted && ~is_strong;
if is_accepted
    accepted_trial_index = sub_output.accepted_trial_index;
    accepted_trial_f = sub_output.accepted_trial_f;
else
    accepted_trial_index = NaN;
    accepted_trial_f = NaN;
end

trace.iter(end+1) = iter;
trace.block(end+1) = block;
trace.nf(end+1) = nf;
trace.accepted(end+1) = is_accepted;
trace.strong(end+1) = is_strong;
trace.weak(end+1) = is_weak;
trace.allow_weak(end+1) = allow_weak;
trace.best_improved(end+1) = best_improved;
trace.trial_count(end+1) = sub_output.nf;
trace.alpha_before(end+1) = alpha_before;
trace.alpha_after(end+1) = alpha_after;
trace.fbase_before(end+1) = fbase_before;
trace.fbase_after(end+1) = fbase_after;
trace.fbest_before(end+1) = fbest_before;
trace.fbest_after(end+1) = fbest_after;
trace.C_before(end+1) = C_before;
trace.C_gap_before(end+1) = C_before - fbest_before;
trace.base_gap_before(end+1) = fbase_before - fbest_before;
trace.accept_gap_before(end+1) = fbase_after - fbest_before;
trace.block_failure_before(end+1) = block_failure_before;
trace.block_failure_after(end+1) = block_failure_after;
trace.cycle_failure_count(end+1) = cycle_failure_count;
trace.cycle_failed_block_count(end+1) = cycle_failed_block_count;
trace.accepted_trial_index(end+1) = accepted_trial_index;
trace.accepted_trial_f(end+1) = accepted_trial_f;
end

function [xaccepted, faccepted, exitflag, output] = inner_nonmonotone_search( ...
    fun, xbase, fbase, fbest, C, D, direction_indices, alpha, submaxfun, ...
    forcing_coeff, slack_coeff, best_slack_coeff, allow_weak)

exitflag = nan;
terminate = false;
nf = 0;
fhist = [];
xhist = [];
xaccepted = xbase;
faccepted = fbase;
accepted = false;
strong_success = false;
fnew = fbase;
accepted_trial_index = NaN;
accepted_trial_f = NaN;

for j = 1:length(direction_indices)
    if nf >= submaxfun
        terminate = true;
        break;
    end

    xnew = xbase + alpha * D(:, j);
    fnew = fun(xnew);
    nf = nf + 1;
    fhist = [fhist, fnew];
    xhist = [xhist, xnew];

    strong_success = (fnew + forcing_coeff * alpha^2 < fbase);
    if allow_weak
        reference_value = min(C, fbase + slack_coeff * alpha^2);
        best_slack = best_slack_coeff * max(1, abs(fbest)) * alpha^2;
        reference_value = min(reference_value, fbest + best_slack);
    else
        reference_value = fbase;
    end
    accepted = (fnew + forcing_coeff * alpha^2 < reference_value);
    if accepted
        xaccepted = xnew;
        faccepted = fnew;
        accepted_trial_index = j;
        accepted_trial_f = fnew;
        direction_indices(1:j) = direction_indices([j, 1:j-1]);
        break;
    end
end

if nf >= submaxfun
    terminate = true;
    exitflag = 1;
end

output.nf = nf;
output.direction_indices = direction_indices;
output.terminate = terminate;
output.fhist = fhist;
output.xhist = xhist;
output.accepted = accepted;
output.strong_success = accepted && strong_success;
output.accepted_trial_index = accepted_trial_index;
output.accepted_trial_f = accepted_trial_f;
end

function [Cnew, Qnew] = update_reference(C, Q, fnew, eta)
Qnew = eta * Q + 1;
Cnew = (eta * Q * C + fnew) / Qnew;
end

function value = get_option(options, name, default_value)
if isfield(options, name)
    value = options.(name);
else
    value = default_value;
end
end
