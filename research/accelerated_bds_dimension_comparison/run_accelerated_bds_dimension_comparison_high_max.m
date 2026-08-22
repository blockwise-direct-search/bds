function run_accelerated_bds_dimension_comparison_high_max()
%RUN_ACCELERATED_BDS_DIMENSION_COMPARISON_HIGH_MAX Run screened 51-200 tests.

    path_experiment = fileparts(mfilename('fullpath'));
    path_research = fileparts(path_experiment);
    path_repo = fileparts(path_research);
    path_tests = fullfile(path_repo, 'tests');
    path_testdata = fullfile(path_experiment, 'testdata');
    path_summaries = fullfile(path_experiment, 'summaries');
    runtime_root = fullfile(path_experiment, 'runtime', 'optiprofiler_max');
    optiprofiler_root = fullfile(runtime_root, 'matlab', 'optiprofiler');
    s2mpj_root = fullfile(optiprofiler_root, 'problem_libs', 's2mpj');

    addpath(fullfile(path_repo, 'src'));
    addpath(path_tests);
    addpath(fullfile(path_tests, 'competitors'));
    addpath(fullfile(path_tests, 'tools'));
    configure_isolated_optiprofiler(optiprofiler_root, s2mpj_root);
    ensure_directory(path_testdata);
    ensure_directory(path_summaries);

    selection_options = struct();
    selection_options.ptype = 'u';
    selection_options.mindim = 51;
    selection_options.maxdim = 200;
    timing_excludelist = high_dimension_timing_excludelist();
    selection_options.excludelist = repository_s2mpj_excludelist();
    frozen_problem_names = sort(s2mpj_select(selection_options));
    frozen_problem_names = unique(frozen_problem_names, 'stable');
    frozen_problem_names = setdiff(frozen_problem_names, ...
        timing_excludelist, 'stable');
    assert(numel(frozen_problem_names) == 86, ...
        'Expected 86 screened S2MPJ max-size problem families, found %d.', ...
        numel(frozen_problem_names));
    assert(isempty(intersect(frozen_problem_names, timing_excludelist)), ...
        'The frozen problem set still contains timing-pilot exclusions.');
    frozen_problem_dims = load_problem_dimensions(frozen_problem_names);
    assert(all(frozen_problem_dims >= 51 & frozen_problem_dims <= 200), ...
        'The frozen problem set contains dimensions outside [51, 200].');

    timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    raw_savepath = fullfile(path_testdata, ...
        ['accelerated_bds_dimension_comparison_high_max_screened86_raw_51_200_s2mpj_', timestamp]);
    redraw_savepath = fullfile(path_testdata, ...
        ['accelerated_bds_dimension_comparison_high_max_screened86_pairwise_51_200_s2mpj_', timestamp]);
    ensure_directory(raw_savepath);
    ensure_directory(redraw_savepath);
    write_frozen_problem_list(fullfile(raw_savepath, 'frozen_problem_names.txt'), ...
        frozen_problem_names, frozen_problem_dims);

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
    manifest.schema_version = 2;
    manifest.started_at = char(datetime('now'));
    manifest.finished_at = '';
    manifest.status = 'RAW-RUNNING';
    manifest.formal_experiment = true;
    manifest.dimension_range = [51, 200];
    manifest.problem_library = 's2mpj';
    manifest.variable_size = 'max';
    manifest.test_feasibility_problems = 0;
    manifest.frozen_problem_names = frozen_problem_names;
    manifest.frozen_problem_dims = frozen_problem_dims;
    manifest.problem_count = numel(frozen_problem_names);
    manifest.timing_pilot_excludelist = timing_excludelist;
    manifest.timing_cutoff_seconds = 1800;
    manifest.optiprofiler_root = optiprofiler_root;
    manifest.runtime_config_sha256 = sha256_file(fullfile(s2mpj_root, 'config.txt'));
    manifest.selector_sha256 = sha256_file(fullfile(s2mpj_root, 's2mpj_select.m'));
    manifest.probinfo_sha256 = sha256_file(fullfile(s2mpj_root, 'probinfo_matlab.mat'));
    manifest.max_eval_factor = 200;
    manifest.n_jobs = 120;
    manifest.step_tolerance_bds = 1e-6;
    manifest.seed = 0;
    manifest.features = features;
    manifest.feature_n_runs = cellfun(@n_runs_for_feature, features);
    manifest.raw_solver_names = raw_solver_names;
    manifest.raw_savepath = raw_savepath;
    manifest.redraw_savepath = redraw_savepath;
    manifest.summary_dir = path_summaries;
    manifest.raw_records = repmat(empty_raw_record(), 1, numel(features));
    manifest.pairs = pairs;
    manifest_file = fullfile(raw_savepath, 'manifest.mat');
    save_manifest(manifest_file, manifest);

    fprintf('Accelerated BDS dimension comparison: screened high-dimensional max-size experiment\n');
    fprintf('Started: %s\n', manifest.started_at);
    fprintf('Isolated OptiProfiler: %s\n', optiprofiler_root);
    fprintf('S2MPJ variable_size: max\n');
    fprintf('Frozen problems: %d distinct families\n', numel(frozen_problem_names));
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
        options.problem_names = frozen_problem_names;
        options.feature_name = feature_name;
        options.feature_display_name = feature_name;
        options.n_runs = n_runs_for_feature(feature_name);
        options.seed = 0;
        options.max_eval_factor = 200;
        options.n_jobs = 120;
        options.solver_names = raw_solver_names;
        options.savepath = raw_savepath;

        fprintf('\n[%s] Raw feature %d/%d: %s (n_runs=%d, problems=%d)\n', ...
            char(datetime('now')), i_feature, numel(features), ...
            feature_name, options.n_runs, numel(frozen_problem_names));
        profile_optiprofiler(options);

        record = capture_new_raw_record(raw_savepath, existing_data_files, ...
            feature_name, frozen_problem_names, frozen_problem_dims, ...
            options.n_runs, raw_solver_names);
        manifest.raw_records(i_feature) = record;
        save_manifest(manifest_file, manifest);
        fprintf('[%s] Raw feature completed and frozen-set validated: %s\n', ...
            char(datetime('now')), feature_name);
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

        fprintf('\nPairwise redraw %s: %s\n', pair.id, ...
            strjoin(pair.display_names, ' vs '));
        for i_feature = 1:numel(features)
            record = manifest.raw_records(i_feature);
            fprintf('[%s] Redraw %s feature %d/%d: %s\n', ...
                char(datetime('now')), pair.id, i_feature, numel(features), ...
                record.feature_name);
            [summary_path, solver_scores] = redraw_pairwise_feature( ...
                record, pair, pair_savepath, frozen_problem_names);
            pair_summary_paths{i_feature} = summary_path;
            pair_scores(i_feature, :) = solver_scores(:)';
            fprintf('Pairwise summary: %s\n', summary_path);
        end

        merged_summary = fullfile(path_summaries, sprintf( ...
            'summary_%s_200n_u_51_200_screened86_10features_s2mpj_%s.pdf', ...
            pair.slug, timestamp));
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


function configure_isolated_optiprofiler(optiprofiler_root, s2mpj_root)

    assert(exist(fullfile(s2mpj_root, 'config.txt'), 'file') == 2, ...
        'Missing isolated S2MPJ config: %s', s2mpj_root);
    config_text = fileread(fullfile(s2mpj_root, 'config.txt'));
    assert(~isempty(regexp(config_text, '(?m)^variable_size=max\s*$', 'once')), ...
        'The isolated S2MPJ runtime is not configured with variable_size=max.');
    assert(~isempty(regexp(config_text, ...
        '(?m)^test_feasibility_problems=0\s*$', 'once')), ...
        'The isolated S2MPJ runtime must exclude feasibility problems.');

    addpath(fullfile(optiprofiler_root, 'src'), '-begin');
    addpath(fullfile(optiprofiler_root, 'problem_libs'), '-begin');
    addpath(s2mpj_root, '-begin');
    benchmark_path = which('benchmark');
    selector_path = which('s2mpj_select');
    assert(startsWith(benchmark_path, optiprofiler_root), ...
        'benchmark is not loaded from the isolated runtime: %s', benchmark_path);
    assert(startsWith(selector_path, optiprofiler_root), ...
        's2mpj_select is not loaded from the isolated runtime: %s', selector_path);

end


function names = repository_s2mpj_excludelist()

    names = { ...
        'DIAMON2DLS', 'DIAMON2D', 'DIAMON3DLS', 'DIAMON3D', ...
        'DMN15102LS', 'DMN15102', 'DMN15103LS', 'DMN15103', ...
        'DMN15332LS', 'DMN15332', 'DMN15333LS', 'DMN15333', ...
        'DMN37142LS', 'DMN37142', 'DMN37143LS', 'DMN37143', ...
        'ROSSIMP3_mp', 'BAmL1SPLS', 'FBRAIN3LS', ...
        'GAUSS1LS', 'GAUSS2LS', 'GAUSS3LS', 'HYDC20LS', 'HYDCAR6LS', ...
        'LUKSAN11LS', 'LUKSAN12LS', 'LUKSAN13LS', 'LUKSAN14LS', ...
        'LUKSAN17LS', 'LUKSAN21LS', 'LUKSAN22LS', ...
        'METHANB8LS', 'METHANL8LS', 'SPINLS', ...
        'VESUVIALS', 'VESUVIOLS', 'VESUVIOULS', 'YATP1CLS', ...
        'MISRA1ALS', 'OSBORNEA', 'ECKERLE4LS', 'NELSONLS' ...
    };

end


function names = high_dimension_timing_excludelist()

    % The stopped 98-family plain pilot excluded ARGTRIGLS_200 immediately
    % and families whose three-solver total exceeded 30 minutes.
    names = { ...
        'ARGTRIGLS_200', 'SENSORS_100', 'TRIGON1_100', 'MANCINO_100', ...
        'SPIN2LS_102', 'INTEQNELS_102', 'MODBEALE_200', ...
        'EIGENBLS_110', 'EIGENALS_110', 'MSQRTALS_100', ...
        'MSQRTBLS_100', 'NCB20B_180' ...
    };

end


function dimensions = load_problem_dimensions(problem_names)

    dimensions = zeros(1, numel(problem_names));
    for i_problem = 1:numel(problem_names)
        problem = s2mpj_load(problem_names{i_problem});
        dimensions(i_problem) = problem.n;
    end

end


function write_frozen_problem_list(filename, problem_names, problem_dims)

    fid = fopen(filename, 'w');
    assert(fid >= 0, 'Cannot create frozen problem list: %s', filename);
    close_file = onCleanup(@() fclose(fid));
    fprintf(fid, '# S2MPJ variable_size=max; one instance per family\n');
    fprintf(fid, '# index\tproblem_name\tdimension\n');
    for i_problem = 1:numel(problem_names)
        fprintf(fid, '%d\t%s\t%d\n', i_problem, ...
            problem_names{i_problem}, problem_dims(i_problem));
    end

end


function pair = make_pair(id, slug, solver_indices, display_names)

    pair = struct('id', id, 'slug', slug, ...
        'solver_indices', solver_indices, 'display_names', {display_names}, ...
        'feature_summary_paths', {{}}, 'solver_scores', [], 'merged_summary', '');

end


function record = empty_raw_record()

    record = struct('feature_name', '', 'internal_feature_name', '', ...
        'benchmark_dir', '', 'stamp_dir', '', 'data_file', '', ...
        'summary_file', '', 'timestamp', '', 'problem_count', 0, ...
        'n_runs', 0);

end


function n_runs = n_runs_for_feature(feature_name)

    n_runs = 3;
    if strcmp(feature_name, 'plain')
        n_runs = 1;
    end

end


function record = capture_new_raw_record(raw_savepath, existing_data_files, ...
        feature_name, frozen_problem_names, frozen_problem_dims, ...
        expected_n_runs, expected_solver_names)

    current_data_files = list_files(raw_savepath, 'data_for_loading.mat');
    new_data_files = setdiff(current_data_files, existing_data_files, 'stable');
    assert(numel(new_data_files) == 1, ...
        'Expected one new data_for_loading.mat for %s, found %d.', ...
        feature_name, numel(new_data_files));

    data_file = new_data_files{1};
    validate_raw_problem_set(data_file, frozen_problem_names, ...
        frozen_problem_dims, expected_n_runs, expected_solver_names);
    test_log_dir = fileparts(data_file);
    stamp_dir = fileparts(test_log_dir);
    benchmark_dir = fileparts(stamp_dir);
    timestamp_files = dir(fullfile(test_log_dir, 'time_stamp_*.txt'));
    assert(numel(timestamp_files) == 1, ...
        'Expected one timestamp file in %s, found %d.', ...
        test_log_dir, numel(timestamp_files));
    timestamp_token = regexp(timestamp_files(1).name, ...
        '^time_stamp_(\d{8}_\d{6})\.txt$', 'tokens', 'once');
    assert(~isempty(timestamp_token), ...
        'Cannot parse timestamp from %s.', timestamp_files(1).name);
    summary_files = dir(fullfile(stamp_dir, 'summary_*.pdf'));
    assert(numel(summary_files) == 1, ...
        'Expected one stamped summary PDF in %s, found %d.', ...
        stamp_dir, numel(summary_files));

    record = empty_raw_record();
    record.feature_name = feature_name;
    record.internal_feature_name = internal_feature_name(feature_name);
    record.benchmark_dir = benchmark_dir;
    record.stamp_dir = stamp_dir;
    record.data_file = data_file;
    record.summary_file = fullfile(summary_files(1).folder, summary_files(1).name);
    record.timestamp = timestamp_token{1};
    record.problem_count = numel(frozen_problem_names);
    record.n_runs = expected_n_runs;

end


function validate_raw_problem_set(data_file, expected_names, expected_dims, ...
        expected_n_runs, expected_solver_names)

    loaded = load(data_file, 'results_plibs');
    assert(isfield(loaded, 'results_plibs') && numel(loaded.results_plibs) == 1, ...
        'Expected one problem library in %s.', data_file);
    result = loaded.results_plibs{1};
    assert(strcmp(result.plib, 's2mpj'), 'Unexpected problem library in %s.', data_file);
    assert(isequal(result.solver_names(:)', expected_solver_names(:)'), ...
        'The saved solver order differs from the requested order in %s.', data_file);
    assert(size(result.computation_times, 3) == expected_n_runs, ...
        'Expected %d runs in %s, found %d.', expected_n_runs, data_file, ...
        size(result.computation_times, 3));
    assert(isequal(result.problem_names(:)', expected_names(:)'), ...
        'The saved problem names differ from the frozen screened set in %s.', data_file);
    assert(isequal(result.problem_dims(:)', expected_dims(:)'), ...
        'The saved problem dimensions differ from the frozen set in %s.', data_file);
    assert(all(result.problem_dims >= 51 & result.problem_dims <= 200), ...
        'Saved dimensions fall outside [51, 200] in %s.', data_file);

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


function [summary_path, solver_scores] = redraw_pairwise_feature( ...
        record, pair, pair_savepath, frozen_problem_names)

    previous_directory = pwd;
    restore_directory = onCleanup(@() cd(previous_directory));
    cd(record.benchmark_dir);
    existing_summaries = list_files(pair_savepath, 'summary_*.pdf');
    options = struct();
    options.load = record.timestamp;
    options.savepath = pair_savepath;
    options.solvers_to_load = pair.solver_indices;
    options.solver_names = pair.display_names;
    options.problem_names = frozen_problem_names;
    options.feature_name = record.internal_feature_name;
    options.plibs = {'s2mpj'};
    options.ptype = 'u';
    options.mindim = 51;
    options.maxdim = 200;
    options.max_eval_factor = 200;
    options.n_jobs = 1;
    options.solver_verbose = 0;
    [solver_scores, ~] = benchmark(options);

    current_summaries = list_files(pair_savepath, 'summary_*.pdf');
    new_summaries = setdiff(current_summaries, existing_summaries, 'stable');
    assert(numel(new_summaries) == 1, ...
        'Expected one new pairwise summary for %s/%s, found %d.', ...
        pair.id, record.feature_name, numel(new_summaries));
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


function digest = sha256_file(filename)

    [status, output] = system(['sha256sum ', shell_quote(filename)]);
    assert(status == 0, 'Cannot hash %s: %s', filename, output);
    token = regexp(output, '^([0-9a-f]{64})', 'tokens', 'once');
    assert(~isempty(token), 'Cannot parse SHA-256 output for %s.', filename);
    digest = token{1};

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
        'Cannot merge summaries because one or more input PDFs are missing.');
    if exist(output_file, 'file') == 2
        delete(output_file);
    end
    command = ['pdfunite ', strjoin(cellfun(@shell_quote, summary_paths, ...
        'UniformOutput', false), ' '), ' ', shell_quote(output_file)];
    [status, output] = system(command);
    assert(status == 0, 'pdfunite failed while creating %s: %s', output_file, output);

end


function quoted = shell_quote(text)

    quoted = ['''', strrep(char(text), '''', '''"''"'''), ''''];

end
