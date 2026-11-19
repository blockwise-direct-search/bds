function [xbest, fbest, exitflag, output] = extrapolate( ...
    fun, y, fy, direction, step, maxfun, ftarget, output_xhist, observed_points, observed_values)
%EXTRAPOLATE Evaluate up to five positions along one given unit direction.
%   All positions use the same base Y with distances STEP times [1,2,4,8,16].
%   Stop at the first rejection. Reuse values from identical points.
%   Histories and the evaluation count include only new evaluations.

if nargin < 9
    observed_points = zeros(numel(y), 0);
    observed_values = [];
end
xbest = y;
fbest = fy;
exitflag = [];
output = struct('nf', 0, 'fhist', [], 'xhist', [], ...
    'invalid_points', [], 'observed_points', observed_points, ...
    'observed_values', observed_values);
if maxfun <= 0
    return;
end
for j = 1:5
    xnew = y + (2 ^ (j - 1)) * step * direction;
    cached = find(all(output.observed_points == xnew, 1), 1);
    if isempty(cached)
        if output.nf >= maxfun
            exitflag = get_exitflag('MAXFUN_REACHED');
            break;
        end
        [fnew, raw_value, valid] = eval_fun(fun, xnew);
        output.observed_points(:, end + 1) = xnew;
        output.observed_values(end + 1) = fnew;
        output.nf = output.nf + 1;
        output.fhist(output.nf) = raw_value;
        if output_xhist
            output.xhist(:, output.nf) = xnew;
            if ~valid
                output.invalid_points(:, end + 1) = xnew;
            end
        end
    else
        fnew = output.observed_values(cached);
    end
    accepted = fnew < fbest;
    if accepted
        xbest = xnew;
        fbest = fnew;
    end
    if fnew <= ftarget
        exitflag = get_exitflag('FTARGET_REACHED');
    elseif output.nf >= maxfun
        exitflag = get_exitflag('MAXFUN_REACHED');
    end
    if ~accepted || ~isempty(exitflag)
        break;
    end
end
end
