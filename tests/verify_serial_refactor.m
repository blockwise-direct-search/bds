function verify_serial_refactor(baseline_dir)
%VERIFY_SERIAL_REFACTOR Independent windows/order checks and frozen off traces.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
count=0;long_window=false;
for n=[1,2,3]
 for algorithm={'cbds','pbds','rbds'}
  for seed=[1,19]
   for switches=[0,3]
    for beta=.6
     for budget=[1,2,3,7,40]
      o=struct('Algorithm',algorithm{1},'seed',seed,'alpha_init',1, ...
       'StepTolerance',0,'MaxFunctionEvaluations',budget,'ftarget',-inf, ...
       'expand',2,'shrink',.5,'reduction_factor',[0,eps,eps], ...
       'cycling_inner',0,'polling_inner','opportunistic', ...
       'use_search_acceleration',logical(switches), ...
       'use_function_value_stop',false,'use_estimated_gradient_stop',false, ...
       'output_xhist',true,'output_block_hist',true);
      for kind=1:3
       if kind==1,fun=@(x)-sum(x);
       elseif kind==2,fun=@(x)sum((x-.37).^2);
       else,fun=@(x)sum((x-2).^2)+sin(sum(x));end
       ref=serial_reference(fun,zeros(n,1),o);
       [x,f,flag,out]=bds(fun,zeros(n,1),o);
       assert(isequal(out.blocks_hist,ref.blocks), 'schedule n=%d alg=%s seed=%d sw=%d beta=%g budget=%d kind=%d actual=%s reference=%s',n,algorithm{1},seed,switches,beta,budget,kind,mat2str(out.blocks_hist),mat2str(ref.blocks));
       assert(isequal(size(out.xhist),size(ref.points)));
       assert(max(abs(out.xhist(:)-ref.points(:)))<=1e-12*max(1,max(abs(ref.points(:)))));
       assert(isequaln(out.fhist,ref.values) && isequaln(x,ref.x) && isequaln(f,ref.f) && flag==ref.flag);
       if ~isempty(ref.events),long_window=long_window || any(ref.events(:,1)-ref.events(:,2)+1>n);end
       count=count+1;
      end
     end
    end
   end
  end
 end
end
assert(long_window,'Fixtures did not exercise windows longer than N.');
fprintf('SERIAL_REFERENCE_OK cases=%d\n',count);

% Existing production source is a valid exact oracle for serial polling with
% acceleration and additional stopping disabled, including custom schedules.
if nargin>0
addpath(baseline_dir,'-end');count=0;
assert(contains(which('bds'),fullfile(root,'src')));
for algorithm={'cbds','pbds','rbds','ds'}
 for n=[1,3,5]
  for seed=[1,19]
   for budget=[1,2,7,60]
    o=struct('Algorithm',algorithm{1},'seed',seed,'MaxFunctionEvaluations',budget, ...
     'use_search_acceleration', false, ...
     'use_function_value_stop',false,'use_estimated_gradient_stop',false, ...
     'output_xhist',true,'output_alpha_hist',true,'output_block_hist',true);
    fun=@(x)sum((x-.27).^2)+.01*sum(sin(x));
    [x,f,flag,out]=bds(fun,(1:n)'/3,o);
    [x_ref,f_ref,exitflag_ref,output_ref]=bds_before_serial(fun,(1:n)'/3,frozen_acceleration_options(o));
    assert(isequaln(x,x_ref)&&isequaln(f,f_ref)&&flag==exitflag_ref&&isequaln(out,output_ref));
    count=count+1;
   end
  end
 end
end
fprintf('SERIAL_OFF_EXACT_OK cases=%d\n',count);

end

% Complete visits follow actual coverage, not a modulo counter. Constant
% objectives make every poll evaluate both directions without acceleration.
for algorithm={'cbds','pbds','rbds'}
 for seed=1:12
  o=struct('Algorithm',algorithm{1},'seed',seed,'MaxFunctionEvaluations',200, ...
   'alpha_init',1,'StepTolerance',0,'output_block_hist',true, ...
   'use_function_value_stop',true,'func_window_size',3);
  [~,~,flag,out]=bds(@(x)1,zeros(3,1),o);
  seen=[];ends=[];
  for k=1:numel(out.blocks_hist)
   seen=unique([seen,out.blocks_hist(k)]);
   if numel(seen)==3,ends(end+1)=k;seen=[];end
  end
  assert(flag==4&&numel(ends)==2&&out.funcCount==1+2*ends(end));
 end
end
fprintf('SERIAL_COMPLETE_VISITS_OK cases=36\n');
end
