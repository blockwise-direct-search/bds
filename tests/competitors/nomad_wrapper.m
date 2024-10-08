function nomad_wrapper(fun, x0, options)
%A wrapper for NOMAD.
%

% Dimension
n = numel(x0);

% Set the default bounds.
lb = -inf(1, n);
ub = inf(1, n);

% Set MAXFUN to the maximum number of function evaluations.
if isfield(options, "MaxFunctionEvaluations")
    MaxFunctionEvaluations = options.MaxFunctionEvaluations;
else
    MaxFunctionEvaluations = get_default_constant("MaxFunctionEvaluations_dim_factor")*n;
end

options.solver = "nomad";

params = struct('MAX_BB_EVAL', num2str(MaxFunctionEvaluations), 'max_eval',num2str(MaxFunctionEvaluations));

nomadOpt(fun, x0, lb, ub, params);

end