function run_production_verification(workspace, stage)
%RUN_PRODUCTION_VERIFICATION Run one isolated production-migration gate.

restoredefaultpath;
candidate = fullfile(workspace, 'candidate');
experiment = '/home/lhtian97/Work/bds_gradient_threshold_20261030';
bundle = '/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8';
opti = fullfile(bundle, 'optiprofiler', 'matlab', 'optiprofiler');
addpath(opti, fullfile(opti, 'src'), fullfile(opti, 'problem_libs'), ...
    fullfile(opti, 'problem_libs', 's2mpj'), fullfile(bundle, 'helpers'), ...
    fullfile(experiment, 'reference', 'mp'), ...
    fullfile(candidate, 'tests'), fullfile(candidate, 'examples'), fullfile(candidate, 'src'));
assert(strcmp(which('bds'), fullfile(candidate, 'src', 'bds.m')));
assert(strcmp(version('-release'), '2026a'));
folder = fullfile(workspace, 'results', stage);
assert(~isfolder(folder));
try
    switch regexprep(stage, '_retry[0-9]+$', '')
        case 'focused'
            mkdir(folder);
            verify_gradient_stopping_threshold();
            verify_gradient_estimate_validity();
            verify_gradient_stop_no_extra_evaluations();
            verify_bds_without_acceleration_reference();
            summary.completed = true;
        case 'regression'
            mkdir(folder);
            run_bds_regression_suite();
            summary.completed = true;
        case 'mp_strict_gradient_off'
            mkdir(folder);
            summary = verify_bds_mp_reference(folder, 'full', false);
        case {'matrix', 's2mpj'}
            summary = verify_gradient_threshold_candidate(fullfile(experiment, 'candidate', 'src'), ...
                folder, regexprep(stage, '_retry[0-9]+$', ''));
        otherwise
            error('Unknown verification stage: %s', stage);
    end
    save(fullfile(folder, 'stage_summary.mat'), 'summary');
    fprintf('PRODUCTION_GRADIENT_STAGE_OK %s\n', stage);
catch exception
    if ~isfolder(folder), mkdir(folder); end
    save(fullfile(folder, 'failure.mat'), 'exception');
    fprintf(2, '%s\n', getReport(exception, 'extended', 'hyperlinks', 'off'));
    rethrow(exception);
end
end
