function options = frozen_acceleration_options(options)
%FROZEN_ACCELERATION_OPTIONS Express the current switch in a frozen solver's API.
if isfield(options, 'use_search_acceleration')
    options.use_iteration_pattern_step = options.use_search_acceleration;
    options.use_momentum_extrapolation = options.use_search_acceleration;
    options = rmfield(options, 'use_search_acceleration');
end
end
