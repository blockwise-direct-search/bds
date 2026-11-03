function [state, stop] = gradient_stop_update(state, gradient_norm, error_scale, consistency, config, poll_failures)
%GRADIENT_STOP_UPDATE Update only the experimental gradient stopping state.
%
%   state          Fixed reference and subsequent gradient window.
%   gradient_norm  Norm of the current valid gradient estimate.
%   error_scale    Error estimate computed with L_H=1.
%   consistency    Same-point discrepancy, used only by the threshold-only ablation.
%   config         Gradient-only parameters from gradient_experiment_config.
%   poll_failures  Current number of consecutive complete polling failures.

stop = false;
error_estimate = config.lipschitz * error_scale;
upper_norm = gradient_norm + error_estimate;
if ~isfinite(upper_norm) || error_estimate < 0
    return;
end
if isnan(state.reference)
    if strcmp(config.rule, 'threshold_only')
        reliable = consistency <= 0.1 ...
            && error_estimate < max(1e-3, 0.1 * gradient_norm);
    else
        reliable = poll_failures >= config.minimum_failures && error_estimate < max(config.reference_absolute, ...
            config.reference_fraction * upper_norm);
    end
    if reliable
        state.reference = upper_norm;
    end
else
    state.window = [state.window(2:end), upper_norm];
end
if ~isnan(state.reference)
    stop = all(state.window < config.tolerance * min(1, state.reference)) ...
        || all(state.window < config.beta * config.tolerance * max(1, state.reference));
end

end
