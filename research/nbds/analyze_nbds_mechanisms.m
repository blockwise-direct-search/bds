function results = analyze_nbds_mechanisms(options)
%ANALYZE_NBDS_MECHANISMS Inspect why nonmonotone BDS wins or loses.
%
% The script is deliberately diagnostic: it does not tune the algorithm or
% hide difficult problems.  It compares representative S2MPJ cases through
% event-level NBDS traces.

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

if ~isfield(options, "problem_names")
    options.problem_names = [ ...
        "INDEF", "SCURLY30", "SCURLY20", "CYCLIC3LS", "MGH10LS", "MGH10SLS", ...
        "MEYER3", "DENSCHND", "PALMER1D", "STREG", "YATP2LS", ...
        "YFITU", "WATSON", "PALMER4C", "PALMER3C"];
end
if ~isfield(options, "max_eval_factor")
    options.max_eval_factor = 500;
end
if ~isfield(options, "verbose")
    options.verbose = true;
end

solver_specs = make_solver_specs();
problem_names = string(options.problem_names);
records = repmat(empty_record(), numel(problem_names), numel(solver_specs));

if options.verbose
    fprintf("NBDS mechanism diagnostics: %d problems, maxfun=%dn\n\n", ...
        numel(problem_names), options.max_eval_factor);
    fprintf("%-12s %-5s %4s %12s %6s %6s %6s %6s %7s %9s %9s %9s %9s %9s\n", ...
        "problem", "solver", "n", "fbest", "strong", "weak", "prod", "late", "lag", ...
        "maxCgap", "maxBgap", "medWgap", "weak/acc", "nf");
    fprintf("%s\n", repmat('-', 1, 124));
end

for pidx = 1:numel(problem_names)
    problem_name = char(problem_names(pidx));
    try
        p = s2mpj_wrapper(s2mpj_load(problem_name));
    catch err
        warning("analyze_nbds_mechanisms:ProblemLoadFailed", ...
            "Skipping %s: %s", problem_name, err.message);
        continue;
    end

    x0 = p.x0(:);
    n = length(x0);
    maxfun = max(1, options.max_eval_factor * n);
    for sidx = 1:numel(solver_specs)
        spec = solver_specs(sidx);
        try
            [~, ~, exitflag, output] = spec.solve(p.objective, x0, maxfun);
            metrics = trace_metrics(output);
            fbest = min(output.fhist(:));
            records(pidx, sidx) = pack_record(problem_name, spec.name, n, ...
                exitflag, fbest, output.funcCount, metrics);
        catch err
            warning("analyze_nbds_mechanisms:SolverFailed", ...
                "%s failed on %s: %s", spec.name, problem_name, err.message);
            records(pidx, sidx).problem = string(problem_name);
            records(pidx, sidx).solver = string(spec.name);
            records(pidx, sidx).n = n;
            records(pidx, sidx).failed = true;
        end

        if options.verbose
            r = records(pidx, sidx);
            fprintf("%-12s %-5s %4d %12.4e %6s %6s %6s %6s %7s %9s %9s %9s %9s %9s\n", ...
                problem_name, spec.name, n, r.fbest, format_number(r.strong), ...
                format_number(r.weak), format_number(r.productive_weak), ...
                format_number(r.late_weak), format_number(r.median_productive_lag), ...
                format_number(r.max_C_gap_scale), ...
                format_number(r.max_base_gap_scale), format_number(r.median_weak_gap_scale), ...
                format_number(r.weak_accept_fraction), format_number(r.nf));
        end
    end
    if options.verbose
        fprintf("%s\n", repmat('-', 1, 124));
    end
end

results = struct();
results.options = options;
results.problem_names = problem_names;
results.solver_specs = solver_specs;
results.records = records;
results.comparison = compare_records(records, solver_specs);

if options.verbose
    fprintf("\nPairwise final-value comparison versus BDS0\n");
    fprintf("%-5s %6s %6s %6s %10s %10s %10s %10s\n", ...
        "solver", "wins", "ties", "losses", "medWeak", "medProd", "medLate", "medCgap");
    for sidx = 1:numel(solver_specs)
        c = results.comparison(sidx);
        fprintf("%-5s %6d %6d %6d %10s %10s %10s %10s\n", ...
            c.solver, c.wins, c.ties, c.losses, format_number(c.median_weak), ...
            format_number(c.median_productive_weak), format_number(c.median_late_weak), ...
            format_number(c.median_max_C_gap_scale));
    end
end

end

function solver_specs = make_solver_specs()
solver_specs = struct("name", {}, "solve", {});

solver_specs(end+1).name = "BDS0";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0, 1, ...
    Inf, Inf, 0, false, false, Inf, 0, 0, 0);

solver_specs(end+1).name = "R3";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, true, false, Inf, 0, 0, 0);

solver_specs(end+1).name = "L3";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0);

solver_specs(end+1).name = "LS3";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 0.5, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0);

solver_specs(end+1).name = "LC3";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, 3, 0, 0, 0);

solver_specs(end+1).name = "LC5";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, 5, 0, 0, 0);

solver_specs(end+1).name = "LF10";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0, 0.10);

solver_specs(end+1).name = "CF10";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0, 0.10, 2, 1, 1e-8, 0.10);

solver_specs(end+1).name = "CF20";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0, 0.20, 2, 1, 1e-8, 0.20);

solver_specs(end+1).name = "BF10";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0, 0.10, ...
    Inf, Inf, 0, Inf, 1e-8, 1);

solver_specs(end+1).name = "BF20";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, false, false, Inf, 0, 0, 0, 0.20, ...
    Inf, Inf, 0, Inf, 1e-8, 1);

solver_specs(end+1).name = "Q3";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, true, false, Inf, 0, 0.25, 0);

solver_specs(end+1).name = "TQ3";
solver_specs(end).solve = @(fun, x0, maxfun) run_nbds(fun, x0, maxfun, 0.95, 1, ...
    Inf, Inf, 3, true, false, Inf, 1, 0.25, 0);
end

function [xopt, fopt, exitflag, output] = run_nbds(fun, x0, maxfun, eta, weak_factor, ...
    slack_coeff, best_slack_coeff, weak_min_failures, weak_accept_resets_failures, ...
    weak_accept_resets_reference, max_weak_per_cycle, weak_min_stalled_cycles, ...
    weak_min_failed_block_fraction, weak_min_failed_blocks_in_cycle, ...
    max_weak_per_cycle_fraction, weak_credit_window_factor, ...
    weak_credit_cooldown_factor, weak_credit_gain_coeff, ...
    weak_credit_max_pending_fraction, weak_burst_gain_coeff, ...
    weak_burst_cooldown_cycles)

if nargin < 15
    max_weak_per_cycle_fraction = Inf;
end
if nargin < 16
    weak_credit_window_factor = Inf;
end
if nargin < 17
    weak_credit_cooldown_factor = Inf;
end
if nargin < 18
    weak_credit_gain_coeff = 0;
end
if nargin < 19
    weak_credit_max_pending_fraction = Inf;
end
if nargin < 20
    weak_burst_gain_coeff = 0;
end
if nargin < 21
    weak_burst_cooldown_cycles = 0;
end

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
options.max_weak_per_cycle_fraction = max_weak_per_cycle_fraction;
options.weak_credit_window_factor = weak_credit_window_factor;
options.weak_credit_cooldown_factor = weak_credit_cooldown_factor;
options.weak_credit_gain_coeff = weak_credit_gain_coeff;
options.weak_credit_max_pending_fraction = weak_credit_max_pending_fraction;
options.weak_burst_gain_coeff = weak_burst_gain_coeff;
options.weak_burst_cooldown_cycles = weak_burst_cooldown_cycles;
options.weak_min_stalled_cycles = weak_min_stalled_cycles;
options.weak_min_failed_block_fraction = weak_min_failed_block_fraction;
options.weak_min_failed_blocks_in_cycle = weak_min_failed_blocks_in_cycle;
[xopt, fopt, exitflag, output] = nbds_simplified(wrapped, x0, options);
output.fhist = output.fhist(:);
end

function metrics = trace_metrics(output)
trace = output.trace;
scale = max(1, abs(output.fhist(1)));
weak = logical(trace.weak);
accepted = logical(trace.accepted);
best_improved = logical(trace.best_improved);

weak_indices = find(weak);
window = 2 * max(1, numel(unique(trace.block)));
productive = false(size(weak));
late = false(size(weak));
productive_lags = [];
for idx = weak_indices
    later = find(best_improved(idx+1:end), 1, "first");
    if isempty(later) || later > window
        late(idx) = true;
    else
        productive(idx) = true;
        productive_lags(end+1) = later;
    end
end

weak_gaps = trace.accept_gap_before(weak) ./ scale;
if isempty(weak_gaps)
    median_weak_gap_scale = NaN;
    max_weak_gap_scale = NaN;
else
    median_weak_gap_scale = median(weak_gaps, "omitnan");
    max_weak_gap_scale = max(weak_gaps, [], "omitnan");
end

metrics.strong = sum(logical(trace.strong));
metrics.weak = sum(weak);
metrics.accepted = sum(accepted);
metrics.productive_weak = sum(productive);
metrics.late_weak = sum(late);
metrics.weak_accept_fraction = safe_ratio(metrics.weak, metrics.accepted);
metrics.productive_weak_fraction = safe_ratio(metrics.productive_weak, metrics.weak);
metrics.late_weak_fraction = safe_ratio(metrics.late_weak, metrics.weak);
metrics.median_productive_lag = median(productive_lags, "omitnan");
metrics.max_C_gap_scale = max(trace.C_gap_before ./ scale, [], "omitnan");
metrics.max_base_gap_scale = max(trace.base_gap_before ./ scale, [], "omitnan");
metrics.median_weak_gap_scale = median_weak_gap_scale;
metrics.max_weak_gap_scale = max_weak_gap_scale;
metrics.final_base_gap_scale = trace.base_gap_before(end) ./ scale;
end

function ratio = safe_ratio(a, b)
if b == 0
    ratio = NaN;
else
    ratio = a / b;
end
end

function record = pack_record(problem_name, solver_name, n, exitflag, fbest, nf, metrics)
record = empty_record();
record.problem = string(problem_name);
record.solver = string(solver_name);
record.n = n;
record.exitflag = exitflag;
record.fbest = fbest;
record.nf = nf;
fields = fieldnames(metrics);
for i = 1:numel(fields)
    record.(fields{i}) = metrics.(fields{i});
end
end

function comparison = compare_records(records, solver_specs)
comparison = repmat(struct("solver", "", "wins", 0, "ties", 0, "losses", 0, ...
    "median_weak", NaN, "median_productive_weak", NaN, "median_late_weak", NaN, ...
    "median_max_C_gap_scale", NaN), 1, numel(solver_specs));
for sidx = 1:numel(solver_specs)
    wins = 0;
    ties = 0;
    losses = 0;
    weak = [];
    productive = [];
    late = [];
    cgap = [];
    for pidx = 1:size(records, 1)
        base = records(pidx, 1);
        rec = records(pidx, sidx);
        if rec.failed || base.failed
            continue;
        end
        tol = 1e-8 + 1e-6 * max([1, abs(base.fbest), abs(rec.fbest)]);
        if rec.fbest < base.fbest - tol
            wins = wins + 1;
        elseif rec.fbest > base.fbest + tol
            losses = losses + 1;
        else
            ties = ties + 1;
        end
        weak(end+1) = rec.weak;
        productive(end+1) = rec.productive_weak_fraction;
        late(end+1) = rec.late_weak_fraction;
        cgap(end+1) = rec.max_C_gap_scale;
    end
    comparison(sidx).solver = solver_specs(sidx).name;
    comparison(sidx).wins = wins;
    comparison(sidx).ties = ties;
    comparison(sidx).losses = losses;
    comparison(sidx).median_weak = median(weak, "omitnan");
    comparison(sidx).median_productive_weak = median(productive, "omitnan");
    comparison(sidx).median_late_weak = median(late, "omitnan");
    comparison(sidx).median_max_C_gap_scale = median(cgap, "omitnan");
end
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

function record = empty_record()
record = struct( ...
    "problem", "", ...
    "solver", "", ...
    "n", NaN, ...
    "exitflag", NaN, ...
    "fbest", NaN, ...
    "nf", NaN, ...
    "failed", false, ...
    "strong", NaN, ...
    "weak", NaN, ...
    "accepted", NaN, ...
    "productive_weak", NaN, ...
    "late_weak", NaN, ...
    "weak_accept_fraction", NaN, ...
    "productive_weak_fraction", NaN, ...
    "late_weak_fraction", NaN, ...
    "median_productive_lag", NaN, ...
    "max_C_gap_scale", NaN, ...
    "max_base_gap_scale", NaN, ...
    "median_weak_gap_scale", NaN, ...
    "max_weak_gap_scale", NaN, ...
    "final_base_gap_scale", NaN);
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
