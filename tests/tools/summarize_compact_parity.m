function audit=summarize_compact_parity(result_dir)
%SUMMARIZE_COMPACT_PARITY Characterize mismatches without waiving them.
s=load(fullfile(result_dir,'summary.mat'));
entries={}; total_nan_calls=0;
for j=1:numel(s.reports)
    r=s.reports{j};
    d=load(fullfile(result_dir,[r.name '.mat']));
    total_nan_calls=total_nan_calls+sum(isnan(d.results{1}.values));
    assert(r.instrumentation_equal,'Observer changed solver behavior: %s',r.name);
    assert(r.external_equal&&r.continuing_states_equal, ...
        'Nonterminal parity failure: %s',r.name);
    if ~r.terminal_state_equal
        p=d.results{2}.out.verification_trace.after{end};
        q=d.results{4}.out.verification_trace.after{end};
        names=fieldnames(p);changed={};
        for k=1:numel(names)
            if ~isequaln(p.(names{k}),q.(names{k})),changed{end+1}=names{k};end %#ok<AGROW>
        end
        entries{end+1}=struct('name',r.name,'changed_fields',{changed}, ...
            'budget_exhausted',d.results{1}.out.funcCount==d.o.MaxFunctionEvaluations, ...
            'message',d.results{1}.out.message,'production_last',p, ...
            'compact_last',q,'returned_x',d.results{1}.x, ...
            'returned_f',d.results{1}.f); %#ok<AGROW>
        fprintf('TERMINAL_DIFFERENCE %s fields=%s budget=%d\n', ...
            r.name,strjoin(changed,','),entries{end}.budget_exhausted);
    end
end
only_unused_final_base=true;
for j=1:numel(entries)
    e=entries{j};
    only_unused_final_base=only_unused_final_base&&e.budget_exhausted ...
        && all(ismember(e.changed_fields,{'x','f'}));
end
audit=struct('summary',s.summary,'terminal_differences',{entries}, ...
    'only_unused_final_base',only_unused_final_base,'nan_calls',total_nan_calls);
save(fullfile(result_dir,'terminal_audit.mat'),'audit');
fprintf('COMPACT_TERMINAL_AUDIT differences=%d only_unused_final_base=%d nan_calls=%d\n', ...
    numel(entries),only_unused_final_base,total_nan_calls);
end
