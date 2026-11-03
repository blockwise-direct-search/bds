function verify_poll_failure_disabled()
%VERIFY_POLL_FAILURE_DISABLED Check instrumentation when gradient stopping is off.

root = getenv('BDS_GRADIENT_ROOT');
addpath(fullfile(root, 'candidate', 'src'), fullfile(root, 'candidate', 'examples'), ...
    fullfile(root, 'experiment'), fullfile(root, 'control'));
configs = gradient_experiment_config();
cases = 0;
for n = [2, 5, 10]
    for seed = [20260828, 20261031]
        rng(seed, 'twister');
        matrix = randn(n);
        fun = @(x) sum((matrix * (x - ones(n, 1))).^2);
        x0 = (1:n)';
        for acceleration = [false, true]
            for function_stop = [false, true]
                options = bds_paper_options(x0, 'external', 'mp');
                options.seed = seed;
                options.use_iteration_pattern_step = acceleration;
                options.use_momentum_extrapolation = acceleration;
                options.use_function_value_stop = function_stop;
                options.use_estimated_gradient_stop = false;
                rng(seed, 'twister');
                [x, f, flag, output] = bds(fun, x0, options);
                for count = [1, 2, 3, 5, 8]
                    config = configs(1);
                    config.minimum_failures = count;
                    config.observe = @(varargin) [];
                    rng(seed, 'twister');
                    [actual_x, actual_f, actual_flag, actual_output] = ...
                        gradient_experiment_bds(fun, x0, options, config);
                    assert(isequaln(x, actual_x) && isequaln(f, actual_f));
                    assert(flag == actual_flag && isequaln(output, actual_output));
                    cases = cases + 1;
                end
            end
        end
    end
end
assert(cases == 120);
fid = fopen(fullfile(root, 'COUNTER_OFF_ACCEPTED.json'), 'w');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', jsonencode(struct('status', 'accepted', 'cases', cases, ...
    'acceleration_on_and_off', true, 'function_stop_on_and_off', true)));
fprintf('POLL_FAILURE_COUNTER_OFF_OK cases=%d\n', cases);

end
