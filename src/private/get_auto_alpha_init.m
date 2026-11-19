function alpha_coord = get_auto_alpha_init(x0, StepTolerance)
%GET_AUTO_ALPHA_INIT Initial steps for the standard coordinate blocks.
%
%   ALPHA_COORD = GET_AUTO_ALPHA_INIT(X0, STEPTOLERANCE) uses one coordinate
%   per block. A nonzero coordinate contributes abs(X0(i)); a zero coordinate
%   contributes the unit step because it supplies no information about scale.
%   Each step is bounded below by the corresponding StepTolerance.
%
%   The caller verifies the coordinate basis and block partition before calling
%   this helper. X0 is a finite real column vector and STEPTOLERANCE contains
%   validated nonnegative block tolerances. General bases and grouped blocks
%   require explicit numeric initial steps in the current implementation.

alpha_coord = max(abs(x0), StepTolerance);
zero_coordinate = (x0 == 0);
alpha_coord(zero_coordinate) = max(1, alpha_coord(zero_coordinate));
if any(~isfinite(alpha_coord)) || any(alpha_coord <= 0)
    error('BDS:get_auto_alpha_init:InvalidResult', ...
        'The initial steps must be finite and positive.');
end
end
