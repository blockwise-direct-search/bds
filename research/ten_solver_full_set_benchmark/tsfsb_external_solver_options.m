function options = tsfsb_external_solver_options(x0, solver, noise_level)
%TSFSB_EXTERNAL_SOLVER_OPTIONS Fixed external-solver options for TSFSB.
%
%   Ported from the C02 c02_external_solver_options.m (commit 846d5c5f)
%   for 'nomad', 'lam', 'newuoa', and 'fd-bfgs' verbatim, extended with
%   'pds', 'bfo', and 'nelder-mead'.
%
%   'pds': only MaxFunctionEvaluations, expand, and shrink are set. Every
%   other option is left to the defaults of tests/competitors/pds.m, which
%   were verified by reading pds.m and get_default_constant.m:
%   StepTolerance 1e-6, ftarget -Inf, quadratic forcing function
%   @(alpha) alpha^2, polling_inner 'opportunistic', cycling_inner 1,
%   alpha_init 1. The per-problem deterministic seed is added by the
%   solver handle (tsfsb_solver_handles) through options.seed.
%
%   'bfo': mapped by bfo_wrapper to 'epsilon' (StepTolerance) and
%   'maxeval' (MaxFunctionEvaluations) with 'verbosity' 'silent'.
%
%   'nelder-mead': option names match tests/competitors/fminsearch_wrapper.m
%   exactly; the wrapper maps MaxFunctionEvaluations to MaxFunEvals and
%   StepTolerance to TolX, and always sets MaxIter 1e20 and TolFun eps.

n = numel(x0);
if n < 1
    error('tsfsb_external_solver_options:InvalidInitialPoint', ...
        'x0 must be nonempty.');
end
solver = char(lower(string(solver)));

switch solver
    case 'nomad'
        options = struct('MaxFunctionEvaluations', 500 * n);
    case 'lam'
        options = struct( ...
            'MaxFunctionEvaluations', 500 * n, ...
            'StepTolerance', 1e-5, ...
            'MaxIterations', Inf, ...
            'ftarget', -Inf);
    case 'newuoa'
        options = struct( ...
            'Algorithm', 'newuoa', ...
            'MaxFunctionEvaluations', 500 * n, ...
            'StepTolerance', 1e-6, ...
            'alpha_init', 1);
    case 'fd-bfgs'
        options = struct( ...
            'MaxObjectiveEvaluations', 500 * n, ...
            'StepTolerance', 1e-6, ...
            'ftarget', -Inf, ...
            'with_gradient', nargin >= 3 && ~isempty(noise_level));
        if options.with_gradient
            validateattributes(noise_level, {'numeric'}, ...
                {'scalar', 'real', 'finite', 'positive'});
            options.noise_level = double(noise_level);
        end
    case 'pds'
        options = struct( ...
            'MaxFunctionEvaluations', 500 * n, ...
            'expand', 2, ...
            'shrink', 0.5);
    case 'bfo'
        options = struct( ...
            'StepTolerance', 1e-6, ...
            'MaxFunctionEvaluations', 500 * n);
    case 'nelder-mead'
        % fminsearch_wrapper maps these to optimset('MaxFunEvals', ...,
        % 'MaxIter', 1e20, 'TolFun', eps, 'TolX', StepTolerance).
        options = struct( ...
            'MaxFunctionEvaluations', 500 * n, ...
            'StepTolerance', 1e-6);
    otherwise
        error('tsfsb_external_solver_options:InvalidSolver', ...
            'Unknown TSFSB external solver ''%s''.', solver);
end

end
