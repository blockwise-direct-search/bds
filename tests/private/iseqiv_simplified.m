function equiv = iseqiv_simplified(solvers, p, ir, single_test, prec, options)

pname = p.name;
x0 = p.x0;
n = length(x0);

% Some randomization
% Set seed using pname, n, and ir. We ALTER THE SEED weekly to test the solvers as much as possible.
% N.B.: The weeknum function considers the week containing January 1 to be the first week of the
% year, and increments the number every SUNDAY.
if isfield(options, 'yw')
    yw = options.yw;
elseif isfield(options, 'seed')
    yw = options.seed;
else
    yw = year_week('Asia/Shanghai');
end
fprintf('\nYW = %d\n', yw);
rseed = max(0, min(2^32 - 1,  sum(pname) + n + ir + yw));  % A random seed defined by the current test and yw
orig_rng_state = rng();  % Save the current random number generator settings
rng(rseed);  % Set the random seed for reproducibility
p.x0 = x0 + 0.5*randn(size(x0));
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% BEGIN: Call the solvers %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Use function handle to avoid `feval`.
solver1 = str2func(solvers{1});
solver2 = str2func(solvers{2});

% The simplified version of BDS has no configurable options; all constants are hardcoded.
% To ensure consistency between the full version and the simplified version, pass
% the corresponding hardcoded parameters to the full version and disable the three
% acceleration mechanisms that are absent from bds_simplified.
%tic;
options_bds = struct();
options_bds.expand = 2;
options_bds.shrink = 0.5;
options_bds.output_xhist = true;
options_bds.use_productive_direction_memory = false;
options_bds.use_iteration_pattern_step = false;
options_bds.use_momentum_extrapolation = false;
[x1, fx1, exitflag1, output1] = solver1(p.objective, p.x0, options_bds);
%T = toc; fprintf('\nRunning time for %s:\t %f\n', solvers{1}, T);
%tic;
[x2, fx2, exitflag2, output2] = solver2(p.objective, p.x0);
%T = toc; fprintf('\nRunning time for %s:\t %f\n', solvers{2}, T);

% Restore the random number generator state
rng(orig_rng_state);


equiv = iseq(x1(:), fx1, exitflag1, output1, x2(:), fx2, exitflag2, output2, prec);

if ~equiv
    format long;
    fprintf('\nnf: nf1 = %d, nf2 = %d', output1.funcCount, output2.funcCount)
    fprintf('\nx:')
    x1(:)'
    x2(:)'
    (x1(:) == x2(:))'
    fprintf('\nf: fx1 = %.16e, fx2 = %.16e', fx1, fx2)
    fprintf('\nexitflag: exitflag1 = %d, exitflag2 = %d', exitflag1, exitflag2)
    if single_test && options.sequential
        fprintf('\nThe solvers produce different results on %s at the %dth run.\n\n', pname, ir);
        cd(options.olddir);
    end
    error('\nThe solvers produce different results on %s at the %dth run.\n', pname, ir);
end

return


function eq = iseq(x, f, exitflag, output, xx, ff, ee, oo, prec)
    eq = true;
    
    if (norm(xx-x)/(1+norm(x)) > prec || abs(ff-f)/(1+abs(f)) > prec)
        eq = false;
    end
    
    if (prec == 0 && (exitflag ~= ee|| oo.funcCount ~= output.funcCount))
        eq = false;
    end
    
    return





