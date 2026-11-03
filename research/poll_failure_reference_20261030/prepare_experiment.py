"""Generate an isolated instrumented solver; never edit production or an oracle."""
import hashlib
import json
from pathlib import Path
import shutil
import sys

workspace = Path(sys.argv[1]).resolve()
source = workspace / 'candidate/src'
target = workspace / 'experiment'
assert source.is_dir() and not target.exists()
target.mkdir()
shutil.copytree(source / 'private', target / 'private')
code = (source / 'bds.m').read_text()

def replace_once(old, new):
    global code
    assert code.count(old) == 1, old
    code = code.replace(old, new, 1)

replace_once('= bds(fun, x0, options)', '= gradient_experiment_bds(fun, x0, options, experiment)')
replace_once('lipschitz_constant = options.lipschitz_constant;', '''lipschitz_constant = options.lipschitz_constant;
experiment_state = struct('reference', nan, 'window', nan(1, experiment.window));
experiment_poll_failures = 0;
experiment_previous_gradient = [];
experiment_previous_point = [];''')
replace_once('    iteration_step = xbase - xbase_iteration_start;', '''    iteration_step = xbase - xbase_iteration_start;
    % Count complete unsuccessful polling iterations, not missing gradients.
    experiment_poll_failed = ~terminate && all(batch_gradient_available);
    if experiment_poll_failed
        assert(isequal(xbase, xbase_iteration_start) && fbase == fbase_iteration_start);
        experiment_poll_failures = experiment_poll_failures + 1;
    else
        experiment_poll_failures = 0;
    end''')
replace_once('    % Track the best function value observed among the latest func_window_size iterations.', '''    experiment_gradient_norm = nan;
    experiment_error_scale = nan;
    experiment_legacy_error = nan;
    experiment_consistency = inf;
    % Track the best function value observed among the latest func_window_size iterations.''')
replace_once('    if use_function_value_stop && ~post_poll_acceleration_succeeded ...', '''    experiment_function_hit = false;
    if ~post_poll_acceleration_succeeded && isfinite(reference_function_value) ...
            && all(isfinite(fopt_window))
        experiment_change = max(fopt_window) - min(fopt_window);
        experiment_function_hit = ...
            experiment_change < func_tol * min(1, abs(fopt - reference_function_value)) ...
            || experiment_change < 1e-3 * func_tol * max(1, abs(fopt - reference_function_value));
    end
    if use_function_value_stop && ~post_poll_acceleration_succeeded ...''')
replace_once('            if use_estimated_gradient_stop\n', '''            % Observations do not evaluate the objective or consume the solver RNG.
            experiment_rng = rng();
            experiment_error_scale = get_gradient_error_bound( ...
                grad_info.step_size_per_block, batch_size, grouped_direction_indices, n, ...
                positive_direction_set, direction_selection_probability_matrix, 1);
            experiment_legacy_error = get_gradient_error_bound( ...
                grad_info.step_size_per_block, batch_size, grouped_direction_indices, n, ...
                positive_direction_set, direction_selection_probability_matrix, 1e3);
            rng(experiment_rng);
            experiment_gradient_norm = norm(grad);
            if ~isempty(experiment_previous_gradient) && isequal(xbase, experiment_previous_point)
                experiment_consistency = norm(grad - experiment_previous_gradient) ...
                    / max([1, norm(grad), norm(experiment_previous_gradient)]);
            end
            experiment_previous_gradient = grad;
            experiment_previous_point = xbase;

            if use_estimated_gradient_stop && ~strcmp(experiment.rule, 'legacy')
                [experiment_state, experiment_stop] = gradient_stop_update( ...
                    experiment_state, experiment_gradient_norm, ...
                    experiment_error_scale, experiment_consistency, experiment, experiment_poll_failures);
                if experiment_stop
                    terminate = true;
                    exitflag = get_exitflag("SMALL_ESTIMATE_GRADIENT");
                end
            elseif use_estimated_gradient_stop
''')
replace_once('    % Terminate the computations if terminate is true.', '''    experiment.observe(iter, nf, xopt, experiment_function_hit, ...
        experiment_gradient_norm, experiment_error_scale, experiment_consistency, ...
        experiment_legacy_error, experiment_poll_failed, experiment_poll_failures);
    % Terminate the computations if terminate is true.''')
(target / 'gradient_experiment_bds.m').write_text(code)
manifest = {}
for folder in ['candidate/src', 'candidate/examples', 'control', 'experiment']:
    for path in sorted((workspace / folder).rglob('*')):
        if path.is_file():
            manifest[str(path.relative_to(workspace))] = hashlib.sha256(path.read_bytes()).hexdigest()
(workspace / 'CONTROL_MANIFEST.json').write_text(json.dumps(manifest, indent=2) + '\n')
print('Generated isolated solver; hashed files:', len(manifest))
