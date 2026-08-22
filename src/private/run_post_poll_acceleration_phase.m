function [post_poll_acceleration_state, acceleration_succeeded, target_reached] = ...
    run_post_poll_acceleration_phase(fun, post_poll_acceleration_state, ...
        acceleration_configuration, iteration_step)
%RUN_POST_POLL_ACCELERATION_PHASE Search pattern and momentum directions after polling.
%
%   [POST_POLL_ACCELERATION_STATE, ACCELERATION_SUCCEEDED, TARGET_REACHED] =
%   RUN_POST_POLL_ACCELERATION_PHASE(FUN, POST_POLL_ACCELERATION_STATE,
%   ACCELERATION_CONFIGURATION, ITERATION_STEP) performs up to two ordered
%   directional searches after regular polling:
%
%   1. The iteration-pattern search probes along the normalized net
%      displacement produced during the current improving iteration.
%   2. The momentum-direction extrapolation is a fallback. It probes along
%      the updated momentum direction only when the pattern search is disabled
%      or produces no improvement.
%
%   fun                                Objective function.
%
%   POST_POLL_ACCELERATION_STATE is an input/output structure containing the
%   mutable solver state read or updated by this phase. Its fields are listed
%   below.
%
%   xbase                              Base point at entry. It is replaced by the best
%                                      accepted acceleration point when this phase succeeds.
%   fbase                              Objective value used for comparisons at xbase. It is
%                                      updated together with xbase when this phase succeeds.
%   nf                                 Number of objective evaluations performed so far. It
%                                      is incremented after every evaluation made here.
%   fhist                              Function-value history. Each new raw objective value
%                                      is stored at the corresponding updated nf index.
%   xhist                              Point history. It is updated only when output_xhist
%                                      is true.
%   invalid_points                     Matrix whose columns are evaluated points with
%                                      invalid objective values. It is updated only when
%                                      output_xhist is true.
%   productive_direction_memory        Ordered structure array with fields direction and
%                                      step. An accepted direction may be admitted to this
%                                      memory.
%   momentum                           Current n-by-1 momentum vector. When momentum
%                                      extrapolation is enabled, it is updated before any
%                                      pattern candidate is evaluated and remains updated
%                                      regardless of the later search outcome.
%
%   ACCELERATION_CONFIGURATION is a read-only structure containing the options
%   needed by the two post-poll acceleration searches. Its fields control
%   which searches are enabled, the momentum update, their common evaluation
%   constraints and history recording, and productive-direction admission.
%
%   use_iteration_pattern_step         Whether pattern candidates are evaluated.
%   use_momentum_extrapolation         Whether momentum is updated and momentum candidates
%                                      may be evaluated.
%   use_productive_direction_memory    Whether an accepted acceleration direction may be
%                                      stored.
%   momentum_decay                     Weight applied to the previous momentum vector.
%   productive_direction_memory_size   Maximum number of retained productive directions.
%   step_floor                         Lower bound for the pattern step and for normalizing
%                                      momentum.
%   MaxFunctionEvaluations             Total objective-evaluation budget.
%   ftarget                            Target function value.
%   output_xhist                       Whether point and invalid-point histories are recorded.
%
%   iteration_step                     Net displacement of xbase during the current outer
%                                      iteration. The caller enters this phase only when its
%                                      norm exceeds step_floor.
%   acceleration_succeeded             True exactly when the phase accepts a point whose
%                                      function value is strictly smaller than the entry
%                                      fbase.
%   target_reached                     Whether the pattern or momentum search accepts an
%                                      improving candidate with comparison value no larger
%                                      than ftarget. The caller owns the corresponding
%                                      terminate and exitflag updates.
%
%   Both searches generate candidates from the entry xbase using the same
%   pattern_step and the same factors [1, 2, 4]; only the search direction
%   differs. Each search stops at its first non-improving candidate. Momentum
%   candidates are tried only if the pattern search did not improve, the
%   target was not reached, a usable momentum direction exists, and budget
%   remains. A momentum point identical to the failed pattern point is not
%   reevaluated.

acceleration_succeeded = false;
target_reached = false;

iteration_step_norm = norm(iteration_step);
pattern_direction = iteration_step / iteration_step_norm;
pattern_step = max(iteration_step_norm, acceleration_configuration.step_floor);

% Prepare the momentum direction before either directional search. The updated
% momentum remains part of the solver state even if the pattern search succeeds.
if acceleration_configuration.use_momentum_extrapolation
    post_poll_acceleration_state.momentum = ...
        acceleration_configuration.momentum_decay ...
        * post_poll_acceleration_state.momentum ...
        + (1.0 - acceleration_configuration.momentum_decay) * pattern_direction;
    momentum_norm = norm(post_poll_acceleration_state.momentum);
    if momentum_norm > acceleration_configuration.step_floor
        momentum_direction = post_poll_acceleration_state.momentum / momentum_norm;
    else
        momentum_direction = [];
    end
else
    momentum_direction = [];
end
% Both directional searches use this common radial schedule from the entry
% xbase with the common pattern_step; only the search direction changes.
factors = [1.0, 2.0, 4.0];
xbest = post_poll_acceleration_state.xbase;
fbest = post_poll_acceleration_state.fbase;
best_direction = [];
pattern_improved = false;
failed_pattern_point = [];

% Part 1: search along the current iteration-pattern direction.
if acceleration_configuration.use_iteration_pattern_step
    for i = 1:numel(factors)
        if post_poll_acceleration_state.nf ...
                >= acceleration_configuration.MaxFunctionEvaluations
            break;
        end
        xnew = post_poll_acceleration_state.xbase ...
            + factors(i) * pattern_step * pattern_direction;
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        post_poll_acceleration_state.nf = post_poll_acceleration_state.nf + 1;
        post_poll_acceleration_state.fhist(post_poll_acceleration_state.nf) = fnew_real;
        if acceleration_configuration.output_xhist
            post_poll_acceleration_state.xhist(:, post_poll_acceleration_state.nf) = xnew;
            if ~is_valid
                post_poll_acceleration_state.invalid_points = [ ...
                    post_poll_acceleration_state.invalid_points, xnew];
            end
        end
        if fnew < fbest
            xbest = xnew;
            fbest = fnew;
            best_direction = pattern_direction;
            pattern_improved = true;
        else
            failed_pattern_point = xnew;
            break;
        end
        if fnew <= acceleration_configuration.ftarget
            target_reached = true;
            break;
        end
    end
end

% Part 2: when the pattern search is disabled or does not improve, reuse the
% same factors and pattern_step along the updated momentum direction.
if ~target_reached && acceleration_configuration.use_momentum_extrapolation ...
        && ~pattern_improved && ~isempty(momentum_direction) ...
        && post_poll_acceleration_state.nf ...
            < acceleration_configuration.MaxFunctionEvaluations
    for i = 1:numel(factors)
        if post_poll_acceleration_state.nf ...
                >= acceleration_configuration.MaxFunctionEvaluations
            break;
        end
        xnew = post_poll_acceleration_state.xbase ...
            + factors(i) * pattern_step * momentum_direction;
        if ~isempty(failed_pattern_point) && isequal(xnew, failed_pattern_point)
            break;
        end
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        post_poll_acceleration_state.nf = post_poll_acceleration_state.nf + 1;
        post_poll_acceleration_state.fhist(post_poll_acceleration_state.nf) = fnew_real;
        if acceleration_configuration.output_xhist
            post_poll_acceleration_state.xhist(:, post_poll_acceleration_state.nf) = xnew;
            if ~is_valid
                post_poll_acceleration_state.invalid_points = [ ...
                    post_poll_acceleration_state.invalid_points, xnew];
            end
        end
        if fnew < fbest
            xbest = xnew;
            fbest = fnew;
            best_direction = momentum_direction;
        else
            break;
        end
        if fnew <= acceleration_configuration.ftarget
            target_reached = true;
            break;
        end
    end
end

% Commit the best point found by whichever directional search succeeded and,
% when enabled, admit its direction to productive-direction memory.
if fbest < post_poll_acceleration_state.fbase
    acceleration_succeeded = true;
    post_poll_acceleration_state.xbase = xbest;
    post_poll_acceleration_state.fbase = fbest;
    if acceleration_configuration.use_productive_direction_memory ...
            && ~isempty(best_direction)
        post_poll_acceleration_state.productive_direction_memory = ...
            admit_productive_direction_to_memory( ...
                post_poll_acceleration_state.productive_direction_memory, ...
                best_direction, pattern_step, ...
                acceleration_configuration.productive_direction_memory_size);
    end
end

end
