function gradient_experiment_unit_test()
%GRADIENT_EXPERIMENT_UNIT_TEST Check reference, window and threshold boundaries.

configs = gradient_experiment_config();
c = configs(1);
c.lipschitz = 1;
c.tolerance = 1e-2;
c.beta = 1e-3;
c.window = 1;
fresh = struct('reference', nan, 'window', nan(1, c.window));
[s, stop] = gradient_stop_update(fresh, 0, 5e-4, inf, c);
assert(~stop && s.reference == 5e-4, 'Absolute reference fallback failed.');
[s, stop] = gradient_stop_update(s, 0, 1e-6, inf, c);
assert(stop, 'Absolute stopping fallback failed.');
[s, stop] = gradient_stop_update(fresh, 1, 1, 0, c);
assert(~stop && isnan(s.reference), 'Unreliable reference accepted.');
[s, stop] = gradient_stop_update(fresh, 10, 0.5, inf, c);
assert(~stop && s.reference == 10.5, 'Relative reference rejected.');
[s, stop] = gradient_stop_update(s, 1e-3, 0, inf, c);
assert(stop && s.reference == 10.5, 'Reference changed after initialization.');
[s, stop] = gradient_stop_update(fresh, 1, inf, 0, c);
assert(~stop && isnan(s.reference));
[s, stop] = gradient_stop_update(fresh, 0, 0, inf, c);
assert(~stop && s.reference == 0);
[~, stop] = gradient_stop_update(s, 0, 0, inf, c);
assert(stop, 'Zero reference must not disable absolute stopping.');
s = struct('reference', 1, 'window', nan);
[~, stop] = gradient_stop_update(s, c.tolerance, 0, inf, c);
assert(~stop, 'Stopping comparison must be strict.');
c.window = 2;
s = struct('reference', 1, 'window', [nan, nan]);
[s, stop] = gradient_stop_update(s, 1e-4, 0, inf, c);
assert(~stop);
[s, stop] = gradient_stop_update(s, 1, 0, inf, c);
assert(~stop);
[s, stop] = gradient_stop_update(s, 1e-4, 0, inf, c);
assert(~stop);
[~, stop] = gradient_stop_update(s, 1e-4, 0, inf, c);
assert(stop);
% Independent replay must reproduce the same state-machine boundary without
% calling gradient_stop_update, including the excluded reference sample.
c.window = 1;
t = struct('calls', 30, 'output_index', 1, 'events', ...
    [1, 10, 0, 0, 5e-4, inf, 1, 0.5; 2, 20, 0, 0, 1e-6, inf, 1, 1e-3]);
p = gradient_experiment_replay(t, c, false);
assert(p.calls == 20 && p.reference_call == 10);
t.events(1, 3) = 1;
p = gradient_experiment_replay(t, c, true);
assert(p.calls == 10);
t.events = zeros(0, 8);
p = gradient_experiment_replay(t, c, true);
assert(p.calls == 30 && isnan(p.reference));
fprintf('GRADIENT_EXPERIMENT_UNIT_OK\n');

end
