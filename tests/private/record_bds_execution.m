function record = record_bds_execution(solver, fun, x0, options, random_state)
%RECORD_BDS_EXECUTION Record every real objective call and every solver output.
%
%   The same random_state must be supplied for both implementations. Exceptions
%   are recorded and rethrown to the solver's own eval_fun, not converted here.
%   Cell arrays preserve input shape and raw values, including NaN and Inf.

original_random_state = rng();
cleanup = onCleanup(@() rng(original_random_state));
rng(random_state);
record.points = {};
record.values = {};
record.errors = {};
[record.xopt, record.fopt, record.exitflag, record.output] = ...
    solver(@record_objective, x0, options);
assert(numel(record.points) == record.output.funcCount, ...
    'record_bds_execution:CountMismatch', 'Actual calls differ from funcCount.');

    function value = record_objective(x)
        record.points{end + 1} = x;
        try
            value = fun(x);
            record.values{end + 1} = value;
            record.errors{end + 1} = '';
        catch exception
            record.values{end + 1} = [];
            record.errors{end + 1} = exception.identifier;
            rethrow(exception);
        end
    end

end
