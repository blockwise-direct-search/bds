function fval = eval_profile_obj(x, plibs, mindim, maxdim, is_noisy)

    % Define parameters for both tuning and default solvers
    tune_params.expand = [x(1), 2.0];
    tune_params.shrink = [x(2), 0.5];
    
    % Configure options for the profiler
    options = struct();
    options.solver_names = {'cbds-tuning', 'cbds-default'};
    options.plibs = plibs;
    options.mindim = mindim;
    options.maxdim = maxdim;
    options.score_only = true;

    if ~is_noisy
        options.n_runs = 1;
    else
        % Use more runs for noisy features to get a more reliable estimate.
        options.n_runs = 3; 
    end

    if ~is_noisy
        % Evaluate the no noise features
        options.feature_name = 'plain';
        scores_plain = tuning_optiprofiler(tune_params, options);
        ratio_plain = scores_plain(1) / scores_plain(2);

        % Evaluate the linearly transformed feature
        options.feature_name = 'linearly_transformed';
        scores_trans = tuning_optiprofiler(tune_params, options);
        ratio_trans = scores_trans(1) / scores_trans(2);

        % Return the objective value for minimization. 
        fval = -min(ratio_plain, ratio_trans);
    else
        % Evaluate the noisy features
        options.feature_name = 'noisy_1e-3';
        [~, profile_scores_noisy_1e_3] = tuning_optiprofiler(tune_params, options);
        noise_level_count = get_noise_level_count(options.feature_name);
        selected_ratios_noisy_1e_3 = profile_scores_noisy_1e_3(1, 1:noise_level_count, 1, 1) ./ ...
                        profile_scores_noisy_1e_3(2, 1:noise_level_count, 1, 1);
        weighted_ratio_noisy_1e_3 = mean(selected_ratios_noisy_1e_3);

        options.feature_name = 'noisy_1e-7';
        [~, profile_scores_noisy_1e_7] = tuning_optiprofiler(tune_params, options);
        noise_level_count = get_noise_level_count(options.feature_name);
        selected_ratios_noisy_1e_7 = profile_scores_noisy_1e_7(1, 1:noise_level_count, 1, 1) ./ ...
                        profile_scores_noisy_1e_7(2, 1:noise_level_count, 1, 1);
        weighted_ratio_noisy_1e_7 = mean(selected_ratios_noisy_1e_7);

        options.feature_name = 'rotation_noisy_1e-3';
        [~, profile_scores_rotation_noisy_1e_3] = tuning_optiprofiler(tune_params, options);
        noise_level_count = get_noise_level_count(options.feature_name);
        selected_ratios_rotation_noisy_1e_3 = profile_scores_rotation_noisy_1e_3(1, 1:noise_level_count, 1, 1) ./ ...
                        profile_scores_rotation_noisy_1e_3(2, 1:noise_level_count, 1, 1);
        weighted_ratio_rotation_noisy_1e_3 = mean(selected_ratios_rotation_noisy_1e_3);

        options.feature_name = 'rotation_noisy_1e-7';
        [~, profile_scores_rotation_noisy_1e_7] = tuning_optiprofiler(tune_params, options);
        noise_level_count = get_noise_level_count(options.feature_name);
        selected_ratios_rotation_noisy_1e_7 = profile_scores_rotation_noisy_1e_7(1, 1:noise_level_count, 1, 1) ./ ...
                        profile_scores_rotation_noisy_1e_7(2, 1:noise_level_count, 1, 1);
        weighted_ratio_rotation_noisy_1e_7 = mean(selected_ratios_rotation_noisy_1e_7);

        % Return the objective value for minimization.
        fval = -min([weighted_ratio_noisy_1e_3, weighted_ratio_noisy_1e_7, weighted_ratio_rotation_noisy_1e_3, weighted_ratio_rotation_noisy_1e_7]);
    end

end

function noise_level_count = get_noise_level_count(feature_name)

    % extractAfter is introduced in MATLAB R2016b.
    % Since BDS supports MATLAB R2017b or later, we can safely use this function here.
    noise_level_str = extractAfter(string(feature_name), "1e-");
    if strlength(noise_level_str) == 0
        error('Cannot parse noise level count from feature_name: %s', feature_name);
    end
    noise_level_count = str2double(noise_level_str);
    if isnan(noise_level_count)
        error('Cannot parse noise level count from feature_name: %s', feature_name);
    end

end