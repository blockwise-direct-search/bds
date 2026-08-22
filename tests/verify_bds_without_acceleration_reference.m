function verify_bds_without_acceleration_reference()
%VERIFY_BDS_WITHOUT_ACCELERATION_REFERENCE Check the frozen BDS oracle.
%
% The reference is a snapshot of the production BDS implementation immediately
% before acceleration was promoted to src/bds.m. This check must pass before
% src/bds.m is replaced.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
old_path = path();
cleanup = onCleanup(@() path(old_path));

addpath(fullfile(root_dir, 'src'));
addpath(fullfile(tests_dir, 'competitors'));

algorithms = ["cbds", "pbds", "rbds", "pads", "ds"];
seeds = [12345, 23456];
x0 = [1; -0.5; 2];

for algorithm = algorithms
    for seed = seeds
        options = struct();
        options.Algorithm = char(algorithm);
        options.MaxFunctionEvaluations = 60;
        options.expand = 1.8;
        options.seed = seed;
        options.output_xhist = true;
        options.output_alpha_hist = true;
        options.output_block_hist = true;
        options.output_grad_hist = true;
        options.use_function_value_stop = true;
        options.func_window_size = 4;
        options.func_tol = 1e-12;
        options.use_estimated_gradient_stop = true;
        options.grad_window_size = 2;
        options.grad_tol = 1e-12;

        production_options = disable_acceleration(options);
        production = run_solver(@bds, x0, production_options);
        reference = run_solver(@bds_without_acceleration_reference, x0, options);

        assert(isequaln(production, reference), ...
            'Frozen BDS reference differs for Algorithm=%s, seed=%d.', ...
            algorithm, seed);
    end
end

% Exercise every shared default while overriding only the deliberately changed
% expansion factor and acceleration switches in production BDS.
default_production_options = disable_acceleration( ...
    struct('seed', 24680, 'expand', 1.8));
default_production = run_solver(@bds, x0, default_production_options);
default_reference = run_solver( ...
    @bds_without_acceleration_reference, x0, struct('seed', 24680));
assert(isequaln(default_production, default_reference), ...
    'Frozen BDS reference differs under default options.');

fprintf('BDS_WITHOUT_ACCELERATION_REFERENCE_OK\n');
clear cleanup

end

function options = disable_acceleration(options)

options.use_productive_direction_memory = false;
options.use_iteration_pattern_step = false;
options.use_momentum_extrapolation = false;

end

function result = run_solver(solver, x0, options)

[result.xopt, result.fopt, result.exitflag, result.output] = ...
    solver(@objective, x0, options);

end

function f = objective(x)

x = x(:);
target = [0.25; -1; 0.75];
A = diag([1, 2, 4]) + 0.1 * ones(3);
f = sum((A * (x - target)).^2) + 0.01 * sum(sin(x));

end
