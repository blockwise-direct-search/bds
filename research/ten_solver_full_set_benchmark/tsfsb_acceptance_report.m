function report = tsfsb_acceptance_report(artifact_root, output_path)
%TSFSB_ACCEPTANCE_REPORT Aggregate TSFSB manifests into one JSON report.
%
%   New for TSFSB. Reads the accepted evaluation manifest of every
%   feature under <ARTIFACT_ROOT>/evaluations and the accepted subset
%   manifests under <ARTIFACT_ROOT>/profiles, and writes one
%   machine-checkable JSON with planned versus actual outcomes per
%   feature, run, and solver, the total against 460*P (P from the frozen
%   problem manifest), solver flag counts, retry records, and the list
%   of unresolved units. The report itself does not accept anything; it
%   only aggregates, and marks status 'incomplete' whenever a unit is
%   missing.

if nargin < 1 || isempty(artifact_root)
    artifact_root = getenv('TSFSB_ARTIFACT_ROOT');
end
if isempty(artifact_root)
    error('tsfsb_acceptance_report:MissingArtifactRoot', ...
        'An artifact root is required (argument or TSFSB_ARTIFACT_ROOT).');
end
if nargin < 2 || isempty(output_path)
    output_path = fullfile(artifact_root, 'tsfsb_acceptance_report.json');
end

module_dir = fileparts(mfilename('fullpath'));
addpath(module_dir);
spec = tsfsb_benchmark_spec();
[pool, ~] = tsfsb_solver_pool();
n_solvers = numel(pool);

problem_manifest_path = fullfile(artifact_root, 'problem_manifest.mat');
if ~exist(problem_manifest_path, 'file')
    problem_manifest_path = spec.problem_manifest;
end
manifest = load(problem_manifest_path, 'problem_names');
problem_count = numel(manifest.problem_names);
planned_runs_total = sum([spec.features.n_runs]);
planned_outcomes_total = planned_runs_total * problem_count * n_solvers;

feature_reports = repmat(struct( ...
    'feature', '', ...
    'status', 'unresolved', ...
    'planned_runs', 0, ...
    'actual_runs', 0, ...
    'planned_outcomes', 0, ...
    'actual_outcomes', 0, ...
    'outcomes_per_solver', [], ...
    'abnormal_termination_count', 0, ...
    'output_fallback_count', 0, ...
    'retry_count', 0, ...
    'time_stamp', ''), 1, numel(spec.features));
unresolved = {};
for i_feature = 1:numel(spec.features)
    feature = spec.features(i_feature);
    entry = feature_reports(i_feature);
    entry.feature = feature.name;
    entry.planned_runs = feature.n_runs;
    entry.planned_outcomes = feature.n_runs * problem_count * n_solvers;
    feature_root = fullfile(artifact_root, 'evaluations', feature.name);
    entry.retry_count = numel(dir(fullfile(feature_root, 'FAILED_*.txt')));
    accepted_path = fullfile(feature_root, 'accepted_manifest.json');
    if ~exist(accepted_path, 'file')
        unresolved{end + 1} = ['evaluation:', feature.name]; %#ok<AGROW>
        feature_reports(i_feature) = entry;
        continue;
    end
    accepted = jsondecode(fileread(accepted_path));
    entry.status = accepted.status;
    entry.actual_runs = accepted.n_runs;
    entry.actual_outcomes = numel(accepted.evaluation_counts);
    entry.outcomes_per_solver = ...
        squeeze(sum(sum(accepted.evaluation_counts >= 0, 1), 3));
    entry.abnormal_termination_count = accepted.abnormal_termination_count;
    entry.output_fallback_count = accepted.output_fallback_count;
    entry.time_stamp = accepted.time_stamp;
    feature_reports(i_feature) = entry;
end

subset_names = fieldnames(spec.subsets);
subset_reports = {};
for i_feature = 1:numel(spec.features)
    feature_name = spec.features(i_feature).name;
    for i_subset = 1:numel(subset_names)
        subset_name = subset_names{i_subset};
        subset_root = fullfile(artifact_root, 'profiles', ...
            feature_name, subset_name);
        accepted_path = fullfile(subset_root, 'accepted_manifest.json');
        entry = struct( ...
            'feature', feature_name, ...
            'subset', subset_name, ...
            'status', 'unresolved', ...
            'target_recomputation_checked', false, ...
            'max_curve_deviation', NaN);
        if exist(accepted_path, 'file')
            accepted = jsondecode(fileread(accepted_path));
            entry.status = accepted.status;
            if isfield(accepted, 'target_recomputation') ...
                    && accepted.target_recomputation.checked
                entry.target_recomputation_checked = true;
                entry.max_curve_deviation = ...
                    accepted.target_recomputation.max_curve_deviation;
            end
        else
            unresolved{end + 1} = ...
                ['subset:', feature_name, '/', subset_name]; %#ok<AGROW>
        end
        subset_reports{end + 1} = entry; %#ok<AGROW>
    end
end

actual_outcomes_total = sum([feature_reports.actual_outcomes]);
report = struct();
report.schema_version = 1;
report.created_at = char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
report.artifact_root = artifact_root;
report.problem_count = problem_count;
report.solver_count = n_solvers;
report.planned_outcomes_total = planned_outcomes_total;
report.actual_outcomes_total = actual_outcomes_total;
report.planned_outcome_formula = '460*P';
report.outcome_totals_match = ...
    actual_outcomes_total == planned_outcomes_total;
report.abnormal_termination_count = ...
    sum([feature_reports.abnormal_termination_count]);
report.output_fallback_count = ...
    sum([feature_reports.output_fallback_count]);
report.retry_count = sum([feature_reports.retry_count]);
report.features = feature_reports;
report.subsets = subset_reports;
report.unresolved = unresolved;
if isempty(unresolved) && report.outcome_totals_match
    report.status = 'complete';
else
    report.status = 'incomplete';
end

tsfsb_write_json(output_path, report);
fprintf('TSFSB_ACCEPTANCE_REPORT %s %s\n', report.status, output_path);
fprintf('TSFSB_ACCEPTANCE_REPORT_OK\n');

end
