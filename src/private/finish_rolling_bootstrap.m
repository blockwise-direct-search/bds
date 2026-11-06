function rolling = finish_rolling_bootstrap(rolling, state)
%FINISH_ROLLING_BOOTSTRAP Carry the first cycle's MP state into rolling visits.
% The first complete cycle uses the existing batch MP direction and kernel.
% Its momentum belongs to the last block, as in the frozen C15 experiment.
last = size(rolling.steps, 2);
rolling.momentum(:, last) = state.momentum;
rolling.steps(:, last) = rolling.steps(:, last) ...
    + (state.xbase - rolling.last_polled);
end
