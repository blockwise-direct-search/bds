function [best_point, best_function_value, num_function_evaluations, ...
    function_value_history, point_history, invalid_points] = ...
    try_productive_direction_extrapolation(fun, base_point, base_function_value, ...
        direction, extrapolation_step, num_function_evaluations, ...
        max_function_evaluations, target_function_value, function_value_history, ...
        point_history, invalid_points, output_point_history)
%TRY_PRODUCTIVE_DIRECTION_EXTRAPOLATION Probe beyond an accepted memory step.
%
%   [BEST_POINT, BEST_FUNCTION_VALUE, NUM_FUNCTION_EVALUATIONS,
%   FUNCTION_VALUE_HISTORY, POINT_HISTORY, INVALID_POINTS] =
%   TRY_PRODUCTIVE_DIRECTION_EXTRAPOLATION(FUN, BASE_POINT,
%   BASE_FUNCTION_VALUE, DIRECTION, EXTRAPOLATION_STEP,
%   NUM_FUNCTION_EVALUATIONS, MAX_FUNCTION_EVALUATIONS,
%   TARGET_FUNCTION_VALUE, FUNCTION_VALUE_HISTORY, POINT_HISTORY,
%   INVALID_POINTS, OUTPUT_POINT_HISTORY) performs at most two additional
%   evaluations along an already accepted productive direction.
%
%   fun                                Objective function.
%   base_point                         Accepted point from which extrapolation begins. It
%                                      initializes best_point.
%   base_function_value                Comparison value at base_point. It initializes
%                                      best_function_value.
%   direction                          Productive direction used by every probe.
%   extrapolation_step                 Step of the first probe. After an improving probe that
%                                      does not reach the target, it is doubled for the next
%                                      and final probe.
%   num_function_evaluations           Evaluation count at input and output. It is incremented
%                                      after every evaluation performed here.
%   max_function_evaluations           Total evaluation budget. No candidate is evaluated after
%                                      the budget is exhausted.
%   target_function_value              Target that stops extrapolation after an improving
%                                      candidate no larger than this value.
%   function_value_history             Input/output history. Each raw objective value is stored
%                                      at the corresponding updated evaluation-count index.
%   point_history                      Input/output point history. It is updated only when
%                                      output_point_history is true.
%   invalid_points                     Input/output invalid-point history. It is extended only
%                                      when output_point_history is true.
%   output_point_history               Whether point and invalid-point histories are recorded.
%
%   best_point                         Best accepted point. It changes only after a strict
%                                      improvement.
%   best_function_value                Comparison value at best_point. Extrapolation stops at
%                                      the first non-improving candidate.

best_point = base_point;
best_function_value = base_function_value;
for k = 1:2
    if num_function_evaluations >= max_function_evaluations
        break;
    end
    candidate_point = best_point + extrapolation_step * direction;
    [candidate_function_value, raw_candidate_function_value, is_valid] = ...
        eval_fun(fun, candidate_point);
    num_function_evaluations = num_function_evaluations + 1;
    function_value_history(num_function_evaluations) = raw_candidate_function_value;
    if output_point_history
        point_history(:, num_function_evaluations) = candidate_point;
        if ~is_valid
            invalid_points = [invalid_points, candidate_point];
        end
    end
    if candidate_function_value < best_function_value
        best_point = candidate_point;
        best_function_value = candidate_function_value;
        if candidate_function_value <= target_function_value
            break;
        end
        extrapolation_step = extrapolation_step * 2.0;
    else
        break;
    end
end

end
