function options = tsfsb_direct_profile_options(solver_indices)
%TSFSB_DIRECT_PROFILE_OPTIONS Fixed public OptiProfiler plotting options.
%
%   Ported from the C02 c02_direct_profile_options.m (commit 846d5c5f),
%   adapted to the ten-solver TSFSB pool.

spec = tsfsb_benchmark_spec();
if nargin < 1
    solver_indices = 1:numel(spec.pool);
end
if ~(isnumeric(solver_indices) && isvector(solver_indices) ...
        && all(isfinite(solver_indices)) ...
        && all(solver_indices == floor(solver_indices)) ...
        && all(solver_indices >= 1) ...
        && all(solver_indices <= numel(spec.pool)) ...
        && numel(unique(solver_indices)) == numel(solver_indices))
    error('tsfsb_direct_profile_options:InvalidSolverIndices', ...
        'solver_indices must contain unique valid canonical solver indices.');
end

options = struct();
options.draw_hist_plots = 'none'; % Profiles only; retain all raw histories.
options.solver_names = {spec.pool(solver_indices).display_name};
options.line_colors = spec.line_colors(solver_indices, :);
options.line_styles = spec.line_styles(solver_indices);
options.line_widths = spec.line_widths(solver_indices);
options.max_tol_order = spec.maximum_tolerance_order;
options.errorbar_type = 'minmax';
options.semilogx = true;
options.summarize_performance_profiles = true;
options.summarize_data_profiles = false;
options.summarize_log_ratio_profiles = false;
options.summarize_output_based_profiles = true;

end
