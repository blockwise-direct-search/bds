function [xbest, fbest, exitflag, output, momentum] = accelerate( ...
    fun, y, fy, pattern_direction, step, momentum, step_floor, maxfun, ftarget, output_xhist)
%ACCELERATE Search from the accepted polling point y along two directions.
%   Try the current block's candidate momentum first and then the pattern.
%   Both searches use the same base point and share values at identical
%   points. Save the candidate momentum only if the pattern improves on fy.
candidate_momentum = 0.6 * momentum + (1 - 0.6) * pattern_direction;
momentum_norm = norm(candidate_momentum);
xbest = y;
fbest = fy;
exitflag = [];
output = struct('nf', 0, 'fhist', [], 'xhist', zeros(numel(y), 0), ...
    'invalid_points', []);
observed_points = zeros(numel(y), 0);
observed_values = [];

for strategy = ["momentum", "pattern"]
    if strategy == "momentum"
        if momentum_norm <= step_floor
            continue;
        end
        direction = candidate_momentum / momentum_norm;
    else
        direction = pattern_direction;
    end
    [x, f, exitflag, search] = extrapolate(fun, y, fy, direction, step, ...
        maxfun - output.nf, ftarget, output_xhist, observed_points, observed_values);
    output.nf = output.nf + search.nf;
    output.fhist = [output.fhist, search.fhist];
    if output_xhist
        output.xhist = [output.xhist, search.xhist];
        output.invalid_points = [output.invalid_points, search.invalid_points];
    end
    if strategy == "momentum"
        observed_points = search.observed_points;
        observed_values = search.observed_values;
    elseif f < fy
        momentum = candidate_momentum;
    end
    if f < fbest
        xbest = x;
        fbest = f;
    end
    if ~isempty(exitflag)
        break;
    end
end
end
