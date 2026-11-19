function iscs = ischarstr(x)
%This file is cited from https://github.com/libprima/prima/blob/main/matlab/tests/private/ischarstr.m,
%which is written by Zaikun ZHANG.
%ISCHARSTR checks whether an input is a "char" or "string".

iscs = (isa(x, "char") || isa(x, "string"));
