function options = set_options(options, n, x0)
%SET_OPTIONS Complete and validate BDS options.
%
%   OPTIONS = SET_OPTIONS(OPTIONS, N, X0) returns the complete
%   internal option structure used by bds.
%
%   options                            Input/output scalar structure containing any subset of
%                                      the public options documented by bds.
%                                      Explicit nonempty values take priority over defaults.
%                                      Algorithm is resolved before the block options and
%                                      requires a compatible explicit num_blocks. The
%                                      output contains validated, shape-normalized values for
%                                      every defaulted option and each accepted optional field.
%                                      Memory guards may disable an unsupported history output.
%   n                                  Problem dimension derived from the column form of x0. It
%                                      sets dimension-dependent defaults and option bounds.
%   x0                                 Initial n-by-1 point prepared by bds.
%                                      Its components must be finite when alpha_init is "auto".
%                                      The automatic steps are resolved in bds only after the
%                                      final polling basis and block partition are available.
%   grad_reference_raw_tol             Internal output field derived from the validated
%                                      grad_reference_finite_difference_error_tol and shrink.

% Check every supplied field before preparing the solver or evaluating fun.
supported = {'Algorithm', 'num_blocks', 'direction_set', 'grouped_direction_indices', ...
    'alpha_init', 'StepTolerance', 'expand', 'shrink', 'forcing_function', ...
    'reduction_factor', 'polling_inner', 'cycling_inner', 'seed', 'use_search_acceleration', ...
    'MaxFunctionEvaluations', 'ftarget', 'use_function_value_stop', 'func_window_size', ...
    'func_tol', 'use_estimated_gradient_stop', 'grad_window_size', 'grad_tol', ...
    'lipschitz_constant', 'use_gradient_reference_consistency', ...
    'grad_reference_finite_difference_error_tol', 'output_xhist', 'output_alpha_hist', ...
    'output_block_hist', 'output_grad_hist', 'iprint', 'debug_flag'};
unknown = setdiff(fieldnames(options), supported);
if ~isempty(unknown)
    error('BDS:UnknownOption', 'Unrecognized BDS option: %s.', unknown{1});
end

% Normalize the public visit-order names once. An explicit algorithm fixes the
% number of blocks. Omitting Algorithm allows a general cyclic partition.
explicit_algorithm = isfield(options, 'Algorithm') && ~isempty(options.Algorithm);
options = set_default_if_missing(options, 'Algorithm', 'cbds');
algorithm = options.Algorithm;
if ~((ischar(algorithm) && isrow(algorithm)) || ...
        (isstring(algorithm) && isscalar(algorithm) && ~ismissing(algorithm)))
    error('BDS:InvalidAlgorithm', 'options.Algorithm must be a character row or a string scalar.');
end
switch lower(char(algorithm))
    case {'cyclic', 'cbds'}
        options.Algorithm = 'cbds';
    case {'permuted', 'pbds'}
        options.Algorithm = 'pbds';
    case {'random', 'rbds'}
        options.Algorithm = 'rbds';
    case 'ds'
        options.Algorithm = 'ds';
    otherwise
        error('BDS:InvalidAlgorithm', ...
            'options.Algorithm must be cyclic, permuted, random, cbds, pbds, rbds, or ds.');
end

% Set the maximum number of function evaluations.
options = set_default_if_missing(options, 'MaxFunctionEvaluations', ...
    get_default_constant("MaxFunctionEvaluations_dim_factor") * n);
if ~(isintegerscalar(options.MaxFunctionEvaluations) && options.MaxFunctionEvaluations > 0)
    error('BDS:InvalidMaxFunctionEvaluations', ...
        'options.MaxFunctionEvaluations must be a positive integer.');
end
options.MaxFunctionEvaluations = double(options.MaxFunctionEvaluations);

% Set the number of blocks. One iteration visits one block.
required_blocks = n;
if strcmp(options.Algorithm, 'ds')
    required_blocks = 1;
end
options = set_default_if_missing(options, 'num_blocks', required_blocks);
if ~(isintegerscalar(options.num_blocks) && options.num_blocks > 0 && options.num_blocks <= n)
    error('BDS:InvalidNumBlocks', ...
        'options.num_blocks must be a positive integer not exceeding n.');
end
options.num_blocks = double(options.num_blocks);
if explicit_algorithm && options.num_blocks ~= required_blocks
    error('BDS:ConflictingNumBlocks', ...
        'Algorithm %s requires %d blocks, but num_blocks is %d.', ...
        char(algorithm), required_blocks, options.num_blocks);
end
options = set_default_if_missing(options, 'direction_set', eye(n));
if ~(ismatrix(options.direction_set) ...
    && size(options.direction_set, 1) == n && size(options.direction_set, 2) == n)
    error('BDS:InvalidDirectionSet', ...
        'options.direction_set must be an n-by-n matrix.');
end
validate_grouped_direction_indices(options, n, options.num_blocks);

% Set the options related to the termination criteria.
options = set_default_if_missing(options, 'ftarget', get_default_constant("ftarget"));
if ~isrealscalar(options.ftarget)
    error('BDS:InvalidFtarget', ...
        'options.ftarget must be a real scalar.');
end
options = set_default_if_missing(options, 'use_function_value_stop', ...
    get_default_constant("use_function_value_stop"));
validate_logical_scalar( ...
    options.use_function_value_stop, 'use_function_value_stop');
options = set_default_if_missing(options, 'func_window_size', ...
    get_default_constant("func_window_size"));
options.func_window_size = normalize_positive_integer(options.func_window_size, 'func_window_size');
options = set_default_if_missing(options, 'func_tol', get_default_constant("func_tol"));
validate_positive_real_scalar(options.func_tol, 'func_tol');
options = set_default_if_missing(options, 'use_estimated_gradient_stop', ...
    get_default_constant("use_estimated_gradient_stop"));
validate_logical_scalar( ...
    options.use_estimated_gradient_stop, 'use_estimated_gradient_stop');
options = set_default_if_missing(options, 'grad_window_size', ...
    get_default_constant("grad_window_size"));
options.grad_window_size = normalize_positive_integer(options.grad_window_size, 'grad_window_size');
options = set_default_if_missing(options, 'grad_tol', get_default_constant("grad_tol"));
validate_positive_real_scalar(options.grad_tol, 'grad_tol');
options = set_default_if_missing(options, 'lipschitz_constant', ...
    get_default_constant("lipschitz_constant"));
validate_positive_real_scalar( ...
    options.lipschitz_constant, 'lipschitz_constant');
options = set_default_if_missing(options, 'use_gradient_reference_consistency', ...
    get_default_constant("use_gradient_reference_consistency"));
validate_logical_scalar( ...
    options.use_gradient_reference_consistency, ...
    'use_gradient_reference_consistency');
options = set_default_if_missing(options, ...
    'grad_reference_finite_difference_error_tol', ...
    get_default_constant( ...
    "grad_reference_finite_difference_error_tol"));
validate_positive_real_scalar( ...
    options.grad_reference_finite_difference_error_tol, ...
    'grad_reference_finite_difference_error_tol');
% Set the threshold for the step sizes.
options = set_default_if_missing(options, 'StepTolerance', ...
    get_default_constant("StepTolerance"));
if ~(isnumeric(options.StepTolerance) && isreal(options.StepTolerance) ...
    && (isscalar(options.StepTolerance) ...
    || (isvector(options.StepTolerance) ...
    && numel(options.StepTolerance) == options.num_blocks)) ...
    && all(isfinite(options.StepTolerance(:))) ...
    && all(options.StepTolerance(:) >= 0))
    error('BDS:InvalidStepTolerance', ...
        ['options.StepTolerance must be a finite nonnegative real numeric ', ...
        'scalar or a num_blocks-vector.']);
end
if isscalar(options.StepTolerance)
    options.StepTolerance = double(options.StepTolerance) * ones(options.num_blocks, 1);
else
    options.StepTolerance = double(options.StepTolerance(:));
end

% Set the initial step sizes.
options = set_default_if_missing(options, 'alpha_init', ...
    get_default_constant("alpha_init"));
options.alpha_init = normalize_alpha_init( ...
    options.alpha_init, options.num_blocks, x0);

% The same defaults apply to every objective. Explicit values take priority.
options = set_default_if_missing(options, 'expand', get_default_constant("expand"));
options = set_default_if_missing(options, 'shrink', get_default_constant("shrink"));
if ~(isrealscalar(options.expand) && options.expand >= 1)
    error('BDS:InvalidExpand', ...
        'options.expand must be a real scalar >= 1.');
end
if ~(isrealscalar(options.shrink) && options.shrink > 0 && options.shrink < 1)
    error('BDS:InvalidShrink', ...
        'options.shrink must be a real scalar in (0, 1).');
end

% Convert the public tolerance to the raw gradient-consistency threshold.
% The calibration and its assumptions are explained in check_additional_termination.m.
options.grad_reference_raw_tol = ...
    options.grad_reference_finite_difference_error_tol ...
    * (1 - options.shrink ^ 2) / options.shrink ^ 2;

% Set the remaining polling and randomization options.
options = set_default_if_missing(options, 'forcing_function', ...
    get_default_constant("forcing_function"));
if ~isa(options.forcing_function, 'function_handle')
    error('BDS:InvalidForcingFunction', ...
        'options.forcing_function must be a function handle.');
end
try
    forcing_function_test_output = options.forcing_function(1);
catch
    error('BDS:InvalidForcingFunction', ...
        'options.forcing_function must accept scalar input.');
end
if ~isscalar(forcing_function_test_output)
    error('BDS:InvalidForcingFunction', ...
        'options.forcing_function must return a scalar for scalar input.');
end
options = set_default_if_missing(options, 'reduction_factor', ...
    get_default_constant("reduction_factor"));
if ~(isnumvec(options.reduction_factor) && numel(options.reduction_factor) == 3)
    error('BDS:InvalidReductionFactor', ...
        'options.reduction_factor must be a 3-dimensional real vector.');
end
options.reduction_factor = options.reduction_factor(:)';
if ~(options.reduction_factor(1) <= options.reduction_factor(2) ...
    && options.reduction_factor(2) <= options.reduction_factor(3) ...
    && options.reduction_factor(1) >= 0 ...
    && options.reduction_factor(2) > 0)
    error('BDS:InvalidReductionFactor', ...
        ['options.reduction_factor must satisfy reduction_factor(1) <= ', ...
        'reduction_factor(2) <= reduction_factor(3), reduction_factor(1) >= 0, ', ...
        'and reduction_factor(2) > 0.']);
end
options = set_default_if_missing(options, 'polling_inner', ...
    get_default_constant("polling_inner"));
if ~(ischarstr(options.polling_inner) ...
    && any(ismember(lower(string(options.polling_inner)), ["opportunistic", "complete"])))
    error('BDS:InvalidPollingInner', ...
        'options.polling_inner must be one of: opportunistic, complete.');
end
options.polling_inner = char(lower(string(options.polling_inner)));
options = set_default_if_missing(options, 'cycling_inner', ...
    get_default_constant("cycling_inner"));
if ~(isintegerscalar(options.cycling_inner) ...
    && options.cycling_inner >= 0 && options.cycling_inner <= 3)
    error('BDS:InvalidCyclingInner', ...
        'options.cycling_inner must be an integer in {0,1,2,3}.');
end
options.cycling_inner = double(options.cycling_inner);
options = set_default_if_missing(options, 'seed', get_default_constant("seed"));
if ~(ischarstr(options.seed) && strcmpi(options.seed, 'shuffle'))
    if ~(isintegerscalar(options.seed) && options.seed >= 0 && options.seed <= 2 ^ 32 - 1)
        error('BDS:InvalidSeed', ...
            'options.seed must be an integer in [0, 2^32 - 1] or "shuffle".');
    end
    options.seed = double(options.seed);
end

% Set the output and debugging options.
options = set_default_if_missing(options, 'output_xhist', ...
    get_default_constant("output_xhist"));
validate_logical_scalar(options.output_xhist, 'output_xhist');
if options.output_xhist
    try
        xhist_allocation_test = nan(n, options.MaxFunctionEvaluations);
        clear xhist_allocation_test
    catch
        options.output_xhist = false;
        warning('BDS:XhistMemory', ...
            'xhist will not be included in the output due to the limit of memory.');
    end
end
options = set_default_if_missing(options, 'output_alpha_hist', ...
    get_default_constant("output_alpha_hist"));
validate_logical_scalar(options.output_alpha_hist, 'output_alpha_hist');
if options.output_alpha_hist
    try
        alpha_hist_allocation_test = nan(options.num_blocks, options.MaxFunctionEvaluations);
        clear alpha_hist_allocation_test
    catch
        options.output_alpha_hist = false;
        warning('BDS:AlphaHistMemory', ...
            'alpha_hist will not be included in the output due to the limit of memory.');
    end
end
options = set_default_if_missing(options, 'output_block_hist', ...
    get_default_constant("output_block_hist"));
validate_logical_scalar(options.output_block_hist, 'output_block_hist');
options = set_default_if_missing(options, 'output_grad_hist', ...
    get_default_constant("output_grad_hist"));
validate_logical_scalar(options.output_grad_hist, 'output_grad_hist');
options = set_default_if_missing(options, 'iprint', ...
    get_default_constant("iprint"));
if ~(isintegerscalar(options.iprint) && options.iprint >= 0 && options.iprint <= 3)
    error('BDS:InvalidIprint', ...
        'options.iprint must be an integer in {0,1,2,3}.');
end
options.iprint = double(options.iprint);
options = set_default_if_missing(options, 'debug_flag', ...
    get_default_constant("debug_flag"));
validate_logical_scalar(options.debug_flag, 'debug_flag');

options = set_default_if_missing(options, 'use_search_acceleration', ...
    get_default_constant("use_search_acceleration"));
validate_logical_scalar(options.use_search_acceleration, 'use_search_acceleration');
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
    error('BDS:InvalidGroupedDirectionIndices', ...
        'options.grouped_direction_indices must be a cell array.');
end
if numel(options.grouped_direction_indices) ~= num_blocks
    error('BDS:InvalidGroupedDirectionIndices', ...
        'The length of options.grouped_direction_indices must equal options.num_blocks.');
end

used_dimension_mask = false(1, n);
num_used_indices = 0;
for k = 1:num_blocks
    group = options.grouped_direction_indices{k};
    if ~(isnumeric(group) && isvector(group) && all(isfinite(group)) ...
        && all(group == floor(group)) && all(group >= 1) && all(group <= n) ...
        && numel(unique(group)) == numel(group))
        error('BDS:InvalidGroupedDirectionIndices', ...
            ['Each group in options.grouped_direction_indices must contain ', ...
            'unique integer dimension indices between 1 and n.']);
    end
    used_dimension_mask(group) = true;
    num_used_indices = num_used_indices + numel(group);
end
if num_used_indices ~= n || ~all(used_dimension_mask)
    error('BDS:InvalidGroupedDirectionIndices', ...
        'options.grouped_direction_indices must partition 1:n exactly once.');
end
end

function alpha_init = normalize_alpha_init(alpha_init, num_blocks, x0)
if ischarstr(alpha_init) && strcmpi(alpha_init, 'auto')
    if any(~isfinite(x0))
        error('BDS:InvalidX0', ...
            'x0 must contain only finite values when options.alpha_init = "auto".');
    end
    return;
end
if ~(isnumeric(alpha_init) && isreal(alpha_init) ...
    && (isscalar(alpha_init) ...
    || (isvector(alpha_init) && numel(alpha_init) == num_blocks)) ...
    && all(isfinite(alpha_init(:))) && all(alpha_init(:) > 0))
    error('BDS:InvalidAlphaInit', ...
        ['options.alpha_init must be a finite positive real numeric scalar, ', ...
        'a num_blocks-vector, or "auto".']);
end
if isscalar(alpha_init)
    alpha_init = double(alpha_init) * ones(num_blocks, 1);
else
    alpha_init = double(alpha_init(:));
end
end

function validate_logical_scalar(value, name)
if ~(islogical(value) && isscalar(value))
    error('BDS:InvalidLogicalOption', ...
        'options.%s must be a logical scalar.', name);
end
end

function value = normalize_positive_integer(value, name)
if ~(isintegerscalar(value) && value > 0)
    error('BDS:InvalidPositiveIntegerOption', ...
        'options.%s must be a positive integer.', name);
end
value = double(value);
end

function validate_positive_real_scalar(value, name)
if ~(isrealscalar(value) && value > 0)
    error('BDS:InvalidPositiveRealOption', ...
        'options.%s must be a positive real scalar.', name);
end
end
