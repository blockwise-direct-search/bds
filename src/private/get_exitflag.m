function [exitflag] = get_exitflag(information)
%GET_EXITFLAG gets the EXITFLAG of BDS.
%   FTARGET_REACHED                 Function value is smaller than or equal to FTARGET.
%   MAXFUN_REACHED                  The number of function evaluations reaches MAXFUN.
%   MAXIT_REACHED                   The number of iterations reaches MAXIT.
%   SMALL_ALPHA                     Step size is below StepTolerance. In the case of variable step
%                                   sizes, SMALL_ALPHA indicates the largest component of step sizes
%                                   is below StepTolerance.
%   SMALL_OBJECTIVE_CHANGE          The change of the function value is small.
%   SMALL_ESTIMATE_GRADIENT         The estimated gradient is small.

% Check whether INFORMATION is a char or string.
if ~ischarstr(information)
    error("Information is not a char or string.");
end

switch information
    case "FTARGET_REACHED"
        exitflag = 0;
    case "MAXFUN_REACHED"
        exitflag = 1;
    case "MAXIT_REACHED"
        exitflag = 2;
    case "SMALL_ALPHA"
        exitflag = 3;
    case "SMALL_OBJECTIVE_CHANGE"
        exitflag = 4;
    case "SMALL_ESTIMATE_GRADIENT"
        exitflag = 5;
    otherwise
        exitflag = nan;
end

if isempty(exitflag) || isnan(exitflag)
    exitflag = nan;
    disp("New break condition happens.");
end

% Check whether EXITFLAG is an integer or not.
if ~isintegerscalar(exitflag)
    error("Exitflag is not an integer.");
end

end
