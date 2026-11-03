function plot_threshold_results(seed_index, feature_indices)
%PLOT_THRESHOLD_RESULTS Export native profiles from completed paired runs.
%
%   seed_index                         1 or 2; seeds are never pooled.
%   feature_indices                    Subset of the six frozen features.
%
%   No solver or problem function is called. The original experiment verified
%   every trajectory against the both-off history before saving each case.
%   This adapter restores the corresponding prefixes and uses true returned
%   values, not noisy solver outputs. Native benchmark(load) recomputes the
%   targets from the two selected solvers independently for each run.

root = '/home/lhtian97/Work/bds_gradient_threshold_20261030';
destination = '/home/lhtian97/Work/bds_gradient_threshold_plots_20261102';
bundle = '/home/lhtian97/Work/c04_external_comparison_20261010/bundle_r8';
opti = fullfile(bundle, 'optiprofiler', 'matlab', 'optiprofiler');
addpath(opti, fullfile(opti, 'src'), fullfile(opti, 'problem_libs'), ...
    fullfile(opti, 'problem_libs', 's2mpj'), fullfile(bundle, 'helpers'));
assert(strcmp(which('benchmark'), fullfile(opti, 'src', 'benchmark.m')));
assert(contains(fileread(fullfile(root, 'run.status')), 'completed exit_code=0'));
assert(ismember(seed_index, [1, 2]));
features = {'plain', 'noisy_1e-4', 'noisy_1e-2', 'linearly_transformed', ...
    'linearly_transformed_noisy_1e-4', 'linearly_transformed_noisy_1e-2'};
assert(all(ismember(feature_indices, 1:6)));
manifest = jsondecode(fileread(fullfile(root, 'problem_manifest.json')));
source_manifest_hash = tsfsb_sha256(fullfile(root, 'CONTROL_MANIFEST.json'));
seed_bases = [20260828, 20261030];
seed_name = sprintf('seed%d', seed_index);
names = reshape(cellstr(manifest.problem_names), 1, []);
dimensions = [manifest.problems.dim]';
assert(numel(names) == 133 && all(dimensions >= 6 & dimensions <= 50));
assert(isequal(names, {manifest.problems.name}));

for feature_index = feature_indices
    feature_name = features{feature_index};
    repeats = 5;
    if feature_index == 1, repeats = 1; end
    job = fullfile(destination, seed_name, feature_name);
    assert(~isfolder(job), 'ThresholdPlots:ExistingJob', 'Already exists: %s', job);
    mkdir(job);
    input_directory = fullfile(job, 'input', 'test_log');
    mkdir(input_directory);
    number_problems = numel(names);
    max_evaluations = 500 * max(dimensions);
    data = struct('plib', 's2mpj', 'ptype', 'u', 'mindim', 6, 'maxdim', 50);
    for key = {'minb', 'maxb', 'minlcon', 'maxlcon', 'minnlcon', 'maxnlcon', 'mincon', 'maxcon'}
        data.(key{1}) = 0;
    end
    data.problem_names_options = names;
    data.excludelist = {};
    data.feature_stamp = feature_name;
    data.solver_names = {'BDS-old', 'BDS-new'};
    data.problem_names = names;
    data.problem_types = repmat({'u'}, number_problems, 1);
    data.problem_dims = dimensions;
    for key = {'problem_mbs', 'problem_mlcons', 'problem_mnlcons', 'problem_mcons'}
        data.(key{1}) = zeros(number_problems, 1);
    end
    data.fun_histories = nan(number_problems, 2, repeats, max_evaluations);
    data.maxcv_histories = zeros(size(data.fun_histories));
    data.fun_outs = nan(number_problems, 2, repeats);
    data.maxcv_outs = zeros(size(data.fun_outs));
    data.fun_inits = nan(number_problems, repeats);
    data.maxcv_inits = zeros(size(data.fun_inits));
    data.n_evals = nan(size(data.fun_outs));
    data.computation_times = nan(size(data.fun_outs));
    data.solvers_successes = false(size(data.fun_outs));
    sources = struct('file', {}, 'sha256', {});
    total_calls = zeros(1, 6);
    for p = 1:number_problems
        for r = 1:repeats
            file = fullfile(root, seed_name, sprintf('f%d_p%03d_r%d.mat', feature_index, p, r));
            before_hash = tsfsb_sha256(file);
            loaded = load(file, 'result');
            result = loaded.result;
            assert(result.all_prefixes_and_counts_verified);
            assert(strcmp(result.task.problem, names{p}) && result.task.problem_index == p);
            assert(strcmp(result.task.feature, feature_name) && result.task.feature_index == feature_index);
            assert(result.task.repeat == r && result.task.seed_base == seed_bases(seed_index));
            assert(isequal(result.labels, {'B', 'F', 'G_old', 'G_new', 'FG_old', 'FG_new'}));
            assert(all([result.outcomes.calls] <= 500 * dimensions(p)));
            assert(numel(result.baseline_truth) == result.outcomes(1).calls);
            assert(result.outcomes(6).calls >= result.outcomes(5).calls);
            data.fun_inits(p, r) = result.initial_value;
            total_calls = total_calls + [result.outcomes.calls];
            for s = 1:2
                outcome = result.outcomes(s + 4);
                assert(outcome.function_stop && outcome.gradient_stop);
                assert(outcome.dual_threshold == (s == 2));
                assert(numel(outcome.xopt) == dimensions(p));
                n = outcome.calls;
                assert(outcome.output_index >= 1 && outcome.output_index <= n);
                assert(isequaln(outcome.returned_truth, result.baseline_truth(outcome.output_index)));
                history = reshape(result.baseline_truth(1:n), 1, 1, 1, []);
                data.fun_histories(p, s, r, 1:n) = history;
                % Match native solveOneProblem: repeat the last value after nf.
                data.fun_histories(p, s, r, n+1:end) = history(end);
                data.fun_outs(p, s, r) = outcome.returned_truth;
                data.n_evals(p, s, r) = n;
                data.computation_times(p, s, r) = outcome.seconds;
                data.solvers_successes(p, s, r) = any(isfinite(history(:)));
                assert(isequaln(reshape(data.fun_histories(p, s, r, 1:n), [], 1), ...
                    reshape(result.baseline_truth(1:n), [], 1)));
            end
            assert(strcmp(before_hash, tsfsb_sha256(file)));
            sources(end+1) = struct('file', file, 'sha256', before_hash);
        end
    end
    data.merit_histories = data.fun_histories;
    data.merit_outs = data.fun_outs;
    data.merit_inits = data.fun_inits;
    results_plibs = {data};
    input_file = fullfile(input_directory, 'data_for_loading.mat');
    save(input_file, 'results_plibs', '-v7.3');
    input_hash = tsfsb_sha256(input_file);
    marker = fopen(fullfile(input_directory, 'time_stamp_20261102_000000.txt'), 'w');
    assert(marker >= 0);
    fprintf(marker, 'Adapter of completed paired runs; zero new solver evaluations.\n');
    fclose(marker);
    tsfsb_write_json(fullfile(job, 'SOURCES.json'), sources);

    options = tsfsb_feature_options(struct('name', feature_name, 'n_runs', repeats));
    options.load = '20261102_000000';
    options.solvers_to_load = [1, 2];
    options.solver_names = data.solver_names;
    options.benchmark_id = '.';
    options.savepath = fullfile(job, 'native');
    options.draw_hist_plots = 'none';
    options.max_tol_order = 4;
    options.errorbar_type = 'minmax';
    options.semilogx = true;
    options.line_colors = [0, 0.447, 0.741; 0.85, 0.325, 0.098];
    options.line_styles = {'-', '--'};
    options.line_widths = [1.8, 1.8];
    options.summarize_performance_profiles = true;
    options.summarize_data_profiles = false;
    options.summarize_log_ratio_profiles = false;
    options.summarize_output_based_profiles = true;
    options.max_eval_factor = 500;
    options.n_jobs = 1;
    options.seed = seed_bases(seed_index);
    options.run_plain = false;
    options.silent = false;
    cd(fullfile(job, 'input'));
    benchmark(options);
    exported = tsfsb_locate_result(options.savepath);
    reloaded = load(exported.data_file, 'results_plibs');
    assert(isequaln(reloaded.results_plibs{1}, data), ...
        'ThresholdPlots:ChangedData', 'Native loading changed the adapted data.');
    curves = load(exported.curves_file, 'curves');
    for order = 1:4
        expected = tsfsb_recompute_perf_curves(data, 10^(-order));
        for s = 1:2
            actual = curves.curves{order}.hist.perf{s, end};
            assert(isequal(size(actual), size(expected{s})));
            assert(max(abs(actual(:) - expected{s}(:))) <= 1e-10);
        end
    end
    assert(strcmp(input_hash, tsfsb_sha256(input_file)));
    for i = 1:numel(sources)
        assert(strcmp(sources(i).sha256, tsfsb_sha256(sources(i).file)));
    end
    assert(strcmp(source_manifest_hash, tsfsb_sha256(fullfile(root, 'CONTROL_MANIFEST.json'))));

    delivery = fullfile(destination, 'delivery', seed_name, feature_name);
    mkdir(delivery);
    copyfile(exported.performance_history_pdf, fullfile(delivery, 'history_all_tolerances.pdf'));
    copyfile(exported.performance_output_pdf, fullfile(delivery, 'output_all_tolerances.pdf'));
    for order = [2, 4]
        panel = dir(fullfile(exported.root, 'detailed_profiles', '*history*', sprintf('perf_hist_%d.pdf', order)));
        assert(isscalar(panel));
        copyfile(fullfile(panel.folder, panel.name), fullfile(delivery, sprintf('history_tau_1e-%d.pdf', order)));
    end
    copyfile(exported.curves_file, fullfile(delivery, 'curves.mat'));
    pdfs = dir(fullfile(delivery, '*.pdf'));
    hashes = struct();
    for i = 1:numel(pdfs)
        hashes.(matlab.lang.makeValidName(pdfs(i).name)) = tsfsb_sha256(fullfile(delivery, pdfs(i).name));
    end
    report = struct('status', 'verified', 'seed', seed_bases(seed_index), ...
        'feature', feature_name, 'n_problems', number_problems, 'n_runs', repeats, ...
        'selected_labels', {{'FG_old', 'FG_new'}}, 'all_variant_total_calls', total_calls, ...
        'new_solver_calls', 0, 'native_data_exact_match', true, ...
        'native_curve_check_orders', 1:4, 'source_files_unchanged', true, ...
        'input_sha256', input_hash, 'control_manifest_sha256', source_manifest_hash, ...
        'benchmark_sha256', tsfsb_sha256(which('benchmark')), ...
        'script_sha256', tsfsb_sha256([mfilename('fullpath'), '.m']), ...
        'pdf_postprocessing', false, 'pdf_sha256', hashes, 'native_result', exported);
    tsfsb_write_json(fullfile(delivery, 'VERIFIED.json'), report);
    copyfile(fullfile(job, 'SOURCES.json'), fullfile(delivery, 'SOURCES.json'));
    fprintf('THRESHOLD_NATIVE_PLOTS_OK %s %s old_nf=%d new_nf=%d\n', ...
        seed_name, feature_name, total_calls(5), total_calls(6));
    close all;
    clear data results_plibs reloaded;
end
end
