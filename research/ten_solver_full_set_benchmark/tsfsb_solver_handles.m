function bundle = tsfsb_solver_handles(feature)
%TSFSB_SOLVER_HANDLES Solver handles for one TSFSB feature.
%
%   New for TSFSB. Given a feature struct from tsfsb_benchmark_spec,
%   returns a bundle with the ten solver handles in canonical pool
%   order, the display names, the machine identifiers, the
%   solver_isrand flags, and a details struct recording the resolved
%   option templates for manifests.
%
%   solver_isrand is true for PDS and BFO, false for the others:
%   - BDS, BDS without acceleration, and DS are deterministic given the
%     fixed options (the direction sets are deterministic and no
%     randomized strategy is enabled).
%   - PDS is randomized but receives a deterministic per-problem seed
%     through its existing options.seed interface (tsfsb_pds_seed); the
%     seed is evaluated inside the handle from x0, so all runs of the
%     same problem share one stream. The OptiProfiler solver-handle
%     interface cannot pass per-run seeds; runs still differ through
%     the feature realization (noise and rotation seeded by
%     OptiProfiler per run).
%   - BFO reseeds rng(0, 'twister') internally at every call by default
%     (bfo.m line 5884 with default 'random-seed' 0), so its behavior
%     does not depend on any external random state.
%   - NOMAD, LAM, NEWUOA, FD-BFGS, and Nelder-Mead are deterministic
%     under the fixed options.
%   Note that OptiProfiler only uses solver_isrand for run-count logic,
%   and every TSFSB feature sets n_runs explicitly, so the flags have
%   no practical effect; they are recorded truthfully.
%
%   FD-BFGS receives the noise level only when the feature has
%   sigma > 0, exactly the C02 branching: noiseless features use
%   SpecifyObjectiveGradient false (fminunc default finite-difference
%   rule) and noisy features use the wrapper forward-difference
%   gradient with step sqrt(sigma*max(1, |f|)).

if ~isstruct(feature) || ~isfield(feature, 'name') ...
        || ~isfield(feature, 'noise_level')
    error('tsfsb_solver_handles:InvalidFeature', ...
        'feature must be a struct from tsfsb_benchmark_spec.');
end
sigma = feature.noise_level;

[pool, ~] = tsfsb_solver_pool();
handles = cell(1, numel(pool));
details = repmat(struct( ...
    'internal_label', '', ...
    'display_name', '', ...
    'configuration', '', ...
    'budget_factor', 500, ...
    'budget_field', '', ...
    'options_static', struct(), ...
    'notes', ''), 1, numel(pool));

for i = 1:numel(pool)
    entry = pool(i);
    details(i).internal_label = entry.internal_label;
    details(i).display_name = entry.display_name;
    details(i).configuration = entry.configuration;
    details(i).budget_factor = entry.budget_factor;
    switch entry.internal_label
        case {'bds', 'bds-no-acceleration', 'ds'}
            configuration = entry.configuration;
            handles{i} = @(fun, x0) bds(fun, x0, ...
                tsfsb_benchmark_options(x0, configuration));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_benchmark_options(ones(2, 1), configuration);
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).notes = ['Production src/bds.m with fixed ', ...
                'TSFSB options; alpha_init auto.'];
        case 'nomad'
            handles{i} = @(fun, x0) nomad_wrapper(fun, x0, ...
                tsfsb_external_solver_options(x0, 'nomad'));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_external_solver_options(ones(2, 1), 'nomad');
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).notes = ['nomad_wrapper maps the budget to ', ...
                'MAX_BB_EVAL and max_eval and sets min_frame_size.'];
        case 'lam'
            handles{i} = @(fun, x0) lam_paper_exact(fun, x0, ...
                tsfsb_external_solver_options(x0, 'lam'));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_external_solver_options(ones(2, 1), 'lam');
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).notes = ['Paper-exact LAM port ', ...
                '(lam_paper_exact), paper constants per the C02 ', ...
                'accepted clone.'];
        case 'newuoa'
            handles{i} = @(fun, x0) prima_wrapper(fun, x0, ...
                tsfsb_external_solver_options(x0, 'newuoa'));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_external_solver_options(ones(2, 1), 'newuoa');
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).notes = ['prima_wrapper maps to rhobeg 1, ', ...
                'rhoend 1e-6, maxfun 500*n, iprint 0.'];
        case 'fd-bfgs'
            if sigma > 0
                handles{i} = @(fun, x0) fminunc_budgeted_wrapper(fun, ...
                    x0, tsfsb_external_solver_options(x0, 'fd-bfgs', sigma));
                details(i).options_static = tsfsb_external_solver_options( ...
                    ones(2, 1), 'fd-bfgs', sigma);
                details(i).notes = ['Noisy feature: wrapper ', ...
                    'forward-difference gradient with step ', ...
                    'sqrt(sigma*max(1, |f|)), budget enforced through ', ...
                    'max_callbacks.'];
            else
                handles{i} = @(fun, x0) fminunc_budgeted_wrapper(fun, ...
                    x0, tsfsb_external_solver_options(x0, 'fd-bfgs'));
                details(i).options_static = ...
                    tsfsb_external_solver_options(ones(2, 1), 'fd-bfgs');
                details(i).notes = ['Noiseless feature: ', ...
                    'SpecifyObjectiveGradient false, fminunc default ', ...
                    'finite-difference rule.'];
            end
            details(i).budget_field = 'MaxObjectiveEvaluations';
            details(i).options_static.MaxObjectiveEvaluations = '500*n';
        case 'pds'
            handles{i} = @(fun, x0) pds(fun, x0, pds_options_with_seed(x0));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_external_solver_options(ones(2, 1), 'pds');
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).options_static.seed = 'tsfsb_pds_seed(x0)';
            details(i).notes = ['Remaining options are the pds.m ', ...
                'defaults recorded in tsfsb_external_solver_options; ', ...
                'the deterministic per-problem seed is derived from ', ...
                'x0 inside the handle.'];
        case 'bfo'
            handles{i} = @(fun, x0) bfo_wrapper(fun, x0, ...
                tsfsb_external_solver_options(x0, 'bfo'));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_external_solver_options(ones(2, 1), 'bfo');
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).notes = ['bfo_wrapper maps to epsilon, maxeval, ', ...
                'and verbosity silent.'];
        case 'nelder-mead'
            handles{i} = @(fun, x0) fminsearch_wrapper(fun, x0, ...
                tsfsb_external_solver_options(x0, 'nelder-mead'));
            details(i).budget_field = 'MaxFunctionEvaluations';
            details(i).options_static = ...
                tsfsb_external_solver_options(ones(2, 1), 'nelder-mead');
            details(i).options_static.MaxFunctionEvaluations = '500*n';
            details(i).notes = ['fminsearch_wrapper maps to ', ...
                'MaxFunEvals 500*n, MaxIter 1e20, TolFun eps, ', ...
                'TolX 1e-6.'];
        otherwise
            error('tsfsb_solver_handles:UnknownSolver', ...
                'Unknown TSFSB pool entry ''%s''.', entry.internal_label);
    end
end

bundle = struct();
bundle.handles = handles;
bundle.solver_names = {pool.display_name};
bundle.machine_ids = {pool.internal_label};
bundle.solver_isrand = false(1, numel(pool));
bundle.solver_isrand([8, 9]) = true; % Randomized algorithms with fixed internal seeds.
bundle.details = details;

end

function options = pds_options_with_seed(x0)

options = tsfsb_external_solver_options(x0, 'pds');
options.seed = tsfsb_pds_seed(x0);

end
