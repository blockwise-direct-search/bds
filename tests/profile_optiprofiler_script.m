clear all
% options.dim = 'big';
options.solver_names = {'cbds-orig', 'cbds-orig-smart-alpha-init'};
options.mindim = 1;
options.maxdim = 200;
% options.feature_name = 'plain';
% profile_optiprofiler(options);

options.feature_name = 'plain';
profile_optiprofiler(options);

% options.feature_name = 'noisy_1e-6';
% profile_optiprofiler(options);

% options.solver_names = {'default-fd-bfgs', 'praxis'};

% options.feature_name = 'noisy_1e-3';
% profile_optiprofiler(options);

% options.feature_name = 'noisy_1e-6';
% profile_optiprofiler(options);


% options.feature_name = 'linearly_transformed';
% profile_optiprofiler(options);
% options.feature_name = 'perturbed_x0_1';
% profile_optiprofiler(options);

% options.feature_name = 'noisy_1e-1';
% profile_optiprofiler(options);

% options.feature_name = 'noisy_1e-2';
% profile_optiprofiler(options);

% options.feature_name = 'noisy_1e-3';
% profile_optiprofiler(options);

% options.feature_name = 'noisy_1e-4';
% profile_optiprofiler(options);

% options.feature_name = 'rotation_noisy_1e-1';
% profile_optiprofiler(options);

% options.feature_name = 'rotation_noisy_1e-2';
% profile_optiprofiler(options);

% options.feature_name = 'rotation_noisy_1e-3';
% profile_optiprofiler(options);

% options.feature_name = 'rotation_noisy_1e-4';
% profile_optiprofiler(options);



