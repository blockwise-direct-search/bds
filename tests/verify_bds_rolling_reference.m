function summary = verify_bds_rolling_reference(reference_root, result_directory, mode)
%VERIFY_BDS_ROLLING_REFERENCE Compare production with independent frozen sources.
% reference_root/c15 contains the sealed C15 src directory; reference_root/base
% contains unmodified production src at a70ab1cb, with its entry copied as
% bds_baseline.m. Private dependencies remain separate for the two references.
% MODE is fixtures or manifest. The manifest mode needs frozen S2MPJ on path
% and reference_root/problem_manifest.mat. No performance profiles are created.

if nargin < 3, mode = 'fixtures'; end
assert(ismember(mode, {'fixtures', 'manifest'}));
assert(isfolder(result_directory));
root = fileparts(fileparts(mfilename('fullpath')));
oldpath = path(); cleanup = onCleanup(@() path(oldpath));
addpath(fullfile(reference_root, 'c15'), fullfile(reference_root, 'base'));
addpath(fullfile(root, 'src'));
assert(strcmp(which('bds'), fullfile(root, 'src', 'bds.m')));
assert(strcmp(which('bds_mp_experiment'), ...
    fullfile(reference_root, 'c15', 'bds_mp_experiment.m')));
cases = {};
if strcmp(mode, 'fixtures')
    for n = [1, 3, 7]
        for stops = 0:3
            for kind = 1:8
                o = options_for(n, stops);
                o.MaxFunctionEvaluations = 160*n;
                o.func_window_size = 3;
                o.StepTolerance = 0;
                o.alpha_init = 1;
                x0 = (1:n)'/3;
                if mod(kind,2) == 0, x0=x0'; end
                cases{end+1} = struct('x0',x0,'options',o,'kind',kind, ...
                    'oracle','green','name',''); %#ok<AGROW>
            end
        end
    end
    % Every small budget crosses polling/acceleration and partial-cycle exits.
    for budget = 1:35
        o=options_for(3,3);o.MaxFunctionEvaluations=budget;
        cases{end+1}=struct('x0',[-1.2;1;0.3],'options',o,'kind',1, ...
            'oracle','green','name',''); %#ok<AGROW>
    end
    for target = [Inf, 10, 1, 0.1]
        o=options_for(3,3);o.ftarget=target;
        cases{end+1}=struct('x0',[-1.2;1;0.3],'options',o,'kind',1, ...
            'oracle','green','name',''); %#ok<AGROW>
    end
    % Non-default selectors, partitions and bases must keep baseline behavior.
    settings = {struct('Algorithm','pbds'),struct('Algorithm','rbds'), ...
        struct('Algorithm','pads'),struct('Algorithm','ds'), ...
        struct('direction_set',[1,.2,0;0,1,.3;.1,0,1]), ...
        struct('num_blocks',2,'batch_size',2), ...
        struct('num_blocks',3,'batch_size',1,'replacement_delay',0)};
    for setting=1:numel(settings)
        for switches=0:3
            for stops=0:3
                o=options_for(3,stops);o.MaxFunctionEvaluations=180;
                if isfield(settings{setting},'num_blocks')
                    o=rmfield(o,'Algorithm');
                end
                for key=fieldnames(settings{setting})'
                    o.(key{1})=settings{setting}.(key{1});
                end
                o.use_iteration_pattern_step=logical(bitget(switches,1));
                o.use_momentum_extrapolation=logical(bitget(switches,2));
                cases{end+1}=struct('x0',[1;-.5;2],'options',o,'kind',2, ...
                    'oracle','baseline','name',''); %#ok<AGROW>
            end
        end
    end
    % Cyclic acceleration-off retains the existing complete solver behavior.
    for stops=0:3
        o=options_for(3,stops);o.use_iteration_pattern_step=false;
        o.use_momentum_extrapolation=false;
        cases{end+1}=struct('x0',[1;-.5;2],'options',o,'kind',2, ...
            'oracle','baseline','name',''); %#ok<AGROW>
    end
else
    manifest=load(fullfile(reference_root,'problem_manifest.mat'));
    assert(numel(manifest.problem_names)==133);
    for j=1:133
        for stops=0:3
            o=options_for(manifest.problem_dims(j),stops);
            cases{end+1}=struct('x0',[],'options',o,'kind',0, ...
                'oracle','green','name',manifest.problem_names{j}); %#ok<AGROW>
        end
    end
end
passed=false(1,numel(cases));flags=nan(1,numel(cases));
parfor j=1:numel(cases)
    flags(j)=compare_case(cases{j},j,result_directory);
    passed(j)=true;
    fprintf('ROLLING_TRACE_PASS %s %d/%d\n',mode,j,numel(cases));
end
summary=struct('mode',mode,'passed',sum(passed),'failed',sum(~passed), ...
    'exitflags',flags,'baseline_commit','a70ab1cb','candidate','C15 P0A1');
save(fullfile(result_directory,[mode '_summary.mat']),'summary');
fprintf('ROLLING_REFERENCE_OK %s %d\n',mode,summary.passed);
end

function o=options_for(n,stops)
o=bds_paper_options(zeros(n,1),'external','mp');
o.use_function_value_stop=logical(bitget(stops,1));
o.use_estimated_gradient_stop=logical(bitget(stops,2));
o.output_xhist=true;o.output_alpha_hist=true;
o.output_block_hist=true;o.output_grad_hist=true;
end

function flag=compare_case(c,j,result_directory)
o=c.options;x0=c.x0;
if c.kind==0
    p=s2mpj_load(c.name);x0=p.x0;fun=@(x)p.fun(x);
else
    fun=@(x)fixture(x,c.kind);
end
rng(20260828); random_state=rng();
actual=[];expected=[];
try
    actual=record_bds_execution(@bds,fun,x0,o,random_state);
    if c.kind==0,p=s2mpj_load(c.name);fun=@(x)p.fun(x);end
    if strcmp(c.oracle,'green')
        oracle=@(f,x,opts)bds_mp_experiment(f,x,opts,'p0a1');
    else
        oracle=@bds_baseline;
    end
    expected=record_bds_execution(oracle,fun,x0,o,random_state);
    if isfield(expected.output,'c12_stats')
        expected.output=rmfield(expected.output,'c12_stats');
    end
    assert(isequaln(actual,expected),'BDS:RollingTraceMismatch', ...
        'Full trace or output mismatch in case %d (%s).',j,c.name);
catch exception
    save(fullfile(result_directory,sprintf('failure_%04d.mat',j)), ...
        'c','o','x0','random_state','actual','expected','exception');
    rethrow(exception);
end
flag=actual.exitflag;
end

function f=fixture(x,kind)
x=x(:);n=numel(x);
f=sum(((diag(1:n)+0.1*ones(n))*(x-0.27)).^2)+0.01*sum(sin(x));
switch kind
    case 2, f=f*(1+0.01*randn());
    case 3, if x(1)>0.5,f=NaN;end
    case 4, if x(1)>0.5,error('fixture:Failure','Failed evaluation.');end
    case 5, f=1;
    case 6, f=sum(100*(x(2:end)-x(1:end-1).^2).^2+(1-x(1:end-1)).^2);
    case 7, f=-sum(x);
    case 8, if x(1)>0.2,f=Inf;end
end
end
