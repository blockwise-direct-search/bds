function verify_bds_unknown_options()
%VERIFY_BDS_UNKNOWN_OPTIONS Unsupported settings fail before evaluating fun.
calls = 0;
for name = {'use_iteration_pattern_step', 'use_momentum_extrapolation', ...
        'momentum_decay', 'use_productive_direction_memory', ...
        'productive_direction_memory_size', 'unknown_field'}
    for value = {false, true, [], 0.6}
        options = struct();
        options.(name{1}) = value{1};
        try
            bds(@counted, [1; 2], options);
            error('Expected rejection of an unknown field.');
        catch err
            assert(strcmp(err.identifier, 'BDS:UnknownOption'));
        end
    end
end
assert(calls == 0);
fprintf('BDS_UNKNOWN_OPTIONS_OK\n');
    function f = counted(x)
        calls = calls + 1;
        f = sum(x.^2);
    end
end
