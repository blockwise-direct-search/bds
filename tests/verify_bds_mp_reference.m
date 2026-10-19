function summary = verify_bds_mp_reference(result_directory, mode)
%VERIFY_BDS_MP_REFERENCE Strict MP verification with iseqiv and complete traces.
%
%   SUMMARY = VERIFY_BDS_MP_REFERENCE(RESULT_DIRECTORY, MODE) requires BDS,
%   C03_BDS_MP (the unmodified frozen reference), and BDS_PAPER_OPTIONS on the
%   path. MODE is 'smoke' or 'full'. Each case saves the effective options,
%   initial point, RNG state, full objective traces, and all solver outputs.
%   Fixed internal/external paper settings and randomized option stress tests
%   are separate suites. Nothing is truncated or compared with a tolerance.

assert(ismember(mode, {'smoke', 'full'}));
assert(~strcmp(which('bds'), which('c03_bds_mp')) && ~isempty(which('c03_bds_mp')));
assert(isfolder(result_directory));
seeds = [12345,23456,34567];
dimensions = 1:10;
runs = 0:20;
if strcmp(mode, 'smoke')
    seeds = seeds(1); dimensions = [1,3]; runs = [0,1,5,7,12,16,20];
end
summary = struct('iseqiv_passed', 0, 'full_trace_passed', 0, 'failed', 0);
first_record = []; second_record = []; effective_options = []; random_state = [];
effective_x0 = []; evidence_file = ''; suite = '';
for suite_cell = {'internal', 'external', 'stress'}
    suite = suite_cell{1};
    for seed = seeds
        for n = dimensions
            p.name = sprintf('MP-%s-n%d', suite, n);
            p.x0 = (1:n)' / 3;
            p.objective = @(x) sum(((diag(1:n) + 0.1 * ones(n)) ...
                * (x(:) - ((-1).^(1:n))' .* (1:n)' / 5)).^2) + 0.01*sum(sin(x(:)));
            for ir = runs
                evidence_file = fullfile(result_directory, ...
                    sprintf('%s-%d-%d-%d.mat', suite, seed, n, ir));
                options = struct('seed', seed, 'Algorithm', 'cbds', ...
                    'noninteractive', true, 'failure_directory', result_directory, ...
                    'sequential', false);
                assert(iseqiv({@candidate_solver, @reference_solver}, p, ir, true, 0, options));
                summary.iseqiv_passed = summary.iseqiv_passed + 1;
                summary.full_trace_passed = summary.full_trace_passed + 1;
                save(fullfile(result_directory, 'summary.mat'), 'summary');
                fprintf('MP_STRICT_PASS %s seed=%d n=%d ir=%d total=%d\n', ...
                    suite, seed, n, ir, summary.iseqiv_passed);
            end
        end
    end
end

    function [x, f, flag, output] = candidate_solver(fun, x0, generated_options)
        if strcmp(suite, 'stress')
            effective_options = bds_paper_options(x0, 'external', 'mp');
        else
            effective_options = bds_paper_options(x0, suite, 'mp');
        end
        % Only the stress suite lets iseqiv override the paper parameters.
        if strcmp(suite, 'stress')
            names = fieldnames(generated_options);
            for k = 1:numel(names)
                effective_options.(names{k}) = generated_options.(names{k});
            end
        end
        effective_options.output_xhist = true;
        effective_options.output_alpha_hist = true;
        effective_options.output_block_hist = true;
        effective_options.output_grad_hist = true;
        random_state = rng();
        effective_x0 = x0;
        first_record = record_bds_execution(@bds, fun, x0, effective_options, random_state);
        x = first_record.xopt; f = first_record.fopt;
        flag = first_record.exitflag; output = first_record.output;
    end

    function [x, f, flag, output] = reference_solver(fun, x0, generated_options)
        second_record = record_bds_execution(@c03_bds_mp, fun, x0, effective_options, random_state);
        save(evidence_file, 'effective_options', 'generated_options', 'effective_x0', ...
            'random_state', 'first_record', 'second_record');
        assert(isequaln(first_record, second_record), ...
            'verify_bds_mp_reference:FullTraceMismatch', 'Full trace differs: %s', evidence_file);
        x = second_record.xopt; f = second_record.fopt;
        flag = second_record.exitflag; output = second_record.output;
    end

end
