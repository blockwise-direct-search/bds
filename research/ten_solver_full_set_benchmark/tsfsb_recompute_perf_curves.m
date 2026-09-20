function mean_curves = tsfsb_recompute_perf_curves(results_plib, tolerance)
%TSFSB_RECOMPUTE_PERF_CURVES Recompute history-based performance curves.
%
%   New for TSFSB. Replicates the OptiProfiler computation of the mean
%   history-based performance profile curves from saved results
%   (processResults.m, the threshold loop in benchmark.m, and
%   getPerformanceDataProfileAxes.m, frozen fdf2c550) so that subset
%   profiling can prove that the Moré-Wild targets were recomputed from
%   the loaded solver subset. The semilogx transform is fixed to true,
%   matching tsfsb_direct_profile_options.

merit_histories = results_plib.merit_histories;
merit_inits = results_plib.merit_inits;
[n_problems, n_solvers, n_runs, ~] = size(merit_histories);

% processResults.m: least merit value for each problem in each run,
% including the initial value.
merit_mins = min(min(merit_histories, [], 4, 'omitnan'), [], 2, 'omitnan');
for i_problem = 1:n_problems
    for i_run = 1:n_runs
        merit_mins(i_problem, i_run) = min( ...
            merit_mins(i_problem, i_run), ...
            merit_inits(i_problem, i_run), 'omitnan');
    end
end

% benchmark.m: Moré-Wild convergence thresholds and first-passage work.
work = NaN(n_problems, n_solvers, n_runs);
for i_problem = 1:n_problems
    for i_run = 1:n_runs
        if isinf(merit_inits(i_problem, i_run))
            threshold = Inf;
        elseif isfinite(merit_mins(i_problem, i_run))
            threshold = max( ...
                tolerance * merit_inits(i_problem, i_run) ...
                + (1 - tolerance) * merit_mins(i_problem, i_run), ...
                merit_mins(i_problem, i_run));
        else
            threshold = -Inf;
        end
        for i_solver = 1:n_solvers
            history = merit_histories(i_problem, i_solver, i_run, :);
            if min(history, [], 'omitnan') <= threshold
                work(i_problem, i_solver, i_run) = ...
                    find(history <= threshold, 1, 'first');
            end
        end
    end
end

% getPerformanceDataProfileAxes.m with the performance denominator.
x = NaN(n_solvers, n_problems, n_runs);
for i_run = 1:n_runs
    for i_problem = 1:n_problems
        denominator = min(work(i_problem, :, i_run), [], 'omitnan');
        x(:, i_problem, i_run) = work(i_problem, :, i_run) / denominator;
    end
end
if all(isnan(x(:)))
    ratio_max = eps;
else
    ratio_max = max(x(:), [], 'omitnan');
end
x(isnan(x)) = Inf;
x = sort(x, 2);
x = reshape(x, [n_solvers, n_problems * n_runs]);
x = x';
[x, index_sort_x] = sort(x, 1);
index_ratio_max = NaN(n_solvers, 1);
for i_solver = 1:n_solvers
    if ~isempty(find(x(:, i_solver) <= ratio_max, 1, 'last'))
        index_ratio_max(i_solver) = ...
            find(x(:, i_solver) <= ratio_max, 1, 'last');
    end
end
y = NaN(n_problems * n_runs, n_solvers, n_runs);
for i_solver = 1:n_solvers
    for i_run = 1:n_runs
        y((i_run - 1) * n_problems + 1:i_run * n_problems, ...
            i_solver, i_run) = linspace(1 / n_problems, 1.0, n_problems);
        y_partial = y(:, i_solver, i_run);
        y(:, i_solver, i_run) = y_partial(index_sort_x(:, i_solver));
        for i_problem = 1:n_problems * n_runs
            if isnan(y(i_problem, i_solver, i_run))
                if i_problem > 1
                    y(i_problem, i_solver, i_run) = ...
                        y(i_problem - 1, i_solver, i_run);
                else
                    y(i_problem, i_solver, i_run) = 0;
                end
            end
        end
    end
end
ratio_max_y = zeros(n_solvers, n_runs);
for i_solver = 1:n_solvers
    for i_run = 1:n_runs
        if ~isnan(index_ratio_max(i_solver))
            ratio_max_y(i_solver, i_run) = ...
                y(index_ratio_max(i_solver), i_solver, i_run);
        end
    end
end
for i_solver = 1:n_solvers
    for i_run = 1:n_runs
        y(:, i_solver, i_run) = ...
            min(y(:, i_solver, i_run), ratio_max_y(i_solver, i_run));
    end
end

% getExtendedPerformancesDataProfileAxes.m with semilogx true.
x_perf = x;
y_perf = y;
x_perf(isfinite(x_perf)) = log2(x_perf(isfinite(x_perf)));
if ratio_max > eps
    ratio_max = max(log2(ratio_max), eps);
end
x_perf(isinf(x_perf)) = 1.1 * ratio_max;
x_perf = [zeros(1, n_solvers); x_perf];
y_perf = [zeros(1, n_solvers, n_runs); y_perf];
if n_problems > 0
    x_perf = [x_perf; ones(1, n_solvers) * ratio_max * 1.1];
    y_perf = [y_perf; y_perf(end, :, :)];
end

mean_curves = cell(1, n_solvers);
for i_solver = 1:n_solvers
    y_mean = squeeze(mean(y_perf(:, i_solver, :), 3));
    mean_curves{i_solver} = [x_perf(:, i_solver)'; y_mean'];
end

end
