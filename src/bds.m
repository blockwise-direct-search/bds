function [xopt, fopt, exitflag, output] = bds(fun, x0, options)
%BDS solves unconstrained optimization problems without
%using derivatives by serial blockwise direct search with optional
%momentum and pattern extrapolation.
%
%   BDS supports MATLAB R2017b or later.
%
%   XOPT = BDS(FUN, X0) returns an approximate minimizer
%   XOPT of the function FUN, starting the calculations at X0. FUN must
%   accept a vector input X with the same orientation as X0 and return a scalar.
%   Internally, points are stored as columns. XOPT has the same orientation as X0.
%
%   XOPT = BDS(FUN, X0, OPTIONS) performs the
%   optimization using the specified options in OPTIONS.
%
%   By default, BDS searches along momentum and pattern directions from the
%   same point after polling and keeps the best point found.
%
%   OPTIONS should be a structure containing fields that configure the algorithm.
%   Omitted or empty fields use their defaults. The options below specify the
%   polling directions, block partition, step sizes, and sufficient decrease.
%   Scheduling, acceleration, termination, and output options follow separately.
%
%   expand                      Expanding factor of step size. A real number no less than 1.
%                               Default: 2.0 for every objective. An explicit value
%                               takes priority over the default.
%   shrink                      Shrinking factor of step size. A positive number less than 1. It
%                               scales the step size after an unsuccessful block update.
%                               Default: 0.5.
%   num_blocks                  Number of blocks. A positive integer. The number of blocks
%                               should be less than or equal to the dimension of the problem.
%                               Default: length(x0).
%   direction_set               A matrix whose columns will be used to define the polling directions.
%                               If options does not contain direction_set, then the polling
%                               directions will be {e_1, -e_1, ..., e_n, -e_n}.
%                               Otherwise, it should be an n-by-n matrix. The intended
%                               polling directions will be {d_1, -d_1, ..., d_n, -d_n}, where d_i is
%                               the i-th column of direction_set. Invalid, negligible, parallel, or
%                               linearly dependent columns are repaired or replaced to produce a
%                               basis while preserving surviving columns in their original positions.
%                               See get_direction_set.m for details.
%                               Default: eye(n).
%   alpha_init                  Initial step size. If alpha_init is a positive scalar, then the
%                               initial step size of each block is set to alpha_init. If alpha_init
%                               is a vector, then the initial step size of the i-th block is
%                               set to alpha_init(i). If alpha_init is "auto",
%                               then the current implementation requires the standard
%                               coordinate blocks {e_i,-e_i}, with block i assigned to
%                               coordinate i. For x0(i) ~= 0, the step is
%                               max(abs(x0(i)), StepTolerance(i)); for x0(i) == 0, it is
%                               max(1, StepTolerance(i)). A zero coordinate supplies no
%                               scale, so the unit step is used instead. General bases
%                               and grouped blocks require explicit numeric initial steps.
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
%                               Let xbase and fbase be the point and value before polling,
%                               y and fy the best polling point and value, and alpha the
%                               step used for this block. The base point is updated if
%                               fy + reduction_factor(1)*forcing_function(alpha) < fbase.
%                               The step is expanded if
%                               fy + reduction_factor(3)*forcing_function(alpha) < fbase,
%                               and otherwise shrunk if
%                               fy + reduction_factor(2)*forcing_function(alpha) >= fbase.
%                               These comparisons use alpha before its update. The inner
%                               opportunistic search uses half the first coefficient to
%                               decide when to stop polling; see inner_direct_search.m.
%                               Default: [0, eps, eps]. See also forcing_function.
%
%   The following options are advanced options for users with specific needs.
%   Algorithm                   Algorithm to use. It can be
%                               'cyclic' or 'cbds' (cyclic blockwise direct search),
%                               'permuted' or 'pbds' (randomly permuted blockwise direct search),
%                               'random' or 'rbds' (randomized blockwise direct search), or
%                               'ds'   (classical direct search with one block).
%                               The default configuration is equivalent to 'cbds'.
%                               An explicit Algorithm determines num_blocks. For cbds,
%                               pbds and rbds it is length(x0); for ds it is 1. When
%                               both options are given, their block counts must agree. If
%                               Algorithm is omitted, num_blocks can specify a general
%                               partition, visited cyclically. Permuted visits draw a new
%                               permutation after every full round. Randomized visits
%                               exclude the most recent num_blocks-1 visited blocks
%                               when sampling the next block.
%   grouped_direction_indices   A cell array of length num_blocks, where each cell contains a vector
%                               of indices corresponding to the directions assigned to that block.
%                               Each index is in the range 1 to n, where n is the problem dimension.
%                               Note that each index represents both the positive and negative
%                               directions (e.g., d_i and -d_i), and these paired directions are
%                               always assigned to the same block. If this field is not provided,
%                               the directions will be divided into num_blocks blocks as evenly as
%                               possible by divide_direction_set.m.
%   polling_inner               Polling strategy in each block. It can be "complete" or
%                               "opportunistic". Default: "opportunistic".
%   cycling_inner               Cycling strategy employed within each block. It is used only when
%                               polling_inner is "opportunistic". It can be 0, 1, 2, 3.
%                               See cycling.m for details.
%                               Default: 1.
%   seed                        The seed for the random number generator. It should be a
%                               non-negative integer in the range [0, 2^32 - 1]. If not provided,
%                               the random number generator will be initialized using the 'shuffle'
%                               mode, which sets the seed based on the current time. This ensures
%                               different random sequences across runs.
%
%   A complete visit is a sequence of consecutive block visits that covers
%   every block at least once. Blocks may repeat. Search acceleration uses the
%   complete visit ending now with the latest possible start. For additional
%   termination checks, start at iteration 0 and take the first visit that
%   completes coverage. Start the next complete visit at the following iteration.
%
%   use_search_acceleration     Enable momentum and pattern extrapolation.
%                               Default: true.
%   Acceleration requires a successful current poll and a complete visit.
%   The displacement from the point before its first poll to the point after
%   the current poll must be longer than max(StepTolerance). See accelerate.m
%   for the two searches and the update to the current block's momentum.
%
%   The budget and target are checked after each evaluation, and step tolerances
%   after each block update. The additional criteria below are checked at the
%   end of a complete visit only if it accepted no extrapolation point.
%   Neither additional criterion requires new function evaluations.
%
%   MaxFunctionEvaluations                       Maximum number of function evaluations. A positive
%                                                integer.
%                                                Default: 500*length(x0).
%   ftarget                                      Target function value. The algorithm terminates when
%                                                the function value is less than or equal to ftarget.
%                                                ftarget should be a real number.
%                                                Default: -Inf.
%   StepTolerance                                Termination threshold for the step size of each block.
%                                                A nonnegative scalar applies to all blocks. A vector
%                                                must have one value for each block.
%                                                Default: 1e-6.
%   use_function_value_stop                      Whether to stop when the function value changes little
%                                                over the stored complete-visit values.
%                                                Default: false.
%   func_window_size                             Number of values in the function-value window.
%                                                The window contains the initial value and then
%                                                the values at complete-visit ends, retaining only
%                                                the latest func_window_size values. Every end is
%                                                recorded, even if acceleration prevents checking.
%                                                A positive integer, including 1. With size 1,
%                                                the change is zero once the window is finite.
%                                                Default: 20.
%   func_tol                                     Positive tolerance for function-value stagnation.
%                                                Let change be the oldest minus the newest value
%                                                in the window, f the current base value, and f_ref
%                                                the initial finite value, or the first finite value
%                                                recorded at a complete-visit end if needed.
%                                                Once the window and reference are finite, stop if
%                                                change < func_tol*min(1,abs(f-f_ref)), or
%                                                change < 1e-3*func_tol*max(1,abs(f-f_ref)).
%                                                Default: 1e-6.
%   use_estimated_gradient_stop                  Whether to stop when the estimated gradient is small
%                                                over the last grad_window_size estimates. This is an
%                                                optional termination criterion. Estimates require
%                                                complete finite paired polling samples at one
%                                                unchanged base point throughout a complete visit.
%                                                Repeated visits replace the same block's samples,
%                                                using their actual steps before shrinkage.
%                                                Default: false.
%   grad_window_size                             Number of estimated gradients used for the gradient
%                                                stopping test. It should be a positive integer.
%                                                Complete visits without an available estimate
%                                                neither fill nor shift this window.
%                                                Default: 1.
%   grad_tol                                     Tolerance for the reference-scaled estimated gradient
%                                                norm. After a reliable reference norm G_ref has been
%                                                initialized, the solver stops if every value G in the
%                                                gradient window satisfies either
%                                                G < grad_tol * min(1, G_ref), or
%                                                G < 1e-3 * grad_tol * max(1, G_ref).
%                                                The two branches have the same form as function-value
%                                                stopping, with G_ref as the fixed reference scale.
%                                                Each G is the gradient norm plus its estimated
%                                                finite-difference error. G_ref is the first such
%                                                value passing the reference-selection checks.
%                                                The reference estimate is not part of the window.
%                                                Default: 1e-2.
%   lipschitz_constant                           Estimate of the Lipschitz constant of the Hessian.
%                                                This estimates a property assumed of the problem.
%                                                With exact function values, the error bound requires
%                                                that the Hessian is Lipschitz continuous and that
%                                                this supplied value bounds its Lipschitz constant.
%                                                Without that verification it gives a heuristic
%                                                error estimate, not a guaranteed error bound.
%                                                It scales the central-difference expression when
%                                                use_estimated_gradient_stop is true. The value must be
%                                                a positive scalar.
%                                                Default: 1e3.
%   use_gradient_reference_consistency           Whether to require agreement with the preceding
%                                                available gradient estimate at the same point
%                                                before fixing the gradient reference. The
%                                                reference error check must also pass. These
%                                                checks apply only when selecting the reference.
%                                                Default: true.
%   grad_reference_finite_difference_error_tol   Positive tolerance calibrating the preceding
%                                                consistency check from an estimated relative
%                                                finite-difference error. With shrink=0.5,
%                                                the default gives raw consistency tolerance 0.1.
%                                                See check_additional_termination.m for the
%                                                ratio, calibration, and assumptions. This option
%                                                affects reference selection only when
%                                                use_gradient_reference_consistency is true.
%                                                Default: 1/30.
%
%   The following options control solver output and diagnostic information.
%   output_xhist                          Whether to output the history of points visited.
%                                         Default: false.
%   output_alpha_hist                     Whether to output the history of step sizes.
%                                         Default: false.
%   output_block_hist                     Whether to output the history of blocks visited.
%                                         Default: false.
%   output_grad_hist                      Whether to output estimated gradients and the
%                                         corresponding points.
%                                         Default: false.
%   iprint                                A flag deciding how much information will be printed
%                                         during the computation. It can be 0, 1, 2, or 3.
%                                         0: no information is printed.
%                                         1: a message is printed at return, showing the best
%                                            vector of variables found and its objective value.
%                                         2: in addition to level 1, the initial and polling
%                                            evaluations and polling step sizes are printed.
%                                            Extrapolation evaluations are recorded in fhist
%                                            and optional xhist, but not printed individually.
%                                         3: in addition to level 2, the sufficient-decrease
%                                            result and decrease value are printed for each block.
%                                         Default: 0.
%                                         This option is cited from
%                                         https://github.com/libprima/prima/blob/main/matlab/
%                                         interfaces/newuoa.m.
%   debug_flag                            A logical flag indicating whether to perform additional
%                                         output verifications after the algorithm completes. If
%                                         true, the algorithm checks the validity and consistency
%                                         of the returned results. This option is intended for
%                                         diagnostic and development use.
%                                         Default: false.
%   [XOPT, FOPT] = BDS(...) returns an approximate minimizer XOPT and its
%   function value FOPT.
%
%   [XOPT, FOPT, EXITFLAG] = BDS(...) also returns an EXITFLAG that indicates
%   the exit condition. The possible values of EXITFLAG are 0, 1, 3, 4, and 5, corresponding to
%   the following exit conditions.
%
%   0    The target of the objective function is reached.
%   1    The maximum number of function evaluations is reached.
%   3    The StepTolerance of the step size is reached.
%   4    The change of the function value is small.
%   5    The estimated gradient is small.
%   [XOPT, FOPT, EXITFLAG, OUTPUT] = BDS(...) returns a
%   structure OUTPUT with the following fields.
%   fhist                       Raw evaluation history, including the initial value and NaN
%                               for caught exceptions. NaN is compared as +Inf internally.
%                               Failed evaluations still count towards the budget.
%   grad_hist                   History of estimated gradients if output_grad_hist is true.
%   grad_iter                   Complete-visit numbers corresponding to grad_hist, if
%                               output_grad_hist is true. These numbers can have gaps.
%   grad_xhist                  History of points where estimated gradients are computed if
%                               output_grad_hist is true.
%   xhist                       History of points visited if output_xhist is true.
%   invalid_points              History of points where function evaluation fails if
%                               output_xhist is true.
%   alpha_hist                  Initial steps, then steps after each round for cbds/pbds,
%                               or after each visit for rbds/ds, if output_alpha_hist is true.
%                               A terminating partial round is included. This output
%                               sampling does not determine complete-visit boundaries.
%   blocks_hist                 History of blocks visited if output_block_hist is true.
%   funcCount                   Number of function evaluations.
%   message                     Message corresponding to EXITFLAG.
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

% Input and options.
% Validate the public interface and preserve the input orientation.

% Set options to an empty structure if it is not provided.
if nargin < 3
    options = struct();
end

% x0 should be a real vector.
if ~isrealvector(x0)
    error("BDS:InvalidInput", "x0 should be a real vector.");
end

% Accept x0 as a row or column vector. Remember its shape and use a double
% column vector for internal calculations.
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
options = set_options(options, n, x0);

% Polling directions and block partition.

MaxFunctionEvaluations = options.MaxFunctionEvaluations;
% Construct the final polling basis before assigning directions to blocks.
% D stores positive/negative pairs in consecutive columns. Each pair stays in
% the same block. positive_direction_set is the basis used for gradient recovery.
D = get_direction_set(n, options);
positive_direction_set = D(:, 1:2:end);
num_blocks = options.num_blocks;
[grouped_direction_indices, block_of_direction_pair] = divide_direction_set(n, num_blocks, options);
alpha_tol = options.StepTolerance;

% Initial step sizes.
% The automatic rule is implemented only for the paper's standard coordinate
% blocks. Check the requested basis as well as the final partition, so repair
% does not silently turn an unsupported request into a supported auto case.

if ischarstr(options.alpha_init) && strcmpi(options.alpha_init, 'auto')
    coordinate_blocks = num_blocks == n && isequal(options.direction_set, eye(n));
    if coordinate_blocks
        for i = 1:n
            coordinate_blocks = coordinate_blocks && isequal(grouped_direction_indices{i}, [2 * i - 1, 2 * i]);
        end
    end
    if ~coordinate_blocks
        error('BDS:AutoInitialStepsCoordinateOnly', ...
            'alpha_init="auto" requires standard coordinate blocks. Supply numeric initial steps for this configuration.');
    end
    alpha_all = get_auto_alpha_init(x0, alpha_tol);
else
    alpha_all = options.alpha_init;
end

% Block visit schedule.
% The visit order is separate from the intervals used for acceleration and
% stopping. Keep a private stream and the current permutation only as needed.

% Use a private random stream for block scheduling. This avoids consuming the
% caller's random stream, which may also be used by a noisy objective function.
random_stream = RandStream('mt19937ar', 'Seed', options.seed);
% Keep the actual block history even when output_block_hist is false. It also
% supplies the preceding visits excluded by the randomized selection rule.
% Iterations k start at zero; MATLAB stores visit k in column k+1.
block_hist = zeros(1, MaxFunctionEvaluations);
num_visited_blocks = 0;

% Complete visits for acceleration and termination, and per-block momentum.

% For each block, store its latest visit index and the point BEFORE that poll.
% The value -1 marks a block that has not yet been visited. Once every block has
% appeared, the smallest latest index is the latest possible start of a window
% that covers all blocks. Saving these points avoids summing past displacements.
last_visit_indices = -ones(1, num_blocks);
last_visit_start_points = zeros(n, num_blocks);
% Each column belongs to an actual block, not to its position in a scheduling
% group. A permutation therefore changes visit order without exchanging memory.
momentum = zeros(n, num_blocks);
step_floor = max(alpha_tol);

% Forward complete visits and additional termination state.

complete_visit_count = 0;
complete_visit_start = 0;
% Accumulate acceptances since this start. A later failed visit must not
% erase an earlier accepted poll or acceleration in the same complete visit.
any_acceleration_accepted_in_complete_visit = false;
any_poll_accepted_in_complete_visit = false;
% Store paired values in the original column order of D. Each block records
% the step used at its most recent poll, before any expansion or shrinkage.
% NaN marks unavailable samples, so an incomplete segment cannot yield a gradient.
poll_values = nan(2 * n, 1);
last_poll_step = nan(num_blocks, 1);

% The function window starts with the initial value. Inf placeholders prevent
% a partially filled window from satisfying the finite-value requirement.
% The gradient window contains only estimates AFTER reference selection; NaN
% placeholders prevent a missing estimate from being mistaken for a small one.
stop_state = struct('function_window', inf(1, options.func_window_size), ...
    'function_reference', nan, 'gradient_window', nan(1, options.grad_window_size), ...
    'gradient_reference', nan, 'previous_gradient', [], 'previous_point', []);

% Output histories.
% These optional records do not control the internal histories needed above.

grad_hist = [];
grad_xhist = [];
grad_iter = [];
output_xhist = options.output_xhist;
output_alpha_hist = options.output_alpha_hist;
xhist = [];
invalid_points = [];
if output_xhist
    xhist = nan(n, MaxFunctionEvaluations);
end
alpha_hist = alpha_all(:);
fhist = nan(1, MaxFunctionEvaluations);

% Initial evaluation and immediate termination checks.

% eval_fun catches evaluation errors and maps NaN to +Inf for comparisons.
% Keep the raw value separately for fhist and count the evaluation even if it
% fails. xbase is the point used by polling; xopt is the best evaluated point,
% which may differ when a positive acceptance coefficient rejects a small gain.
[fbase, f0_real, valid] = eval_fun(fun, x0);
nf = 1;
xbase = x0;
xopt = x0;
fopt = fbase;
fhist(nf) = f0_real;
if output_xhist
    xhist(:, nf) = x0;
    if ~valid
        invalid_points = x0;
    end
end
% Use the initial value as the function reference only when it is finite.
% Otherwise, select the first finite complete-visit value later in the loop.
if isfinite(fbase)
    stop_state.function_reference = fbase;
end
stop_state.function_window(end) = fbase;
exitflag = get_exitflag('MAXFUN_REACHED');
terminate = false;
% Preserve the raw initial-value target check: a failed initial evaluation
% (NaN) must not satisfy the target merely because it is compared as +Inf.
if f0_real <= options.ftarget
    exitflag = get_exitflag('FTARGET_REACHED');
    terminate = true;
elseif nf >= MaxFunctionEvaluations
    terminate = true;
end
iprint = options.iprint;
if iprint >= 2
    fprintf('Function number %d    F = %23.16E\n', nf, f0_real);
    print_aligned_vector(xbase);
end

% Block visits.
% Each pass consumes at least one evaluation, so the evaluation budget gives
% a finite upper bound on the number of visits.
for k = 0:MaxFunctionEvaluations - 1
    if terminate
        break;
    end
    position = mod(k, num_blocks) + 1;
    if strcmp(options.Algorithm, 'rbds')
        % Preserve the established randomized rule: exclude the last num_blocks-1
        % visits, then sample one available block using the private stream.
        first = max(1, k - num_blocks + 2);
        available = setdiff(1:num_blocks, block_hist(first:k));
        i = available(random_stream.randperm(numel(available), 1));
    else
        if position == 1
            order = random_stream.randperm(num_blocks, num_blocks);
        end
        if strcmp(options.Algorithm, 'pbds')
            i = order(position);
        else
            % Cyclic visits need only the position. Retain the per-round random
            % draw so the private stream matches established seeded runs.
            i = position;
        end
    end
    block_hist(k + 1) = i;
    num_visited_blocks = k + 1;
    % Record the visit before polling, regardless of whether it will succeed.
    % Window coverage is about which blocks were visited, not which improved.
    last_visit_indices(i) = k;
    last_visit_start_points(:, i) = xbase;
    value_before_poll = fbase;
    alpha = alpha_all(i);
    direction_indices = grouped_direction_indices{i};
    % Poll this block from the current base, passing only the remaining budget.
    % The polling helper checks the target and budget after each evaluation.
    % Its returned direction order is used on the next visit to this block.
    suboptions = struct('FunctionEvaluations_exhausted', nf, ...
        'MaxFunctionEvaluations', MaxFunctionEvaluations - nf, ...
        'ftarget', options.ftarget, 'forcing_function', options.forcing_function, ...
        'reduction_factor', options.reduction_factor, 'polling_inner', options.polling_inner, ...
        'cycling_inner', options.cycling_inner, 'iprint', iprint, 'i_real', i);
    [x_poll, f_poll, sub_exitflag, sub_output] = inner_direct_search(fun, xbase, fbase, ...
        D(:, direction_indices), direction_indices, alpha, suboptions);
    % Append the polling evaluations in their actual order, including failures.
    % The raw histories are distinct from the values used for comparisons.
    fhist(nf + (1:sub_output.nf)) = sub_output.fhist;
    if output_xhist
        xhist(:, nf + (1:sub_output.nf)) = sub_output.xhist;
        invalid_points = [invalid_points, sub_output.invalid_points];
    end
    nf = nf + sub_output.nf;
    grouped_direction_indices{i} = sub_output.direction_indices;
    if f_poll < fopt
        xopt = x_poll;
        fopt = f_poll;
    end
    % Update the base only after the acceptance comparison using the old step.
    % Record the best evaluated point separately, even if that gain is too small
    % to pass a positive sufficient-decrease coefficient.
    poll_accepted = f_poll + options.reduction_factor(1) * options.forcing_function(alpha) < fbase;
    if poll_accepted
        xbase = x_poll;
        fbase = f_poll;
    end
    any_poll_accepted_in_complete_visit = any_poll_accepted_in_complete_visit || poll_accepted;

    % Save actual finite-difference samples and their PRE-shrink steps. Repeated
    % visits replace the same block's samples; any accepted poll invalidates the
    % whole segment for gradient estimation because its base would have changed.
    poll_values(direction_indices) = nan;
    if sub_output.nf == numel(direction_indices) && ~poll_accepted
        poll_values(direction_indices) = sub_output.fhist(:);
    end
    last_poll_step(i) = alpha;
    % Expand or shrink only the step of the visited block. Use the value before
    % polling and the step actually used, rather than an already updated step.
    if f_poll + options.reduction_factor(3) * options.forcing_function(alpha) < value_before_poll
        alpha_all(i) = options.expand * alpha;
    elseif f_poll + options.reduction_factor(2) * options.forcing_function(alpha) >= value_before_poll
        alpha_all(i) = options.shrink * alpha;
    end
    if sub_output.terminate
        terminate = true;
        exitflag = sub_exitflag;
    elseif all(alpha_all < alpha_tol)
        terminate = true;
        exitflag = get_exitflag('SMALL_ALPHA');
    end

    [latest_start, start_block, visit_complete] = ...
        complete_visit_status(last_visit_indices, complete_visit_start);
    acceleration_accepted = false;
    if ~terminate && options.use_search_acceleration && latest_start >= 0 ...
            && poll_accepted && fbase < value_before_poll
        % Both searches start at the accepted polling point. Earlier accepted
        % accelerations contribute to the displacement across this complete visit.
        pattern = xbase - last_visit_start_points(:, start_block);
        step = norm(pattern);
        if step > step_floor
            [xnew, fnew, acceleration_exitflag, extra, momentum(:, i)] = accelerate( ...
                fun, xbase, fbase, pattern / step, step, momentum(:, i), step_floor, ...
                MaxFunctionEvaluations - nf, options.ftarget, output_xhist);
            fhist(nf + (1:extra.nf)) = extra.fhist;
            if output_xhist
                xhist(:, nf + (1:extra.nf)) = extra.xhist;
                invalid_points = [invalid_points, extra.invalid_points];
            end
            nf = nf + extra.nf;
            acceleration_accepted = fnew < fbase;
            xbase = xnew;
            fbase = fnew;
            if fbase < fopt
                xopt = xbase;
                fopt = fbase;
            end
            if ~isempty(acceleration_exitflag)
                terminate = true;
                exitflag = acceleration_exitflag;
            end
        end
    end
    % Preserve acceleration success anywhere in the current complete visit.
    % In particular, failure at its last block must not enable extra stopping.
    any_acceleration_accepted_in_complete_visit = any_acceleration_accepted_in_complete_visit || acceleration_accepted;

    % At the first visit covering all blocks since complete_visit_start, check
    % the applicable criteria before polling another block. Record the function
    % value even if an accepted acceleration rules out stopping here.
    if visit_complete
        complete_visit_count = complete_visit_count + 1;
        stop_state.function_window = [stop_state.function_window(2:end), fbase];
        if isnan(stop_state.function_reference) && isfinite(fbase)
            stop_state.function_reference = fbase;
        end
        % Keep the applicability conditions here, where the execution flow is
        % visible. The shared helper computes the criteria and reference updates.
        % A function window requires finite values. A gradient additionally needs
        % paired finite samples, positive recorded steps, and no accepted poll,
        % so all samples come from the same unchanged base point.
        check_function = options.use_function_value_stop ...
            && all(isfinite(stop_state.function_window)) ...
            && isfinite(stop_state.function_reference);
        check_gradient = (options.use_estimated_gradient_stop || options.output_grad_hist) ...
            && ~any_poll_accepted_in_complete_visit && all(isfinite(poll_values)) ...
            && all(isfinite(last_poll_step)) && all(last_poll_step > 0);
        % A completed criterion can explain the final evaluation even when it
        % also exhausts the budget. A reached target retains priority.
        check_stopping = ~terminate || exitflag ~= get_exitflag('FTARGET_REACHED');
        if ~any_acceleration_accepted_in_complete_visit && ((check_stopping && check_function) || check_gradient)
            [stop_state, stop_flag, grad] = check_additional_termination( ...
                stop_state, xbase, fbase, poll_values, last_poll_step(block_of_direction_pair), ...
                positive_direction_set, options, check_function && check_stopping, check_gradient);
            % Record every available estimate requested for diagnostics, even
            % when the gradient stopping switch is off. Number these estimates
            % by complete visits; missing estimates can leave gaps in grad_iter.
            if options.output_grad_hist && ~isempty(grad)
                grad_hist(:, end + 1) = grad;
                grad_xhist(:, end + 1) = xbase;
                grad_iter(end + 1) = complete_visit_count;
            end
            if check_stopping && ~isempty(stop_flag)
                terminate = true;
                exitflag = stop_flag;
            end
        end
        % Start the next forward complete visit at the next block. Reset only
        % segment data. Rolling history, per-block momentum, reference values,
        % and the two stopping windows persist across complete visits.
        complete_visit_start = k + 1;
        any_acceleration_accepted_in_complete_visit = false;
        any_poll_accepted_in_complete_visit = false;
        poll_values(:) = nan;
        last_poll_step(:) = nan;
    end
    % Preserve each algorithm's established step-history sampling. This output
    % convention does not determine the complete visits used for stopping.
    if output_alpha_hist && (position == num_blocks || strcmp(options.Algorithm, 'rbds') || terminate)
        alpha_hist(:, end + 1) = alpha_all(:);
    end
end

% Return only the evaluations and visits that actually occurred. Optional
% outputs do not control the internal histories needed by the algorithm.
output.funcCount = nf;
output.fhist = fhist(1:nf);
if options.output_block_hist
    output.blocks_hist = block_hist(1:num_visited_blocks);
end
if output_alpha_hist
    output.alpha_hist = alpha_hist;
end
if output_xhist
    output.xhist = xhist(:, 1:nf);
    output.invalid_points = invalid_points;
end
if options.output_grad_hist
    output.grad_hist = grad_hist;
    output.grad_xhist = grad_xhist;
    output.grad_iter = grad_iter;
end

% Set the message according to exitflag.
switch exitflag
    case get_exitflag("FTARGET_REACHED")
        output.message = "The target of the objective function is reached.";
    case get_exitflag("MAXFUN_REACHED")
        output.message = "The maximum number of function evaluations is reached.";
    case get_exitflag("SMALL_ALPHA")
        output.message = "The StepTolerance of the step size is reached.";
    case get_exitflag("SMALL_OBJECTIVE_CHANGE")
        output.message = "The change of the function value is small.";
    case get_exitflag("SMALL_ESTIMATE_GRADIENT")
        output.message = "The estimated gradient is small.";
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
