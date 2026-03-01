function performance_return = hp_handle(hyperparameters_value, parameters)
% perfprof_handle - Function handle for calculating the value of the
% performance profile


    parameters.solvers_options{1}.expand = hyperparameters_value(1);
    parameters.solvers_options{1}.shrink = hyperparameters_value(2);

    
    for i = 1:length(parameters.solvers_name)
        parameters.solvers_options{i}.solver = parameters.solvers_name(i);
    end

    [~, frec, fmin] = profile(parameters);
    options_perf.natural_stop = false;
    num_tau = length(parameters.tau);
    multi_performance = NaN(num_tau, 1);
    for i = 1 : num_tau
        options_perf.tau = parameters.tau(i);
        multi_performance(i) = performance_calculated(frec, fmin, options_perf);
    end
    
    %performance_return = mean(multi_performance);
    performance_return = mean(((1-1e-1) / (num_tau - 1) * sum(multi_performance(1:end-1))) + 1e-1*multi_performance(end));

end


