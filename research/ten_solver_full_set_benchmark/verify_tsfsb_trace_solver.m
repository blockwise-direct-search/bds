function verify_tsfsb_trace_solver()
% Exercise native feature seeds, observational tracing and strict budgets.
tsfsb_setup_paths();
root = tempname; mkdir(root);
p = Problem(struct('name','TRACE_TEST','x0',ones(6,1),'fun',@(x)sum(x.^2)));
f = Feature('noisy', struct('noise_level',1e-4,'n_runs',5));
featured_problem = FeaturedProblem(p,f,3000,299497375);
fun = @(x) featured_problem.fun(x);
plain = sample(fun,p.x0);
hist1 = featured_problem.fun_hist;
featured_problem = FeaturedProblem(p,f,3000,299497375);
fun = @(x) featured_problem.fun(x);
observed = tsfsb_trace_solver(@sample,fun,p.x0,'sample',root);
assert(isequal(plain,observed) && isequal(hist1,featured_problem.fun_hist));
a = load(fullfile(root,'TRACE_TEST__sample__299497375.mat'));
assert(a.trace.calls == 3 && numel(a.trace.assessments) == 3);
assert(a.trace.values(1) ~= a.trace.values(2)); % repeated point, fresh draw
featured_problem = FeaturedProblem(p,f,3000,299497586);
fun = @(x) featured_problem.fun(x);
tsfsb_trace_solver(@sample,fun,p.x0,'sample',root);
b = load(fullfile(root,'TRACE_TEST__sample__299497586.mat'));
assert(~isequal(a.trace.values,b.trace.values));
featured_problem = FeaturedProblem(p,Feature('plain'),3000,299497375);
fun = @(x) featured_problem.fun(x);
x = tsfsb_trace_solver(@overrun,fun,p.x0,'overrun',root);
c = load(fullfile(root,'TRACE_TEST__overrun__299497375.mat'));
assert(c.trace.calls==3000 && featured_problem.n_eval_fun==3000);
assert(c.trace.budget_guard_used && strcmp(c.trace.status,'budget_exhausted'));
assert(isequal(x,p.x0));
fprintf('VERIFY_TSFSB_TRACE_SOLVER_OK\n');
end
function x=sample(fun,x)
fun(x); fun(x); fun(x+1);
end
function x=overrun(fun,x)
for j=1:3002, fun(x); end
end
