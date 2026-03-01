function [best_value] = hp_tuning(initial_value, parameters, options)
% This file is to tune the hyperparameters of BDS, only including expanding
% factor, shrinking factor.
%
% Input:
% Parameters should include the following fields:
% solvers_name:    the algorithm of the BDS, including "cbds", "pbds", "rbds",
%                  "ds" and "pads".
% problem_mindim:  the minimum dimension of the problem. The default value
%                  is 1.
% problem_maxdim:  the maximum dimension of the problem. The default value
%                  is 5.
% tau:             the tolerance for performance profile.
% min_precision:   the minimum precision for performance profile.
% parallel:        whether to use parallel computing. The default value is false.
% tuning_solver:   The default value is bobyqa. To see more details, please refer
%                  to the matlab version of prima (https://github.com/libprima/prima).
%                  The user can set any derivative-free optimization solver
%                  which can handle the bound constraints.
%                  but please make sure that the path of the solver is already
%                  set before you do the tuning.
%
% Options should include the following fields:
% maxfun:          the maximum number of function evaluations for the tuning
%                  solver.
% initial_value:   the initial value of the hyperparameters. It only includes
%                  the expanding factor and the shrinking factor. The default
%                  value is [2, 0.5].
% average:         whether to use average to sample the hyperparameters. The default
%                  value is false. If it is true, the algorithm will sample the
%                  hyperparameters like central difference with the step size of half of the
%                  hyperparameters (only for reduction factors). This is done
%                  mainly because the reduction factors are quite small compared
%                  to the other hyperparameters. Average the sampled values can
%                  improve the robustness of the algorithm. To see more details,
%                  please refer to the hp_handle.m.
% num_random:      the number of random problems. The default value is 1.
%

% Record the current path.
oldpath = path();
% Restore the "right out of the box" path of MATLAB.
restoredefaultpath;
% Record the current directory.
old_dir = pwd();

% Add the paths that we need to use in the performance profile into the MATLAB
% search path.
current_path = mfilename("fullpath");
path_tests = fileparts(fileparts(current_path));
path_tuning = fileparts(current_path);
path_root = fileparts(path_tests);
path_tools = fullfile(path_tests, "tools");
path_src = fullfile(path_root, "src");
path_competitors = fullfile(path_tests, "competitors");
addpath(path_root);
addpath(path_tests);
addpath(path_src);
addpath(path_competitors);
addpath(path_tuning);
addpath(path_tools);

% If the folder of testdata does not exist, make a new one.
path_testdata = fullfile(path_tests, "testdata");
if ~exist(path_testdata, "dir")
    mkdir(path_testdata);
end

% Go back to the original path.
cd(old_dir);

% Set tau for performance profile.
if isfield(parameters, "min_precision")
    parameters.tau = 10.^(-1:-1:(-parameters.min_precision));
    parameters = rmfield(parameters, "min_precision");
elseif ~isfield(parameters, "min_precision") && ~isfield(parameters, "tau")
    parameters.tau = 10.^(-1:-1:get_default_profile_options("min_precision"));
end
if ~isfield(parameters, "parallel")
    parameters.parallel = false;
end
PRIMA_list = ["uobyqa", "bobyqa", "bobyqa", "lincoa", "cobyla"];
if ~isfield(parameters, "tuning_solver")
    parameters.tuning_solver = "bobyqa";
end
if ismember(parameters.tuning_solver, PRIMA_list)
    % Setup prima since the tuning solver is in the PRIMA list.
    locate_prima_position = fullfile(path_competitors, "private");
    cd(locate_prima_position)
    locate_prima();
end
if ~isfield(parameters, "blacklist")
    parameters.blacklist = false;
end
if ~isfield(parameters, "reduction_error")
    parameters.reduction_error = false;
end

if ~isfield(parameters, "test_type")
    parameters.test_type = "s2mpj";
end

if ~isfield(parameters, "num_random")
    parameters.num_random = 1;
end

if ~isfield(parameters, "output_xhist")
    options.output_xhist = true;
end

best_value = NaN(1, length(parameters.tau) + length(initial_value) + 1);

% Preconditions for initial_value and constrains.
initial_value_saved = initial_value;
best_value(1:length(parameters.tau)) = parameters.tau;

% Here we can use any solver that can deal with the unconstrained problem to tune
% the hyperparameters.
switch parameters.tuning_solver
    case "bobyqa"
        %options.rhobeg = 0.125;
        options.rhoend = 1e-10;
        options.scale = false;
        lb = log2([1 + 1e-2, 1e-2]);
        ub = log2([10, 1 - 1e-2]);
        [xopt, fopt, ~, output_tuning] = ...
            bobyqa(@(x)hp_handle(2.^x, parameters), log2(initial_value), lb, ub, options);
    otherwise
        tuning_solver = str2func(parameters.tuning_solver);
        [xopt, fopt, ~, output_tuning] = ...
            tuning_solver(@(x)hp_handle(x, parameters), initial_value, options);
end

% Scale xhist as the real value.
if isfield(output_tuning, "xhist")

    switch parameters.tuning_solver
        case "bobyqa"
            output_tuning.xhist = 2.^(output_tuning.xhist(1:2, :));
        otherwise
            error("Unknown algorithm %s", parameters.tuning_solver);
    end

end

% Scale xopt and transpose xopt for record the best_value in the txt file.
switch lower(parameters.solvers_name(1))
    case "cbds"
        best_value(end-2) = fopt;
        best_value(end-1:end) = 2.^(xopt);
    otherwise
        error("Unknown algorithm %s", parameters.solvers_name(1));
end

% Use time to distinguish.
tst = strcat("hyperparameters_tuning", "_", parameters.solvers_name(1));
if length(parameters.tau) == 1
    tst = strcat(tst, "_", "single", "_", parameters.tuning_solver, "_", ...
        int2str(int32(-log10(parameters.tau))));
else
    tst = strcat(tst, "_", "multi", "_", parameters.tuning_solver, "_", ...
        int2str(int32(-log10(max(parameters.tau)))), ...
        "_", int2str(int32(-log10(min(parameters.tau)))));
end
if isfield(parameters, "feature")
    tst = strcat(tst, "_", parameters.feature);
else
    tst = strcat(tst, "_", "plain");
end

if isfield(parameters, "test_type")
    tst = strcat(tst, "_", parameters.test_type);
else
    tst = strcat(tst, "_", "s2mpj");
end

if parameters.blacklist
    tst = strcat(tst, "_", "blacklist");
else
    tst = strcat(tst, "_", "non_blacklist");
end
if isfield(options, "maxfun")
    tst = strcat(tst, "_", string(num2str(options.maxfun)));
end
if isfield(options, "MaxFunctionEvaluations")
    tst = strcat(tst, "_", string(num2str(options.MaxFunctionEvaluations)));
end
% Trim time string.
time_str = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
time_str = trim_time(time_str);
tst = strcat(tst, "_", time_str);

path_testdata = fullfile(path_tests, "testdata");
path_testdata_outdir = fullfile(path_tests, "testdata", tst);

% Make a new folder to save numerical results and source code.
mkdir(path_testdata, tst);
mkdir(path_testdata_outdir, "tuning_data");
path_testdata_tuning_data = fullfile(path_testdata_outdir, "tuning_data");
mkdir(path_testdata_outdir, "src");
path_testdata_src = fullfile(path_testdata_outdir, "src");
mkdir(path_testdata_outdir, "tests");
path_testdata_tests = fullfile(path_testdata_outdir, "tests");
path_testdata_competitors = fullfile(path_testdata_tests, "competitors");
mkdir(path_testdata_competitors);
path_testdata_private = fullfile(path_testdata_tests, "private");
mkdir(path_testdata_private);

% Make a Txt file to store the initial_value, best_value and output under
% different tau.
filePath = strcat(path_testdata_tuning_data, "/tune_results.txt");
fileID = fopen(filePath, 'w');
% Write initial_value into the file in one line. Notice that when we try
% to record it, make sure the form of the initial_value should be column
% vector.
initial_value_record = num2str(reshape(initial_value_saved, 1, []));
separator = ", ";
initial_value_record = strjoin(strsplit(initial_value_record), separator);
fprintf(fileID, '%s: %s\n',"initial_value", initial_value_record);
% Write field names and their corresponding values into a file line by line.
best_value_record = num2str(best_value);
separator = ", ";
best_value_record = strjoin(strsplit(best_value_record), separator);
fprintf(fileID, '%s: %s\n',"tau_length", best_value_record);
% Get the field names of the output structure under the specific tau.
output_tuning_saved = output_tuning;
% Normally, output_tuning_saved should be a structure, which contains
% the following fields:
% xhist: the history of the hyperparameters.
% fhist: the history of the objective function values, which are the
%        value of the performance profile.
% funcCount: the number of function evaluations.
% algorithm: the algorithm used.
% message: the message returned by the algorithm.
% After trimming, the fields of output_tuning_saved should be still
% the same. However, the values of the fields may be different.
% xhist will be unchanged since it is always the matrix (here it implies
% that the number of rows are not 1).
% fhist will become a string. We will write it to the txt file
% directly.
% funcCount will also become a string. We will write it to the txt file
% directly, too.
% The same work for algorithm and message.
output_tuning_saved = trim_struct(output_tuning_saved);
% Get the field names of a structure.
output_tuning_saved_fields = fieldnames(output_tuning_saved);
for i = 1:numel(output_tuning_saved_fields)
    field = output_tuning_saved_fields{i};
    value = output_tuning_saved.(field);
    if ~iscell(value)
        if isnumvec(value)
            if size(value{1}, 1) == 1
                value_saved = num2str(value');
                separator = ", ";
                if length(value_saved) ~= 1
                    value_saved = strjoin(strsplit(value_saved), separator);
                    fprintf(fileID, '%s: %s\n', field, value_saved);
                end
            end
            % This extreme case is just for xhist, since it is still a matrix
            % after trimming.
        elseif ismatrix(value) && size(value, 1) == length(initial_value)
            value = value';
            fprintf(fileID, '%s:\n', field);
            % Define the width of each column and the spacing between columns.
            column_width = 10;
            column_spacing = 5;
            [rows, cols] = size(value);
            for row = 1:rows
                for col = 1:cols
                    % Use a formatting string to set left alignment and
                    % spacing for columns.
                    format = sprintf('%%-%ds', column_width);
                    fprintf(fileID, format, num2str(value(row, col)));
                    % Add spacing between columns.
                    if col < cols
                        fprintf(fileID, repmat(' ', 1, column_spacing));
                    end
                end
                fprintf(fileID, '\n');
            end
        elseif ischarstr(value)
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

% Make a Txt file to store the parameters that are used.
filePath = strcat(path_testdata_tuning_data, "/parameters.txt");
fileID = fopen(filePath, 'w');
parameters_saved = parameters;
parameters_saved = trim_struct(parameters_saved);
% Get the field names of a structure.
parameters_saved_fields = fieldnames(parameters_saved);
% Write field names and their corresponding values into a file line by line.
for i = 1:numel(parameters_saved_fields)
    field = parameters_saved_fields{i};
    value = parameters_saved.(field);
    if ~iscell(value)
        fprintf(fileID, '%s: %s\n', field, value);
    else
        for j = 1:length(value)
            solvers_options_saved = trim_struct(value{j});
            solvers_options_saved_fields = fieldnames(solvers_options_saved);
            for k = 1:numel(solvers_options_saved_fields)
                solvers_options_saved_field = solvers_options_saved_fields{k};
                solvers_options_saved_value = solvers_options_saved.(solvers_options_saved_field);
                fprintf(fileID, '%s: %s ', solvers_options_saved_field, ...
                    solvers_options_saved_value);
            end
            fprintf(fileID, '\n');
        end
    end
end
fclose(fileID);

% Copy the source code and test code to path_outdir.
copyfile(fullfile(path_src, "*"), path_testdata_src);
copyfile(fullfile(path_competitors, "*"), path_testdata_competitors);
copyfile(fullfile(path_tests, "private", "*"), path_testdata_private);
copyfile(fullfile(path_root, "setup.m"), path_testdata_outdir);

source_folder = path_tests;
destination_folder = path_testdata_tests;

% Get all files in the source folder.
file_list = dir(fullfile(source_folder, '*.*'));
file_list = file_list(~[file_list.isdir]);

% Copy all files (excluding subfolders) to the destination folder.
for i = 1:numel(file_list)
    source_file = fullfile(source_folder, file_list(i).name);
    destination_file = fullfile(destination_folder, file_list(i).name);
    copyfile(source_file, destination_file);
end

% Plot the performance profile with the specific tau.
parameters_perfprof.solvers_name = parameters.solvers_name;
parameters_perfprof.parallel = true;
if ~isfield(parameters, "problem_mindim")
    parameters_perfprof.problem_mindim = 1;
else
    parameters_perfprof.problem_mindim = parameters.problem_mindim;
end
if ~isfield(parameters, "problem_maxdim")
    parameters_perfprof.problem_maxdim = 5;
else
    parameters_perfprof.problem_maxdim = parameters.problem_maxdim;
end
if isfield(parameters, "feature")
    parameters_perfprof.feature = parameters.feature;
end
if isfield(parameters, "num_random")
    parameters_perfprof.num_random = parameters.num_random;
end
if isfield(parameters, "test_type")
    parameters_perfprof.test_type = parameters.test_type;
end

switch lower(parameters.solvers_name(1))
    case "cbds"
        parameters_perfprof.solvers_options{1}.expand = best_value(end-1);
        parameters_perfprof.solvers_options{1}.shrink = best_value(end);
        % parameters_perfprof.solvers_options{1}.reduction_factor = best_value(end-2:end);
        plot_profile(parameters_perfprof);
    otherwise
        error("Unknown algorithm %s", parameters.solvers_name(1));
end

% Restore the path to oldpath.
setpath(oldpath);
% Go back to the original directory.
cd(old_dir);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% [x, fx, ~, output] = bobyqa(objective, x0, options)
% fprintf('tau: %f\n', tau);
% fprintf('Optimized parameters: %f\n', x);
% fprintf('Optimized value: %f\n', fx);
% fprintf('History of parameters: \n'); fprintf('%f, %f\n', output.xhist);
% fprintf('History of the values: %f\n', output.fhist);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

end