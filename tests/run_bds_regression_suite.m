function run_bds_regression_suite()
%RUN_BDS_REGRESSION_SUITE Run the maintained BDS regression checks.
%
%   RUN_BDS_REGRESSION_SUITE() is the single entry point for the tests that
%   guard production BDS behavior. It runs the source-level unit tests, the
%   standalone tests under TESTS, the focused acceleration and stopping
%   checks, and the complete acceleration equivalence comparison.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
old_path = path();
old_folder = pwd();
cleanup = onCleanup(@() restore_environment(old_path, old_folder));

addpath(fullfile(root_dir, 'src'));
addpath(tests_dir);
cd(tests_dir);

unit_test_files = { ...
    fullfile(root_dir, 'src', 'unit_test.m'), ...
    fullfile(tests_dir, 'test_iseqiv_row_input.m'), ...
    fullfile(tests_dir, 'test_iseqiv_seed.m'), ...
    fullfile(tests_dir, 'test_scalar_function.m')};

for i = 1:numel(unit_test_files)
    results = runtests(unit_test_files{i});
    assert(~isempty(results) && all([results.Passed]), ...
        'BDS:RegressionSuiteUnitTestFailure', ...
        'At least one test failed in %s.', unit_test_files{i});
end

focused_verifiers = { ...
    @verify_bds_auto_alpha_init, ...
    @verify_bds_momentum_duplicate, ...
    @verify_bds_without_acceleration_reference, ...
    @verify_function_value_reference, ...
    @verify_gradient_estimate_validity, ...
    @verify_gradient_stop_no_extra_evaluations, ...
    @verify_gradient_stopping_threshold};

for i = 1:numel(focused_verifiers)
    focused_verifiers{i}();
end

verify_bds_acceleration();

fprintf('\nBDS_REGRESSION_SUITE_OK\n');
clear cleanup

end

function restore_environment(old_path, old_folder)

path(old_path);
cd(old_folder);

end
