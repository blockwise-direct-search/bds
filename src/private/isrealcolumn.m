function [isrc, len] = isrealcolumn(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isrealcolumn.m,
%which is written by Zaikun ZHANG.
%ISREALCOLUMN checks whether x is a real column. If yes, it returns len = length(x); otherwise,
%len = nan.
%   N.B.: isrealcolumn([]) = true

if isempty(x)
    isrc = true;
    len = 0;
elseif isnumeric(x) && isreal(x) && isvector(x) && (size(x, 2) == 1)
    isrc = true;
    len = length(x);
else
    isrc = false;
    len = nan;
end
return
