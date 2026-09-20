function x = tsfsb_trace_solver(solver, fun, x0, machine_id, trace_root)
% Record solver-visible calls and outputs without re-evaluating objectives.
% The frozen OptiProfiler callback captures its FeaturedProblem object.
% Inspect it only for metadata and already computed assessment values;
% the actual solver receives only counted_fun and x0, never this object.
info = functions(fun);
fp = [];
for j = 1:numel(info.workspace)
    if isfield(info.workspace{j}, 'featured_problem')
        fp = info.workspace{j}.featured_problem;
        break;
    end
end
assert(isa(fp, 'FeaturedProblem'), 'TSFSB:MissingFeaturedProblem');
budget = 500*numel(x0);
points = NaN(numel(x0), budget);
values = NaN(1, budget);
count = 0;
best_value = Inf;
best_point = x0;
trace = struct('problem', fp.problem.name, 'solver', machine_id, ...
    'seed', fp.seed, 'x0', x0, 'budget', budget, ...
    'status', 'returned', 'error_identifier', '', 'error_message', '', ...
    'budget_guard_used', false);
failure = [];
x = [];
try
    x = solver(@counted_fun, x0);
catch err
    if strcmp(err.identifier, 'TSFSB:BudgetReached')
        % Budget exhaustion is normal, not an optimizer failure. Select
        % only among solver-visible, evaluated values (never assessments).
        x = best_point;
        trace.status = 'budget_exhausted';
    else
        trace.status = 'solver_exception';
        trace.error_identifier = err.identifier;
        trace.error_message = err.message;
        trace.error_stack = err.stack;
        failure = err;
    end
end
trace.points = points(:, 1:count);
trace.values = values(1:count);
trace.assessments = fp.fun_hist;
trace.calls = count;
trace.output = x;
trace.assessment_count = fp.n_eval_fun;
trace_path = fullfile(trace_root, sprintf('%s__%s__%u.mat', ...
    fp.problem.name, machine_id, fp.seed));
assert(~isfile(trace_path), 'TSFSB:DuplicateTrace');
save(trace_path, 'trace', '-v7');
if ~isempty(failure), rethrow(failure); end

    function value = counted_fun(point)
        if count >= budget
            trace.budget_guard_used = true;
            error('TSFSB:BudgetReached', 'The 500N evaluation budget is exhausted.');
        end
        count = count + 1;
        points(:, count) = point(:);
        value = fun(point);
        values(count) = value;
        if isreal(value) && isscalar(value) && value < best_value
            best_value = value;
            best_point = point(:);
        end
    end
end
