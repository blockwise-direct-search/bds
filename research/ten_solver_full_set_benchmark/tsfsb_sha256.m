function digest = tsfsb_sha256(file_path)
%TSFSB_SHA256 Return the SHA-256 digest of one file.
%
%   Ported from the C02 c02_sha256.m (commit 846d5c5f); falls back to
%   `shasum -a 256` when sha256sum is absent (for example on macOS).

if ~exist(file_path, 'file')
    error('tsfsb_sha256:MissingFile', ...
        'Cannot hash missing file %s.', file_path);
end
quoted_path = ['''', strrep(file_path, '''', '''"''"'''), ''''];
[status, output] = system(sprintf('sha256sum %s', quoted_path));
if status ~= 0
    [status, output] = system(sprintf('shasum -a 256 %s', quoted_path));
end
if status ~= 0
    error('tsfsb_sha256:CommandFailed', ...
        'SHA-256 hashing failed for %s: %s', file_path, output);
end
parts = strsplit(strtrim(output));
digest = parts{1};

end
