function [productive_direction_memory_state, target_reached] = ...
    run_productive_direction_memory_phase(fun, productive_direction_memory_state, ...
        acceleration_configuration, alpha_average)
%RUN_PRODUCTIVE_DIRECTION_MEMORY_PHASE Search retained directions before polling.
%
%   [PRODUCTIVE_DIRECTION_MEMORY_STATE, TARGET_REACHED] =
%   RUN_PRODUCTIVE_DIRECTION_MEMORY_PHASE(FUN,
%   PRODUCTIVE_DIRECTION_MEMORY_STATE, ACCELERATION_CONFIGURATION,
%   ALPHA_AVERAGE) considers the retained productive-direction memory entries
%   in their stored order before the regular block-polling phase. Each entry
%   contains a normalized productive direction and a successful step length
%   stored with that direction. For each retained direction, the trial step is
%   the larger of ALPHA_AVERAGE and the step stored with that direction.
%
%   The stored step preserves a successful direction-specific search scale,
%   whereas ALPHA_AVERAGE reflects the current overall polling scale. Taking
%   the larger value prevents the memory search from trying that direction
%   below either reference scale. A retained direction need not belong to one
%   particular block, so the mean of the current per-block polling step sizes
%   provides a single direction-independent measure of the current scale.
%
%   The first improving direction is accepted. Unless that accepted memory
%   trial already reaches the target, the phase evaluates at most two farther
%   points along the same direction and then promotes the direction to the
%   front of memory. The phase then stops.
%
%   fun                                Objective function.
%
%   PRODUCTIVE_DIRECTION_MEMORY_STATE is an input/output structure containing
%   the mutable solver state used by this phase. Its fields are listed below.
%
%   xbase                              Current base point, an n-by-1 real vector. It is
%                                      updated when this phase accepts an improving point.
%   fbase                              Objective value used for comparisons at xbase. It is
%                                      updated together with xbase.
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
%                                      step. A successful direction is moved to the
%                                      highest-priority first position.
%
%   ACCELERATION_CONFIGURATION is a read-only structure containing the options
%   needed by this phase. Its fields control whether the phase runs, the common
%   evaluation budget and target, and optional point-history recording.
%
%   use_productive_direction_memory    Whether this phase is enabled.
%   MaxFunctionEvaluations             Total objective-evaluation budget.
%   ftarget                            Target function value.
%   output_xhist                       Whether point and invalid-point histories are recorded.
%
%   alpha_average                      Mean of the current per-block polling step sizes. It is
%                                      the direction-independent current-scale reference used
%                                      when selecting a memory trial step.
%   target_reached                     True exactly when this phase evaluates or extrapolates
%                                      to a point whose comparison value is no larger than
%                                      ftarget. The caller owns the corresponding terminate
%                                      and exitflag updates.
%
%   The phase stops when the target is reached, an improving retained
%   direction has been processed, every retained direction has been tried,
%   or the evaluation budget is exhausted. Evaluation order, histories, and
%   invalid-value handling follow the main solver conventions.

target_reached = false;

% Try the productive directions recorded from successful polling steps.
if acceleration_configuration.use_productive_direction_memory && ...
        ~isempty(productive_direction_memory_state.productive_direction_memory) ...
        && productive_direction_memory_state.nf ...
            < acceleration_configuration.MaxFunctionEvaluations
    for i = 1:numel(productive_direction_memory_state.productive_direction_memory)
        if productive_direction_memory_state.nf ...
                >= acceleration_configuration.MaxFunctionEvaluations
            break;
        end
        direction = ...
            productive_direction_memory_state.productive_direction_memory(i).direction;
        step = max(alpha_average, ...
            productive_direction_memory_state.productive_direction_memory(i).step);
        xnew = productive_direction_memory_state.xbase + step * direction;
        [fnew, fnew_real, is_valid] = eval_fun(fun, xnew);
        productive_direction_memory_state.nf = ...
            productive_direction_memory_state.nf + 1;
        productive_direction_memory_state.fhist( ...
            productive_direction_memory_state.nf) = fnew_real;
        if acceleration_configuration.output_xhist
            productive_direction_memory_state.xhist(:, ...
                productive_direction_memory_state.nf) = xnew;
            if ~is_valid
                productive_direction_memory_state.invalid_points = [ ...
                    productive_direction_memory_state.invalid_points, xnew];
            end
        end
        if fnew <= acceleration_configuration.ftarget
            target_reached = true;
        end
        if fnew < productive_direction_memory_state.fbase
            productive_direction_memory_state.xbase = xnew;
            productive_direction_memory_state.fbase = fnew;
            if target_reached
                break;
            end
            % Starting from the accepted memory trial, probe at most two
            % farther points along the same direction. The first extrapolation
            % step is twice the accepted trial step and is doubled again only
            % after a further improvement. The helper also updates the
            % evaluation count and recorded histories.
            [productive_direction_memory_state.xbase, ...
                productive_direction_memory_state.fbase, ...
                productive_direction_memory_state.nf, ...
                productive_direction_memory_state.fhist, ...
                productive_direction_memory_state.xhist, ...
                productive_direction_memory_state.invalid_points] = ...
                try_productive_direction_extrapolation( ...
                    fun, productive_direction_memory_state.xbase, ...
                    productive_direction_memory_state.fbase, direction, step * 2.0, ...
                    productive_direction_memory_state.nf, ...
                    acceleration_configuration.MaxFunctionEvaluations, ...
                    acceleration_configuration.ftarget, ...
                    productive_direction_memory_state.fhist, ...
                    productive_direction_memory_state.xhist, ...
                    productive_direction_memory_state.invalid_points, ...
                    acceleration_configuration.output_xhist);
            % Move the successful retained direction from its old position to
            % the front of memory and store the accepted memory-trial step, so
            % that this direction has the highest priority the next time the
            % memory is searched.
            productive_direction_memory_state.productive_direction_memory(i) = [];
            productive_direction_memory_state.productive_direction_memory = ...
                prepend_productive_direction_memory( ...
                    productive_direction_memory_state.productive_direction_memory, ...
                    direction, step);
            if productive_direction_memory_state.fbase ...
                    <= acceleration_configuration.ftarget
                target_reached = true;
            end
            break;
        end
        if target_reached
            break;
        end
    end
end

end
