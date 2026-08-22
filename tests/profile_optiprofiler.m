function [solver_scores, profile_scores, curves] = profile_optiprofiler(options)
    clc

    path_tests = fileparts(mfilename('fullpath'));
    path_competitors = fullfile(path_tests, 'competitors');
    path_tools = fullfile(path_tests, 'tools');
    if exist(path_competitors, 'dir')
        addpath(path_competitors);
    end
    if exist(path_tools, 'dir')
        addpath(path_tools);
    end
    ensure_optiprofiler_on_path();

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Example 1 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % solvers = {@fminsearch_test, @fminunc_test};
    % benchmark(solvers)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Example 2 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % solvers = {@fminsearch_test, @fminunc_test};
    % benchmark(solvers, 'noisy')

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Example 3 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % solvers = {@fminsearch_test, @fminunc_test};
    % options.feature_name = 'noisy';
    % options.n_runs = 5;
    % options.problem = s_load('LIARWHD');
    % options.seed = 1;
    % benchmark(solvers, options)

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% Example 4 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    if ~isfield(options, 'feature_name')
        error('Please provide the feature name');
    end
    input_feature_name = char(options.feature_name);
    if isfield(options, 'feature_display_name')
        feature_display_name = char(options.feature_display_name);
        options = rmfield(options, 'feature_display_name');
    else
        feature_display_name = '';
    end
    if ~isfield(options, 'savepath')
        options.savepath = fullfile(fileparts(mfilename('fullpath')), 'testdata');
    end
    custom_feature_kind = '';
    if contains(options.feature_name, 'noisy')
        options.noise_level = parse_feature_value(options.feature_name, 1e-3);
        noise_level_label = format_noise_level_for_display(options.noise_level);
        if startsWith(options.feature_name, 'permuted_noisy')
            options.feature_name = 'custom';
            options.permuted = true;
            custom_feature_kind = 'permuted';
            options.feature_stamp = strcat('permuted_noisy_', int2str(int32(-log10(options.noise_level))));
            if isempty(feature_display_name)
                feature_display_name = ['permuted_noisy_', noise_level_label];
            end
        elseif startsWith(options.feature_name, 'rotation_noisy')
            options.feature_name = 'custom';
            custom_feature_kind = 'rotation';
            options.feature_stamp = strcat('rotation_noisy_', int2str(int32(-log10(options.noise_level))));
            if isempty(feature_display_name)
                feature_display_name = ['rotation_noisy_', noise_level_label];
            end
        elseif startsWith(options.feature_name, 'linearly_transformed_noisy')
            options.feature_name = 'custom';
            custom_feature_kind = 'linearly_transformed';
            options.feature_stamp = strcat('linearly_transformed_noisy_', int2str(int32(-log10(options.noise_level))));
            if isempty(feature_display_name)
                feature_display_name = ['linearly_transformed_noisy_', noise_level_label];
            end
        else
            options.feature_name = 'noisy';
            if isempty(feature_display_name)
                feature_display_name = ['noisy_', noise_level_label];
            end
        end
    end
    if isempty(feature_display_name)
        if strcmp(input_feature_name, 'custom') && isfield(options, 'feature_stamp')
            feature_display_name = char(options.feature_stamp);
        else
            feature_display_name = input_feature_name;
        end
    end
    if startsWith(options.feature_name, 'truncated')
        options.significant_digits = parse_feature_value(options.feature_name, 6);
        % Actually, the way of truncating the function value is to
        % Truncate to n significant figures and round off the last digit, which
        % can be regarded as some kind of noise. The minimum value should be
        % 0 of course. When it comes to the case of maximum value, the actual
        % value is 10^m + 5*10^{m-n} and the truncated value is 5*10^{m-n}.
        % The relative error is 5/(10^n + 5). Assume that the noise follows
        % the uniform distribution, then the noise level is 5/(10^n + 5) * 0.5.
        options.noise_level = 5 / (10^options.significant_digits + 5) * 0.5;
        options.feature_name = 'truncated';
    end
    if startsWith(options.feature_name, 'quantized')
        if sum(options.feature_name == '_') > 0
            options.mesh_size = 10.^(-str2double(options.feature_name(end)));
        else
            options.mesh_size = 1e-3;
        end
        options.feature_name = 'quantized';
    end
    if startsWith(options.feature_name, 'random_nan')
        options.nan_rate = str2double(options.feature_name(find(options.feature_name == '_', 1, 'last') + 1:end)) / 100;
        options.feature_name = 'random_nan';
    end
    if startsWith(options.feature_name, 'perturbed_x0')
        if sum(options.feature_name == '_') > 1
            str = split(options.feature_name, '_');
            options.perturbation_level = str2double(str{end});
        else
            options.perturbation_level = 1e-3;
        end
        options.feature_name = 'perturbed_x0';
    end
    if ~isfield(options, 'solver_names')
        error('Please provide the solver_names for the solvers');
    end
    if isfield(options, 'test_blocks') && options.test_blocks
        options.solver_names(strcmpi(options.solver_names, 'cbds')) = {'cbds-block'};
        options.solver_names(strcmpi(options.solver_names, 'cbds-half')) = {'cbds-half-block'};
        options.solver_names(strcmpi(options.solver_names, 'cbds-quarter')) = {'cbds-quarter-block'};
        options.solver_names(strcmpi(options.solver_names, 'cbds-eighth')) = {'cbds-eighth-block'};
        options.solver_names(strcmpi(options.solver_names, 'ds')) = {'ds-block'};
        options = rmfield(options, 'test_blocks');
    end
    % Why we remove the truncated form feature adaptive? Fminunc do not know the noise level
    % such that it can not decide the step size.
    feature_adaptive = {'noisy', 'custom', 'truncated'};
    if ismember(options.feature_name, feature_adaptive)
        if ismember('fd-bfgs', options.solver_names)
            options.solver_names(strcmpi(options.solver_names, 'fd-bfgs')) = {'adaptive-fd-bfgs'};
        end
        bds_Algorithms = {'ds', 'ds-randomized-orthogonal', 'pbds', 'rbds', 'pads', 'scbds', 'cbds', 'cbds-randomized-orthogonal',...
         'cbds-randomized-gaussian', 'cbds-permuted'};
        if any(ismember(bds_Algorithms, options.solver_names))
            % options.solver_names(strcmpi(options.solver_names, 'ds')) = {'ds-noisy'};
            % Temporarily, we will use the label 'ds'.
            options.solver_names(strcmpi(options.solver_names, 'ds')) = {'ds'};
            options.solver_names(strcmpi(options.solver_names, 'ds-randomized-orthogonal')) = {'ds-randomized-orthogonal-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'pbds')) = {'pbds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'rbds')) = {'rbds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'pads')) = {'pads-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'scbds')) = {'scbds-noisy'};
            % options.solver_names(strcmpi(options.solver_names, 'cbds')) = {'cbds-noisy'};
            % Temporarily, we will use the label 'cbds'.
            options.solver_names(strcmpi(options.solver_names, 'cbds')) = {'cbds'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-randomized-orthogonal')) = {'cbds-randomized-orthogonal-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-randomized-gaussian')) = {'cbds-randomized-gaussian-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-permuted')) = {'cbds-permuted-noisy'};
        end
    end

    if ~isfield(options, 'n_runs')
        if strcmpi(options.feature_name, 'plain') || strcmpi(options.feature_name, 'quantized')
            options.n_runs = 1;
        else
            options.n_runs = 2;
        end
    end
    if ~isfield(options, 'solver_verbose')
        options.solver_verbose = 2;
    end
    time_str = char(datetime('now', 'Format', 'yy_MM_dd_HH_mm_ss'));
    options.silent = false;
    options.ptype = 'u';
    if isfield(options, 'dim')
        if strcmpi(options.dim, 'small')
            options.mindim = 1;
            options.maxdim = 5;
        elseif strcmpi(options.dim, 'big')
            options.mindim = 6;
            options.maxdim = 20;
        elseif strcmpi(options.dim, 'large')
            options.mindim = 21;
            options.maxdim = 200;
        end
        options = rmfield(options, 'dim');
    end
    if ~isfield(options, 'mindim')
        options.mindim = 1;
    end
    if ~isfield(options, 'maxdim')
        options.maxdim = 5;
    end
    if ~isfield(options, 'run_plain')
        options.run_plain = false;
    end
    solvers = cell(1, length(options.solver_names));
    has_auto_alpha_candidate = false;
    for i = 1:length(options.solver_names)
        switch options.solver_names{i}
            case 'bds-infinite'
                solvers{i} = @bds_default;
            case 'bds-finite'
                solvers{i} = @bds_finite_test;
            case 'bds'
                solvers{i} = @bds_test;
            case 'bds-default'
                solvers{i} = @bds_default;
            case {'bds-scaled', 'bds-auto', 'bds_auto'}
                solvers{i} = @bds_scaled;
            case {'bds-hybrid-025', 'bds_hybrid_025'}
                solvers{i} = @(fun, x0) bds_hybrid_scaled(fun, x0, 0.025);
            case {'bds-hybrid-05', 'bds_hybrid_05'}
                solvers{i} = @(fun, x0) bds_hybrid_scaled(fun, x0, 0.05);
            case {'bds-hybrid-10', 'bds_hybrid_10'}
                solvers{i} = @(fun, x0) bds_hybrid_scaled(fun, x0, 0.10);
            case {'bds-hybrid-25', 'bds_hybrid_25'}
                solvers{i} = @(fun, x0) bds_hybrid_scaled(fun, x0, 0.25);
            case {'bds-hybrid-50', 'bds_hybrid_50'}
                solvers{i} = @(fun, x0) bds_hybrid_scaled(fun, x0, 0.50);
            case {'bds-hybrid-abs', 'bds_hybrid_abs'}
                solvers{i} = @(fun, x0) bds_hybrid_scaled(fun, x0, 1.00);
            case {'bds-simplex-025', 'bds_simplex_025'}
                solvers{i} = @(fun, x0) bds_simplex_scaled(fun, x0, 0.025);
            case {'bds-simplex-05', 'bds_simplex_05'}
                solvers{i} = @(fun, x0) bds_simplex_scaled(fun, x0, 0.05);
            case {'bds-simplex-10', 'bds_simplex_10'}
                solvers{i} = @(fun, x0) bds_simplex_scaled(fun, x0, 0.10);
            case 'our-method'
                solvers{i} = @cbds_orig_test;
            case 'adaptive-fd-bfgs'
                solvers{i} = @(fun, x0) fminunc_adaptive(fun, x0, options.noise_level);
            case 'fd-bfgs'
                solvers{i} = @fminunc_test;
            case {'fd-bfgs-500n', 'fd_bfgs_500n'}
                if isfield(options, 'noise_level')
                    noise_level_for_bfgs = options.noise_level;
                    solvers{i} = @(fun, x0) fd_bfgs_500n_test( ...
                        fun, x0, true, noise_level_for_bfgs);
                else
                    solvers{i} = @(fun, x0) fd_bfgs_500n_test( ...
                        fun, x0, false, []);
                end
            case {'bfgs-200n', 'bfgs_200n'}
                if isfield(options, 'noise_level')
                    noise_level_for_bfgs = options.noise_level;
                    solvers{i} = @(fun, x0) bfgs_200n_test(fun, x0, true, noise_level_for_bfgs);
                else
                    solvers{i} = @(fun, x0) bfgs_200n_test(fun, x0, false, []);
                end
            case 'default-fd-bfgs'
                solvers{i} = @(fun, x0) fminunc_adaptive_tmp(fun, x0, options.noise_level);
            case 'praxis'
                solvers{i} = @praxis_test;
            case 'nelder-mead'
                solvers{i} = @fminsearch_test;
            case {'nelder-mead-500n', 'nelder_mead_500n'}
                solvers{i} = @fminsearch_test;
            case {'nelder-mead-200n', 'nelder_mead_200n', 'fminsearch-200n', 'fminsearch_200n'}
                solvers{i} = @fminsearch_200n_test;
            case 'ds'
                solvers{i} = @ds_test;
            case {'ds-500n', 'ds_500n'}
                solvers{i} = @ds_500n_test;
            case {'ds-200n', 'ds_200n'}
                solvers{i} = @ds_200n_test;
            case {'ds-baseline-200n', 'ds_baseline_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'ds', false, false, false, 200, 1e-6);
            case {'ds-pattern-momentum-200n', 'ds_pattern_momentum_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'ds', false, true, true, 200, 1e-6);
            case {'accelerated-ds-all-on-200n', 'accelerated_ds_all_on_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'ds', true, true, true, 200, 1e-6);
            case 'direct-search-orig'
                solvers{i} = @ds_orig_test;
            case 'ds-block'
                solvers{i} = @ds_block_test;
            case 'ds-noisy'
                solvers{i} = @(fun, x0) ds_test_noisy(fun, x0, true);
            case 'ds-randomized-orthogonal'
                solvers{i} = @ds_randomized_orthogonal_test;
            case 'ds-randomized-orthogonal-noisy'
                solvers{i} = @(fun, x0) ds_randomized_orthogonal_test_noisy(fun, x0, true);
            case 'pbds'
                solvers{i} = @pbds_test;
            case 'pbds-noisy'
                solvers{i} = @(fun, x0) pbds_test_noisy(fun, x0, true);
            case 'pbds-orig'
                solvers{i} = @pbds_orig_test;
            case 'pbds-permuted-0'
                solvers{i} = @pbds_permuted_0_test;
            case 'pbds-permuted-1'
                solvers{i} = @pbds_permuted_1_test;
            case 'pbds-permuted-quarter-n'
                solvers{i} = @pbds_permuted_quarter_n_test;
            case 'pbds-permuted-half-n'
                solvers{i} = @pbds_permuted_half_n_test;
            case 'pbds-permuted-n'
                solvers{i} = @pbds_permuted_n_test;
            case 'rbds-orig'
                solvers{i} = @rbds_orig_test;
            case 'rbds'
                solvers{i} = @rbds_test;
            case 'rbds-noisy'
                solvers{i} = @(fun, x0) rbds_test_noisy(fun, x0, true);
            % r0d means the replacement delay is zero.
            case 'r0d'
                solvers{i} = @rbds_zero_delay_test;
            % r1d means the replacement delay is one.
            case 'r1d'
                solvers{i} = @rbds_one_delay_test;
            % rend means the replacement delay is equal to the eighth of the dimension of the problem.
            case 'rend'
                solvers{i} = @rbds_eighth_delay_test;
            % rqnd means the replacement delay is equal to the quarter of the dimension of the problem.
            case 'rqnd'
                solvers{i} = @rbds_quarter_delay_test;
            % rhnd means the replacement delay is equal to the half of the dimension of the problem.
            case 'rhnd'
                solvers{i} = @rbds_half_delay_test;
            % rnm1d means the replacement delay is equal to the dimension of the problem minus one.
            case 'rnm1d'
                solvers{i} = @rbds_n_minus_1_delay_test;
            % rnb means the batch size is equal to the dimension of the problem.
            case 'rnb'
                solvers{i} = @rbds_batch_size_n_test;
            % rhnb means the batch size is equal to the half of the dimension of the problem.
            case 'rhnb'
                solvers{i} = @rbds_batch_size_half_n_test;
            % rqnb means the batch size is equal to the quarter of the dimension of the problem.
            case 'rqnb'
                solvers{i} = @rbds_batch_size_quarter_n_test;
            % renb means the batch size is equal to the eighth of the dimension of the problem.
            case 'renb'
                solvers{i} = @rbds_batch_size_eighth_n_test;
            % r1b means the batch size is equal to 1.
            case 'r1b'
                solvers{i} = @rbds_batch_size_one_test;
            % r1bs means the batch size is equal to 1 and the seed is fixed.
            case 'r1bs'
                solvers{i} = @rbds_batch_size_one_seed_test;   
            % r1bse means the batch size is equal to 1 and the seed is fixed and the expand equals
            % to 2 and the shrink satisfies the boundary condition of 1/n > p_0.  
            case 'r1bse'
                solvers{i} = @rbds_batch_size_one_seed_expand_cov_test;
            % r1bss means the batch size is equal to 1 and the seed is fixed and the shrink equals
            % to 0.5 and the expand satisfies the boundary condition of 1/n > p_0.  
            case 'r1bss'
                solvers{i} = @rbds_batch_size_one_seed_shrink_cov_test; 
            case 'pads-orig'
                solvers{i} = @pads_orig_test;
            case 'pads'
                solvers{i} = @pads_test;
            case 'pads-noisy'
                solvers{i} = @(fun, x0) pads_test_noisy(fun, x0, true);
            case 'scbds'
                solvers{i} = @scbds_test;
            case 'scbds-noisy'
                solvers{i} = @(fun, x0) scbds_test_noisy(fun, x0, true);
            case 'cbds'
                solvers{i} = @cbds_test;
            case {'cbds-200n', 'cbds_200n'}
                solvers{i} = @cbds_200n_test;
            case {'cbds-500n', 'cbds_500n'}
                solvers{i} = @cbds_500n_test;
            case {'cbds-baseline-200n', 'cbds_baseline_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'cbds', false, false, false, 200, 1e-6);
            case {'cbds-memory-only-200n', 'cbds_memory_only_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'cbds', true, false, false, 200, 1e-6);
            case {'cbds-pattern-only-200n', 'cbds_pattern_only_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'cbds', false, true, false, 200, 1e-6);
            case {'cbds-momentum-only-200n', 'cbds_momentum_only_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'cbds', false, false, true, 200, 1e-6);
            case {'cbds-pattern-momentum-200n', 'cbds_pattern_momentum_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'cbds', false, true, true, 200, 1e-6);
            case {'accelerated-bds-all-on-200n', 'accelerated_bds_all_on_200n'}
                solvers{i} = @(fun, x0) bds_acceleration_profile_test( ...
                    fun, x0, 'cbds', true, true, true, 200, 1e-6);
            case 'cbds-development'
                solvers{i} = @cbds_development_test;
            case 'cbds-cycle-all'
                solvers{i} = @cbds_cycle_all_test;
            case 'cbds-cycle-1'
                solvers{i} = @cbds_cycle_single_1_test;
            case 'cbds-cycle-2'
                solvers{i} = @cbds_cycle_single_2_test;
            case 'cbds-cycle-3'
                solvers{i} = @cbds_cycle_single_3_test;
            case 'cbds-cycle-4'
                solvers{i} = @cbds_cycle_single_4_test;
            case 'cbds-block'
                solvers{i} = @cbds_block_test;
            case 'cbds-orig'
                solvers{i} = @cbds_orig_test;
            case 'cbds-noisy'
                solvers{i} = @(fun, x0) cbds_test_noisy(fun, x0, true);
            case 'cbds-half-block'
                solvers{i} = @cbds_num_blocks_half_n_test;
            case 'cbds-quarter-block'
                solvers{i} = @cbds_num_blocks_quarter_n_test;
            case 'cbds-eighth-block'
                solvers{i} = @cbds_num_blocks_eighth_n_test;
            case 'cbds-randomized-orthogonal'
                solvers{i} = @cbds_randomized_orthogonal_test;
            case 'cbds-randomized-orthogonal-noisy'
                solvers{i} = @(fun, x0) cbds_randomized_orthogonal_test_noisy(fun, x0, true);
            case 'cbds-randomized-gaussian'
                solvers{i} = @cbds_randomized_gaussian_test;
            case 'cbds-randomized-gaussian-noisy'
                solvers{i} = @(fun, x0) cbds_randomized_gaussian_test_noisy(fun, x0, true);
            case 'cbds-permuted'
                solvers{i} = @cbds_permuted_test;
            case 'cbds-permuted-noisy'
                solvers{i} = @(fun, x0) cbds_permuted_test_noisy(fun, x0, true);
            case 'cbds-orig-direction-set-from-x0'
                solvers{i} = @cbds_construct_directions_from_x0_test;
            case 'pds'
                solvers{i} = @pds_test;
            case {'pds-500n', 'pds_500n'}
                solvers{i} = @pds_500n_test;
            case {'pds-200n', 'pds_200n'}
                solvers{i} = @pds_200n_test;
            case 'bfo'
                solvers{i} = @bfo_test;
            case {'bfo-500n', 'bfo_500n'}
                solvers{i} = @bfo_test;
            case {'bfo-200n', 'bfo_200n'}
                solvers{i} = @bfo_200n_test;
            case 'newuoa'
                solvers{i} = @newuoa_test;
            case {'newuoa-500n', 'newuoa_500n'}
                solvers{i} = @newuoa_test;
            case {'newuoa-200n', 'newuoa_200n'}
                solvers{i} = @newuoa_200n_test;
            case 'lam'
                solvers{i} = @lam_test;
            case 'fmds'
                solvers{i} = @fmds_test;
            case 'nomad'
                solvers{i} = @nomad_test;
            case {'nomad-200n', 'nomad_200n'}
                solvers{i} = @nomad_test;
            case {'nomad-500n', 'nomad_500n'}
                solvers{i} = @nomad_500n_test;
            case {'lean-evolved-bds', 'evolved-bds-lean'}
                solvers{i} = @lean_evolved_bds_test;
            case {'bds-accelerated', 'bds_accelerated', 'accelerated-bds', ...
                    'accelerated_bds', 'lean-evolved-bds-full-options', ...
                    'lean-evolved-bds-options', 'lean_evolved_bds_options'}
                solvers{i} = @(fun, x0) bds_acceleration_test(fun, x0, true, true, true);
            case {'bds-accelerated-budget-limited', 'bds_accelerated_budget_limited', ...
                    'accelerated-bds-budget-limited', ...
                    'accelerated_bds_budget_limited', ...
                    'lean-evolved-bds-options-budget-limited', ...
                    'lean_evolved_bds_options_budget_limited'}
                solvers{i} = @bds_acceleration_budget_limited_test;
            case 'lean-evolved-bds-no-memory'
                solvers{i} = @(fun, x0) bds_acceleration_test(fun, x0, false, true, true);
            case 'lean-evolved-bds-memory-only'
                solvers{i} = @(fun, x0) bds_acceleration_test(fun, x0, true, false, false);
            case 'lean-evolved-bds-pattern-momentum'
                solvers{i} = @(fun, x0) bds_acceleration_test(fun, x0, false, true, true);
            case 'bds-no-additional-stopping'
                solvers{i} = @cbds_simplified_test;
            case 'bds-simplified'
                solvers{i} = @cbds_simplified_test;
            case 'cbds-simplified'
                solvers{i} = @cbds_simplified_test;
            case {'nbds-r3', 'nbds_r3'}
                solvers{i} = @nbds_r3_test;
            case {'nbds-f10', 'nbds_f10'}
                solvers{i} = @nbds_f10_test;
            case {'nbds-q3', 'nbds_q3'}
                solvers{i} = @nbds_q3_test;
            case {'nbds-tq3', 'nbds_tq3'}
                solvers{i} = @nbds_tq3_test;
            case 'cbds-orig-termination'
                solvers{i} = @cbds_orig_termination_test;
            case 'cbds-orig-smart-alpha-init'
                solvers{i} = @cbds_orig_smart_alpha_init_test;
            case {'auto-accelerated-all-on-500n-no-optional-stop', ...
                    'auto_accelerated_all_on_500n_no_optional_stop'}
                solvers{i} = @(fun, x0) accelerated_auto_stopping_profile_test( ...
                    fun, x0, false, false, 20, 1e-6, 1, 1e-6);
            case {'auto-accelerated-all-on-500n-default-combined-stop', ...
                    'auto_accelerated_all_on_500n_default_combined_stop'}
                solvers{i} = @accelerated_auto_combined_stop_500n_test;
            case {'accelerated-unit-500n', 'accelerated_unit_500n'}
                solvers{i} = @accelerated_unit_500n_test;
            case {'accelerated-auto-500n', 'accelerated_auto_500n'}
                solvers{i} = @accelerated_auto_500n_test;
            case {'accelerated-auto-combined-stop-500n', ...
                    'accelerated_auto_combined_stop_500n'}
                solvers{i} = @accelerated_auto_combined_stop_500n_test;
            otherwise
                [is_stopping_candidate, func_window_size, func_tol, ...
                    grad_window_size, grad_tol, use_function_stop, ...
                    use_gradient_stop, lipschitz_constant, ...
                    use_gradient_reference_consistency, ...
                    grad_reference_finite_difference_error_tol] = ...
                    parse_accelerated_auto_stopping_solver_name( ...
                    options.solver_names{i});
                if is_stopping_candidate
                    solvers{i} = @(fun, x0) accelerated_auto_stopping_profile_test( ...
                        fun, x0, use_function_stop, use_gradient_stop, ...
                        func_window_size, func_tol, grad_window_size, grad_tol, ...
                        lipschitz_constant, use_gradient_reference_consistency, ...
                        grad_reference_finite_difference_error_tol);
                else
                    [is_auto_candidate, c_x, c_tau, use_acceleration, ...
                        use_unit_steps, max_eval_factor] = ...
                        parse_auto_alpha_init_solver_name(options.solver_names{i});
                    if ~is_auto_candidate
                        error('Unknown solver');
                    end
                    has_auto_alpha_candidate = true;
                    solvers{i} = @(fun, x0) auto_alpha_init_profile_test( ...
                        fun, x0, c_x, c_tau, use_acceleration, ...
                        use_unit_steps, max_eval_factor);
                end
        end
    end
    if has_auto_alpha_candidate
        auto_budgets = cellfun(@auto_alpha_init_budget_from_name, ...
            options.solver_names(cellfun(@is_auto_alpha_init_solver_name, ...
            options.solver_names)));
        if numel(unique(auto_budgets)) ~= 1
            error('profile_optiprofiler:MixedAutoAlphaBudgets', ...
                'Automatic initial-step candidates in one benchmark must use one budget.');
        end
        required_max_eval_factor = auto_budgets(1);
        if isfield(options, 'max_eval_factor') && ...
                options.max_eval_factor ~= required_max_eval_factor
            error('profile_optiprofiler:AutoAlphaBudgetMismatch', ...
                'The profile max_eval_factor must match the candidate labels.');
        end
        options.max_eval_factor = required_max_eval_factor;
    end
    if ~isfield(options, 'benchmark_id') || isempty(options.benchmark_id)
        options.benchmark_id = [];
        for i = 1:length(solvers)
            if i == 1
                options.benchmark_id = strrep(options.solver_names{i}, '-', '_');
            else
                options.benchmark_id = [options.benchmark_id, '_', ...
                    strrep(options.solver_names{i}, '-', '_')];
            end
        end
        if isfield(options, 'problem_names')
            options.benchmark_id = [options.benchmark_id, '_', ...
                options.problem_names{1}, '_', num2str(options.n_runs)];
        else
            options.benchmark_id = [options.benchmark_id, '_', ...
                num2str(options.mindim), '_', num2str(options.maxdim), '_', ...
                num2str(options.n_runs)];
        end
    end
    switch options.feature_name
        case 'noisy'
            % If the noise level is written in scientific notation, we will use the power to express the noise level in benchmark_id.
            % If the noise level is written in decimal notation, we will use the decimal notation to express the noise level in benchmark_id.
            % For example, if the noise level is 1e-3, we will use 3 to express the noise level in benchmark_id.
            % If the noise level is 0.001, we will use 0_001 to express the noise level in benchmark_id.
            if abs(log10(options.noise_level) - floor(log10(options.noise_level))) < 1e-10 || abs(log10(options.noise_level) - ceil(log10(options.noise_level))) < 1e-10
                options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(-log10(options.noise_level))), '_no_rotation'];
            else
                noise_level_str = strrep(num2str(options.noise_level), '.', '_');
                options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', noise_level_str, '_no_rotation'];
            end
        case 'custom'
            if isfield(options, 'feature_stamp')
                options.benchmark_id = [options.benchmark_id, '_', options.feature_stamp];
            else
                % The same notation as above. The only difference is that we will distinguish permuted_noisy and rotation_noisy.
                if abs(log10(options.noise_level) - floor(log10(options.noise_level))) < 1e-10 || abs(log10(options.noise_level) - ceil(log10(options.noise_level))) < 1e-10
                    noise_level_str = int2str(int32(-log10(options.noise_level)));
                else
                    noise_level_str = strrep(num2str(options.noise_level), '.', '_');
                end
                options.benchmark_id = [options.benchmark_id, '_', 'permuted_noisy', '_', noise_level_str];
                if ~(isfield(options, 'permuted') && options.permuted)
                    options.benchmark_id = strrep(options.benchmark_id, 'permuted', 'rotation');
                end
            end
        case 'truncated'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(options.significant_digits)];
            options = rmfield(options, 'noise_level');
        case 'quantized'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(-log10(options.mesh_size)))];
        case 'random_nan'
            nan_rate_pct = round(100 * options.nan_rate);
            nan_rate_str = sprintf('%02d', nan_rate_pct);
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_pct', nan_rate_str];
        case 'perturbed_x0'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name];
            % For perturbed_x0, we will only use decimal notation to express the perturbation level in benchmark_id.
            % For example, if the perturbation level is 1e-3, we will use 0_001 to express the perturbation level in benchmark_id.
            % If the perturbation level is 10, we will use 10 to express the perturbation level in benchmark_id.
            perturbation_level_str = strrep(num2str(options.perturbation_level), '.', '_');
            options.benchmark_id = [options.benchmark_id, '_', perturbation_level_str];
    otherwise
        options.benchmark_id = [options.benchmark_id, '_', options.feature_name];
    end
    if options.run_plain
        options.benchmark_id = [options.benchmark_id, '_plain'];
    end
    if isfield(options, 'plibs')
        options.benchmark_id = [options.benchmark_id, '_', options.plibs];
    else
        % If the plibs is not provided, we will use the default value, which is 's2mpj'.
        options.benchmark_id = [options.benchmark_id, '_s2mpj'];
    end
    options.benchmark_id = [options.benchmark_id, '_', time_str];
    
    if ~isfield(options, 'problem_names')
        if isfield(options, 'plibs') && strcmpi(options.plibs, 'matcutest')
            options.excludelist = {'ARGTRIGLS',...
            'BROWNAL',...
            'COATING',...
            'DIAMON2DLS',...
            'DIAMON3DLS',...
            'DMN15102LS', ...
            'DMN15103LS',...
            'DMN15332LS',...
            'DMN15333LS',...
            'DMN37142LS',...
            'DMN37143LS',...
            'ERRINRSM',...
            'HYDC20LS',...
            'LRA9A',...
            'LRCOVTYPE',...
            'LUKSAN12LS',...
            'LUKSAN14LS',...
            'LUKSAN17LS',...
            'LUKSAN21LS',...
            'LUKSAN22LS',...
            'MANCINO',...
            'PENALTY2',...
            'PENALTY3',...
            'VARDIM',...
            'GAUSS1LS',...
            'GAUSS2LS',...
            'GAUSS3LS',...
            'CERI651ALS',...
            'CERI651BLS',...
            'CERI651CLS',...
            'CERI651DLS',...
            'CERI651ELS',...
            'MISRA1ALS',...
            'OSBORNEA',...
            'ECKERLE4LS',...
            'NELSONLS'};
        else
            options.excludelist = {'DIAMON2DLS',...
            'DIAMON2D',...
            'DIAMON3DLS',...
            'DIAMON3D',...
            'DMN15102LS',...
            'DMN15102',...
            'DMN15103LS',...
            'DMN15103',...
            'DMN15332LS',...
            'DMN15332',...
            'DMN15333LS',...
            'DMN15333',...
            'DMN37142LS',...
            'DMN37142',...
            'DMN37143LS',...
            'DMN37143',...
            'ROSSIMP3_mp',...
            'BAmL1SPLS',...
            'FBRAIN3LS',...
            'GAUSS1LS',...
            'GAUSS2LS',...
            'GAUSS3LS',...
            'HYDC20LS',...
            'HYDCAR6LS',...
            'LUKSAN11LS',...
            'LUKSAN12LS',...
            'LUKSAN13LS',...
            'LUKSAN14LS',...
            'LUKSAN17LS',...
            'LUKSAN21LS',...
            'LUKSAN22LS',...
            'METHANB8LS',...
            'METHANL8LS',...
            'SPINLS',...
            'VESUVIALS',...
            'VESUVIOLS',...
            'VESUVIOULS',...
            'YATP1CLS',...
            'MISRA1ALS',...
            'OSBORNEA',...
            'ECKERLE4LS',...
            'NELSONLS'};
        end
    end
    
    if strcmp(options.feature_name, 'custom')

        if strcmp(custom_feature_kind, 'permuted')
            options.mod_x0 = @mod_x0_permuted;
            options.mod_affine = @perm_affine;
            if isfield(options, 'permuted')
                options = rmfield(options, 'permuted');
            end
        else
            % We need mod_x0 to make sure that the linearly transformed problem is mathematically equivalent
            % to the original problem.
            options.mod_x0 = @mod_x0;
            options.mod_affine = @mod_affine;
        end
        % We only modify mod_fun since we are dealing with unconstrained problems.
        switch options.noise_level
            case 1e-1
                options.mod_fun = @mod_fun_1;
            case 1e-2
                options.mod_fun = @mod_fun_2;
            case 1e-3
                options.mod_fun = @mod_fun_3;
            case 1e-4
                options.mod_fun = @mod_fun_4;
            case 1e-5
                options.mod_fun = @mod_fun_5;
            case 1e-6
                options.mod_fun = @mod_fun_6;
            otherwise
                error('Unknown noise level');
        end
            options = rmfield(options, 'noise_level');

    end
    [solver_scores, profile_scores, curves] = benchmark(solvers, options);
    postprocess_summary_feature_titles(options, feature_display_name);

end
function postprocess_summary_feature_titles(options, feature_display_name)

    if isempty(feature_display_name) || ~isfield(options, 'savepath') || ~isfield(options, 'benchmark_id')
        return;
    end

    path_out = fullfile(options.savepath, options.benchmark_id);
    if ~exist(path_out, 'dir')
        return;
    end

    listing = dir(fullfile(path_out, '*', 'summary_*.pdf'));
    for i_file = 1:numel(listing)
        try
            fix_summary_feature_titles(fullfile(listing(i_file).folder, listing(i_file).name), feature_display_name);
        catch err
            warning('profile_optiprofiler:SummaryTitlePostprocessFailed', ...
                'Failed to update the feature title in %s: %s', ...
                fullfile(listing(i_file).folder, listing(i_file).name), err.message);
        end
    end

    try
        summary_files = dir(fullfile(path_out, '*', 'summary_*.pdf'));
        summary_time_stamps = arrayfun(@(f) datetime(f.name(end-18:end-4), ...
            'InputFormat', 'yyyyMMdd_HHmmss'), summary_files);
        [~, idx] = sort(summary_time_stamps, 'descend');
        summary_files = summary_files(idx);
        summary_files = summary_files(1:min(10, numel(summary_files)));
        summary_paths = arrayfun(@(f) fullfile(f.folder, f.name), ...
            summary_files, 'UniformOutput', false);
        merge_summary_pdfs(summary_paths, fullfile(path_out, 'summary.pdf'));
    catch err
        warning('profile_optiprofiler:SummaryMergeAfterRetitleFailed', ...
            'Failed to rebuild summary.pdf after updating the feature title under %s: %s', ...
            path_out, err.message);
    end

end

function merge_summary_pdfs(summary_paths, output_file)

    if isempty(summary_paths)
        return;
    end

    if exist(output_file, 'file')
        delete(output_file);
    end

    if numel(summary_paths) == 1
        copyfile(summary_paths{1}, output_file);
        return;
    end

    command = ['pdfunite ', strjoin(cellfun(@shell_quote, summary_paths, ...
        'UniformOutput', false), ' '), ' ', shell_quote(output_file)];
    [status, output] = system(command);
    if status ~= 0
        error('profile_optiprofiler:PdfMergeFailed', ...
            'pdfunite failed while rebuilding %s: %s', output_file, output);
    end

end

function quoted = shell_quote(text)

    quoted = ['''', strrep(char(text), '''', '''"''"'''), ''''];

end

function label = format_noise_level_for_display(noise_level)

    exponent = round(log10(noise_level));
    if noise_level > 0 && abs(noise_level - 10^exponent) <= 10 * eps(max(1, abs(noise_level)))
        label = sprintf('1e%d', exponent);
    else
        label = num2str(noise_level, '%.15g');
    end

end

function ensure_optiprofiler_on_path()

    if exist('benchmark', 'file')
        return;
    end

    home_dir = char(java.lang.System.getProperty('user.home'));
    optiprofiler_root = fullfile(home_dir, 'local', 'optiprofiler');
    candidate_paths = { ...
        fullfile(optiprofiler_root, 'matlab', 'optiprofiler', 'src'), ...
        fullfile(optiprofiler_root, 'matlab', 'optiprofiler', 'problem_libs'), ...
        fullfile(optiprofiler_root, 'matlab', 'optiprofiler'), ...
        fullfile(optiprofiler_root, 'matlab'), ...
        fullfile(optiprofiler_root, 'python', 'optiprofiler') ...
    };

    for i_path = 1:numel(candidate_paths)
        if exist(candidate_paths{i_path}, 'dir')
            addpath(candidate_paths{i_path});
        end
    end

    if ~exist('benchmark', 'file')
        error('profile_optiprofiler:OptiProfilerNotFound', ...
            'Cannot find benchmark. Add the OptiProfiler MATLAB package to the path.');
    end

end

function x0 = mod_x0(rand_stream, problem)

    [Q, R] = qr(rand_stream.randn(problem.n));
    Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
    x0 = Q * problem.x0;
end

function x0 = mod_x0_permuted(rand_stream, problem)

    P = eye(problem.n);
    P = P(rand_stream.randperm(problem.n), :);
    x0 = P * problem.x0;
end

function f = mod_fun_1(x, rand_stream, problem)

    f = problem.fun(x);
    f = f + max(1, abs(f)) * 1e-1 * rand_stream.randn(1);
end

function f = mod_fun_2(x, rand_stream, problem)

    f = problem.fun(x);
    f = f + max(1, abs(f)) * 1e-2 * rand_stream.randn(1);
end

function f = mod_fun_3(x, rand_stream, problem)

    f = problem.fun(x);
    f = f + max(1, abs(f)) * 1e-3 * rand_stream.randn(1);
end

function f = mod_fun_4(x, rand_stream, problem)

    f = problem.fun(x);
    f = f + max(1, abs(f)) * 1e-4 * rand_stream.randn(1);
end

function f = mod_fun_5(x, rand_stream, problem)

    f = problem.fun(x);
    f = f + max(1, abs(f)) * 1e-5 * rand_stream.randn(1);
end

function f = mod_fun_6(x, rand_stream, problem)

    f = problem.fun(x);
    f = f + max(1, abs(f)) * 1e-6 * rand_stream.randn(1);
end

function [A, b, inv] = mod_affine(rand_stream, problem)

    [Q, R] = qr(rand_stream.randn(problem.n));
    Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
    A = Q';
    b = zeros(problem.n, 1);
    inv = Q;
end

function [A, b, inv] = perm_affine(rand_stream, problem)

    p = rand_stream.randperm(problem.n);
    P = eye(problem.n);
    P = P(p,:);
    A = P';
    b = zeros(problem.n, 1);    
    inv = P;
end

function x = fminsearch_test(fun, x0)

    % Dimension
    n = numel(x0);

    % Set MAXFUN to the maximum number of function evaluations.
    MaxFunctionEvaluations = 500*n;

    % Set the value of StepTolerance. The default value is 1e-4.
    tol = 1e-6;

    options = optimset("MaxFunEvals", MaxFunctionEvaluations, "maxiter", 10^20, "tolfun", eps, "tolx", tol);    

    x = fminsearch(fun, x0, options);
    
end

function x = fminsearch_200n_test(fun, x0)

    options.MaxFunctionEvaluations = 200*length(x0);
    x = fminsearch_wrapper(fun, x0, options);
    
end

function x = fminunc_test(fun, x0)

    options = struct();
    
    % Set MAXFUN to the maximum number of function evaluations.
    if isfield(options, "MaxFunctionEvaluations")
        MaxFunctionEvaluations = options.MaxFunctionEvaluations;
    else
        MaxFunctionEvaluations = 500 * length(x0);
    end
    
    % Set the value of StepTolerance.
    if isfield(options, "StepTolerance")
        tol = options.StepTolerance;
    else
        tol = 1e-6;
    end
    
    % Set the target of the objective function.
    if isfield(options, "ftarget")
        ftarget = options.ftarget;
    else
        ftarget = -inf;
    end
    
    % Set the options of fminunc.
    options = optimoptions("fminunc", ...
        "Algorithm", "quasi-newton", ...
        "HessUpdate", "bfgs", ...
        "MaxFunctionEvaluations", MaxFunctionEvaluations, ...
        "MaxIterations", 10^20, ...
        "ObjectiveLimit", ftarget, ...
        "StepTolerance", tol, ...
        "OptimalityTolerance", eps);

    x = fminunc(fun, x0, options);

end

function x = fminunc_adaptive(fun, x0, noise_level)

    options.with_gradient = true;
    options.noise_level = noise_level;
    x = fminunc_wrapper(fun, x0, options);

end

function x = fminunc_adaptive_tmp(fun, x0, noise_level)

    options.with_gradient = true;
    options.noise_level = noise_level;
    x = fminunc_wrapper_tmp(fun, x0, options);

end

function x = bfgs_200n_test(fun, x0, with_gradient, noise_level)

    n = numel(x0);
    options = struct();
    options.with_gradient = with_gradient;

    if with_gradient
        options.noise_level = noise_level;
        options.MaxFunctionEvaluations = max(1, floor(200 * n / (n + 1)));
    else
        options.MaxFunctionEvaluations = 200 * n;
    end

    x = fminunc_wrapper(fun, x0, options);

end

function x = fd_bfgs_500n_test(fun, x0, with_gradient, noise_level)

    options.MaxObjectiveEvaluations = 500*length(x0);
    options.StepTolerance = 1e-6;
    options.with_gradient = with_gradient;
    if with_gradient
        options.noise_level = noise_level;
    end
    x = fminunc_budgeted_wrapper(fun, x0, options);

end

function x = praxis_test(fun, x0)
    %xtol = eps;
    xtol = 1e-6;
    %xtol = 1e-3;
    h0 = 1;
    n = length(x0);
    prin = 0;
    funn = @(x, n) fun(x);
    addpath('praxis/matlab');
    [~, x] = praxis(xtol, h0, n, prin, x0, funn);
end

function x = bds_test(fun, x0)

    x = bds(fun, x0);
    
end

function x = ds_orig_test(fun, x0)

    option.Algorithm = 'ds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);

end

function x = ds_test(fun, x0)

    option.Algorithm = 'ds';
    x = bds(fun, x0, option);

end

function x = ds_200n_test(fun, x0)

    option.Algorithm = 'ds';
    option.MaxFunctionEvaluations = 200*length(x0);
    x = bds(fun, x0, option);

end

function x = cbds_200n_test(fun, x0)

    option.Algorithm = 'cbds';
    option.MaxFunctionEvaluations = 200*length(x0);
    option.StepTolerance = 1e-6;
    x = bds(fun, x0, option);

end

function x = cbds_500n_test(fun, x0)

    option.Algorithm = 'cbds';
    option.MaxFunctionEvaluations = 500*length(x0);
    option.StepTolerance = 1e-12;
    x = bds(fun, x0, option);

end

function x = ds_block_test(fun, x0)

    option.Algorithm = 'ds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
end

function x = ds_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'ds';
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
end

function x = ds_randomized_orthogonal_test(fun, x0)

    option.Algorithm = 'ds';
    [Q,R] = qr(randn(numel(x0), numel(x0)));
    Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
    option.direction_set = Q;
    x = bds(fun, x0, option);
    
end

function x = ds_500n_test(fun, x0)

    option.Algorithm = 'ds';
    option.MaxFunctionEvaluations = 500*length(x0);
    x = bds(fun, x0, option);

end

function x = ds_randomized_orthogonal_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'ds';
    [Q,R] = qr(randn(numel(x0), numel(x0)));
    Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
    option.direction_set = Q;
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

function x = pbds_test(fun, x0)

    option.Algorithm = 'pbds';
    x = bds(fun, x0, option);
    
end

function x = pbds_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'pbds';
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);

end

function x = pbds_orig_test(fun, x0)

    option.Algorithm = 'pbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.Algorithm = 'pbds';
    x = bds(fun, x0, option);
    
end

function x = pbds_permuted_0_test(fun, x0)

    option.Algorithm = 'pbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.permuting_period = 0;
    x = bds_development(fun, x0, option);
    
end

function x = pbds_permuted_1_test(fun, x0)

    option.Algorithm = 'pbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.permuting_period = 1;
    x = bds_development(fun, x0, option);
    
end

function x = pbds_permuted_quarter_n_test(fun, x0)

    option.Algorithm = 'pbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.permuting_period = ceil(numel(x0)/4);
    x = bds_development(fun, x0, option);
    
end

function x = pbds_permuted_half_n_test(fun, x0)

    option.Algorithm = 'pbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.permuting_period = ceil(numel(x0)/2);
    x = bds_development(fun, x0, option);
    
end

function x = pbds_permuted_n_test(fun, x0)

    option.Algorithm = 'pbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.permuting_period = numel(x0);
    x = bds_development(fun, x0, option);
    
end

function x = cbds_test(fun, x0)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = cbds_development_test(fun, x0)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds_development(fun, x0, option);
    
end

function x = cbds_cycle_all_test(fun, x0)

    option.Algorithm = 'cycle_all';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds_development(fun, x0, option);
    
end

function x = cbds_cycle_single_1_test(fun, x0)

    option.Algorithm = 'cycle_single_1';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds_development(fun, x0, option);
    
end

function x = cbds_cycle_single_2_test(fun, x0)

    option.Algorithm = 'cycle_single_2';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds_development(fun, x0, option);
    
end

function x = cbds_cycle_single_3_test(fun, x0)

    option.Algorithm = 'cycle_single_3';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds_development(fun, x0, option);
    
end

function x = cbds_cycle_single_4_test(fun, x0)

    option.Algorithm = 'cycle_single_4';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds_development(fun, x0, option);
    
end

function x = cbds_block_test(fun, x0)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = cbds_orig_test(fun, x0)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = cbds_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'cbds';
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

function x = cbds_num_blocks_half_n_test(fun, x0)

    option.num_blocks = ceil(numel(x0)/2);
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = cbds_num_blocks_quarter_n_test(fun, x0)

    option.num_blocks = ceil(numel(x0)/4);
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = cbds_num_blocks_eighth_n_test(fun, x0)

    option.num_blocks = ceil(numel(x0)/8);
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = cbds_randomized_orthogonal_test(fun, x0)

    [Q,R] = qr(randn(numel(x0), numel(x0)));
    Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
    option.direction_set = Q;
    x = bds(fun, x0, option);
    
end

function x = cbds_randomized_orthogonal_test_noisy(fun, x0, is_noisy)

    [Q,R] = qr(randn(numel(x0), numel(x0)));
    Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
    option.direction_set = Q;
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

function x = cbds_randomized_gaussian_test(fun, x0)

    option.direction_set = randn(numel(x0), numel(x0));
    option.direction_set = option.direction_set ./ vecnorm(option.direction_set);
    x = bds(fun, x0, option);
    
end

function x = cbds_randomized_gaussian_test_noisy(fun, x0, is_noisy)

    option.direction_set = randn(numel(x0), numel(x0));
    option.direction_set = option.direction_set ./ vecnorm(option.direction_set);
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

function x = cbds_permuted_test(fun, x0)

    p = randperm(numel(x0));
    P = eye(numel(x0));
    P = P(p,:);
    option.direction_set = P;
    x = bds(fun, x0, option);
    
end

function x = cbds_permuted_test_noisy(fun, x0, is_noisy)

    p = randperm(numel(x0));
    P = eye(numel(x0));
    P = P(p,:);
    option.direction_set = P;
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

% function x = cbds_construct_directions_from_x0_test(fun, x0) 

%     option.Algorithm = 'cbds';

%     % Ensure x0 is a column vector
%     x0 = x0(:);
%     n = length(x0);

%     % Normalize the input vector
%     x0_hat = x0 / norm(x0);

%     % Construct the first standard basis vector
%     e1 = zeros(n, 1);
%     e1(1) = 1;

%     % Check if x0 is already aligned with e1
%     if norm(x0_hat - e1) < 1e-10
%         R = eye(n); % If x0 is already aligned with e1, return identity matrix
%     else
%         % Compute the Householder vector
%         u = x0_hat - e1;

%         % Avoid numerical instability when u is close to zero
%         if norm(u) < 1e-10
%             % Use a fallback: set u to a simple direction
%             u = zeros(n, 1);
%             u(2) = 1; % Choose a valid direction orthogonal to e1
%         else
%             u = u / norm(u); % Normalize u
%         end

%         % Compute the Householder reflection matrix implicitly
%         % H = I - 2 * (u * u'), but we avoid forming H explicitly
%         % Instead, we compute R directly
%         R = eye(n) - 2 * (u * u'); % Compute the full rotation matrix

%         % Ensure that the first column of R is aligned with x0.
%     end

%     option.direction_set = R;
%     option.expand = 2;
%     option.shrink = 0.5;

%     x = bds(fun, x0, option);
    
% end

function x = cbds_construct_directions_from_x0_test(fun, x0) 

    option.Algorithm = 'cbds';

    % Ensure x0 is a column vector
    x0 = x0(:);

    % Extract the sign of x0 to determine the direction towards the origin.
    % If x0(i) is exactly 0, sign() returns 0. We default to 1 to maintain full rank.
    s = sign(x0);
    s(s == 0) = 1;
    
    % Construct the Directed Coordinate Basis:
    % We flip the sign (-s) so that the basis vector points TOWARDS the origin.
    % Using diag() ensures the matrix remains 100% sparse and orthogonal.
    D = diag(-s);

    option.direction_set = D;
    option.expand = 2;
    option.shrink = 0.5;

    x = bds(fun, x0, option);
    
end

function x = rbds_orig_test(fun, x0)

    option.Algorithm = 'rbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = rbds_test(fun, x0)

    option.Algorithm = 'rbds';
    x = bds(fun, x0, option);
    
end

function x = rbds_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'rbds';
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

function x = rbds_zero_delay_test(fun, x0)

    option.batch_size = 1;
    option.expand = 2;
    option.shrink = 0.5;
    option.replacement_delay = 0;
    x = bds(fun, x0, option);
    
end

function x = rbds_one_delay_test(fun, x0)

    option.batch_size = 1;
    option.expand = 2;
    option.shrink = 0.5;
    option.replacement_delay = 1;
    x = bds(fun, x0, option);
    
end

function x = rbds_eighth_delay_test(fun, x0)

    option.batch_size = 1;
    option.expand = 2;
    option.shrink = 0.5;
    option.replacement_delay = ceil(numel(x0)/8);
    x = bds(fun, x0, option);
    
end

function x = rbds_quarter_delay_test(fun, x0)

    option.batch_size = 1;
    option.expand = 2;
    option.shrink = 0.5;
    option.replacement_delay = ceil(numel(x0)/4);
    x = bds(fun, x0, option);
    
end

function x = rbds_half_delay_test(fun, x0)

    option.batch_size = 1;
    option.expand = 2;
    option.shrink = 0.5;
    option.replacement_delay = ceil(numel(x0)/2);
    x = bds(fun, x0, option);
    
end

function x = rbds_n_minus_1_delay_test(fun, x0)

    option.batch_size = 1;
    option.expand = 2;
    option.shrink = 0.5;
    option.replacement_delay = numel(x0) - 1;
    x = bds(fun, x0, option);
    
end

function x = rbds_batch_size_n_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.batch_size = numel(x0);
    option.replacement_delay = 0;
    x = bds(fun, x0, option);
    
end

function x = rbds_batch_size_half_n_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.batch_size = ceil(numel(x0)/2);
    option.replacement_delay = 0;
    x = bds(fun, x0, option);

end

function x = rbds_batch_size_quarter_n_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.batch_size = ceil(numel(x0)/4);
    option.replacement_delay = 0;
    x = bds(fun, x0, option);

end

function x = rbds_batch_size_eighth_n_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.batch_size = ceil(numel(x0)/8);
    option.replacement_delay = 0;
    x = bds(fun, x0, option);

end

function x = rbds_batch_size_one_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.batch_size = 1;
    option.replacement_delay = 0;
    x = bds(fun, x0, option);

end

function x = rbds_batch_size_one_seed_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.batch_size = 1;
    option.replacement_delay = 0;
    option.seed = round(1e4 * option.batch_size) + round(1e6 * option.replacement_delay) + round(sum(x0));
    x = bds(fun, x0, option);

end

function x = rbds_batch_size_one_seed_expand_cov_test(fun, x0)

    n = numel(x0);
    option.expand = 2;
    option.shrink = 2^(-1/(n+1));
    option.batch_size = 1;
    option.replacement_delay = 0;
    option.seed = round(1e4 * option.batch_size) + round(1e6 * option.replacement_delay) + round(sum(x0));
    x = bds(fun, x0, option);

end

function x = rbds_batch_size_one_seed_shrink_cov_test(fun, x0)

    n = numel(x0);
    option.shrink = 0.5;
    option.expand = 0.5^(-(n+1));
    option.batch_size = 1;
    option.replacement_delay = 0;
    option.seed = round(1e4 * option.batch_size) + round(1e6 * option.replacement_delay) + round(sum(x0));
    x = bds(fun, x0, option);

end

function x = pads_orig_test(fun, x0)

    option.Algorithm = 'pads';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = pads_test(fun, x0)

    option.Algorithm = 'pads';
    x = bds(fun, x0, option);
    
end

function x = pads_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'pads';
    option.is_noisy = is_noisy;
    x = bds(fun, x0, option);
    
end

function x = scbds_test(fun, x0)

    option.Algorithm = 'scbds';
    x = bds_development(fun, x0, option);
    
end

function x = scbds_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'scbds';
    option.is_noisy = is_noisy;
    x = bds_development(fun, x0, option);
    
end

function x = pds_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    x = pds(fun, x0, option);
    
end

function x = pds_500n_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.MaxFunctionEvaluations = 500*length(x0);
    x = pds(fun, x0, option);

end

function x = pds_200n_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.MaxFunctionEvaluations = 200*length(x0);
    x = pds(fun, x0, option);
    
end

function x = bfo_test(fun, x0)

    ensure_bfo_on_path();

    % Dimension
    n = numel(x0);

    StepTolerance = 1e-6;
    maxeval = 500*n;

    [x, ~, ~, ~, ~] = bfo(fun, x0, 'epsilon', StepTolerance, 'maxeval', maxeval);
    
end

function x = bfo_200n_test(fun, x0)

    ensure_bfo_on_path();
    options.MaxFunctionEvaluations = 200*length(x0);
    x = bfo_wrapper(fun, x0, options);
    
end

function x = newuoa_test(fun, x0)

    ensure_newuoa_on_path();
    options.maxfun = 500*length(x0);
    x = newuoa(fun, x0, options);
    
end

function x = newuoa_200n_test(fun, x0)

    ensure_newuoa_on_path();
    options.maxfun = 200*length(x0);
    x = newuoa(fun, x0, options);
    
end

function x = lam_test(fun, x0)

    x = lam(fun, x0);
    
end

function x = fmds_test(fun, x0)

    x = fmds(fun, x0);
    
end

function x = nomad_test(fun, x0)
    
    x = nomad_with_budget_test(fun, x0, 200);
    
end

function x = nomad_500n_test(fun, x0)
    
    x = nomad_with_budget_test(fun, x0, 500);
    
end

function x = nomad_with_budget_test(fun, x0, max_eval_factor)
    
    % Dimension:
    n = numel(x0);

    ensure_nomad_on_path();

    % Set the default bounds.
    lb = -inf(n, 1);
    ub = inf(n, 1);

    % Set MAXFUN to the maximum number of function evaluations.
    MaxFunctionEvaluations = max_eval_factor*n;

    % We deliberately do not set MIN_FRAME_SIZE or MIN_MESH_SIZE here. In
    % NOMAD 4, their parameter documentation says "No default value"; during
    % parameter checking, however, undefined minimum frame/mesh sizes are
    % internally expanded to 0 for continuous variables, or to granularity
    % for granular variables. For our continuous unconstrained CUTEst/S2MPJ
    % tests, leaving them unset is therefore equivalent to using 0, so NOMAD
    % will not stop early at a positive mesh/frame tolerance such as 1e-6.
    % This matches the Python PyNomad wrapper, where only MAX_BB_EVAL and
    % display/output parameters are supplied.
    params = struct('BB_OUTPUT_TYPE', 'OBJ', ...
    'MAX_BB_EVAL', num2str(MaxFunctionEvaluations), 'max_eval',num2str(MaxFunctionEvaluations));

    % As of NOMAD version 4.4.0 and OptiProfiler commit 24d8cc0, the following line is 
    % necessary. Otherwise, NOMAD will throw an error, complaining that the blackbox 
    % evaluation fails. This seems to be because OptiProfiler wraps the function 
    % handle in a way that NOMAD does not expect: NOMAD expects a function handle 
    % `fun` with the signature fun(x), where x is a column vector, while OptiProfiler 
    % produces one with the signature @(varargin)featured_problem.fun(varargin{:}).
    fun = @(x) fun(x(:));

    [x, ~, ~, ~, ~] = nomadOpt(fun,x0,lb,ub,params);
    
end

function ensure_bfo_on_path()

    if exist('bfo', 'file')
        return;
    end

    home_dir = char(java.lang.System.getProperty('user.home'));
    bfo_roots = { ...
        getenv('BDS_BFO_ROOT'), ...
        fullfile(home_dir, 'local', 'BFO'), ...
        fullfile(home_dir, 'Documents', 'Nutstore', 'Transfer', ...
        'optiprofiler_transfer'), ...
        fullfile(home_dir, 'Documents', 'optiprofiler_results')};
    candidate_paths = {};
    for i_root = 1:numel(bfo_roots)
        if ~isempty(bfo_roots{i_root})
            candidate_paths = [candidate_paths, { ...
                bfo_roots{i_root}, ...
                fullfile(bfo_roots{i_root}, 'src'), ...
                fullfile(bfo_roots{i_root}, 'matlab')}];
        end
    end

    for i_path = 1:numel(candidate_paths)
        if exist(candidate_paths{i_path}, 'dir')
            addpath(candidate_paths{i_path});
        end
    end

    if ~exist('bfo', 'file')
        error('profile_optiprofiler:BfoNotFound', ...
            'Cannot find bfo. Add the BFO directory to the MATLAB path.');
    end

end

function ensure_nomad_on_path()

    if exist('nomadOpt', 'file')
        return;
    end

    home_dir = char(java.lang.System.getProperty('user.home'));
    nomad_root = fullfile(home_dir, 'local', 'nomad');
    candidate_paths = { ...
        fullfile(nomad_root, 'build', 'release', 'lib'), ...
        fullfile(nomad_root, 'interfaces', 'Matlab_MEX', 'Functions'), ...
        fullfile(nomad_root, 'build', 'release', 'interfaces', 'Matlab_MEX') ...
    };

    for i_path = 1:numel(candidate_paths)
        if exist(candidate_paths{i_path}, 'dir')
            addpath(candidate_paths{i_path});
        end
    end

    if ~exist('nomadOpt', 'file')
        error('profile_optiprofiler:NomadNotFound', ...
            ['Cannot find nomadOpt. Add the NOMAD Matlab_MEX Functions ', ...
            'and compiled MEX directories to the MATLAB path.']);
    end

end

function ensure_newuoa_on_path()

    if exist('newuoa', 'file')
        return;
    end

    home_dir = char(java.lang.System.getProperty('user.home'));
    prima_root = fullfile(home_dir, 'local', 'prima');
    candidate_paths = { ...
        fullfile(prima_root, 'matlab', 'interfaces'), ...
        fullfile(prima_root, 'matlab') ...
    };

    for i_path = 1:numel(candidate_paths)
        if exist(candidate_paths{i_path}, 'dir')
            addpath(candidate_paths{i_path});
        end
    end

    if ~exist('newuoa', 'file')
        error('profile_optiprofiler:NewuoaNotFound', ...
            'Cannot find newuoa. Add the PRIMA Matlab interfaces directory to the MATLAB path.');
    end

end

function x = lean_evolved_bds_test(fun, x0)

    x = lean_evolved_bds(fun, x0);

end

function x = bds_acceleration_test(fun, x0, use_memory, use_pattern, use_momentum)

    options.use_productive_direction_memory = use_memory;
    options.use_iteration_pattern_step = use_pattern;
    options.use_momentum_extrapolation = use_momentum;
    x = bds(fun, x0, options);

end

function x = bds_acceleration_profile_test( ...
    fun, x0, algorithm, use_memory, use_pattern, use_momentum, ...
    max_eval_factor, step_tolerance)

    options.Algorithm = algorithm;
    options.use_productive_direction_memory = use_memory;
    options.use_iteration_pattern_step = use_pattern;
    options.use_momentum_extrapolation = use_momentum;
    options.MaxFunctionEvaluations = max_eval_factor*length(x0);
    options.StepTolerance = step_tolerance;
    x = bds(fun, x0, options);

end

function x = bds_acceleration_budget_limited_test(fun, x0)

    options.use_productive_direction_memory = true;
    options.use_iteration_pattern_step = true;
    options.use_momentum_extrapolation = true;
    options.StepTolerance = 1e-12;
    x = bds(fun, x0, options);

end

function x = accelerated_unit_500n_test(fun, x0)

    options = accelerated_500n_profile_options(x0);
    options.alpha_init = 1;
    x = bds(fun, x0, options);

end

function x = accelerated_auto_500n_test(fun, x0)

    options = accelerated_500n_profile_options(x0);
    options.alpha_init = 'auto';
    x = bds(fun, x0, options);

end

function x = accelerated_auto_combined_stop_500n_test(fun, x0)

    options = accelerated_500n_profile_options(x0);
    options.alpha_init = 'auto';
    options.use_function_value_stop = true;
    options.func_window_size = 20;
    options.func_tol = 1e-6;
    options.use_estimated_gradient_stop = true;
    options.grad_window_size = 1;
    options.grad_tol = 1e-2;
    options.lipschitz_constant = 1e3;
    options.use_gradient_reference_consistency = true;
    options.grad_reference_finite_difference_error_tol = 1/30;
    x = bds(fun, x0, options);

end

function options = accelerated_500n_profile_options(x0)

    options.Algorithm = 'cbds';
    options.MaxFunctionEvaluations = 500*length(x0);
    options.StepTolerance = 1e-6;
    options.ftarget = -Inf;
    options.expand = 1.8;
    options.shrink = 0.5;
    options.is_noisy = false;
    options.forcing_function = @(alpha) alpha^2;
    options.reduction_factor = [0, eps, eps];
    options.polling_inner = 'opportunistic';
    options.cycling_inner = 1;
    options.seed = 0;
    options.use_productive_direction_memory = true;
    options.use_iteration_pattern_step = true;
    options.use_momentum_extrapolation = true;
    options.use_function_value_stop = false;
    options.use_estimated_gradient_stop = false;

end

function x = auto_alpha_init_profile_test( ...
        fun, x0, c_x, c_tau, use_acceleration, use_unit_steps, max_eval_factor)

    options.Algorithm = 'cbds';
    options.MaxFunctionEvaluations = max_eval_factor*length(x0);
    options.StepTolerance = 1e-6;
    options.ftarget = -Inf;
    options.expand = 1.8;
    options.shrink = 0.5;
    options.is_noisy = false;
    options.forcing_function = @(alpha) alpha^2;
    options.reduction_factor = [0, eps, eps];
    options.polling_inner = 'opportunistic';
    options.cycling_inner = 1;
    options.seed = 0;
    options.use_function_value_stop = false;
    options.use_estimated_gradient_stop = false;
    if use_unit_steps
        alpha_init = ones(length(x0), 1);
    else
        alpha_init = auto_alpha_init_candidate( ...
            x0, options.StepTolerance, c_x, c_tau);
    end

    if use_acceleration
        options.use_productive_direction_memory = true;
        options.use_iteration_pattern_step = true;
        options.use_momentum_extrapolation = true;
        options.alpha_init = alpha_init;
        x = bds(fun, x0, options);
    else
        options.alpha_init = alpha_init;
        x = bds(fun, x0, options);
    end

end

function x = accelerated_auto_stopping_profile_test(fun, x0, ...
    use_function_stop, use_gradient_stop, func_window_size, func_tol, ...
    grad_window_size, grad_tol, lipschitz_constant, ...
    use_gradient_reference_consistency, grad_reference_finite_difference_error_tol)

    if nargin < 9
        lipschitz_constant = 1e3;
    end
    if nargin < 10
        use_gradient_reference_consistency = false;
    end
    if nargin < 11
        grad_reference_finite_difference_error_tol = 1/30;
    end
    options.Algorithm = 'cbds';
    options.MaxFunctionEvaluations = 500*length(x0);
    options.StepTolerance = 1e-6;
    options.ftarget = -Inf;
    options.expand = 1.8;
    options.shrink = 0.5;
    options.is_noisy = false;
    options.forcing_function = @(alpha) alpha^2;
    options.reduction_factor = [0, eps, eps];
    options.polling_inner = 'opportunistic';
    options.cycling_inner = 1;
    options.seed = 0;
    options.use_productive_direction_memory = true;
    options.use_iteration_pattern_step = true;
    options.use_momentum_extrapolation = true;
    options.alpha_init = auto_alpha_init_candidate( ...
        x0, options.StepTolerance, 1, 1);
    options.use_function_value_stop = use_function_stop;
    options.func_window_size = func_window_size;
    options.func_tol = func_tol;
    options.use_estimated_gradient_stop = use_gradient_stop;
    options.grad_window_size = grad_window_size;
    options.grad_tol = grad_tol;
    options.lipschitz_constant = lipschitz_constant;
    options.use_gradient_reference_consistency = ...
        use_gradient_reference_consistency;
    options.grad_reference_finite_difference_error_tol = ...
        grad_reference_finite_difference_error_tol;
    x = bds(fun, x0, options);

end

function [matched, func_window_size, func_tol, grad_window_size, grad_tol, ...
        use_function_stop, use_gradient_stop, lipschitz_constant, ...
        use_gradient_reference_consistency, ...
        grad_reference_finite_difference_error_tol] = ...
    parse_accelerated_auto_stopping_solver_name(solver_name)

    expression = ['^auto-accelerated-all-on-500n-', ...
        '(stop|function-stop|gradient-stop)-', ...
        'fw([0-9]+)-ft1em([0-9]+)-gw([0-9]+)-gt1em([0-9]+)$'];
    solver_name_full = char(solver_name);
    solver_name_without_scale = regexprep(solver_name_full, ...
        '-grs[0-9]+(?:p[0-9]+)?$', '');
    solver_name_base = regexprep(solver_name_without_scale, ...
        '-grc[0-9]+(?:p[0-9]+)?$', '');
    solver_name_core = regexprep(solver_name_base, '-lc1em[0-9]+$', '');
    tokens = regexp(solver_name_core, expression, 'tokens', 'once');
    matched = ~isempty(tokens);
    if ~matched
        func_window_size = NaN;
        func_tol = NaN;
        grad_window_size = NaN;
        grad_tol = NaN;
        use_function_stop = false;
        use_gradient_stop = false;
        lipschitz_constant = NaN;
        use_gradient_reference_consistency = false;
        grad_reference_finite_difference_error_tol = NaN;
        return
    end

    stop_kind = tokens{1};
    func_window_size = str2double(tokens{2});
    func_tol = 10^(-str2double(tokens{3}));
    grad_window_size = str2double(tokens{4});
    grad_tol = 10^(-str2double(tokens{5}));
    use_function_stop = ~strcmp(stop_kind, 'gradient-stop');
    use_gradient_stop = ~strcmp(stop_kind, 'function-stop');
    lc_tokens = regexp(solver_name_full, ...
        '-lc1em([0-9]+)(?:-grc[0-9]+(?:p[0-9]+)?)?$', ...
        'tokens', 'once');
    if isempty(lc_tokens)
        lipschitz_constant = 1e3;
    else
        lipschitz_constant = 10^str2double(lc_tokens{1});
    end
    grc_tokens = regexp(solver_name_full, ...
        '-grc([0-9]+(?:p[0-9]+)?)(?:-grs[0-9]+(?:p[0-9]+)?)?$', ...
        'tokens', 'once');
    use_gradient_reference_consistency = ~isempty(grc_tokens);
    if use_gradient_reference_consistency
        grad_reference_finite_difference_error_tol = str2double( ...
            strrep(grc_tokens{1}, 'p', '.')) / 3;
    else
        grad_reference_finite_difference_error_tol = 1/30;
    end
    grs_tokens = regexp(solver_name_full, ...
        '-grs([0-9]+(?:p[0-9]+)?)$', 'tokens', 'once');
    if ~isempty(grs_tokens)
        % Historical solver names encoded the effective reference tolerance
        % as a multiplier of the old grad_tol. Convert that label at the
        % experiment boundary; the solver itself accepts only the resulting
        % single grad_tol.
        grad_tol = str2double(strrep(grs_tokens{1}, 'p', '.')) * grad_tol;
    end

end

function [matched, c_x, c_tau, use_acceleration, use_unit_steps, ...
        max_eval_factor] = ...
        parse_auto_alpha_init_solver_name(solver_name)

    candidate_expression = ['^auto-cx-([0-9]+(?:p[0-9]+)?)-', ...
        'ctau-([0-9]+(?:p[0-9]+)?)-', ...
        '(plain|accelerated-all-on)-([0-9]+)n$'];
    unit_expression = '^unit-(plain|accelerated-all-on)-([0-9]+)n$';
    tokens = regexp(char(solver_name), candidate_expression, 'tokens', 'once');
    unit_tokens = regexp(char(solver_name), unit_expression, 'tokens', 'once');
    use_unit_steps = isempty(tokens) && ~isempty(unit_tokens);
    if use_unit_steps
        tokens = {'1', '1', unit_tokens{1}, unit_tokens{2}};
    end
    matched = ~isempty(tokens);
    c_x = NaN;
    c_tau = NaN;
    use_acceleration = false;
    use_unit_steps = use_unit_steps && matched;
    max_eval_factor = NaN;
    if ~matched
        return;
    end

    c_x = str2double(strrep(tokens{1}, 'p', '.'));
    c_tau = str2double(strrep(tokens{2}, 'p', '.'));
    if ~(isfinite(c_x) && c_x > 0 && isfinite(c_tau) && c_tau > 0)
        error('profile_optiprofiler:InvalidAutoAlphaCoefficient', ...
            'Automatic initial-step coefficients must be finite and positive.');
    end
    use_acceleration = strcmp(tokens{3}, 'accelerated-all-on');
    max_eval_factor = str2double(tokens{4});
    if ~(isfinite(max_eval_factor) && max_eval_factor > 0 && ...
            max_eval_factor == floor(max_eval_factor))
        error('profile_optiprofiler:InvalidAutoAlphaBudget', ...
            'The automatic initial-step budget must be a positive integer.');
    end

end

function matched = is_auto_alpha_init_solver_name(solver_name)

    [matched, ~, ~, ~, ~, ~] = parse_auto_alpha_init_solver_name(solver_name);

end

function max_eval_factor = auto_alpha_init_budget_from_name(solver_name)

    [matched, ~, ~, ~, ~, max_eval_factor] = ...
        parse_auto_alpha_init_solver_name(solver_name);
    if ~matched
        error('profile_optiprofiler:InvalidAutoAlphaSolverName', ...
            'Expected an automatic initial-step candidate label.');
    end

end

function x = cbds_simplified_test(fun, x0)

    x = bds_simplified(fun, x0);

end

function x = nbds_r3_test(fun, x0)

    options = nbds_profile_options(x0);
    options.weak_min_failures = 3;
    options.weak_accept_resets_failures = true;
    [x, ~, ~, ~] = nbds_simplified(fun, x0, options);

end

function x = nbds_f10_test(fun, x0)

    options = nbds_profile_options(x0);
    options.weak_min_failures = 3;
    options.weak_accept_resets_failures = false;
    options.max_weak_per_cycle_fraction = 0.10;
    [x, ~, ~, ~] = nbds_simplified(fun, x0, options);

end

function x = nbds_q3_test(fun, x0)

    options = nbds_profile_options(x0);
    options.weak_min_failures = 3;
    options.weak_accept_resets_failures = true;
    options.weak_min_failed_block_fraction = 0.25;
    [x, ~, ~, ~] = nbds_simplified(fun, x0, options);

end

function x = nbds_tq3_test(fun, x0)

    options = nbds_profile_options(x0);
    options.weak_min_failures = 3;
    options.weak_accept_resets_failures = true;
    options.weak_min_stalled_cycles = 1;
    options.weak_min_failed_block_fraction = 0.25;
    [x, ~, ~, ~] = nbds_simplified(fun, x0, options);

end

function options = nbds_profile_options(x0)

    n = numel(x0);
    options.maxfun = 500 * n;
    options.alpha_tol = 1e-6;
    options.expand = 2;
    options.shrink = 0.5;
    options.eta = 0.95;
    options.weak_factor = 1;
    options.slack_coeff = Inf;
    options.best_slack_coeff = Inf;

end

function x = cbds_orig_termination_test(fun, x0)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    option.use_function_value_stop = true;
    option.func_window_size = 20;
    option.func_tol = 1e-6;
    option.use_estimated_gradient_stop = true;
    option.grad_window_size = 1;
    option.grad_tol = 1e-6;
    option.StepTolerance = 1e-6;
    x = bds(fun, x0, option);
    
end

function x = cbds_orig_smart_alpha_init_test(fun, x0)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;

    option.alpha_init = 'auto';

    x = bds(fun, x0, option);
    
end

function x = bds_default(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = bds_scaled(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    option.alpha_init = 'auto';
    x = bds(fun, x0, option);
    
end

function x = bds_simplex_scaled(fun, x0, relative_delta)

    option.expand = 2;
    option.shrink = 0.5;
    option.StepTolerance = 1e-6;
    option.alpha_init = fminsearch_alpha_init_for_profile(x0, option.StepTolerance, relative_delta);
    x = bds(fun, x0, option);

end

function x = bds_hybrid_scaled(fun, x0, relative_delta)

    option.expand = 2;
    option.shrink = 0.5;
    option.StepTolerance = 1e-6;
    option.alpha_init = hybrid_alpha_init_for_profile(x0, option.StepTolerance, relative_delta);
    x = bds(fun, x0, option);

end

function alpha_init = fminsearch_alpha_init_for_profile(x0, StepTolerance, relative_delta)

    zero_term_delta = 0.00025;
    abs_x0 = abs(x0(:));
    alpha_init = relative_delta * abs_x0;
    alpha_init(abs_x0 == 0) = zero_term_delta;
    alpha_init = max(alpha_init, StepTolerance * ones(size(alpha_init)));

end

function alpha_init = hybrid_alpha_init_for_profile(x0, StepTolerance, relative_delta)

    alpha_init = fminsearch_alpha_init_for_profile(x0, StepTolerance, relative_delta);
    abs_x0 = abs(x0(:));

    neutral_scale = ones(size(abs_x0));
    small_nonzero = (abs_x0 > 0) & (abs_x0 <= 1);
    neutral_scale(small_nonzero) = max(abs_x0(small_nonzero), StepTolerance);

    alpha_init = max(alpha_init, neutral_scale);
    alpha_init = max(alpha_init, StepTolerance * ones(size(alpha_init)));

end

function x = bds_finite_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;
    x = bds(@finite_barrier_fun, x0, option);

    function f = finite_barrier_fun(x)
        f = fun(x);
        if isnan(f)
            f = 1e30;
        end
    end
    
end
