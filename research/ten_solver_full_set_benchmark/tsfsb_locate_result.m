function result = tsfsb_locate_result(search_root, time_stamp)
%TSFSB_LOCATE_RESULT Locate one OptiProfiler result by its marker file.
%
%   Ported from the C02 c02_locate_result.m (commit 846d5c5f), extended
%   with the curves.mat and profile_scores.mat artifacts.

if nargin < 2
    time_stamp = '';
end
if ~exist(search_root, 'dir')
    error('tsfsb_locate_result:MissingSearchRoot', ...
        'The search root does not exist: %s', search_root);
end

if isempty(time_stamp)
    pattern = 'time_stamp_*.txt';
else
    pattern = sprintf('time_stamp_%s.txt', time_stamp);
end
markers = dir(fullfile(search_root, '**', pattern));
if isempty(markers)
    error('tsfsb_locate_result:NoResult', ...
        'No OptiProfiler result marker was found under %s.', search_root);
end
if isempty(time_stamp)
    [~, order] = sort({markers.name});
    marker = markers(order(end));
else
    if numel(markers) ~= 1
        error('tsfsb_locate_result:AmbiguousResult', ...
            'Expected one marker for %s and found %d.', ...
            time_stamp, numel(markers));
    end
    marker = markers(1);
end

result = struct();
result.marker = fullfile(marker.folder, marker.name);
result.time_stamp = marker.name(12:end-4);
result.test_log = marker.folder;
result.root = fileparts(marker.folder);
result.data_file = fullfile(marker.folder, 'data_for_loading.mat');
result.options_user_file = fullfile(marker.folder, 'options_user.mat');
result.options_refined_file = fullfile(marker.folder, 'options_refined.mat');
result.report_file = fullfile(marker.folder, 'report.txt');
result.curves_file = fullfile(marker.folder, 'curves.mat');
result.profile_scores_file = fullfile(marker.folder, 'profile_scores.mat');
result.performance_history_pdf = fullfile(result.root, 'perf_hist.pdf');
result.performance_output_pdf = fullfile(result.root, 'perf_out.pdf');

end
