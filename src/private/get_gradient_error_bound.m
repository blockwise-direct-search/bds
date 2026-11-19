function upper_bound = get_gradient_error_bound(alpha_all, batch_size, direction_indices_per_block, ...
    n, positive_direction_set, direction_selection_probability_matrix, lipschitz_constant)
%GET_GRADIENT_ERROR_BOUND calculates an upper bound on the gradient estimation error.
%

% Create full alpha vector for all n directions
alpha_full = zeros(n, 1);
num_blocks = length(direction_indices_per_block);
% Map each block's alpha value to the corresponding directions
for i = 1:num_blocks
    % Get the direction indices for the current block
    indices = direction_indices_per_block{i};
    % Convert to positive direction indices (odd columns correspond to positive directions)
    pos_indices = ceil(indices / 2);
    % Map the current block's alpha value to the corresponding directions
    alpha_full(pos_indices) = alpha_all(i);
end

alpha_powers = alpha_full .^ 4;
direction_norms_powers = vecnorm(positive_direction_set) .^ 6;

if batch_size == num_blocks
    upper_bound = (lipschitz_constant / (6 * svds(positive_direction_set, 1, "smallest"))) * ...
        sqrt(sum(direction_norms_powers .* alpha_powers'));
else
    upper_bound = (lipschitz_constant / (6 * svds(positive_direction_set * ...
        direction_selection_probability_matrix * positive_direction_set', 1, "smallest"))) ...
        * svds(positive_direction_set, 1, "largest") ...
        * sqrt((batch_size / num_blocks) ^ 2 * sum(direction_norms_powers .* alpha_powers'));
end

end
