function setup(varargin)
%This file is based on https://github.com/libprima/prima/blob/main/setup.m, which is written by 
%Zaikun Zhang.
%SETUP sets the package up for MATLAB.
%
%   This script can be called in the following ways.
%
%   setup  % Add the paths needed to use the package
%   setup install  % Add the paths needed to use the package
%   setup uninstall  % Uninstall the package
%
%   REMARKS:
%
%   To make the setup persistent across MATLAB sessions, this script needs write access to the
%   system path definition file or to the user's startup.m file.
%
%   ***********************************************************************
%   Authors:    Haitian LI (hai-tian.li@connect.polyu.hk)
%               and Zaikun ZHANG (zhangzaikun@mail.sysu.edu.cn)
%               Department of Applied Mathematics,
%               The Hong Kong Polytechnic University
%               School of Mathematics,
%               Sun Yat-sen University
%   ***********************************************************************

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Attribute: public (can be called directly by users)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% setup starts

% Name of the package. It will be used as a stamp in startup.m path entries.
% Needed only if `savepath` fails.
package_name = "bds";

% Check the version of MATLAB.
if verLessThan("matlab", "9.3")   % MATLAB R2017b = MATLAB 9.3
    fprintf("\nSorry, this package does not support MATLAB R2017a or earlier releases.\n\n");
    return
end

% The full paths to several directories needed for the setup.
setup_dir = fileparts(mfilename("fullpath")); % The directory containing this setup script.
src_dir = fullfile(setup_dir, "src"); % Directory containing the source code of the package.
examples_dir = fullfile(setup_dir, "examples"); % Directory containing some examples.
tests_dir = fullfile(setup_dir, "tests"); % Directory containing some tests.

% % We need write access to `setup_dir` (and its subdirectories). Return if we do not have it.
% % N.B.: This checking is NOT perfect because of the following --- but it is better than nothing.
% % 1. `fileattrib` may not reflect the attributes correctly, particularly on Windows. See
% % https://www.mathworks.com/matlabcentral/answers/296657-how-can-i-check-if-i-have-read-or-write-access-to-a-directory
% % 2. Even if we have write access to `setup_dir`, we may not have the same access to its subdirectories.
% [~, attribute] = fileattrib(setup_dir);
% if ~attribute.UserWrite
%     fprintf("\nSorry, we cannot continue because we do not have write access to\n\n%s\n\n", setup_dir);
%     return
% end

% Parse the input.
[action, wrong_input] = parse_input(varargin);

% Exit if wrong input detected. Error messages have been printed during the parsing.
if wrong_input
    error("bds:InvalidInput", "setup: The input is invalid.");
end

% Uninstall the package if requested.
if strcmp(action, "uninstall")
    uninstall_bds(package_name);
    return
end

% Add the related paths to the MATLAB path, and then try saving the path.
path_strings = {src_dir, examples_dir};
% A solver-only sparse checkout does not include the test suite.
if exist(tests_dir, "dir")
    path_strings{end + 1} = tests_dir;
end
path_saved = add_save_path(path_strings, package_name);

fprintf("\nThe package is ready to use.\n");
fprintf("\nYou may now try ""help bds"" for information on the usage of the package.\n");
if exist(tests_dir, "dir")
    fprintf("\nYou may also run ""testbds"" to test the package on a few examples.\n");
end

if ~path_saved  % `add_save_path` failed to save the path.
    add_path_string = sprintf("addpath(""%s"");", src_dir);
    fprintf("\n***** To use the package in other MATLAB sessions, do ONE of the following. *****\n");
    fprintf("\n- Append the following line to your startup script");
    fprintf("\n  (see https://www.mathworks.com/help/matlab/ref/startup.html for information):\n");
    fprintf("\n    %s\n", add_path_string);
    fprintf("\n- OR come to the current directory and run ""setup"" when you need the package.\n");
end

fprintf("\n");

% setup ends
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function path_saved = add_save_path(path_strings, path_string_stamp)
%This function is based on https://github.com/libprima/prima/blob/main/setup.m, by Zaikun Zhang.
%ADD_SAVE_PATH adds the paths indicated by PATH_STRINGS to the MATLAB path and then tries saving the paths.
% PATH_STRING_STAMP is a stamp used when writing PATH_STRINGS to the user's startup.m file, which is
% needed only if `savepath` fails.

for i = 1:length(path_strings)
    if ~exist(path_strings{i}, "dir")
        error("bds:PathNotExist", "The string %s does not correspond to an existing directory.", path_strings{i});
    end

    addpath(path_strings{i});
end

% Try saving the path in the system path-defining file at sys_pathdef. If the user does not have
% writing permission for this file, then the path will not saved.
% N.B. Do not save the path to the pathdef.m file under userpath. This file is not loaded by default
% at startup. See
% https://www.mathworks.com/matlabcentral/answers/269482-is-userdata-pathdef-m-for-local-path-additions-supported-on-linux
orig_warning_state = warning;
warning("off", "MATLAB:SavePath:PathNotSaved"); % Maybe we do not have the permission to save path
sys_pathdef = fullfile(matlabroot(), "toolbox", "local", "pathdef.m");
path_saved = (savepath(sys_pathdef) == 0);
warning(orig_warning_state); % Restore the behavior of displaying warnings

% If path not saved, try editing the startup.m of this user. Do this only if userpath is nonempty.
% Otherwise, we will only get a startup.m in the current directory, which will not be executed
% when MATLAB starts from other directories. On Linux, the default value of userpath is
% ~/Documents/MATLAB, but it will be "" if this directory does not exist. We refrain from creating
% this directory in that case.
if ~path_saved && numel(userpath) > 0
    user_startup = fullfile(userpath, "startup.m");
    path_saved = true;

    for i = 1:length(path_strings)
        add_path_string = sprintf("addpath(""%s"");", path_strings{i});
        full_add_path_string = sprintf("%s\t%s %s", add_path_string, "%", path_string_stamp);

        % First, check whether full_add_path_string already exists in user_startup or not.
        if exist(user_startup, "file")
            startup_text_cells = regexp(fileread(user_startup), "\n", "split");
            full_add_path_string_exists = any(strcmp(startup_text_cells, full_add_path_string));
        else
            startup_text_cells = {};
            full_add_path_string_exists = false;
        end

        if ~full_add_path_string_exists
            % We first check whether the last line of the user startup script is an empty line (or the
            % file is empty or even does not exist at all). If yes, we do not need to put a line break
            % before the path adding string.
            if exist(user_startup, "file")
                last_line_empty = isempty(startup_text_cells) || (isempty(startup_text_cells{end}) && ...
                    isempty(startup_text_cells{max(1, end-1)}));
            else
                last_line_empty = true;
            end

            file_id = fopen(user_startup, "a");  % Open/create file for writing. Append data to the end.
            if file_id ~= -1 % If FOPEN cannot open the file, it returns -1; We keep silent if it fails.
                if ~last_line_empty  % The last line of user_startup is not empty
                    fprintf(file_id, "\n");  % Add a new empty line
                end
                fprintf(file_id, "%s", full_add_path_string);
                fclose(file_id);
            end
        end

        % Check that full_add_path_string is indeed added to user_startup.
        if exist(user_startup, "file")
            startup_text_cells = regexp(fileread(user_startup), "\n", "split");
            full_add_path_string_exists = any(strcmp(startup_text_cells, full_add_path_string));
        else
            full_add_path_string_exists = false;
        end
        path_saved = path_saved && full_add_path_string_exists;
    end
end


% add_save_path ends
return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function uninstall_bds(path_string_stamp)
    %This function is based on https://github.com/libprima/prima/blob/main/matlab/setup_tools/uninstall_prima.m,
    %by Zaikun Zhang.
    %UNINSTALL_BDS uninstalls BDS.
    
    fprintf("\nUninstalling BDS (if it is installed) ... ");
    
    % The full path of several directories.
    mfiledir = fileparts(mfilename("fullpath"));  % The directory where this .m file resides
    src = fullfile(mfiledir, "src"); % Directory containing the source code
    examples = fullfile(mfiledir, "examples"); % Directory containing some examples
    tests = fullfile(mfiledir, "tests"); % Directory containing some tests
    path_strings = {src, examples, tests}; % The paths to be removed
    
    % Try removing the paths possibly added by BDS.
    orig_warning_state = warning;
    warning("off", "MATLAB:rmpath:DirNotFound"); % Maybe the paths were not added. We do not want to see this warning.
    warning("off", "MATLAB:SavePath:PathNotSaved"); % Maybe we do not have the permission to save path.
    rmpath(src, examples, tests);
    sys_pathdef = fullfile(matlabroot(), "toolbox", "local", "pathdef.m");
    savepath(sys_pathdef);
    warning(orig_warning_state); % Restore the behavior of displaying warnings
    
    % Removing the line possibly added to the user startup script
    user_startup = fullfile(userpath, "startup.m");
    if exist(user_startup, "file")
        for i = 1:length(path_strings)
            add_path_string = sprintf("addpath(""%s"");", path_strings{i});
            full_add_path_string = sprintf("%s\t%s %s", add_path_string, "%", path_string_stamp);
            try
                del_str_ln(user_startup, full_add_path_string);
            catch
                % Do nothing.
            end
        end
    end
    
    fprintf("Done.\nYou may now remove\n\n    %s\n\nif it contains nothing you want to keep.\n\n", mfiledir);
    
    return
    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function [action, wrong_input] = parse_input(argin)
    %This function is based on https://github.com/libprima/prima/blob/main/matlab/setup_tools/parse_input.m,
    %by Zaikun Zhang.
    %PARSE_INPUT parses the input to the setup script.
    
    % Setup actions.
    action_list = ["install", "uninstall"];
    action = "install";
    wrong_input = false;

    % Start the parsing to set `input_string` and `options`.
    input_string = "install";  % Default value for `input_string`.
    if length(argin) > 1
        fprintf("\nSetup accepts at most one input.\n\n");
        wrong_input = true;
    elseif length(argin) == 1
        if ischarstr(argin{1})
            input_string = argin{1};
        else
            fprintf("\nThe input to setup should be a string and/or a structure.\n\n");
            wrong_input = true;
        end
    end
    
    % Cast input_string to a character array in case it is a MATLAB string.
    input_string = lower(char(input_string));
    
    % Parse `input_string` to set `action`.
    if ismember(input_string, action_list)
        action = input_string;
    else
        wrong_input = true;
    end
    
    return


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    

function del_str_ln(filename, string)
    %This file is cited from https://github.com/libprima/prima/blob/main/matlab/setup_tools/del_str_ln.m,
    %which is written by Zaikun Zhang.
    %DEL_STR_LN deletes from filename all the lines that are identical to string
    
    fid = fopen(filename, "r");  % Open file for reading.
    if fid == -1
        error("Cannot open file %s.", filename);
    end
    
    % Read the file into a cell of strings
    data = textscan(fid, "%s", "delimiter", "\n", "whitespace", "");
    if fclose(fid) ~= 0
        warning("Failed to close file %s.", filename);
    end
    cstr = data{1};
    
    % Remove the rows containing string, ignoring leading and trailing whitespaces.
    cstr(strcmp(strtrim(cstr), strtrim(string))) = [];
    
    % Save the file again
    fid = fopen(filename, "w");  % Open/create new file for writing. Discard existing contents, if any.
    if fid == -1
        error("Cannot open file %s.", filename);
    end
    fprintf(fid, "%s\n", cstr{:});
    if fclose(fid) ~= 0
        warning("Failed to close file %s.", filename);
    end
    
    return

    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function iscs = ischarstr(x)
    %ISCHARSTR checks whether an input is a `char` or `string`
    
    iscs = (isa(x, "char") || isa(x, "string"));
    
