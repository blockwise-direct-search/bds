function summary=verify_bds_visit_refactor(baseline_src,result_dir)
%VERIFY_BDS_VISIT_REFACTOR Compare all calls/outputs with frozen 37e80376.
% The baseline directory contains bds_before_visit_refactor.m and its own
% unchanged private dependencies. A failure is saved before being rethrown.
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path();cleanup=onCleanup(@()path(oldpath));
addpath(baseline_src);
addpath(fullfile(root,'src'));
assert(strcmp(which('bds'),fullfile(root,'src','bds.m')));
assert(strcmp(which('bds_before_visit_refactor'), ...
    fullfile(baseline_src,'bds_before_visit_refactor.m')));
if ~isfolder(result_dir),mkdir(result_dir);end
n=6;x0=(1:n)'/4;
settings={struct(),struct('Algorithm','cbds'),struct('Algorithm','pbds'), ...
    struct('Algorithm','rbds'),struct('Algorithm','pads'),struct('Algorithm','ds'), ...
    struct('direction_set',eye(n)+.1*diag(ones(n-1,1),1)), ...
    struct('num_blocks',2,'batch_size',2,'grouped_direction_indices',{{1,2:6}}), ...
    struct('num_blocks',6,'batch_size',2,'replacement_delay',2), ...
    struct('num_blocks',6,'batch_size',2,'replacement_delay',1,'block_visiting_pattern','random'), ...
    struct('num_blocks',6,'batch_size',2,'replacement_delay',2,'block_visiting_pattern','parallel'), ...
    struct('num_blocks',3,'batch_size',2,'block_visiting_pattern','parallel')};
cases={};
for setting=1:numel(settings)
    for acceleration=0:3
        for stops=0:3
            for complete=0:1
                for kind=1:6
                    o=base_options(n,acceleration,stops);
                    for field=fieldnames(settings{setting})'
                        o.(field{1})=settings{setting}.(field{1});
                    end
                    if complete,o.polling_inner='complete';end
                    o.cycling_inner=mod(setting+kind,4);
                    o.seed=1000+setting+kind;
                    if mod(setting,2)==0,o.alpha_init='auto';end
                    c=struct('x0',x0,'options',o,'kind',kind);
                    if mod(kind,2)==0,c.x0=x0';end
                    cases{end+1}=c; %#ok<AGROW>
                end
            end
        end
    end
end
% Every short budget crosses visit, batch and acceleration boundaries.
for algorithm={'cbds','pbds','rbds','pads','ds'}
    for acceleration=0:3
        for budget=1:30
            o=base_options(n,acceleration,3);o.Algorithm=algorithm{1};
            o.MaxFunctionEvaluations=budget;
            cases{end+1}=struct('x0',x0,'options',o,'kind',1); %#ok<AGROW>
        end
        for target=[Inf,10,1,0,-Inf]
            o=base_options(n,acceleration,3);o.Algorithm=algorithm{1};o.ftarget=target;
            cases{end+1}=struct('x0',x0,'options',o,'kind',1); %#ok<AGROW>
        end
        for tolerance=[0,1e-6,.6,3]
            o=base_options(n,acceleration,0);o.Algorithm=algorithm{1};
            o.StepTolerance=tolerance;
            cases{end+1}=struct('x0',zeros(n,1),'options',o,'kind',5); %#ok<AGROW>
        end
    end
end
% Near-threshold acceptance and all optional history toggles.
for history=0:7
    for factors={[eps,eps,eps],[0,eps,eps],[.1,.2,.4]}
        o=base_options(n,3,3);o.reduction_factor=factors{1};
        o.output_xhist=logical(bitget(history,1));
        o.output_grad_hist=logical(bitget(history,2));
        o.output_alpha_hist=logical(bitget(history,3));
        o.output_block_hist=o.output_alpha_hist;
        cases{end+1}=struct('x0',zeros(n,1),'options',o,'kind',7); %#ok<AGROW>
    end
end
calls=zeros(size(cases));flags=zeros(size(cases));
parfor j=1:numel(cases)
    c=cases{j};actual=[];expected=[];
    rng(9876);state=rng();fun=@(x)objective(x,c.kind);
    try
        actual=record_bds_execution(@bds,fun,c.x0,c.options,state);
        expected=record_bds_execution(@bds_before_visit_refactor,fun,c.x0,c.options,state);
        assert(isequaln(actual,expected),'BDS:VisitRefactorMismatch','Case %d differs.',j);
    catch exception
        save_failure(result_dir,j,c,actual,expected,exception);
        rethrow(exception);
    end
    calls(j)=actual.output.funcCount;flags(j)=actual.exitflag;
    if mod(j,100)==0,fprintf('VISIT_REFERENCE_PROGRESS %d/%d\n',j,numel(cases));end
end
summary=struct('baseline','37e80376','passed',numel(cases),'failed',0, ...
    'calls',sum(calls),'calls_per_case',calls,'exitflags',flags);
save(fullfile(result_dir,'visit_reference_summary.mat'),'summary','cases','-v7');
fprintf('VISIT_REFERENCE_OK cases=%d calls=%d\n',summary.passed,summary.calls);
end

function o=base_options(n,acceleration,stops)
o=struct('MaxFunctionEvaluations',144,'alpha_init',1,'StepTolerance',1e-6, ...
    'expand',2,'shrink',.5,'seed',77,'polling_inner','opportunistic', ...
    'use_iteration_pattern_step',logical(bitget(acceleration,1)), ...
    'use_momentum_extrapolation',logical(bitget(acceleration,2)), ...
    'use_function_value_stop',logical(bitget(stops,1)), ...
    'use_estimated_gradient_stop',logical(bitget(stops,2)), ...
    'func_window_size',3,'grad_window_size',1,'lipschitz_constant',1e-6, ...
    'use_gradient_reference_consistency',false,'output_xhist',true, ...
    'output_alpha_hist',true,'output_block_hist',true,'output_grad_hist',true);
assert(n==6);
end

function f=objective(x,kind)
x=x(:);n=numel(x);
f=sum(((diag(1:n)+.1*ones(n))*(x-.27)).^2)+.01*sum(sin(x));
switch kind
    case 2,f=f*(1+1e-4*randn());
    case 3,if x(1)>.4,f=NaN;end
    case 4,if x(1)>.4,error('visit:EvaluationFailure','Controlled failure.');end
    case 5,f=1;
    case 6,f=-sum(x);
    case 7,f=-.75*eps*sum(x);
end
end

function save_failure(folder,j,c,actual,expected,exception)
save(fullfile(folder,sprintf('failure_%04d.mat',j)), ...
    'c','actual','expected','exception','-v7');
end
