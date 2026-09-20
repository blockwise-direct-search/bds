function manifest = tsfsb_verify_manifest(manifest_path)
%TSFSB_VERIFY_MANIFEST Recompute checksums for one accepted TSFSB artifact.
%
%   Ported from the C02 c02_verify_manifest.m (commit 846d5c5f); the
%   completion marker is TSFSB_COMPLETE.

if ~exist(manifest_path, 'file')
    error('tsfsb_verify_manifest:MissingManifest', ...
        'The manifest does not exist: %s', manifest_path);
end
manifest = jsondecode(fileread(manifest_path));
if ~isfield(manifest, 'status') || ~strcmp(manifest.status, 'accepted') ...
        || ~isfield(manifest, 'result_root') ...
        || ~exist(fullfile(manifest.result_root, 'TSFSB_COMPLETE'), 'file')
    error('tsfsb_verify_manifest:IncompleteArtifact', ...
        'The manifest does not describe a completed accepted artifact.');
end
if isfield(manifest, 'raw_traces')
    for j = 1:numel(manifest.raw_traces.checksums)
        item = manifest.raw_traces.checksums(j);
        assert(strcmp(tsfsb_sha256(item.path), item.sha256), 'TSFSB:RawChecksumMismatch');
    end
end
entries = manifest.artifact_checksums;
for i = 1:numel(entries)
    path = fullfile(manifest.result_root, entries(i).path);
    info = dir(path);
    if isempty(info) || info.bytes ~= entries(i).bytes ...
            || ~strcmp(tsfsb_sha256(path), entries(i).sha256)
        error('tsfsb_verify_manifest:ChecksumMismatch', ...
            'Checksum verification failed for %s.', path);
    end
end

end
