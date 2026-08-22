function run_accelerated_bds_dimension_comparison_e4()
%RUN_ACCELERATED_BDS_DIMENSION_COMPARISON_E4 Redraw E4 from stored histories.

    path_experiment = fileparts(mfilename('fullpath'));
    path_research = fileparts(path_experiment);
    path_repo = fileparts(path_research);
    path_tests = fullfile(path_repo, 'tests');
    path_testdata = fullfile(path_experiment, 'testdata');
    path_summaries = fullfile(path_experiment, 'summaries');
    historical_root = fullfile(path_testdata, ...
        'lean_evolved_bds_options_newuoa_200n_bfgs_200n_6_50_10features_s2mpj_20260702_175908');

    addpath(fullfile(path_tests, 'tools'));
    ensure_optiprofiler_on_path();
    assert(exist(historical_root, 'dir') == 7, ...
        'Historical E4 raw-data directory does not exist: %s', historical_root);
    ensure_directory(path_summaries);

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
    source_timestamps = { ...
        '20260702_180056', ...
        '20260702_181457', ...
        '20260702_183504', ...
        '20260702_185620', ...
        '20260702_192009', ...
        '20260702_194704', ...
        '20260702_202858', ...
        '20260702_205432', ...
        '20260702_211820', ...
        '20260702_214338' ...
    };
    expected_solver_names = { ...
        'lean_evolved_bds_options', 'newuoa-200n', 'bfgs-200n'};

    run_timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    redraw_savepath = fullfile(path_testdata, ...
        ['accelerated_bds_dimension_comparison_e4_pairwise_6_50_s2mpj_', run_timestamp]);
    ensure_directory(redraw_savepath);

    records = repmat(empty_record(), 1, numel(features));
    manifest = struct();
    manifest.schema_version = 1;
    manifest.comparison_id = 'E4';
    manifest.status = 'VALIDATING-SOURCES';
    manifest.started_at = char(datetime('now'));
    manifest.finished_at = '';
    manifest.no_solver_calls = true;
    manifest.source_root = historical_root;
    manifest.redraw_savepath = redraw_savepath;
    manifest.features = features;
    manifest.source_timestamps = source_timestamps;
    manifest.solvers_to_load = [1, 2];
    manifest.solver_names = {'Accelerated BDS', 'NEWUOA'};
    manifest.plain_duplicate_validation = struct();
    manifest.records = records;
    manifest.merged_summary = '';
    manifest_file = fullfile(redraw_savepath, 'manifest.mat');
    save_manifest(manifest_file, manifest);

    fprintf('Accelerated BDS dimension comparison E4: redraw only\n');
    fprintf('Started: %s\n', manifest.started_at);
    fprintf('Historical source: %s\n', historical_root);
    fprintf('Pairwise output: %s\n', redraw_savepath);
    fprintf('No solver handles are supplied; benchmark load mode is required.\n');

    for i_feature = 1:numel(features)
        records(i_feature) = resolve_and_validate_source( ...
            historical_root, features{i_feature}, source_timestamps{i_feature}, ...
            expected_solver_names);
        fprintf('Validated source %d/%d: %s\n', ...
            i_feature, numel(features), records(i_feature).data_file);
    end

    manifest.plain_duplicate_validation = validate_plain_duplicates( ...
        records(1).data_file, [1, 2]);
    manifest.records = records;
    manifest.status = 'REDRAW-RUNNING';
    save_manifest(manifest_file, manifest);
    fprintf('Plain five-run exact-duplicate gate: PASSED\n');

    summary_paths = cell(1, numel(features));
    solver_scores = nan(numel(features), 2);
    for i_feature = 1:numel(features)
        fprintf('[%s] E4 redraw %d/%d: %s\n', char(datetime('now')), ...
            i_feature, numel(features), features{i_feature});
        [summary_paths{i_feature}, scores] = redraw_feature( ...
            records(i_feature), redraw_savepath);
        solver_scores(i_feature, :) = scores(:)';
        records(i_feature).summary_file = summary_paths{i_feature};
        records(i_feature).solver_scores = scores(:)';
        manifest.records = records;
        save_manifest(manifest_file, manifest);
        fprintf('Pairwise summary: %s\n', summary_paths{i_feature});
    end

    merged_summary = fullfile(path_summaries, sprintf( ...
        'summary_accelerated_bds_newuoa_200n_u_6_50_10features_s2mpj_%s.pdf', ...
        run_timestamp));
    merge_summary_pdfs(summary_paths, merged_summary);

    manifest.status = 'COMPLETE';
    manifest.finished_at = char(datetime('now'));
    manifest.records = records;
    manifest.solver_scores = solver_scores;
    manifest.merged_summary = merged_summary;
    save_manifest(manifest_file, manifest);
    fprintf('Merged E4 summary: %s\n', merged_summary);
    fprintf('Completed: %s\n', manifest.finished_at);
    fprintf('Manifest: %s\n', manifest_file);

end

function record = empty_record()

    record = struct();
    record.feature_name = '';
    record.internal_feature_name = '';
    record.source_timestamp = '';
    record.benchmark_dir = '';
    record.data_file = '';
    record.summary_file = '';
    record.solver_scores = [];

end

function record = resolve_and_validate_source(root_path, feature_name, ...
        source_timestamp, expected_solver_names)

    stamp_name = ['time_stamp_', source_timestamp, '.txt'];
    stamp_files = dir(fullfile(root_path, '**', stamp_name));
    stamp_files = stamp_files(~[stamp_files.isdir]);
    assert(numel(stamp_files) == 1, ...
        'Expected exactly one %s under %s, found %d.', ...
        stamp_name, root_path, numel(stamp_files));

    log_dir = stamp_files(1).folder;
    data_file = fullfile(log_dir, 'data_for_loading.mat');
    assert(exist(data_file, 'file') == 2, ...
        'Missing data_for_loading.mat for %s.', feature_name);
    loaded = load(data_file, 'results_plibs');
    assert(isfield(loaded, 'results_plibs') && iscell(loaded.results_plibs), ...
        'Invalid results_plibs in %s.', data_file);
    matching = find(cellfun(@(entry) isstruct(entry) && isfield(entry, 'plib') ...
        && strcmp(entry.plib, 's2mpj'), loaded.results_plibs));
    assert(numel(matching) == 1, ...
        'Expected exactly one S2MPJ result in %s.', data_file);
    result = loaded.results_plibs{matching};
    assert(isequal(result.solver_names(:)', expected_solver_names), ...
        'Unexpected historical solver order in %s.', data_file);
    assert(result.mindim == 6 && result.maxdim == 50, ...
        'Unexpected dimension range in %s.', data_file);
    assert(contains(result.ptype, 'u'), ...
        'Historical data is not unconstrained in %s.', data_file);
    assert(size(result.fun_histories, 3) == 5, ...
        'Expected five historical runs for %s.', feature_name);

    record = empty_record();
    record.feature_name = feature_name;
    record.internal_feature_name = internal_feature_name(feature_name);
    record.source_timestamp = source_timestamp;
    record.benchmark_dir = fileparts(fileparts(log_dir));
    record.data_file = data_file;

end

function validation = validate_plain_duplicates(data_file, solver_indices)

    loaded = load(data_file, 'results_plibs');
    matching = find(cellfun(@(entry) isstruct(entry) && isfield(entry, 'plib') ...
        && strcmp(entry.plib, 's2mpj'), loaded.results_plibs));
    result = loaded.results_plibs{matching};
    n_runs = size(result.fun_histories, 3);
    assert(n_runs == 5, 'The historical plain feature must contain five runs.');

    history_fields = {'fun_histories', 'maxcv_histories', 'merit_histories'};
    output_fields = {'fun_outs', 'maxcv_outs', 'n_evals', 'merit_outs'};
    init_fields = {'fun_inits', 'maxcv_inits', 'merit_inits'};
    diagnostic_fields = {'solver_abnormal_terminations', 'solver_output_fallbacks'};

    for i_field = 1:numel(history_fields)
        name = history_fields{i_field};
        for i_run = 2:n_runs
            assert(isequaln(result.(name)(:, solver_indices, 1, :), ...
                result.(name)(:, solver_indices, i_run, :)), ...
                'Plain runs differ in %s (run 1 vs run %d).', name, i_run);
        end
    end
    for i_field = 1:numel(output_fields)
        name = output_fields{i_field};
        for i_run = 2:n_runs
            assert(isequaln(result.(name)(:, solver_indices, 1), ...
                result.(name)(:, solver_indices, i_run)), ...
                'Plain runs differ in %s (run 1 vs run %d).', name, i_run);
        end
    end
    for i_field = 1:numel(init_fields)
        name = init_fields{i_field};
        for i_run = 2:n_runs
            assert(isequaln(result.(name)(:, 1), result.(name)(:, i_run)), ...
                'Plain runs differ in %s (run 1 vs run %d).', name, i_run);
        end
    end
    for i_field = 1:numel(diagnostic_fields)
        name = diagnostic_fields{i_field};
        if isfield(result, name)
            for i_run = 2:n_runs
                assert(isequaln(result.(name)(:, solver_indices, 1), ...
                    result.(name)(:, solver_indices, i_run)), ...
                    'Plain runs differ in %s (run 1 vs run %d).', name, i_run);
            end
        end
    end

    validation = struct();
    validation.passed = true;
    validation.n_runs = n_runs;
    validation.solver_indices = solver_indices;
    validation.checked_fields = [history_fields, output_fields, init_fields, ...
        diagnostic_fields(cellfun(@(name) isfield(result, name), diagnostic_fields))];
    % Timing and success bookkeeping are not copied to duplicate deterministic runs.
    validation.excluded_bookkeeping_fields = {'computation_times', 'solvers_successes'};

end

function [summary_path, solver_scores] = redraw_feature(record, redraw_savepath)

    feature_savepath = fullfile(redraw_savepath, record.feature_name);
    ensure_directory(feature_savepath);
    previous_directory = pwd;
    restore_directory = onCleanup(@() cd(previous_directory));
    cd(record.benchmark_dir);

    existing_summaries = list_files(feature_savepath, 'summary_*.pdf');
    options = struct();
    options.load = record.source_timestamp;
    options.savepath = feature_savepath;
    options.solvers_to_load = [1, 2];
    options.solver_names = {'Accelerated BDS', 'NEWUOA'};
    options.feature_name = record.internal_feature_name;
    options.plibs = {'s2mpj'};
    options.ptype = 'u';
    options.mindim = 6;
    options.maxdim = 50;
    options.max_eval_factor = 200;
    options.n_jobs = 1;
    options.solver_verbose = 0;
    [solver_scores, ~] = benchmark(options);

    current_summaries = list_files(feature_savepath, 'summary_*.pdf');
    new_summaries = setdiff(current_summaries, existing_summaries, 'stable');
    assert(numel(new_summaries) == 1, ...
        'Expected one new E4 summary for %s, found %d.', ...
        record.feature_name, numel(new_summaries));
    summary_path = new_summaries{1};
    fix_summary_feature_titles(summary_path, record.feature_name);

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

function paths = list_files(root_path, filename_pattern)

    listing = dir(fullfile(root_path, '**', filename_pattern));
    listing = listing(~[listing.isdir]);
    paths = arrayfun(@(entry) fullfile(entry.folder, entry.name), ...
        listing, 'UniformOutput', false);
    paths = paths(:)';

end

function ensure_optiprofiler_on_path()

    if exist('benchmark', 'file') == 2
        return;
    end
    home_dir = char(java.lang.System.getProperty('user.home'));
    root_path = fullfile(home_dir, 'local', 'optiprofiler');
    candidates = { ...
        fullfile(root_path, 'matlab', 'optiprofiler', 'src'), ...
        fullfile(root_path, 'matlab', 'optiprofiler', 'problem_libs'), ...
        fullfile(root_path, 'matlab', 'optiprofiler'), ...
        fullfile(root_path, 'matlab') ...
    };
    for i_path = 1:numel(candidates)
        if exist(candidates{i_path}, 'dir') == 7
            addpath(candidates{i_path});
        end
    end
    assert(exist('benchmark', 'file') == 2, 'Cannot find OptiProfiler benchmark.');

end

function save_manifest(manifest_file, manifest)

    save(manifest_file, 'manifest');

end

function ensure_directory(path_directory)

    if exist(path_directory, 'dir') ~= 7
        mkdir(path_directory);
    end

end

function merge_summary_pdfs(summary_paths, output_file)

    assert(~isempty(summary_paths) ...
        && all(cellfun(@(path) exist(path, 'file') == 2, summary_paths)), ...
        'Cannot merge E4 summaries because one or more inputs are missing.');
    command = ['pdfunite ', strjoin(cellfun(@shell_quote, summary_paths, ...
        'UniformOutput', false), ' '), ' ', shell_quote(output_file)];
    [status, output] = system(command);
    assert(status == 0, 'pdfunite failed while creating %s: %s', output_file, output);

end

function quoted = shell_quote(text)

    quoted = ['''', strrep(char(text), '''', '''"''"'''), ''''];

end
