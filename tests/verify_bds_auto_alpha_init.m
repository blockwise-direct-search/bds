function verify_bds_auto_alpha_init()
%VERIFY_BDS_AUTO_ALPHA_INIT Check automatic steps for every block layout.

tests_dir = fileparts(mfilename('fullpath'));
root_dir = fileparts(tests_dir);
old_path = path();
cleanup = onCleanup(@() path(old_path));
addpath(fullfile(root_dir, 'src'));

x0 = [0; 2; -3; 1e-8];
coordinate_tolerance = 1e-6;
expected_coordinate_alpha = [1; 2; 3; 1e-6];
candidate_coordinate_alpha = auto_alpha_init_candidate( ...
    x0, coordinate_tolerance, 1, 1);
assert(isequal(candidate_coordinate_alpha, expected_coordinate_alpha), ...
    'The test-only (1,1) candidate no longer implements the frozen rule.');

verify_auto_matches_numeric('default-coordinate-blocks', x0, ...
    coordinate_tolerance, expected_coordinate_alpha, struct(), false);

vector_tolerance = [2; 1e-6; 1e-2; 1e-10];
expected_vector_alpha = [2; 2; 3; 1e-8];
verify_auto_matches_numeric('coordinate-block-vector-tolerance', x0, ...
    vector_tolerance, expected_vector_alpha, struct(), false);

single_block_options = struct('num_blocks', 1, 'batch_size', 1);
verify_auto_matches_numeric('single-block', x0, coordinate_tolerance, 3, ...
    single_block_options, true);

two_block_options = struct('num_blocks', 2, 'batch_size', 2);
verify_auto_matches_numeric('two-balanced-blocks', x0, ...
    coordinate_tolerance, [2; 3], two_block_options, true);

custom_block_options = struct( ...
    'num_blocks', 2, ...
    'batch_size', 2, ...
    'grouped_direction_indices', {{[1, 4], [2, 3]}}, ...
    'direction_set', [1, 1, 0, 0; 0, 1, 1, 0; 0, 0, 1, 1; 0, 0, 0, 1]);
verify_auto_matches_numeric('custom-nonconsecutive-blocks', x0, ...
    [0.5; 2.5], [1; 3], custom_block_options, false);

direct_search_options = struct('Algorithm', 'ds');
verify_auto_matches_numeric('Algorithm-ds', x0, coordinate_tolerance, 3, ...
    direct_search_options, false);

fprintf('BDS_AUTO_ALPHA_INIT_OK\n');
clear cleanup

end

function verify_auto_matches_numeric(label, x0, StepTolerance, ...
        expected_alpha, block_options, verify_acceleration_activity)

acceleration_switches = logical([ ...
    0, 0, 0; ...
    1, 0, 0; ...
    0, 1, 0; ...
    0, 0, 1; ...
    1, 1, 1]);
acceleration_labels = { ...
    'all-off', ...
    'productive-memory-only', ...
    'iteration-pattern-only', ...
    'momentum-only', ...
    'all-on'};
auto_results = cell(size(acceleration_labels));

for i = 1:size(acceleration_switches, 1)
    auto_result = run_solver('auto', acceleration_switches(i, :), x0, ...
        StepTolerance, block_options);
    auto_results{i} = auto_result;
    numeric_result = run_solver( ...
        expected_alpha, acceleration_switches(i, :), x0, ...
        StepTolerance, block_options);
    assert(isequaln(auto_result, numeric_result), ...
        ['The public auto path differs from the equivalent numeric path ', ...
        'for %s with acceleration configuration %s.'], ...
        label, acceleration_labels{i});
    assert(isequal(auto_result.output.alpha_hist(:, 1), expected_alpha(:)), ...
        ['The public auto path produced unexpected initial steps for %s ', ...
        'with acceleration configuration %s.'], ...
        label, acceleration_labels{i});
end

if verify_acceleration_activity
    for i = 2:numel(auto_results)
        assert(~isequaln( ...
            auto_results{1}.output.xhist, auto_results{i}.output.xhist), ...
            ['Acceleration configuration %s did not change the evaluated ', ...
            'point history for focused block layout %s.'], ...
            acceleration_labels{i}, label);
    end
end

end

function result = run_solver(alpha_init, acceleration_switches, x0, ...
        StepTolerance, block_options)

options = struct();
options.MaxFunctionEvaluations = 80;
options.StepTolerance = StepTolerance;
options.alpha_init = alpha_init;
options.seed = 0;
options.use_productive_direction_memory = acceleration_switches(1);
options.use_iteration_pattern_step = acceleration_switches(2);
options.use_momentum_extrapolation = acceleration_switches(3);
options.use_function_value_stop = false;
options.use_estimated_gradient_stop = false;
options.output_xhist = true;
options.output_alpha_hist = true;
options.output_block_hist = true;

block_option_names = fieldnames(block_options);
for i = 1:numel(block_option_names)
    option_name = block_option_names{i};
    options.(option_name) = block_options.(option_name);
end

[result.x, result.f, result.exitflag, result.output] = ...
    bds(@focused_objective, x0, options);

end

function f = focused_objective(x)

x = x(:);
target = [1; -1; 0.5; 2];
A = diag([1, 2, 3, 4]) + 0.05 * ones(4);
f = sum((A * (x - target)).^2) + 0.01 * sum(sin(x));

end
