function weighted_integral = integrate(curve, weights)
% This function integrates one curve to calculate the performance of the solver.

weighted_integral = 0;

% Since the stair function is right continuous, when we calculate the performance, 
% we need to multiply the height of the left point by the length of the stair.
for i = 2 : size(curve, 2)
    weighted_integral = weighted_integral + (curve(1, i) - curve(1, i-1))...
        *curve(2, i-1) * weights(curve(1, i-1));
end

end

