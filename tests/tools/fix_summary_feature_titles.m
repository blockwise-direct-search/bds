function fix_summary_feature_titles(pdf_file, feature_title)
%FIX_SUMMARY_FEATURE_TITLES Retitle an OptiProfiler MATLAB summary PDF.
%
% OptiProfiler's MATLAB summary title uses feature.name, which must remain a
% legal internal feature such as "noisy" or "custom".  This helper changes the
% saved summary .fig title and re-exports the PDF, so wrappers can display a
% specific label such as "noisy_1e-3" without changing OptiProfiler inputs or
% rerunning the experiment.

    if nargin < 2 || isempty(feature_title)
        return;
    end
    if iscell(feature_title)
        feature_title = feature_title{1};
    end
    feature_title = char(feature_title);

    if ~exist(pdf_file, 'file')
        error('fix_summary_feature_titles:FileNotFound', ...
            'Cannot find PDF file: %s', pdf_file);
    end

    fig_file = summary_fig_file(pdf_file);
    if ~exist(fig_file, 'file')
        warning('fix_summary_feature_titles:FigFileNotFound', ...
            'Cannot retitle %s because the matching summary figure was not found: %s', ...
            pdf_file, fig_file);
        return;
    end

    fig = openfig(fig_file, 'invisible');
    cleanup_fig = onCleanup(@() close_valid_figure(fig));

    layouts = findall(fig, 'Type', 'tiledlayout');
    if isempty(layouts)
        warning('fix_summary_feature_titles:NoTiledLayout', ...
            'Cannot retitle %s because no tiledlayout was found in %s.', ...
            pdf_file, fig_file);
        return;
    end

    title_handle = find_summary_title(layouts);
    title_handle.String = ['Profiles with the ''', feature_title, ''' feature'];
    title_handle.Interpreter = 'none';

    restore_optiprofiler_summary_size(fig, layouts);
    drawnow;
    if ispc
        print(fig, pdf_file, '-dpdf', '-vector');
    else
        exportgraphics(fig, pdf_file, 'ContentType', 'vector');
    end
    savefig(fig, fig_file);

end

function title_handle = find_summary_title(layouts)

    title_handle = [];
    for i_layout = 1:numel(layouts)
        try
            if ~isempty(layouts(i_layout).Title.String)
                title_handle = layouts(i_layout).Title;
                return;
            end
        catch
        end
    end
    title_handle = layouts(1).Title;

end

function restore_optiprofiler_summary_size(fig, layouts)

    [outer_grid, inner_grid] = summary_grid_size(layouts);
    if isempty(outer_grid) || isempty(inner_grid)
        return;
    end

    default_width = 640;
    default_height = 480;
    summary_width = inner_grid(2) * default_width;
    summary_height = outer_grid(1) * inner_grid(1) * default_height;

    fig.Units = 'pixels';
    fig.Position = [fig.Position(1:2), summary_width, summary_height];

end

function [outer_grid, inner_grid] = summary_grid_size(layouts)

    grids = zeros(numel(layouts), 2);
    for i_layout = 1:numel(layouts)
        try
            grids(i_layout, :) = layouts(i_layout).GridSize;
        catch
        end
    end

    valid = all(grids > 0, 2);
    grids = grids(valid, :);
    if isempty(grids)
        outer_grid = [];
        inner_grid = [];
        return;
    end

    [~, outer_idx] = min(prod(grids, 2));
    outer_grid = grids(outer_idx, :);

    inner_candidates = grids;
    inner_candidates(outer_idx, :) = [];
    if isempty(inner_candidates)
        inner_grid = [];
        return;
    end
    [~, inner_idx] = max(prod(inner_candidates, 2));
    inner_grid = inner_candidates(inner_idx, :);

end

function close_valid_figure(fig)

    if isgraphics(fig)
        close(fig);
    end

end

function fig_file = summary_fig_file(pdf_file)

    [summary_dir, pdf_name, ~] = fileparts(pdf_file);
    figs_dir = fullfile(summary_dir, 'test_log', 'profile_figs');
    fig_file = fullfile(figs_dir, [pdf_name, '.fig']);

end
