function results = run_accelerated_bds_memory_ablation()
%RUN_ACCELERATED_BDS_MEMORY_ABLATION Controlled ablation for acceleration strategies.
%
% The experiment is deliberately small and deterministic.  It compares the
% productive-direction memory against the sweep-pattern and momentum
% mechanisms on plain and rotated quadratic test problems.

path_ablation = fileparts(mfilename('fullpath'));
path_research = fileparts(path_ablation);
path_root = fileparts(path_research);
oldpath = path();
cleanup = onCleanup(@() path(oldpath));

addpath(fullfile(path_root, 'src'));

dims = [2, 5, 10, 20, 50];
seeds = [101, 202, 303];
problems = { ...
    'axis_sphere', ...
    'coupled_quadratic', ...
    'rotated_ellipsoid_1e2', ...
    'rotated_ellipsoid_1e4'};
variants = make_variants();

rows = struct([]);
row = 0;
fprintf('Running accelerated BDS memory ablation...\n');
fprintf('Problems=%d, dims=%d, seeds=%d, variants=%d\n', ...
    numel(problems), numel(dims), numel(seeds), numel(variants));

for ip = 1:numel(problems)
    problem_name = problems{ip};
    for in = 1:numel(dims)
        n = dims(in);
        for iseed = 1:numel(seeds)
            seed = seeds(iseed);
            [fun, x0] = make_problem(problem_name, n, seed);

            for iv = 1:numel(variants)
                variant = variants(iv);
                options = make_options(variant, n);
                tstart = tic;
                [~, fopt, exitflag, output] = bds(fun, x0, options);
                elapsed = toc(tstart);

                row = row + 1;
                rows(row).problem = problem_name;
                rows(row).n = n;
                rows(row).seed = seed;
                rows(row).variant = variant.name;
                rows(row).use_memory = variant.use_memory;
                rows(row).use_pattern = variant.use_pattern;
                rows(row).use_momentum = variant.use_momentum;
                rows(row).final_f = fopt;
                rows(row).funcCount = output.funcCount;
                rows(row).exitflag = exitflag;
                rows(row).elapsed = elapsed;
            end
            fprintf('  done %-24s n=%2d seed=%d\n', problem_name, n, seed);
        end
    end
end

results = struct2table(rows);
out_dir = fullfile(path_ablation, 'testdata');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
out_csv = fullfile(out_dir, ['accelerated_bds_memory_ablation_', timestamp, '.csv']);
writetable(results, out_csv);

fprintf('\nSaved raw results to:\n%s\n', out_csv);
print_summary(results, problems, variants);

end

function variants = make_variants()

variants = struct( ...
    'name', {}, ...
    'use_memory', {}, ...
    'use_pattern', {}, ...
    'use_momentum', {});

variants(end + 1) = make_variant('all_off', false, false, false);
variants(end + 1) = make_variant('memory_only', true, false, false);
variants(end + 1) = make_variant('pattern_only', false, true, false);
variants(end + 1) = make_variant('momentum_only', false, false, true);
variants(end + 1) = make_variant('pattern_momentum', false, true, true);
variants(end + 1) = make_variant('full', true, true, true);

end

function variant = make_variant(name, use_memory, use_pattern, use_momentum)

variant.name = name;
variant.use_memory = use_memory;
variant.use_pattern = use_pattern;
variant.use_momentum = use_momentum;

end

function options = make_options(variant, n)

options = struct();
options.MaxFunctionEvaluations = 200 * n;
options.StepTolerance = 1e-6;
options.use_productive_direction_memory = variant.use_memory;
options.use_iteration_pattern_step = variant.use_pattern;
options.use_momentum_extrapolation = variant.use_momentum;

end

function [fun, x0] = make_problem(problem_name, n, seed)

rng(seed, 'twister');
x0 = linspace(-1.5, 1.5, n)' + 0.15 * randn(n, 1);
target = ((-1).^(1:n))' .* (1:n)' / max(n, 1);

switch problem_name
    case 'axis_sphere'
        weights = ones(n, 1);
        Q = eye(n);
    case 'coupled_quadratic'
        weights = ones(n, 1);
        Q = coupled_factor(n);
    case 'rotated_ellipsoid_1e2'
        weights = logspace(0, 2, n)';
        Q = random_orthogonal(n);
    case 'rotated_ellipsoid_1e4'
        weights = logspace(0, 4, n)';
        Q = random_orthogonal(n);
    otherwise
        error('Unknown problem: %s', problem_name);
end

fun = @(x) quadratic_fun(x, target, Q, weights);

end

function f = quadratic_fun(x, target, Q, weights)

z = Q' * (x(:) - target);
f = sum(weights .* (z .^ 2));

end

function Q = random_orthogonal(n)

[Q, R] = qr(randn(n));
sign_diag = sign(diag(R));
sign_diag(sign_diag == 0) = 1;
Q = Q * diag(sign_diag);

end

function Q = coupled_factor(n)

Q = eye(n);
for i = 1:(n - 1)
    Q(i, i + 1) = 0.35;
    Q(i + 1, i) = -0.25;
end

end

function print_summary(results, problems, variants)

fprintf('\nBest-variant counts by final objective value:\n');
print_best_counts(results, variants);

fprintf('\nPair summaries.  Negative median_log10_ratio means the first variant is better.\n');
print_pair_summary(results, 'full', 'pattern_momentum');
print_pair_summary(results, 'memory_only', 'all_off');
print_pair_summary(results, 'full', 'all_off');
print_pair_summary(results, 'pattern_momentum', 'all_off');

fprintf('\nFull vs no-memory by problem:\n');
for ip = 1:numel(problems)
    subset = results(strcmp(results.problem, problems{ip}), :);
    print_pair_summary(subset, 'full', 'pattern_momentum');
end

fprintf('\nMedian funcCount by variant:\n');
for iv = 1:numel(variants)
    name = variants(iv).name;
    mask = strcmp(results.variant, name);
    fprintf('  %-16s median_nf=%7.1f median_f=% .3e\n', ...
        name, median(results.funcCount(mask)), median(results.final_f(mask)));
end

end

function print_best_counts(results, variants)

case_keys = make_case_keys(results);
unique_keys = unique(case_keys, 'stable');
counts = zeros(numel(variants), 1);

for ik = 1:numel(unique_keys)
    mask_case = strcmp(case_keys, unique_keys{ik});
    fvals = results.final_f(mask_case);
    names = results.variant(mask_case);
    best_f = min(fvals);
    best = find(fvals <= best_f + 1e-12 * max(1, abs(best_f)));
    for ib = 1:numel(best)
        idx = find(strcmp({variants.name}, names{best(ib)}), 1);
        counts(idx) = counts(idx) + 1 / numel(best);
    end
end

for iv = 1:numel(variants)
    fprintf('  %-16s %6.1f / %d\n', variants(iv).name, counts(iv), numel(unique_keys));
end

end

function print_pair_summary(results, first, second)

case_keys = make_case_keys(results);
unique_keys = unique(case_keys, 'stable');
ratios = nan(numel(unique_keys), 1);
wins = 0;
ties = 0;
losses = 0;

for ik = 1:numel(unique_keys)
    mask_case = strcmp(case_keys, unique_keys{ik});
    f1 = results.final_f(mask_case & strcmp(results.variant, first));
    f2 = results.final_f(mask_case & strcmp(results.variant, second));
    if isempty(f1) || isempty(f2)
        continue;
    end
    f1s = score_value(f1(1));
    f2s = score_value(f2(1));
    ratios(ik) = log10(f1s / f2s);
    tol = 1e-12 * max([1, abs(f1s), abs(f2s)]);
    if f1s < f2s - tol
        wins = wins + 1;
    elseif f1s > f2s + tol
        losses = losses + 1;
    else
        ties = ties + 1;
    end
end

ratios = ratios(~isnan(ratios));
fprintf('  %-16s vs %-16s wins=%2d ties=%2d losses=%2d median_log10_ratio=% .3f mean_log10_ratio=% .3f\n', ...
    first, second, wins, ties, losses, median(ratios), mean(ratios));

end

function value = score_value(f)

if isnan(f)
    value = inf;
elseif f <= 0
    value = realmin;
else
    value = f;
end

end

function keys = make_case_keys(results)

keys = cell(height(results), 1);
for i = 1:height(results)
    keys{i} = sprintf('%s|%d|%d', results.problem{i}, results.n(i), results.seed(i));
end

end
