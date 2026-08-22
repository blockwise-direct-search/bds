function productive_direction_memory = admit_productive_direction_to_memory( ...
    productive_direction_memory, candidate_direction, candidate_step, ...
    productive_direction_memory_size)
%ADMIT_PRODUCTIVE_DIRECTION_TO_MEMORY Store a distinct productive direction.
%
%   PRODUCTIVE_DIRECTION_MEMORY = ADMIT_PRODUCTIVE_DIRECTION_TO_MEMORY(
%   PRODUCTIVE_DIRECTION_MEMORY, CANDIDATE_DIRECTION, CANDIDATE_STEP,
%   PRODUCTIVE_DIRECTION_MEMORY_SIZE) admits a nonzero candidate direction
%   when no retained direction is nearly parallel or antiparallel to it.
%
%   productive_direction_memory        Input/output ordered structure array. The first entry
%                                      has the highest priority. Its fields are listed below.
%   direction                          Normalized n-by-1 productive direction.
%   step                               Step associated with the productive direction.
%
%   candidate_direction                Real vector converted to a column and normalized before
%                                      storage. An exact zero leaves the memory unchanged.
%   candidate_step                     Scalar step stored with an admitted direction.
%   productive_direction_memory_size   Positive integer capacity. If the memory is full, its
%                                      last entry is removed before a new entry is inserted at
%                                      the front.
%
%   A candidate is treated as a duplicate when the absolute inner product
%   with a retained normalized direction is greater than 0.95. Duplicate
%   candidates leave both the entries and their priority order unchanged.

candidate_direction = candidate_direction(:);
direction_norm = norm(candidate_direction);
if direction_norm == 0
    return;
end
candidate_direction = candidate_direction / direction_norm;

is_duplicate_direction = false;
for k = 1:numel(productive_direction_memory)
    if abs(productive_direction_memory(k).direction' * candidate_direction) > 0.95
        is_duplicate_direction = true;
        break;
    end
end
if is_duplicate_direction
    return;
end
if numel(productive_direction_memory) >= productive_direction_memory_size
    productive_direction_memory(end) = [];
end
productive_direction_memory = insert_productive_direction_at_memory_front( ...
    productive_direction_memory, candidate_direction, candidate_step);

end
