function verify_bds_visit_schedule(solver)
%VERIFY_BDS_VISIT_SCHEDULE Independent expected-point tests, not an old oracle.
root=fileparts(fileparts(mfilename('fullpath')));
oldpath=path();cleanup=onCleanup(@()path(oldpath));
addpath(fullfile(root,'src'));
if nargin<1,solver=@bds;end
o=struct('num_blocks',2,'alpha_init',1,'StepTolerance',0, ...
    'MaxFunctionEvaluations',6,'expand',2,'shrink',.5, ...
    'polling_inner','complete','cycling_inner',1,'reduction_factor',[eps,eps,eps], ...
    'use_search_acceleration', false, ...
    'use_function_value_stop',false,'use_estimated_gradient_stop',false, ...
    'output_xhist',true,'output_alpha_hist',true,'output_block_hist',true, ...
    'output_grad_hist',true,'seed',19);
expected=[1,2,0,0,0,2;1,1,1,2,0,0];
count=0;
for budget=1:6
    o.MaxFunctionEvaluations=budget;
    r=run(solver,@(x)sum(x.^2),[1;1],o);
    assert(isequal(r.points,expected(:,1:budget)), ...
        'BDS:VisitBase','budget=%d actual=%s expected=%s', ...
        budget,mat2str(r.points),mat2str(expected(:,1:budget)));
    assert(r.out.funcCount==budget);
    count=count+1;
end

% For this cyclic schedule, complete visits end after two block visits.
o.MaxFunctionEvaluations=100;
o.use_function_value_stop=true;o.func_window_size=2;
r=run(solver,@(x)1,[0;0],o);
assert(r.out.funcCount==5 && numel(r.out.blocks_hist)==2 ...
    && size(r.out.alpha_hist,2)==2);
assert(contains(r.out.message,'function value'));
o.use_function_value_stop=false;o.use_estimated_gradient_stop=true;
o.use_gradient_reference_consistency=false;o.lipschitz_constant=1e-6;
o.grad_window_size=1;o.grad_tol=1e-2;
r=run(solver,@(x)1,[0;0],o);
assert(r.out.funcCount==9 && isequal(r.out.grad_iter,[1,2]) ...
    && isequal(r.out.grad_hist,zeros(2,2)));
assert(contains(r.out.message,'gradient'));
count=count+2;

% A pattern call occurs between blocks 1 and 2 of the second cycle. The
% next window includes the first cycle's acceleration (green A1 behavior).
o.use_estimated_gradient_stop=false;o.use_search_acceleration = true;
o.polling_inner='opportunistic';o.MaxFunctionEvaluations=15;
r=run(solver,@(x)-sum(x),[0;0],o);
% The first two visits cover both blocks. The two identical searches on
% that visit share their evaluations through the fifth extrapolation point.
expected=[0,1,1,2,3,5,9,17;0,0,1,2,3,5,9,17];
assert(isequal(r.points(:,1:size(expected,2)),expected));
assert(isequal(r.out.blocks_hist(1:3),[1,2,1]));
count=count+1;
fprintf('BDS_VISIT_SCHEDULE_OK cases=%d\n',count);
end

function r=run(solver,fun,x0,o)
r.points=[];
[r.x,r.f,r.flag,r.out]=solver(@observe,x0,o);
    function f=observe(x)
        r.points(:,end+1)=x(:);f=fun(x);
    end
end
