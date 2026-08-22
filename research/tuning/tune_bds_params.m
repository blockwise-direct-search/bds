function [x_best, f_min] = tune_bds_params(x0, rhobeg, rhoend, maxfun, mindim, maxdim, plibs, is_noisy)
% TUNE_BDS_PARAMS Tunes the hyperparameters of BDS (expand and shrink).
%
%   Input:
%   x0       The initial value [expand, shrink]. Normally [2.0, 0.5].
%   rhobeg   Initial size of the trust region. Normally 0.2.
%   rhoend   Final size of the trust region. Normally 1e-2.
%   maxfun   Maximum number of function evaluations.
%   mindim   Minimum dimension of the problem.
%   maxdim   Maximum dimension of the problem.
%   plibs    Libraries for performance profile ('s2mpj', 'matcutest', or {'matcutest', 's2mpj'}).
%   is_noisy Whether to evaluate on noisy features.

options = struct();
options.rhobeg = rhobeg;
options.rhoend = rhoend;
options.maxfun = maxfun;
options.output_xhist = true; % Enable history tracking of x values

% =========================================================================
% 1. Optimization Phase
% =========================================================================
% Bounds: expand > 1, 0 < shrink < 1
lb = [1 + eps, eps];
ub = [10.0, 1 - eps]; % Replaced inf with 10.0 for stability

[xopt, fopt, ~, output_tuning] = ...
    bobyqa(@(x)eval_profile_obj(x, plibs, mindim, maxdim, is_noisy), x0, lb, ub, options);

x_best = xopt;
f_min = fopt;

% =========================================================================
% 2. Data Logging Phase
% =========================================================================
time_str = char(datetime('now', 'Format', 'yy_MM_dd_HH_mm'));
plibs_stamp = get_plibs_stamp(plibs);
if is_noisy
    subfolder_name = sprintf('cbds_tuning_expand_shrink_noise_%d_%d_%d_%s_%s', ...
        mindim, maxdim, options.maxfun, plibs_stamp, time_str);
else
    subfolder_name = sprintf('cbds_tuning_expand_shrink_%d_%d_%d_%s_%s', ...
        mindim, maxdim, options.maxfun, plibs_stamp, time_str);
end

current_path = mfilename("fullpath");
path_current_dir = fileparts(current_path);

% Define the main tuning_data folder
path_tuning_main = fullfile(path_current_dir, "tuning_data");

% Define the specific subfolder for this specific run
path_tuning_sub = fullfile(path_tuning_main, subfolder_name);

% Create the directories if they do not exist
if ~exist(path_tuning_sub, "dir")
    mkdir(path_tuning_sub);
end

% Save tuning history to txt strictly inside the subfolder
filePath = fullfile(path_tuning_sub, "tune_results.txt");
fileID = fopen(filePath, 'w');

% Record initial values
initial_value_record = strjoin(string(x0(:)'), ', ');
fprintf(fileID, 'initial_value: %s\n', initial_value_record);

% Record optimized values
best_value_record = strjoin(string(xopt(:)'), ', ');
fprintf(fileID, 'optimized_value: %s\n', best_value_record);
fprintf(fileID, 'optimized_fval: %f\n\n', fopt);

% Extract and print xhist and fhist together
has_history = isfield(output_tuning, 'xhist') && isfield(output_tuning, 'fhist');
if has_history
    fprintf(fileID, 'xhist & fhist:\n');
    x_trans = output_tuning.xhist';
    f_vec = output_tuning.fhist(:);
    
    rows = min(size(x_trans, 1), length(f_vec));
    cols = size(x_trans, 2);
    
    for row = 1:rows
        for col = 1:cols
            fprintf(fileID, '%-15s', num2str(x_trans(row, col)));
        end
        fprintf(fileID, '%-15s\n', num2str(f_vec(row)));
    end
end

% Record the rest of bobyqa output structure
output_tuning_saved = trim_struct(output_tuning); 
output_fields = fieldnames(output_tuning_saved);

for i = 1:numel(output_fields)
    field = output_fields{i};
    
    % Skip xhist and fhist as they are already printed
    if has_history && (strcmp(field, 'xhist') || strcmp(field, 'fhist'))
        continue;
    end
    
    value = output_tuning_saved.(field);
    
    if ~iscell(value)
        if isnumeric(value)
            if isvector(value)
                val_str = strjoin(string(value(:)'), ', ');
                fprintf(fileID, '%s: %s\n', field, val_str);
            elseif ismatrix(value)
                fprintf(fileID, '%s:\n', field);
                % Transpose the matrix to print row by row with left alignment
                val_trans = value';
                [rows, cols] = size(val_trans);
                for row = 1:rows
                    for col = 1:cols
                        fprintf(fileID, '%-15s', num2str(val_trans(row, col)));
                    end
                    fprintf(fileID, '\n');
                end
            end
        elseif ischar(value) || isstring(value)
            fprintf(fileID, '%s: %s\n', field, value);
        end
    else
        fprintf(fileID, '%s:\n', field);
        for j = 1:length(value)
            fprintf(fileID, '%s\n', value{j});
        end
    end
end
fclose(fileID);

% =========================================================================
% 3. Visualization Phase
% =========================================================================
parameters_perfprof = struct();
parameters_perfprof.expand = [xopt(1), 2.0];
parameters_perfprof.shrink = [xopt(2), 0.5];

options_perfprof = struct();
options_perfprof.solver_names = {'cbds-tuning', 'cbds-default'};
options_perfprof.plibs = plibs;
options_perfprof.mindim = mindim;
options_perfprof.maxdim = maxdim;

% Pass the specific subfolder path to the profiler to save plots together
options_perfprof.savepath = path_tuning_sub;

if ~is_noisy
    options_perfprof.n_runs = 1;

    options_perfprof.feature_name = 'plain';
    tuning_optiprofiler(parameters_perfprof, options_perfprof);

    options_perfprof.feature_name = 'linearly_transformed';
    tuning_optiprofiler(parameters_perfprof, options_perfprof);
else
    options_perfprof.n_runs = 3;
    
    options_perfprof.feature_name = 'noisy_1e-3';
    tuning_optiprofiler(parameters_perfprof, options_perfprof);

    options_perfprof.feature_name = 'noisy_1e-7';
    tuning_optiprofiler(parameters_perfprof, options_perfprof);

    options_perfprof.feature_name = 'rotation_noisy_1e-3';
    tuning_optiprofiler(parameters_perfprof, options_perfprof);
    
    options_perfprof.feature_name = 'rotation_noisy_1e-7';
    tuning_optiprofiler(parameters_perfprof, options_perfprof);
end

end

function plibs_stamp = get_plibs_stamp(plibs)
    if ischar(plibs)
        plibs = {plibs};
    elseif isstring(plibs)
        plibs = cellstr(plibs(:)');
    end

    plibs = lower(plibs);
    has_matcutest = any(strcmp(plibs, 'matcutest'));
    has_s2mpj = any(strcmp(plibs, 's2mpj'));

    if has_matcutest && has_s2mpj
        plibs_stamp = 'matcutest_s2mpj';
    elseif has_matcutest
        plibs_stamp = 'matcutest';
    elseif has_s2mpj
        plibs_stamp = 's2mpj';
    else
        plibs_stamp = strjoin(unique(plibs, 'stable'), '_');
    end
end