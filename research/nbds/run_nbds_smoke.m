function results = run_nbds_smoke()
%RUN_NBDS_SMOKE Small feasibility check for nonmonotone BDS.
%
% The script compares simplified BDS with several NBDS eta values on
% hand-picked smooth problems.  It is intentionally lightweight: the goal is
% to detect whether the nonmonotone reference has numerical signal before
% investing in a full OptiProfiler/S2MPJ run.

old_dir = pwd();
repo_dir = fileparts(fileparts(mfilename("fullpath")));
cleanup = onCleanup(@() cd(old_dir));
cd(repo_dir);
addpath(fullfile(repo_dir, "src"));
addpath(fullfile(repo_dir, "tests"));
addpath(fullfile(repo_dir, "tests", "competitors"));

problems = make_smoke_problems();
solver_specs = make_solver_specs();
num_problems = numel(problems);
num_solvers = numel(solver_specs);

results = struct();
records = repmat(empty_record(), num_problems, num_solvers);

fprintf("NBDS smoke test: %d problems, %d solvers\n\n", num_problems, num_solvers);
fprintf("%-22s %-14s %10s %14s %14s %10s %9s %9s\n", ...
    "problem", "solver", "nf", "fbest", "gap", "ratio", "strong", "weak");
fprintf("%s\n", repmat('-', 1, 105));

for pidx = 1:num_problems
    p = problems(pidx);
    f0 = p.fun(p.x0);
    ftarget = p.ftarget;
    base_cost = NaN;

    for sidx = 1:num_solvers
        spec = solver_specs(sidx);
        fun = p.fun;
        [~, ~, exitflag, output] = spec.solve(fun, p.x0, p.maxfun);
        fhist_best = cummin(output.fhist(:));
        fbest = fhist_best(end);
        target_index = find(fhist_best <= ftarget, 1, "first");
        if isempty(target_index)
            cost = Inf;
        else
            cost = target_index;
        end
        if sidx == 1
            base_cost = cost;
        end
        if isinf(cost) && isinf(base_cost)
            ratio = 1;
        elseif isinf(cost)
            ratio = Inf;
        elseif isinf(base_cost)
            ratio = 0;
        else
            ratio = cost / max(1, base_cost);
        end

        records(pidx, sidx).problem = p.name;
        records(pidx, sidx).solver = spec.name;
        records(pidx, sidx).nf = output.funcCount;
        records(pidx, sidx).cost = cost;
        records(pidx, sidx).fbest = fbest;
        records(pidx, sidx).gap = max(fbest - p.fmin, 0);
        records(pidx, sidx).exitflag = exitflag;
        records(pidx, sidx).ratio_to_bds = ratio;
        records(pidx, sidx).f0 = f0;
        records(pidx, sidx).ftarget = ftarget;
        records(pidx, sidx).strong = getfield_default(output, "strong_success_count", NaN);
        records(pidx, sidx).weak = getfield_default(output, "weak_success_count", NaN);
        records(pidx, sidx).failures = getfield_default(output, "failure_count", NaN);

        fprintf("%-22s %-14s %10.0f %14.6e %14.6e %10s %9s %9s\n", ...
            p.name, spec.name, output.funcCount, fbest, records(pidx, sidx).gap, ...
            format_number(ratio), format_number(records(pidx, sidx).strong), ...
            format_number(records(pidx, sidx).weak));
    end
    fprintf("%s\n", repmat('-', 1, 105));
end

summary = summarize_records(records, solver_specs);
results.records = records;
results.summary = summary;

fprintf("\nSummary relative to BDS target-hit cost\n");
fprintf("%-14s %8s %8s %10s %10s %12s\n", ...
    "solver", "wins", "ties", "losses", "solved", "geom_ratio");
for sidx = 1:num_solvers
    fprintf("%-14s %8d %8d %10d %10d %12.4g\n", ...
        summary(sidx).solver, summary(sidx).wins, summary(sidx).ties, ...
        summary(sidx).losses, summary(sidx).solved, summary(sidx).geom_ratio);
end

end

function solver_specs = make_solver_specs()
solver_specs = struct("name", {}, "solve", {});

solver_specs(end+1).name = "BDS0";
solver_specs(end).solve = make_nbds_handle(0, 1, Inf, Inf, 0, false, false);

solver_specs(end+1).name = "BDS-simpl";
solver_specs(end).solve = @(fun, x0, maxfun) run_bds(fun, x0, maxfun);

etas = [0.25, 0.50, 0.85, 0.95];
for k = 1:numel(etas)
    eta = etas(k);
    solver_specs(end+1).name = sprintf("NBDS-%0.2g", eta);
    solver_specs(end).solve = make_nbds_handle(eta, 1, Inf, Inf, 0, false, false);
end

for k = 1:numel(etas)
    eta = etas(k);
    solver_specs(end+1).name = sprintf("NBDSw-%0.2g", eta);
    solver_specs(end).solve = make_nbds_handle(eta, 0.5, Inf, Inf, 0, false, false);
end

moderate_etas = [0.50, 0.85, 0.95];
moderate_weak_factors = [0.8, 0.9];
for w = 1:numel(moderate_weak_factors)
    weak_factor = moderate_weak_factors(w);
    for k = 1:numel(moderate_etas)
        eta = moderate_etas(k);
        solver_specs(end+1).name = sprintf("W%0.1g-%0.2g", weak_factor, eta);
        solver_specs(end).solve = make_nbds_handle(eta, weak_factor, Inf, Inf, 0, false, false);
    end
end

failure_gate_etas = [0.85, 0.95];
failure_gates = [2, 4, 8];
for g = 1:numel(failure_gates)
    gate = failure_gates(g);
    for k = 1:numel(failure_gate_etas)
        eta = failure_gate_etas(k);
        solver_specs(end+1).name = sprintf("F%d-%0.2g", gate, eta);
        solver_specs(end).solve = make_nbds_handle(eta, 1, Inf, Inf, gate, false, false);
    end
end

for g = 1:numel(failure_gates)
    gate = failure_gates(g);
    for k = 1:numel(failure_gate_etas)
        eta = failure_gate_etas(k);
        solver_specs(end+1).name = sprintf("R%d-%0.2g", gate, eta);
        solver_specs(end).solve = make_nbds_handle(eta, 1, Inf, Inf, gate, true, false);
    end
end

focused_reset_etas = [0.90, 0.95];
focused_reset_gates = [2, 3];
for g = 1:numel(focused_reset_gates)
    gate = focused_reset_gates(g);
    for k = 1:numel(focused_reset_etas)
        eta = focused_reset_etas(k);
        if gate == 2 && eta == 0.95
            continue;
        end
        solver_specs(end+1).name = sprintf("R%d-%0.2g", gate, eta);
        solver_specs(end).solve = make_nbds_handle(eta, 1, Inf, Inf, gate, true, false);
    end
end

focused_weak_factors = [0.8, 0.9];
for w = 1:numel(focused_weak_factors)
    weak_factor = focused_weak_factors(w);
    for g = 1:numel(focused_reset_gates)
        gate = focused_reset_gates(g);
        eta = 0.95;
        solver_specs(end+1).name = sprintf("R%dW%0.1g-%0.2g", gate, weak_factor, eta);
        solver_specs(end).solve = make_nbds_handle(eta, weak_factor, Inf, Inf, gate, true, false);
    end
end

reference_reset_gates = [2, 3];
for g = 1:numel(reference_reset_gates)
    gate = reference_reset_gates(g);
    eta = 0.95;
    solver_specs(end+1).name = sprintf("C%d-%0.2g", gate, eta);
    solver_specs(end).solve = make_nbds_handle(eta, 1, Inf, Inf, gate, true, true);
end

guard_etas = [0.50, 0.85, 0.95];
guard_slacks = [1, 10, 100];
for s = 1:numel(guard_slacks)
    slack = guard_slacks(s);
    for k = 1:numel(guard_etas)
        eta = guard_etas(k);
        solver_specs(end+1).name = sprintf("G%g-%0.2g", slack, eta);
        solver_specs(end).solve = make_nbds_handle(eta, 1, slack, Inf, 0, false, false);
    end
end
end

function handle = make_nbds_handle(eta, weak_factor, slack_coeff, best_slack_coeff, weak_min_failures, ...
    weak_accept_resets_failures, weak_accept_resets_reference, max_weak_per_cycle)
if nargin < 8
    max_weak_per_cycle = Inf;
end
handle = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, eta, weak_factor, ...
    slack_coeff, best_slack_coeff, weak_min_failures, weak_accept_resets_failures, ...
    weak_accept_resets_reference, max_weak_per_cycle);
end

function [xopt, fopt, exitflag, output] = run_bds(fun, x0, maxfun)
wrapped = budgeted_fun(fun, maxfun);
[xopt, fopt, exitflag, output] = bds_simplified(wrapped, x0);
output.fhist = output.fhist(:);
end

function [xopt, fopt, exitflag, output] = run_nbds(fun, x0, maxfun, eta, weak_factor, ...
    slack_coeff, best_slack_coeff, weak_min_failures, weak_accept_resets_failures, ...
    weak_accept_resets_reference, max_weak_per_cycle)
wrapped = budgeted_fun(fun, maxfun);
options.maxfun = maxfun;
options.eta = eta;
options.weak_factor = weak_factor;
options.slack_coeff = slack_coeff;
options.best_slack_coeff = best_slack_coeff;
options.weak_min_failures = weak_min_failures;
options.weak_accept_resets_failures = weak_accept_resets_failures;
options.weak_accept_resets_reference = weak_accept_resets_reference;
options.max_weak_per_cycle = max_weak_per_cycle;
[xopt, fopt, exitflag, output] = nbds_simplified(wrapped, x0, options);
output.fhist = output.fhist(:);
end

function fun = budgeted_fun(fun0, maxfun)
count = 0;
    function f = wrapped(x)
        count = count + 1;
        if count > maxfun
            f = realmax("double");
        else
            f = fun0(x);
        end
    end
fun = @wrapped;
end

function problems = make_smoke_problems()
problems = struct("name", {}, "fun", {}, "x0", {}, "fmin", {}, "ftarget", {}, "maxfun", {});

problems(end+1) = make_problem("rosen10", @rosenbrock, -1.2 * ones(10, 1), 0, 1e-4, 8000);
problems(end+1) = make_problem("rosen20", @rosenbrock, -1.2 * ones(20, 1), 0, 1e-3, 16000);

n = 20;
problems(end+1) = make_problem("rotquad20", @(x) rotated_quadratic(x, 1e6), alternating_start(n), 0, 1e-8, 12000);

n = 40;
problems(end+1) = make_problem("illquad40", @(x) diagonal_quadratic(x, 1e8), alternating_start(n), 0, 1e-8, 16000);

n = 30;
problems(end+1) = make_problem("coupled30", @coupled_quartic, 1.5 * alternating_start(n), 0, 1e-6, 14000);

n = 60;
problems(end+1) = make_problem("sparse60", @sparse_active_quadratic, 2 * alternating_start(n), 0, 1e-8, 14000);

n = 20;
problems(end+1) = make_problem("noisyquad20", @(x) deterministic_noisy_quadratic(x, 1e-4), alternating_start(n), 0, 1e-4, 12000);

n = 12;
problems(end+1) = make_problem("powell12", @powell_singular, 3 * ones(n, 1), 0, 1e-6, 12000);
end

function p = make_problem(name, fun, x0, fmin, rel_target, maxfun)
f0 = fun(x0);
target = fmin + rel_target * max(1, f0 - fmin);
p.name = name;
p.fun = fun;
p.x0 = x0(:);
p.fmin = fmin;
p.ftarget = target;
p.maxfun = maxfun;
end

function x0 = alternating_start(n)
x0 = ones(n, 1);
x0(2:2:end) = -1;
end

function f = rosenbrock(x)
x = x(:);
f = sum(100 * (x(2:end) - x(1:end-1).^2).^2 + (1 - x(1:end-1)).^2);
end

function f = rotated_quadratic(x, cond_number)
x = x(:);
n = length(x);
Q = fixed_orthogonal(n);
exponents = linspace(0, 1, n)';
lambda = cond_number .^ exponents;
y = Q * x;
f = 0.5 * sum(lambda .* y.^2);
end

function f = diagonal_quadratic(x, cond_number)
x = x(:);
n = length(x);
lambda = cond_number .^ linspace(0, 1, n)';
f = 0.5 * sum(lambda .* x.^2);
end

function f = coupled_quartic(x)
x = x(:);
f = sum((x - 1).^4) + 10 * sum((x(2:end) - x(1:end-1)).^2);
end

function f = sparse_active_quadratic(x)
x = x(:);
m = min(5, length(x));
f = sum((x(1:m) - 0.25).^2) + 1e-4 * sum(x(m+1:end).^2);
end

function f = deterministic_noisy_quadratic(x, sigma)
x = x(:);
base = 0.5 * sum(x.^2);
noise = sigma * sin(1e3 * sum((1:length(x))' .* x));
f = base + noise;
end

function f = powell_singular(x)
x = x(:);
n = length(x);
f = 0;
for k = 1:4:n-3
    f = f + (x(k) + 10*x(k+1))^2 ...
        + 5*(x(k+2) - x(k+3))^2 ...
        + (x(k+1) - 2*x(k+2))^4 ...
        + 10*(x(k) - x(k+3))^4;
end
end

function Q = fixed_orthogonal(n)
persistent cache_n cache_Q
if ~isempty(cache_n) && cache_n == n
    Q = cache_Q;
    return;
end
A = zeros(n, n);
for i = 1:n
    for j = 1:n
        A(i, j) = sin(17*i + 31*j) + cos(13*i*j);
    end
end
[Q, ~] = qr(A);
cache_n = n;
cache_Q = Q;
end

function record = empty_record()
record = struct( ...
    "problem", "", ...
    "solver", "", ...
    "nf", NaN, ...
    "cost", Inf, ...
    "fbest", NaN, ...
    "gap", NaN, ...
    "exitflag", NaN, ...
    "ratio_to_bds", NaN, ...
    "f0", NaN, ...
    "ftarget", NaN, ...
    "strong", NaN, ...
    "weak", NaN, ...
    "failures", NaN);
end

function summary = summarize_records(records, solver_specs)
num_solvers = numel(solver_specs);
summary = repmat(struct("solver", "", "wins", 0, "ties", 0, "losses", 0, ...
    "solved", 0, "geom_ratio", NaN), 1, num_solvers);
for sidx = 1:num_solvers
    ratios = [];
    wins = 0;
    ties = 0;
    losses = 0;
    solved = 0;
    for pidx = 1:size(records, 1)
        bds_cost = records(pidx, 1).cost;
        cost = records(pidx, sidx).cost;
        if isfinite(cost)
            solved = solved + 1;
        end
        if cost < bds_cost
            wins = wins + 1;
        elseif cost == bds_cost || (isinf(cost) && isinf(bds_cost))
            ties = ties + 1;
        else
            losses = losses + 1;
        end
        if isfinite(cost) && isfinite(bds_cost)
            ratios(end+1) = cost / max(1, bds_cost);
        end
    end
    if isempty(ratios)
        geom_ratio = Inf;
    else
        geom_ratio = exp(mean(log(max(ratios, realmin))));
    end
    summary(sidx).solver = solver_specs(sidx).name;
    summary(sidx).wins = wins;
    summary(sidx).ties = ties;
    summary(sidx).losses = losses;
    summary(sidx).solved = solved;
    summary(sidx).geom_ratio = geom_ratio;
end
end

function value = getfield_default(s, field, default_value)
if isfield(s, field)
    value = s.(field);
else
    value = default_value;
end
end

function text = format_number(x)
if isnan(x)
    text = "-";
elseif isinf(x)
    text = "Inf";
elseif abs(x - round(x)) < 1e-12 && abs(x) < 1e9
    text = sprintf("%d", round(x));
else
    text = sprintf("%.3g", x);
end
end
