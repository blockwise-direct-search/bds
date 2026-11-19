function verify_serial_stopping()
%VERIFY_SERIAL_STOPPING General complete visits, skipped estimates and gating.
o=struct('Algorithm','pbds','alpha_init',1, ...
 'StepTolerance',0,'MaxFunctionEvaluations',31,'output_grad_hist',true, ...
 'output_block_hist',true,'output_xhist',true,'use_function_value_stop',false, ...
 'use_estimated_gradient_stop',false);

for seed=1:12
 o.seed=seed;
 [~,~,~,out]=bds(@(x)1,zeros(3,1),o);
 start=1;ends=[];
 for k=1:numel(out.blocks_hist)
  if numel(unique(out.blocks_hist(start:k)))==3
   ends(end+1)=k;assert(k-start+1==3);start=k+1;
  end
 end
 assert(isequal(out.grad_iter,1:numel(ends)));
 assert(isequal(out.grad_hist,zeros(3,numel(ends))));
 assert(isequal(out.grad_xhist,zeros(3,numel(ends))));
 assert(out.funcCount==31&&size(out.xhist,2)==31);
end

% Missing samples omit an estimate, not a complete visit or a gradient-window
% entry. Reference consistency uses the preceding AVAILABLE estimate.
o.Algorithm='cbds';o.MaxFunctionEvaluations=30;o.use_estimated_gradient_stop=true;
o.grad_tol=.01;o.lipschitz_constant=realmin;
for consistency=[false,true]
 o.use_gradient_reference_consistency=consistency;o.grad_window_size=2-consistency;
 [~,~,flag,out]=bds(@missing_samples,0,o);
 assert(flag==5&&out.funcCount==9);
 assert(isequal(out.grad_iter,[1,3,4])&&isequal(out.grad_hist,[0,0,0]));
end
% Function history includes the completed visit with accepted acceleration.
o.use_estimated_gradient_stop=false;o.use_function_value_stop=true;o.func_window_size=2;
[~,~,flag,out]=bds(@(x)-min(x,5),0,o);
assert(flag==4&&out.funcCount==8&&isequal(out.blocks_hist,[1,1]));
% Acceleration accepted at an early block suppresses checking at a later
% failed block in the SAME complete visit. Window size one exposes this gate.
o.func_window_size=1;
[~,~,flag,out]=bds(@(x)-min(x(1),7),[0;0],o);
assert(flag==4&&numel(out.blocks_hist)==2); % no current-poll success at block 2
% Without that immediate window-one stop, the second complete visit contains
% accepted acceleration at block 1 followed by a failed block 2.
o.func_window_size=2;
[~,~,flag,out]=bds(@(x)-min(x(1),7),[0;0],o);
assert(flag==4&&isequal(out.blocks_hist,[1,2,1,2,1,2]));
fprintf('SERIAL_STOPPING_OK permuted_complete=12 missing=2 acceleration_history=3\n');
end
function f=missing_samples(x)
if abs(x)==.5,f=nan;else,f=1;end
end
