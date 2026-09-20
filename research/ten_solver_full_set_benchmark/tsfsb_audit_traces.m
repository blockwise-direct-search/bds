function report = tsfsb_audit_traces(trace_root, data, context)
% Match all raw calls to native OptiProfiler results, never clipped counts.
entries = dir(fullfile(trace_root, '*.mat'));
expected = numel(data.problem_names)*numel(data.solver_names)*context.expected_n_runs;
assert(numel(entries) == expected, 'TSFSB:TraceCountMismatch');
seeds = mod(23333*context.base_seed + 211*(1:context.expected_n_runs), 2^32);
checksums = repmat(struct('path','','sha256',''), 1, expected);
guard_count = 0;
failures = struct('problem',{},'solver',{},'run',{},'identifier',{},'message',{});
k = 0;
for p = 1:numel(data.problem_names)
    for s = 1:numel(data.solver_names)
        for r = 1:context.expected_n_runs
            path = fullfile(trace_root, sprintf('%s__%s__%u.mat', ...
                data.problem_names{p}, context.expected_machine_ids{s}, seeds(r)));
            loaded = load(path, 'trace');
            tr = loaded.trace;
            assert(tr.calls <= 500*data.problem_dims(p), 'TSFSB:RawBudgetViolation');
            assert(tr.assessment_count == data.n_evals(p,s,r), 'TSFSB:TraceEvaluationMismatch');
            assert(tr.calls == tr.assessment_count, 'TSFSB:NativeActualCountMismatch');
            n = tr.assessment_count;
            assert(isequaln(tr.assessments(:), ...
                reshape(data.fun_histories(p,s,r,1:n), [], 1)), 'TSFSB:TraceHistoryMismatch');
            assert(size(tr.points,2) == tr.calls && numel(tr.values) == tr.calls);
            guard_count = guard_count + tr.budget_guard_used;
            if ~isempty(tr.error_identifier)
                failures(end+1) = struct('problem',tr.problem,'solver',tr.solver, ...
                    'run',r,'identifier',tr.error_identifier,'message',tr.error_message); %#ok<AGROW>
            end
            k = k+1;
            checksums(k).path = path;
            checksums(k).sha256 = tsfsb_sha256(path);
        end
    end
end
report = struct('root',trace_root,'count',expected,'run_seeds',seeds, ...
    'budget_guard_count',guard_count,'checksums',checksums,'failures',failures);
end
