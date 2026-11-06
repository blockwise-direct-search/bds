function [state, rolling, succeeded, target_reached, attempted] = ...
    run_rolling_acceleration(fun, state, configuration, rolling, block, ...
        visit_count, point_before, value_before)
%RUN_ROLLING_ACCELERATION Record one poll and dispatch the existing MP kernel.
% state has the interface of run_post_poll_acceleration_phase. Its entry
% point/value are AFTER the current poll; point_before/value_before are
% BEFORE that poll. Only the current block's momentum is read and written.
% The first cycle only records polling updates. Its end-of-cycle bootstrap
% is handled by bds and finish_rolling_bootstrap.
%
% Keep the frozen C15 arithmetic order: overwrite the current slot, sum the
% slots, then add this call's acceleration displacement to the slot. A running
% sum or a subtraction of endpoints need not be bitwise equivalent.

num_blocks = size(rolling.steps, 2);
slot = 1 + mod(visit_count - 1, num_blocks);
polled = state.xbase;
rolling.last_polled = polled;
rolling.steps(:, slot) = polled - point_before;
direction = sum(rolling.steps, 2);
attempted = visit_count > num_blocks && state.fbase < value_before ...
    && norm(direction) > configuration.step_floor ...
    && state.nf < configuration.MaxFunctionEvaluations;
succeeded = false;
target_reached = false;
if attempted
    state.momentum = rolling.momentum(:, block);
    [state, succeeded, target_reached] = run_post_poll_acceleration_phase( ...
        fun, state, configuration, direction);
    rolling.momentum(:, block) = state.momentum;
end
% The present acceleration belongs to future windows, not its own direction.
rolling.steps(:, slot) = rolling.steps(:, slot) + (state.xbase - polled);
end
