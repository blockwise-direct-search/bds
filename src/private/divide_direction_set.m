function [grouped_direction_indices, block_of_direction_pair] = divide_direction_set(n, num_blocks, options)
%DIVIDE_DIRECTION_SET gets indices of the directions in each block.
%   GROUPED_DIRECTION_INDICES = DIVIDE_DIRECTION_SET(n, num_blocks, options) returns a cell, where
%   the grouped_direction_indices{i} contains the indices of the directions in the i-th block.
%
%   The second output gives the block containing each positive/negative direction pair.
%
%   Notice that the direction set is in the form of [d_1, -d_1, d_2, -d_2, ..., d_n, -d_n],
%   containing 2n directions.
%
%   If the options does not contain the field of grouped_direction_indices, we divide the direction
%   set into num_blocks blocks, with the first mod(n, num_blocks) blocks containing
%   2*(floor(n/num_blocks) + 1) directions and the rest containing 2*floor(n/num_blocks) directions.
%
%   If the options contains the field of grouped_direction_indices, the grouped_direction_indices
%   should be a cell, where each cell contains the indices of the dimensions in the corresponding
%   block. Each block contains 2*length(grouped_direction_indices{i}) directions.
%   We also point out that d_i and -d_i will be assigned to the same block.
%
%   The structure of grouped_direction_indices output is different from the one in options.
%
%   Example
%     n = 11, num_blocks = 3.
%     The number of directions in each block is 4*2, 4*2, 3*2 respectively.
%     Thus grouped_direction_indices is a cell, where
%     grouped_direction_indices{1} = [1, 2, 3, 4, 5, 6, 7, 8],
%     grouped_direction_indices{2} = [9, 10, 11, 12, 13, 14, 15, 16],
%     grouped_direction_indices{3} = [17, 18, 19, 20, 21, 22].
%
%     n = 11, num_blocks = 3, options.grouped_direction_indices = {[1 3 5 7], [2 4 8], [6 9 10 11]}.
%     Then, grouped_direction_indices is a cell, where
%     grouped_direction_indices{1} = [1, 2, 5, 6, 9, 10, 13, 14],
%     grouped_direction_indices{2} = [3, 4, 7, 8, 15, 16],
%     grouped_direction_indices{3} = [11, 12, 17, 18, 19, 20, 21, 22].
%

% Set options to an empty structure if it is not provided.
if nargin < 3
    options = struct();
end

% Detect whether the input is given in the correct type.
if isfield(options, "grouped_direction_indices") && ~iscell(options.grouped_direction_indices)
    error('options.grouped_direction_indices should be a cell array.');
end
if isfield(options, "grouped_direction_indices") && ...
    length(options.grouped_direction_indices) ~= num_blocks
    error('The length of options.grouped_direction_indices should be equal to num_blocks.');
end


grouped_direction_indices = cell(1, num_blocks);

if ~isfield(options, "grouped_direction_indices") || isempty(options.grouped_direction_indices)
    % Calculate the number of dimensions assigned to each block.
    % We try to make the number of dimensions in each block as even as possible. In specific, the first
    % mod(n, num_blocks) blocks contain 2*(floor(n/num_blocks) + 1) dimensions and the rest contain
    % 2*floor(n/num_blocks) dimensions.
    num_dimensions_each_block = ones(num_blocks, 1) * floor(n / num_blocks);
    num_dimensions_each_block(1:mod(n, num_blocks)) = num_dimensions_each_block(1:mod(n, num_blocks)) + 1;

    % Compute the last and first dimension indices for each block.
    % last_dim_idx_each_block stores the ending index of each block,
    % while first_dim_idx_each_block stores the starting index of each block.
    % These indices are then used to assign the correct range of dimensions to each block.
    last_dim_idx_each_block = cumsum(num_dimensions_each_block);
    first_dim_idx_each_block = [1; last_dim_idx_each_block(1:end - 1) + 1];

    dim_indices_each_block = cell(1, num_blocks);
    for i = 1:num_blocks
        dim_indices_each_block{i} = first_dim_idx_each_block(i):last_dim_idx_each_block(i);
    end
else
    dim_indices_each_block = options.grouped_direction_indices;
end

block_of_direction_pair = zeros(n, 1);
for i = 1:num_blocks
    block_of_direction_pair(dim_indices_each_block{i}) = i;
    % Each block contains 2*length(dim_indices_each_block{i}) directions.
    % We assign the indices of the dimensions in the i-th block to the grouped_direction_indices.
    for j = dim_indices_each_block{i}
        % Each dimension j corresponds to two directions: d_j and -d_j.
        % d_j and -d_j will be assigned to the same block.
        grouped_direction_indices{i} = [grouped_direction_indices{i}, 2 * j - 1, 2 * j];
    end
end

% Check whether the output is in the right type.
if length(grouped_direction_indices) ~= num_blocks
    error('The number of blocks of grouped_direction_indices is not correct.');
end

end
