function [xopt,fopt,exitflag,output] = bds_simplified_one_page(fun,x0)
n=length(x0);maxfun=500*n;maxit=maxfun;
alpha_tol=1e-6;alpha_all=ones(1,n);expand=2;shrink=0.5;
D=nan(n,2*n);D(:,1:2:2*n-1)=eye(n);D(:,2:2:2*n)=-eye(n);
grouped_direction_indices=arrayfun(@(i)[2*i-1,2*i],1:n, "UniformOutput",false);
fopt_all=nan(1,n);xopt_all=nan(n,n);exitflag=0;terminate=false;
f0=fun(x0);nf=1;xbase=x0;fbase=f0;xopt=x0;fopt=f0;
for iter = 1:maxit
    for i=1:n
        direction_indices=grouped_direction_indices{i};
        [sub_xopt,sub_fopt,sub_exitflag,sub_output]=inner_direct_search(...
        fun,xbase,fbase,D(:,direction_indices),direction_indices,...
        alpha_all(i),maxfun-nf);
        nf=nf+sub_output.nf;fopt_all(i)=sub_fopt;xopt_all(:,i)=sub_xopt;
        grouped_direction_indices{i}=sub_output.direction_indices;
        is_expand=(sub_fopt+eps*(alpha_all(i)^2)<fbase);
        alpha_all(i)=alpha_all(i)*(is_expand*expand+(1-is_expand)*shrink);
        if sub_output.terminate, terminate=true;exitflag=sub_exitflag;break;end
        if sub_fopt<fbase, xbase=sub_xopt;fbase=sub_fopt;end
        if all(alpha_all<alpha_tol), terminate=true;exitflag=3;break;end
        if nf>=maxfun, terminate=true;exitflag=1;break;end
    end
    [~,index]=min(fopt_all,[],"omitnan");
    if (~isempty(index)&&fopt_all(index)<fopt)
    fopt=fopt_all(index);xopt=xopt_all(:,index);end
    if terminate, break;end
end
output.funcCount=nf;
end
function [xopt,fopt,exitflag,output] = inner_direct_search(fun,...
        xbase,fbase,D,direction_indices,alpha,submaxfun)
exitflag=nan;terminate=false;nf=0;fopt=fbase;xopt=xbase;fhist=[];xhist=[];
for j=1:length(direction_indices)
    xnew=xbase+alpha*D(:,j);fnew=fun(xnew);nf=nf+1;
    fhist=[fhist,fnew];xhist=[xhist,xnew];
    if fnew<fopt, xopt=xnew;fopt=fnew;end    
    if fnew<=-inf || nf>=submaxfun, terminate=true;break;end
    if fnew<fbase, direction_indices(1:j)=direction_indices([j, 1:j-1]);break;end
end
if fnew<=-inf, exitflag=0;elseif nf>=submaxfun, exitflag=1;end
output.nf=nf;output.direction_indices=direction_indices;
output.terminate=terminate;
end
