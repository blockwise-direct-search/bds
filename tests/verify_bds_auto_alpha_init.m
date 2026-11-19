function verify_bds_auto_alpha_init()
%VERIFY_BDS_AUTO_ALPHA_INIT Coordinate initialization and explicit scope errors.
root=fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'src'));
count=0;
for n=[1,4]
 for row=[false,true]
  x0=[0;2;-3;1e-8];x0=x0(1:n);if row,x0=x0';end
  for tol={1e-6,linspace(.1,2,n)'}
   h=max(abs(x0(:)),tol{1});h(x0(:)==0)=max(1,h(x0(:)==0));
   for switches=[0,3]
    o=struct('alpha_init','auto','StepTolerance',tol{1}, ...
     'MaxFunctionEvaluations',80,'seed',19,'output_alpha_hist',true, ...
     'output_xhist',true,'output_block_hist',true, ...
     'use_search_acceleration',logical(switches));
    [x,f,flag,out]=bds(@objective,x0,o);o.alpha_init=h;
    [xx,ff,fl,oo]=bds(@objective,x0,o);
    assert(isequaln(x,xx)&&isequaln(f,ff)&&flag==fl&&isequaln(out,oo));
    assert(isequal(out.alpha_hist(:,1),h));count=count+1;
   end
  end
 end
end
% Reject unsupported automatic initialization before any objective evaluation.
unsupported={struct('num_blocks',1),struct('num_blocks',2), ...
 struct('direction_set',[1,1,0;0,1,0;0,0,1]), ...
 struct('direction_set',2*eye(3)),struct('direction_set',zeros(3)), ...
 struct('grouped_direction_indices',{{2,1,3}}),struct('Algorithm','ds')};
calls=0;
for j=1:numel(unsupported)
 o=unsupported{j};o.alpha_init='auto';
 try,bds(@counted,zeros(3,1),o);error('Expected unsupported auto error.');
 catch err,assert(strcmp(err.identifier,'BDS:AutoInitialStepsCoordinateOnly'));end
end
assert(calls==0);
% General bases and grouped blocks remain usable with explicit numeric steps.
for j=1:2
 o=unsupported{j};o.alpha_init=.5;o.MaxFunctionEvaluations=40;
 [x,f,~,out]=bds(@objective,ones(3,1),o);
 assert(all(isfinite(x))&&isfinite(f)&&out.funcCount<=40);
end
% Gradient stopping remains available with an explicit general-basis step.
o=struct('direction_set',[1,1,0;1,-1,0;0,0,sqrt(2)]/sqrt(2), ...
 'alpha_init',[1;2;1],'use_estimated_gradient_stop',true, ...
 'use_gradient_reference_consistency',false,'lipschitz_constant',1e-6, ...
 'StepTolerance',0,'MaxFunctionEvaluations',100,'output_grad_hist',true);
[~,~,flag,out]=bds(@(x)1,zeros(3,1),o);
assert(flag==5&&all(out.grad_hist(:)==0));
fprintf('BDS_AUTO_ALPHA_INIT_OK exact=%d rejected=%d explicit_general=3\n',count,numel(unsupported));
    function f=counted(x)
        calls=calls+1;f=objective(x);
    end
end
function f=objective(x)
x=x(:);f=sum((x-.27).^2)+.01*sum(sin(x));
end
