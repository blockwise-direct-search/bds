function [solver_scores, profile_scores] = profile_optiprofiler(options)
    clc
    
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
    if ~isfield(options, 'savepath')
        options.savepath = fullfile(fileparts(mfilename('fullpath')), 'testdata');
    end
    if contains(options.feature_name, 'noisy')
        if sum(options.feature_name == '_') > 0
            % Find the position of the last underscore
            underscore_pos = find(options.feature_name == '_', 1, 'last');
            % Extract the part after the last underscore as noise level. If the part
            % contains 'e', it means the noise level is written in scientific notation.
            % If the part does not contain 'e', it means the noise level is written in
            % decimal notation.
            if contains(options.feature_name(underscore_pos + 1:end), 'e')
                options.noise_level = 10.^(str2double(options.feature_name(end-1:end)));
            else
                options.noise_level = str2double(options.feature_name(underscore_pos + 1:end));
            end
        else
            options.noise_level = 1e-3;
        end
        if startsWith(options.feature_name, 'permuted_noisy')
            options.feature_name = 'custom';
            options.permuted = true;
        elseif startsWith(options.feature_name, 'rotation_noisy')
            options.feature_name = 'custom';
        else
            options.feature_name = 'noisy';
        end
    end
    if startsWith(options.feature_name, 'truncated')
        if sum(options.feature_name == '_') > 0
            options.significant_digits = str2double(options.feature_name(end));
        else
            options.significant_digits = 6;
        end
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
         'cbds-randomized-gaussian', 'cbds-permuted', 'cbds-rotated-initial-point'};
        if any(ismember(bds_Algorithms, options.solver_names))
            options.solver_names(strcmpi(options.solver_names, 'ds')) = {'ds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'ds-randomized-orthogonal')) = {'ds-randomized-orthogonal-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'pbds')) = {'pbds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'rbds')) = {'rbds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'pads')) = {'pads-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'scbds')) = {'scbds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds')) = {'cbds-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-randomized-orthogonal')) = {'cbds-randomized-orthogonal-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-randomized-gaussian')) = {'cbds-randomized-gaussian-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-permuted')) = {'cbds-permuted-noisy'};
            options.solver_names(strcmpi(options.solver_names, 'cbds-rotated-initial-point')) = {'cbds-rotated-initial-point-noisy'};
        end
    end

    if ~isfield(options, 'n_runs')
        if strcmpi(options.feature_name, 'plain') || strcmpi(options.feature_name, 'quantized')
            options.n_runs = 1;
        else
            options.n_runs = 2;
        end
    end
    options.n_runs = 1;
    if ~isfield(options, 'solver_verbose')
        options.solver_verbose = 2;
    end
    time_str = char(datetime('now', 'Format', 'yy_MM_dd_HH_mm'));
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
        else
            error('Unknown dim option');
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
    for i = 1:length(options.solver_names)
        switch options.solver_names{i}
            case 'adaptive-fd-bfgs'
                solvers{i} = @(fun, x0) fminunc_adaptive(fun, x0, options.noise_level);
            case 'fd-bfgs'
                solvers{i} = @fminunc_test;
            case 'default-fd-bfgs'
                solvers{i} = @(fun, x0) fminunc_adaptive_tmp(fun, x0, options.noise_level);
            case 'praxis'
                solvers{i} = @praxis_test;
            case 'nelder-mead'
                solvers{i} = @fminsearch_test;
            case 'direct-search'
                solvers{i} = @ds_test;
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
            case 'cbds-rotated-initial-point'
                solvers{i} = @cbds_rotated_initial_point_test;
            case 'cbds-rotated-initial-point-noisy'
                solvers{i} = @(fun, x0) cbds_rotated_initial_point_test_noisy(fun, x0, true);
            case 'pds'
                solvers{i} = @pds_test;
            case 'bfo'
                solvers{i} = @bfo_test;
            case 'newuoa'
                solvers{i} = @newuoa_test;
            case 'lam'
                solvers{i} = @lam_test;
            case 'fmds'
                solvers{i} = @fmds_test;
            case 'nomad'
                solvers{i} = @nomad_test;
            case 'nomad-6'
                solvers{i} = @nomad_6_test;
            case 'bds-gws-1-gtol-3x-6x'
                solvers{i} = @bds_grad_window_size_01_grad_tol_3x_6x_test;
            case 'bds-development-gws-1-gtol-3x-6x'
                solvers{i} = @bds_development_grad_window_size_01_grad_tol_3x_6x_test;
            case 'bb1'
                solvers{i} = @bb1_test;
            case 'bb2'
                solvers{i} = @bb2_test;
            case 'sc'
                solvers{i} = @sc_test;
            case 'dogleg'
                solvers{i} = @dogleg_test;
            case 'bdss'
                solvers{i} = @bdss_test;
            case 'newuoas'
                solvers{i} = @newuoas_test;
            case 'bdss-bds'
                solvers{i} = @bdss_bds_test;
            case 'bdss-newuoa'
                solvers{i} = @bdss_newuoa_test;
            case 'bdss-bds-1'
                solvers{i} = @bdss_bds_1_test;
            case 'bdss-bds-2'
                solvers{i} = @bdss_bds_2_test;
            case 'bdss-bds-3'
                solvers{i} = @bdss_bds_3_test;
            case 'dss-bds'
                solvers{i} = @dss_bds_test;
            case 'cbds-simplified'
                solvers{i} = @cbds_simplified_test;
            case 'cbds-orig-termination'
                solvers{i} = @cbds_orig_termination_test;
            case 'cbds-orig-smart-alpha-init'
                solvers{i} = @cbds_orig_smart_alpha_init_test;
            otherwise
                error('Unknown solver');
        end
    end
    options.benchmark_id = [];
    for i = 1:length(solvers)
        if i == 1
            options.benchmark_id = strrep(options.solver_names{i}, '-', '_');
        else
            options.benchmark_id = [options.benchmark_id, '_', strrep(options.solver_names{i}, '-', '_')];
        end
    end
    options.benchmark_id = [options.benchmark_id, '_', num2str(options.mindim), '_', num2str(options.maxdim), '_', num2str(options.n_runs)];
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
        case 'truncated'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(options.significant_digits)];
            options = rmfield(options, 'noise_level');
        case 'quantized'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(-log10(options.mesh_size)))];
        case 'random_nan'
            % Since the nan_rate should be in the range of [0, 1], we will discuss in two cases: one is nan_rate < 0.1, 
            % the other is nan_rate >= 0.1.
            if options.nan_rate < 0.1
                options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_0', int2str(int32(options.nan_rate * 100))];
            else
                options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(options.nan_rate * 100))];
            end
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
        'VARDIM'};
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
        'YATP1CLS',... % The dimensions of the above problems are from 6 to 50. The following problems are from 51 to 200;
        'ARGLINA',...
        'ARGTRIGLS_100',...
        'EIGENALS_110',...
        'EIGENBLS_110',...
        'MANCINO_100',...
        'MODBEALE_200',...
        'MSQRTALS_100',...
        'MSQRTBLS_100',...
        'SENSORS_100',...
        'SPARSINE_100',...
        'SSBRYBND_100',...
        'TRIGON1_100',...
        'YATP1LS_120'};
    end    

    if strcmp(options.feature_name, 'custom')

        if ~isfield(options, 'permuted')
            % We need mod_x0 to make sure that the linearly transformed problem is mathematically equivalent
            % to the original problem.
            options.mod_x0 = @mod_x0;
            options.mod_affine = @mod_affine;
            options.feature_stamp = strcat('rotation_noisy_', int2str(int32(-log10(options.noise_level))));
        else
            options.mod_x0 = @mod_x0_permuted;
            options.mod_affine = @perm_affine;
            options.feature_stamp = strcat('permuted_noisy_', int2str(int32(-log10(options.noise_level))));
            options = rmfield(options, 'permuted');
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
    [solver_scores, profile_scores] = benchmark(solvers, options);

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
    option.permuting_period = 0;
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

function x = cbds_rotated_initial_point_test(fun, x0) 

    option.Algorithm = 'cbds';

    % Ensure x0 is a column vector
    x0 = x0(:);
    n = length(x0);

    % Normalize the input vector
    x0_hat = x0 / norm(x0);

    % Construct the first standard basis vector
    e1 = zeros(n, 1);
    e1(1) = 1;

    % Check if x0 is already aligned with e1
    if norm(x0_hat - e1) < 1e-10
        R = eye(n); % If x0 is already aligned with e1, return identity matrix
    else
        % Compute the Householder vector
        u = x0_hat - e1;

        % Avoid numerical instability when u is close to zero
        if norm(u) < 1e-10
            % Use a fallback: set u to a simple direction
            u = zeros(n, 1);
            u(2) = 1; % Choose a valid direction orthogonal to e1
        else
            u = u / norm(u); % Normalize u
        end

        % Compute the Householder reflection matrix implicitly
        % H = I - 2 * (u * u'), but we avoid forming H explicitly
        % Instead, we compute R directly
        R = eye(n) - 2 * (u * u'); % Compute the full rotation matrix

        % Ensure that the first column of R is aligned with x0.
    end

    option.direction_set = R;

    x = bds_development(fun, x0, option);
    
end

function x = cbds_rotated_initial_point_test_noisy(fun, x0, is_noisy)

    option.Algorithm = 'cbds';

    % Ensure x0 is a column vector
    x0 = x0(:);
    n = length(x0);

    % Normalize the input vector
    x0_hat = x0 / norm(x0);

    % Construct the first standard basis vector
    e1 = zeros(n, 1);
    e1(1) = 1;

    % Check if x0 is already aligned with e1
    if norm(x0_hat - e1) < 1e-10
        R = eye(n); % If x0 is already aligned with e1, return identity matrix
    else
        % Compute the Householder vector
        u = x0_hat - e1;

        % Avoid numerical instability when u is close to zero
        if norm(u) < 1e-10
            % Use a fallback: set u to a simple direction
            u = zeros(n, 1);
            u(2) = 1; % Choose a valid direction orthogonal to e1
        else
            u = u / norm(u); % Normalize u
        end

        % Compute the Householder reflection matrix implicitly
        % H = I - 2 * (u * u'), but we avoid forming H explicitly
        % Instead, we compute R directly
        R = eye(n) - 2 * (u * u'); % Compute the full rotation matrix
    end

    option.direction_set = R;
    option.is_noisy = is_noisy;
    x = bds_development(fun, x0, option);

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

function x = bfo_test(fun, x0)

    % Dimension
    n = numel(x0);

    StepTolerance = 1e-6;
    maxeval = 500*n;

    [x, ~, ~, ~, ~] = bfo(fun, x0, 'epsilon', StepTolerance, 'maxeval', maxeval);
    
end

function x = newuoa_test(fun, x0)

    options.maxfun = 500*length(x0);
    x = newuoa(fun, x0, options);
    
end

function x = lam_test(fun, x0)

    x = lam(fun, x0);
    
end

function x = fmds_test(fun, x0)

    x = fmds(fun, x0);
    
end

function x = nomad_test(fun, x0)
    
    % Dimension:
    n = numel(x0);

    % Set the default bounds.
    lb = -inf(n, 1);
    ub = inf(n, 1);

    % Set MAXFUN to the maximum number of function evaluations.
    MaxFunctionEvaluations = 500*n;

    params = struct('MAX_BB_EVAL', num2str(MaxFunctionEvaluations), 'max_eval',num2str(MaxFunctionEvaluations));

    % As of NOMAD version 4.4.0 and OptiProfiler commit 24d8cc0, the following line is 
    % necessary. Otherwise, NOMAD will throw an error, complaining that the blackbox 
    % evaluation fails. This seems to be because OptiProfiler wraps the function 
    % handle in a way that NOMAD does not expect: NOMAD expects a function handle 
    % `fun` with the signature fun(x), where x is a column vector, while OptiProfiler 
    % produces one with the signature @(varargin)featured_problem.fun(varargin{:}).
    fun = @(x) fun(x(:));

    [x, ~, ~, ~, ~] = nomadOpt(fun,x0,lb,ub,params);
    
end

function x = nomad_6_test(fun, x0)
    
    % Dimension:
    n = numel(x0);

    % Set the default bounds.
    lb = -inf(n, 1);
    ub = inf(n, 1);

    % Set MAXFUN to the maximum number of function evaluations.
    MaxFunctionEvaluations = 500*n;

    params = struct('min_frame_size','* 0.000001', 'min_mesh_size', '* 0.000001', ...
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

function x = bds_grad_window_size_01_grad_tol_3x_6x_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;

    option.use_estimated_gradient_stop = true;
    option.grad_window_size = 1;
    option.grad_tol_1 = 1e-3;
    option.grad_tol_2 = 1e-6;

    x = bds(fun, x0, option);
    
end

function x = bds_development_grad_window_size_01_grad_tol_3x_6x_test(fun, x0)

    option.expand = 2;
    option.shrink = 0.5;

    option.use_estimated_gradient_stop = true;
    option.grad_window_size = 1;
    option.grad_tol_1 = 1e-3;
    option.grad_tol_2 = 1e-6;

    x = bds_development(fun, x0, option);
    
end

function x = bb1_test(fun, x0)

    option.bb1 = true;
    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = bb2_test(fun, x0)

    option.bb2 = true;
    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = sc_test(fun, x0)

    option.spectral_cauchy = true;
    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = dogleg_test(fun, x0)

    option.dogleg = true;
    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bds(fun, x0, option);
    
end

function x = bdss_test(fun, x0)

    option = struct();
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = newuoas_test(fun, x0)

    option.maxfun = 500*length(x0);
    option.maxiter = 500*length(x0);
    option.debug = false;
    [x, ~, ~, ~] = newuoas(fun, x0, option);

end

function x = bdss_bds_test(fun, x0)

    option.subsolver = 'bds';
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = bdss_newuoa_test(fun, x0)

    option.subsolver = 'newuoa';
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = dss_bds_test(fun, x0)

    option.subsolver = 'bds';
    option.options_bds.num_blocks = 1;
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = bdss_bds_1_test(fun, x0)

    option.subsolver = 'bds';
    option.subspace_dim = 1;
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = bdss_bds_2_test(fun, x0)

    option.subsolver = 'bds';
    option.subspace_dim = 2;
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = bdss_bds_3_test(fun, x0)

    option.subsolver = 'bds';
    option.subspace_dim = 3;
    option.expand = 2;
    option.shrink = 0.5;
    x = bdss(fun, x0, option);

end

function x = cbds_simplified_test(fun, x0)

    x = bds_simplified(fun, x0);

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