function run_accelerated_bds_ablation_remaining(group_name)
%RUN_ACCELERATED_BDS_ABLATION_REMAINING Run selected remaining A experiments.

    if nargin < 1
        error('Please provide group_name.');
    end

    group_name = lower(char(group_name));
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
    [group_label, experiments] = group_experiments(group_name);
    savepath = fullfile(path_ablation, 'testdata', ...
        [group_label, '_6_50_s2mpj_', timestamp]);
    if ~exist(savepath, 'dir')
        mkdir(savepath);
    end

    fprintf('Remaining group: %s\n', group_name);
    fprintf('Savepath: %s\n', savepath);
    fprintf('Started: %s\n', char(datetime('now')));

    summary_paths = {};
    for i_exp = 1:numel(experiments)
        experiment = experiments(i_exp);
        fprintf('\nExperiment %d/%d: %s\n', ...
            i_exp, numel(experiments), experiment.label);
        fprintf('Solvers: %s\n', strjoin(experiment.solver_names, ', '));

        for i_feature = 1:numel(experiment.feature_names)
            feature_name = experiment.feature_names{i_feature};
            options = struct();
            options.mindim = 6;
            options.maxdim = 50;
            options.plibs = 's2mpj';
            options.feature_name = feature_name;
            options.n_runs = n_runs_for_feature(feature_name);
            options.solver_names = experiment.solver_names;
            options.savepath = savepath;
            options.feature_display_name = feature_name;

            fprintf('[%s] Running %s, feature %d/%d: %s (n_runs=%d)\n', ...
                char(datetime('now')), experiment.label, ...
                i_feature, numel(experiment.feature_names), ...
                feature_name, options.n_runs);
            profile_optiprofiler(options);
            summary_paths{end + 1} = newest_summary_pdf(savepath);
            fprintf('[%s] Finished %s, feature %d/%d: %s\n', ...
                char(datetime('now')), experiment.label, ...
                i_feature, numel(experiment.feature_names), feature_name);
            fprintf('Summary: %s\n', summary_paths{end});
        end
    end

    output_file = fullfile(path_summaries, ...
        ['summary_', group_label, '_u_6_50_s2mpj_', timestamp, '.pdf']);
    merge_summary_pdfs(summary_paths, output_file);
    fprintf('\nMerged summary: %s\n', output_file);
    fprintf('Finished: %s\n', char(datetime('now')));

end

function [group_label, experiments] = group_experiments(group_name)

    plain_and_rotated = {'plain', 'linearly_transformed'};

    switch group_name
        case 'a_memory_rotated'
            group_label = 'accelerated_bds_ablation_A_memory_only_rotated_remaining';
            experiments = make_experiment('cbds_baseline_vs_memory_only_200n', ...
                {'cbds-baseline-200n', 'cbds-memory-only-200n'}, ...
                {'linearly_transformed'});
        case 'a_pattern_momentum'
            group_label = 'accelerated_bds_ablation_A_pattern_momentum_remaining';
            experiments = [ ...
                make_experiment('cbds_baseline_vs_pattern_only_200n', ...
                    {'cbds-baseline-200n', 'cbds-pattern-only-200n'}, ...
                    plain_and_rotated), ...
                make_experiment('cbds_baseline_vs_momentum_only_200n', ...
                    {'cbds-baseline-200n', 'cbds-momentum-only-200n'}, ...
                    plain_and_rotated) ...
            ];
        otherwise
            error('Unknown remaining ablation group: %s.', group_name);
    end

end

function experiment = make_experiment(label, solver_names, feature_names)

    experiment = struct();
    experiment.label = label;
    experiment.solver_names = solver_names;
    experiment.feature_names = feature_names;

end

function n_runs = n_runs_for_feature(feature_name)

    if strcmpi(feature_name, 'plain')
        n_runs = 1;
    else
        n_runs = 5;
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

    if isempty(summary_paths)
        error('No summary PDFs to merge.');
    end
    missing = cellfun(@(p) isempty(p) || ~exist(p, 'file'), summary_paths);
    if any(missing)
        error('Some summary PDFs are missing.');
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
