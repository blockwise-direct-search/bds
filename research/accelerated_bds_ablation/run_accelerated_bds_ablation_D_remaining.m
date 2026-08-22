function run_accelerated_bds_ablation_D_remaining(previous_savepath)
%RUN_ACCELERATED_BDS_ABLATION_D_REMAINING Resume the unfinished 500n D group.

    if nargin < 1 || ~isfolder(previous_savepath)
        error('Please provide the existing D-group save path.');
    end

    path_ablation = fileparts(mfilename('fullpath'));
    path_research = fileparts(path_ablation);
    path_repo = fileparts(path_research);
    path_tests = fullfile(path_repo, 'tests');
    path_summaries = fullfile(path_ablation, 'summaries');
    addpath(fullfile(path_repo, 'src'));
    addpath(path_tests);
    addpath(fullfile(path_tests, 'competitors'));
    addpath(fullfile(path_tests, 'tools'));
    if ~exist(path_summaries, 'dir')
        mkdir(path_summaries);
    end

    timestamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    group_label = 'accelerated_bds_ablation_D_cbds_nomad_500n_rotated_remaining';
    savepath = fullfile(path_ablation, 'testdata', ...
        [group_label, '_6_50_s2mpj_', timestamp]);
    mkdir(savepath);

    completed_prefixes = { ...
        'cbds_500n_nomad_500n_6_50_1_plain_s2mpj_', ...
        'cbds_500n_nomad_500n_6_50_5_noisy_1_no_rotation_s2mpj_', ...
        'cbds_500n_nomad_500n_6_50_5_noisy_2_no_rotation_s2mpj_', ...
        'cbds_500n_nomad_500n_6_50_5_noisy_3_no_rotation_s2mpj_', ...
        'cbds_500n_nomad_500n_6_50_5_noisy_4_no_rotation_s2mpj_' ...
    };
    remaining_features = { ...
        'linearly_transformed', ...
        'linearly_transformed_noisy_1e-1', ...
        'linearly_transformed_noisy_1e-2', ...
        'linearly_transformed_noisy_1e-3', ...
        'linearly_transformed_noisy_1e-4' ...
    };

    summary_paths = existing_summary_paths(previous_savepath, completed_prefixes);
    fprintf('Previous savepath: %s\n', previous_savepath);
    fprintf('Resume savepath: %s\n', savepath);
    fprintf('Started: %s\n', char(datetime('now')));

    for i_feature = 1:numel(remaining_features)
        feature_name = remaining_features{i_feature};
        options = struct();
        options.mindim = 6;
        options.maxdim = 50;
        options.plibs = 's2mpj';
        options.feature_name = feature_name;
        options.feature_display_name = feature_name;
        options.n_runs = 5;
        options.solver_names = {'cbds-500n', 'nomad-500n'};
        options.savepath = savepath;

        fprintf('[%s] Running remaining feature %d/%d: %s\n', ...
            char(datetime('now')), i_feature, numel(remaining_features), feature_name);
        profile_optiprofiler(options);
        summary_paths{end + 1} = newest_summary_pdf(savepath);
        fprintf('[%s] Finished remaining feature %d/%d: %s\n', ...
            char(datetime('now')), i_feature, numel(remaining_features), feature_name);
        fprintf('Summary: %s\n', summary_paths{end});
    end

    output_file = fullfile(path_summaries, ...
        ['summary_accelerated_bds_ablation_D_cbds_500n_nomad_500n_', ...
        'u_6_50_10features_s2mpj_', timestamp, '.pdf']);
    merge_summary_pdfs(summary_paths, output_file);
    fprintf('\nMerged summary: %s\n', output_file);
    fprintf('Finished: %s\n', char(datetime('now')));

end

function summary_paths = existing_summary_paths(savepath, prefixes)

    summary_paths = cell(size(prefixes));
    for i_prefix = 1:numel(prefixes)
        listing = dir(fullfile(savepath, [prefixes{i_prefix}, '*'], 'summary.pdf'));
        if numel(listing) ~= 1
            error('Expected exactly one completed summary for prefix %s, found %d.', ...
                prefixes{i_prefix}, numel(listing));
        end
        summary_paths{i_prefix} = fullfile(listing.folder, listing.name);
    end

end

function summary_file = newest_summary_pdf(savepath)

    listing = dir(fullfile(savepath, '*', 'summary.pdf'));
    if isempty(listing)
        listing = dir(fullfile(savepath, '*', '*', 'summary_*.pdf'));
    end
    if isempty(listing)
        error('Cannot find a summary PDF under %s.', savepath);
    end
    [~, idx] = max([listing.datenum]);
    summary_file = fullfile(listing(idx).folder, listing(idx).name);

end

function merge_summary_pdfs(summary_paths, output_file)

    missing = cellfun(@(p) isempty(p) || ~exist(p, 'file'), summary_paths);
    if any(missing)
        error('Some summary PDFs are missing.');
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
