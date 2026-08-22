function [xbase, fbase, nf, fhist, xhist, invalid_points] = ...
    try_productive_direction_extrapolation(fun, xbase, fbase, direction, ...
        extrapolation_step, nf, MaxFunctionEvaluations, ftarget, fhist, ...
        xhist, invalid_points, output_xhist)
%TRY_PRODUCTIVE_DIRECTION_EXTRAPOLATION Probe beyond an accepted memory step.
%
%   [XBASE, FBASE, NF, FHIST, XHIST, INVALID_POINTS] =
%   TRY_PRODUCTIVE_DIRECTION_EXTRAPOLATION(FUN, XBASE, FBASE, DIRECTION,
%   EXTRAPOLATION_STEP, NF, MAXFUNCTIONEVALUATIONS, FTARGET, FHIST, XHIST,
%   INVALID_POINTS, OUTPUT_XHIST) performs at most two additional evaluations
%   along an already accepted productive direction.
%
%   fun                                Objective function.
%   xbase                              Accepted point from which extrapolation begins. It is
%                                      updated after every strict improvement.
%   fbase                              Comparison value at xbase. It is updated together with
%                                      xbase.
%   direction                          Productive direction used by every probe.
%   extrapolation_step                 Step of the first probe. After an improving probe that
%                                      does not reach the target, it is doubled for the next
%                                      and final probe.
%   nf                                 Global evaluation count at input and output. It is
%                                      incremented after every evaluation performed here.
%   MaxFunctionEvaluations             Total evaluation budget. No candidate is evaluated after
%                                      the budget is exhausted.
%   ftarget                            Target that stops extrapolation after an improving
%                                      candidate no larger than this value.
%   fhist                              Input/output function-value history. Each raw objective
%                                      value is stored at the corresponding updated nf index.
%   xhist                              Input/output point history. It is updated only when
%                                      output_xhist is true.
%   invalid_points                     Input/output invalid-point history. It is extended only
%                                      when output_xhist is true.
%   output_xhist                       Whether point and invalid-point histories are recorded.
%
%   XBASE, FBASE, NF, FHIST, XHIST, and INVALID_POINTS return the updated
%   solver state. Extrapolation stops at the first non-improving candidate,
%   after reaching FTARGET, after two probes, or when the evaluation budget
%   is exhausted.

for k = 1:2
    if nf >= MaxFunctionEvaluations
        break;
    end
    candidate_point = xbase + extrapolation_step * direction;
    [candidate_function_value, raw_candidate_function_value, is_valid] = ...
        eval_fun(fun, candidate_point);
    nf = nf + 1;
    fhist(nf) = raw_candidate_function_value;
    if output_xhist
        xhist(:, nf) = candidate_point;
        if ~is_valid
            invalid_points = [invalid_points, candidate_point];
        end
    end
    if candidate_function_value < fbase
        xbase = candidate_point;
        fbase = candidate_function_value;
        if candidate_function_value <= ftarget
            break;
        end
        extrapolation_step = extrapolation_step * 2.0;
    else
        break;
    end
end
end
