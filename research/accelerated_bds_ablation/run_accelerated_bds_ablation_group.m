function run_accelerated_bds_ablation_group(group_name)
%RUN_ACCELERATED_BDS_ABLATION_GROUP Run accelerated BDS ablation groups.

    if nargin < 1
        error('Please provide group_name.');
    end

    group_name = upper(char(group_name));
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

    fprintf('Group: %s\n', group_name);
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

    ablation_features = {'plain', 'linearly_transformed'};
    full_features = { ...
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

    switch group_name
        case 'A'
            group_label = 'accelerated_bds_ablation_A_cbds_single_strategy';
            experiments = [ ...
                make_experiment('cbds_baseline_vs_memory_only_200n', ...
                    {'cbds-baseline-200n', 'cbds-memory-only-200n'}, ablation_features), ...
                make_experiment('cbds_baseline_vs_pattern_only_200n', ...
                    {'cbds-baseline-200n', 'cbds-pattern-only-200n'}, ablation_features), ...
                make_experiment('cbds_baseline_vs_momentum_only_200n', ...
                    {'cbds-baseline-200n', 'cbds-momentum-only-200n'}, ablation_features) ...
            ];
        case 'B'
            group_label = 'accelerated_bds_ablation_B_cbds_minimal_combination';
            experiments = [ ...
                make_experiment('cbds_baseline_vs_pattern_momentum_200n', ...
                    {'cbds-baseline-200n', 'cbds-pattern-momentum-200n'}, ablation_features), ...
                make_experiment('cbds_pattern_momentum_vs_all_on_200n', ...
                    {'cbds-pattern-momentum-200n', 'accelerated-bds-all-on-200n'}, ablation_features), ...
                make_experiment('cbds_baseline_vs_all_on_200n', ...
                    {'cbds-baseline-200n', 'accelerated-bds-all-on-200n'}, ablation_features) ...
            ];
        case 'C'
            group_label = 'accelerated_bds_ablation_C_ds_generalization';
            experiments = [ ...
                make_experiment('ds_baseline_vs_all_on_200n', ...
                    {'ds-baseline-200n', 'accelerated-ds-all-on-200n'}, ablation_features), ...
                make_experiment('ds_baseline_vs_pattern_momentum_200n', ...
                    {'ds-baseline-200n', 'ds-pattern-momentum-200n'}, ablation_features), ...
                make_experiment('ds_pattern_momentum_vs_all_on_200n', ...
                    {'ds-pattern-momentum-200n', 'accelerated-ds-all-on-200n'}, ablation_features) ...
            ];
        case 'D'
            group_label = 'accelerated_bds_ablation_D_cbds_nomad_baseline';
            experiments = [ ...
                make_experiment('cbds_200n_vs_nomad_200n', ...
                    {'cbds-baseline-200n', 'nomad-200n'}, full_features), ...
                make_experiment('cbds_500n_vs_nomad_500n', ...
                    {'cbds-500n', 'nomad-500n'}, full_features) ...
            ];
        otherwise
            error('Unknown ablation group: %s.', group_name);
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
