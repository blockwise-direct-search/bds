function verify_bds_rolling_switches()
%VERIFY_BDS_ROLLING_SWITCHES The public switch controls both searches.
options = struct('seed', 42, 'MaxFunctionEvaluations', 4, 'output_xhist', true);
fun = @(x) (x - 1)^2;
options.use_search_acceleration = true;
[~, ~, ~, accelerated] = bds(fun, 0, options);
options.use_search_acceleration = false;
[~, ~, ~, polling] = bds(fun, 0, options);
assert(isequal(accelerated.xhist, [0, 1, 2, 3]));
assert(~isequal(accelerated.xhist, polling.xhist));
fprintf('BDS_ROLLING_SWITCHES_OK\n');
end
