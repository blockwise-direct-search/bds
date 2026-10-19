function summary = verify_bds_mp_defaults(reference_solver, result_directory)
%VERIFY_BDS_MP_DEFAULTS Check default switches, explicit variants, and raw traces.
%
%   Without arguments this is a dependency-free regression test. With a frozen
%   reference handle, every explicit switch/stopping combination is also checked
%   against that solver, including retained memory, row inputs, and noisy or
%   invalid objectives. These objectives are stress fixtures, not paper noise.

if nargin < 1
    reference_solver = [];
end
if nargin < 2
    result_directory = tempdir;
end
original_random_state = rng();
cleanup = onCleanup(@() rng(original_random_state));
rng(12345);
random_state = rng();
summary = struct('defaults_passed', 0, 'reference_passed', 0, 'retained_observed', false);
for n = [1,3,7]
    x0 = (1:n)' / 3;
    options = struct('seed', 12345, 'output_xhist', true, ...
        'output_alpha_hist', true, 'output_block_hist', true, 'output_grad_hist', true);
    implicit = record_bds_execution(@bds, @objective, x0, options, random_state);
    options.use_productive_direction_memory = false;
    options.use_iteration_pattern_step = true;
    options.use_momentum_extrapolation = true;
    explicit = record_bds_execution(@bds, @objective, x0, options, random_state);
    assert(isequaln(implicit, explicit), 'Default switches differ from explicit MP.');
    summary.defaults_passed = summary.defaults_passed + 1;
end
if ~isempty(reference_solver)
    n = 3;
    for switches = 0:7
        for stops = 0:3
            for kind = 1:4
                x0 = (1:n)' / 3;
                if mod(kind,2) == 0
                    x0 = x0';
                end
                options = bds_paper_options(x0, 'external', 'mp');
                options.use_productive_direction_memory = logical(bitget(switches,1));
                options.use_iteration_pattern_step = logical(bitget(switches,2));
                options.use_momentum_extrapolation = logical(bitget(switches,3));
                options.use_function_value_stop = logical(bitget(stops,1));
                options.use_estimated_gradient_stop = logical(bitget(stops,2));
                options.output_xhist = true;
                options.output_alpha_hist = true;
                options.output_block_hist = true;
                options.output_grad_hist = true;
                candidate = record_bds_execution(@bds, @stress_objective, x0, options, random_state);
                reference = record_bds_execution(reference_solver, @stress_objective, x0, options, random_state);
                save(fullfile(result_directory, sprintf('switches-%d-stops-%d-kind-%d.mat', ...
                    switches, stops, kind)), 'candidate', 'reference', 'options', 'x0', 'random_state');
                assert(isequaln(candidate, reference), ...
                    'verify_bds_mp_defaults:Mismatch', 'Switches=%d stops=%d kind=%d.', switches, stops, kind);
                summary.reference_passed = summary.reference_passed + 1;
                if switches == 1 && stops == 0 && kind == 1
                    options.use_productive_direction_memory = false;
                    without_retained = record_bds_execution(@bds, @stress_objective, x0, options, random_state);
                    summary.retained_observed = ~isequaln(candidate.points, without_retained.points);
                end
            end
        end
    end
    assert(summary.retained_observed, 'Retained compatibility fixture did not exercise memory.');
end
fprintf('BDS_MP_DEFAULTS_OK: defaults=%d reference=%d retained_observed=%d\n', ...
    summary.defaults_passed, summary.reference_passed, summary.retained_observed);

    function value = objective(x)
        value = sum((diag(1:n) * (x(:) - 0.27)).^2) + 0.01 * sum(sin(x(:)));
    end

    function value = stress_objective(x)
        value = objective(x);
        if kind == 2
            value = value * (1 + 0.01 * randn());
        elseif kind == 3 && x(1) > 0.5
            value = NaN;
        elseif kind == 4
            if x(1) > 0.5
                error('verify_bds_mp_defaults:ObjectiveFailure', 'Intentional failure.');
            elseif x(1) < -0.5
                value = Inf;
            end
        end
    end

end
