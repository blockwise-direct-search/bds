function [f, f_real, is_valid] = eval_fun(fun, x)
%EVAL_FUN evaluates function FUN at point X, returning f and f_real.
%   f_real is the real function value (raw output), potentially NaN or Inf.
%   f is the moderated version used by the optimization algorithm.
%   is_valid is a boolean indicating whether the evaluation was successful.

is_valid = true;

try
    f_real = fun(x);
catch
    warning('The function evaluation failed.');
    f_real = nan;
    is_valid = false;
end

% Separate the algorithmic value (f) from the historical value (f_real).
% We initialize f as f_real.
f = f_real;

% Handling NaN:
% If the function failed (NaN), we must tell the algorithm this is a "bad" point 
% by setting f to Inf. However, we keep f_real as NaN so the history reflects 
% the actual evaluation failure.
if isnan(f_real)
    f = inf;
    is_valid = false;
end

% Handling Inf/Huge values:
% We do NOT truncate huge values or Inf. Direct search handles them natively.
% So if f_real is 1e50 or Inf, f remains 1e50 or Inf.
% This ensures f and f_real are consistent in valid regions, but distinct 
% (Inf vs NaN) in failure regions.

end

% function [f, f_real, is_valid] = eval_fun(fun, x)
% %EVAL_FUN evaluates function FUN at point X, returning f and f_real.
% %   f_real is the real function value, while f is a moderated version of f_real.
% %   The moderation is to handle nan, huge values, and evaluation failures. The 
% %   algorithm will operate on f, while f_real is used for recording the history.

% is_valid = true;

% try
%     f_real = fun(x);
% catch
%     warning('The function evaluation failed.');
%     f_real = nan;
%     is_valid = false;
% end

% % Apply the moderate extreme barrier to handle nan, huge values, and evaluation failures.
% % See 4.5 of "PDFO: A Cross-Platform Package for Powell's Derivative-Free Optimization Solvers" 
% % by Tom M. Ragonneau and Zaikun Zhang.
% if isnan(f_real)
%     f_real = inf;
% end
% f = min([f_real, 1e30, sqrt(realmax())]);

% end

% % TODO: return those points where the function evaluation failed or return nan.