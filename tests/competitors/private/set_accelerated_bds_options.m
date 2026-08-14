function options = set_accelerated_bds_options(options, n, x0)
% SET_ACCELERATED_BDS_OPTIONS Set and validate options for accelerated_bds_options.
%
%   OPTIONS = SET_ACCELERATED_BDS_OPTIONS(OPTIONS, N, X0) validates the values
%   in OPTIONS, resolves the priority of Algorithm, and sets the missing values.

% We handle Algorithm early because it determines the values of num_blocks,
% batch_size, and block_visiting_pattern.
if isfield(options, 'Algorithm') && ~isempty(options.Algorithm)
    algorithm = options.Algorithm;
    if ~(ischarstr(algorithm) ...
            && any(ismember(lower(string(algorithm)), ["cbds", "pbds", "pads", "rbds", "ds"])))
        error('accelerated_bds_options:InvalidAlgorithm', ...
            'options.Algorithm must be one of: cbds, pbds, pads, rbds, ds.');
    end
    algorithm = char(lower(string(algorithm)));

    fields_conflicting_with_algorithm = intersect(fieldnames(options), ...
        {'block_visiting_pattern', 'num_blocks', 'batch_size'});
    if ~isempty(fields_conflicting_with_algorithm)
        warning('accelerated_bds_options:AlgorithmPriority', ...
            ['Algorithm and block_visiting_pattern/num_blocks/batch_size are ', ...
            'mutually exclusive. Algorithm will be used.']);
        options = rmfield(options, fields_conflicting_with_algorithm);
    end

    switch algorithm
        case 'cbds'
            options.num_blocks = n;
            options.batch_size = n;
            options.block_visiting_pattern = 'sorted';
        case 'pbds'
            options.num_blocks = n;
            options.batch_size = n;
            options.block_visiting_pattern = 'random';
        case 'rbds'
            options.num_blocks = n;
            options.batch_size = 1;
            options.block_visiting_pattern = 'random';
        case 'ds'
            options.num_blocks = 1;
            options.batch_size = 1;
        case 'pads'
            options.num_blocks = n;
            options.batch_size = n;
            options.block_visiting_pattern = 'parallel';
    end
    options.Algorithm = algorithm;
end

% Set the maximum number of function evaluations.
options = set_default_if_missing(options, 'MaxFunctionEvaluations', ...
    get_accelerated_bds_default_constant("MaxFunctionEvaluations_dim_factor") * n);
if ~(isintegerscalar(options.MaxFunctionEvaluations) && options.MaxFunctionEvaluations > 0)
    error('accelerated_bds_options:InvalidMaxFunctionEvaluations', ...
        'options.MaxFunctionEvaluations must be a positive integer.');
end
options.MaxFunctionEvaluations = double(options.MaxFunctionEvaluations);

% Set the number of blocks and the number of blocks visited in each iteration.
options = set_default_if_missing(options, 'num_blocks', n);
if ~(isintegerscalar(options.num_blocks) && options.num_blocks > 0 && options.num_blocks <= n)
    error('accelerated_bds_options:InvalidNumBlocks', ...
        'options.num_blocks must be a positive integer not exceeding n.');
end
options.num_blocks = double(options.num_blocks);
options = set_default_if_missing(options, 'batch_size', options.num_blocks);
if ~(isintegerscalar(options.batch_size) && options.batch_size > 0)
    error('accelerated_bds_options:InvalidBatchSize', ...
        'options.batch_size must be a positive integer.');
end
if options.batch_size > options.num_blocks || options.batch_size > n
    error('accelerated_bds_options:InvalidBatchSize', ...
        'options.batch_size cannot exceed options.num_blocks or n.');
end
options.batch_size = double(options.batch_size);
options = set_default_if_missing(options, 'replacement_delay', ...
    floor(options.num_blocks / options.batch_size) - 1);
if ~(isintegerscalar(options.replacement_delay) && options.replacement_delay >= 0)
    error('accelerated_bds_options:InvalidReplacementDelay', ...
        'options.replacement_delay must be a nonnegative integer.');
end
if options.replacement_delay > floor(options.num_blocks / options.batch_size) - 1
    error('accelerated_bds_options:InvalidReplacementDelay', ...
        'options.replacement_delay cannot exceed floor(num_blocks / batch_size) - 1.');
end
options.replacement_delay = double(options.replacement_delay);
options = set_default_if_missing(options, 'block_visiting_pattern', ...
    get_accelerated_bds_default_constant("block_visiting_pattern"));
if ~(ischarstr(options.block_visiting_pattern) ...
        && any(ismember(lower(string(options.block_visiting_pattern)), ...
        ["sorted", "random", "parallel"])))
    error('accelerated_bds_options:InvalidBlockVisitingPattern', ...
        'options.block_visiting_pattern must be one of: sorted, random, parallel.');
end
options.block_visiting_pattern = char(lower(string(options.block_visiting_pattern)));
options = set_default_if_missing(options, 'direction_set', eye(n));
if ~(ismatrix(options.direction_set) ...
        && size(options.direction_set, 1) == n && size(options.direction_set, 2) == n)
    error('accelerated_bds_options:InvalidDirectionSet', ...
        'options.direction_set must be an n-by-n matrix.');
end
validate_grouped_direction_indices(options, n, options.num_blocks);

% Set the options related to the termination criteria.
options = set_default_if_missing(options, 'ftarget', get_accelerated_bds_default_constant("ftarget"));
if ~isrealscalar(options.ftarget)
    error('accelerated_bds_options:InvalidFtarget', ...
        'options.ftarget must be a real scalar.');
end
options = set_default_if_missing(options, 'use_function_value_stop', ...
    get_accelerated_bds_default_constant("use_function_value_stop"));
options.use_function_value_stop = normalize_logical_scalar( ...
    options.use_function_value_stop, 'use_function_value_stop');
options = set_default_if_missing(options, 'func_window_size', ...
    get_accelerated_bds_default_constant("func_window_size"));
options.func_window_size = normalize_positive_integer(options.func_window_size, 'func_window_size');
options = set_default_if_missing(options, 'func_tol', get_accelerated_bds_default_constant("func_tol"));
options.func_tol = normalize_positive_real_scalar(options.func_tol, 'func_tol');
options = set_default_if_missing(options, 'use_estimated_gradient_stop', ...
    get_accelerated_bds_default_constant("use_estimated_gradient_stop"));
options.use_estimated_gradient_stop = normalize_logical_scalar( ...
    options.use_estimated_gradient_stop, 'use_estimated_gradient_stop');
options = set_default_if_missing(options, 'grad_window_size', ...
    get_accelerated_bds_default_constant("grad_window_size"));
options.grad_window_size = normalize_positive_integer(options.grad_window_size, 'grad_window_size');
options = set_default_if_missing(options, 'grad_tol', get_accelerated_bds_default_constant("grad_tol"));
options.grad_tol = normalize_positive_real_scalar(options.grad_tol, 'grad_tol');
options = set_default_if_missing(options, 'lipschitz_constant', ...
    get_accelerated_bds_default_constant("lipschitz_constant"));
options.lipschitz_constant = normalize_positive_real_scalar( ...
    options.lipschitz_constant, 'lipschitz_constant');
options = set_default_if_missing(options, 'use_gradient_reference_consistency', ...
    get_accelerated_bds_default_constant("use_gradient_reference_consistency"));
options.use_gradient_reference_consistency = normalize_logical_scalar( ...
    options.use_gradient_reference_consistency, ...
    'use_gradient_reference_consistency');
options = set_default_if_missing(options, ...
    'grad_reference_finite_difference_error_tol', ...
    get_accelerated_bds_default_constant( ...
    "grad_reference_finite_difference_error_tol"));
options.grad_reference_finite_difference_error_tol = ...
    normalize_positive_real_scalar( ...
    options.grad_reference_finite_difference_error_tol, ...
    'grad_reference_finite_difference_error_tol');
options = set_default_if_missing(options, 'grad_reference_relative_tol', ...
    get_accelerated_bds_default_constant("grad_reference_relative_tol"));
options.grad_reference_relative_tol = normalize_positive_real_scalar( ...
    options.grad_reference_relative_tol, 'grad_reference_relative_tol');

% Set the threshold for the step sizes.
options = set_default_if_missing(options, 'StepTolerance', ...
    get_accelerated_bds_default_constant("StepTolerance"));
if isscalar(options.StepTolerance)
    options.StepTolerance = options.StepTolerance * ones(options.num_blocks, 1);
else
    options.StepTolerance = options.StepTolerance(:);
end
if numel(options.StepTolerance) ~= options.num_blocks || any(options.StepTolerance < 0)
    error('accelerated_bds_options:InvalidStepTolerance', ...
        'options.StepTolerance must be a nonnegative scalar or a num_blocks-vector.');
end

% Set the initial step sizes.
options = set_default_if_missing(options, 'alpha_init', ...
    get_accelerated_bds_default_constant("alpha_init"));
options.alpha_init = normalize_alpha_init(options.alpha_init, options.num_blocks, n, x0, options.StepTolerance);

% Set the expanding and shrinking factors.
options = set_default_if_missing(options, 'is_noisy', ...
    get_accelerated_bds_default_constant("is_noisy"));
options.is_noisy = normalize_logical_scalar(options.is_noisy, 'is_noisy');
if options.is_noisy
    options = set_default_if_missing(options, 'expand', ...
        get_accelerated_bds_default_constant("expand_noisy"));
    options = set_default_if_missing(options, 'shrink', ...
        get_accelerated_bds_default_constant("shrink_noisy"));
else
    options = set_default_if_missing(options, 'expand', ...
        get_accelerated_bds_default_constant("expand"));
    options = set_default_if_missing(options, 'shrink', ...
        get_accelerated_bds_default_constant("shrink"));
end
if ~(isrealscalar(options.expand) && options.expand >= 1)
    error('accelerated_bds_options:InvalidExpand', ...
        'options.expand must be a real scalar >= 1.');
end
if ~(isrealscalar(options.shrink) && options.shrink > 0 && options.shrink < 1)
    error('accelerated_bds_options:InvalidShrink', ...
        'options.shrink must be a real scalar in (0, 1).');
end

% Two estimates at the same base point use h and shrink*h. The leading error
% of a central difference is O(h^2), so the consistency threshold should be
% adjusted when the user changes shrink. The default gives 0.1 when shrink=0.5.
options.grad_reference_raw_tol = ...
    options.grad_reference_finite_difference_error_tol ...
    * (1 - options.shrink^2) / options.shrink^2;

% Set the remaining polling and randomization options.
options = set_default_if_missing(options, 'forcing_function', ...
    get_accelerated_bds_default_constant("forcing_function"));
options.forcing_function = normalize_forcing_function(options.forcing_function);
options = set_default_if_missing(options, 'reduction_factor', ...
    get_accelerated_bds_default_constant("reduction_factor"));
if ~(isnumvec(options.reduction_factor) && numel(options.reduction_factor) == 3)
    error('accelerated_bds_options:InvalidReductionFactor', ...
        'options.reduction_factor must be a 3-dimensional real vector.');
end
options.reduction_factor = options.reduction_factor(:)';
if ~(options.reduction_factor(1) <= options.reduction_factor(2) ...
        && options.reduction_factor(2) <= options.reduction_factor(3) ...
        && options.reduction_factor(1) >= 0 ...
        && options.reduction_factor(2) > 0)
    error('accelerated_bds_options:InvalidReductionFactor', ...
        ['options.reduction_factor must satisfy reduction_factor(1) <= ', ...
        'reduction_factor(2) <= reduction_factor(3), reduction_factor(1) >= 0, ', ...
        'and reduction_factor(2) > 0.']);
end
options = set_default_if_missing(options, 'polling_inner', ...
    get_accelerated_bds_default_constant("polling_inner"));
if ~(ischarstr(options.polling_inner) ...
        && any(ismember(lower(string(options.polling_inner)), ["opportunistic", "complete"])))
    error('accelerated_bds_options:InvalidPollingInner', ...
        'options.polling_inner must be one of: opportunistic, complete.');
end
options.polling_inner = char(lower(string(options.polling_inner)));
options = set_default_if_missing(options, 'cycling_inner', ...
    get_accelerated_bds_default_constant("cycling_inner"));
if ~(isintegerscalar(options.cycling_inner) ...
        && options.cycling_inner >= 0 && options.cycling_inner <= 3)
    error('accelerated_bds_options:InvalidCyclingInner', ...
        'options.cycling_inner must be an integer in {0,1,2,3}.');
end
options.cycling_inner = double(options.cycling_inner);
options = set_default_if_missing(options, 'seed', get_accelerated_bds_default_constant("seed"));
if ~(ischarstr(options.seed) && strcmpi(options.seed, 'shuffle'))
    if ~(isintegerscalar(options.seed) && options.seed >= 0 && options.seed <= 2^32 - 1)
        error('accelerated_bds_options:InvalidSeed', ...
            'options.seed must be an integer in [0, 2^32 - 1] or "shuffle".');
    end
    options.seed = double(options.seed);
end

% Set the output and debugging options.
options = set_default_if_missing(options, 'output_xhist', ...
    get_accelerated_bds_default_constant("output_xhist"));
options.output_xhist = normalize_logical_scalar(options.output_xhist, 'output_xhist');
if options.output_xhist
    try
        xhist_allocation_test = nan(n, options.MaxFunctionEvaluations);
        clear xhist_allocation_test
    catch
        options.output_xhist = false;
        warning('accelerated_bds_options:XhistMemory', ...
            'xhist will not be included in the output due to the limit of memory.');
    end
end
options = set_default_if_missing(options, 'output_alpha_hist', ...
    get_accelerated_bds_default_constant("output_alpha_hist"));
options.output_alpha_hist = normalize_logical_scalar(options.output_alpha_hist, 'output_alpha_hist');
if options.output_alpha_hist
    try
        alpha_hist_allocation_test = nan(options.num_blocks, options.MaxFunctionEvaluations);
        clear alpha_hist_allocation_test
    catch
        options.output_alpha_hist = false;
        warning('accelerated_bds_options:AlphaHistMemory', ...
            'alpha_hist will not be included in the output due to the limit of memory.');
    end
end
options = set_default_if_missing(options, 'output_block_hist', ...
    get_accelerated_bds_default_constant("output_block_hist"));
options.output_block_hist = normalize_logical_scalar(options.output_block_hist, 'output_block_hist');
options = set_default_if_missing(options, 'output_grad_hist', ...
    get_accelerated_bds_default_constant("output_grad_hist"));
options.output_grad_hist = normalize_logical_scalar(options.output_grad_hist, 'output_grad_hist');
options = set_default_if_missing(options, 'iprint', ...
    get_accelerated_bds_default_constant("iprint"));
if ~(isintegerscalar(options.iprint) && options.iprint >= 0 && options.iprint <= 3)
    error('accelerated_bds_options:InvalidIprint', ...
        'options.iprint must be an integer in {0,1,2,3}.');
end
options.iprint = double(options.iprint);
options = set_default_if_missing(options, 'debug_flag', ...
    get_accelerated_bds_default_constant("debug_flag"));
options.debug_flag = normalize_logical_scalar(options.debug_flag, 'debug_flag');

% Set the acceleration options.
options = set_default_if_missing(options, 'productive_direction_memory_size', max(1, min(n, 5)));
options.productive_direction_memory_size = normalize_positive_integer( ...
    options.productive_direction_memory_size, 'productive_direction_memory_size');
options = set_default_if_missing(options, 'momentum_decay', 0.6);
if ~(isrealscalar(options.momentum_decay) ...
        && options.momentum_decay >= 0 && options.momentum_decay < 1)
    error('accelerated_bds_options:InvalidMomentumDecay', ...
        'options.momentum_decay must be a real scalar in [0, 1).');
end
options = set_default_if_missing(options, 'use_productive_direction_memory', true);
options.use_productive_direction_memory = normalize_logical_scalar( ...
    options.use_productive_direction_memory, 'use_productive_direction_memory');
options = set_default_if_missing(options, 'use_iteration_pattern_step', true);
options.use_iteration_pattern_step = normalize_logical_scalar( ...
    options.use_iteration_pattern_step, 'use_iteration_pattern_step');
options = set_default_if_missing(options, 'use_momentum_extrapolation', true);
options.use_momentum_extrapolation = normalize_logical_scalar( ...
    options.use_momentum_extrapolation, 'use_momentum_extrapolation');
end

function options = set_default_if_missing(options, name, value)
if ~isfield(options, name) || isempty(options.(name))
    options.(name) = value;
end
end

function validate_grouped_direction_indices(options, n, num_blocks)
if ~isfield(options, 'grouped_direction_indices') || isempty(options.grouped_direction_indices)
    return;
end
if ~iscell(options.grouped_direction_indices)
    error('accelerated_bds_options:InvalidGroupedDirectionIndices', ...
        'options.grouped_direction_indices must be a cell array.');
end
if numel(options.grouped_direction_indices) ~= num_blocks
    error('accelerated_bds_options:InvalidGroupedDirectionIndices', ...
        'The length of options.grouped_direction_indices must equal options.num_blocks.');
end

used_dimension_mask = false(1, n);
num_used_indices = 0;
for k = 1:num_blocks
    group = options.grouped_direction_indices{k};
    if ~(isnumeric(group) && isvector(group) && all(isfinite(group)) ...
            && all(group == floor(group)) && all(group >= 1) && all(group <= n) ...
            && numel(unique(group)) == numel(group))
        error('accelerated_bds_options:InvalidGroupedDirectionIndices', ...
            ['Each group in options.grouped_direction_indices must contain ', ...
            'unique integer dimension indices between 1 and n.']);
    end
    used_dimension_mask(group) = true;
    num_used_indices = num_used_indices + numel(group);
end
if num_used_indices ~= n || ~all(used_dimension_mask)
    error('accelerated_bds_options:InvalidGroupedDirectionIndices', ...
        'options.grouped_direction_indices must partition 1:n exactly once.');
end
end

function alpha_init = normalize_alpha_init(alpha_init, num_blocks, n, x0, StepTolerance)
if ischarstr(alpha_init) && strcmpi(alpha_init, 'auto')
    if num_blocks ~= n
        error('accelerated_bds_options:InvalidAlphaInit', ...
            'options.alpha_init = "auto" is supported only when options.num_blocks equals n.');
    end
    alpha_init = get_auto_alpha_init(x0, StepTolerance, 1, 1);
    return;
end
if isscalar(alpha_init)
    alpha_init = alpha_init * ones(num_blocks, 1);
else
    alpha_init = alpha_init(:);
end
if numel(alpha_init) ~= num_blocks || any(alpha_init <= 0)
    error('accelerated_bds_options:InvalidAlphaInit', ...
        'options.alpha_init must be a positive scalar, a num_blocks-vector, or "auto".');
end
end

function value = normalize_logical_scalar(value, name)
if ~(islogical(value) && isscalar(value))
    error('accelerated_bds_options:InvalidLogicalOption', ...
        'options.%s must be a logical scalar.', name);
end
end

function forcing_function = normalize_forcing_function(forcing_function)
if ~isa(forcing_function, 'function_handle')
    error('accelerated_bds_options:InvalidForcingFunction', ...
        'options.forcing_function must be a function handle.');
end
try
    test_output = forcing_function(1);
catch
    error('accelerated_bds_options:InvalidForcingFunction', ...
        'options.forcing_function must accept scalar input.');
end
if ~isscalar(test_output)
    error('accelerated_bds_options:InvalidForcingFunction', ...
        'options.forcing_function must return a scalar for scalar input.');
end
end

function value = normalize_positive_integer(value, name)
if ~(isintegerscalar(value) && value > 0)
    error('accelerated_bds_options:InvalidPositiveIntegerOption', ...
        'options.%s must be a positive integer.', name);
end
value = double(value);
end

function value = normalize_positive_real_scalar(value, name)
if ~(isrealscalar(value) && value > 0)
    error('accelerated_bds_options:InvalidPositiveRealOption', ...
        'options.%s must be a positive real scalar.', name);
end
end
