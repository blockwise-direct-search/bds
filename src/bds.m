function [xopt, fopt, exitflag, output] = bds(fun, x0, options)
%BDS solves unconstrained optimization problems without
%using derivatives by blockwise direct search methods with optional
%acceleration steps.
%
%   BDS supports MATLAB R2017b or later.
%
%   XOPT = BDS(FUN, X0) returns an approximate minimizer
%   XOPT of the function FUN, starting the calculations at X0. FUN must
%   accept a vector input X and return a scalar.
%
%   XOPT = BDS(FUN, X0, OPTIONS) performs the
%   optimization using the specified options in OPTIONS.
%
%   By default, BDS enables three acceleration mechanisms around regular
%   block polling: productive-direction memory before polling, followed by
%   iteration-pattern search and momentum-direction extrapolation after
%   polling. The two post-poll searches use the same candidate step factors
%   1, 2, and 4, with pattern candidates considered first. Each mechanism can
%   be disabled independently by the options documented below.
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
%                               Default: 2.0.
%   shrink                      Shrinking factor of step size. A positive number less than 1. It
%                               depends on the dimension of the problem and whether the problem is
%                               noisy or not and the Algorithm.
%                               Default: 0.5.
%   num_blocks                  Number of blocks. A positive integer. The number of blocks
%                               should be less than or equal to the dimension of the problem.
%                               Default: length(x0).
%   direction_set               A matrix whose columns will be used to define the polling directions.
%                               If options does not contain direction_set, then the polling
%                               directions will be {e_1, -e_1, ..., e_n, -e_n}.
%                               Otherwise, it should be a nonsingular n-by-n matrix. Then the
%                               polling directions will be {d_1, -d_1, ..., d_n, -d_n}, where d_i is
%                               the i-th column of direction_set. If direction_set is not singular,
%                               then we will revise the direction_set to make it linear independent.
%                               See get_direction_set.m for details.
%                               Default: eye(n).
%   alpha_init                  Initial step size. If alpha_init is a positive scalar, then the
%                               initial step size of each block is set to alpha_init. If alpha_init
%                               is a vector, then the initial step size of the i-th block is
%                               set to alpha_init(i). If alpha_init is "auto",
%                               then the initial polling steps are chosen by
%                               a fminsearch-inspired scale-aware rule:
%                               MATLAB's fminsearch constructs its initial
%                               simplex using coordinate-dependent
%                               perturbations of x0; analogously, BDS uses
%                               the coordinate scales of the starting point.
%                               Nonzero coordinates receive
%                               max(abs(x0(i)), StepTolerance), while exact
%                               zero coordinates keep the neutral BDS unit
%                               step. If a block contains several coordinates,
%                               its initial step size is the maximum coordinate
%                               step size in that block.
%                               This rule is primarily intended for the
%                               default coordinate direction set; with a
%                               custom direction_set, the same column/block
%                               indices are used.
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
%   is_noisy                    A flag deciding whether the problem is noisy or not. The value of
%                               is_noisy will be only used to determine the values of expand and
%                               shrink now.
%                               Default: false.
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
%   The following options are related to the acceleration steps.
%   use_productive_direction_memory   Whether to try productive search directions retained from
%                                     previous iterations before the regular block-polling phase.
%                                     The memory is an ordered list that is retained across
%                                     iterations rather than reset after each iteration. Each
%                                     entry stores a normalized productive direction together
%                                     with the step length associated with that direction. A
%                                     direction is considered productive if it produces an
%                                     accepted polling update or a successful iteration-level
%                                     acceleration step.
%                                     The list contains at most
%                                     productive_direction_memory_size entries. When the list
%                                     is full and a new direction is admitted, its oldest entry
%                                     is removed. A direction that is nearly parallel or
%                                     antiparallel to a direction already in the list is not
%                                     stored as a separate entry.
%                                     At the beginning of each iteration, the retained directions
%                                     are considered in list order before regular polling. For a
%                                     retained direction, the algorithm evaluates a candidate point
%                                     obtained by stepping from the current base point along that
%                                     direction. The trial step length is the larger of the
%                                     current mean block step size and the stored step length.
%                                     If the candidate improves the objective function, it is
%                                     accepted, and up to two further candidates may be evaluated
%                                     by extrapolating farther along the same direction with
%                                     successively doubled step lengths. The memory phase stops
%                                     after such a productive direction is found or after all
%                                     retained directions have been considered.
%                                     In summary, enabling this option adds an opportunistic
%                                     search over retained productive directions before the
%                                     regular BDS block-polling phase.
%                                     Default: true.
%   productive_direction_memory_size  Maximum number of entries retained in the ordered
%                                     productive-direction memory. This option limits the number
%                                     of stored entries, each consisting of a direction and its
%                                     associated step length. It does not limit the length or
%                                     magnitude of the directions. Default: max(1, min(n, 5)).
%   use_iteration_pattern_step        Whether to perform an additional search after the regular
%                                     polling phase of an iteration. The search is attempted only
%                                     when the base point at the end of the iteration has a lower
%                                     objective value than the base point at its beginning, the
%                                     norm of the net displacement of the base point from the
%                                     beginning to the end of the iteration is greater than the
%                                     largest component of StepTolerance, and function evaluations
%                                     remain available.
%                                     The pattern direction is the normalized net displacement of
%                                     the base point during the current iteration. The pattern step
%                                     length is the larger of the norm of this displacement and
%                                     the largest component of StepTolerance. Starting from the
%                                     current base point, the algorithm evaluates at most three
%                                     candidate points, using step length factors 1, 2, and 4.
%                                     The search stops at the first candidate whose objective value
%                                     is not lower than the best value found in this phase, when
%                                     the objective value is less than or equal to ftarget, or when
%                                     the function evaluation budget is exhausted. If the search
%                                     improves the objective function, the best candidate becomes
%                                     the new base point and its direction may be stored in the
%                                     productive direction memory.
%                                     If use_momentum_extrapolation is enabled, the momentum vector
%                                     is updated from the same normalized iteration displacement
%                                     before this search, regardless of whether the pattern search
%                                     improves the objective function.
%                                     In summary, enabling this option adds a finite search along
%                                     the normalized net displacement accumulated during the current
%                                     iteration, after the regular BDS polling phase.
%                                     Default: true.
%   use_momentum_extrapolation        Whether to maintain a momentum direction across iterations
%                                     and to search along that direction when appropriate. After an
%                                     iteration has produced a lower objective value at its ending
%                                     base point than at its starting base point, has a net base
%                                     point displacement greater than the largest component of
%                                     StepTolerance, and still has available function evaluations,
%                                     its normalized net displacement is incorporated into the
%                                     momentum vector by the update
%                                     momentum = momentum_decay * momentum + ...
%                                     (1 - momentum_decay) * pattern_direction.
%                                     This momentum update is performed before the pattern and
%                                     momentum candidate searches and is performed even when the
%                                     pattern search subsequently finds an improving candidate. If
%                                     the updated momentum vector has a norm greater than the
%                                     largest component of StepTolerance, it is normalized to form
%                                     the momentum direction. Otherwise, no momentum direction is
%                                     available for the current iteration.
%                                     When use_iteration_pattern_step is enabled, pattern candidates
%                                     are evaluated first. Candidates along the momentum direction
%                                     are evaluated only if the pattern search produces no
%                                     improvement, the target value has not been reached, a momentum
%                                     direction is available, and function evaluations remain
%                                     available. When use_iteration_pattern_step is disabled, the
%                                     momentum search is attempted directly whenever a momentum
%                                     direction is available and the same iteration conditions hold.
%                                     In either case, candidate points use the pattern step length
%                                     multiplied by the factors 1, 2, and 4. The search stops at the
%                                     first candidate whose objective value is not lower than the
%                                     current best value, when the objective value is less than or
%                                     equal to ftarget, or when the function evaluation budget is
%                                     exhausted. If a momentum candidate is exactly the same point
%                                     as a pattern candidate that has already been evaluated and
%                                     rejected, it is skipped so that the objective function is not
%                                     evaluated twice. If the momentum search improves the objective
%                                     function, the best candidate becomes the new base point and
%                                     its direction may be stored in the productive direction
%                                     memory.
%                                     In summary, this option updates a direction averaged over
%                                     successful iteration displacements and may use that direction
%                                     for an additional search after an unsuccessful pattern search
%                                     or when the pattern search is disabled.
%                                     Default: true.
%   momentum_decay                    Weight assigned to the previous momentum vector in the
%                                     momentum update
%                                     momentum = momentum_decay * momentum + ...
%                                     (1 - momentum_decay) * pattern_direction.
%                                     At the start of the solver, the momentum vector is initialized
%                                     to the zero vector. After regular polling, the algorithm
%                                     updates the momentum vector when the current iteration ends
%                                     with a lower base point objective value than at its beginning,
%                                     the norm of the net base point displacement exceeds the
%                                     largest component of StepTolerance, and function evaluations
%                                     remain available. The first iteration satisfying all three
%                                     conditions produces a momentum vector directly from its
%                                     pattern_direction. Each later iteration satisfying all three
%                                     conditions combines its new pattern_direction with the
%                                     momentum vector retained from earlier iterations. The momentum
%                                     vector can therefore incorporate directions from multiple
%                                     iterations after the second such update.
%                                     Each momentum update first computes an updated momentum vector
%                                     by multiplying the retained momentum vector by momentum_decay,
%                                     multiplying the current pattern_direction by
%                                     1 - momentum_decay, and adding the two resulting vectors. The
%                                     algorithm then computes the norm of the updated momentum vector
%                                     and creates momentum_direction by normalizing the updated vector
%                                     only when its norm is greater than the largest component of
%                                     StepTolerance. If the norm does not exceed the largest component
%                                     of StepTolerance, the updated momentum vector is retained for
%                                     later updates, but no momentum_direction is available for the
%                                     current iteration and no search is performed along the momentum
%                                     direction.
%                                     The retained momentum vector summarizes normalized net
%                                     displacement directions from earlier iterations.
%                                     The coefficient momentum_decay multiplies the retained
%                                     momentum vector, while 1 - momentum_decay multiplies the
%                                     normalized net displacement of the current iteration. The
%                                     momentum update is applied before normalization.
%                                     With momentum_decay = 0, every update uses only the current
%                                     pattern_direction and retains no information from earlier
%                                     iterations. The parameter controls only the momentum update.
%                                     It does not change the pattern step length or the candidate step
%                                     factors.
%                                     Default: 0.6.
%
%   The following options are related to the termination criteria.
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
%                                                over the last func_window_size iterations. This is an
%                                                optional termination criterion.
%                                                Default: false.
%   func_window_size                             Number of iterations used for the function-value
%                                                stopping test. It should be a positive integer.
%                                                Default: 20.
%   func_tol                                     Tolerance for the change in function value. The change
%                                                over the last func_window_size iterations is compared
%                                                with [func_tol * 1e-3, func_tol].
%                                                Default: 1e-6.
%   use_estimated_gradient_stop                  Whether to stop when the estimated gradient is small
%                                                over the last grad_window_size estimates. This is an
%                                                optional termination criterion.
%                                                Default: false.
%   grad_window_size                             Number of estimated gradients used for the gradient
%                                                stopping test. It should be a positive integer.
%                                                Default: 1.
%   grad_tol                                     Tolerance for the reference-scaled estimated gradient
%                                                norm. After a reliable reference norm G_ref has been
%                                                initialized, every value G in the gradient window must
%                                                satisfy G < grad_tol * max(1, G_ref). Thus grad_tol is
%                                                an absolute tolerance when G_ref <= 1 and a relative
%                                                tolerance when G_ref > 1.
%                                                Default: 1e-2.
%   lipschitz_constant                           Estimate of the objective function's Lipschitz constant.
%                                                It is used to compute the gradient error bound when
%                                                use_estimated_gradient_stop is true. The value must be
%                                                a positive scalar.
%                                                Default: 1e3.
%   use_gradient_reference_consistency           Whether to require a consistency check before
%                                                initializing the gradient reference scale. The
%                                                current gradient estimate, grad, is compared with
%                                                previous_gradient, the estimate retained from the
%                                                preceding iteration that produced a valid gradient
%                                                estimate. Both estimates must come from iterations
%                                                whose polling phase did not obtain a sufficient
%                                                decrease. The two estimates must be computed at
%                                                exactly the same base point xbase. Their relative
%                                                difference is computed as
%                                                norm(grad - previous_gradient) /
%                                                max(1, norm(grad), norm(previous_gradient)).
%                                                The consistency check passes only when this ratio is
%                                                less than or equal to grad_reference_raw_tol. Both
%                                                gradient estimates reuse ordinary polling evaluations,
%                                                so the check does not require extra function
%                                                evaluations. Passing the consistency check is
%                                                necessary but not sufficient to initialize the
%                                                gradient reference scale. The separate gradient
%                                                error bound test must also pass.
%                                                Default: true.
%   grad_reference_finite_difference_error_tol   Tolerance for the relative finite difference error
%                                                inferred by comparing two gradient estimates at the
%                                                same base point. Each estimate uses ordinary polling
%                                                evaluations and the current step size of every visited
%                                                block. The step size for block i in the second estimate
%                                                is the corresponding step size in the first estimate
%                                                multiplied by shrink. Polling directions and visited
%                                                blocks can differ between the two iterations because
%                                                the solver may select different batches. The threshold
%                                                conversion uses the leading truncation term of the
%                                                central difference formula. To see the conversion,
%                                                consider a fixed direction d_i with step h_i in the
%                                                first estimate and theta*h_i in the second, where theta
%                                                is the public shrink factor. The leading error of the
%                                                first directional estimate is proportional to h_i^2.
%                                                Replacing h_i by theta*h_i changes the leading error
%                                                to theta^2*e_i. The leading difference between the two
%                                                directional estimates is therefore (1-theta^2)*e_i,
%                                                while the leading error in the second estimate is
%                                                theta^2*e_i. The second directional error is consequently
%                                                estimated from the difference by the factor
%                                                theta^2/(1-theta^2). The solver applies the same factor
%                                                to calibrate the consistency ratio between grad and
%                                                previous_gradient after gradient reconstruction. If
%                                                this option is tol, the corresponding raw consistency
%                                                threshold is tol*(1-theta^2)/theta^2, stored as
%                                                grad_reference_raw_tol. The conversion is a leading
%                                                order calibration for the reconstructed gradient
%                                                consistency ratio, not an exact error identity for the
%                                                complete reconstructed gradient. The derivation applies
%                                                to general polling directions and does not require an
%                                                orthogonal or coordinate basis. When
%                                                use_gradient_reference_consistency is true, the
%                                                consistency ratio between grad and previous_gradient
%                                                is compared with grad_reference_raw_tol. With
%                                                shrink=0.5, the default value gives
%                                                grad_reference_raw_tol = 0.1.
%                                                Default: 1/30.
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
%                                         2: in addition to level 1, each function evaluation and
%                                            its variables are printed. The step size for each
%                                            block is also printed.
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
%   the exit condition. The possible values of EXITFLAG are 0, 1, 2, 3, 4, and 5, corresponding to
%   the following exit conditions.
%
%   0    The target of the objective function is reached.
%   1    The maximum number of function evaluations is reached.
%   2    The maximum number of iterations is reached.
%   3    The StepTolerance of the step size is reached.
%   4    The change of the function value is small.
%   5    The estimated gradient is small.
%   [XOPT, FOPT, EXITFLAG, OUTPUT] = BDS(...) returns a
%   structure OUTPUT with the following fields.
%   fhist                       History of function values.
%   grad_hist                   History of estimated gradients if output_grad_hist is true.
%   grad_xhist                  History of points where estimated gradients are computed if
%                               output_grad_hist is true.
%   xhist                       History of points visited if output_xhist is true.
%   invalid_points              History of points where function evaluation fails if
%                               output_xhist is true.
%   alpha_hist                  History of step sizes for each iteration if output_alpha_hist
%                               is true. Not all blocks are necessarily visited in every
%                               iteration. For a block skipped in an iteration, alpha_hist
%                               records the step size carried forward from the previous
%                               iteration.
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

% Set options to an empty structure if it is not provided.
if nargin < 3
    options = struct();
end

% x0 should be a real vector.
if ~isrealvector(x0)
    error("BDS:InvalidInput", "x0 should be a real vector.");
end

% Convert x0 to a double column vector.
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
reference_function_value = nan;

use_estimated_gradient_stop = options.use_estimated_gradient_stop;
grad_window_size = options.grad_window_size;
grad_tol = options.grad_tol;
% Initialize with nan to disable the stopping test until the window is fully replaced with
% valid gradient norms.
norm_grad_window = nan(1, grad_window_size);
reference_grad_norm_initialized = false;
reference_candidate_reliable = ~options.use_gradient_reference_consistency;
previous_gradient = [];
previous_gradient_x = [];

lipschitz_constant = options.lipschitz_constant;

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

productive_direction_memory_size = options.productive_direction_memory_size;
% Initialize an empty memory whose entries store a normalized direction and its associated step.
productive_direction_memory = struct('direction', {}, 'step', {});
momentum = zeros(n, 1);
momentum_decay = options.momentum_decay;

output_xhist = options.output_xhist;
xhist = [];
invalid_points = [];
if output_xhist
    xhist = nan(n, MaxFunctionEvaluations);
end
fhist = nan(1, MaxFunctionEvaluations);

% Read-only configuration shared by the two acceleration-phase helpers.
acceleration_configuration = struct( ...
    'use_productive_direction_memory', options.use_productive_direction_memory, ...
    'use_iteration_pattern_step', options.use_iteration_pattern_step, ...
    'use_momentum_extrapolation', options.use_momentum_extrapolation, ...
    'momentum_decay', momentum_decay, ...
    'productive_direction_memory_size', productive_direction_memory_size, ...
    'step_floor', max(alpha_tol), ...
    'MaxFunctionEvaluations', MaxFunctionEvaluations, ...
    'ftarget', ftarget, ...
    'output_xhist', output_xhist);

output_alpha_hist = options.output_alpha_hist;
% Record the initial step size into the alpha_hist.
if output_alpha_hist
    alpha_hist(:, 1) = alpha_all(:);
end
output_block_hist = options.output_block_hist;
% Initialize the history of blocks visited.
block_hist = nan(1, MaxFunctionEvaluations);

output_grad_hist = options.output_grad_hist;

iprint = options.iprint;

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

% Initialize exitflag with the default termination status.
% If no other termination condition overrides it, completing maxit iterations
% leaves exitflag equal to MAXIT_REACHED.
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
    if ~is_valid
        fprintf("Warning: The function evaluation at the initial point x0 is not valid.\n");
    end
end

% Initialize xopt and fopt with x0 and f(x0), respectively. At this point, since
% only one point has been evaluated, xopt and fopt are trivially the best point
% and function value. Note that during each iteration, xopt and fopt are updated
% only after the iteration completes, so they may not represent the true optimal
% point and value within an iteration.
xopt = x0;
fopt = f0;

% Fix the function-value stopping scale at the first finite incumbent. If the
% initial evaluation fails, leave the reference uninitialized until the solver
% first recovers a finite incumbent.
if isfinite(fopt)
    reference_function_value = fopt;
end

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
    terminate = true;
    exitflag = get_exitflag("FTARGET_REACHED");
elseif nf >= MaxFunctionEvaluations
    maxit = 0;
    terminate = true;
    exitflag = get_exitflag("MAXFUN_REACHED");
end

% Initialize xbase and fbase. xbase serves as the "base point" for the computation in the next
% block, meaning that reduction will be calculated with respect to xbase. fbase is the function
% value at xbase.
xbase = xopt;
fbase = fopt;

% Initialize the number of blocks visited.
num_visited_blocks = 0;

% fopt_all(i) stores the best function value found in the i-th block after one iteration,
% while xopt_all(:, i) holds the corresponding x. If a block is not visited during the iteration,
% fopt_all(i) is set to nan. fopt_all is a vector of length num_blocks, and xopt_all is an
% n-by-num_blocks matrix. Not all blocks are necessarily visited in each iteration, but the best
% function value and corresponding point across all blocks must still be recorded.
fopt_all = nan(1, num_blocks);
xopt_all = nan(n, num_blocks);

for iter = 1:maxit

    % Save the base point and function value at the beginning of the iteration.
    xbase_iteration_start = xbase;
    fbase_iteration_start = fbase;

    % Record whether the post-poll acceleration phase accepts an update using
    % that phase's own acceptance rule.
    post_poll_acceleration_succeeded = false;

    % Pre-poll phase: try the productive directions retained from previous iterations.
    % productive_direction_memory_state packs exactly the mutable state the
    % phase may update; the terminate/exitflag update stays in this caller.
    productive_direction_memory_state = struct( ...
        'xbase', xbase, 'fbase', fbase, ...
        'nf', nf, 'fhist', fhist, 'xhist', xhist, 'invalid_points', invalid_points, ...
        'productive_direction_memory', productive_direction_memory);
    [productive_direction_memory_state, pre_poll_target_reached] = ...
        run_productive_direction_memory_phase( ...
            fun, productive_direction_memory_state, ...
            acceleration_configuration, mean(alpha_all));
    xbase = productive_direction_memory_state.xbase;
    fbase = productive_direction_memory_state.fbase;
    nf = productive_direction_memory_state.nf;
    fhist = productive_direction_memory_state.fhist;
    xhist = productive_direction_memory_state.xhist;
    invalid_points = productive_direction_memory_state.invalid_points;
    productive_direction_memory = ...
        productive_direction_memory_state.productive_direction_memory;
    if pre_poll_target_reached
        terminate = true;
        exitflag = get_exitflag("FTARGET_REACHED");
    end

    % Define block_indices, a vector that specifies both the indices of the blocks
    % and the order in which they will be visited during the current iteration.
    % The length of block_indices is equal to batch_size.
    % These blocks should not have been visited in the previous replacement_delay
    % iterations. Each completed iteration contributes batch_size entries to block_hist.
    unavailable_block_indices = unique(block_hist(max(1, (iter - replacement_delay - 1) * batch_size + 1) : ...
                                (iter-1) * batch_size), 'stable');
    available_block_indices = setdiff(1:num_blocks, unavailable_block_indices);

    % Select batch_size blocks randomly from the available blocks. The selected blocks
    % will be visited in this iteration.
    block_indices = available_block_indices(random_stream.randperm(length(available_block_indices), ...
                    batch_size));

    % Compute the direction selection probability matrix.
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

        % The pre-poll phase may already reach ftarget or exhaust the function-evaluation
        % budget. In either case, stop visiting regular-polling blocks in this iteration.
        if terminate || nf >= MaxFunctionEvaluations
            break;
        end

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
        suboptions = struct( ...
            'FunctionEvaluations_exhausted', nf, ...
            'MaxFunctionEvaluations', MaxFunctionEvaluations - nf, ...
            'ftarget', ftarget, ...
            'forcing_function', forcing_function, ...
            'reduction_factor', reduction_factor, ...
            'polling_inner', polling_inner, ...
            'cycling_inner', cycling_inner, ...
            'iprint', iprint, ...
            'i_real', i_real);

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

        % Store the base point before a possible update in this block.
        xbase_before_block = xbase;

        % Whether to update xbase and fbase. xbase serves as the "base point" for the computation
        % in the next block, meaning that reduction will be calculated with respect to xbase, as
        % shown above. The condition must be checked before updating alpha_all(i_real) because the
        % sufficient decrease is calculated based on the current step size.
        % eval_fun maps a failed NaN evaluation to Inf for algorithmic comparisons.
        % Keep the NaN clauses as defensive safeguards in case that policy changes.
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

            % The regular-polling update for this block is complete. Record the accepted
            % block displacement as one entry in the productive-direction memory. The memory
            % can retain multiple normalized directions for consideration during the pre-poll
            % phase of later iterations.
            block_step = sub_xopt - xbase_before_block;
            block_step_norm = norm(block_step);
            if options.use_productive_direction_memory && block_step_norm > alpha_tol(i_real)
                productive_direction_memory = admit_productive_direction_to_memory( ...
                    productive_direction_memory, block_step, block_step_norm, ...
                    productive_direction_memory_size);
            end
        end
    end

    % Record the step sizes after the current iteration if output_alpha_hist is true.
    % The first column stores the initial step sizes. Each subsequent column stores
    % the step sizes carried into the next iteration.
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

    % Summarize the net displacement accumulated since the beginning of the
    % current iteration for the post-poll acceleration phase.
    iteration_step = xbase - xbase_iteration_start;

    % Post-poll acceleration phase: try a pattern step, then momentum if needed.
    % The entry guard stays here to keep the phase ordering visible;
    % post_poll_acceleration_state packs exactly the mutable state the phase
    % may update.
    if ~terminate && fbase < fbase_iteration_start ...
            && norm(iteration_step) > acceleration_configuration.step_floor ...
            && nf < MaxFunctionEvaluations ...
            && (options.use_iteration_pattern_step || options.use_momentum_extrapolation)
        post_poll_acceleration_state = struct( ...
            'xbase', xbase, 'fbase', fbase, ...
            'nf', nf, 'fhist', fhist, 'xhist', xhist, 'invalid_points', invalid_points, ...
            'productive_direction_memory', productive_direction_memory, ...
            'momentum', momentum);
        [post_poll_acceleration_state, post_poll_acceleration_succeeded, ...
            post_poll_target_reached] = run_post_poll_acceleration_phase( ...
                fun, post_poll_acceleration_state, ...
                acceleration_configuration, iteration_step);
        xbase = post_poll_acceleration_state.xbase;
        fbase = post_poll_acceleration_state.fbase;
        nf = post_poll_acceleration_state.nf;
        fhist = post_poll_acceleration_state.fhist;
        xhist = post_poll_acceleration_state.xhist;
        invalid_points = post_poll_acceleration_state.invalid_points;
        productive_direction_memory = ...
            post_poll_acceleration_state.productive_direction_memory;
        momentum = post_poll_acceleration_state.momentum;
        if post_poll_target_reached
            terminate = true;
            exitflag = get_exitflag("FTARGET_REACHED");
        end
    end

    if fbase < fopt
        fopt = fbase;
        xopt = xbase;
    end

    if isnan(reference_function_value) && isfinite(fopt)
        reference_function_value = fopt;
    end

    % Track the best function value observed among the latest func_window_size iterations.
    fopt_window = [fopt_window(2:end), fopt];

    % Check if the optimization should stop due to insufficient change in the objective function
    % over the last func_window_size iterations. If the change is below a specified threshold,
    % terminate the optimization. This check is performed after the current iteration is complete,
    % ensuring fopt_window includes the latest function value.
    % Scale the thresholds with the displacement from the first finite
    % incumbent. This remains translation invariant even when the initial
    % evaluation fails. The test stays inactive until both the reference and
    % every entry of the sliding window are finite.
    if use_function_value_stop && ~post_poll_acceleration_succeeded ...
            && isfinite(reference_function_value) && all(isfinite(fopt_window))
        func_change = max(fopt_window) - min(fopt_window);
        if func_change < (func_tol * min(1, abs(fopt - reference_function_value))) || ...
                func_change < (1e-3 * func_tol * max(1, abs(fopt - reference_function_value)))
            terminate = true;
            exitflag = get_exitflag("SMALL_OBJECTIVE_CHANGE");
        end
    end

    % When sufficient decrease is not achieved in any batch, we estimate the gradient.
    if ~post_poll_acceleration_succeeded && all(batch_gradient_available)
        grad_info.sampled_direction_indices_per_batch = sampled_direction_indices_per_batch;
        grad_info.function_values_per_batch = function_values_per_batch;
        grad = estimate_gradient(grad_info);
        % A gradient estimate is available exactly when estimate_gradient returns
        % the documented n-by-1 real vector with finite components. Magnitude is
        % not a validity condition: zero and very small estimates are essential
        % for detecting stationarity, and large finite estimates remain valid.
        if isrealcolumn(grad) && numel(grad) == n && all(isfinite(grad))
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
                                                    direction_selection_probability_matrix, ...
                                                    lipschitz_constant);

                % Core gradient-stopping logic: decide whether the current estimated gradient
                % can be used to initialize reference_grad_norm. A gradient estimate is generated
                % in an iteration only when ordinary polling provides complete directional
                % information without sufficient decrease and no post-poll acceleration is
                % accepted.

                % In the core algorithm, the consistency test has exactly one purpose: deciding
                % whether reference_grad_norm may be initialized. Gradient estimates added to
                % norm_grad_window after initialization do not undergo the consistency test.
                % When use_gradient_reference_consistency is false, the current estimate becomes
                % a reference candidate without comparison with an earlier estimate. When the
                % option is true, the most recent available estimate must exist, both estimates
                % must be computed at the same xbase, and their consistency ratio is computed as
                %     norm(grad - previous_gradient) /
                %         max(1, norm(grad), norm(previous_gradient)).
                % The ratio must not exceed grad_reference_raw_tol. The estimate stored in
                % previous_gradient need not come from the immediately preceding outer iteration.
                % Passing the consistency test is necessary but not sufficient for initialization.
                % The gradient error test below must also pass. Once reference_grad_norm has
                % been initialized, the consistency test is no longer needed and is not computed.
                % Core gradient-stopping state update. Before initialization, a reliable estimate
                % establishes the fixed reference scale. After initialization, each new estimate
                % is appended to the sliding window as a conservative norm upper bound.
                if ~reference_grad_norm_initialized && options.use_gradient_reference_consistency
                    reference_candidate_reliable = ~isempty(previous_gradient) ...
                        && isequal(xbase, previous_gradient_x) ...
                        && (norm(grad - previous_gradient) / ...
                            max([1, norm(grad), norm(previous_gradient)]) ...
                            <= options.grad_reference_raw_tol);
                end
                if ~reference_grad_norm_initialized && reference_candidate_reliable ...
                        && grad_error < max(1e-3, 1e-1 * norm(grad))
                    reference_grad_norm = norm(grad) + grad_error;
                    reference_grad_norm_initialized = true;
                elseif reference_grad_norm_initialized
                    norm_grad_window = [norm_grad_window(2:end), norm(grad) + grad_error];
                end

                % The fixed reliable reference can appear well after iteration zero.
                % max(1, reference_grad_norm) supplies an absolute scale for a small reference
                % and a relative scale for a large reference.
                if reference_grad_norm_initialized ...
                        && all(norm_grad_window ...
                            < grad_tol * max(1, reference_grad_norm))
                    terminate = true;
                    exitflag = get_exitflag("SMALL_ESTIMATE_GRADIENT");
                end

                if ~reference_grad_norm_initialized ...
                        && options.use_gradient_reference_consistency
                    previous_gradient = grad;
                    previous_gradient_x = xbase;
                end

            end
        end
    end

    if ~terminate && nf >= MaxFunctionEvaluations
        terminate = true;
        exitflag = get_exitflag("MAXFUN_REACHED");
    elseif ~terminate && all(alpha_all < alpha_tol)
        terminate = true;
        exitflag = get_exitflag("SMALL_ALPHA");
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
    output.alpha_hist = alpha_hist;
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
