function [isrv, len] = isrealvector(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isrealvector.m,
%which is written by Zaikun ZHANG.
%ISREALVECTOR checks whether x is a real vector. If yes, it returns len = length(x); otherwise,
%len = nan.
%   N.B.: isrealvector([]) = true.
if isrealrow(x) || isrealcolumn(x)
    isrv = true;
    len = length(x);
else
    isrv = false;
    len = nan;
end
return
