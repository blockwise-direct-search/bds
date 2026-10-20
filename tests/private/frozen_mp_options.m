function options = frozen_mp_options(options, n)
%FROZEN_MP_OPTIONS Add only the disabled retained fields of the frozen API.
%
%   Production no longer stores retained directions. The unmodified C04/C06
%   oracle still accepts these fields; keep its historical setting explicit.
%   Save this returned structure separately from the candidate options.

options.use_productive_direction_memory = false;
options.productive_direction_memory_size = max(1, min(n, 5));

end
