function prima_wrapper(fun, x0, options)
%A wrapper for PRIMA.
%

% Tell MATLAB where to find PRIMA.
locate_prima();

% Dimension
n = numel(x0);

if isfield(options, "default") && options.default

    Algorithm = "newuoa";
    solver = str2func(Algorithm);
    solver(fun, x0);

else

    if isfield(options, "StepTolerance")
        options.rhoend = options.StepTolerance;
    else
        options.rhoend = get_default_constant("StepTolerance");
    end

    if isfield(options, "alpha_init")
        options.rhobeg = options.alpha_init;
    else
        options.rhobeg = get_default_constant("alpha_init");
    end
    % An indicator: it can attain 0, 1, 2, 3, -1, -2, -3. Default value is
    % 0. More absolute value of iprint, more information will be printed on command
    % window. When the value of iprint is negative, no information will be
    % printed on command window and will be stored in a file.
    % options.iprint = 0;
    options.iprint = 0;

    % Set MAXFUN to the maximum number of function evaluations.
    if isfield(options, "MaxFunctionEvaluations")
        MaxFunctionEvaluations = options.MaxFunctionEvaluations;
    else
        MaxFunctionEvaluations = get_default_constant("MaxFunctionEvaluations_dim_factor")*n;
    end

    options.maxfun = MaxFunctionEvaluations;

    if isfield(options, "Algorithm")
        Algorithm = options.Algorithm;
        options = rmfield(options, "Algorithm");
    else
        Algorithm = "newuoa";
    end
    solver = str2func(Algorithm);
    if isfield(options, "solver")
        options = rmfield(options, "solver");
    end
    solver(fun, x0, options);

end

end

