function is_numvec = isnumvec(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/isnumvec.m,
%which is written by Zaikun ZHANG.
%ISNUMVEC verifies whether x is a number vector.

is_numvec = isnumeric(x) && isvector(x);
end
