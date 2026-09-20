function tsfsb_preflight_smoke(artifact_root)
% Full-budget ten-solver smoke on an old and a newly included problem.
tsfsb_setup_paths();
options = struct('artifact_root', artifact_root, ...
    'problem_names', {{'ARWHEAD', 'GAUSS1LS'}}, ...
    'feature_names', {{'plain','noisy_1e-4','linearly_transformed', ...
    'linearly_transformed_noisy_1e-4'}});
features = options.feature_names;
for i = 1:numel(features)
    options.feature_names = features(i);
    if i > 1, options.problem_names = {'ARWHEAD','BROWNAL'}; end
    results = run_tsfsb_benchmark(options);
    feature_root = fullfile(artifact_root,'evaluations',results{1}.feature.name);
    for subset = {'acceleration','blocking','direction_based','model_fd','full_pool'}
        profile_tsfsb_saved_results(feature_root, subset{1}, fullfile(artifact_root,'profiles'));
    end
end
verify_tsfsb_subset_targets(fullfile(artifact_root,'sensitivity_fixture'));
fprintf('TSFSB_PREFLIGHT_SMOKE_OK\n');
end
