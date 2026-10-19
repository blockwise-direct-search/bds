function summary = verify_bds_mp_phase(reference_phase)
%VERIFY_BDS_MP_PHASE Exercise production post-poll semantics and optionally an oracle.
%
%   VERIFY_BDS_MP_PHASE() checks explicit MP branch expectations without an
%   external dependency. VERIFY_BDS_MP_PHASE(@C03_PHASE_MP) additionally compares
%   the complete state and every objective call against the frozen MP bridge.
%   This verifier lives beside BDS to use normal MATLAB private visibility.

if nargin < 1
    reference_phase = [];
end
summary = struct('passed', 0, 'reference_compared', 0);
for scenario = 1:20
    configuration = struct('use_iteration_pattern_step', true, ...
        'use_momentum_extrapolation', true, 'use_productive_direction_memory', true, ...
        'momentum_decay', 0.6, 'productive_direction_memory_size', 5, ...
        'step_floor', 1e-6, 'MaxFunctionEvaluations', 20, ...
        'ftarget', -Inf, 'output_xhist', true);
    initial_state = struct('xbase', [0;0], 'fbase', 10, 'nf', 0, 'fhist', [], ...
        'xhist', zeros(2,0), 'invalid_points', zeros(2,0), ...
        'productive_direction_memory', struct('direction', {}, 'step', {}), ...
        'momentum', [0;1]);
    values = [9,11];
    expected_count = 2;
    error_at = 0;
    switch scenario
        case 2
            values = [11,9,11]; expected_count = 3;
        case 3
            values = [11,11];
        case 4
            initial_state.momentum = [1;0]; values = 11; expected_count = 1;
        case 5
            configuration.MaxFunctionEvaluations = 1; values = 11; expected_count = 1;
        case 6
            configuration.ftarget = 9; values = 9; expected_count = 1;
        case 7
            configuration.use_productive_direction_memory = false;
        case 8
            values = [NaN,11];
        case 9
            initial_state.momentum = [-2/3;0]; values = 11; expected_count = 1;
        case 10
            configuration.use_momentum_extrapolation = false;
        case 11
            configuration.use_iteration_pattern_step = false;
        case 12
            configuration.use_momentum_extrapolation = false;
            configuration.use_iteration_pattern_step = false;
            expected_count = 0;
        case 13
            values = [Inf,9,11]; expected_count = 3;
        case 14
            values = [NaN,9,11]; error_at = 1; expected_count = 3;
        case 15
            configuration.MaxFunctionEvaluations = 2; values = [9,8];
        case 16
            configuration.MaxFunctionEvaluations = 0; expected_count = 0;
        case 17
            values = [9,8,7]; expected_count = 3;
        case 18
            configuration.output_xhist = false; values = [NaN,11];
        case 19
            values = [-Inf]; expected_count = 1;
        case 20
            configuration.ftarget = 9; values = [11,9];
    end
    count = 0; points = {};
    [candidate, succeeded, target] = run_post_poll_acceleration_phase( ...
        @objective, initial_state, configuration, [1;0]);
    candidate_points = points;
    assert(count == expected_count && candidate.nf == expected_count, ...
        'verify_bds_mp_phase:Count', 'Wrong evaluation count in scenario %d.', scenario);
    if configuration.use_momentum_extrapolation
        expected_momentum = 0.6 * initial_state.momentum + (1.0 - 0.6) * [1;0];
        assert(isequal(candidate.momentum, expected_momentum));
    else
        assert(isequal(candidate.momentum, initial_state.momentum));
    end
    if scenario == 1 || scenario == 2
        momentum = [1.0 - 0.6; 0.6];
        assert(isequal(candidate_points{1}, momentum / norm(momentum)));
        assert(succeeded && ~target);
        if scenario == 2
            assert(isequal(candidate_points{2}, [1;0]));
        end
    end
    if scenario == 7
        assert(isempty(candidate.productive_direction_memory));
    elseif scenario == 1
        assert(numel(candidate.productive_direction_memory) == 1);
    end
    if any(scenario == [6,19,20])
        assert(target && succeeded);
    end
    if ~isempty(reference_phase)
        count = 0; points = {};
        [reference, reference_succeeded, reference_target] = reference_phase( ...
            @objective, initial_state, configuration, [1;0]);
        assert(isequaln(candidate, reference) && isequaln(candidate_points, points) ...
            && succeeded == reference_succeeded && target == reference_target, ...
            'verify_bds_mp_phase:ReferenceMismatch', 'Scenario %d differs.', scenario);
        summary.reference_compared = summary.reference_compared + 1;
    end
    summary.passed = summary.passed + 1;
end
fprintf('BDS_MP_PHASE_OK: %d cases, %d frozen-reference comparisons.\n', ...
    summary.passed, summary.reference_compared);

    function value = objective(x)
        count = count + 1;
        points{count} = x;
        assert(count <= numel(values), 'verify_bds_mp_phase:ExtraEvaluation', ...
            'Unexpected objective call.');
        if count == error_at
            error('verify_bds_mp_phase:ObjectiveFailure', 'Intentional objective failure.');
        end
        value = values(count);
    end

end
