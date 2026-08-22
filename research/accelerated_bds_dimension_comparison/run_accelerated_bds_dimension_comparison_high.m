function run_accelerated_bds_dimension_comparison_high()
%RUN_ACCELERATED_BDS_DIMENSION_COMPARISON_HIGH Run and redraw the 51-200 tests.

    path_experiment = fileparts(mfilename('fullpath'));
    path_research = fileparts(path_experiment);
    path_repo = fileparts(path_research);
    path_tests = fullfile(path_repo, 'tests');
    path_testdata = fullfile(path_experiment, 'testdata');
    path_summaries = fullfile(path_experiment, 'summaries');

    addpath(fullfile(path_repo, 'src'));
    addpath(path_tests);
    addpath(fullfile(path_tests, 'competitors'));
    addpath(fullfile(path_tests, 'tools'));
    ensure_directory(path_testdata);
    ensure_directory(path_summaries);

    timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    raw_savepath = fullfile(path_testdata, ...
        ['accelerated_bds_dimension_comparison_high_raw_51_200_s2mpj_', timestamp]);
    redraw_savepath = fullfile(path_testdata, ...
        ['accelerated_bds_dimension_comparison_high_pairwise_51_200_s2mpj_', timestamp]);
    ensure_directory(raw_savepath);
    ensure_directory(redraw_savepath);

    features = { ...
        'plain', ...
        'noisy_1e-1', ...
        'noisy_1e-2', ...
        'noisy_1e-3', ...
        'noisy_1e-4', ...
        'linearly_transformed', ...
        'linearly_transformed_noisy_1e-1', ...
        'linearly_transformed_noisy_1e-2', ...
        'linearly_transformed_noisy_1e-3', ...
        'linearly_transformed_noisy_1e-4' ...
    };
    raw_solver_names = { ...
        'cbds-baseline-200n', ...
        'accelerated-bds-all-on-200n', ...
        'newuoa-200n' ...
    };
    pairs = [ ...
        make_pair('E2', 'original_bds_accelerated_bds', [1, 2], ...
            {'Original BDS', 'Accelerated BDS'}), ...
        make_pair('E5', 'original_bds_newuoa', [1, 3], ...
            {'Original BDS', 'NEWUOA'}), ...
        make_pair('E6', 'accelerated_bds_newuoa', [2, 3], ...
            {'Accelerated BDS', 'NEWUOA'}) ...
    ];

    manifest = struct();
    manifest.schema_version = 1;
    manifest.started_at = char(datetime('now'));
    manifest.finished_at = '';
    manifest.status = 'RAW-RUNNING';
    manifest.dimension_range = [51, 200];
    manifest.problem_library = 's2mpj';
    manifest.max_eval_factor = 200;
    manifest.n_jobs = 120;
    manifest.step_tolerance_bds = 1e-6;
    manifest.seed = 0;
    manifest.features = features;
    manifest.raw_solver_names = raw_solver_names;
    manifest.raw_savepath = raw_savepath;
    manifest.redraw_savepath = redraw_savepath;
    manifest.summary_dir = path_summaries;
    manifest.raw_records = repmat(empty_raw_record(), 1, numel(features));
    manifest.pairs = pairs;
    manifest_file = fullfile(raw_savepath, 'manifest.mat');
    save_manifest(manifest_file, manifest);

    fprintf('Accelerated BDS dimension comparison: High-dimensional raw experiment\n');
    fprintf('Started: %s\n', manifest.started_at);
    fprintf('Raw savepath: %s\n', raw_savepath);
    fprintf('Pairwise redraw savepath: %s\n', redraw_savepath);
    fprintf('Solvers: %s\n', strjoin(raw_solver_names, ', '));

    for i_feature = 1:numel(features)
        feature_name = features{i_feature};
        existing_data_files = list_files(raw_savepath, 'data_for_loading.mat');
        options = struct();
        options.mindim = 51;
        options.maxdim = 200;
        options.plibs = 's2mpj';
        options.feature_name = feature_name;
        options.feature_display_name = feature_name;
        options.n_runs = n_runs_for_feature(feature_name);
        options.seed = 0;
        options.max_eval_factor = 200;
        options.n_jobs = 120;
        options.solver_names = raw_solver_names;
        options.savepath = raw_savepath;

        fprintf('\n[%s] Raw feature %d/%d: %s (n_runs=%d)\n', ...
            char(datetime('now')), i_feature, numel(features), ...
            feature_name, options.n_runs);
        profile_optiprofiler(options);

        record = capture_new_raw_record(raw_savepath, existing_data_files, feature_name);
        manifest.raw_records(i_feature) = record;
        save_manifest(manifest_file, manifest);
        fprintf('[%s] Raw feature completed: %s\n', char(datetime('now')), feature_name);
        fprintf('Data: %s\n', record.data_file);
        fprintf('Timestamp: %s\n', record.timestamp);
    end

    manifest.status = 'REDRAW-RUNNING';
    save_manifest(manifest_file, manifest);

    for i_pair = 1:numel(pairs)
        pair = pairs(i_pair);
        pair_savepath = fullfile(redraw_savepath, pair.slug);
        ensure_directory(pair_savepath);
        pair_summary_paths = cell(1, numel(features));
        pair_scores = nan(numel(features), 2);

        fprintf('\nPairwise redraw %s: %s\n', pair.id, strjoin(pair.display_names, ' vs '));
        for i_feature = 1:numel(features)
            record = manifest.raw_records(i_feature);
            fprintf('[%s] Redraw %s feature %d/%d: %s\n', ...
                char(datetime('now')), pair.id, i_feature, numel(features), ...
                record.feature_name);
            [summary_path, solver_scores] = redraw_pairwise_feature( ...
                record, pair, pair_savepath);
            pair_summary_paths{i_feature} = summary_path;
            pair_scores(i_feature, :) = solver_scores(:)';
            fprintf('Pairwise summary: %s\n', summary_path);
        end

        merged_summary = fullfile(path_summaries, sprintf( ...
            'summary_%s_200n_u_51_200_10features_s2mpj_%s.pdf', pair.slug, timestamp));
        merge_summary_pdfs(pair_summary_paths, merged_summary);
        manifest.pairs(i_pair).feature_summary_paths = pair_summary_paths;
        manifest.pairs(i_pair).solver_scores = pair_scores;
        manifest.pairs(i_pair).merged_summary = merged_summary;
        save_manifest(manifest_file, manifest);
        fprintf('Merged %s summary: %s\n', pair.id, merged_summary);
    end

    manifest.status = 'COMPLETE';
    manifest.finished_at = char(datetime('now'));
    save_manifest(manifest_file, manifest);
    fprintf('\nCompleted: %s\n', manifest.finished_at);
    fprintf('Manifest: %s\n', manifest_file);

end

function pair = make_pair(id, slug, solver_indices, display_names)

    pair = struct();
    pair.id = id;
    pair.slug = slug;
    pair.solver_indices = solver_indices;
    pair.display_names = display_names;
    pair.feature_summary_paths = {};
    pair.solver_scores = [];
    pair.merged_summary = '';

end

function record = empty_raw_record()

    record = struct();
    record.feature_name = '';
    record.internal_feature_name = '';
    record.benchmark_dir = '';
    record.stamp_dir = '';
    record.data_file = '';
    record.summary_file = '';
    record.timestamp = '';

end

function n_runs = n_runs_for_feature(feature_name)

    if strcmp(feature_name, 'plain')
        n_runs = 1;
    else
        n_runs = 5;
    end

end

function record = capture_new_raw_record(raw_savepath, existing_data_files, feature_name)

    current_data_files = list_files(raw_savepath, 'data_for_loading.mat');
    new_data_files = setdiff(current_data_files, existing_data_files, 'stable');
    if numel(new_data_files) ~= 1
        error('Expected one new data_for_loading.mat for %s, found %d.', ...
            feature_name, numel(new_data_files));
    end

    data_file = new_data_files{1};
    test_log_dir = fileparts(data_file);
    stamp_dir = fileparts(test_log_dir);
    benchmark_dir = fileparts(stamp_dir);
    timestamp_files = dir(fullfile(test_log_dir, 'time_stamp_*.txt'));
    if numel(timestamp_files) ~= 1
        error('Expected one timestamp file in %s, found %d.', ...
            test_log_dir, numel(timestamp_files));
    end
    timestamp_token = regexp(timestamp_files(1).name, ...
        '^time_stamp_(\d{8}_\d{6})\.txt$', 'tokens', 'once');
    if isempty(timestamp_token)
        error('Cannot parse timestamp from %s.', timestamp_files(1).name);
    end
    summary_files = dir(fullfile(stamp_dir, 'summary_*.pdf'));
    if numel(summary_files) ~= 1
        error('Expected one stamped summary PDF in %s, found %d.', ...
            stamp_dir, numel(summary_files));
    end

    record = empty_raw_record();
    record.feature_name = feature_name;
    record.internal_feature_name = internal_feature_name(feature_name);
    record.benchmark_dir = benchmark_dir;
    record.stamp_dir = stamp_dir;
    record.data_file = data_file;
    record.summary_file = fullfile(summary_files(1).folder, summary_files(1).name);
    record.timestamp = timestamp_token{1};

end

function feature_name = internal_feature_name(display_name)

    if startsWith(display_name, 'linearly_transformed_noisy_')
        feature_name = 'custom';
    elseif startsWith(display_name, 'noisy_')
        feature_name = 'noisy';
    else
        feature_name = display_name;
    end

end

function [summary_path, solver_scores] = redraw_pairwise_feature(record, pair, pair_savepath)

    previous_directory = pwd;
    restore_directory = onCleanup(@() cd(previous_directory));
    cd(record.benchmark_dir);

    existing_summaries = list_files(pair_savepath, 'summary_*.pdf');
    options = struct();
    options.load = record.timestamp;
    options.savepath = pair_savepath;
    options.solvers_to_load = pair.solver_indices;
    options.solver_names = pair.display_names;
    options.feature_name = record.internal_feature_name;
    options.plibs = {'s2mpj'};
    options.ptype = 'u';
    options.mindim = 51;
    options.maxdim = 200;
    options.seed = 0;
    options.max_eval_factor = 200;
    options.n_jobs = 1;
    options.solver_verbose = 0;
    [solver_scores, ~] = benchmark(options);

    current_summaries = list_files(pair_savepath, 'summary_*.pdf');
    new_summaries = setdiff(current_summaries, existing_summaries, 'stable');
    if numel(new_summaries) ~= 1
        error('Expected one new pairwise summary for %s/%s, found %d.', ...
            pair.id, record.feature_name, numel(new_summaries));
    end
    summary_path = new_summaries{1};
    fix_summary_feature_titles(summary_path, record.feature_name);

end

function paths = list_files(root_path, filename_pattern)

    listing = dir(fullfile(root_path, '**', filename_pattern));
    listing = listing(~[listing.isdir]);
    paths = arrayfun(@(entry) fullfile(entry.folder, entry.name), ...
        listing, 'UniformOutput', false);
    paths = paths(:)';

end

function save_manifest(manifest_file, manifest)

    save(manifest_file, 'manifest');

end

function ensure_directory(path_directory)

    if ~exist(path_directory, 'dir')
        mkdir(path_directory);
    end

end

function merge_summary_pdfs(summary_paths, output_file)

    if isempty(summary_paths) || any(cellfun(@(path) ~exist(path, 'file'), summary_paths))
        error('Cannot merge summaries because one or more input PDFs are missing.');
    end
    if exist(output_file, 'file')
        delete(output_file);
    end
    command = ['pdfunite ', strjoin(cellfun(@shell_quote, summary_paths, ...
        'UniformOutput', false), ' '), ' ', shell_quote(output_file)];
    [status, output] = system(command);
    if status ~= 0
        error('pdfunite failed while creating %s: %s', output_file, output);
    end

end

function quoted = shell_quote(text)

    quoted = ['''', strrep(char(text), '''', '''"''"'''), ''''];

end
