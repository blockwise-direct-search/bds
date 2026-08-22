function stats = inspect_nbds_trace(options)
%INSPECT_NBDS_TRACE Summarize weak-acceptance burst patterns.
%
% This diagnostic complements analyze_nbds_mechanisms.m.  It keeps the
% algorithm fixed and inspects whether weak acceptances are isolated events
% or sustained bursts across blocks/cycles.

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
    options.problem_names = ["SCURLY30", "CYCLIC3LS", "YATP2LS", "MEYER3"];
end
if ~isfield(options, "solver_names")
    options.solver_names = ["R3", "L3", "Q3", "TQ3"];
end
if ~isfield(options, "max_eval_factor")
    options.max_eval_factor = 500;
end
if ~isfield(options, "verbose")
    options.verbose = true;
end

problem_names = string(options.problem_names);
solver_names = string(options.solver_names);
stats = repmat(empty_stats(), numel(problem_names), numel(solver_names));

if options.verbose
    fprintf("NBDS weak-burst trace inspection: %d problems, maxfun=%dn\n\n", ...
        numel(problem_names), options.max_eval_factor);
    fprintf("%-12s %-5s %4s %12s %6s %6s %7s %7s %7s %8s %9s %9s %9s %9s\n", ...
        "problem", "solver", "n", "fbest", "weak", "late", "maxRun", ...
        "maxCyc", "uBlock", "medGap", "medWa", "medSa", "medFa", "medGain");
    fprintf("%s\n", repmat('-', 1, 126));
end

for pidx = 1:numel(problem_names)
    problem_name = char(problem_names(pidx));
    p = s2mpj_wrapper(s2mpj_load(problem_name));
    x0 = p.x0(:);
    n = length(x0);
    maxfun = max(1, options.max_eval_factor * n);

    for sidx = 1:numel(solver_names)
        solver_name = solver_names(sidx);
        solver_options = make_options(solver_name, maxfun);
        wrapped = budgeted_fun(p.objective, maxfun);
        [~, ~, ~, output] = nbds_simplified(wrapped, x0, solver_options);
        stats(pidx, sidx) = trace_stats(problem_name, solver_name, n, output);

        if options.verbose
            r = stats(pidx, sidx);
            fprintf("%-12s %-5s %4d %12.4e %6s %6s %7s %7s %7s %8s %9s %9s %9s %9s\n", ...
                r.problem, r.solver, r.n, r.fbest, fmt(r.weak), fmt(r.late_weak), ...
                fmt(r.max_weak_run), fmt(r.max_weak_per_cycle), ...
                fmt(r.unique_weak_blocks), fmt(r.median_same_block_gap), ...
                fmt(r.median_weak_alpha), fmt(r.median_strong_alpha), ...
                fmt(r.median_failure_alpha), fmt(r.median_weak_window_gain));
        end
    end
    if options.verbose
        fprintf("%s\n", repmat('-', 1, 126));
    end
end

end

function options = make_options(solver_name, maxfun)
options.maxfun = maxfun;
options.alpha_tol = 1e-6;
options.expand = 2;
options.shrink = 0.5;
options.slack_coeff = Inf;
options.best_slack_coeff = Inf;

switch string(solver_name)
    case "BDS0"
        options.eta = 0;
        options.weak_factor = 1;
        options.weak_min_failures = 0;
        options.weak_accept_resets_failures = false;
    case "R3"
        options.eta = 0.95;
        options.weak_factor = 1;
        options.weak_min_failures = 3;
        options.weak_accept_resets_failures = true;
    case "L3"
        options.eta = 0.95;
        options.weak_factor = 1;
        options.weak_min_failures = 3;
        options.weak_accept_resets_failures = false;
    case "LS3"
        options.eta = 0.95;
        options.weak_factor = 0.5;
        options.weak_min_failures = 3;
        options.weak_accept_resets_failures = false;
    case "Q3"
        options.eta = 0.95;
        options.weak_factor = 1;
        options.weak_min_failures = 3;
        options.weak_accept_resets_failures = true;
        options.weak_min_failed_block_fraction = 0.25;
    case "TQ3"
        options.eta = 0.95;
        options.weak_factor = 1;
        options.weak_min_failures = 3;
        options.weak_accept_resets_failures = true;
        options.weak_min_failed_block_fraction = 0.25;
        options.weak_min_stalled_cycles = 1;
    otherwise
        error("Unknown solver name: %s", solver_name);
end
end

function r = trace_stats(problem_name, solver_name, n, output)
trace = output.trace;
weak = logical(trace.weak);
strong = logical(trace.strong);
accepted = logical(trace.accepted);
failure = ~accepted;
best_improved = logical(trace.best_improved);
weak_indices = find(weak);
window = 2 * max(1, numel(unique(trace.block)));

late_weak = false(size(weak));
weak_window_gains = [];
scale = max(1, abs(output.fhist(1)));
for idx = weak_indices
    later = find(best_improved(idx+1:end), 1, "first");
    late_weak(idx) = isempty(later) || later > window;
    last_idx = min(numel(trace.fbest_after), idx + window);
    window_best = min(trace.fbest_after(idx:last_idx));
    weak_window_gains(end+1) = max(0, trace.fbest_before(idx) - window_best) / scale;
end

r = empty_stats();
r.problem = string(problem_name);
r.solver = string(solver_name);
r.n = n;
r.fbest = min(output.fhist(:));
r.weak = sum(weak);
r.late_weak = sum(late_weak);
r.max_weak_run = max_true_run(weak);
r.max_weak_per_cycle = max_count_by_key(trace.iter(weak));
r.unique_weak_blocks = numel(unique(trace.block(weak)));
r.median_same_block_gap = median_same_block_gap(trace.block, weak_indices);
r.median_weak_alpha = median(trace.alpha_before(weak), "omitnan");
r.median_strong_alpha = median(trace.alpha_before(strong), "omitnan");
r.median_failure_alpha = median(trace.alpha_before(failure), "omitnan");
r.median_weak_window_gain = median(weak_window_gains, "omitnan");
r.max_weak_window_gain = max(weak_window_gains, [], "omitnan");
r.weak_fraction = safe_ratio(sum(weak), numel(weak));
r.weak_accept_fraction = safe_ratio(sum(weak), sum(accepted));
end

function value = max_true_run(mask)
if isempty(mask)
    value = 0;
    return;
end
starts = find(diff([false, mask(:).', false]) == 1);
ends = find(diff([false, mask(:).', false]) == -1) - 1;
if isempty(starts)
    value = 0;
else
    value = max(ends - starts + 1);
end
end

function value = max_count_by_key(keys)
if isempty(keys)
    value = 0;
    return;
end
ukeys = unique(keys);
counts = arrayfun(@(key) sum(keys == key), ukeys);
value = max(counts);
end

function value = median_same_block_gap(blocks, weak_indices)
if numel(weak_indices) < 2
    value = NaN;
    return;
end
gaps = [];
for idx = weak_indices(:).'
    previous = weak_indices(weak_indices < idx & blocks(weak_indices) == blocks(idx));
    if ~isempty(previous)
        gaps(end+1) = idx - previous(end);
    end
end
value = median(gaps, "omitnan");
end

function ratio = safe_ratio(a, b)
if b == 0
    ratio = NaN;
else
    ratio = a / b;
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

function r = empty_stats()
r = struct( ...
    "problem", "", ...
    "solver", "", ...
    "n", NaN, ...
    "fbest", NaN, ...
    "weak", NaN, ...
    "late_weak", NaN, ...
    "max_weak_run", NaN, ...
    "max_weak_per_cycle", NaN, ...
    "unique_weak_blocks", NaN, ...
    "median_same_block_gap", NaN, ...
    "median_weak_alpha", NaN, ...
    "median_strong_alpha", NaN, ...
    "median_failure_alpha", NaN, ...
    "median_weak_window_gain", NaN, ...
    "max_weak_window_gain", NaN, ...
    "weak_fraction", NaN, ...
    "weak_accept_fraction", NaN);
end

function text = fmt(x)
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
