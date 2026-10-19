function options = bds_paper_options(x0, experiment, configuration)
%BDS_PAPER_OPTIONS Explicit BDS-family settings of the accepted C06/C04 experiments.
%
%   OPTIONS = BDS_PAPER_OPTIONS(X0, EXPERIMENT, CONFIGURATION) returns options
%   for the production solver BDS, not a benchmark driver. These settings do
%   not depend on the software defaults or on a solver display name.
%
%   x0                                 Initial point; its length determines the budget.
%   experiment                         'internal' (C06) or 'external' (C04).
%   configuration                      'mp', 'noacc', or 'ds' for internal comparisons;
%                                      only 'mp' for the external BDS configuration.
%   options                            Explicit solver options. Internal comparisons use
%                                      unit block steps and no optional stopping. External
%                                      comparisons use automatic steps and both stops.
%
%   Example:
%       x0 = [-1.2; 1];
%       options = bds_paper_options(x0, 'internal', 'mp');
%       [xopt, fopt, exitflag, output] = bds(@(x) sum(x.^2), x0, options);
%
%   Problem selection, features, random realizations, and dependency versions
%   are separate benchmark inputs; see docs/PAPER_REPRODUCTION.md. This entry
%   does not rerun or replace the accepted experiments.

if ~ismember(experiment, {'internal', 'external'}) ...
        || ~ismember(configuration, {'mp', 'noacc', 'ds'}) ...
        || (strcmp(experiment, 'external') && ~strcmp(configuration, 'mp'))
    error('bds_paper_options:UnknownConfiguration', ...
        'Use internal mp/noacc/ds or external mp.');
end

n = numel(x0);
options = struct();
options.Algorithm = 'cbds';
options.alpha_init = 'auto';
options.MaxFunctionEvaluations = 500*n;
options.StepTolerance = 1e-6;
options.ftarget = -Inf;
options.expand = 2;
options.shrink = 0.5;
options.is_noisy = false;
options.forcing_function = @(alpha) alpha^2;
options.reduction_factor = [0, eps, eps];
options.polling_inner = 'opportunistic';
options.cycling_inner = 1;
options.use_productive_direction_memory = false;
options.use_iteration_pattern_step = strcmp(configuration, 'mp');
options.use_momentum_extrapolation = strcmp(configuration, 'mp');
options.productive_direction_memory_size = max(1, min(n, 5));
options.momentum_decay = 0.6;
options.use_function_value_stop = true;
options.func_window_size = 20;
options.func_tol = 1e-6;
options.use_estimated_gradient_stop = true;
options.grad_window_size = 1;
options.grad_tol = 1e-2;
options.lipschitz_constant = 1e3;
options.use_gradient_reference_consistency = true;
options.grad_reference_finite_difference_error_tol = 1/30;
options.seed = 20260828;
options.output_xhist = false;
options.output_alpha_hist = false;
options.output_block_hist = false;
options.output_grad_hist = false;
options.iprint = 0;
options.debug_flag = false;

if strcmp(experiment, 'internal')
    options.alpha_init = 1;
    options.use_function_value_stop = false;
    options.use_estimated_gradient_stop = false;
end
if strcmp(configuration, 'ds')
    options.Algorithm = 'ds';
end

end
