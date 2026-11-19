function isis = isintegerscalar(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isintegerscalar.m,
%which is written by Zaikun ZHANG.
%ISINTEGERSCALAR checks whether x is an integer scalar.
%   N.B.: isintegerscalar([]) = FALSE, isintegerscalar(nan) = FALSE, isintegerscalar(inf) = FALSE !!!

isis = isrealscalar(x) && (rem(x, 1) == 0);

return
