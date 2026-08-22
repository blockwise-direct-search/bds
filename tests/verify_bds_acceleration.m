function verify_bds_acceleration()
%VERIFY_BDS_ACCELERATION Strict checks for the production BDS accelerations.
%
% This verification has two acceptance targets:
%
%   1. With all acceleration switches off, bds.m must match the frozen
%      pre-acceleration BDS reference for the same Algorithm and explicit
%      options.
%   2. With all acceleration switches on and the default/CBDS base algorithm,
%      bds.m must match the independent lean_evolved_bds.m reference.

path_tests = fileparts(mfilename('fullpath'));
path_root = fileparts(path_tests);
oldpath = path();
oldfolder = pwd();
cleanup = onCleanup(@() restore_state(oldpath, oldfolder));

addpath(fullfile(path_tests, 'competitors'));
addpath(fullfile(path_root, 'src'));
cd(path_tests);

fprintf('\nRunning production BDS acceleration verification...\n');

verify_acceleration_off_matches_reference(oldfolder);
verify_acceleration_on_matches_lean(oldfolder, false);
verify_acceleration_on_matches_lean(oldfolder, true);

fprintf('\nProduction BDS acceleration verification passed.\n');
fprintf(['  off: bds.m == bds_without_acceleration_reference.m for ', ...
    'Algorithm=cbds/pbds/rbds/pads/ds, with matching explicit options.\n']);
fprintf('  on : bds.m == lean_evolved_bds.m for default and Algorithm=cbds.\n');

end

function verify_acceleration_off_matches_reference(oldfolder)

dims = 1:5;
ir_values = 0:17;
seed_values = [12345, 23456, 34567];
algorithms = ["cbds", "pbds", "rbds", "pads", "ds"];

for algorithm = algorithms
    label = sprintf('acceleration-off-Algorithm-%s', algorithm);
    options = base_iseqiv_options(oldfolder);
    options.Algorithm = char(algorithm);
    run_iseqiv_suite(label, ...
        {@run_frozen_bds_reference, @run_production_bds_no_acceleration}, ...
        dims, ir_values, seed_values, options);
end

end

function verify_acceleration_on_matches_lean(oldfolder, use_algorithm_cbds)

dims = 1:10;
ir_values = 0:20;
seed_values = [12345, 23456, 34567];
options = base_iseqiv_options(oldfolder);

if use_algorithm_cbds
    label = 'acceleration-on-Algorithm-cbds-vs-lean';
    production_solver = @(fun, x0, solver_options) ...
        run_production_bds_lean(fun, x0, solver_options, true);
else
    label = 'acceleration-on-default-vs-lean';
    production_solver = @(fun, x0, solver_options) ...
        run_production_bds_lean(fun, x0, solver_options, false);
end

run_iseqiv_suite(label, {@run_lean_reference, production_solver}, ...
    dims, ir_values, seed_values, options);

end

function run_iseqiv_suite(label, solvers, dims, ir_values, seed_values, base_options)

prec = 0;
single_test = true;
num_cases = numel(dims) * numel(ir_values) * numel(seed_values);
case_count = 0;

fprintf('\nRunning %s iseqiv suite (%d cases)...\n', label, num_cases);
for seed = seed_values
    for n = dims
        p = toy_problem(n, label);
        for ir = ir_values
            case_count = case_count + 1;
            options = base_options;
            options.seed = seed;

            ok = iseqiv(solvers, p, ir, single_test, prec, options);
            if ~ok
                error('verify_bds_acceleration:IseqivFailure', ...
                    '%s failed for n=%d, ir=%d, seed=%d.', ...
                    label, n, ir, seed);
            end

            fprintf('[%s] case %03d/%03d passed: n=%d, ir=%d, seed=%d\n', ...
                label, case_count, num_cases, n, ir, seed);
        end
    end
end

fprintf('%s suite passed.\n', label);

end

function options = base_iseqiv_options(oldfolder)

options = struct();
options.olddir = oldfolder;
options.sequential = false;

end

function [xopt, fopt, exitflag, output] = run_frozen_bds_reference(fun, x0, options)

if ~isfield(options, 'expand')
    options.expand = 1.8;
end
[xopt, fopt, exitflag, output] = ...
    bds_without_acceleration_reference(fun, x0, options);

end

function [xopt, fopt, exitflag, output] = run_production_bds_no_acceleration(fun, x0, options)

options.use_productive_direction_memory = false;
options.use_iteration_pattern_step = false;
options.use_momentum_extrapolation = false;

% Production BDS uses expand=2.0, whereas the frozen non-accelerated reference
% uses 1.8. The all-off comparison fixes the historical reference value because
% it checks the acceleration mechanism rather than the separately chosen public
% default.
if ~isfield(options, 'expand')
    options.expand = 1.8;
end

[xopt, fopt, exitflag, output] = bds(fun, x0, options);

end

function [xopt, fopt, exitflag, output] = run_lean_reference(fun, x0, ~)

[xopt, fopt, exitflag, output] = lean_evolved_bds(@safe_fun, x0);
output = lean_algorithmic_output(output);

    function f = safe_fun(x)
        f = algorithmic_eval(fun, x);
    end

end

function [xopt, fopt, exitflag, output] = run_production_bds_lean( ...
        fun, x0, ~, use_algorithm_cbds)

production_options = struct();
if use_algorithm_cbds
    production_options.Algorithm = 'cbds';
end
production_options.use_productive_direction_memory = true;
production_options.use_iteration_pattern_step = true;
production_options.use_momentum_extrapolation = true;

% Keep the row-input/tough behavior used by the fixed reference comparison:
% force the solver's internal input to a column without wrapping the objective.
x0 = double(x0(:));
[xopt, fopt, exitflag, output] = bds(fun, x0, production_options);
output = lean_algorithmic_output(output);

end

function output = lean_algorithmic_output(raw_output)

output.funcCount = raw_output.funcCount;

end

function f = algorithmic_eval(fun, x)

try
    f = fun(x);
catch
    f = nan;
end
if isnan(f)
    f = inf;
end

end

function p = toy_problem(n, label)

p.name = sprintf('%s-n%d', upper(regexprep(label, '[^A-Za-z0-9]', '')), n);
p.x0 = (1:n)' / 3;
p.objective = @(x) toy_objective(x);

    function f = toy_objective(x)
        x = x(:);
        target = ((-1).^(1:n))' .* (1:n)' / 5;
        A = diag(1:n) + 0.1 * ones(n);
        f = sum((A * (x - target)).^2) + 0.01 * sum(sin(x));
    end

end

function restore_state(oldpath, oldfolder)

path(oldpath);
cd(oldfolder);

end
