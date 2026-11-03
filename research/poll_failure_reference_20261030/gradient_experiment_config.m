function configs = gradient_experiment_config()
%GRADIENT_EXPERIMENT_CONFIG Predeclared gradient-only candidates and ablations.

base = struct('rule', 'new', 'lipschitz', 1e3, 'tolerance', 1e-2, ...
    'beta', 1e-3, 'window', 1, 'reference_absolute', 1e-3, ...
    'reference_fraction', 1/11, 'minimum_failures', 1);
configs = repmat(base, 1, 0);
for minimum_failures = [1, 2, 3, 5, 8]
    for lipschitz = [10, 100, 1000, 10000, 100000]
        for tolerance = [1e-5, 1e-4, 1e-3, 1e-2, 3e-2]
            for beta = [1e-3, 1e-2, 1e-1]
                for window = [1, 2]
                    item = base;
                    item.minimum_failures = minimum_failures;
                    item.lipschitz = lipschitz;
                    item.tolerance = tolerance;
                    item.beta = beta;
                    item.window = window;
                    configs(end+1) = item;
                end
            end
        end
    end
end
for rule = {'legacy', 'threshold_only'}
    item = base;
    item.rule = rule{1};
    configs(end+1) = item;
end

end
