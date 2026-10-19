function verify_iseqiv_noninteractive_failure(failure_directory)
%VERIFY_ISEQIV_NONINTERACTIVE_FAILURE Deliberately fail; batch must exit nonzero.

p = struct('name', 'DELIBERATE_MISMATCH', 'x0', [1;2], ...
    'objective', @(x) sum(x.^2));
options = struct('seed', 12345, 'noninteractive', true, ...
    'failure_directory', failure_directory, 'sequential', false);
iseqiv({@first_solver, @second_solver}, p, 0, true, 0, options);
error('verify_iseqiv_noninteractive_failure:DidNotFail', ...
    'The deliberate mismatch was not detected.');

end

function [x, f, flag, output] = first_solver(~, x, ~)
f = 0;
flag = 0;
output = struct('funcCount', 1, 'fhist', 0);
end

function [x, f, flag, output] = second_solver(~, x, ~)
f = 1;
flag = 0;
output = struct('funcCount', 1, 'fhist', 1);
end
