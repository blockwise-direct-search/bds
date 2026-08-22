function constant_value = get_default_constant(constant_name)
%GET_DEFAULT_CONSTANT Defaults for BDS.
%
%   CONSTANT_VALUE = GET_DEFAULT_CONSTANT(CONSTANT_NAME)
%   returns the internal default selected by CONSTANT_NAME.
%
%   constant_name                      Text scalar naming an option or dimension-independent
%                                      constant handled below. An unknown name raises an error.
%   constant_value                     Default with the type and shape required by the named
%                                      option or constant.
%
%   These defaults define the production BDS behavior. The caller may
%   combine a returned constant with problem-dependent information, such as
%   the dimension, before using it as a public default. Explicit nonempty user
%   options remain authoritative.

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
        % For theta=shrink=0.5 this reproduces the historical raw threshold 0.1.
        constant_value = 1/30;
    case "block_visiting_pattern"
        constant_value = "sorted";
    case "seed"
        constant_value = "shuffle";
    case "alpha_init"
        constant_value = 1;
    case "expand"
        constant_value = 2.0;
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
    case "productive_direction_memory_size_cap"
        constant_value = 5;
    case "momentum_decay"
        constant_value = 0.6;
    case "use_productive_direction_memory"
        constant_value = true;
    case "use_iteration_pattern_step"
        constant_value = true;
    case "use_momentum_extrapolation"
        constant_value = true;
    otherwise
        error("Unknown BDS constant name '%s'.", constant_name);
end
end
