function manifest = tsfsb_build_problem_manifest(user_options)
%TSFSB_BUILD_PROBLEM_MANIFEST Build and freeze the TSFSB problem manifest.
%
%   New for TSFSB. Builds the frozen problem set in three independent
%   steps: (a) metadata enumeration from probinfo_matlab.mat of the
%   frozen S2MPJ library, (b) selector enumeration through s2mpj_select
%   with the same filters and an explicitly empty excludelist, and (c) a
%   per-problem load check through s2mpj_load that verifies the
%   dimension, the unconstrained status, and the initial point, and
%   evaluates the objective once at x0. Load failures are recorded in
%   the manifest with status and error message; they are never dropped.
%   Any failure stops the build unless user_options.allow_failures is
%   true (an explicit waiver by the parent agent).
%
%   Writes problem_manifest.mat and problem_manifest.json and prints the
%   SHA-256 of both files, the problem count, and the dimension
%   distribution. When user_options.reference_problem_list points to a
%   plain text file with one problem name per line (for example the old
%   C02 problem list), the set difference against that list is printed.

if nargin < 1
    user_options = struct();
end

home_dir = getenv('HOME');
if isfield(user_options, 'optiprofiler_root') ...
        && ~isempty(user_options.optiprofiler_root)
    optiprofiler_root = user_options.optiprofiler_root;
else
    optiprofiler_root = fullfile(home_dir, 'local', 'optiprofiler_c02');
end
module_dir = fileparts(mfilename('fullpath'));
if isfield(user_options, 'output_dir') && ~isempty(user_options.output_dir)
    output_dir = user_options.output_dir;
else
    output_dir = module_dir;
end
allow_failures = isfield(user_options, 'allow_failures') ...
    && user_options.allow_failures;

addpath(fullfile(optiprofiler_root, 'matlab', 'optiprofiler', 'src'));
addpath(fullfile(optiprofiler_root, 'matlab', 'optiprofiler', ...
    'problem_libs'));
addpath(fullfile(optiprofiler_root, 'matlab', 'optiprofiler', ...
    'problem_libs', 's2mpj'));
s2mpj_dir = fileparts(which('s2mpj_select'));
if ~startsWith(s2mpj_dir, optiprofiler_root)
    error('tsfsb_build_problem_manifest:UnexpectedS2mpjSource', ...
        's2mpj_select resolves to %s, outside %s.', ...
        s2mpj_dir, optiprofiler_root);
end

% (a) Metadata enumeration, replicating the default-dimension selection
% of s2mpj_select for ptype 'u', dimensions 6 to 50, feasibility 0.
probinfo_file = fullfile(s2mpj_dir, 'probinfo_matlab.mat');
loaded = load(probinfo_file, 'probinfo');
probinfo = loaded.probinfo;
metadata_names = {};
metadata_dims = [];
for i = 2:size(probinfo, 1)
    problem_name = char(probinfo{i, 1});
    ptype = char(probinfo{i, 2});
    dim = probinfo{i, 4};
    % No additional feasibility or exclusion filter is applied here.
    if ~ismember(ptype, 'u')
        continue;
    end
    if dim >= 6 && dim <= 50
        metadata_names{end + 1} = problem_name; %#ok<AGROW>
        metadata_dims(end + 1) = dim; %#ok<AGROW>
    end
end

% (b) Selector enumeration without an exclusion option. Check below that
% the selector built-in exclusions do not remove any eligible problem.
selector_options = struct( ...
    'ptype', 'u', ...
    'mindim', 6, ...
    'maxdim', 50);
[selector_names, ~] = s2mpj_select(selector_options);
selector_names = cellfun(@char, selector_names, 'UniformOutput', false);
builtin_exclusions = { ...
    'DANWOODLS', 'MISRA1CLS', 'ROSSIMP1', 'ROSSIMP2', 'ROSSIMP3'};
intersection = intersect(metadata_names, builtin_exclusions);
fprintf('TSFSB_MANIFEST_BUILTIN_EXCLUSION_INTERSECTION %d\n', ...
    numel(intersection));
if ~isempty(intersection)
    error('tsfsb_build_problem_manifest:ExclusionIntersection', ...
        ['The metadata selection intersects the selector built-in ', ...
        'exclusions: %s. This version of the manifest builder must ', ...
        'stop here.'], strjoin(intersection, ', '));
end
if ~isequal(metadata_names, selector_names)
    only_metadata = setdiff(metadata_names, selector_names);
    only_selector = setdiff(selector_names, metadata_names);
    error('tsfsb_build_problem_manifest:SelectorMetadataMismatch', ...
        ['Metadata and selector enumerations disagree. Only metadata: ', ...
        '%s. Only selector: %s.'], strjoin(only_metadata, ', '), ...
        strjoin(only_selector, ', '));
end

% (c) Per-problem load check.
problem_names = selector_names;
problem_dims = metadata_dims;
n_problems = numel(problem_names);
records = repmat(struct( ...
    'name', '', ...
    'dim', 0, ...
    'x0_sha256', '', ...
    'x0', [], ...
    'f0', NaN, ...
    'f0_finite', false, ...
    'status', 'ok', ...
    'message', ''), 1, n_problems);
for i = 1:n_problems
    records(i).name = problem_names{i};
    records(i).dim = problem_dims(i);
    try
        problem = s2mpj_load(problem_names{i});
        if problem.n ~= problem_dims(i)
            error('tsfsb_build_problem_manifest:DimensionMismatch', ...
                'Loaded dimension %d differs from metadata dimension %d.', ...
                problem.n, problem_dims(i));
        end
        if ~strcmp(problem.ptype, 'u') || problem.mb ~= 0 || problem.mcon ~= 0
            error('tsfsb_build_problem_manifest:NotUnconstrained', ...
                'The loaded problem is not unconstrained.');
        end
        x0 = double(problem.x0(:));
        if any(~isfinite(x0))
            error('tsfsb_build_problem_manifest:InvalidInitialPoint', ...
                'The initial point is not finite.');
        end
        records(i).x0_sha256 = vector_sha256(x0);
        records(i).x0 = x0;
        f0 = problem.fun(x0);
        records(i).f0 = f0;
        records(i).f0_finite = isfinite(f0);
    catch error_record
        records(i).status = 'failed';
        records(i).message = sprintf('%s: %s', error_record.identifier, ...
            error_record.message);
    end
end
failed = find(strcmp({records.status}, 'failed'));
nonfinite_f0 = find(~[records.f0_finite] & strcmp({records.status}, 'ok'));
if ~isempty(failed)
    fprintf('TSFSB_MANIFEST_LOAD_FAILURES %s\n', ...
        strjoin({records(failed).name}, ', '));
end
if ~isempty(nonfinite_f0)
    fprintf('TSFSB_MANIFEST_NONFINITE_F0 %s\n', ...
        strjoin({records(nonfinite_f0).name}, ', '));
end
if (~isempty(failed) || ~isempty(nonfinite_f0)) && ~allow_failures
    error('tsfsb_build_problem_manifest:LoadCheckFailures', ...
        ['%d load failures and %d non-finite initial objective values. ', ...
        'Investigate before freezing, or waive explicitly with ', ...
        'user_options.allow_failures.'], ...
        numel(failed), numel(nonfinite_f0));
end

created = char(datetime('now', 'TimeZone', 'Asia/Shanghai', ...
    'Format', 'yyyy-MM-dd HH:mm:ss Z'));
config_sha256 = tsfsb_sha256(fullfile(s2mpj_dir, 'config.txt'));
s2mpj_commit = git_value(s2mpj_dir, 'rev-parse HEAD');
optiprofiler_commit = git_value(optiprofiler_root, 'rev-parse HEAD');

if ~exist(output_dir, 'dir'), mkdir(output_dir); end
mat_path = fullfile(output_dir, 'problem_manifest.mat');
json_path = fullfile(output_dir, 'problem_manifest.json');
save(mat_path, 'problem_names', 'problem_dims', 'records', ...
    'created', 'config_sha256', 's2mpj_commit', 'optiprofiler_commit', ...
    '-v7.3');

manifest = struct();
manifest.schema_version = 1;
manifest.created_at = created;
manifest.problem_library = 's2mpj';
manifest.problem_type = 'u';
manifest.minimum_dimension = 6;
manifest.maximum_dimension = 50;
manifest.problem_count = n_problems;
manifest.problem_names = problem_names;
manifest.problem_dims = problem_dims;
manifest.problems = records;
manifest.selector_metadata_agreement = true;
manifest.builtin_exclusion_intersection = intersection;
manifest.s2mpj_commit = s2mpj_commit;
manifest.optiprofiler_commit = optiprofiler_commit;
manifest.config_txt_sha256 = config_sha256;
tsfsb_write_json(json_path, manifest);

fprintf('TSFSB_MANIFEST_MAT_SHA256 %s %s\n', ...
    tsfsb_sha256(mat_path), mat_path);
fprintf('TSFSB_MANIFEST_JSON_SHA256 %s %s\n', ...
    tsfsb_sha256(json_path), json_path);
fprintf('TSFSB_MANIFEST_PROBLEM_COUNT %d\n', n_problems);
[unique_dims, ~, dim_index] = unique(problem_dims);
dim_counts = accumarray(dim_index, 1);
fprintf('TSFSB_MANIFEST_DIMENSION_DISTRIBUTION\n');
for i = 1:numel(unique_dims)
    fprintf('  dim %d: %d problems\n', unique_dims(i), dim_counts(i));
end

if isfield(user_options, 'reference_problem_list') ...
        && ~isempty(user_options.reference_problem_list)
    old_names = read_name_list(user_options.reference_problem_list);
    fprintf('TSFSB_MANIFEST_ADDED_VS_REFERENCE %s\n', ...
        strjoin(setdiff(problem_names, old_names), ', '));
    fprintf('TSFSB_MANIFEST_REMOVED_VS_REFERENCE %s\n', ...
        strjoin(setdiff(old_names, problem_names), ', '));
end

end

function digest = vector_sha256(x)

temporary_path = [tempname, '.bin'];
file_id = fopen(temporary_path, 'w');
if file_id < 0
    error('tsfsb_build_problem_manifest:TemporaryFileFailed', ...
        'Cannot create a temporary file for the x0 hash.');
end
cleanup = onCleanup(@() delete(temporary_path));
fwrite(file_id, x, 'double');
fclose(file_id);
digest = tsfsb_sha256(temporary_path);
clear cleanup

end

function names = read_name_list(list_path)

text = fileread(list_path);
names = strsplit(strtrim(text));
names = cellfun(@char, names, 'UniformOutput', false);

end

function value = git_value(path, arguments)

quoted_path = ['''', strrep(path, '''', '''"''"'''), ''''];
[status, output] = system(sprintf('git -C %s %s', quoted_path, arguments));
if status == 0
    value = strtrim(output);
else
    value = '';
end

end
