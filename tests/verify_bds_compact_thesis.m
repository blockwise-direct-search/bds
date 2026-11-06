function summary = verify_bds_compact_thesis(compact_file, c10_root, result_dir)
%VERIFY_BDS_COMPACT_THESIS Exact all-off parity, including private update states.
% Existing solvers are never edited. Observer statements are inserted in
% temporary copies and checked against uninstrumented executions. C10 replay
% returns frozen values ONLY after checking every requested point exactly.
assert(isfile(compact_file) && isfolder(c10_root));
if ~isfolder(result_dir), mkdir(result_dir); end
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path(); cleanup=onCleanup(@()path(oldpath));
observers=fullfile(result_dir,'observer_sources');
assert(~isfolder(observers),'Use a new result directory for each attempt.');
mkdir(observers);
copyfile(fullfile(root,'src','private'),fullfile(observers,'private'));
production=fileread(fullfile(root,'src','bds.m'));
compact=fileread(compact_file);
write_source(fullfile(result_dir,'original_bds.m'),production);
write_source(fullfile(result_dir,'original_compact.m'),compact);
prepare_observers(production,compact,observers);
copyfile(compact_file,fullfile(observers,'bds_compact_thesis.m'));
addpath(fullfile(root,'src'),observers);
assert(strcmp(which('bds'),fullfile(root,'src','bds.m')));
cases={};
for n=[1,3,7]
    for kind=1:9
        cases{end+1}=struct('name',sprintf('probe_n%d_k%d',n,kind), ...
            'x0',zeros(n,1),'kind',kind,'frozen',[]); %#ok<AGROW>
    end
end
manifest=load(fullfile(c10_root,'preflight','problem_dimensions.mat'));
assert(numel(manifest.names)==133);
for j=1:numel(manifest.names)
    name=char(manifest.names{j});
    frozen=load(fullfile(c10_root,'preflight',[name '_parity.mat']));
    assert(isequaln(frozen.points1,frozen.points2) ...
        && isequaln(frozen.values1,frozen.values2));
    cases{end+1}=struct('name',name,'x0',frozen.points1(:,1), ...
        'kind',0,'frozen',frozen); %#ok<AGROW>
end
reports=cell(size(cases));
for j=1:numel(cases)
    reports{j}=compare_case(cases{j},result_dir);
    a=reports{j};
    fprintf('COMPACT_PARITY %d/%d %s external=%d continuing=%d terminal=%d calls=%d\n', ...
        j,numel(cases),a.name,a.external_equal,a.continuing_states_equal, ...
        a.terminal_state_equal,a.calls);
end
a=[reports{:}];
summary=struct('cases',numel(cases),'fresh_probes',27,'saved_problem_traces',133, ...
    'external_equal',sum([a.external_equal]), ...
    'continuing_states_equal',sum([a.continuing_states_equal]), ...
    'terminal_state_equal',sum([a.terminal_state_equal]), ...
    'instrumentation_equal',sum([a.instrumentation_equal]), ...
    'calls',sum([a.calls]),'matlab',version);
summary.exact_all_states=all([a.external_equal]) ...
    && all([a.continuing_states_equal]) && all([a.terminal_state_equal]) ...
    && all([a.instrumentation_equal]);
save(fullfile(result_dir,'summary.mat'),'summary','reports');
disp(summary);
fprintf('COMPACT_PARITY_COMPLETED exact_all_states=%d\n',summary.exact_all_states);
end

function report=compare_case(c,result_dir)
n=numel(c.x0);
o=struct('Algorithm','cbds','alpha_init',1,'expand',2,'shrink',0.5, ...
    'StepTolerance',1e-6,'MaxFunctionEvaluations',500*n, ...
    'forcing_function',@(alpha)alpha^2,'reduction_factor',[eps,eps,eps], ...
    'polling_inner','opportunistic','cycling_inner',1,'replacement_delay',0, ...
    'ftarget',-Inf,'use_iteration_pattern_step',false, ...
    'use_momentum_extrapolation',false,'use_function_value_stop',false, ...
    'use_estimated_gradient_stop',false,'output_alpha_hist',true, ...
    'output_block_hist',true,'output_xhist',true,'output_grad_hist',false, ...
    'seed',99,'iprint',0,'debug_flag',false);
results=cell(1,4);
for solver=1:4
    points=[]; values=[]; bad_request=false; count=0;
    try
        if solver==1
            [x,f,flag,out]=bds(@objective,c.x0,o);
        elseif solver==2
            [x,f,flag,out]=bds_observed(@objective,c.x0,o);
        elseif solver==3
            [x,f,out]=bds_compact_thesis(@objective,c.x0);flag=[];
        else
            [x,f,out]=compact_observed(@objective,c.x0);flag=[];
        end
        err=[];
    catch exception
        x=[]; f=[];flag=[];out=struct();err=exception;
    end
    results{solver}=struct('x',x,'f',f,'flag',flag,'out',out, ...
        'points',points,'values',values,'bad_request',bad_request,'error',err);
end
p=results{1}; po=results{2}; q=results{3}; qo=results{4};
instrumentation_equal=false; external_equal=false;
continuing_states_equal=false; terminal_state_equal=false;
if all(cellfun(@(r)isempty(r.error)&&~r.bad_request,results))
    if c.kind==0
        assert(all(cellfun(@(r)size(r.points,2)==size(c.frozen.points1,2),results)), ...
            'A saved trajectory was not consumed completely.');
    end
    pclean=po; pclean.out=rmfield(pclean.out,'verification_trace');
    qclean=qo; qclean.out=rmfield(qclean.out,'verification_trace');
    instrumentation_equal=isequaln(p,pclean)&&isequaln(q,qclean);
    external_equal=isequaln(p.points,q.points)&&isequaln(p.values,q.values) ...
        && isequaln(p.x,q.x)&&isequaln(p.f,q.f) ...
        && isequaln(p.out.alpha_hist,q.out.alpha_hist) ...
        && isequaln(p.out.blocks_hist(:),q.out.blocks_hist(:)) ...
        && isequaln(p.out.funcCount,q.out.funcCount);
    pt=po.out.verification_trace;qt=qo.out.verification_trace;
    continuing_states_equal=isequaln(pt.before,qt.before) ...
        && isequaln(pt.after(1:end-1),qt.after(1:end-1));
    terminal_state_equal=isequaln(pt.after(end),qt.after(end));
end
report=struct('name',c.name,'kind',c.kind,'calls',size(p.points,2), ...
    'instrumentation_equal',instrumentation_equal,'external_equal',external_equal, ...
    'continuing_states_equal',continuing_states_equal, ...
    'terminal_state_equal',terminal_state_equal);
save(fullfile(result_dir,[c.name '.mat']),'report','results','o','-v7');

    function f=objective(x)
        count=count+1;points(:,count)=x(:);
        if c.kind==0
            if count>size(c.frozen.points1,2) ...
                    || ~isequaln(x(:),c.frozen.points1(:,count))
                bad_request=true;
                error('BDS:CompactReplayMismatch','Wrong point at call %d.',count);
            end
            f=c.frozen.values1(count);
        else
            switch c.kind
                case 1, f=1;
                case 2, f=sum((x-(1:n)'/3).^2);
                case 3, f=eps*sum((x-ones(n,1)).^2);
                case 4, f=-0.75*eps*sum(x);
                case 5, f=-2*eps*sum(x);
                case 6, f=-sum(x);
                case 7, f=sum((x-(1:n)'/3).^2)+1e-4*sin(count);
                case 8, f=sum(100*(x(2:end)-x(1:end-1).^2).^2+(1-x(1:end-1)).^2);
                case 9, f=sum(x.^2);if count==500*n,f=-1e10;end
            end
        end
        values(count)=f;
    end
end

function prepare_observers(p,q,folder)
p=replace_once(p,'= bds(', '= bds_observed(');
p=replace_once(p,'num_visited_blocks = 0;', ...
    sprintf('num_visited_blocks = 0;\nverification_trace=struct(''before'',{{}},''after'',{{}});'));
p=replace_once(p,'i_real = block_indices(i);',sprintf(['i_real = block_indices(i);\n' ...
    'verification_trace.before{end+1}=compact_snapshot(i_real,nf,xbase,fbase,alpha_all,vertcat(grouped_direction_indices{:}));']));
record='verification_trace.after{end+1}=compact_snapshot(i_real,nf,xbase,fbase,alpha_all,vertcat(grouped_direction_indices{:}));';
p=replace_once(p,sprintf('\n        if sub_output.terminate\n'),sprintf('\n        if sub_output.terminate\n%s\n',record));
p=replace_once(p,'if all(alpha_all < alpha_tol)',sprintf('if all(alpha_all < alpha_tol)\n%s',record));
p=replace_once(p,sprintf('        if rolling.enabled\n            acceleration_state'), ...
    sprintf('        %s\n        if rolling.enabled\n            acceleration_state',record));
p=replace_once(p,'output.funcCount = nf;',sprintf('output.funcCount = nf;\noutput.verification_trace=verification_trace;'));
q=replace_once(q,'=bds_compact_thesis(', '=compact_observed(');
q=replace_once(q,'for iter=1:maxfun',sprintf('verification_trace=struct(''before'',{{}},''after'',{{}});\nfor iter=1:maxfun'));
q=replace_once(q,'ind=blocks(i,:);',sprintf('verification_trace.before{end+1}=compact_snapshot(i,nf,xbase,fbase,alpha,blocks);\n    ind=blocks(i,:);'));
q=replace_once(q,'if sub_stop, stop=true; break; end',sprintf(['verification_trace.after{end+1}=compact_snapshot(i,nf,xbase,fbase,alpha,blocks);\n' ...
    '    if sub_stop, stop=true; break; end']));
q=replace_once(q,'output.funcCount=nf;',sprintf('output.funcCount=nf;\noutput.verification_trace=verification_trace;'));
write_source(fullfile(folder,'bds_observed.m'),p);
write_source(fullfile(folder,'compact_observed.m'),q);
helper=sprintf(['function s=compact_snapshot(block,nf,x,f,alpha,directions)\n' ...
    's=struct(''block'',block,''nf'',nf,''x'',x(:),''f'',f,''alpha'',alpha(:),''directions'',directions);\nend\n']);
write_source(fullfile(folder,'compact_snapshot.m'),helper);
end

function s=replace_once(s,old,new)
assert(numel(strfind(s,old))==1,'Observer anchor is not unique: %s',old);
s=strrep(s,old,new);
end

function write_source(file,content)
fid=fopen(file,'w');assert(fid>=0);c=onCleanup(@()fclose(fid));
fprintf(fid,'%s',content);
end
