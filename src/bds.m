function [xopt, fopt, exitflag, output] = bds(fun, x0, options)
%BDS solves unconstrained optimization problems without using derivatives by
%blockwise direct search methods.
%
%   BDS supports in MATLAB R2017b or later.
%
%   XOPT = BDS(FUN, X0) returns an approximate minimizer XOPT of the function
%   FUN, starting the calculations at X0. FUN must accept a vector input X and
%   return a scalar.
%
%   XOPT = BDS(FUN, X0, OPTIONS) performs the optimization using the specified
%   options in OPTIONS. 
%
%   OPTIONS should be a structure containing various fields that configure the algorithm's behavior. 
%   The most important options correspond directly to the parameters in Algorithm 2 of 
%   https://lht97.github.io/documents/DFOS2024.pdf, which provides a simplified and practical 
%   framework suitable for most users. These options are highlighted below. 
%   Additional advanced options for specific or complex use cases are introduced later.
%
%   expand                      Expanding factor of step size. A real number no less than 1. 
%                               It depends on the dimension of the problem and whether the problem 
%                               is noisy or not and the Algorithm. 
%                               Default: 2.
%   shrink                      Shrinking factor of step size. A positive number less than 1. It 
%                               depends on the dimension of the problem and whether the problem is 
%                               noisy or not and the Algorithm. 
%                               Default: 0.5.
%   num_blocks                  Number of blocks. A positive integer. The number of blocks
%                               should be less than or equal to the dimension of the problem.
%                               Default: length(x0).
%   alpha_init                  Initial step size. If alpha_init is a positive scalar, then the 
%                               initial step size of each block is set to alpha_init. If alpha_init 
%                               is a vector, then the initial step size of the i-th block is
%                               set to alpha_init(i).
%                               Default: 1.
%   forcing_function            The forcing function used for deciding whether the step achieves a 
%                               sufficient decrease. forcing_function should be a function handle.
%                               Default: @(alpha) alpha^2. See also reduction_factor.
%   reduction_factor            Factors multiplied to the forcing function for
%                               deciding whether a step achieves a sufficient decrease and
%                               for updating the step size. It should be a vector of length 3 such
%                               that
%                               reduction_factor(1) <= reduction_factor(2) <= reduction_factor(3),
%                               reduction_factor(1) >= 0, and reduction_factor(2) > 0.
%                               After the "inner direct search" over each block, the base
%                               point is updated to the best trial point in the block if
%                               its reduction is more than 
%                               reduction_factor(1) * forcing_function(step size).
%                               the step size in this block is shrunk if the reduction is at most
%                               reduction_factor(2) * forcing_function(step size), and it is
%                               expanded if the reduction is at least
%                               reduction_factor(3) * forcing_function(step size).
%                               Note: the step size passed to forcing_function is the step size
%                               used in the current iteration (before any update), not the updated
%                               step size for the next iteration.
%                               Default: [0, eps, eps]. See also forcing_function.
%   direction_set               A matrix whose columns will be used to define the polling directions. 
%                               If options does not contain direction_set, then the polling
%                               directions will be {e_1, -e_1, ..., e_n, -e_n}.
%                               Otherwise, it should be a nonsingular n-by-n matrix. Then the 
%                               polling directions will be {d_1, -d_1, ..., d_n, -d_n}, where d_i is
%                               the i-th column of direction_set. If direction_set is not singular, 
%                               then we will revise the direction_set to make it linear independent.
%                               See get_direction_set.m for details. 
%                               Default: eye(n).
%
%   The following options are advanced options for users with specific needs.
%   Algorithm                   Algorithm to use. It can be 
%                               'cbds' (sorted blockwise direct search) 
%                               'pbds' (randomly permuted blockwise direct search)
%                               'rbds' (randomized blockwise direct search), 
%                               'pads' (parallel blockwise direct search)
%                               'ds'   (the classical direct search). 
%                               If no Algorithm is specified in the options, the default setting 
%                               will be equivalent to using 'cbds' as the input.
%                               The detail can be found in the set_options.m file.
%   batch_size                  Suppose that batch_size is k. In each iteration, k blocks are 
%                               randomly selected to visit. A positive integer less than or equal 
%                               to num_blocks.
%                               Default: num_blocks.
%   replacement_delay           The delay for block replacement. If a block is selected in the 
%                               current iteration, it will not be selected in the next 
%                               replacement_delay iterations.
%                               A non-negative integer. 
%                               Default: floor(num_blocks / batch_size) - 1.
%   grouped_direction_indices   A cell array of length num_blocks, where each cell contains a vector 
%                               of indices corresponding to the directions assigned to that block. 
%                               Each index is in the range 1 to n, where n is the problem dimension.
%                               Note that each index represents both the positive and negative 
%                               directions (e.g., d_i and -d_i), and these paired directions are 
%                               always assigned to the same block. If this field is not provided,
%                               the directions will be divided into num_blocks blocks as evenly as 
%                               possible by divide_direction_set.m.
%   block_visiting_pattern      block_visiting_pattern to use. It can be 
%                               'sorted'   (The selected blocks will be visited in the order of 
%                                          their indices)
%                               'random'   (The selected blocks will be visited in a random order)
%                               'parallel' (The selected blocks will be visited in parallel)
%                               Default: 'sorted'.
%                               See divide_direction_set.m for details.
%                               It should be strictly less than StepTolerance.
%                               A positive number. Default: 1e-3*StepTolerance.
%   is_noisy                    A flag deciding whether the problem is noisy or not. The value of 
%                               is_noisy will be only used to determine the values of expand and 
%                               shrink now.
%                               Default: false.
%   polling_inner               Polling strategy in each block. It can be "complete" or
%                               "opportunistic". Default: "opportunistic".
%   cycling_inner               Cycling strategy employed within each block. It is used only when 
%                               polling_inner is "opportunistic". It can be 0, 1, 2, 3. 
%                               See cycling.m for details.
%                               Default: 3.
%   seed                        The seed for the random number generator. It should be a 
%                               non-negative integer in the range [0, 2^32 - 1]. If not provided, 
%                               the random number generator will be initialized using the 'shuffle'
%                               mode, which sets the seed based on the current time. This ensures 
%                               different random sequences across runs.
%
%   The following options are related to the termination criteria.
%   MaxFunctionEvaluations      Maximum of function evaluations. A positive integer.
%   ftarget                     Target of the function value. If the function value is smaller than 
%                               or equal to ftarget, then the algorithm terminates. 
%                               ftarget should be a real number.
%                               Default: -Inf.
%   StepTolerance               Termination threshold for step size. The algorithm terminates
%                               when the step size for each block falls below their corresponding
%                               value. It can be a positive scalar (applied to all blocks) or a
%                               vector with length equal to the number of blocks.
%                               Default: 1e-6.
%   use_function_value_stop     Whether to use the function value to stop the algorithm. If it is 
%                               true, then the algorithm will stop when the function value does not 
%                               change significantly over the last func_window_size iterations.
%                               It is an optional termination criterion.
%                               Default: false.
%   func_window_size            The number of iterations to consider when checking
%                               whether the function value has changed significantly.
%                               It should be a positive integer. 
%                               Default: 20.
%   func_tol                    Tolerance for the function value change. The algorithm checks 
%                               whether the change in the function value over the last 
%                               func_window_size iterations falls within the range 
%                               [func_tol * 1e-3, func_tol]. If the change is smaller than this 
%                               range, the algorithm terminates. 
%                               It should be a positive number. 
%                               Default: 1e-6.
%   use_estimated_gradient_stop Whether to use the estimated gradient to stop the algorithm. If it 
%                               is true and the algorithm is not terminated by other criteria, then 
%                               the algorithm will stop when the estimated gradient is sufficiently 
%                               small over the last grad_window_size estimated gradients.
%                               It is an optional termination criterion.
%                               Default: false.
%   grad_window_size            The number of estimated gradients to consider when checking
%                               whether the estimated gradient has changed significantly.
%                               It should be a positive integer. 
%                               Default: 1.
%   grad_tol                    Tolerance for the estimated gradient norm. The algorithm checks 
%                               whether the norm of the estimated gradient over the last 
%                               grad_window_size iterations falls within the range 
%                               [grad_tol * 1e-3, grad_tol]. If the norm is smaller than this 
%                               range, the algorithm terminates.
%                               It should be a positive number. 
%                               Default: 1e-6.
%
%   The following options are related to output and debugging.
%   output_xhist                Whether to output the history of points visited.
%                               Default: false.
%   output_alpha_hist           Whether to output the history of step sizes.
%                               Default: false.
%   output_block_hist           Whether to output the history of blocks visited.
%                               Default: false.
%   output_grad_hist            Whether to output the history of estimated gradients
%                               and the corresponding points. Default: false.
%   iprint                      a flag deciding how much information will be printed during
%                               the computation. It can be 0, 1, 2, or 3.
%                               0: there will be no printing;
%                               1: a message will be printed to the screen at the return,
%                               showing the best vector of variables found and its
%                               objective function value;
%                               2: in addition to 1, each function evaluation with its
%                               variables will be printed to the screen. The step size
%                               for each block will also be printed.
%                               3: in addition to 2, prints whether BDS satisfies the sufficient
%                               decrease condition in each block, as well as the corresponding
%                               decrease value for that block.
%                               Default: 0.
%                               This option is cited from
%                               https://github.com/libprima/prima/blob/main/matlab/interfaces/newuoa.m.
%   debug_flag                  A logical flag indicating whether to perform additional verifications 
%                               on the outputs after the algorithm completes. If set to true, the
%                               algorithm will execute a series of checks to ensure the validity and
%                               consistency of the results. This option is primarily intended for
%                               debugging and development purposes.
%                               Default: false.
%
%   [XOPT, FOPT] = BDS(...) returns an approximate minimizer XOPT and its function value FOPT.
%
%   [XOPT, FOPT, EXITFLAG] = BDS(...) also returns an EXITFLAG that indicates the exit
%   condition. The possible values of EXITFLAG are 0, 1, 2, 3, 4, 5, and 6, corresponding to the 
%   following exit conditions.
%
%   0    The StepTolerance of the step size is reached.
%   1    The target of the objective function is reached.
%   2    The maximum number of function evaluations is reached.
%   3    The maximum number of iterations is reached.
%   4    The change of the function value is small.
%   5    The estimated gradient is small.
%   6    The gradient estimation is completed.
%
%   [XOPT, FOPT, EXITFLAG, OUTPUT] = BDS(...) returns a
%   structure OUTPUT with the following fields.
%
%   fhist            History of function values.
%   grad_hist        History of estimated gradients (if output_grad_hist is true).
%   grad_xhist       History of points where the estimated gradients are computed (if 
%                    output_grad_hist is true).
%   xhist            History of points visited (if output_xhist is true).
%   invalid_points   History of points where the function evaluation fails (if output_xhist is true).
%   alpha_hist       History of step sizes for each iteration (present only if output_alpha_hist
%                    is true).
%                    Note that not all blocks are necessarily visited in every iteration. For blocks
%                    that are skipped in an iteration, their entries in alpha_hist record the
%                    step sizes carried forward from the previous iteration.
%   blocks_hist      History of blocks visited (if output_block_hist is true).
%   funcCount        The number of function evaluations.
%   message          The information of EXITFLAG.
%
%   ***********************************************************************
%   Authors:    Haitian LI (hai-tian.li@connect.polyu.hk)
%               and Zaikun ZHANG (zhangzaikun@mail.sysu.edu.cn)
%               Department of Applied Mathematics,
%               The Hong Kong Polytechnic University
%               School of Mathematics,
%               Sun Yat-sen University
%   ***********************************************************************
%   All rights reserved.
%

% Set options to an empty structure if it is not provided.
if nargin < 3
    options = struct();
end

% x0 should be a real vector.
if ~isrealvector(x0)
    error("BDS:InvalidInput", "x0 should be a real vector.");
end

% Transpose x0 if it is a row.
x0_is_row = isrow(x0);
x0 = double(x0(:));

% If FUN is a string, then convert it to a function handle.
if ischarstr(fun)
    fun = str2func(fun);
end
% Redefine fun to accept columns if x0 is a row, as we use columns internally.
fun_orig = fun;
if x0_is_row
    fun = @(x)fun(x');
end

% Get the dimension of the problem.
n = length(x0);

% Set the default value of options.
options = set_options(options, n);

MaxFunctionEvaluations = options.MaxFunctionEvaluations;
% Set the maximum number of iterations.
% Each iteration will use at least one function evaluation.
% Setting maxit to MaxFunctionEvaluations 
% will ensure that MaxFunctionEvaluations is exhausted before maxit is reached.
maxit = MaxFunctionEvaluations;

ftarget = options.ftarget;

alpha_tol = options.StepTolerance;

% The following variables are used for the optional stopping criteria.
use_function_value_stop = options.use_function_value_stop;
func_window_size = options.func_window_size;
func_tol = options.func_tol;
% Initialize fopt_window with inf values. This ensures that the objective-change
% stopping criterion remains inactive until the window is fully replaced with
% valid fopt values. Using inf instead of nan is necessary because the subsequent
% computation involves calculating the difference between the maximum and minimum
% values in this array. If nan were used, the result of max and min would ignore
% nan values and return the same valid value repeatedly, leading to an incorrect
% difference of 0, which is not the intended behavior.
fopt_window = inf(1, func_window_size);

use_estimated_gradient_stop = options.use_estimated_gradient_stop;
grad_window_size = options.grad_window_size;
grad_tol = options.grad_tol;
% Initialize with nan to disable the stopping test until the window is fully replaced with
% valid gradient norms.
norm_grad_window = nan(1, grad_window_size);
record_gradient_norm = false;

% Get the direction set.
D = get_direction_set(n, options);
positive_direction_set = D(:, 1:2:end);

num_blocks = options.num_blocks;

batch_size = options.batch_size;

replacement_delay = options.replacement_delay;

% Determine the indices of directions in each block.
grouped_direction_indices = divide_direction_set(n, num_blocks, options);

block_visiting_pattern = options.block_visiting_pattern;

% Initial step sizes for all blocks.
alpha_all = options.alpha_init;

expand = options.expand;
shrink = options.shrink;

forcing_function = options.forcing_function;

reduction_factor = options.reduction_factor;

polling_inner = options.polling_inner;

cycling_inner = options.cycling_inner;

seed = options.seed;
random_stream = RandStream("mt19937ar", "Seed", seed);

output_xhist = options.output_xhist;
if output_xhist
    xhist = nan(n, MaxFunctionEvaluations);
end
fhist = nan(1, MaxFunctionEvaluations);

output_alpha_hist = options.output_alpha_hist;
% Record the initial step size into the alpha_hist.
if  output_alpha_hist
    alpha_hist(:, 1) = alpha_all(:);
end

output_block_hist = options.output_block_hist;
% Initialize the history of blocks visited.
block_hist = nan(1, MaxFunctionEvaluations);

output_grad_hist = options.output_grad_hist;

iprint = options.iprint;

% Internal: gradient_estimation_complete
gradient_estimation_complete = options.gradient_estimation_complete;

% Initialize gradient history variables and info structure.
% grad_info.step_size_per_batch stores step sizes for the batch_size blocks 
% visited in the current iteration (used for gradient estimation).
% grad_info.step_size_per_block stores step sizes for all num_blocks blocks 
% (used for computing gradient error bounds).
grad_hist = [];
grad_xhist = [];
grad_iter = [];
grad_info = struct();
grad_info.n = n;
grad_info.step_size_per_batch = nan(batch_size, 1);
grad_info.step_size_per_block = alpha_all;
grad_info.fbase_per_batch = nan(batch_size, 1);
grad_info.complete_direction_set = D;

% Initialize exitflag.
% If exitflag is not set elsewhere, then the maximum number of iterations
% is reached, and hence we initialize exitflag to the corresponding value.
exitflag = get_exitflag("MAXIT_REACHED");

% Evaluate the function at the starting point x0.
% f0_real is the real function value at x0, while f0 might be different from f0_real.
% The detail is explained in eval_fun.m.
[f0, f0_real, is_valid] = eval_fun(fun, x0);
% Initialize nf (the number of function evaluations), xhist (history of points visited), and
% fhist (history of function values).
nf = 1;
if output_xhist
    % invalid_points will store the points where the function evaluation fails.
    % Specifically, it records points that result in NaN values or trigger an error
    % during the function evaluation. This information can be useful for debugging
    % or analyzing problematic regions in the search space. Note that invalid_points
    % will only be included in the output if output_xhist is set to true.
    invalid_points = [];
    xhist(:, nf) = x0;
    if ~is_valid
        invalid_points = [invalid_points, x0];
    end
end
% When we record fhist, we should use the real function value at x0, which is f0_real.
fhist(nf) = f0_real;
if iprint >= 2
    fprintf("The initial step size is:\n");
    print_aligned_vector(alpha_all);
    fprintf("Function number %d    F = %23.16E\n", nf, f0_real);
    fprintf("The corresponding X is:\n");
    print_aligned_vector(x0);
    fprintf("\n");
end

% Initialize xopt and fopt with x0 and f(x0), respectively. At this point, since
% only one point has been evaluated, xopt and fopt are trivially the best point
% and function value. Note that during each iteration, xopt and fopt are updated
% only after the iteration completes, so they may not represent the true optimal
% point and value within an iteration.
xopt = x0;
fopt = f0;

% Update fopt_window with the initial objective value. Although no iteration
% has been performed yet, the initial evaluation at x0 is treated as the
% zeroth iteration for the purpose of the sliding window used in the
% objective-change stopping criterion.
fopt_window = [fopt_window(2:end), fopt];

terminate = false;
% Check whether ftarget or MaxFunctionEvaluations is reached immediately after every function 
% evaluation. If one of them is reached at x0, no further computation should be entertained, 
% and hence, we will not run any iteration by setting maxit to 0.
if f0_real <= ftarget
    maxit = 0;
    exitflag = get_exitflag("FTARGET_REACHED");
elseif nf >= MaxFunctionEvaluations
    maxit = 0;
    exitflag = get_exitflag("MAXFUN_REACHED");
end

% Initialize xbase and fbase. xbase serves as the "base point" for the computation in the next
% block, meaning that reduction will be calculated with respect to xbase. fbase is the function
% value at xbase.
xbase = xopt;
fbase = fopt;

%Initialize the number of blocks visited.
num_visited_blocks = 0;

% fopt_all(i) stores the best function value found in the i-th block after one iteration,
% while xopt_all(:, i) holds the corresponding x. If a block is not visited during the iteration,
% fopt_all(i) is set to nan. Both fopt_all and xopt_all have a length of num_blocks, not batch_size,
% as not all blocks might not be visited in each iteration, but the best function value across all
% blocks must still be recorded.
fopt_all = nan(1, num_blocks);
xopt_all = nan(n, num_blocks);

for iter = 1:maxit

    % Define block_indices, a vector that specifies both the indices of the blocks
    % and the order in which they will be visited during the current iteration.
    % The length of block_indices is equal to batch_size.
    % These blocks should not have been visited in the previous replacement_delay
    % iterations when the replacement_delay is nonnegative.
    unavailable_block_indices = unique(block_hist(max(1, (iter-replacement_delay) * batch_size) : ...
                                (iter-1) * batch_size), 'stable');
    available_block_indices = setdiff(1:num_blocks, unavailable_block_indices);

    % Select batch_size blocks randomly from the available blocks. The selected blocks
    % will be visited in this iteration.
    block_indices = available_block_indices(random_stream.randperm(length(available_block_indices), ...
                    batch_size));

    % Compute the direction selection probability matrix.
    % TODO: where to change there?
    direction_selection_probability_matrix = get_direction_probability_matrix(n, batch_size, ...
                                            grouped_direction_indices, available_block_indices);
    grad_info.direction_selection_probability_matrix = direction_selection_probability_matrix;

    % Choose the block indices based on options.block_visiting_pattern.
    if strcmpi(block_visiting_pattern, "sorted")
        block_indices = sort(block_indices);
    end
    
    % Initialize sampled_direction_indices_per_batch as a cell array of length batch_size to store 
    % the indices of directions evaluated in each batch during the current iteration.
    % Initialize function_values_per_batch as a cell array of length batch_size to store the 
    % function values computed in each batch during the current iteration.
    % Initialize batch_gradient_available as a logical array of length batch_size, indicating whether
    % each block qualifies for gradient estimation based on specific criteria.
    sampled_direction_indices_per_batch = cell(1, batch_size);
    function_values_per_batch = cell(1, batch_size);
    % When the following two conditions are satisfied, the block is eligible for gradient estimation:
    % (1) sufficient decrease criterion is not met.
    % (2) all directions in the block have been evaluated.
    % The second condition is essential because gradient estimation requires complete
    % directional information. Without it, we might incorrectly attempt gradient estimation
    % when function evaluation budget is 1 and this only function evaluation does not achieve
    % sufficient decrease. This situation is particularly critical when num_blocks = 1.
    batch_gradient_available = false(1, batch_size);

    for i = 1:length(block_indices)

        % i_real = block_indices(i) is the real index of the block to be visited. For example,
        % if block_indices is [1 3 2] and i = 2, then we are going to visit the 3rd block.
        i_real = block_indices(i);

        % Get indices of directions in the i_real-th block.
        direction_indices = grouped_direction_indices{i_real};

        % Store the step size for the i_real-th block in grad_info.
        % - step_size_per_block(i_real): indexed by global block index i_real because it maintains
        %   step sizes for ALL num_blocks blocks (used later for gradient error bound calculation
        %   which needs the complete picture of all block step sizes).
        % - step_size_per_batch(i): indexed by batch index i because it only stores step sizes for
        %   the batch_size blocks visited in the current iteration. The batch index i directly
        %   corresponds to the position in sampled_direction_indices_per_batch and 
        %   function_values_per_batch, which are also batch_size in length (used for gradient 
        %   estimation which only needs information about blocks visited in this iteration).
        grad_info.step_size_per_block(i_real) = alpha_all(i_real);
        grad_info.step_size_per_batch(i) = alpha_all(i_real);
        grad_info.fbase_per_batch(i) = fbase;

        % Set the options for the direct search within the i_real-th block.
        suboptions.FunctionEvaluations_exhausted = nf;
        suboptions.MaxFunctionEvaluations = MaxFunctionEvaluations - nf;
        suboptions.ftarget = ftarget;
        suboptions.forcing_function = forcing_function;
        suboptions.reduction_factor = reduction_factor;
        suboptions.polling_inner = polling_inner;
        suboptions.cycling_inner = cycling_inner;
        suboptions.iprint = iprint;
        suboptions.i_real = i_real;

        % Perform the direct search within the i_real-th block.
        [sub_xopt, sub_fopt, sub_exitflag, sub_output] = inner_direct_search(fun, xbase,...
            fbase, D(:, direction_indices), direction_indices,...
            alpha_all(i_real), suboptions);

        % Record the index of the block visited.
        num_visited_blocks = num_visited_blocks + 1;
        block_hist(num_visited_blocks) = i_real;

        % Record the points visited by inner_direct_search if output_xhist is true.
        if output_xhist
            xhist(:, (nf+1):(nf+sub_output.nf)) = sub_output.xhist;
            invalid_points = [invalid_points, sub_output.invalid_points];
        end
        
        % Record the function values calculated by inner_direct_search,
        fhist((nf+1):(nf+sub_output.nf)) = sub_output.fhist;

        % Update the number of function evaluations.
        nf = nf+sub_output.nf;

        % Store the indices of directions (with respect to the full direction set) that were 
        % evaluated in the current batch during this iteration.
        % Note that The reason that we use sampled_direction_indices_per_batch{i} instead of
        % sampled_direction_indices_per_batch{i_real} is similar to that for
        % grad_info.step_size_per_batch(i) explained above.
        % We use direction_indices(1:sub_output.nf) instead of sub_output.direction_indices
        % because inner_direct_search might not evaluate all directions in the block and may cycle
        % through the directions multiple times. direction_indices(1:sub_output.nf) accurately 
        % captures the specific directions evaluated during this invocation of inner_direct_search.
        sampled_direction_indices_per_batch{i} = direction_indices(1:sub_output.nf);

        % Store function values for the current batch.
        function_values_per_batch{i} = sub_output.fhist;

        % Record whether all directions in the i_real-th block have been evaluated and
        % sufficient decrease is not achieved.
        batch_gradient_available(i) = (sub_output.nf == length(direction_indices)) && ...
        ~sub_output.sufficient_decrease;

        % Record the best function value and point encountered in the i_real-th block.
        fopt_all(i_real) = sub_fopt;
        xopt_all(:, i_real) = sub_xopt;

        % Retrieve the direction indices of the i_real-th block, which represent the order of the
        % directions in the i_real-th block when we perform the direct search in this block next time.
        grouped_direction_indices{i_real} = sub_output.direction_indices;

        % Whether to update xbase and fbase. xbase serves as the "base point" for the computation 
        % in the next block, meaning that reduction will be calculated with respect to xbase, as 
        % shown above. The condition must be checked before updating alpha_all(i_real) because the 
        % sufficient decrease is calculated based on the current step size.
        % Although eval_fun replaces all potential NaN values with 1e30 to allow algorithm 
        % iterations, and inner_direct_search also includes similar defensive checks when updating 
        % fopt, we apply the same NaN safeguard here. This consistent defensive practice ensures 
        % robustness: whenever a comparison involving fopt or fbase is performed, we account for 
        % potential NaN values. This approach anticipates possible future modifications to eval_fun 
        % or other unforeseen edge cases.
        update_base = (sub_fopt + reduction_factor(1) * forcing_function(alpha_all(i_real)) < fbase) ...
                    || (isnan(fbase) && ~isnan(sub_fopt));
        % Update the step size alpha_all according to the reduction achieved.
        if (sub_fopt + reduction_factor(3) * forcing_function(alpha_all(i_real)) < fbase) ...
                || (isnan(fbase) && ~isnan(sub_fopt))
            alpha_all(i_real) = expand * alpha_all(i_real);
        elseif (sub_fopt + reduction_factor(2) * forcing_function(alpha_all(i_real)) >= fbase) ...
                || (isnan(sub_fopt) && ~isnan(fbase))
            alpha_all(i_real) = shrink * alpha_all(i_real);
        end

        % Terminate the computations if sub_output.terminate is true, which means that 
        % inner_direct_search decides that the algorithm should be terminated for some reason 
        % indicated by sub_exitflag.
        if sub_output.terminate
            terminate = true;
            exitflag = sub_exitflag;
            break;
        end

        % Terminate the computations if the step size for each block falls below their 
        % corresponding thresholds.
        if all(alpha_all < alpha_tol)
            terminate = true;
            exitflag = get_exitflag("SMALL_ALPHA");
            break;
        end

        % If the block_visiting_pattern is not "parallel", then we will update xbase and fbase after
        % finishing the direct search in the i_real-th block. For "parallel", we will update xbase 
        % and fbase after one iteration of the outer loop.
        if ~strcmpi(block_visiting_pattern, "parallel") && update_base
            xbase = sub_xopt;
            fbase = sub_fopt;
        end
    end

    % Record the step size for every iteration if output_alpha_hist is true.
    % Why iter+1? Because we record the step size for the next iteration.
    if output_alpha_hist
        alpha_hist = [alpha_hist, alpha_all(:)];
    end

    % Update xopt and fopt. Note that we do this only if the iteration encounters a strictly 
    % better point. Make sure that fopt is always the minimum of fhist after the moment we update 
    % fopt. The determination between fopt_all and fopt is to avoid the case that fopt_all is
    % bigger than fopt due to the update of xbase and fbase.
    % NOTE: If the function values are complex, the min function will return the value with the 
    % smallest norm (magnitude).
    [~, index] = min(fopt_all, [], "omitnan");
    if fopt_all(index) < fopt
        fopt = fopt_all(index);
        xopt = xopt_all(:, index);
    end

    % Track the best function value observed among the latest func_window_size iterations.
    fopt_window = [fopt_window(2:end), fopt];

    % Actually, fopt is not always the minimum of fhist after the moment we update fopt
    % since the value we used to iterate is not always equal to the value returned by the function.
    % See eval_fun.m for details.
    % assert(fopt == min(fhist));

    % For "parallel", we will update xbase and fbase only after one iteration of the outer loop.
    % During the inner loop, every block will share the same xbase and fbase.
    if strcmpi(block_visiting_pattern, "parallel")
        % Update xbase and fbase. xbase serves as the "base point" for the computation in the
        % next block, meaning that reduction will be calculated with respect to xbase, as shown above.
        % Note that their update requires a sufficient decrease if reduction_factor(1) > 0.
        if (reduction_factor(1) <= 0 && fopt < fbase) || fopt + reduction_factor(1) * ...
            forcing_function(min(alpha_all)) < fbase
            xbase = xopt;
            fbase = fopt;
        end
    end

    % Check if the optimization should stop due to insufficient change in the objective function
    % over the last func_window_size iterations. If the change is below a specified threshold,
    % terminate the optimization. This check is performed after the current iteration is complete,
    % ensuring fopt_window includes the latest function value.
    % Note that fopt - f0 is used instead of fopt to ensure translation invariance. This adjustment
    % makes the stopping criterion depend on the relative change in the objective function,
    % unaffected by constant shifts (e.g., f(x) -> f(x) + c). Such normalization ensures consistent
    % behavior regardless of the function's translation.
    if use_function_value_stop
        func_change = max(fopt_window) - min(fopt_window);
        if func_change < (func_tol * min(1, abs(fopt - f0))) || ...
                func_change < (1e-3 * func_tol * max(1, abs(fopt - f0)))
            terminate = true;
            exitflag = get_exitflag("SMALL_OBJECTIVE_CHANGE");
        end
    end

    % When sufficient decrease is not achieved in any batch, we estimate the gradient.
    if all(batch_gradient_available)
        grad_info.sampled_direction_indices_per_batch = sampled_direction_indices_per_batch;
        grad_info.function_values_per_batch = function_values_per_batch;
        grad = estimate_gradient(grad_info);
        % If the norm of the estimated gradient exceeds the threshold (1e30), it is discarded.
        % This threshold is chosen to maintain consistency with the standard used in eval_fun.m.
        % Additionally, we check for nan values to ensure the gradient is valid. The first verification
        % can cover both cases. The second verification is to avoid the length of grad is too short.
        if (norm(grad) <= sqrt(n)*1e30) && (norm(grad) > 10*sqrt(n)*eps)
            % Record the estimated gradient in grad_hist.
            grad_hist = [grad_hist, grad];
            % Record the corresponding xbase in grad_xhist. As long as all batches do not achieve
            % sufficient decrease, we record the estimated gradient. Thus, xbase should be recorded
            % not xopt even if xopt is better than xbase.
            grad_xhist = [grad_xhist, xbase];
            % Record the iteration number at which the gradient was estimated.
            % The gradient is estimated during iteration iter when none of the selected 
            % blocks achieve sufficient decrease. Although the estimation is based on xbase 
            % (which may have been updated in a previous iteration), the estimation itself 
            % occurs in the current iteration iter.
            grad_iter = [grad_iter, iter];

            % When gradient_estimation_complete is true, we check whether the estimated gradient is
            % from the first iteration. If it is not, the solver will terminate.
            if gradient_estimation_complete && iter > 1
                terminate = true;
                exitflag = get_exitflag("gradient_estimation_complete");
            end

            if use_estimated_gradient_stop

                % Compute the gradient error bound.
                % Note that we use grad_info.step_size_per_block (not step_size_per_batch) and
                % grouped_direction_indices (not sampled_direction_indices_per_batch) because
                % computing the gradient error bound requires complete information about ALL blocks,
                % not just the batch_size blocks visited in the current iteration.
                % step_size_per_block contains step sizes for all num_blocks blocks.
                % grouped_direction_indices contains direction assignments for all num_blocks blocks.
                % This is different from gradient estimation, which only needs information about
                % the visited blocks in the current iteration.
                grad_error = get_gradient_error_bound(grad_info.step_size_per_block, ...
                                                    batch_size, grouped_direction_indices, n, ...
                                                    positive_direction_set, ...
                                                    direction_selection_probability_matrix);

                % Set up the reference gradient norm for the stopping criterion.
                %
                % Recording of norm_grad_window starts only after the first gradient estimate
                % with sufficiently small estimation error is obtained. From this point on,
                % gradient estimates are considered reliable for termination checks.
                %
                % For robustness against estimation error, both the entries stored in
                % norm_grad_window and the reference value reference_grad_norm are defined as
                % conservative upper bounds of the true gradient norm, namely
                %   norm(grad) + grad_error.
                % The reference value is fixed once at initialization and is used solely to
                % set the scale of the stopping thresholds, ensuring consistent and robust
                % scaling in the presence of estimation uncertainty.
                if ~record_gradient_norm
                    if grad_error < max(1e-3, 1e-1 * norm(grad))
                        reference_grad_norm = norm(grad);
                        record_gradient_norm = true;
                    end
                else
                    norm_grad_window = [norm_grad_window(2:end), norm(grad) + grad_error];
                end

                % Stopping test over the sliding window.
                % Two natural aggregations are possible:
                %   (i) all(x < T1) || all(x < T2)  : requires the entire window to satisfy
                %       a single threshold (uniform criterion).
                %   (ii) all((x < T1) | (x < T2))   : requires each entry to satisfy at least
                %       one of the thresholds (pointwise criterion).
                % These are not equivalent in general. We adopt the pointwise form as suggested.
                if record_gradient_norm && all((norm_grad_window < grad_tol * min(1, reference_grad_norm)) ...
                        | (norm_grad_window < 1e-3 * grad_tol * max(1, reference_grad_norm)))
                    terminate = true;
                    exitflag = get_exitflag("SMALL_ESTIMATE_GRADIENT");
                end

            end
        end
    end

    % Terminate the computations if terminate is true.
    if terminate
        break;
    end

end

% Record the number of function evaluations in output.
output.funcCount = nf;
% Truncate the histories of the blocks visited, the step sizes, the points visited,
% and the function values.
if output_block_hist
    output.blocks_hist = block_hist(1:num_visited_blocks);
end
if output_alpha_hist
    output.alpha_hist = alpha_hist(:, 1:min(iter, maxit));
end
if output_xhist
    output.xhist = xhist(:, 1:nf);
    output.invalid_points = invalid_points;
end
if output_grad_hist
    output.grad_hist = grad_hist;
    output.grad_xhist = grad_xhist;
    output.grad_iter = grad_iter;
end

output.fhist = fhist(1:nf);
% output.alpha_final = alpha_all;

% Set the message according to exitflag.
switch exitflag
    case get_exitflag("FTARGET_REACHED")
        output.message = "The target of the objective function is reached.";
    case get_exitflag("MAXFUN_REACHED")
        output.message = "The maximum number of function evaluations is reached.";
    case get_exitflag("MAXIT_REACHED")
        output.message = "The maximum number of iterations is reached.";
    case get_exitflag("SMALL_ALPHA")
        output.message = "The StepTolerance of the step size is reached.";
    case get_exitflag("SMALL_OBJECTIVE_CHANGE")
        output.message = "The change of the function value is small.";
    case get_exitflag("SMALL_ESTIMATE_GRADIENT")
        output.message = "The estimated gradient is small.";
    case get_exitflag("GRADIENT_ESTIMATION_COMPLETED")
        output.message = "The gradient estimation is completed.";
    otherwise
        output.message = "Unknown exitflag";
end

% Transpose xopt if x0 is a row.
if x0_is_row
    xopt = xopt';
end

% verify_postconditions is to detect whether the output is valid when debug_flag is true.
if options.debug_flag
    verify_postconditions(fun_orig, xopt, fopt, exitflag, output);
end

if iprint >= 1
    fprintf("\n");
    fprintf('%s\n', output.message);
    fprintf("Number of function values = %d    Least value of F is %23.16E\n", nf, fopt);
    fprintf("The corresponding X is:\n");
    print_aligned_vector(xopt);
end

end
