function verify_bds(parameters)
% This function tests the latest version of the BDS solver against its development version,
% verifying whether they produce consistent results on CUTEst problems.
%
% where
% - `Algorithm` is the name of the Algorithm to test, including "cbds", "ds", "rbds".
%   If it is not provided, then the default Algorithm is "cbds", which is the default Algorithm of BDS.
% - `problem_names` are the names of the problems to test.
% - `n_runs` is the index of the first random run in iseqiv.m. Default is 1.
% - `num_random` is the number of random runs in iseqiv.m. Default is 20.
% - `parallel` is either true or false, which means whether to test the problems parallelly.
% - `problem_type` can only be "u" now, indicating the problem type to test.
%
% Coded by LI Haitian (hai-tian.li@connect.polyu.hk) and Zaikun ZHANG (zhangzaikun@mail.sysu.edu.cn).
%
% Started: Nov 2023
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


% % Record the current path.
% oldpath = path();
% % Restore the "right out of the box" path of MATLAB.
% restoredefaultpath;
% Record the current directory.
old_dir = pwd();

exception = [];

% Set options to an empty structure if it is not provided.
if nargin < 1
    parameters = struct();
end

try

    % Compile the version of norma.
    path_norma = locate_norma();
    path_verify_bds = fileparts(mfilename('fullpath'));
    cd(path_norma{1});
    setup
    cd(path_verify_bds);

    % % Compile the version of modern repository.
    path_root = fileparts(path_verify_bds);
    cd(path_root);
    setup
    cd(path_verify_bds);

    solvers = {"bds", "bds_norma"};

    % Get list of problems
    if isfield(parameters, "ptype")
        options_s2mpj.ptype = parameters.ptype;
    else
        options_s2mpj.ptype = "u";
    end

    if isfield(parameters, "mindim")
        options_s2mpj.mindim = parameters.mindim;
    else
        options_s2mpj.mindim = 1;
    end

    if isfield(parameters, "maxdim")
        options_s2mpj.maxdim = parameters.maxdim;
    else
        options_s2mpj.maxdim = 10;
    end

    blacklist = ["DIAMON2DLS",...
        "DIAMON2D",...
        "DIAMON3DLS",...
        "DIAMON3D",...
        "DMN15102LS",...
        "DMN15102",...
        "DMN15103LS",...
        "DMN15103",...
        "DMN15332LS",...
        "DMN15332",...
        "DMN15333LS",...
        "DMN15333",...
        "DMN37142LS",...
        "DMN37142",...
        "DMN37143LS",...
        "DMN37143",...
        "ROSSIMP3_mp"];
    blacklist_time_consuming = ["BAmL1SPLS",...
        "FBRAIN3LS",...
        "GAUSS1LS",...
        "GAUSS2LS",...
        "GAUSS3LS",...
        "HYDC20LS",...
        "HYDCAR6LS",...
        "LUKSAN11LS",...
        "LUKSAN12LS",...
        "LUKSAN13LS",...
        "LUKSAN14LS",...
        "LUKSAN17LS",...
        "LUKSAN21LS",...
        "LUKSAN22LS",...
        "METHANB8LS",...
        "METHANL8LS",...
        "SPINLS",...
        "VESUVIALS",...
        "VESUVIOLS",...
        "VESUVIOULS",...
        "YATP1CLS"];
    problem_names_orig = s2mpj_select(options_s2mpj);
    problem_names = [];
    for i = 1:length(problem_names_orig)
        if ~ismember(problem_names_orig(i), blacklist) && ...
                ~ismember(problem_names_orig(i), blacklist_time_consuming)
            problem_names = [problem_names, problem_names_orig(i)];
        end
    end

    % Record `olddir` in `options` so that we can come back to `olddir` during `isequiv` if
    % necessary (for example, when a single test fails).
    parameters.olddir = old_dir;
    
    fprintf("We will load %d problems\n\n", length(problem_names))

    % Get the number of problems.
    num_problems = length(problem_names);

    if isfield(parameters, 'prec')
        prec = parameters.prec;
    else
        prec = 0;
    end

    if ~isfield(parameters, "parallel")
        parallel = get_default_profile_options("parallel");
    else
        parallel = parameters.parallel;
    end
    parameters.sequential = ~parallel;

    if ~isfield(parameters, "n_runs")
        n_runs = 1;
    else
        n_runs = parameters.n_runs;
    end

    if ~isfield(parameters, "num_random")
        num_random = 20;
    else
        num_random = parameters.num_random;
    end

    if isfield(parameters, 'single_test')
        single_test = parameters.single_test;
    else
        single_test = (num_random == 1);
    end
    
    if parallel
        parfor i_problem = 1:num_problems
            problem_info = s2mpj_load(char(problem_names(i_problem)));
            p = s2mpj_wrapper(problem_info);
            for i_run = n_runs:n_runs+num_random-1
                fprintf("%d(%d). %s\n", i_problem, i_run, p.name);
                iseqiv(solvers, p, i_run, single_test, prec, parameters);
            end
        end
    else
        for i_problem = 1:num_problems
            problem_info = s2mpj_load(char(problem_names(i_problem)));
            p = s2mpj_wrapper(problem_info);
            for i_run = n_runs:n_runs+num_random-1
                fprintf("%d(%d). %s\n", i_problem, i_run, p.name);
                iseqiv(solvers, p, i_run, single_test, prec, parameters);
            end
        end
    end

catch exception

    % Do nothing for the moment.

end

% Go back to the original directory.
cd(old_dir);

if ~isempty(exception)  % Rethrow any exception caught above.
    rethrow(exception);
end

end