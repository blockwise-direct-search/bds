function options = validate_bds_without_acceleration_reference_options(options, n)
% VALIDATE_OPTIONS Validate the values of fields in the options structure.
%
%   This function checks that all fields in the options structure have valid
%   values. It assumes that all field names in the options structure are valid
%   and predefined. If any field contains an invalid value, the function will
%   throw an error and terminate execution. This ensures that the options structure
%   is strictly validated before proceeding.
%
%   Inputs:
%   - options: A structure containing the options to be validated. All field names
%              are assumed to be valid and predefined.
%   - n: The dimension of the optimization problem.
%
%   Outputs:
%   - options: The validated options structure, containing only valid fields
%              with valid values.
%
%   Note:
%   - If any field in the options structure contains an invalid value, an
%     error will be thrown, and the program will terminate.
%

% MaxFunctionEvaluations
if isfield(options, 'MaxFunctionEvaluations')
    if ~(isintegerscalar(options.MaxFunctionEvaluations) && options.MaxFunctionEvaluations > 0)
        error('options.MaxFunctionEvaluations must be a positive integer.');
    end
end
% ftarget
if isfield(options, 'ftarget')
    if ~isrealscalar(options.ftarget)
        error('options.ftarget must be a real scalar.');
    end
end

% StepTolerance
if isfield(options, 'StepTolerance')
    if isfield(options, 'num_blocks')
        expected_step_tolerance_length = options.num_blocks;
    else
        expected_step_tolerance_length = n;
    end
    if ~((isrealscalar(options.StepTolerance) && options.StepTolerance >= 0) || ...
         (isnumvec(options.StepTolerance) && all(options.StepTolerance >= 0) && ...
          length(options.StepTolerance) == expected_step_tolerance_length))
        error(['options.StepTolerance must be a nonnegative scalar or a nonnegative vector with length ' ...
               'equal to n (or options.num_blocks if provided).']);
    end
end

% use_function_value_stop
if isfield(options, 'use_function_value_stop')
    if ~(islogical(options.use_function_value_stop) && isscalar(options.use_function_value_stop))
        error('options.use_function_value_stop must be a logical scalar.');
    end
end

% func_window_size
if isfield(options, 'func_window_size')
    if ~(isintegerscalar(options.func_window_size) && options.func_window_size > 0)
        error('options.func_window_size must be a positive integer.');
    end
end

% func_tol
if isfield(options, 'func_tol')
    if ~(isrealscalar(options.func_tol) && options.func_tol > 0)
        error('options.func_tol must be a positive real scalar.');
    end
end

% use_estimated_gradient_stop
if isfield(options, 'use_estimated_gradient_stop')
    if ~(islogical(options.use_estimated_gradient_stop) && isscalar(options.use_estimated_gradient_stop))
        error('options.use_estimated_gradient_stop must be a logical scalar.');
    end
end

% grad_window_size
if isfield(options, 'grad_window_size')
    if ~(isintegerscalar(options.grad_window_size) && options.grad_window_size > 0)
        error('options.grad_window_size must be a positive integer.');
    end
end

% grad_tol
if isfield(options, 'grad_tol')
    if ~(isrealscalar(options.grad_tol) && options.grad_tol > 0)
        error('options.grad_tol must be a positive real scalar.');
    end
end

% lipschitz_constant
if isfield(options, 'lipschitz_constant')
    if ~(isrealscalar(options.lipschitz_constant) && options.lipschitz_constant > 0)
        error('options.lipschitz_constant must be a positive real scalar.');
    end
end

% use_gradient_reference_consistency
if isfield(options, 'use_gradient_reference_consistency')
    if ~(islogical(options.use_gradient_reference_consistency) ...
            && isscalar(options.use_gradient_reference_consistency))
        error('options.use_gradient_reference_consistency must be a logical scalar.');
    end
end

% grad_reference_finite_difference_error_tol
if isfield(options, 'grad_reference_finite_difference_error_tol')
    if ~(isrealscalar(options.grad_reference_finite_difference_error_tol) ...
            && options.grad_reference_finite_difference_error_tol > 0)
        error(['options.grad_reference_finite_difference_error_tol must be ', ...
            'a positive real scalar.']);
    end
end

% Algorithm
Algorithm_list = ["cbds", "pbds", "pads", "rbds", "ds"];
if isfield(options, 'Algorithm')
    if ~(ischarstr(options.Algorithm) ...
        && any(ismember(lower(string(options.Algorithm)), Algorithm_list)))
        error('options.Algorithm must be one of: cbds, pbds, pads, rbds, ds.');
    end
end

% direction_set (basis matrix of size n-by-n)
if isfield(options, 'direction_set')
    if ~(ismatrix(options.direction_set) && (size(options.direction_set,1) == n) ...
        && (size(options.direction_set,2) == n))
        error('options.direction_set must be an n-by-n matrix (n is dimension of the problem).');
    end
end

% num_blocks
if isfield(options, 'num_blocks')
    if ~(isintegerscalar(options.num_blocks) && options.num_blocks > 0)
        error('options.num_blocks must be a positive integer.');
    elseif options.num_blocks > n
        error('options.num_blocks cannot exceed the dimension of n.');
    end
end

% batch_size
if isfield(options, 'batch_size')
    if ~(isintegerscalar(options.batch_size) && options.batch_size > 0)
        error('options.batch_size must be a positive integer.');
    end
    if isfield(options, 'num_blocks') && options.batch_size > options.num_blocks
        error('options.batch_size cannot exceed options.num_blocks.');
    end
    if options.batch_size > n
        error('options.batch_size cannot exceed the dimension of n.');
    end
end

% replacement_delay
if isfield(options, 'replacement_delay')
    if ~(isintegerscalar(options.replacement_delay) && options.replacement_delay >= 0)
        error('options.replacement_delay must be a non-negative integer.');
    end
    if (isfield(options, 'num_blocks') && isfield(options, 'batch_size')) && ...
            (options.replacement_delay > floor(options.num_blocks / options.batch_size) - 1)
        error('options.replacement_delay must be less than or equal to floor(num_blocks / batch_size) - 1.');
    end
end

% grouped_direction_indices
if isfield(options, 'grouped_direction_indices')
    if ~iscell(options.grouped_direction_indices)
        error('options.grouped_direction_indices must be a cell array.');
    else
        total_directions = 0;
        for k = 1:length(options.grouped_direction_indices)
            group = options.grouped_direction_indices{k};
            if ~(isnumvec(group) && all(group >= 1) && all(group <= n) && length(unique(group)) == length(group))
                error('Each group in options.grouped_direction_indices must be a vector of unique integers between 1 and n.');
            end
            total_directions = total_directions + length(group);
        end
        if total_directions ~= n
            error('The sum of the lengths of all indices in options.grouped_direction_indices must equal n.');
        end
    end
end

% block_visiting_pattern
if isfield(options, 'block_visiting_pattern')
    pat_list = ["sorted", "random", "parallel"];
    if ~(ischarstr(options.block_visiting_pattern) ...
        && any(ismember(lower(string(options.block_visiting_pattern)), pat_list)))
        error('options.block_visiting_pattern must be one of: sorted, random, parallel.');
    end
end

% alpha_init
if isfield(options, 'alpha_init')
    if ~((isrealscalar(options.alpha_init) && options.alpha_init > 0) || ...
         (isnumvec(options.alpha_init) && all(options.alpha_init > 0) && ...
          length(options.alpha_init) <= n && ...
          (~isfield(options, 'num_blocks') || length(options.alpha_init) <= options.num_blocks)) || ...
         (ischarstr(options.alpha_init) && strcmpi(options.alpha_init, 'auto')))
        error(['options.alpha_init must be a positive scalar, the string ''auto'', ' ...
               'or a positive vector with length not exceeding n ' ...
               '(and not exceeding options.num_blocks if provided).']);
    end
end

% expand
if isfield(options, 'expand')
    if ~(isrealscalar(options.expand) && options.expand >= 1)
        error('options.expand must be a real scalar >= 1.');
    end
end

% shrink
if isfield(options, 'shrink')
    if ~(isrealscalar(options.shrink) && options.shrink > 0 && options.shrink < 1)
        error('options.shrink must be a real scalar in (0, 1).');
    end
end

% is_noisy
if isfield(options, 'is_noisy')
    if ~(islogical(options.is_noisy) && isscalar(options.is_noisy))
        error('options.is_noisy must be a logical scalar.');
    end
end

% forcing_function
if isfield(options, 'forcing_function')
    if ~isa(options.forcing_function, 'function_handle')
        error('options.forcing_function must be a function handle.');
    else
        % Test if the function accepts scalar input and returns scalar output
        try
            test_input = 1; % Example scalar input
            test_output = options.forcing_function(test_input);
            if ~isscalar(test_output)
                error('options.forcing_function must return a scalar for scalar input.');
            end
        catch
            error('options.forcing_function must accept scalar input.');
        end
    end
end

% reduction_factor (3-vector with ordering constraints)
if isfield(options, 'reduction_factor')
    if ~(isnumvec(options.reduction_factor) && length(options.reduction_factor) == 3)
        error('options.reduction_factor must be a 3-dimensional real vector');
    else
        reduction_factor = options.reduction_factor(:);
        if ~(reduction_factor(1) <= reduction_factor(2) && ...
             reduction_factor(2) <= reduction_factor(3) && ...
             reduction_factor(1) >= 0 && reduction_factor(2) > 0)
            error('options.reduction_factor must satisfy reduction_factor(1) <= reduction_factor(2) <= reduction_factor(3), reduction_factor(1) >= 0, and reduction_factor(2) > 0.');
        end
    end
end

% polling_inner
if isfield(options, 'polling_inner')
    pi_list = ["opportunistic", "complete"];
    if ~(ischarstr(options.polling_inner) ...
        && any(ismember(lower(string(options.polling_inner)), pi_list)))
        error('options.polling_inner must be one of: opportunistic, complete.');
    end
end

% cycling_inner
if isfield(options, 'cycling_inner')
    if ~(isintegerscalar(options.cycling_inner) && options.cycling_inner >= 0 && options.cycling_inner <= 3)
        error('options.cycling_inner must be an integer in {0,1,2,3}.');
    end
end

% seed
if isfield(options, 'seed')
    if ~(isintegerscalar(options.seed) && options.seed >= 0 && options.seed <= 2^32 -1)
        error('options.seed must be an integer in [0, 2^32 - 1].');
    end
end

% output flags
flag_fields = {'output_xhist','output_alpha_hist','output_block_hist', 'output_grad_hist'};
for k = 1:numel(flag_fields)
    f = flag_fields{k};
    if isfield(options, f)
        if ~(islogical(options.(f)) && isscalar(options.(f)))
            error('options.%s must be a logical scalar.', f);
        end
    end
end

% iprint
if isfield(options, 'iprint')
    if ~(isintegerscalar(options.iprint) && options.iprint >= 0 && options.iprint <= 3)
        error('options.iprint must be an integer in {0,1,2,3}.');
    end
end

% debug_flag
if isfield(options, 'debug_flag')
    if ~(islogical(options.debug_flag) && isscalar(options.debug_flag))
        error('options.debug_flag must be a logical scalar.');
    end
end

end
