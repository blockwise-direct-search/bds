function verify_tsfsb_known_failures()
% Independently recheck the six C02 INDEF/FD-BFGS failure classifications.
tsfsb_setup_paths();
spec = tsfsb_benchmark_spec();
p = s2mpj_load('INDEF');
root = tempname; mkdir(root);
counts = [3619,3653,3620,3587,3655,3666];
for k=1:6
    if k==1, feature=Feature('plain'); run=1; else
        feature=Feature('linearly_transformed',struct('rotated',true,'condition_factor',0));
        run=k-1;
    end
    seed=mod(23333*spec.base_seed+211*run,2^32);
    featured_problem=FeaturedProblem(p,feature,500*p.n,seed);
    fun=@(x) featured_problem.fun(x);
    bundle=tsfsb_solver_handles(spec.features(1));
    folder=fullfile(root,sprintf('case%d',k)); mkdir(folder);
    caught=false;
    try
        tsfsb_trace_solver(bundle.handles{7},fun,featured_problem.x0,'fd-bfgs',folder);
    catch err
        assert(strcmp(err.identifier,'MATLAB:roots:NonFiniteInput'));
        caught=true;
    end
    assert(caught && featured_problem.n_eval_fun==counts(k));
    fprintf('TSFSB_KNOWN_FAILURE_CONFIRMED case=%d count=%d\n',k,counts(k));
end
fprintf('VERIFY_TSFSB_KNOWN_FAILURES_OK\n');
end
