function [perf_prof] = performance_value(frec, fmin, options)
% This function returns a struct containing the information that is needed to calculate the difference
% in performance between the solver being tuned and the benchmark solver. The struct contains the
% performance profiles of the solvers, the minimal function values, the number of solvers and cut ratio.
% frec: trajectory of function values; frec(ip, is, ir, k) is the function value of the ip-th
% problem obtained by the is-th solver at the ir-th random run at the k-th iteration.
% fmin: the minimal function values; either fmin(ip) is the minimal function value of the ip-th
% problem, or fmin(ip, ir) is the minimal function value of the ip-th problem for the ir-th run.
% tau: the StepTolerance of convergence.
% solvers: the list of solvers.

% Parameters.
% If a solver fails to achieve the convergence test on a problem, the log performance ratio is set to
% penalty*max_ratio, where max_ratio is the maximal log performance ratio that achieve the convergence.
penalty = 100;
% We plot the performance profiles only for the log performance ratio in [0, cut*max_ratio].
cut = 1.05;

% Why frec may contain NaN? Because we use objective in get_fhist.m to record the 
% history of the objective function. In this case, the value that we record is the 
% real value of the objective function. It definitely may contain NaN.
[np, ns, nr, MaxFunctionEvaluations] = size(frec);

% nf_return(ip, is, ir) is the number of function evaluations that the is-th solver uses when it
% returns from solving the ip-th problem at the ir-th random run, and f_return(ip, is, ir) is the
% function value it returns. In testcu.m, the returned function value and constraint violation are
% recorded in fval_history(nf + 1) and cv_history(nf + 1), respectively.
% N.B.: If the problem has no noise, then a reasonable solver (e.g., those in PRIMA) should
% return the best point found along the iterations, in terms of the objective function value or
% a merit function. It is not the case when there is noise.
nf_return = NaN(np, ns, nr);
f_return = NaN(np, ns, nr);
for ip = 1:np
    for is = 1:ns
        for ir = 1:nr
            if all(isnan(frec(ip, is, ir, :)))
                nf_return(ip, is, ir) = MaxFunctionEvaluations;
                f_return(ip, is, ir) = NaN;
            else
                nf_return(ip, is, ir) = find(~isnan(frec(ip, is, ir, :)), 1, 'last') - 1;
                f_return(ip, is, ir) = frec(ip, is, ir, nf_return(ip, is, ir) + 1);
            end
        end
    end
end

% T(ip, is, ir) is the number of function evaluations that the is-th solver needs to solve the ip-th
% problem (up to StepTolerance tau) at the ir-th random run.
T = NaN(np, ns, nr);
f0 = -Inf(np, nr);
for ip = 1:np
    for ir = 1:nr
        f0(ip,ir) = frec(ip, 1, ir, 1);
    end
end

tau = options.tau;

for ip = 1:np
    for is = 1:ns
        for ir = 1:nr
            if numel(fmin) == length(fmin)  % fmin is a vector indexed by ip only.
                fminp = fmin(ip);
            else
                fminp = fmin(ip, ir);
            end
            fthreshold = tau*f0(ip,ir) + (1-tau)*fminp;
            % We need to ensure fthreshold >= fminp, which may not be true due to rounding
            % errors when fminp = f0(ip,ir).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fthreshold = max(fthreshold, fminp);
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if options.natural_stop
                % In this case, the number of function evaluations is the amount used by the
                % solver when it stops naturally.
                ftest = f_return(ip, is, ir);
                if (ftest <= fthreshold)
                    T(ip, is, ir) = nf_return(ip, is, ir);
                else
                    T(ip, is, ir) = NaN;
                end
            else
                ftest = min(frec(ip, is, ir, :));
                % Do not change the "if .. else ..." order, as frec(ip, is, ir, 1:M) may be all NaNs.
                if (ftest <= fthreshold)
                    T(ip, is, ir) = find(frec(ip, is, ir, :) <= fthreshold, 1, 'first');
                else
                    T(ip, is, ir) = NaN;
                end
            end
        end
    end
end

% pp{is, ir} is the performance profile of the is-th solver during the ir-th run.
pp = cell(ns, nr);
cut_ratio = 0;
for ir = 1 : nr
    Tmin = min(T(:, :, ir), [], 2);

    % Calculate r. r(ip, is, ir) is the number of function evaluations that the is-th solvers needs
    % to solve the ip-th problem during the ir-th run, normalized by the minimal number of function
    % evaluations needed by all the solvers for this problem during the same run. We replace r by
    % log2(r) for better scaling. Why not using semilogx instead? Because semilogx only supports log10!
    r = zeros(np, ns);
    for ip = 1 : np
        r(ip, :) = T(ip, :, ir)/Tmin(ip);
    end
    r = log2(r);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Taking a max with 1.0E-1 ensures the correctness of the profiles in extreme cases.
    max_ratio = max(1.0E-1, max(max(r)));
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    penalty_ratio = penalty*max_ratio;
    cut_ratio = max(cut_ratio, cut*max_ratio);
    r(isnan(r)) = penalty_ratio;
    r = sort(r);
    for is = 1:ns
        [xx, yy] = stairs(r(:, is), (1:np)/np);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % The following ensures the correctness of the profiles in extreme cases like
        % one of the solvers always performs the best, or one of the solvers cannot
        % solve any problem.
        xx = [0; xx(1); xx; penalty_ratio];
        yy = [0; 0; yy; yy(end)];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % In the curve defined by [xx, yy], the same value of x may correspond to many
        % different y; this will be an issue when averaging these curves across the
        % random runs. To overcome this difficulty, we slightly modify xx as follows
        % so that it becomes strictly increasing. This modification makes no visible
        % difference to the plots.
        xx = xx + 10*max(xx)*eps*(0: length(xx)-1)';
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        pp{is, ir} = [xx'; yy'];
    end
end

% For each solver, we average the performance profiles across the random runs. The resultant profile
% for the is-th solver is recorded in perf_prof{is}.
perf_prof = cell(1, ns);
% x{is} is the "horizontal values" of the profile for the is-th solver. It is the sorted union of
% the horizontal values of all the profiles for this solver among all the random runs.
x = cell(1, ns);
for is = 1 : ns
    x{is} = [];
    for ir = 1 : nr
        x{is} = [x{is}, pp{is, ir}(1, :)];
    end
    x{is} = sort(x{is});
end
% y{is} is the "vertical values" of the profile for the is-th solver.
y = cell(1, ns);
for is = 1 : ns
    % r(ir, :) is the "vertical values" of the profile for the current (is-th) solver during the
    % ir-th random run. Note that some values in x{is} do not have a corresponding vertical value,
    % which is defined below according to the fact that the performance profiles are right-continuous
    % piecewise constant functions.
    r = NaN(nr, length(x{is}));
    for ir = 1 : nr
        for ix = 1 : length(x{is})
            r(ir, ix) = pp{is, ir}(2, find(pp{is, ir}(1, :) <= x{is}(ix), 1, 'last'));
        end
    end
    % y{is} is the average of r across its first dimension.
    y{is} = mean(r, 1);
    % Record the averaged profile in perf_prof, which will be plotted later and also returned as
    % a field of "output".
    perf_prof{is} = [x{is}; y{is}];
end

% Set the output.
curves = perf_prof;
perf_prof = struct();
perf_prof.curves = curves;
perf_prof.ns = ns;
perf_prof.fmin = fmin;
perf_prof.cut_ratio = cut_ratio;

end

