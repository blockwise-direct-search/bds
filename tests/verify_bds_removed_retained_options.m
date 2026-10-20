function verify_bds_removed_retained_options()
%VERIFY_BDS_REMOVED_RETAINED_OPTIONS Check the legacy API without memory state.

options = struct('seed', 12345, 'MaxFunctionEvaluations', 100, ...
    'output_xhist', true, 'output_alpha_hist', true, ...
    'output_block_hist', true, 'output_grad_hist', true);
random_state = rng();
x0 = [1;2;3];
baseline = record_bds_execution(@bds, @objective, x0, options, random_state);
for value = {false, []}
    options.use_productive_direction_memory = value{1};
    actual = record_bds_execution(@bds, @objective, x0, options, random_state);
    assert(isequaln(actual, baseline), 'Legacy disabled switch changed solver execution.');
end

warning_id = 'BDS:DeprecatedProductiveDirectionMemorySize';
old_warning = warning('query', warning_id);
cleanup = onCleanup(@() warning(old_warning));
warning('on', warning_id);
for capacity = {5, [], -1, 'obsolete'}
    options.productive_direction_memory_size = capacity{1};
    lastwarn('');
    actual = record_bds_execution(@bds, @objective, x0, options, random_state);
    [~, identifier] = lastwarn();
    assert(strcmp(identifier, warning_id), 'Obsolete capacity did not warn.');
    assert(isequaln(actual, baseline), 'Obsolete capacity changed solver execution.');
end

options = rmfield(options, 'productive_direction_memory_size');
options.use_productive_direction_memory = true;
calls = 0;
try
    bds(@counted_objective, x0, options);
    error('verify_bds_removed_retained_options:MissingError', 'Removed acceleration was accepted.');
catch exception
    assert(strcmp(exception.identifier, 'BDS:RemovedProductiveDirectionMemory'));
end
assert(calls == 0, 'Removed option was rejected only after objective evaluations.');
fprintf('BDS_REMOVED_RETAINED_OPTIONS_OK\n');

    function value = counted_objective(x)
        calls = calls + 1;
        value = objective(x);
    end

end

function value = objective(x)

value = sum((x(:) - 0.27).^2);

end
