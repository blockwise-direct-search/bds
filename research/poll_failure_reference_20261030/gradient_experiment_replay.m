function prediction = gradient_experiment_replay(trace, config, function_stop)
%GRADIENT_EXPERIMENT_REPLAY Independently predict stopping on a complete baseline.
% Events: iteration, calls, function hit, gradient norm, unit error,
% same-point discrepancy, incumbent evaluation index, original L_H=1000 error.
% The last two columns are explicit polling failure and its recorded run length.

events = trace.events;
reference = nan;
reference_call = nan;
reference_iteration = nan;
reference_error_ratio = nan;
reference_failures = nan;
poll_failures = 0;
recent = [];
gradient_event = inf;
for k = 1:size(events, 1)
    if events(k, 9)
        poll_failures = poll_failures + 1;
    else
        poll_failures = 0;
    end
    assert(poll_failures == events(k, 10), 'GradientExperiment:FailureCounterMismatch', ...
        'The recorded polling failure count differs from the independently reconstructed count.');
    gradient_norm = events(k, 4);
    if ~isfinite(gradient_norm)
        continue;
    end
    if strcmp(config.rule, 'legacy')
        error_estimate = events(k, 8);
    else
        error_estimate = config.lipschitz * events(k, 5);
    end
    value = gradient_norm + error_estimate;
    if ~isfinite(value) || error_estimate < 0
        continue;
    end
    if isnan(reference)
        if ismember(config.rule, {'legacy', 'threshold_only'})
            acceptable = events(k, 6) <= 0.1 ...
                && error_estimate < max(1e-3, 0.1 * gradient_norm);
        else
            acceptable = poll_failures >= config.minimum_failures ...
                && error_estimate < max(config.reference_absolute, ...
                config.reference_fraction * value);
        end
        if acceptable
            reference = value;
            reference_call = events(k, 2);
            reference_iteration = events(k, 1);
            reference_error_ratio = error_estimate / value;
            reference_failures = poll_failures;
        end
        continue;
    end
    recent(end+1) = value;
    if numel(recent) < config.window
        continue;
    end
    maximum = max(recent(end-config.window+1:end));
    if strcmp(config.rule, 'legacy')
        threshold = config.tolerance * max(1, reference);
    else
        threshold = max(config.tolerance * min(1, reference), ...
            config.beta * config.tolerance * max(1, reference));
    end
    if maximum < threshold
        gradient_event = k;
        break;
    end
end
function_event = inf;
if function_stop
    first = find(events(:, 3) ~= 0, 1);
    if ~isempty(first)
        function_event = first;
    end
end
event = min(gradient_event, function_event);
prediction = struct('calls', trace.calls, 'output_index', trace.output_index, ...
    'reference', reference, 'reference_call', reference_call, ...
    'reference_iteration', reference_iteration, 'reference_error_ratio', reference_error_ratio, ...
    'reference_failures', reference_failures, ...
    'gradient_event', gradient_event, 'function_event', function_event, 'event', event);
if isfinite(event)
    prediction.calls = events(event, 2);
    prediction.output_index = events(event, 7);
end

end
