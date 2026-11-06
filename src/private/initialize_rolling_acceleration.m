function rolling = initialize_rolling_acceleration(options, basis, blocks)
%INITIALIZE_ROLLING_ACCELERATION Allocate history for the validated cyclic case.
% Other configurations keep the existing batch MP behavior. This predicate
% concerns resolved settings, not an Algorithm alias. No random draws occur.
% steps has one chronological ring slot per coordinate block; momentum has
% one vector per block. Both are private state, not additional user options.

n = size(basis, 1);
supported = options.num_blocks == n && options.batch_size == n ...
    && options.replacement_delay == 0 ...
    && strcmpi(options.block_visiting_pattern, 'sorted') ...
    && isequal(basis, eye(n));
if supported
    for i = 1:n
        if ~isequal(blocks{i}(:)', [2*i-1, 2*i])
            supported = false;
            break;
        end
    end
end
rolling.enabled = supported && (options.use_iteration_pattern_step ...
    || options.use_momentum_extrapolation);
if rolling.enabled
    rolling.steps = zeros(n, n);
    rolling.momentum = zeros(n, n);
    rolling.last_polled = [];
end
end
