function tests = unit_test
%   UNIT_TEST runs all the test functions in this file.
%   To run these tests, simply type "Run Tests" in the command window.
%   To create a new test function in this file with a name that starts or
%   finishes with "test" (case insensitive). For more info, see
%
%   https://www.mathworks.com/help/matlab/matlab_prog/write-simple-test-case-with-functions.html

tests = functiontests(localfunctions);

end

function cycling_test(testcase)
%CYCLING_TEST tests the file private/cycling.m.

array = [1, 2, 3, 4, 5];
% When index < 0, the array should remain unchanged.
for strategy = 0:3
    verifyEqual(testcase, cycling(array, -1, strategy), array)
end
% When strategy == 0, the array should remain unchanged.
for index = 1:length(array)
    verifyEqual(testcase, cycling(array, index, 0), array)
end

% For the 'strategy' parameter, possible values are 1, 2, or 3. All cases are tested below.
array = [1, 2, 3, 4, 5];
verifyEqual(testcase, cycling(array, 3, 0), [1, 2, 3, 4, 5])
verifyEqual(testcase, cycling(array, 3, 1), [3, 1, 2, 4, 5])
verifyEqual(testcase, cycling(array, 3, 2), [3, 4, 5, 1, 2])
verifyEqual(testcase, cycling(array, 3, 3), [4, 5, 1, 2, 3])

array = [2, 1, 4, 5, 3];
verifyEqual(testcase, cycling(array, 3, 0), [2, 1, 4, 5, 3])
verifyEqual(testcase, cycling(array, 3, 1), [4, 2, 1, 5, 3])
verifyEqual(testcase, cycling(array, 3, 2), [4, 5, 3, 2, 1])
verifyEqual(testcase, cycling(array, 3, 3), [5, 3, 2, 1, 4])

end

function divide_direction_set_test(testcase)
%DIVIDE_DIRECTION_SET_TEST tests the file private/divide_direction_set.m.

% Test the case where n cannot be divided by nb.
n = 11;
nb = 3;
index_direction_set = cell(1,nb);
index_direction_set{1} = [1 2 3 4 5 6 7 8];
index_direction_set{2} = [9 10 11 12 13 14 15 16];
index_direction_set{3} = [17 18 19 20 21 22];

verifyEqual(testcase, divide_direction_set(n, nb), index_direction_set)

n = 10;
nb = 3;
index_direction_set = cell(1,nb);
index_direction_set{1} = [1 2 3 4 5 6 7 8];
index_direction_set{2} = [9 10 11 12 13 14];
index_direction_set{3} = [15 16 17 18 19 20];

verifyEqual(testcase, divide_direction_set(n, nb), index_direction_set)

% Test the case where n can be divided by nb.
n = 15;
nb = 3;
index_direction_set = cell(1,nb);
index_direction_set{1} = [1 2 3 4 5 6 7 8 9 10];
index_direction_set{2} = [11 12 13 14 15 16 17 18 19 20];
index_direction_set{3} = [21 22 23 24 25 26 27 28 29 30];

verifyEqual(testcase, divide_direction_set(n, nb), index_direction_set)

% Test the case where n is equal to nb.
n = 3;
nb = 3;
index_direction_set = cell(1,nb);
index_direction_set{1} = [1 2];
index_direction_set{2} = [3 4];
index_direction_set{3} = [5 6];

verifyEqual(testcase, divide_direction_set(n, nb), index_direction_set)

% Test the case where options.grouped_direction_indices is provided.
n = 11;
nb = 3;
options.grouped_direction_indices = {[1 3 5 7], [2 4 8], [6 9 10 11]};
index_direction_set = cell(1,nb);
index_direction_set{1} = [1 2 5 6 9 10 13 14];
index_direction_set{2} = [3 4 7 8 15 16];
index_direction_set{3} = [11 12 17 18 19 20 21 22];

verifyEqual(testcase, divide_direction_set(n, nb, options), index_direction_set)

end

function output = eval_fun_tmp(x)
if length(x) <= 100
    output = nan;
elseif length(x) <= 200
    output = inf;
elseif length(x) <= 300
    output = 1e30;
else
    error('The length of x is too large.');
end
end

function eval_fun_test(testcase)
%EVAL_FUN_TEST tests the file private/eval_fun.m.

n = randi([1, 100]);
x = randn(n, 1);
f_return = inf;

% When eval_fun processes nan, it should be treated as an error, 
% and eval_fun should print a warning and return inf. The warning message is not checked here.
verifyEqual(testcase, eval_fun(@eval_fun_tmp, x), f_return);

n = randi([101, 200]);
x = randn(n, 1);
f_return = inf;

% When eval_fun processes inf, it should return inf without printing a warning, as inf is not 
% treated as an error.
verifyEqual(testcase, eval_fun(@eval_fun_tmp, x), f_return)

n = randi([201, 300]);
x = randn(n, 1);
f_return = 1e30;

% When eval_fun processes a value that is large such as 1e30, it should return the same value 
% without printing a warning, as it is not treated as an error.
verifyEqual(testcase, eval_fun(@eval_fun_tmp, x), f_return)

n = randi([301, 400]);
x = randn(n, 1);
f_return = inf;

% When eval_fun processes an error, it will print a warning and return 1e30.
% The warning message is not checked here.
verifyEqual(testcase, eval_fun(@eval_fun_tmp, x), f_return)

end

function get_default_constant_test(testcase)
%GET_DEFAULT_CONSTANT_TEST tests the file private/get_default_constant.m.
% The following tests verify the default values of parameters required by bds.
% Some code repetition is expected.
% The test order matches the parameter order in get_default_constant.m.
% If any test fails, it indicates that a default parameter value has been modified.

constant_name = "MaxFunctionEvaluations_dim_factor";
constant_value = 500;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "ftarget";
constant_value = -inf;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "StepTolerance";
constant_value = 1e-6;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "use_function_value_stop";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "func_window_size";
constant_value = 20;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "func_tol";
constant_value = 1e-6;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "use_estimated_gradient_stop";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "grad_window_size";
constant_value = 1;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "grad_tol";
constant_value = 1e-2;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "lipschitz_constant";
constant_value = 1e3;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "use_gradient_reference_consistency";
constant_value = true;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "grad_reference_finite_difference_error_tol";
constant_value = 1/30;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "block_visiting_pattern";
constant_value = "sorted";
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "alpha_init";
constant_value = 1;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "expand";
constant_value = 2.0;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "shrink";
constant_value = 0.5;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "expand_noisy";
constant_value = 1.5;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "shrink_noisy";
constant_value = 0.5;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "is_noisy";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

% To ensure that the forcing function is a function handle, we use func2str to compare the function handles.
assert(strcmp(func2str(get_default_constant("forcing_function")), func2str(@(alpha) alpha^2)));

constant_name = "reduction_factor";
constant_value = [0, eps, eps];
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "polling_inner";
constant_value = "opportunistic";
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "cycling_inner";
constant_value = 1;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "seed";
constant_value = "shuffle";
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "output_xhist";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "output_alpha_hist";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "output_block_hist";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "output_grad_hist";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "iprint";
constant_value = 0;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "debug_flag";
constant_value = false;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "productive_direction_memory_size_cap";
constant_value = 5;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "momentum_decay";
constant_value = 0.6;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "use_productive_direction_memory";
constant_value = true;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "use_iteration_pattern_step";
constant_value = true;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

constant_name = "use_momentum_extrapolation";
constant_value = true;
verifyEqual(testcase, get_default_constant(constant_name), constant_value)

end

function get_exitflag_test(testcase)
%GET_EXITFLAG_TEST tests the file private/get_exitflag.m.

information = "FTARGET_REACHED";
EXITFLAG = 0;
verifyEqual(testcase, get_exitflag(information), EXITFLAG)

information = "MAXFUN_REACHED";
EXITFLAG = 1;
verifyEqual(testcase, get_exitflag(information), EXITFLAG)

information = "MAXIT_REACHED";
EXITFLAG = 2;
verifyEqual(testcase, get_exitflag(information), EXITFLAG)

information = "SMALL_ALPHA";
EXITFLAG = 3;
verifyEqual(testcase, get_exitflag(information), EXITFLAG)

information = "SMALL_OBJECTIVE_CHANGE";
EXITFLAG = 4;
verifyEqual(testcase, get_exitflag(information), EXITFLAG)

information = "SMALL_ESTIMATE_GRADIENT";
EXITFLAG = 5;
verifyEqual(testcase, get_exitflag(information), EXITFLAG)

end

function set_options_test(testcase)
%SET_OPTIONS_TEST checks production option validation and public defaults.

n = 3;
x0 = zeros(n, 1);

options = struct();
options.StepTolerance = [1e-6, 1e-6];
verifyError(testcase, @() set_options(options, n, x0), ...
    'BDS:InvalidStepTolerance')

options.StepTolerance = [1e-6, 1e-6, 1e-6];
resolved = set_options(options, n, x0);
verifyEqual(testcase, resolved.MaxFunctionEvaluations, 500 * n)
verifyEqual(testcase, resolved.expand, 2.0)
verifyTrue(testcase, resolved.use_productive_direction_memory)
verifyTrue(testcase, resolved.use_iteration_pattern_step)
verifyTrue(testcase, resolved.use_momentum_extrapolation)

options.num_blocks = 2;
options.StepTolerance = [1e-6, 1e-6];
resolved = set_options(options, n, x0);
verifyEqual(testcase, resolved.StepTolerance, [1e-6; 1e-6])

end

function get_auto_alpha_init_test(testcase)
%GET_AUTO_ALPHA_INIT_TEST tests the automatic initial-step formula.

x0 = [0; 2; -3; 1e-8];
StepTolerance = 1e-6;
expected = [1; 1; 1.5; 5e-6];
actual = get_auto_alpha_init(x0, StepTolerance, 0.5, 5);
verifyEqual(testcase, actual, expected, ...
    'AbsTol', 2 * eps(max(abs(expected))))
verifyEqual(testcase, ...
    get_auto_alpha_init(-x0, StepTolerance, 0.5, 5), expected, ...
    'AbsTol', 2 * eps(max(abs(expected))))

vector_tolerance = [2; 1e-6; 1e-2; 1e-10];
expected = [10; 2; 3; 1e-8];
verifyEqual(testcase, ...
    get_auto_alpha_init(x0, vector_tolerance, 1, 5), expected, ...
    'AbsTol', 2 * eps(max(abs(expected))))

abs_x0 = abs(x0);
incumbent = max(abs_x0, StepTolerance);
incumbent(abs_x0 == 0) = 1;
incumbent = max(incumbent, StepTolerance);
verifyEqual(testcase, ...
    get_auto_alpha_init(x0, StepTolerance, 1, 1), incumbent, ...
    'AbsTol', 2 * eps(max(abs(incumbent))))

tiny_nonzero = get_auto_alpha_init(1e-12, StepTolerance, 0.5, 5);
exact_zero = get_auto_alpha_init(0, StepTolerance, 0.5, 5);
verifyEqual(testcase, tiny_nonzero, 5e-6, 'AbsTol', 2 * eps(5e-6))
verifyEqual(testcase, exact_zero, 1)

verifyError(testcase, ...
    @() get_auto_alpha_init(x0, StepTolerance, 0, 1), ...
    'BDS:get_auto_alpha_init:InvalidCoefficient')
verifyError(testcase, ...
    @() get_auto_alpha_init(x0, StepTolerance, Inf, 1), ...
    'BDS:get_auto_alpha_init:InvalidCoefficient')
verifyError(testcase, ...
    @() get_auto_alpha_init(realmax, 1, 2, 1), ...
    'BDS:get_auto_alpha_init:InvalidResult')

end

function alpha_init_option_regression_test(testcase)
%ALPHA_INIT_OPTION_REGRESSION_TEST locks non-auto option behavior.

x0 = [0; 2; -3];
base_options.MaxFunctionEvaluations = 1;
base_options.output_alpha_hist = true;

[~, ~, ~, output] = bds(@(x) sum(x.^2), x0, base_options);
verifyEqual(testcase, output.alpha_hist(:, 1), ones(3, 1))

scalar_options = base_options;
scalar_options.alpha_init = 2;
[~, ~, ~, output] = bds(@(x) sum(x.^2), x0, scalar_options);
verifyEqual(testcase, output.alpha_hist(:, 1), 2*ones(3, 1))

vector_options = base_options;
vector_options.alpha_init = [1; 2; 3];
[~, ~, ~, output] = bds(@(x) sum(x.^2), x0, vector_options);
verifyEqual(testcase, output.alpha_hist(:, 1), vector_options.alpha_init)

auto_options = base_options;
auto_options.alpha_init = 'auto';
[~, ~, ~, output] = bds(@(x) sum(x.^2), x0, auto_options);
verifyEqual(testcase, output.alpha_hist(:, 1), [1; 2; 3])

end

function direction_set_test(testcase)
%DIRECTION_SET_TEST tests the file private/get_direction_set.m.

% Set the random seed for reproducibility.
dt = datetime("now", "TimeZone", 'Asia/Shanghai');
yw = 100*mod(year(dt), 100) + week(dt);
rng(yw);

% If no options are provided and only the dimension n is given,
% get_direction_set(n) should return a block diagonal matrix with 1 and -1.
% The following code constructs the expected direction set D for a given n,
% where each row ii has 1 at position 2*ii-1 and -1 at position 2*ii.
n = randi([1,100]);
D = [zeros(n) zeros(n)];
for ii = 1:n
    D(ii, 2*ii-1) = 1;
    D(ii, 2*ii) = -1;
end
verifyEqual(testcase, get_direction_set(n), D)

% If options is provided but it is empty, get_direction_set(n, options) should 
% return the same result as above.
options = struct();
verifyEqual(testcase, get_direction_set(n, options), D)

n = randi([1000,2000]);
options = struct();
A = randn(n);
options.direction_set = A;
D = get_direction_set(n, options);
D_unique = D(:, 1:2:2*n-1);
% Note: In get_direction_set, It may remove columns that are too short. However, for a random matrix 
% with high dimensions, the probability of such case is negligible. According to 
% High-Dimensional Probability (Remark 3.2.5), independent random vectors 
% in high dimensions are almost surely orthogonal, so collinearity and linear dependence are not a 
% concern here. Another explanation for the low probability of collinearity is that the probability of 
% a random matrix having a zero determinant is essentially zero. This is because the determinant is a 
% polynomial function of the matrix entries, and the set of matrices with zero determinant forms a 
% lower-dimensional subset in the space of all matrices. As a result, the probability of randomly 
% selecting a matrix with zero determinant is zero.
% In get_direction_set, we sort the indices of vectors that are present in both the input matrix A and 
% the output matrix D. Although QR factorization with column pivoting is used to select a maximal linearly 
% independent subset, sorting these indices ensures that the order of the vectors in the output matrix D 
% is as consistent as possible with that in the input matrix A. This allows us to use isequal to verify 
% that the odd columns of D are identical to the input matrix A. Note that get_direction_set does not alter 
% the input matrix A unless collinearity, linear dependence, nan, Inf, or very short columns are present.
% As previously discussed, the probability of such cases is negligible for random matrices with large n.
% Therefore, we can reliably use isequal to confirm that the odd columns of D match the input matrix A.
% We also need to check whether the odd columns of D equal to the even columns of D with a negative
% sign. In general, checking for exact equality between floating-point matrices is not recommended
% due to numerical precision issues. However, in this case, we use strict equality to confirm that
% get_direction_set does not alter the input matrix, and the odd columns of D are indeed the negative
% of the even columns. In addition, we need to check whether the odd columns of D form a basis.
% To verify this, we can use the svd function to compute the rank of the matrix formed by the odd 
% columns of D.
if ~isequal(D_unique, A)
    error('The odd columns of D are not the same as the input matrix.');
end
if D(:, 1:2:2*n-1) ~= -D(:, 2:2:2*n)
    error('The directions in one block are not opposite.');
end
[~, S, ~] = svd(D_unique);
r = sum(abs(diag(S)) > 1e-10);
if r ~= n
    error('The odd columns of D is not a basis.');
end

% The following tests evaluate the behavior of get_direction_set when the input matrix consists 
% entirely of nan values. The expected behavior is that get_direction_set should return a block 
% diagonal matrix with 1 and -1.
n = randi([1,100]);
options.direction_set = nan(n, n);
D = [zeros(n) zeros(n)];
for ii = 1:n
    D(ii, 2*ii-1) = 1;
    D(ii, 2*ii) = -1;
end
verifyEqual(testcase, get_direction_set(n, options), D)

% The following tests evaluate the behavior of get_direction_set when the input matrix consists
% entirely of Inf values. The expected behavior is that get_direction_set should return a block 
% diagonal matrix with 1 and -1.
n = randi([1,100]);
options.direction_set = inf(n, n);
D = [zeros(n) zeros(n)];
for ii = 1:n
    D(ii, 2*ii-1) = 1;
    D(ii, 2*ii) = -1;
end
verifyEqual(testcase, get_direction_set(n, options), D)

% The following tests evaluate the behavior of get_direction_set when the input matrix consists 
% entirely of zeros. The expected behavior is that get_direction_set should return a block diagonal 
% matrix with 1 and -1.
n = randi([1,100]);
options.direction_set = zeros(n, n);
D = [zeros(n) zeros(n)];
for ii = 1:n
    D(ii, 2*ii-1) = 1;
    D(ii, 2*ii) = -1;
end
verifyEqual(testcase, get_direction_set(n, options), D)

% The following example is based on https://github.com/libprima/prima/blob/main/matlab/tests/testprima.m, 
% which is written by Zaikun Zhang.
function [f, g, H]=chrosen(x)
%CHROSEN calculates the function value, gradient, and Hessian of the
%   Chained Rosenbrock function.
%   See
%   [1] Toint (1978), 'Some numerical results using a sparse matrix
%   updating formula in unconstrained optimization'
%   [2] Powell (2006), 'The NEWUOA software for unconstrained
%   optimization without derivatives'

n=length(x);

alpha = 4;

f=0; % Function value
g=zeros(n,1); % Gradient
H=zeros(n,n); % Hessian

for i=1:n-1
    f = f + (x(i)-1)^2+alpha*(x(i)^2-x(i+1))^2;

    g(i)   = g(i) + 2*(x(i)-1)+alpha*2*(x(i)^2-x(i+1))*2*x(i);
    g(i+1) = g(i+1) - alpha*2*(x(i)^2-x(i+1));

    H(i,i)    =  H(i,i)+2+alpha*2*2*(3*x(i)^2-x(i+1));
    H(i,i+1)  =  H(i,i+1)-alpha*2*2*x(i);
    H(i+1,i)  =  H(i+1,i) -alpha*2*2*x(i);
    H(i+1,i+1)=  H(i+1,i+1)+alpha*2;
end
end

function bds_test(testcase)
%BDS_TEST tests the file ./bds.m.

% This test verifies the core functionality of the bds algorithm by checking its ability to
% minimize the Chained Rosenbrock function. The bds.m is tested under various configurations, 
% including different block_visiting_pattern, batch_size.
% While the optimal function value returned by bds.m may vary slightly depending on these parameters, 
% all results should be close to zero.
x0 = zeros(3,1);
[~, fopt, ~, ~] = bds(@chrosen, x0);
verifyEqual(testcase, fopt, 0)
options = struct();
options.iprint = 0;
options.MaxFunctionEvaluations = 5000 * length(x0);
options.ftarget = -inf;
options.output_alpha_hist = true;
options.output_xhist = true;
options.debug_flag = true;
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
verifyEqual(testcase, fopt, 0)

% Test the case where the block_visiting_pattern is "parallel".
options.block_visiting_pattern = "parallel";
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-3
    error('The function value is not close to 0.');
end

% Test the case where the block_visiting_pattern is "random".
options.block_visiting_pattern = "random";
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-8
    error('The function value is not close to 0.');
end

% Test the case where the batch_size is 1.
options.batch_size = 1;
options.debug_flag = false;
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-8
    error('The function value is not close to 0.');
end

% Test the case where the batch_size is 2.
options.batch_size = 2;
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-8
    error('The function value is not close to 0.');
end

% Test the case where the batch_size is 3.
options.batch_size = 3;
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-8
    error('The function value is not close to 0.');
end

% Test that replacement_delay excludes blocks visited in previous iterations.
delay_options = struct();
delay_options.num_blocks = 4;
delay_options.batch_size = 2;
delay_options.replacement_delay = 1;
delay_options.output_block_hist = true;
delay_options.MaxFunctionEvaluations = 80;
delay_options.ftarget = -inf;
delay_options.seed = 1;
[~, fopt, ~, output] = bds(@(x) sum(x.^2), ones(4, 1), delay_options);
if abs(fopt) > 1e-8
    error('The function value is not close to 0.');
end
block_hist = output.blocks_hist;
num_iters = floor(length(block_hist) / delay_options.batch_size);
block_hist = reshape(block_hist(1:delay_options.batch_size*num_iters), delay_options.batch_size, num_iters)';
for k = 2:num_iters
    verifyEmpty(testcase, intersect(block_hist(k, :), block_hist(k-1, :)))
end

% Test the case where the batch_size is 3 and the block_visiting_pattern is "sorted".
options.block_visiting_pattern = "sorted";
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-8
    error('The function value is not close to 0.');
end

options = rmfield(options, 'batch_size');

% Test the case where the block_visiting_pattern is "parallel" and the 
% batch_size is equal to the number of variables.
options.block_visiting_pattern = "parallel";
options.batch_size = numel(x0);
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-3
    error('The function value is not close to 0.');
end

% Test the case where the batch_size is equal to the num_blocks. Both
% of them are 1.
options.batch_size = 1;
options.num_blocks = 1;
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-6
    error('The function value is not close to 0.');
end

% When both batch_size and num_blocks are set to 1, different values 
% of block_visiting_pattern are tested. In this scenario, block_visiting_pattern 
% has no effect, as there is only one block to visit.
options.block_visiting_pattern = "random";
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-6
    error('The function value is not close to 0.');
end
options.block_visiting_pattern = "sorted";
[~, fopt, ~, ~] = bds(@chrosen, x0, options);
if abs(fopt) > 1e-6
    error('The function value is not close to 0.');
end

end

end
