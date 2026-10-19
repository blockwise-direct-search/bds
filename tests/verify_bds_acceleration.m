function verify_bds_acceleration()
%VERIFY_BDS_ACCELERATION Strict checks for the production BDS accelerations.
%
% All five non-accelerated algorithms retain their frozen-reference checks.
% The former lean/PM all-on comparison is preserved as a historical test in
% tests/archive/legacy_pm/verify_bds_acceleration_pm.m. It is not an MP oracle.
% Run verify_bds_mp_reference separately with the frozen MP on the path.

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

fprintf('\nProduction BDS acceleration verification passed.\n');
fprintf(['  off: bds.m == bds_without_acceleration_reference.m for ', ...
    'Algorithm=cbds/pbds/rbds/pads/ds, with matching explicit options.\n']);
fprintf('  MP-on: separate frozen-reference verification is required.\n');

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
options.noninteractive = true;

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
