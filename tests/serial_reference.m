function result = serial_reference(fun, x, o)
%SERIAL_REFERENCE Small coordinate reference using explicit full visit history.
% No production helper is called. Windows are found by backwards scanning;
% unlike production, no last-visit cache or rolling momentum wrapper is used.
n=numel(x);x=x(:);a=ones(n,1);memory=zeros(n,n);
points=[];raw=[];blocks=zeros(1,0);starts=[];history=[];events=[];
stream=RandStream('mt19937ar','Seed',o.seed);
f=evaluate(x);best=x;bestf=f;flag=1;
for k=1:o.MaxFunctionEvaluations
    if numel(raw)>=o.MaxFunctionEvaluations || f<=o.ftarget,break;end
    if strcmp(o.Algorithm,'rbds')
        available=setdiff(1:n,blocks(max(1,k-n+1):end));
        order=stream.randperm(numel(available),1);i=available(order(1));
    else
        pos=mod(k-1,n)+1;
        if pos==1
            order=stream.randperm(n,n);
            if strcmp(o.Algorithm,'cbds'),order=sort(order);end
        end
        i=order(pos);
    end
    blocks(end+1)=i;starts(:,end+1)=x;before=f;
    yp=x;fp=f;
    for sign=[1,-1]
        z=x;z(i)=z(i)+sign*a(i);v=evaluate(z);
        if v<fp,yp=z;fp=v;end
        if v<bestf,best=z;bestf=v;end
        if numel(raw)>=o.MaxFunctionEvaluations || v<=o.ftarget || v<before,break;end
    end
    if fp+eps*a(i)^2<before,a(i)=2*a(i);else,a(i)=.5*a(i);end
    x=yp;f=fp;
    if f<=o.ftarget,flag=0;break;end
    if numel(raw)>=o.MaxFunctionEvaluations,break;end
    start=0;
    for ell=k:-1:1
        if numel(unique(blocks(ell:k)))==n,start=ell;break;end
    end
    if start>0 && f<before && o.use_search_acceleration
        s=yp-starts(:,start);length_s=norm(s);
        if length_s>0
            q = s / length_s;
            candidate = .6 * memory(:, i) + (1 - .6) * q;
            directions = [candidate / max(norm(candidate), realmin), q];
            events = [events; k, start, i];
            first_extrapolation_eval = numel(raw) + 1;
            for search = 1:2
                if search == 1 && ~any(candidate)
                    continue;
                end
                direction_best = fp;
                for factor = [1, 2, 4, 8, 16]
                    z = yp + factor * length_s * directions(:, search);
                    prior = first_extrapolation_eval:numel(raw);
                    idx = find(all(points(:, prior) == z, 1), 1);
                    if isempty(idx)
                        v = evaluate(z);
                    else
                        v = raw(prior(idx));
                        if isnan(v)
                            v = inf;
                        end
                    end
                    improve = v < direction_best;
                    if improve
                        direction_best = v;
                        if search == 2
                            memory(:, i) = candidate;
                        end
                        if v < f
                            x = z;
                            f = v;
                        end
                    end
                    if v < bestf
                        best = z;
                        bestf = v;
                    end
                    if v <= o.ftarget
                        flag = 0;
                        break;
                    end
                    if numel(raw) >= o.MaxFunctionEvaluations || ~improve
                        break;
                    end
                end
                if flag == 0 || numel(raw) >= o.MaxFunctionEvaluations
                    break;
                end
            end
        end
    end
    history(:,end+1)=x;
end
if f<=o.ftarget,flag=0;end
result=struct('x',best,'f',bestf,'flag',flag,'points',points,'values',raw, ...
    'blocks',blocks,'events',events);
    function value=evaluate(z)
        try,r=fun(z);catch,r=nan;end
        points(:,end+1)=z;raw(end+1)=r;
        value=r;if isnan(value),value=inf;end
    end
end
