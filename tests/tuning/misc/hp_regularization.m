    function d = hp_regularization(x)
% HP_REGULARIZATION Regularization function for calculating the residual value
% of the point x concerning the constraints.
    y = log(x + eps);
    resid = [
        log(1 + eps) - y(1);
        log(2 * eps) - y(2);
        y(2);
        % log(eps) - y(3);
        % log(2 * eps) - y(4);
        % y(3) - y(4);
        % y(4) - y(5);
    ];
    d = norm(max(resid, 0));
    return;
end