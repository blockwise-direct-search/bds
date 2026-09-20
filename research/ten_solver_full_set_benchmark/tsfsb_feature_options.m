function options = tsfsb_feature_options(feature)
%TSFSB_FEATURE_OPTIONS Map a logical TSFSB feature to benchmark options.
%
%   New for TSFSB. The parsing follows tests/profile_optiprofiler.m
%   (lines 57-129) and the OptiProfiler Feature.m source (frozen
%   fdf2c550).
%
%   'plain'                  -> feature_name 'plain', n_runs from the
%                               feature (1 in the frozen spec).
%   'noisy_1e-k'             -> feature_name 'noisy', noise_level 1e-k.
%   'linearly_transformed'   -> feature_name 'linearly_transformed' with
%                               rotated true and condition_factor 0 set
%                               explicitly (pure orthogonal
%                               transformation; these are also the
%                               OptiProfiler defaults, set here so the
%                               options do not depend on defaults).
%   'linearly_transformed_noisy_1e-k'
%                            -> feature_name 'custom' with mod_x0,
%                               mod_affine, and mod_fun ported from
%                               tests/profile_optiprofiler.m. This is the
%                               C02 mechanism, kept because the OptiProfiler
%                               Feature constructor does not accept
%                               noise_level for 'linearly_transformed'
%                               (verified in Feature.m, known options for
%                               that feature are n_runs, rotated, and
%                               condition_factor only). The custom
%                               modifiers reproduce the built-in
%                               realization exactly: mod_affine draws the
%                               same sign-fixed QR rotation as the
%                               built-in linearly_transformed feature
%                               with condition_factor 0, and mod_fun adds
%                               sigma*max(1,|f|)*Z with Z drawn from the
%                               same per-evaluation stream as the built-in
%                               noisy feature.
%
%   feature_stamp is always the logical feature name, so the result
%   directory identity matches the frozen spec names.

if ~isstruct(feature) || ~isfield(feature, 'name')
    error('tsfsb_feature_options:InvalidFeature', ...
        'feature must be a struct from tsfsb_benchmark_spec.');
end
name = char(feature.name);

options = struct();
options.n_runs = feature.n_runs;
options.feature_stamp = name;

if strcmp(name, 'plain')
    options.feature_name = 'plain';
    return;
end

noise_level = 0;
if contains(name, 'noisy')
    exponent_text = extractAfter(name, '1e-');
    noise_level = 10^(-str2double(exponent_text));
end

if startsWith(name, 'linearly_transformed_noisy')
    options.feature_name = 'custom';
    options.mod_x0 = @tsfsb_mod_x0_orthogonal;
    options.mod_affine = @tsfsb_mod_affine_orthogonal;
    options.mod_fun = @(x, rand_stream, problem) ...
        tsfsb_mod_fun_noisy(x, rand_stream, problem, noise_level);
elseif startsWith(name, 'linearly_transformed')
    options.feature_name = 'linearly_transformed';
    options.rotated = true;
    options.condition_factor = 0;
elseif startsWith(name, 'noisy')
    options.feature_name = 'noisy';
    options.noise_level = noise_level;
else
    error('tsfsb_feature_options:UnknownFeature', ...
        'Unknown TSFSB logical feature name ''%s''.', name);
end

end

function x0 = tsfsb_mod_x0_orthogonal(rand_stream, problem)
% Ported from mod_x0 in tests/profile_optiprofiler.m (C02 mechanism).

[Q, R] = qr(rand_stream.randn(problem.n));
Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
x0 = Q * problem.x0;

end

function [A, b, inv] = tsfsb_mod_affine_orthogonal(rand_stream, problem)
% Ported from mod_affine in tests/profile_optiprofiler.m (C02 mechanism).
% Reproduces the built-in linearly_transformed feature with
% condition_factor 0: A = Q', b = 0, inv = Q.

[Q, R] = qr(rand_stream.randn(problem.n));
Q(:, diag(R) < 0) = -Q(:, diag(R) < 0);
A = Q';
b = zeros(problem.n, 1);
inv = Q;

end

function f = tsfsb_mod_fun_noisy(x, rand_stream, problem, noise_level)
% Ported from the mod_fun_* family in tests/profile_optiprofiler.m (C02
% mechanism), parameterized by the noise level. Reproduces the built-in
% noisy feature: f_tilde = f + sigma*max(1, |f|)*Z with Z standard
% normal from the per-evaluation stream.

f = problem.fun(x);
f = f + max(1, abs(f)) * noise_level * rand_stream.randn(1);

end
