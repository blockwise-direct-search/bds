function isls = islogicalscalar(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/islogicalscalar.m,
%which is written by Zaikun ZHANG.
%ISLOGICALSCALAR checks whether x is a logical scalar, including 0 and 1.
%   N.B.: islogicalscalar([]) = FALSE !!!

if isa(x, "logical") && isscalar(x)
    isls = true;
elseif isrealscalar(x) && (x == 1 || x == 0) % !!!!!!
    isls = true;
else
    isls = false;
end

return
