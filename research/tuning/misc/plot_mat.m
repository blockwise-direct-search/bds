function plot_mat(p1, p2, perfs, perfs_saved, options, parameters, solver, competitor)
% parameters: a structure with two fields; the field names are the names of the parameters; for each
% field, the value is a vector representing the values of the corresponding parameter.
% solver: a string representing the solver whose performance is to be evaluated.
% competitor: a string representing the competitor solver.
% options: a structure representing the options to be passed to the performance function.
% p1: a vector representing the values of the first parameter.
% p2: a vector representing the values of the second parameter.
% perfs: a matrix representing the differ in performance between the solver and the competitor.
% perfs_saved: a matrix representing the differ in performance between the solver and the competitor saved in the previous run.

% Get parameter names
param_names = fieldnames(parameters);
assert(length(param_names) == 2, 'There should be two parameters.');
param1_name = param_names{1};
param2_name = param_names{2};

% We save the results in the `data_path` folder. 
current_path = fileparts(mfilename("fullpath"));
% Create the folder if it does not exist.
data_path = fullfile(current_path, "tuning_data");
if ~exist(data_path, 'dir')
    mkdir(data_path);
end
% Creat a subfolder stamped with the current time for the current test. 
time_str = char(datetime('now', 'Format', 'yy_MM_dd_HH_mm'));
feature_str = [char(solver), '_vs_', char(competitor), '_', num2str(options.mindim), '_', ...
                num2str(options.maxdim), '_', char(options.feature), '_', char(options.test_type)];
data_path_name = [feature_str, '_', time_str];
data_path = fullfile(data_path, data_path_name);
mkdir(data_path);

% Save performance data 
save(fullfile(data_path, 'performance_data.mat'), 'p1', 'p2', 'perfs', 'perfs_saved');

% Save options into a mat file.
save(fullfile(data_path, 'options.mat'), 'options');
% Save options into a txt file.
fileID = fopen(fullfile(data_path, 'options.txt'), 'w');
fprintf(fileID, 'options.mindim = %d;\n', options.mindim);
fprintf(fileID, 'options.maxdim = %d;\n', options.maxdim);
fprintf(fileID, 'options.test_type = "%s";\n', options.test_type);
fprintf(fileID, 'options.tau_weights = [%s];\n', num2str(options.tau_weights));
fprintf(fileID, 'options.feature = "%s";\n', options.feature);
fprintf(fileID, 'options.num_random = %d;\n', options.num_random);
fprintf(fileID, 'options.tau_indices = [%s];\n', num2str(options.tau_indices));
fprintf(fileID, 'options.plot_weights = %s;\n', func2str(options.plot_weights));
fclose(fileID);

% Save the parameters into a mat file.
save(fullfile(data_path, 'parameters.mat'), 'parameters');
% Save the parameters into a txt file.
fileID = fopen(fullfile(data_path, 'parameters.txt'), 'w');
fprintf(fileID, 'parameters.%s = [%s];\n', param1_name, num2str(parameters.(param1_name)));
fprintf(fileID, 'parameters.%s = [%s];\n', param2_name, num2str(parameters.(param2_name)));
fclose(fileID);

% Plot
FigHandle=figure('Name', ['(', param1_name, ', ', param2_name, ')', ' v.s. performance']);
hold on;

colormap(jet);

if isfield(options, 'log_color') && options.log_color
    % Use log scale of perfs for a better usage of the color spectrum.
    max_perf = max(perfs(:));
    min_perf = min(perfs(:));
    C = min_perf + (max_perf - min_perf) .* log(perfs - min_perf + 1) ./ log(max_perf - min_perf + 1);
    surf(p1, p2, perfs, C, 'FaceColor','interp', 'FaceAlpha', 0.8, ...
         'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.5);
else
    surf(p1, p2, perfs, 'FaceColor','interp', 'FaceAlpha', 0.8, ...
         'EdgeColor', [0.2 0.2 0.2], 'LineWidth', 0.5);
end

title(gca, strrep(feature_str, '_', '-')); 
xlabel(param1_name);
ylabel(param2_name);

colorbar; 

% Find the top 10 maximum values
[~, idx] = maxk(perfs(:), 10);

markerSize = 10;  % 减小圆圈大小
labelFontSize = 10;  % 减小字体大小

% 添加偏移
z_offset = (max(perfs(:)) - min(perfs(:))) * 0.001;

% 画空心圆，使用深色边缘
h_points = plot3(p1(idx), p2(idx), perfs(idx) + z_offset, 'o', 'MarkerSize', markerSize, ...
      'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0.1 0.1 0.1], 'LineWidth', 1.5);

% 添加黑色标号
h_text = zeros(length(idx), 1);
for i = 1:length(idx)
    h_text(i) = text(p1(idx(i)), p2(idx(i)), perfs(idx(i)) + z_offset, num2str(i), ...
         'VerticalAlignment', 'middle', 'HorizontalAlignment', 'center', ...
         'Color', 'k', 'FontSize', labelFontSize, 'FontWeight', 'bold');
end

% 将点和文本移到最上层
uistack(h_points, 'top');
for i = 1:length(h_text)
    uistack(h_text(i), 'top');
end

view(3) % 3D view
% Save fig
saveas(FigHandle, fullfile(data_path, [param1_name, '_', param2_name, '_vs_performance_3d.fig']), 'fig');
% Use openfig to open the fig file.
% openfig('my3DPlot.fig');
% Save eps of 3d plot 
saveas(FigHandle, fullfile(data_path, [param1_name, '_', param2_name, '_vs_performance_3d.eps']), 'epsc');
% Try converting the eps to pdf.
epsPath = fullfile(data_path, [param1_name, '_', param2_name, '_vs_performance_3d.eps']);
% One way to convert eps to pdf, without showing the output of the command.
system(('epstopdf '+epsPath+' 2> /dev/null'));

% Save eps of 2d plot 
view(2); % Top-down view
% Save fig
saveas(FigHandle, fullfile(data_path, [param1_name, '_', param2_name, '_vs_performance_2d.fig']), 'fig');
% Save eps of 2d plot
saveas(FigHandle, fullfile(data_path, [param1_name, '_', param2_name, '_vs_performance_2d.eps']), 'epsc');
% Try converting the eps to pdf.
epsPath = fullfile(data_path, [param1_name, '_', param2_name, '_vs_performance_2d.eps']);
% One way to convert eps to pdf, without showing the output of the command.
system(('epstopdf '+epsPath+' 2> /dev/null'));


fprintf('Performance data and plots saved in \n %s\n', data_path);

end
