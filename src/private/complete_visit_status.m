function [latest_start, start_block, visit_complete] = complete_visit_status(last_visit_indices, complete_visit_start)
%COMPLETE_VISIT_STATUS Select the complete visits used by acceleration and stopping.
%   The earliest of the blocks' last visits is the latest start that still
%   covers every block up to the current visit. A negative index means that a
%   block has yet to appear, in which case start_block is not used.
[latest_start, start_block] = min(last_visit_indices);

%   The interval from the fixed start covers every block precisely when every
%   block has been visited at or after that start.
visit_complete = latest_start >= complete_visit_start;
end
