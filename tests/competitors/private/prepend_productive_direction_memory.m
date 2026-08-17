function productive_direction_memory = prepend_productive_direction_memory( ...
    productive_direction_memory, direction, step)
%PREPEND_PRODUCTIVE_DIRECTION_MEMORY Put one entry at the highest priority.
%
%   PRODUCTIVE_DIRECTION_MEMORY = PREPEND_PRODUCTIVE_DIRECTION_MEMORY(
%   PRODUCTIVE_DIRECTION_MEMORY, DIRECTION, STEP) constructs one memory entry
%   and inserts it before all existing entries.
%
%   productive_direction_memory        Input/output ordered structure array with fields
%                                      direction and step. The first entry has the highest
%                                      priority. An empty input is replaced by the new entry.
%   direction                          Vector stored as a column. This helper does not normalize
%                                      its magnitude or check for a retained duplicate.
%   step                               Scalar stored as a double. This helper does not enforce
%                                      the memory capacity.
%
%   Duplicate detection, direction normalization, and the capacity rule belong
%   to the caller.

memory_entry.direction = direction(:);
memory_entry.step = double(step);
if isempty(productive_direction_memory)
    productive_direction_memory = memory_entry;
else
    productive_direction_memory = [memory_entry, productive_direction_memory];
end

end
