function gradient_experiment_unit_test()
%GRADIENT_EXPERIMENT_UNIT_TEST Check reference, window and threshold boundaries.

configs = gradient_experiment_config();
c = configs(1);
c.lipschitz = 1;
c.tolerance = 1e-2;
c.beta = 1e-3;
c.window = 1;
fresh = struct('reference', nan, 'window', nan(1, c.window));
[s, stop] = gradient_stop_update(fresh, 0, 5e-4, inf, c, 1);
assert(~stop && s.reference == 5e-4, 'Absolute reference fallback failed.');
[s, stop] = gradient_stop_update(s, 0, 1e-6, inf, c, 1);
assert(stop, 'Absolute stopping fallback failed.');
[s, stop] = gradient_stop_update(fresh, 1, 1, 0, c, 1);
assert(~stop && isnan(s.reference), 'Unreliable reference accepted.');
[s, stop] = gradient_stop_update(fresh, 10, 0.5, inf, c, 1);
assert(~stop && s.reference == 10.5, 'Relative reference rejected.');
[s, stop] = gradient_stop_update(s, 1e-3, 0, inf, c, 1);
assert(stop && s.reference == 10.5, 'Reference changed after initialization.');
[s, stop] = gradient_stop_update(fresh, 1, inf, 0, c, 1);
assert(~stop && isnan(s.reference));
[s, stop] = gradient_stop_update(fresh, 0, 0, inf, c, 1);
assert(~stop && s.reference == 0);
[~, stop] = gradient_stop_update(s, 0, 0, inf, c, 1);
assert(stop, 'Zero reference must not disable absolute stopping.');
s = struct('reference', 1, 'window', nan);
[~, stop] = gradient_stop_update(s, c.tolerance, 0, inf, c, 1);
assert(~stop, 'Stopping comparison must be strict.');
c.window = 2;
s = struct('reference', 1, 'window', [nan, nan]);
[s, stop] = gradient_stop_update(s, 1e-4, 0, inf, c, 1);
assert(~stop);
[s, stop] = gradient_stop_update(s, 1, 0, inf, c, 1);
assert(~stop);
[s, stop] = gradient_stop_update(s, 1e-4, 0, inf, c, 1);
assert(~stop);
[~, stop] = gradient_stop_update(s, 1e-4, 0, inf, c, 1);
assert(stop);
% Independent replay must reproduce the same state-machine boundary without
% calling gradient_stop_update, including the excluded reference sample.
c.window = 1;
t = struct('calls', 30, 'output_index', 1, 'events', ...
    [1, 10, 0, 0, 5e-4, inf, 1, 0.5, 1, 1; 2, 20, 0, 0, 1e-6, inf, 1, 1e-3, 1, 2]);
p = gradient_experiment_replay(t, c, false);
assert(p.calls == 20 && p.reference_call == 10);
t.events(1, 3) = 1;
p = gradient_experiment_replay(t, c, true);
assert(p.calls == 10);
t.events = zeros(0, 10);
p = gradient_experiment_replay(t, c, true);
assert(p.calls == 30 && isnan(p.reference));
% Waiting counts polling failures, not previous successful error tests.
c.minimum_failures = 3;
fresh = struct('reference', nan, 'window', nan(1, c.window));
[s, stop] = gradient_stop_update(fresh, 1, 0, inf, c, 2);
assert(~stop && isnan(s.reference));
[s, stop] = gradient_stop_update(s, 1, 1, inf, c, 3);
assert(~stop && isnan(s.reference));
[s, stop] = gradient_stop_update(s, 10, 0.5, inf, c, 4);
assert(~stop && s.reference == 10.5);
[s, stop] = gradient_stop_update(s, 1e-4, 0, inf, c, 5);
assert(stop && s.reference == 10.5);
[s, stop] = gradient_stop_update(fresh, nan, 0, inf, c, 4);
assert(~stop && isnan(s.reference));
% A successful polling iteration resets the run even without a gradient.
t.events = [1,10,0,1,0,inf,1,0,1,1; 2,20,0,1,0,inf,1,0,1,2; ...
    3,30,0,nan,nan,inf,1,nan,0,0; 4,40,0,1,0,inf,1,0,1,1; ...
    5,50,0,1,0,inf,1,0,1,2; 6,60,0,1,0,inf,1,0,1,3; ...
    7,70,0,1e-4,0,inf,1,0,1,4];
t.calls = 80;
p = gradient_experiment_replay(t, c, false);
assert(p.reference_call == 60 && p.reference_failures == 3 && p.calls == 70);
% The last error test alone suffices; earlier failed error gates do not reset K.
t.events(4:5, 5) = 1;
p = gradient_experiment_replay(t, c, false);
assert(p.reference_call == 60 && p.calls == 70);
t.events(6, 5) = 1;
p = gradient_experiment_replay(t, c, false);
assert(p.reference_call == 70 && p.calls == 80);
% Deliberately corrupted observer counts must be rejected by independent replay.
t.events(2, 10) = 1;
detected = false;
try
    gradient_experiment_replay(t, c, false);
catch exception
    detected = strcmp(exception.identifier, 'GradientExperiment:FailureCounterMismatch');
end
assert(detected);
fprintf('GRADIENT_EXPERIMENT_UNIT_OK\n');

end
