function verify_lam_paper_exact()
%VERIFY_LAM_PAPER_EXACT Verify the published LAM and DF-Linesearch rules.
%
%   Ported from the C02 verifier of the same name (commit 846d5c5f), adapted
%   to the lam_paper_exact/lam_paper_exact_linesearch port in
%   tests/competitors. Keeps all 13 test classes of the C02 original.

    test_paper_parameters();
    test_positive_direction();
    test_negative_direction();
    test_two_sided_failure();
    test_non_strict_acceptance();
    test_successive_point_expansion();
    test_direction_memory();
    test_successful_pass_update();
    test_failed_pass_update();
    test_coupling_formula();
    test_budget_boundaries();
    test_target_adapter();
    test_nonfinite_values();
    fprintf('VERIFY_LAM_PAPER_EXACT_OK\n');

end

function test_non_strict_acceptance()

    initial_values = containers.Map({'0', '1'}, {1, 1 - 1e-6});
    initial_objective = @(x) table_value(initial_values, x);
    options.MaxFunctionEvaluations = 2;
    [x, f, exitflag] = lam_paper_exact(initial_objective, 0, options);
    assert(exitflag == -1);
    assert(x == 1 && f == 1 - 1e-6);

    expansion_values = containers.Map( ...
        {'0', '1', '2'}, {2, 1, 1 - 1e-6});
    expansion_objective = @(x) table_value(expansion_values, x);
    options.MaxFunctionEvaluations = 3;
    [x, f, exitflag] = lam_paper_exact(expansion_objective, 0, options);
    assert(exitflag == -1);
    assert(x == 2 && f == 1 - 1e-6);

end

function test_paper_parameters()

    options.MaxFunctionEvaluations = 1;
    [~, ~, ~, output] = lam_paper_exact(@(x) sum(x.^2), zeros(2, 1), options);
    parameters = output.paperParameters;
    assert(parameters.coupling == 1e-10);
    assert(parameters.theta == 0.5);
    assert(parameters.delta == 0.5);
    assert(parameters.gamma == 1e-6);
    assert(parameters.initialTentativeStep == 1);

end

function test_positive_direction()

    options.MaxFunctionEvaluations = 2;
    [x, f, exitflag, output] = lam_paper_exact(@(x) (x - 2).^2, 0, options);
    assert(exitflag == -1);
    assert(x == 1 && f == 1);
    assert(output.funcCount == 2);
    assert(isequal(output.xhist, [0, 1]));
    assert(output.directionSigns == 1);

end

function test_negative_direction()

    options.MaxFunctionEvaluations = 3;
    [x, f, exitflag, output] = lam_paper_exact(@(x) (x + 2).^2, 0, options);
    assert(exitflag == -1);
    assert(x == -1 && f == 1);
    assert(output.funcCount == 3);
    assert(isequal(output.xhist, [0, 1, -1]));
    assert(output.directionSigns == -1);

end

function test_two_sided_failure()

    options.MaxFunctionEvaluations = 3;
    options.StepTolerance = 0.5;
    [x, f, exitflag, output] = lam_paper_exact(@(x) x.^2, 0, options);
    assert(exitflag == 0);
    assert(x == 0 && f == 0);
    assert(isequal(output.xhist, [0, 1, -1]));
    assert(output.alphaTilde == 0.5);

end

function test_successive_point_expansion()

    values = containers.Map( ...
        {'0', '1', '2', '4'}, {10, 8, 7.5, 9});
    objective = @(x) table_value(values, x);
    options.MaxFunctionEvaluations = 4;
    [x, f, exitflag, output] = lam_paper_exact(objective, 0, options);
    assert(exitflag == -1);
    assert(x == 2 && f == 7.5);
    assert(isequal(output.xhist, [0, 1, 2, 4]));
    assert(output.bestEvaluatedPoint == 2);

end

function test_direction_memory()

    values = containers.Map( ...
        {'0', '1', '-1', '-2'}, {10, 12, 8, 9});
    objective = @(x) table_value(values, x);
    options.MaxFunctionEvaluations = 5;
    [~, ~, exitflag, output] = lam_paper_exact(objective, 0, options);
    assert(exitflag == -1);
    assert(isequal(output.xhist, [0, 1, -1, -2, -2]));
    assert(output.directionSigns == -1);

end

function test_successful_pass_update()

    options.MaxFunctionEvaluations = 6;
    options.MaxIterations = 1;
    [x, f, exitflag, output] = lam_paper_exact(@(x) sum((x - 1).^2), ...
        zeros(2, 1), options);
    assert(exitflag == -2);
    assert(isequal(x, ones(2, 1)) && f == 0);
    assert(isequal(output.alphaTilde, ones(2, 1)));

end

function test_failed_pass_update()

    options.MaxFunctionEvaluations = 6;
    options.MaxIterations = 1;
    [x, f, exitflag, output] = lam_paper_exact(@(x) sum(x.^2), zeros(2, 1), options);
    assert(exitflag == -2);
    assert(isequal(x, zeros(2, 1)) && f == 0);
    assert(isequal(output.alphaTilde, 0.5 * ones(2, 1)));

end

function test_coupling_formula()

    stop_power = 37;
    objective = @(x) coupling_objective(x, stop_power);
    options.MaxFunctionEvaluations = stop_power + 6;
    options.MaxIterations = 1;
    [~, ~, exitflag, output] = lam_paper_exact(objective, zeros(2, 1), options);
    assert(exitflag == -2);
    assert(output.alphaTilde(1) == 2^stop_power);
    assert(output.nextAlphaBar(2) == 1e-10 * 2^stop_power);

end

function test_budget_boundaries()

    objective = @(x) sum((x - 2).^2);
    for budget = 1:8
        options.MaxFunctionEvaluations = budget;
        [~, ~, ~, output] = lam_paper_exact(objective, zeros(2, 1), options);
        assert(output.funcCount == budget);
        assert(numel(output.fhist) == budget);
        assert(size(output.xhist, 2) == budget);
        assert(all(isfinite(output.fhist)));
    end

end

function test_target_adapter()

    options.MaxFunctionEvaluations = 10;
    options.ftarget = 1;
    [x, f, exitflag, output] = lam_paper_exact(@(x) (x - 2).^2, 0, options);
    assert(exitflag == 1);
    assert(x == 1 && f == 1);
    assert(output.funcCount == 2);

end

function test_nonfinite_values()

    options.MaxFunctionEvaluations = 5;
    [x, f, exitflag, output] = lam_paper_exact(@(~) NaN, 0, options);
    assert(exitflag == -3);
    assert(x == 0 && isnan(f));
    assert(output.funcCount == 1);

    objective = @(x) finite_only_at_origin(x);
    options.MaxFunctionEvaluations = 3;
    options.StepTolerance = 0.5;
    [x, f, exitflag, output] = lam_paper_exact(objective, 0, options);
    assert(exitflag == 0);
    assert(x == 0 && f == 0);
    assert(isequaln(output.fhist, [0, Inf, Inf]));

end

function value = table_value(values, x)

    key = sprintf('%.15g', x(1));
    if isKey(values, key)
        value = values(key);
    else
        value = 1e6 + sum(x.^2);
    end

end

function value = coupling_objective(x, stop_power)

    if x(2) ~= 0
        value = 1e100 + abs(x(2));
    elseif x(1) < 0
        value = 1e100 + abs(x(1));
    elseif x(1) == 0
        value = 0;
    elseif x(1) <= 2^stop_power
        value = -x(1)^2;
    else
        value = 1e100 + x(1);
    end

end

function value = finite_only_at_origin(x)

    if x == 0
        value = 0;
    else
        value = Inf;
    end

end
