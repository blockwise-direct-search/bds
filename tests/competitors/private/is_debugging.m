function debug_flag = is_debugging()
%IS_DEBUGGING returns whether MATLAB is currently running under debug mode.

debug_flag = ~isempty(dbstack('-completenames'));

end
