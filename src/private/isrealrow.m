function [isrr, len] = isrealrow(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isrealrow.m,
%which is written by Zaikun ZHANG.
%isrealrow([]) = true
%ISREALROW checks whether x is a real row. If yes, it returns len = length(x); otherwise, len = nan.
%   N.B.: isrealrow([]) = true.
if isempty(x)
    isrr = true;
    len = 0;
elseif isnumeric(x) && isreal(x) && isvector(x) && size(x, 1) == 1
    isrr = true;
    len = length(x);
else
    isrr = false;
    len = nan;
end
return
