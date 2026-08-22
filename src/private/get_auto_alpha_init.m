function alpha_coord = get_auto_alpha_init(x0, StepTolerance, c_x, c_tau)
%GET_AUTO_ALPHA_INIT Compute coordinate-wise automatic initial steps.
%
%   ALPHA_COORD = GET_AUTO_ALPHA_INIT(X0, STEPTOLERANCE, C_X, C_TAU)
%   computes the initial polling step for each coordinate. For a nonzero
%   coordinate x0(i), the rule is
%
%       alpha_coord(i) = max(c_x*abs(x0(i)), ...
%                            c_tau*StepTolerance(i)).
%
%   C_X weights the scale supplied by the initial point, and C_TAU weights
%   the lower scale supplied by the step tolerance (tau). An exact zero
%   coordinate supplies no positive coordinate scale, so its first term is
%   replaced by the neutral BDS unit step:
%
%       alpha_coord(i) = max(1, c_tau*StepTolerance(i)).
%
%   The coefficients remain explicit so that this helper represents the
%   parameterized rule studied during automatic-step tuning. The production
%   caller currently uses the frozen choice (c_x, c_tau) = (1, 1).
%
%   X0 and STEPTOLERANCE are prevalidated by set_options as
%   finite real column vectors of the same length, with nonnegative entries
%   in STEPTOLERANCE.

validate_coefficient(c_x, 'c_x');
validate_coefficient(c_tau, 'c_tau');

abs_x0 = abs(x0);
alpha_coord = max(c_x * abs_x0, c_tau * StepTolerance);
zero_coordinate = (abs_x0 == 0);
alpha_coord(zero_coordinate) = max( ...
    1, c_tau * StepTolerance(zero_coordinate));
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
