function [solver_scores, profile_scores] = tuning_optiprofiler(parameters, options)

    clc
    options.n_jobs = 1; % Set the number of jobs to 1 for the seed to be consistent.
    n_solvers = length(options.solver_names);
    solvers = cell(1, n_solvers);
    
    % According to the field of parameters, different solvers are tested.
    param_fields = fieldnames(parameters);
    
    switch true
        case ismember('expand', param_fields) && ismember('shrink', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_expand_shrink(fun, x0, parameters.expand(i_solver), parameters.shrink(i_solver));
            end
        case ismember('func_window_size', param_fields) && ismember('func_tol', param_fields) ...
            && ~ismember('grad_window_size', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_window_size_fun_tol(fun, x0, parameters.func_window_size(i_solver), parameters.func_tol(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ~ismember('batch_size', param_fields) && ~ismember('func_window_size', param_fields) ...
            && ~ismember('maxfun_factor', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_window_size_grad_tol(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ~ismember('batch_size', param_fields) && ~ismember('func_window_size', param_fields) ...
            && ismember('maxfun_factor', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_window_size_grad_tol_maxfun_factor(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver), parameters.maxfun_factor(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ~ismember('func_window_size', param_fields) ...
            && ismember('batch_size', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_window_size_grad_tol_batch_size(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver), parameters.batch_size(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ismember('func_window_size', param_fields) && ismember('func_tol', param_fields) ...
            && ~ismember('rotation', param_fields) ...
            && ~ismember('maxfun_factor', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_window_size_grad_tol_func_tol(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver), parameters.func_window_size(i_solver), parameters.func_tol(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ismember('func_window_size', param_fields) && ismember('func_tol', param_fields) ...
            && ~ismember('rotation', param_fields) ...
            && ismember('maxfun_factor', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_window_size_grad_tol_func_tol_maxfun_factor(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver), parameters.func_window_size(i_solver), parameters.func_tol(i_solver), parameters.maxfun_factor(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ismember('func_window_size', param_fields) && ismember('func_tol', param_fields) ...
            && ismember('rotation', param_fields) ...
            && ~ismember('maxfun_factor', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_rotation_window_size_grad_tol_func_tol(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver), parameters.func_window_size(i_solver), parameters.func_tol(i_solver), parameters.rotation(i_solver));
            end
        case ismember('grad_window_size', param_fields) && ismember('grad_tol', param_fields) ...
            && ismember('func_window_size', param_fields) && ismember('func_tol', param_fields) ...
            && ismember('rotation', param_fields) ...
            && ismember('maxfun_factor', param_fields)
            for i_solver = 1:n_solvers
                solvers{i_solver} = @(fun, x0) cbds_rotation_window_size_grad_tol_func_tol_maxfun_factor(fun, x0, parameters.grad_window_size(i_solver), parameters.grad_tol(i_solver), parameters.func_window_size(i_solver), parameters.func_tol(i_solver), parameters.rotation(i_solver), parameters.maxfun_factor(i_solver));
            end
    end
    if ~isfield(options, 'feature_name')
        error('Please provide the feature name');
    end
    if startsWith(options.feature_name, 'noisy')
        if sum(options.feature_name == '_') > 0
            options.noise_level = 10.^(str2double(options.feature_name(end-1:end)));
        else
            options.noise_level = 1e-3;
        end
        options.feature_name = 'noisy';
    end 
    if startsWith(options.feature_name, 'rotation_noisy')
        options.noise_level = 10.^(str2double(options.feature_name(end-1:end)));
        options.feature_name = 'custom';
    end
    if startsWith(options.feature_name, 'permuted_noisy')
        if sum(options.feature_name == '_') > 0
            options.noise_level = 10.^(str2double(options.feature_name(end-1:end)));
        else
            options.noise_level = 1e-3;
        end
        options.feature_name = 'custom';
        options.permuted = true;
    end
    if startsWith(options.feature_name, 'truncated')
        if sum(options.feature_name == '_') > 0
            options.significant_digits = str2double(options.feature_name(end));
        else
            options.significant_digits = 6;
        end
        switch options.significant_digits
            % Why we set the noise level like this? See the link below:
            % https://github.com/Lht97/to_do_list. 
            case 1
                options.noise_level = 10^(-1) / (2 * sqrt(3));
            case 2
                options.noise_level = 10^(-2) / (2 * sqrt(3));
            case 3
                options.noise_level = 10^(-3) / (2 * sqrt(3));
            case 4
                options.noise_level = 10^(-4) / (2 * sqrt(3));                
            case 5
                options.noise_level = 10^(-5) / (2 * sqrt(3));
            case 6
                options.noise_level = 10^(-6) / (2 * sqrt(3));
            case 7
                options.noise_level = 10^(-7) / (2 * sqrt(3));
            case 8
                options.noise_level = 10^(-8) / (2 * sqrt(3));
        end
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

    options.n_runs = 1;
    if ~isfield(options, 'solver_verbose')
        options.solver_verbose = 2;
    end
    time_str = char(datetime('now', 'Format', 'yy_MM_dd_HH_mm'));
    options.silent = false;
    options.ptype = 'u';
    if isfield(options, 'problem_names')
        if isfield(options, 'dim')
            options = rmfield(options, 'dim');
        end
        options.mindim = 1;
        options.maxdim = 200;
    end
    if isfield(options, 'dim')
        if strcmpi(options.dim, 'small')
            options.mindim = 2;
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
        options.mindim = 2;
    end
    if ~isfield(options, 'maxdim')
        options.maxdim = 5;
    end
    if ~isfield(options, 'run_plain')
        options.run_plain = false;
    end

    options.benchmark_id = [];
    for i = 1:length(solvers)
        if i == 1
            options.benchmark_id = strrep(options.solver_names{i}, '-', '_');
        else
            options.benchmark_id = [options.benchmark_id, '_', strrep(options.solver_names{i}, '-', '_')];
        end
    end
    if isfield(options, 'problem_names')
        options.benchmark_id = [options.benchmark_id, '_', options.problem_names{1}, '_', num2str(options.n_runs)];
    else
        options.benchmark_id = [options.benchmark_id, '_', num2str(options.mindim), '_', num2str(options.maxdim), '_', num2str(options.n_runs)];
    end
    switch options.feature_name
        case 'noisy'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(-log10(options.noise_level))), '_no_rotation'];
        case 'custom'
            if isfield(options, 'permuted') && options.permuted
                options.benchmark_id = [options.benchmark_id, '_', 'permuted_noisy', '_', int2str(int32(-log10(options.noise_level)))];
            else
                options.benchmark_id = [options.benchmark_id, '_', 'rotation_noisy', '_', int2str(int32(-log10(options.noise_level)))];
            end
        case 'truncated'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(options.significant_digits)];
            options = rmfield(options, 'noise_level');
        case 'quantized'
            options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(-log10(options.mesh_size)))];
        case 'random_nan'
            if 100*options.nan_rate < 10
                options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_0', int2str(int32(options.nan_rate * 100))];
            else
                options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_', int2str(int32(options.nan_rate * 100))];
            end
        case 'perturbed_x0'
            switch options.perturbation_level
                case 1e-3
                    options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_0_001'];
                case 1
                    options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_01'];
                case 10
                    options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_10'];
                case 100
                    options.benchmark_id = [options.benchmark_id, '_', options.feature_name, '_100'];
            end
    otherwise
        options.benchmark_id = [options.benchmark_id, '_', options.feature_name];
    end
    if options.run_plain
        options.benchmark_id = [options.benchmark_id, '_plain'];
    end
    
    % When tuning with parallel computing, the benchmark_id should be unique. In our test, we use the
    % value of the parameters to make the benchmark_id unique.
    param_fields = fieldnames(parameters);
    if ismember('expand', param_fields)
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'expand', parameters.expand(1));
    end
    if ismember('shrink', param_fields)
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'shrink', parameters.shrink(1));
    end
    if ismember('func_tol', param_fields)
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'func_tol', parameters.func_tol(1));
    end
    if ismember('func_window_size', param_fields)
        if parameters.func_window_size(1) < 10
            formatted_value = sprintf('%02d', parameters.func_window_size(1)); % Format as two digits
        else
            formatted_value = sprintf('%.0f', parameters.func_window_size(1)); % Keep as integer
        end
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'func_window_size', formatted_value);
    end
    if ismember('grad_window_size', param_fields)
        if parameters.grad_window_size(1) < 10
            formatted_value = sprintf('%02d', parameters.grad_window_size(1)); % Format as two digits
        else
            formatted_value = sprintf('%.0f', parameters.grad_window_size(1)); % Keep as integer
        end
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'grad_window_size', formatted_value);
    end
    if ismember('grad_tol', param_fields)
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'grad_tol', parameters.grad_tol(1));
    end
    if ismember('maxfun_factor', param_fields)
        options.benchmark_id = append_param_to_id(options.benchmark_id, 'maxfun_factor', parameters.maxfun_factor(1));
        options.max_eval_factor = max(parameters.maxfun_factor);
    end

    if isfield(options, 'plibs')
        options.benchmark_id = [options.benchmark_id, '_', get_plibs_benchmark_id(options.plibs)];
    end

    options.benchmark_id = [options.benchmark_id, '_', time_str];
    
    if ~isfield(options, 'savepath')
        options.savepath = fullfile(fileparts(mfilename('fullpath')), 'tuning_data');
    end

    if ~isfield(options, 'problem_names')
        matcutest_excludelist = {'ARGTRIGLS',...
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
        s2mpj_excludelist = {'DIAMON2DLS',...
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

        if isfield(options, 'plibs')
            plibs = normalize_plibs(options.plibs);
            if isequal(plibs, {'matcutest'})
                options.excludelist = matcutest_excludelist;
            elseif isequal(plibs, {'s2mpj'})
                options.excludelist = s2mpj_excludelist;
            elseif isequal(plibs, {'matcutest', 's2mpj'})
                options.excludelist = union(matcutest_excludelist, s2mpj_excludelist, 'stable');
            else
                options.excludelist = s2mpj_excludelist;
            end
        else
            options.excludelist = s2mpj_excludelist;
        end
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
            otherwise
                error('Unknown noise level');
        end
            options = rmfield(options, 'noise_level');
    end
    
    if ~isfield(options, 'seed')
        options.seed = 0;
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

function x = cbds_expand_shrink(fun, x0, expand, shrink)

    option.Algorithm = 'cbds';
    option.expand = expand;
    option.shrink = shrink;
    x = bds(fun, x0, option);
    
end

function x = cbds_window_size_fun_tol(fun, x0, func_window_size, func_tol)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if func_window_size > 1e5 || func_tol == 1e-30
        option.use_function_value_stop = false;
    else
        option.func_window_size = func_window_size;
        option.func_tol = func_tol;
        option.use_function_value_stop = true;
    end
    x = bds(fun, x0, option);
    
end

function x = cbds_window_size_grad_tol(fun, x0, grad_window_size, grad_tol)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    
    x = bds(fun, x0, option);
     
end

function x = cbds_window_size_grad_tol_maxfun_factor(fun, x0, grad_window_size, grad_tol, maxfun_factor)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    option.StepTolerance = eps;
    option.MaxFunctionEvaluations = maxfun_factor * numel(x0);
    
    x = bds(fun, x0, option);
    
end

function x = cbds_window_size_grad_tol_batch_size(fun, x0, grad_window_size, grad_tol, batch_size)

    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    switch batch_size
        case "one"
            option.batch_size = 1;
        case "quarter-n"
            option.batch_size = ceil(numel(x0)/4);
        case "half-n"
            option.batch_size = ceil(numel(x0)/2);
        otherwise
            error('Unknown batch size');
    end
    % Use the seed to make sure that the only difference between the comparison is the parameters related to the
    % gradient computation.
    seed = round(1e4 * option.expand) + round(1e6 * option.shrink) + option.batch_size;
    option.seed = seed;
    option.output_block_hist = true;
    option.replacement_delay = 0;

    x = bds(fun, x0, option);
    
end

function x = cbds_window_size_grad_tol_func_tol(fun, x0, grad_window_size, grad_tol, func_window_size, func_tol)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    if func_window_size > 1e5 || func_tol == 1e-30
        option.use_function_value_stop = false;
    else
        option.func_window_size = func_window_size;
        option.func_tol = func_tol;
        option.use_function_value_stop = true;
    end

    % % When the feature is linearly transformed, the default stopping criteria may even trigger too early.
    % % So we set a smaller step tolerance and a larger maximum number of function evaluations to see the effect
    % % of the parameters.
    % rotation_feature_list = {'linearly_transformed', 'rotation_noisy_1e-1', 'rotation_noisy_1e-2', 'rotation_noisy_1e-3', 'rotation_noisy_1e-4'};
    % if ismember(feature_name, rotation_feature_list)
    %     option.StepTolerance = 1e-9;
    %     option.MaxFunctionEvaluations = 1e3 * numel(x0);
    % end
    x = bds(fun, x0, option);
    
end

function x = cbds_window_size_grad_tol_func_tol_maxfun_factor(fun, x0, grad_window_size, grad_tol, func_window_size, func_tol, maxfun_factor)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    if func_window_size > 1e5 || func_tol == 1e-30
        option.use_function_value_stop = false;
    else
        option.func_window_size = func_window_size;
        option.func_tol = func_tol;
        option.use_function_value_stop = true;
    end

    option.StepTolerance = eps;
    option.MaxFunctionEvaluations = maxfun_factor * numel(x0);
    x = bds(fun, x0, option);
    
end

function x = cbds_rotation_window_size_grad_tol_func_tol(fun, x0, grad_window_size, grad_tol, func_window_size, func_tol, rotation)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    if func_window_size > 1e5 || func_tol == 1e-30
        option.use_function_value_stop = false;
    else
        option.func_window_size = func_window_size;
        option.func_tol = func_tol;
        option.use_function_value_stop = true;
    end
    n = length(x0);
    seed = round(1e4 * option.expand) + round(1e6 * option.shrink) + n;
    if rotation
        oldState = rng();
        rng(seed);
        [Q,R] = qr(randn(n));
        Q = Q*diag(sign(diag(R)));
        option.direction_set = Q;
        rng(oldState);
    end

    % % When the feature is linearly transformed, the default stopping criteria may even trigger too early.
    % % So we set a smaller step tolerance and a larger maximum number of function evaluations to see the effect
    % % of the parameters.
    % rotation_feature_list = {'linearly_transformed', 'rotation_noisy_1e-1', 'rotation_noisy_1e-2', 'rotation_noisy_1e-3', 'rotation_noisy_1e-4'};
    % if ismember(feature_name, rotation_feature_list)
    %     option.StepTolerance = 1e-9;
    %     option.MaxFunctionEvaluations = 1e3 * numel(x0);
    % end
    x = bds(fun, x0, option);
    
end

function x = cbds_rotation_window_size_grad_tol_func_tol_maxfun_factor(fun, x0, grad_window_size, grad_tol, func_window_size, func_tol, rotation)

    option.Algorithm = 'cbds';
    option.expand = 2;
    option.shrink = 0.5;
    if grad_window_size > 1e5 || grad_tol == 1e-30
        option.use_estimated_gradient_stop = false;
    else
        option.grad_window_size = grad_window_size;
        option.grad_tol = grad_tol;
        option.use_estimated_gradient_stop = true;
    end
    if func_window_size > 1e5 || func_tol == 1e-30
        option.use_function_value_stop = false;
    else
        option.func_window_size = func_window_size;
        option.func_tol = func_tol;
        option.use_function_value_stop = true;
    end
    n = length(x0);
    seed = round(1e4 * option.expand) + round(1e6 * option.shrink) + n;
    if rotation
        oldState = rng();
        rng(seed);
        [Q,R] = qr(randn(n));
        Q = Q*diag(sign(diag(R)));
        option.direction_set = Q;
        rng(oldState);
    end

    option.StepTolerance = eps;
    option.MaxFunctionEvaluations = maxfun_factor * numel(x0);
    
    x = bds(fun, x0, option);
    
end

function benchmark_id = append_param_to_id(benchmark_id, param_name, param_value, format)
    if nargin < 4
        format = '%.2f';
    end
    param_str = num2str(param_value, format);
    if strcmp(param_name, 'expand')
        param_str = strrep(param_str, '.', 'x');
    elseif strcmp(param_name, 'shrink')
        param_str = strrep(param_str, '.', 'x');
    elseif strcmp(param_name, 'maxfun_factor')
        param_str = sprintf('%d', round(param_value));
    elseif contains(param_name, 'tol')
        if param_value > 1e-10
            param_str = sprintf('0%d', int32(-log10(param_value)));
        else
            param_str = sprintf('%d', int32(-log10(param_value)));
        end
    end
    benchmark_id = [benchmark_id, '_', param_name, '_', param_str];
end

function plibs = normalize_plibs(plibs)
    if ischar(plibs)
        plibs = {plibs};
    elseif isstring(plibs)
        plibs = cellstr(plibs);
    end

    plibs = lower(plibs);

    ordered_plibs = {};
    if any(strcmp(plibs, 'matcutest'))
        ordered_plibs{end + 1} = 'matcutest';
    end
    if any(strcmp(plibs, 's2mpj'))
        ordered_plibs{end + 1} = 's2mpj';
    end

    if isempty(ordered_plibs)
        plibs = unique(plibs, 'stable');
    else
        plibs = ordered_plibs;
    end
end

function plibs_benchmark_id = get_plibs_benchmark_id(plibs)
    plibs = normalize_plibs(plibs);
    if isequal(plibs, {'matcutest', 's2mpj'})
        plibs_benchmark_id = 'matcutest_s2mpj';
    else
        plibs_benchmark_id = strjoin(plibs, '_');
    end
end