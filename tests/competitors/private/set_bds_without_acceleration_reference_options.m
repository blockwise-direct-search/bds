function options = set_bds_without_acceleration_reference_options(options, n, x0)
% SET_OPTIONS Set and validate options for the BDS algorithm.
%
%   OPTIONS = SET_OPTIONS(OPTIONS, N, X0) processes and validates the input options
%   structure for the BDS algorithm. It performs the following tasks:
%   1. Validate that all field names in OPTIONS are recognized.
%   2. Validate that all field values are valid through the frozen validator.
%   3. Resolve conflicts between mutually exclusive options (e.g., Algorithm
%      vs. block_visiting_pattern/num_blocks/batch_size).
%   4. Set default values for missing fields based on problem dimension N and
%      other context-specific information.
%   5. Check memory constraints for optional output fields (output_alpha_hist,
%      output_xhist).
%
%   Inputs:
%   - options: A structure containing user-specified options for the BDS algorithm.
%              All field names must be valid and recognized.
%   - n: The dimension of the optimization problem.
%   - x0: The initial point for the optimization problem.
%
%   Outputs:
%   - options: A fully validated and processed options structure with all required
%              fields set to appropriate values (either user-provided or defaults).
%
%   Note:
%   - If any field name is unknown or any field value is invalid, an error is
%     thrown and execution terminates.
%   - If optional output fields exceed memory limits, a warning is issued and
%     the corresponding output flag is set to false.

% Define the list of allowed fields.
field_list = {
    'MaxFunctionEvaluations'
    'ftarget'
    'StepTolerance'
    'use_function_value_stop'
    'func_window_size'
    'func_tol'
    'use_estimated_gradient_stop'
    'grad_window_size'
    'grad_tol'
    'lipschitz_constant'
    'use_gradient_reference_consistency'
    'grad_reference_finite_difference_error_tol'
    'Algorithm'
    'direction_set'
    'num_blocks'
    'batch_size'
    'replacement_delay'
    'grouped_direction_indices'
    'block_visiting_pattern'
    'alpha_init'
    'expand'
    'shrink'
    'is_noisy'
    'forcing_function'
    'reduction_factor'
    'polling_inner'
    'cycling_inner'
    'seed'
    'output_xhist'
    'output_alpha_hist'
    'output_block_hist'
    'output_grad_hist'
    'iprint'
    'debug_flag'
    };

% Get the field names of options and convert to cell array of strings.
field_names = fieldnames(options);
% Check for unknown fields. If any unknown fields are found, throw an error.
% Rationale: Using a warning here might allow the program to continue execution,
% which could lead to unexpected behavior if the user provided incorrect or
% misspelled field names. Additionally, some MATLAB environments or configurations
% might suppress warnings, making it harder for users to identify the issue.
% By throwing an error, we ensure that the user is immediately notified of the
% problem and can correct the input options before proceeding.
unknown_fields = field_names(~ismember(field_names, field_list));
if ~isempty(unknown_fields)
    error('BDS:set_options:UnknownField', ...
        'The following fields in options are not recognized: %s', strjoin(unknown_fields, ', '));
end

% At this point, all fields in options are valid field names, as any unknown fields
% have already caused an error earlier. The next step ensures that
% the values associated with these fields are valid. If any field contains an
% invalid value, the frozen validation function will throw an error and terminate
% execution. This strict validation ensures that the options structure is fully
% consistent before proceeding.
options = validate_bds_without_acceleration_reference_options(options, n);

% Although the field names are valid and the corresponding values are valid after the above step,
% conflicts may arise if the user provides values for some certain fields simultaneously.
% We need to resolve such priority issues to avoid ambiguity. The following procedures
% handle such conflicts and set default values for missing fields.

% Set the maximum number of function evaluations.
% If the options do not contain MaxFunctionEvaluations,
% it is set to MaxFunctionEvaluations_dim_factor*n, where n is the dimension of the problem.
if ~isfield(options, "MaxFunctionEvaluations")
    options.MaxFunctionEvaluations = get_bds_without_acceleration_reference_default_constant("MaxFunctionEvaluations_dim_factor")*n;
end

% We handle Algorithm early because it determines defaults for num_blocks, batch_size, etc.
if isfield(options, 'Algorithm')
    if any(isfield(options, {'block_visiting_pattern', 'num_blocks', 'batch_size'}))
        warning('Algorithm and block_visiting_pattern/num_blocks/batch_size are mutually exclusive. Algorithm will be used.');
        % Remove block_visiting_pattern, num_blocks, and batch_size from options.
        options = rmfield(options, intersect(fieldnames(options), {'block_visiting_pattern', 'num_blocks', 'batch_size'}));
    end
    options.Algorithm = lower(options.Algorithm);
    switch lower(options.Algorithm)
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
        case 'pads'
            options.num_blocks = n;
            options.batch_size = n;
            options.block_visiting_pattern = 'parallel';
        case 'ds'
            options.num_blocks = 1;
            options.batch_size = 1;
    end
end

% Set the directions.
if ~isfield(options, 'direction_set')
    options.direction_set = eye(n);
end

% Set the number of blocks (num_blocks) if it is not provided.
if ~isfield(options, 'num_blocks')
    options.num_blocks = n;
end

% Set the step size threshold for termination. The algorithm terminates when the step size for each
% block falls below their corresponding threshold.
% If StepTolerance is not provided, it is set to 1e-6 for each block.
% If StepTolerance is a numeric vector, its length must match options.num_blocks.
if isfield(options, "StepTolerance")
    if isscalar(options.StepTolerance)
        options.StepTolerance = options.StepTolerance * ones(options.num_blocks, 1);
    elseif isnumvec(options.StepTolerance) && length(options.StepTolerance) == options.num_blocks
        options.StepTolerance = options.StepTolerance(:);
    else
        error('BDS:set_options:InvalidStepToleranceLength', ...
            'Length of options.StepTolerance must match options.num_blocks.');
    end
else
    options.StepTolerance = 1e-6 * ones(options.num_blocks, 1);
end

% Set the value of batch_size.
if ~isfield(options, 'batch_size')
    options.batch_size = options.num_blocks;
elseif options.batch_size > options.num_blocks
    error('BDS:set_options:BatchSizeTooLarge', ...
        'options.batch_size cannot exceed options.num_blocks.');
end

% If replacement_delay is r, the block selected in the current iteration will not
% be selected again in the next r iterations.
% While a larger replacement_delay can potentially improve performance, we set it
% to the maximum allowable value to prioritize performance.
% Note that replacement_delay cannot exceed floor(num_blocks/batch_size) - 1.
if isfield(options, "replacement_delay")
    if options.replacement_delay > floor(options.num_blocks/options.batch_size) - 1
        error('BDS:set_options:InvalidReplacementDelay', ...
            'options.replacement_delay cannot exceed floor(options.num_blocks/options.batch_size) - 1.');
    end
else
    options.replacement_delay = floor(options.num_blocks/options.batch_size) - 1;
end

% Set the default value of block_visiting_pattern if it is not provided.
if ~isfield(options, 'block_visiting_pattern')
    options.block_visiting_pattern = get_bds_without_acceleration_reference_default_constant("block_visiting_pattern");
end

% Set the initial step sizes.
% If options do not contain the field of alpha_init, then the initial step size of each block is set
% to 1.
% If alpha_init is a positive scalar, then the initial step size of each block is set to
% alpha_init.
% If alpha_init is a vector, then the initial step size of the i-th block is set to
% alpha_init(i). We first verify it is a numeric vector to avoid accepting strings that happen
% to have the same length (for example, 'auto' when num_blocks = 4).
% If alpha_init is "auto", then use a fminsearch-inspired scale-aware rule
% adapted to BDS polling steps: nonzero coordinates receive max(abs(x0),
% StepTolerance), exact zero coordinates keep the neutral unit step, and
% block steps are the maximum coordinate steps in each block.
if isfield(options, "alpha_init")
    if isrealscalar(options.alpha_init)
        options.alpha_init = options.alpha_init * ones(options.num_blocks, 1);
    elseif isnumvec(options.alpha_init) && (length(options.alpha_init) == options.num_blocks)
        options.alpha_init = options.alpha_init(:);
    elseif strcmpi(options.alpha_init, "auto")
        grouped_direction_indices = divide_direction_set(n, options.num_blocks, options);
        alpha_block = zeros(options.num_blocks, 1);
        for i = 1:options.num_blocks
            direction_indices = grouped_direction_indices{i};
            coordinate_indices = unique(ceil(direction_indices(:) / 2));
            alpha_coord = get_bds_without_acceleration_reference_auto_alpha_init( ...
                x0(coordinate_indices), options.StepTolerance(i), 1, 1);
            alpha_block(i) = max(alpha_coord);
        end
        options.alpha_init = alpha_block;
    else
        error('BDS:set_options:InvalidAlphaInit', ...
            'options.alpha_init must be a positive scalar, a vector of length options.num_blocks, or "auto".');
    end
else
    options.alpha_init = ones(options.num_blocks, 1);
end

% Set whether the objective function is noisy.
% Note: is_noisy determines the defaults for expand and shrink, so it must be set first before
% setting expand and shrink.
if ~isfield(options, 'is_noisy')
    options.is_noisy = get_bds_without_acceleration_reference_default_constant("is_noisy");
end

% Set default expand and shrink values.
% The defaults depend only on whether the problem is noisy.
if isfield(options, "is_noisy") && options.is_noisy
    expand = get_bds_without_acceleration_reference_default_constant("expand_noisy");
    shrink = get_bds_without_acceleration_reference_default_constant("shrink_noisy");
else
    expand = get_bds_without_acceleration_reference_default_constant("expand");
    shrink = get_bds_without_acceleration_reference_default_constant("shrink");
end

% Set the values of options.expand and options.shrink.
% The values of expand and shrink have been determined earlier based only on
% whether the problem is noisy. If the user has not provided values for expand
% or shrink, the precomputed default values are used. Since the options
% structure has already been validated by remove_invalid_options, any
% user-provided values are assumed to be valid and will not be overwritten.
if ~isfield(options, "expand")
    options.expand = expand;
end
if ~isfield(options, "shrink")
    options.shrink = shrink;
end

% The above procedures handle some fields that depend on problem-specific information and are not
% determined solely by user input.
% We define a list of fields that are either handled manually above or should not
% be filled by get_default_constant.
manual_fields = {'MaxFunctionEvaluations', 'Algorithm', 'direction_set', 'num_blocks', ...
                'StepTolerance', 'batch_size', 'replacement_delay', 'block_visiting_pattern', ...
                'alpha_init', 'is_noisy', 'expand', 'shrink', 'grouped_direction_indices'};

% For the remaining fields, set default values using get_default_constant if they are missing.
% We iterate through field_list to maintain the order defined in bds.m.
for i = 1:length(field_list)
    field_name = field_list{i};
    if ~ismember(field_name, manual_fields)
        if ~isfield(options, field_name)
            % Get the default value of those fields that are not related to the problem information
            % from the get_default_constant function.
            options.(field_name) = get_bds_without_acceleration_reference_default_constant(field_name);
        end
    end
end

% Two gradient estimates at the same base point use step sizes h and
% shrink*h. The leading error of a central difference is proportional to
% h^2, so their leading difference is (1-shrink^2) times the error at h.
% Convert the public relative finite-difference error tolerance into the raw
% consistency threshold applied to the two reconstructed gradients.
options.grad_reference_raw_tol = ...
    options.grad_reference_finite_difference_error_tol ...
    * (1 - options.shrink^2) / options.shrink^2;

% Initialize alpha_hist if output_alpha_hist is true and alpha_hist does not exceed the
% maximum memory size allowed.
% Both NaN and zero have the same memory allocation in MATLAB, as they are stored
% as double-precision floating-point numbers. For the purpose of memory allocation
% testing, either NaN or zero can be used interchangeably. Here, nan is chosen
% arbitrarily, as the choice does not affect subsequent computations.
if options.output_alpha_hist
    try
        % Test allocation of alpha_hist whether it exceeds the maximum memory size allowed.
        alpha_hist_test = nan(options.num_blocks, options.MaxFunctionEvaluations);
        clear alpha_hist_test
    catch
        options.output_alpha_hist = false;
        warning("alpha_hist will not be included in the output due to the limit of memory.")
    end
end
% If xhist exceeds the maximum memory size allowed, then we will not output xhist.
if  options.output_xhist
    try
        % Test allocation of xhist whether it exceeds the maximum memory size allowed.
        xhist_test = nan(n, options.MaxFunctionEvaluations);
        clear xhist_test
    catch
        options.output_xhist = false;
        warning("xhist will be not included in the output due to the limit of memory.");
    end
end
end
