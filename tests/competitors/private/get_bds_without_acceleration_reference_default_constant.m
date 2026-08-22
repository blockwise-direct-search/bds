function constant_value = get_bds_without_acceleration_reference_default_constant(constant_name)
switch constant_name
    case "MaxFunctionEvaluations_dim_factor"
        constant_value = 500;
    case "ftarget"
        constant_value = -inf;
    case "StepTolerance"
        constant_value = 1e-6;
    case "use_function_value_stop"
        constant_value = false;
    case "func_window_size"
        constant_value = 20;
    case "func_tol"
        constant_value = 1e-6;
    case "use_estimated_gradient_stop"
        constant_value = false;
    case "grad_window_size"
        constant_value = 1;
    case "grad_tol"
        constant_value = 1e-2;
    case "lipschitz_constant"
        constant_value = 1e3;
    case "use_gradient_reference_consistency"
        constant_value = true;
    case "grad_reference_finite_difference_error_tol"
        constant_value = 1/30;
    case "block_visiting_pattern"
        constant_value = "sorted";
    case "alpha_init"
        constant_value = 1;
    case "expand"
        constant_value = 1.8;
    case "shrink"
        constant_value = 0.5;
    case "expand_noisy"
        constant_value = 1.5;
    case "shrink_noisy"
        constant_value = 0.5;
    case "is_noisy"
        constant_value = false;
    case "forcing_function"
        constant_value = @(alpha) alpha^2;
    case "reduction_factor"
        constant_value = [0, eps, eps];
    case "polling_inner"
        constant_value = "opportunistic";
    case "cycling_inner"
        constant_value = 1;
    case "seed"
        constant_value = "shuffle";
    case "output_xhist"
        constant_value = false;
    case "output_alpha_hist"
        constant_value = false;
    case "output_block_hist"
        constant_value = false;
    case "output_grad_hist"
        constant_value = false;
    case "iprint"
        constant_value = 0;
    case "debug_flag"
        constant_value = false;
    otherwise
        error("Unknown constant name '%s'.", constant_name);
end
end
