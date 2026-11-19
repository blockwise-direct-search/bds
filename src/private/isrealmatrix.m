function [isrm, m, n] = isrealmatrix(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isrealmatrix.m,
%which is written by Zaikun ZHANG.
%ISREALMATRIX checks whether x is a real matrix.
%   N.B.: isrealmatrix([]) = true.

if isempty(x)
    isrm = true;
    m = 0;
    n = 0;
elseif isnumeric(x) && isreal(x) && ismatrix(x)
    isrm = true;
    [m, n] = size(x);
else
    isrm = false;
    m = nan;
    n = nan;
end
return
