function [perf, perf_prof_saved] = eval_performance(solver, competitor, options)

    % perf = rand();
    % return

    parameters = struct();

    parameters.tuning = true;
    parameters.parallel = false;
    parameters.problem_mindim = options.mindim;
    parameters.problem_maxdim = options.maxdim;
    parameters.num_random = options.num_random;
    parameters.test_type = options.test_type;
    parameters.feature = options.feature;
    parameters.tau_indices = options.tau_indices;

    parameters.solvers_name = [solver, competitor];
    parameters.solvers_options{1} = options.solver_options;
    parameters.solvers_options{1}.solver = solver;
    parameters.solvers_options{2}.solver = competitor;

    perf_prof_saved = cell(10, 1);

    addpath(fileparts(fileparts(fileparts(mfilename('fullpath')))));
    tic;
    [~, frec, fmin] = profile(parameters);
    toc;
    perf_options = struct();
    perf_options.natural_stop = false;
    performances= NaN(10, 1);

    for i = 1 : 10

        perf_options.tau = 10^(-i);
        perf_prof_saved{i}.tau = perf_options.tau;
        perf_prof_saved{i}.solver_options = options.solver_options;
        perf_prof = performance_value(frec, fmin, perf_options);

        num_valid_points = sum(perf_prof.curves{1}(1, :) <= perf_prof.cut_ratio);
        perf_prof.curves{1}(1, num_valid_points + 1) = perf_prof.cut_ratio;
        curve_solver = perf_prof.curves{1}(:, 1:num_valid_points + 1);
        performance_solver = integrate(curve_solver, options.plot_weights) / perf_prof.cut_ratio;

        num_valid_points = sum(perf_prof.curves{2}(1, :) <= perf_prof.cut_ratio);
        perf_prof.curves{2}(1, num_valid_points + 1) = perf_prof.cut_ratio;
        curve_competitor = perf_prof.curves{2}(:, 1:num_valid_points + 1);
        performance_competitor = integrate(curve_competitor, options.plot_weights) / perf_prof.cut_ratio;

        perf_prof_saved{i}.perf_prof = perf_prof;
        perf_prof_saved{i}.performance_solver = performance_solver;
        perf_prof_saved{i}.performance_competitor = performance_competitor;
        perf_prof_saved{i}.performance_diff = performance_solver - performance_competitor;

        performances(i) = perf_prof_saved{i}.performance_diff;

    end
    
    perf = sum(performances(options.tau_indices)'.*options.tau_weights);
    
end

