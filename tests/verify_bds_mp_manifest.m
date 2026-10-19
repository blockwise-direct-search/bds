function summary = verify_bds_mp_manifest(manifest_file, result_directory, mode)
%VERIFY_BDS_MP_MANIFEST Compare all 133 frozen S2MPJ problems, without exclusions.
%
%   MODE='full' checks both internal and external paper settings on the whole
%   manifest. MODE='smoke' checks the first two entries only. S2MPJ_LOAD must
%   resolve to the frozen dependency. This is a plain trajectory regression,
%   not an OptiProfiler performance experiment. Each pair uses a fresh problem
%   instance and the same RNG state; the budget remains 500*n.

assert(ismember(mode, {'smoke', 'full'}));
manifest = load(manifest_file);
assert(numel(manifest.problem_names) == 133);
assert(all(manifest.problem_dims >= 6 & manifest.problem_dims <= 50));
indices = 1:133;
if strcmp(mode, 'smoke')
    indices = 1:2;
end
summary = struct('internal_passed', 0, 'external_passed', 0, 'failed', 0, 'skipped', 0);
original_random_state = rng();
cleanup = onCleanup(@() rng(original_random_state));
for experiment_cell = {'internal', 'external'}
    experiment = experiment_cell{1};
    for index = indices
        name = manifest.problem_names{index};
        problem = s2mpj_load(name);
        x0 = problem.x0;
        assert(numel(x0) == manifest.problem_dims(index));
        options = bds_paper_options(x0, experiment, 'mp');
        options.output_xhist = true;
        options.output_alpha_hist = true;
        options.output_block_hist = true;
        options.output_grad_hist = true;
        rng(20260828);
        random_state = rng();
        elapsed = tic;
        candidate = record_bds_execution(@bds, @(x) problem.fun(x), x0, options, random_state);
        problem = s2mpj_load(name);
        reference = record_bds_execution(@c03_bds_mp, @(x) problem.fun(x), x0, options, random_state);
        seconds = toc(elapsed);
        evidence_file = fullfile(result_directory, sprintf('%s-%03d-%s.mat', experiment, index, name));
        save(evidence_file, 'candidate', 'reference', 'options', 'x0', 'random_state', 'seconds', 'name');
        assert(isequaln(candidate, reference), ...
            'verify_bds_mp_manifest:Mismatch', 'Complete trajectories differ: %s', evidence_file);
        summary.([experiment, '_passed']) = summary.([experiment, '_passed']) + 1;
        save(fullfile(result_directory, 'summary.mat'), 'summary');
        fprintf('MP_MANIFEST_PASS %s %d/133 %s n=%d nf=%d seconds=%.3f\n', ...
            experiment, index, name, numel(x0), candidate.output.funcCount, seconds);
    end
end

end
