function verify_preconditions(fun, x0, options)
%VERIFY_PRECONDITIONS verifies whether the inputs are in valid form.

if ~(isa(fun, 'function_handle') || ischarstr(fun))
    error("fun should be a function handle or a function name.");
end

if ~isrealvector(x0)
    error("x0 should be a real vector.");
end

if nargin < 3 || ~isstruct(options)
    error("options should be a structure.");
end

end
