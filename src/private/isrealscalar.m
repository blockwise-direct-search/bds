function isrs = isrealscalar(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isrealscalar.m,
%which is written by Zaikun ZHANG.
%ISREALSCALAR checks whether x is a real scalar.
%   N.B.: isrealscalar([]) = FALSE, isrealscalar(nan) = TRUE, isrealscalar(inf) = TRUE!!!

isrs = isnumeric(x) && isreal(x) && isscalar(x);

return
