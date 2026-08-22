function alpha_coord = get_bds_without_acceleration_reference_auto_alpha_init(x0, StepTolerance, c_x, c_tau)
%GET_AUTO_ALPHA_INIT Compute coordinate-wise automatic initial steps.

validate_coefficient(c_x, 'c_x');
validate_coefficient(c_tau, 'c_tau');

if ~(isnumeric(x0) && isreal(x0) && isvector(x0) && ...
        all(isfinite(x0(:))))
    error('BDS:get_auto_alpha_init:InvalidX0', ...
        'x0 must be a real numeric vector.');
end
if ~(isnumeric(StepTolerance) && isreal(StepTolerance) && ...
        (isscalar(StepTolerance) || isvector(StepTolerance)) && ...
        all(isfinite(StepTolerance(:))) && all(StepTolerance(:) >= 0))
    error('BDS:get_auto_alpha_init:InvalidStepTolerance', ...
        'StepTolerance must be a nonnegative real scalar or vector.');
end
abs_x0 = abs(x0(:));
step_tolerance = StepTolerance(:);
if isscalar(step_tolerance)
    step_tolerance = repmat(step_tolerance, size(abs_x0));
elseif numel(step_tolerance) ~= numel(abs_x0)
    error('BDS:get_auto_alpha_init:InvalidStepToleranceLength', ...
        'A vector StepTolerance must have the same length as x0.');
end

alpha_coord = max(c_x * abs_x0, c_tau * step_tolerance);
zero_coordinate = (abs_x0 == 0);
alpha_coord(zero_coordinate) = max( ...
    1, c_tau * step_tolerance(zero_coordinate));
if any(~isfinite(alpha_coord)) || any(alpha_coord <= 0)
    error('BDS:get_auto_alpha_init:InvalidResult', ...
        'The automatic initial steps must be finite and positive.');
end

end

function validate_coefficient(value, name)

if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
        isfinite(value) && value > 0)
    error('BDS:get_auto_alpha_init:InvalidCoefficient', ...
        '%s must be a finite positive real scalar.', name);
end

end
