function run_bds_mp_verification(workspace, stage)
%RUN_BDS_MP_VERIFICATION Isolated server runner; never calls experiment setup.

restoredefaultpath;
candidate = fullfile(workspace, 'candidate');
reference = fullfile(workspace, 'reference', 'mp');
c06 = '/home/lhtian97/Work/c06_pure_internal_20261015/bundle_r1';
opti = fullfile(c06, 'optiprofiler', 'matlab', 'optiprofiler');
addpath(fullfile(candidate, 'src'), fullfile(candidate, 'tests'), ...
    fullfile(candidate, 'examples'), reference);
addpath(opti, fullfile(opti, 'problem_libs'), ...
    fullfile(opti, 'problem_libs', 's2mpj'), fullfile(opti, 'src'));
assert(strcmp(which('bds'), fullfile(candidate, 'src', 'bds.m')));
assert(strcmp(which('c03_bds_mp'), fullfile(reference, 'c03_bds_mp.m')));
assert(strcmp(which('s2mpj_load'), fullfile(opti, 'problem_libs', 's2mpj', 's2mpj_load.m')));
disp(which('bds', '-all'));
disp(which('c03_bds_mp', '-all'));
disp(which('s2mpj_load', '-all'));
assert(strcmp(version('-release'), '2026a'));
result_directory = fullfile(workspace, 'results', stage);
assert(~isfolder(result_directory), 'run_bds_mp_verification:ExistingResults', ...
    'Refusing to overwrite results: %s', result_directory);
mkdir(result_directory);
try
    switch regexprep(stage, '_retry[0-9]+$', '')
        case 'smoke'
            frozen = load(fullfile(workspace, 'results', 'frozen_options.mat'));
            for experiment_cell = {'internal', 'external'}
                experiment = experiment_cell{1};
                actual = bds_paper_options([1;2], experiment, 'mp');
                expected = frozen.([experiment, '_options']);
                assert(~expected.use_productive_direction_memory);
                assert(expected.productive_direction_memory_size == 2);
                expected = rmfield(expected, ...
                    {'use_productive_direction_memory', 'productive_direction_memory_size'});
                assert(strcmp(func2str(actual.forcing_function), func2str(expected.forcing_function)));
                assert(isequaln(rmfield(actual, 'forcing_function'), rmfield(expected, 'forcing_function')));
            end
            verify_bds_removed_retained_options();
            summary.defaults = verify_bds_mp_defaults(@c03_bds_mp, result_directory);
            mkdir(fullfile(result_directory, 'iseqiv'));
            summary.iseqiv = verify_bds_mp_reference(fullfile(result_directory, 'iseqiv'), 'smoke');
            mkdir(fullfile(result_directory, 'manifest'));
            summary.manifest = verify_bds_mp_manifest(fullfile(c06, 'problem_manifest.mat'), ...
                fullfile(result_directory, 'manifest'), 'smoke');
        case 'deliberate_failure'
            verify_iseqiv_noninteractive_failure(result_directory);
        case 'strict'
            summary = verify_bds_mp_reference(result_directory, 'full');
        case 'manifest'
            summary = verify_bds_mp_manifest(fullfile(c06, 'problem_manifest.mat'), result_directory, 'full');
        case 'manifest_internal'
            summary = verify_bds_mp_manifest(fullfile(c06, 'problem_manifest.mat'), result_directory, 'internal');
        case 'manifest_external'
            summary = verify_bds_mp_manifest(fullfile(c06, 'problem_manifest.mat'), result_directory, 'external');
        case 'regression'
            run_bds_regression_suite();
            summary.completed = true;
        otherwise
            error('run_bds_mp_verification:UnknownStage', 'Unknown stage: %s', stage);
    end
    save(fullfile(result_directory, 'stage_summary.mat'), 'summary');
    fprintf('BDS_MP_STAGE_COMPLETED %s\n', stage);
catch exception
    save(fullfile(result_directory, 'failure.mat'), 'exception');
    fprintf(2, '%s\n', getReport(exception, 'extended', 'hyperlinks', 'off'));
    rethrow(exception);
end

end
