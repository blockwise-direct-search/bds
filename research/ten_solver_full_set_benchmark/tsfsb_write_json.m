function tsfsb_write_json(file_path, value)
%TSFSB_WRITE_JSON Write JSON through a temporary file and an atomic move.
%
%   Ported from the C02 c02_write_json.m (commit 846d5c5f).

parent = fileparts(file_path);
if ~exist(parent, 'dir')
    mkdir(parent);
end
temporary_path = [file_path, '.tmp'];
file_id = fopen(temporary_path, 'w');
if file_id < 0
    error('tsfsb_write_json:OpenFailed', ...
        'Cannot create temporary JSON file %s.', temporary_path);
end
cleanup = onCleanup(@() fclose(file_id));
fprintf(file_id, '%s\n', jsonencode(value, 'PrettyPrint', true));
clear cleanup
[success, message] = movefile(temporary_path, file_path, 'f');
if ~success
    error('tsfsb_write_json:MoveFailed', ...
        'Cannot move JSON file into place: %s', message);
end

end
