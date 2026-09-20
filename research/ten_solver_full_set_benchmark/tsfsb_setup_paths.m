function report = tsfsb_setup_paths(mode, dependency_roots)
%TSFSB_SETUP_PATHS Client and worker path setup for the TSFSB benchmark.
%
%   New for TSFSB. REPORT = TSFSB_SETUP_PATHS() adds the repository and
%   dependency paths to the MATLAB path of the client and returns a
%   report struct recording, for every required function, the paths
%   resolved by WHICH('-all', ...). The function errors if any function
%   resolves to an unexpected location, for example the other
%   OptiProfiler copy or a bds outside this repository's src.
%
%   TSFSB_SETUP_PATHS('verify_workers') checks that every worker of the
%   current parallel pool resolves the same paths as the client. It is
%   intended to be called after pool creation: OptiProfiler parfor
%   workers inherit the client path at pool creation, so the worker
%   check proves that NOMAD, PRIMA, and BFO MEX paths are visible on the
%   workers.
%
%   TSFSB_SETUP_PATHS(..., ROOTS) overrides the default dependency
%   roots. ROOTS is a struct with optional fields repo, optiprofiler,
%   prima, nomad, bfo. The defaults match the frozen server layout.

if nargin < 1 || isempty(mode)
    mode = 'client';
end
mode = char(mode);

roots = default_roots();
if nargin >= 2 && ~isempty(dependency_roots)
    names = fieldnames(dependency_roots);
    for i = 1:numel(names)
        if ~isfield(roots, names{i})
            error('tsfsb_setup_paths:UnknownRoot', ...
                'Unknown dependency root field ''%s''.', names{i});
        end
        roots.(names{i}) = char(dependency_roots.(names{i}));
    end
end

required_names = { ...
    'bds', 'benchmark', 's2mpj_select', 's2mpj_load', 'newuoa', ...
    'nomadOpt', 'bfo', 'pds', 'lam_paper_exact', 'fminsearch', ...
    'fminunc'};

switch mode
    case 'client'
        add_dependency_paths(roots);
        report = check_resolution(required_names, roots);
        report.mode = 'client';
        report.roots = roots;
    case 'verify_workers'
        report = check_resolution(required_names, roots);
        worker_reports = resolution_on_workers(required_names);
        for i = 1:numel(worker_reports)
            for j = 1:numel(required_names)
                name = matlab.lang.makeValidName(required_names{j});
                if ~isequal(worker_reports{i}.(name), report.(name))
                    error('tsfsb_setup_paths:WorkerPathMismatch', ...
                        ['Worker %d resolves %s differently from the ', ...
                        'client. The pool does not inherit the runner path.'], ...
                        i, required_names{j});
                end
            end
        end
        report.mode = 'verify_workers';
        report.roots = roots;
        report.worker_count = numel(worker_reports);
    otherwise
        error('tsfsb_setup_paths:InvalidMode', ...
            'Unknown mode ''%s''.', mode);
end

end

function roots = default_roots()

home_dir = getenv('HOME');
module_dir = fileparts(mfilename('fullpath'));
roots = struct();
roots.repo = fileparts(fileparts(module_dir));
roots.optiprofiler = fullfile(home_dir, 'local', 'optiprofiler_c02');
roots.prima = fullfile(home_dir, 'local', 'prima');
roots.nomad = fullfile(home_dir, 'local', 'nomad');
roots.bfo = fullfile(home_dir, 'local', 'BFO');

end

function add_dependency_paths(roots)

% The later an entry is added, the higher it ranks on the MATLAB path
% (addpath prepends). The frozen optiprofiler_c02 copy must therefore be
% added after PRIMA, NOMAD, and BFO so that it shadows any other
% OptiProfiler copy already on the path.
candidates = { ...
    roots.bfo, ...
    fullfile(roots.bfo, 'src'), ...
    fullfile(roots.bfo, 'matlab'), ...
    fullfile(roots.nomad, 'build', 'release', 'lib'), ...
    fullfile(roots.nomad, 'interfaces', 'Matlab_MEX', 'Functions'), ...
    fullfile(roots.nomad, 'build', 'release', 'interfaces', 'Matlab_MEX'), ...
    fullfile(roots.prima, 'matlab', 'interfaces'), ...
    fullfile(roots.optiprofiler, 'matlab', 'optiprofiler'), ...
    fullfile(roots.optiprofiler, 'matlab', 'optiprofiler', 'problem_libs'), ...
    fullfile(roots.optiprofiler, 'matlab', 'optiprofiler', 'problem_libs', ...
        's2mpj'), ...
    fullfile(roots.optiprofiler, 'matlab', 'optiprofiler', 'src'), ...
    fullfile(roots.repo, 'research', 'ten_solver_full_set_benchmark'), ...
    fullfile(roots.repo, 'tests', 'competitors'), ...
    fullfile(roots.repo, 'src')};
for i = 1:numel(candidates)
    if exist(candidates{i}, 'dir')
        addpath(candidates{i});
    end
end

end

function report = check_resolution(required_names, roots)

report = struct();
for i = 1:numel(required_names)
    name = required_names{i};
    resolved = which(name, '-all');
    if iscell(resolved)
        resolved = strtrim(resolved);
    else
        resolved = {strtrim(resolved)};
    end
    report.(matlab.lang.makeValidName(name)) = resolved;
    if isempty(resolved) || all(cellfun(@isempty, resolved))
        error('tsfsb_setup_paths:MissingDependency', ...
            'Cannot resolve required function %s.', name);
    end
end

expected_bds = fullfile(roots.repo, 'src', 'bds.m');
if ~strcmp(report.bds{1}, expected_bds)
    error('tsfsb_setup_paths:UnexpectedBdsSource', ...
        'Expected production BDS at %s and found %s.', ...
        expected_bds, report.bds{1});
end
optiprofiler_functions = {'benchmark', 's2mpj_select', 's2mpj_load'};
for i = 1:numel(optiprofiler_functions)
    name = optiprofiler_functions{i};
    first = report.(matlab.lang.makeValidName(name)){1};
    if ~startsWith(first, [roots.optiprofiler, filesep])
        error('tsfsb_setup_paths:UnexpectedOptiProfilerSource', ...
            ['Expected %s under the frozen OptiProfiler copy %s and ', ...
            'found %s. Another OptiProfiler copy may shadow it.'], ...
            name, roots.optiprofiler, first);
    end
end
if ~startsWith(report.newuoa{1}, [roots.prima, filesep])
    error('tsfsb_setup_paths:UnexpectedPrimaSource', ...
        'Expected newuoa under %s and found %s.', ...
        roots.prima, report.newuoa{1});
end
if ~startsWith(report.nomadOpt{1}, [roots.nomad, filesep])
    error('tsfsb_setup_paths:UnexpectedNomadSource', ...
        'Expected nomadOpt under %s and found %s.', ...
        roots.nomad, report.nomadOpt{1});
end
if ~startsWith(report.bfo{1}, [roots.bfo, filesep])
    error('tsfsb_setup_paths:UnexpectedBfoSource', ...
        'Expected bfo under %s and found %s.', roots.bfo, report.bfo{1});
end
expected_pds = fullfile(roots.repo, 'tests', 'competitors', 'pds.m');
if ~strcmp(report.pds{1}, expected_pds)
    error('tsfsb_setup_paths:UnexpectedPdsSource', ...
        'Expected PDS at %s and found %s.', expected_pds, report.pds{1});
end
expected_lam = fullfile(roots.repo, 'tests', 'competitors', ...
    'lam_paper_exact.m');
if ~strcmp(report.lam_paper_exact{1}, expected_lam)
    error('tsfsb_setup_paths:UnexpectedLamSource', ...
        'Expected paper-exact LAM at %s and found %s.', ...
        expected_lam, report.lam_paper_exact{1});
end

end

function worker_reports = resolution_on_workers(required_names)

pool = gcp('nocreate');
if isempty(pool)
    error('tsfsb_setup_paths:MissingPool', ...
        'verify_workers requires an existing parallel pool.');
end
futures = parfevalOnAll(pool, @resolve_required, 1, required_names);
worker_reports = fetchOutputs(futures);
if ~iscell(worker_reports)
    worker_reports = {worker_reports};
end

end

function report = resolve_required(required_names)

report = struct();
for i = 1:numel(required_names)
    resolved = which(required_names{i}, '-all');
    if iscell(resolved)
        resolved = strtrim(resolved);
    else
        resolved = {strtrim(resolved)};
    end
    report.(matlab.lang.makeValidName(required_names{i})) = resolved;
end

end
