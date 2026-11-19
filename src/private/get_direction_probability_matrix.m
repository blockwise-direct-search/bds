function direction_selection_probability_matrix = get_direction_probability_matrix(n, batch_size, ...
    grouped_direction_indices, available_block_indices)
% GET_DIRECTION_PROBABILITY_MATRIX calculates the probability of each direction being selected and
% returns a diagonal matrix where the i-th diagonal element represents the probability of selecting
% the i-th direction. Directions that are not eligible to be selected in this iteration are assigned
% a probability of 0.

% Initialize a vector to hold probabilities for each direction. The vector is initialized
% with zeros because directions that are not eligible to be selected in this iteration
% should have a selection probability of 0.
direction_probabilities = zeros(n, 1);

% Calculate how many blocks are available to be selected in this iteration.
num_available_blocks = length(available_block_indices);

% Calculate the probability for those directions in the available blocks.
if num_available_blocks > 0
    % For the available blocks, each block is assigned an equal probability of being selected.
    % Although it is theoretically possible to assign non-uniform probabilities to the blocks,
    % we choose equal probabilities for simplicity and ease of implementation.
    block_selection_probability = batch_size / num_available_blocks;

    % Calculate the probability for each direction based on the probability of selecting each
    % block. For each available block, the block's selection probability is assigned to all
    % directions within that block. Since each direction has both a positive and a negative
    % component (e.g., d_i and -d_i), the same probability is assigned to both components.
    for i = 1:num_available_blocks
        % Get the indices of the directions in the available_block_indices(i)-th block.
        % Note: The available_block_indices array may not be in sequential order, as blocks
        % can be shuffled or selected randomly in this iteration. This does not affect the
        % probability assignment, as each block's probability is calculated independently.
        direction_indices = grouped_direction_indices{available_block_indices(i)};
        % Extract the primary forward directions (e.g., d_i) from the given indices, excluding
        % their negative counterparts (e.g., -d_i).
        primary_direction_indices = direction_indices(mod(direction_indices, 2) == 1);
        direction_probabilities((primary_direction_indices + 1) / 2) = block_selection_probability;
    end
else
    error('No available blocks to be selected, which should not happen.');
end

% Create diagonal matrix with the probabilities.
direction_selection_probability_matrix = diag(direction_probabilities);

end
