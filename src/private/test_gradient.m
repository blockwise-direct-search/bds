function test_gradient(n, seed)

% Add an optional seed parameter for reproducibility
% Default seed if not provided
if nargin < 2
    time_zone = "Asia/Shanghai";

    dt = datetime("now", "TimeZone", time_zone);
    yw = 100 * mod(year(dt), 100) + week(dt);
    seed = yw;
end

% Save current random number generator state
oldState = rng();

% Set the random seed for reproducibility
rng(seed);

if nargin < 1
    n = randi(100); % Randomly choose a dimension between 1 and 100
end

% Randomly choose the number of blocks and batch size.
% num_blocks should be at most n and at least 1.
% batch_size should be at least 1 and at most num_blocks.
num_blocks = randi(n);
batch_size = randi(num_blocks);

% Randomly generate step sizes for each block.
alpha_all = 0.01 + 0.09 * rand(num_blocks, 1);

direction_selection_probability_matrix = (batch_size / num_blocks) * eye(n);
grad_info.direction_selection_probability_matrix = direction_selection_probability_matrix;

% Divide the direction set into num_blocks blocks.
direction_indices_per_block = divide_direction_set(n, num_blocks);

% Create full alpha vector for all n directions
alpha_full = zeros(n, 1);
% Map each block's alpha value to the corresponding directions
for i = 1:num_blocks
    % Get the direction indices for the current block
    indices = direction_indices_per_block{i};
    % Convert to positive direction indices (odd columns correspond to positive directions)
    pos_indices = ceil(indices / 2);
    % Map the current block's alpha value to the corresponding directions
    alpha_full(pos_indices) = alpha_all(i);
end

% Randomly generate a point in n-dimensional space.
x = randn(n, 1);

options.direction_set = randn(n, n);
% Get the complete direction set (both positive and negative directions).
grad_info.complete_direction_set = get_direction_set(n, options);
positive_direction_set = grad_info.complete_direction_set(:, 1:2:end);

% If batch_size equals num_blocks, the gradient estimation is deterministic.
% Otherwise, we perform multiple repetitions to estimate the gradient.
if batch_size == num_blocks
    num_repetitions = 1;
else
    num_repetitions = 50;
end

grad = [];
for i = 1:num_repetitions
    grad = [grad, gradient_generator(n, num_blocks, batch_size, direction_indices_per_block, alpha_all, @(z) random_cubic_function_with_gradient(z), x, grad_info)];
end
estimated_grad = mean(grad, 2);

alpha_powers = alpha_full .^ 4;
direction_norms_powers = vecnorm(positive_direction_set) .^ 6;

[~, true_grad] = random_cubic_function_with_gradient(x);

grad_diff = norm(estimated_grad - true_grad);
if batch_size == num_blocks
    theoretical_bound = (1 / (6 * svds(positive_direction_set, 1, "smallest"))) * sqrt(sum(direction_norms_powers .* alpha_powers'));
else
    theoretical_bound = (1 / (6 * svds(positive_direction_set * direction_selection_probability_matrix * positive_direction_set', 1, "smallest"))) ...
        * svds(positive_direction_set, 1, "largest") ...
        * sqrt((batch_size / num_blocks) ^ 2 * sum(direction_norms_powers .* alpha_powers'));
end
assert(grad_diff <= theoretical_bound, 'Test failed! Actual gradient difference: %e exceeds Theoretical bound: %e', grad_diff, theoretical_bound);

fprintf('Test passed! Actual gradient difference: %e, Theoretical bound: %e\n', grad_diff, theoretical_bound);

% Restore the original random number generator state
rng(oldState);

end

function [f, grad] = random_cubic_function_with_gradient(x)
% Simple random cubic function with non-diagonal Hessian
% Maintains Lipschitz constant of Hessian = 1

time_zone = "Asia/Shanghai";

dt = datetime("now", "TimeZone", time_zone);
yw = 100 * mod(year(dt), 100) + week(dt);
seed = yw;

n = length(x);

% Save current random number generator state
oldState = rng();

rng(seed);

% Generate a random orthogonal matrix from Haar measure.
[Q, R] = qr(randn(n, n));
Q = Q * diag(sign(diag(R)));

y = Q' * x;
f = sum(y .^ 3) / 6;
grad_y = 0.5 * y .^ 2;

grad = Q * grad_y;

rng(oldState);
end
