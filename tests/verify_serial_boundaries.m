function verify_serial_boundaries()
%VERIFY_SERIAL_BOUNDARIES Public-call boundaries independent of private helpers.
o=struct('Algorithm','cbds','alpha_init',1,'StepTolerance',0, ...
 'MaxFunctionEvaluations',30,'ftarget',-inf,'expand',2,'shrink',.5, ...
 'reduction_factor',[0,eps,eps],'cycling_inner',0, ...
 'polling_inner','opportunistic','seed',19, ...
 'use_search_acceleration', true, ...
 'use_function_value_stop',false,'use_estimated_gradient_stop',false, ...
 'output_xhist',true,'output_block_hist',true);
count=0;
for kind=1:6
 for budget=[1,2,3,4,5,6,7,12,30]
  for target=[-inf,-1]
   o.MaxFunctionEvaluations=budget;o.ftarget=target;
   ref=serial_reference(@objective,zeros(2,1),o);
   [x,f,flag,out]=bds(@objective,zeros(2,1),o);
   assert(isequaln(out.xhist,ref.points)&&isequaln(out.fhist,ref.values));
   assert(isequaln(x,ref.x)&&isequaln(f,ref.f)&&flag==ref.flag);
   assert(out.funcCount==numel(out.fhist)&&out.funcCount<=budget);
   count=count+1;
  end
 end
end
% A successful first block followed by a failed block must NOT bootstrap.
o.MaxFunctionEvaluations=5;o.ftarget=-inf;kind=1;
[~,~,~,out]=bds(@objective,[0;0],o);
assert(isequal(out.xhist,[0,1,1,1,3;0,0,1,-1,0]));
% A failed initial raw value must not satisfy even an infinite target.
p=o;p.ftarget=inf;
[~,~,fl,oo]=bds(@(x)nan,[0;0],p);
assert(fl==0&&oo.funcCount==2); % preserves the existing polling target rule
% Recording histories never changes the trajectory; row input is preserved.
o.MaxFunctionEvaluations=40;fun=@(x)sum((x-.37).^2);
[x,f,flag,out]=bds(fun,[0;0],o);
for mask=0:15
 p=o;p.output_xhist=logical(bitget(mask,1));p.output_block_hist=logical(bitget(mask,2));
 p.output_alpha_hist=logical(bitget(mask,3));p.output_grad_hist=logical(bitget(mask,4));
 [xx,ff,fl,oo]=bds(fun,[0;0],p);
 assert(isequaln(xx,x)&&ff==f&&fl==flag&&isequaln(oo.fhist,out.fhist));
end
[xr,fr,flr,orr]=bds(@row_objective,[0,0],o);
assert(isequal(xr,x')&&fr==f&&flr==flag&&isequaln(orr.fhist,out.fhist));
% General bases, uneven block partitions and complete polling retain exact
% nonaccelerated behavior against the existing independent frozen solver.
for grouped={ {[1,2],3}, {1,[2,3]}, {[1,3],2} }
 for cycling=0:3
  p=rmfield(o,'Algorithm');p.num_blocks=2;
  p.grouped_direction_indices=grouped{1};p.direction_set=[1,.2,0;0,1,.3;.1,0,1];
  p.use_search_acceleration=false;
  p.cycling_inner=cycling;p.polling_inner='complete';
  p.output_grad_hist=false;p.MaxFunctionEvaluations=60;
  [xx,ff,fl,oo]=bds(fun,zeros(3,1),p);
  [xxr,ffr,flrr,oor]=bds_without_acceleration_reference(fun,zeros(3,1), ...
   rmfield(p,'use_search_acceleration'));
  assert(isequaln(xx,xxr)&&ff==ffr&&fl==flrr&&isequaln(oo,oor));
 end
end
% Unsupported algorithm names fail before the initial objective evaluation.
calls=0;
try
    bds(@count_calls,[0;0],struct('Algorithm','pads'));
    error('Expected an invalid algorithm error.');
catch err
    assert(strcmp(err.identifier,'BDS:InvalidAlgorithm'));
end
assert(calls==0);
fprintf('SERIAL_BOUNDARIES_OK reference=%d outputs=16 grouped=12 invalid_algorithm=1\n',count);
    function f=objective(x)
        switch kind
            case 1,f=-x(1);
            case 2,f=nan;
            case 3,f=inf;
            case 4,if x(1)>0,error('BDS:FixtureError','Expected.');end;f=sum((x+.3).^2);
            case 5,if x(2)>0,f=nan;else,f=sum((x-.3).^2);end
            case 6,if x(1)>0,f=-inf;else,f=0;end
        end
    end
    function f=row_objective(x)
        assert(isrow(x));f=fun(x);
    end
    function f=count_calls(~)
        calls=calls+1;f=0;
    end
end
