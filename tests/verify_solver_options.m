function verify_solver_options(baseline_dir)
%VERIFY_SOLVER_OPTIONS Public interface, schedule and pre-change trace checks.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
calls=0;
for field={'batch_size','block_visiting_pattern','replacement_delay','is_noisy'}
 for value={[],0,1,true,'sorted'}
  o=struct();o.(field{1})=value{1};
  try,bds(@counted,zeros(2,1),o);error('Expected removed option rejection.');
  catch err,assert(strcmp(err.identifier,'BDS:UnknownOption'));end
 end
end
assert(calls==0);
% Explicit expansion still works and the omitted expansion is exactly 2.
for algorithm={'cbds','pbds','rbds','ds'}
 o=struct('Algorithm',algorithm{1},'seed',19,'MaxFunctionEvaluations',60, ...
  'output_xhist',true,'output_alpha_hist',true,'output_block_hist',true);
 a=run(@bds,@(x)-sum(x),zeros(3,1),o);o.expand=2;
 b=run(@bds,@(x)-sum(x),zeros(3,1),o);assert(isequaln(a,b));
 o.expand=1.8;c=run(@bds,@(x)-sum(x),zeros(3,1),o);
 assert(~isequaln(a.output.xhist,c.output.xhist));
end
% A noisy objective no longer selects different defaults. Both runs use exactly
% the same deterministic point-dependent perturbation, so full histories compare.
o=struct('seed',19,'MaxFunctionEvaluations',70,'output_xhist',true);
f=@(x)sum((x-.3).^2)+.1*sin(123*sum(x));
a=run(@bds,f,zeros(3,1),o);o.expand=2;
b=run(@bds,f,zeros(3,1),o);assert(isequaln(a,b));
fprintf('SOLVER_OPTIONS_INTERFACE_OK removed=20 default=5 explicit=4\n');
if nargin==0,return;end
addpath(baseline_dir,'-end');count=0;
assert(strcmp(which('bds'),fullfile(root,'src/bds.m')));
for algorithm={'cbds','pbds','rbds','ds'}
 for n=[1,3]
  x0=2.^((0:n-1)');x0(1)=0;
  for seed=[1,19]
   for switches=0
    for stops=0:3
     for budget=[1,2,7,60]
      o=struct('Algorithm',algorithm{1},'seed',seed,'alpha_init',1, ...
       'StepTolerance',1e-6,'MaxFunctionEvaluations',budget, ...
       'output_xhist',true,'output_alpha_hist',true,'output_block_hist',true, ...
       'output_grad_hist',true,'func_window_size',2, ...
       'use_search_acceleration',logical(switches), ...
       'use_function_value_stop',logical(bitget(stops,1)), ...
       'use_estimated_gradient_stop',logical(bitget(stops,2)));
      for kind=1:3
       a=run(@bds,@objective,x0,o);b=run(@bds_options_baseline,@objective,x0,frozen_acceleration_options(o));
       assert(isequaln(a,b),'Trace changed: %s n=%d seed=%d switches=%d stops=%d budget=%d kind=%d', ...
        algorithm{1},n,seed,switches,stops,budget,kind);count=count+1;
      end
     end
    end
   end
  end
 end
end
% Coordinate auto uses the paper's formula. Binary scales avoid reciprocal
% roundoff in the old general-basis formula when comparing exact trajectories.
for algorithm={'cbds','pbds','rbds'}
 for seed=[1,19]
  o=struct('Algorithm',algorithm{1},'alpha_init','auto','seed',seed, ...
   'use_search_acceleration', false, ...
   'MaxFunctionEvaluations',90,'output_xhist',true,'output_alpha_hist',true, ...
   'output_block_hist',true,'output_grad_hist',true);
  kind=1;a=run(@bds,@objective,[0;2;-4],o);
  b=run(@bds_options_baseline,@objective,[0;2;-4],frozen_acceleration_options(o));assert(isequaln(a,b));
 end
end
% Target boundaries retain exact behavior, including an invalid initial value.
for target=[-inf,0,inf]
 for kind=1:3
  o=struct('use_search_acceleration', false, ...
   'ftarget',target,'seed',19,'MaxFunctionEvaluations',7,'output_xhist',true);
  a=run(@bds,@objective,[0;0],o);b=run(@bds_options_baseline,@objective,[0;0],frozen_acceleration_options(o));
  assert(isequaln(a,b));
 end
end
fprintf('SOLVER_OPTIONS_BASELINE_OK traces=%d auto=6 targets=9\n',count);
    function f=counted(x)
        calls=calls+1;f=sum(x.^2);
    end
    function f=objective(x)
        if kind==1,f=sum((x-.27).^2)+.01*sum(sin(x));
        elseif kind==2,f=1;
        else
            if sum(x)>2,error('BDS:ExpectedFixtureError','Expected evaluation failure.');end
            if sum(x)==0,f=nan;else,f=sum(x.^2);end
        end
    end
end
function r=run(solver,fun,x0,o)
[r.x,r.f,r.flag,r.output]=solver(fun,x0,o);
end
