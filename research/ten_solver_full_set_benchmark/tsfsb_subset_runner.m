function tsfsb_subset_runner(artifact_root, destination_root)
%TSFSB_SUBSET_RUNNER Reprofile all TSFSB subsets from saved evaluations.
%
%   New for TSFSB. Runs profile_tsfsb_saved_results over the five solver
%   subsets of the frozen spec for every accepted feature evaluation, in
%   load mode only (no solver or objective re-evaluation is possible in
%   load mode). Each subset replot is idempotent: an already accepted
%   subset manifest is verified and skipped. Finishes with the synthetic
%   sensitivity fixture verify_tsfsb_subset_targets.
%
%   TSFSB_SUBSET_RUNNER(ARTIFACT_ROOT) reads evaluations from
%   <ARTIFACT_ROOT>/evaluations and writes subset profiles to
%   <ARTIFACT_ROOT>/profiles. With no arguments, both roots come from
%   the environment variable TSFSB_ARTIFACT_ROOT.

if nargin < 1 || isempty(artifact_root)
    artifact_root = getenv('TSFSB_ARTIFACT_ROOT');
end
if isempty(artifact_root)
    error('tsfsb_subset_runner:MissingArtifactRoot', ...
        'An artifact root is required (argument or TSFSB_ARTIFACT_ROOT).');
end
if nargin < 2 || isempty(destination_root)
    destination_root = fullfile(artifact_root, 'profiles');
end

module_dir = fileparts(mfilename('fullpath'));
addpath(module_dir);
tsfsb_setup_paths();

spec = tsfsb_benchmark_spec();
subset_names = fieldnames(spec.subsets);
for i_feature = 1:numel(spec.features)
    feature_name = spec.features(i_feature).name;
    source_feature_root = fullfile(artifact_root, 'evaluations', ...
        feature_name);
    for i_subset = 1:numel(subset_names)
        subset_name = subset_names{i_subset};
        manifest = profile_tsfsb_saved_results( ...
            source_feature_root, subset_name, destination_root);
        assert(~manifest.pdf_postprocessing);
        assert(manifest.target_recomputation.checked);
    end
end

fixture_root = fullfile(artifact_root,'sensitivity_fixture');
if ~isfile(fullfile(fixture_root,'VERIFIED'))
    verify_tsfsb_subset_targets(fixture_root);
    fid = fopen(fullfile(fixture_root,'VERIFIED'),'w');
    fprintf(fid,'native subset-target sensitivity check passed\n'); fclose(fid);
end

report = tsfsb_acceptance_report(artifact_root);
assert(strcmp(report.status,'complete'), 'TSFSB:IncompleteAggregate');

fprintf('TSFSB_SUBSET_RUNNER_OK\n');

end
