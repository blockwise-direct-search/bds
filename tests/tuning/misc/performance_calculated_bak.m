function [performance_tuning, performance_benchmark, performance_diff] = performance_calculated_bak(perf_prof)
% This function integrates one curve to calculate the performance of the solver.

ns = perf_prof.ns;
cut_ratio = perf_prof.cut_ratio;
curves = perf_prof.curves;

performance = zeros(ns, 1);
% Here, we set the first solver as the one that being tested and the
% second solver is the default one. Then we calculate the relative
% performance for the first solver. Since the stair function is right continuous,
% when we calculate the performance, we need to multiply the height of the
% left point by the length of the stair.
for is = 1 : ns
    num_valid_points = sum(curves{is}(1, :) <= cut_ratio);
    curves{is}(1, num_valid_points + 1) = cut_ratio;
    for i = 2 : num_valid_points + 1
        performance(is) = performance(is) + (curves{is}(1, i) - curves{is}(1, i-1))...
            *curves{is}(2, i-1);
    end
end

% Scale the performance. Here we scale the performance by dividing the the value
% of the default solver at the last point. Since the solver that we use is
% to minimize, here we use performance(2) - performance(1). Since the
% performance_diff is in the range of [-1, 1], we use the following formula.
performance_tuning = performance(1)/cut_ratio;
performance_benchmark = performance(2)/cut_ratio;
performance_diff = max(-1, min(1, (performance(1) - performance(2)) / cut_ratio));

end

