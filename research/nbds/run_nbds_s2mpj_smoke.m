function results = run_nbds_s2mpj_smoke(options)
%RUN_NBDS_S2MPJ_SMOKE External smoke test for the NBDS prototype.
%
% This script intentionally stays outside the main OptiProfiler workflow. It
% uses a small S2MPJ subset to check whether the nonmonotone-BDS signal found
% on handcrafted problems survives on non-handpicked test problems.

if nargin < 1
    options = struct();
end

old_dir = pwd();
repo_dir = fileparts(fileparts(mfilename("fullpath")));
cleanup = onCleanup(@() cd(old_dir));
cd(repo_dir);
setup;
addpath(fullfile(repo_dir, "tests"));
addpath(fullfile(repo_dir, "tests", "competitors"));

if ~isfield(options, "mindim")
    options.mindim = 2;
end
if ~isfield(options, "maxdim")
    options.maxdim = 10;
end
if ~isfield(options, "num_problems")
    options.num_problems = 30;
end
if ~isfield(options, "start_index")
    options.start_index = 1;
end
if ~isfield(options, "max_eval_factor")
    options.max_eval_factor = 500;
end
if ~isfield(options, "target_fraction")
    options.target_fraction = 1e-3;
end
if ~isfield(options, "verbose")
    options.verbose = true;
end
if ~isfield(options, "solver_family")
    options.solver_family = "activation";
end
if ~isfield(options, "problem_names")
    problem_names = select_s2mpj_problems(options);
else
    problem_names = string(options.problem_names);
end

solver_specs = make_solver_specs();
num_problems = numel(problem_names);
num_solvers = numel(solver_specs);
records = repmat(empty_record(), num_problems, num_solvers);

fprintf("NBDS S2MPJ smoke: %d problems, dims [%d,%d], maxfun=%dn\n\n", ...
    num_problems, options.mindim, options.maxdim, options.max_eval_factor);
if options.verbose
    fprintf("%-14s %4s %-10s %8s %13s %10s %8s %8s\n", ...
        "problem", "n", "solver", "cost", "fbest", "ratio", "strong", "weak");
    fprintf("%s\n", repmat('-', 1, 86));
end

for pidx = 1:num_problems
    problem_name = char(problem_names(pidx));
    try
        p = s2mpj_wrapper(s2mpj_load(problem_name));
    catch err
        warning("run_nbds_s2mpj_smoke:ProblemLoadFailed", ...
            "Skipping %s: %s", problem_name, err.message);
        continue;
    end

    x0 = p.x0(:);
    n = length(x0);
    maxfun = max(1, options.max_eval_factor * n);
    solver_outputs = repmat(empty_solver_output(), 1, num_solvers);
    f0 = safe_eval(p.objective, x0);

    for sidx = 1:num_solvers
        spec = solver_specs(sidx);
        try
            [~, ~, exitflag, output] = spec.solve(p.objective, x0, maxfun);
            output.fhist = output.fhist(:);
            fhist_best = cummin(output.fhist);
            solver_outputs(sidx).exitflag = exitflag;
            solver_outputs(sidx).nf = output.funcCount;
            solver_outputs(sidx).fhist_best = fhist_best;
            solver_outputs(sidx).fbest = fhist_best(end);
            solver_outputs(sidx).strong = getfield_default(output, "strong_success_count", NaN);
            solver_outputs(sidx).weak = getfield_default(output, "weak_success_count", NaN);
            solver_outputs(sidx).failed = false;
        catch err
            warning("run_nbds_s2mpj_smoke:SolverFailed", ...
                "%s failed on %s: %s", spec.name, problem_name, err.message);
            solver_outputs(sidx).failed = true;
            solver_outputs(sidx).fbest = Inf;
        end
    end

    fbest_all = [solver_outputs.fbest];
    finite_fbest = fbest_all(isfinite(fbest_all));
    if isempty(finite_fbest)
        ftarget = -Inf;
    else
        best_seen = min(finite_fbest);
        ftarget = best_seen + options.target_fraction * max(1, abs(f0 - best_seen));
    end
    base_cost = target_cost(solver_outputs(1).fhist_best, ftarget);

    for sidx = 1:num_solvers
        spec = solver_specs(sidx);
        out = solver_outputs(sidx);
        cost = target_cost(out.fhist_best, ftarget);
        ratio = cost_ratio(cost, base_cost);

        records(pidx, sidx).problem = string(problem_name);
        records(pidx, sidx).n = n;
        records(pidx, sidx).solver = string(spec.name);
        records(pidx, sidx).nf = out.nf;
        records(pidx, sidx).cost = cost;
        records(pidx, sidx).ratio_to_bds = ratio;
        records(pidx, sidx).f0 = f0;
        records(pidx, sidx).ftarget = ftarget;
        records(pidx, sidx).fbest = out.fbest;
        records(pidx, sidx).exitflag = out.exitflag;
        records(pidx, sidx).strong = out.strong;
        records(pidx, sidx).weak = out.weak;
        records(pidx, sidx).failed = out.failed;

        if options.verbose
            fprintf("%-14s %4d %-10s %8s %13.4e %10s %8s %8s\n", ...
                problem_name, n, spec.name, format_cost(cost), out.fbest, ...
                format_number(ratio), format_number(out.strong), format_number(out.weak));
        end
    end
    if options.verbose
        fprintf("%s\n", repmat('-', 1, 86));
    end
end

summary = summarize_records(records, solver_specs);

results = struct();
results.options = options;
results.problem_names = problem_names;
results.records = records;
results.summary = summary;

fprintf("\nSummary relative to BDS target-hit cost\n");
fprintf("%-10s %8s %8s %10s %10s %12s\n", ...
    "solver", "wins", "ties", "losses", "solved", "geom_ratio");
for sidx = 1:num_solvers
    fprintf("%-10s %8d %8d %10d %10d %12.4g\n", ...
        summary(sidx).solver, summary(sidx).wins, summary(sidx).ties, ...
        summary(sidx).losses, summary(sidx).solved, summary(sidx).geom_ratio);
end

end

function solver_specs = make_solver_specs()
solver_specs = struct("name", {}, "solve", {});

solver_specs(end+1).name = "BDS0";
solver_specs(end).solve = make_nbds_handle(0, 1, Inf, Inf, 0, false, false);

solver_specs(end+1).name = "R2-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 2, true, false);

solver_specs(end+1).name = "R3-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 3, true, false);

solver_specs(end+1).name = "T2-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 2, true, false, Inf, 1, 0, 0);

solver_specs(end+1).name = "T3-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 3, true, false, Inf, 1, 0, 0);

solver_specs(end+1).name = "Q2-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 2, true, false, Inf, 0, 0.25, 0);

solver_specs(end+1).name = "Q3-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 3, true, false, Inf, 0, 0.25, 0);

solver_specs(end+1).name = "TQ2-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 2, true, false, Inf, 1, 0.25, 0);

solver_specs(end+1).name = "TQ3-0.95";
solver_specs(end).solve = make_nbds_handle(0.95, 1, Inf, Inf, 3, true, false, Inf, 1, 0.25, 0);
end

function handle = make_nbds_handle(eta, weak_factor, slack_coeff, best_slack_coeff, weak_min_failures, ...
    weak_accept_resets_failures, weak_accept_resets_reference, max_weak_per_cycle, ...
    weak_min_stalled_cycles, weak_min_failed_block_fraction, weak_min_failed_blocks_in_cycle)
if nargin < 8
    max_weak_per_cycle = Inf;
end
if nargin < 9
    weak_min_stalled_cycles = 0;
end
if nargin < 10
    weak_min_failed_block_fraction = 0;
end
if nargin < 11
    weak_min_failed_blocks_in_cycle = 0;
end
handle = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, eta, weak_factor, ...
    slack_coeff, best_slack_coeff, weak_min_failures, weak_accept_resets_failures, ...
    weak_accept_resets_reference, max_weak_per_cycle, weak_min_stalled_cycles, ...
    weak_min_failed_block_fraction, weak_min_failed_blocks_in_cycle);
end

function [xopt, fopt, exitflag, output] = run_nbds(fun, x0, maxfun, eta, weak_factor, ...
    slack_coeff, best_slack_coeff, weak_min_failures, weak_accept_resets_failures, ...
    weak_accept_resets_reference, max_weak_per_cycle, weak_min_stalled_cycles, ...
    weak_min_failed_block_fraction, weak_min_failed_blocks_in_cycle)
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
options.weak_min_stalled_cycles = weak_min_stalled_cycles;
options.weak_min_failed_block_fraction = weak_min_failed_block_fraction;
options.weak_min_failed_blocks_in_cycle = weak_min_failed_blocks_in_cycle;
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
            f = safe_eval(fun0, x);
        end
    end
fun = @wrapped;
end

function f = safe_eval(fun, x)
try
    f = fun(x);
    if ~isfinite(f)
        f = realmax("double");
    end
catch
    f = realmax("double");
end
end

function problem_names = select_s2mpj_problems(options)
select_options.ptype = "u";
select_options.mindim = options.mindim;
select_options.maxdim = options.maxdim;
problem_names = string(s2mpj_select(select_options));
excluded = [ ...
    "DIAMON2DLS", "DIAMON2D", "DIAMON3DLS", "DIAMON3D", ...
    "DMN15102LS", "DMN15102", "DMN15103LS", "DMN15103", ...
    "DMN15332LS", "DMN15332", "DMN15333LS", "DMN15333", ...
    "DMN37142LS", "DMN37142", "DMN37143LS", "DMN37143", ...
    "ROSSIMP3_mp", "BAmL1SPLS", "FBRAIN3LS", "GAUSS1LS", ...
    "GAUSS2LS", "GAUSS3LS", "HYDC20LS", "HYDCAR6LS", ...
    "LUKSAN11LS", "LUKSAN12LS", "LUKSAN13LS", "LUKSAN14LS", ...
    "LUKSAN17LS", "LUKSAN21LS", "LUKSAN22LS", "METHANB8LS", ...
    "METHANL8LS", "SPINLS", "VESUVIALS", "VESUVIOLS", ...
    "VESUVIOULS", "YATP1CLS"];
problem_names = problem_names(~ismember(problem_names, excluded));
first = min(max(1, options.start_index), numel(problem_names) + 1);
last = min(first + options.num_problems - 1, numel(problem_names));
problem_names = problem_names(first:last);
end

function cost = target_cost(fhist_best, ftarget)
if isempty(fhist_best) || ~isfinite(ftarget)
    cost = Inf;
    return;
end
index = find(fhist_best <= ftarget, 1, "first");
if isempty(index)
    cost = Inf;
else
    cost = index;
end
end

function ratio = cost_ratio(cost, base_cost)
if isinf(cost) && isinf(base_cost)
    ratio = 1;
elseif isinf(cost)
    ratio = Inf;
elseif isinf(base_cost)
    ratio = 0;
else
    ratio = cost / max(1, base_cost);
end
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

function record = empty_record()
record = struct( ...
    "problem", "", ...
    "n", NaN, ...
    "solver", "", ...
    "nf", NaN, ...
    "cost", Inf, ...
    "ratio_to_bds", NaN, ...
    "f0", NaN, ...
    "ftarget", NaN, ...
    "fbest", NaN, ...
    "exitflag", NaN, ...
    "strong", NaN, ...
    "weak", NaN, ...
    "failed", false);
end

function output = empty_solver_output()
output = struct( ...
    "nf", NaN, ...
    "fhist_best", [], ...
    "fbest", Inf, ...
    "exitflag", NaN, ...
    "strong", NaN, ...
    "weak", NaN, ...
    "failed", false);
end

function value = getfield_default(s, field, default_value)
if isfield(s, field)
    value = s.(field);
else
    value = default_value;
end
end

function text = format_cost(x)
if isinf(x)
    text = "Inf";
else
    text = sprintf("%d", round(x));
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
